import * as admin from "firebase-admin";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";

admin.initializeApp();
const db = admin.firestore();

export const autoValidateMatches = onSchedule(
  {schedule: "0 0 * * *", timeZone: "Europe/Paris", region: "europe-west3"},
  async () => {
    const now = admin.firestore.Timestamp.now();
    const snapshot = await db.collection("matches")
      .where("status", "==", "open")
      .where("startTime", "<=", now)
      .get();
    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.update(doc.ref, {status: "finished"});
    });
    await batch.commit();
    console.log(`Auto-validé ${snapshot.size} matchs`);
  }
);

export const autoAcceptPlayers = onSchedule(
  {schedule: "*/30 * * * *", timeZone: "Europe/Paris", region: "europe-west3"},
  async () => {
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 6 * 60 * 60 * 1000)
    );
    const snapshot = await db.collection("matches")
      .where("status", "==", "open")
      .where("createdAt", "<=", cutoff)
      .get();
    for (const doc of snapshot.docs) {
      const match = doc.data();
      const pendingIds: string[] = match.pendingIds || [];
      if (pendingIds.length === 0) continue;
      const batch = db.batch();
      batch.update(doc.ref, {
        playerIds: admin.firestore.FieldValue.arrayUnion(...pendingIds),
        pendingIds: [],
      });
      for (const uid of pendingIds) {
        await sendNotification(uid, {
          title: "Demande acceptée ! 🎾",
          body: `Tu es accepté dans le match à ${match.club}`,
        });
      }
      await batch.commit();
    }
  }
);

export const onMatchCreated = onDocumentCreated(
  {document: "matches/{matchId}", region: "europe-west3"},
  async (event) => {
    const match = event.data?.data();
    if (!match) return;
    if (match.visibility !== "public") return;
    const usersSnap = await db.collection("users")
      .where("level", ">=", match.levelMin - 1)
      .where("level", "<=", match.levelMax + 1)
      .get();
    const organizerId = match.organizerId;
    const notifications = usersSnap.docs
      .filter((doc) => doc.id !== organizerId)
      .map((doc) => sendNotification(doc.id, {
        title: "Nouveau match près de toi ! 🎾",
        body: `${match.club} · Niveau ${match.levelMin}-${match.levelMax}`,
        data: {matchId: event.params.matchId},
      }));
    await Promise.allSettled(notifications);
  }
);

export const onMatchCancelled = onDocumentUpdated(
  {document: "matches/{matchId}", region: "europe-west3"},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return;
    if (after.status !== "cancelled") return;
    const playerIds: string[] = after.playerIds || [];
    const organizerId = after.organizerId;
    const batch = db.batch();
    for (const uid of playerIds) {
      if (uid === organizerId) continue;
      const userRef = db.collection("users").doc(uid);
      const userDoc = await userRef.get();
      const credits = userDoc.data()?.credits || 0;
      batch.update(userRef, {
        credits: admin.firestore.FieldValue.increment(1),
      });
      batch.set(db.collection("creditTransactions").doc(), {
        userId: uid,
        type: "refund",
        amount: 1,
        balanceBefore: credits,
        balanceAfter: credits + 1,
        refId: event.params.matchId,
        description: "Remboursement : match annulé",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      await sendNotification(uid, {
        title: "Match annulé 😔",
        body: `Le match à ${after.club} a été annulé. 1 crédit remboursé.`,
      });
    }
    await batch.commit();
  }
);

export const onMatchFinished = onDocumentUpdated(
  {document: "matches/{matchId}", region: "europe-west3"},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return;
    if (after.status !== "finished") return;
    const playerIds: string[] = after.playerIds || [];
    const notifications = playerIds.map((uid) =>
      sendNotification(uid, {
        title: "Match terminé ! Laisse un avis 🌟",
        body: `+1 crédit offert pour ton avis sur le match à ${after.club}`,
        data: {matchId: event.params.matchId},
      })
    );
    await Promise.allSettled(notifications);
  }
);

export const onTournamentStatusChanged = onDocumentUpdated(
  {document: "tournaments/{tournamentId}", region: "europe-west3"},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return;
    const organizerId = after.organizerId;
    const isApproved = after.status === "published";
    await sendNotification(organizerId, {
      title: isApproved ? "Tournoi approuvé ! 🏆" : "Tournoi refusé",
      body: isApproved
        ? `Ton tournoi "${after.title}" est maintenant visible.`
        : `Ton tournoi "${after.title}" n'a pas été approuvé.`,
    });
  }
);

export const updateStatsOnMatchFinish = onDocumentUpdated(
  {document: "matches/{matchId}", region: "europe-west3"},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return;
    if (after.status !== "finished") return;
    if (!after.score) return;
    const playerIds: string[] = after.playerIds || [];
    for (const uid of playerIds) {
      const statsRef = db.collection("userStats").doc(uid);
      await statsRef.set({
        matchesPlayed: admin.firestore.FieldValue.increment(1),
        minutesPlayed: admin.firestore.FieldValue.increment(after.durationMinutes || 90),
      }, {merge: true});
    }
  }
);

async function sendNotification(
  uid: string,
  payload: {title: string; body: string; data?: Record<string, string>}
) {
  try {
    const userDoc = await db.collection("users").doc(uid).get();
    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) return;
    await admin.messaging().send({
      token: fcmToken,
      notification: {title: payload.title, body: payload.body},
      data: payload.data || {},
    });
  } catch (e) {
    console.error(`Erreur notification pour ${uid}:`, e);
  }
}
