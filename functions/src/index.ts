import * as admin from "firebase-admin";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import {onCall, onRequest, HttpsError, type CallableRequest} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import Stripe from "stripe";
import {google} from "googleapis";

const stripeSecretKey     = defineSecret("STRIPE_SECRET_KEY");
const stripeWebhookSecret = defineSecret("STRIPE_WEBHOOK_SECRET");
const appleSharedSecret   = defineSecret("APPLE_SHARED_SECRET");

// ── Bundle ID Android (doit correspondre à google-services.json) ──
const ANDROID_PACKAGE_NAME = "com.example.zupadel";

// ── Packs de crédits ─────────────────────────────────────────────
const CREDIT_PACKS: Record<string, {credits: number; amountCents: number; name: string}> = {
  starter: {credits: 10,  amountCents: 500,  name: "Starter"},
  joueur:  {credits: 25,  amountCents: 1000, name: "Joueur"},
  pro:     {credits: 60,  amountCents: 2000, name: "Pro"},
  elite:   {credits: 150, amountCents: 4000, name: "Elite"},
};

function getDb(): admin.firestore.Firestore {
  if (!admin.apps.length) admin.initializeApp();
  return admin.firestore();
}

// ══════════════════════════════════════════════
//  PAIEMENTS STRIPE
// ══════════════════════════════════════════════

export const createPaymentIntent = onCall(
  {region: "europe-west3", secrets: [stripeSecretKey]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Non authentifié");
    }

    const packId = request.data.packId as string;
    const pack = CREDIT_PACKS[packId];
    if (!pack) throw new HttpsError("invalid-argument", "Pack inconnu");

    const stripe = new Stripe(stripeSecretKey.value());
    const db  = getDb();
    const uid = request.auth.uid;

    // Récupère ou crée le Customer Stripe
    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    const userData = userDoc.data()!;

    let customerId = userData.stripeCustomerId as string | undefined;
    if (!customerId) {
      const customer = await stripe.customers.create({
        email: userData.email as string,
        name: `${userData.firstName ?? ""} ${userData.lastName ?? ""}`.trim(),
        metadata: {firebaseUid: uid},
      });
      customerId = customer.id;
      await userRef.update({stripeCustomerId: customerId});
    }

    // Clé éphémère pour le Payment Sheet
    const ephemeralKey = await stripe.ephemeralKeys.create(
      {customer: customerId},
      {apiVersion: "2024-06-20"},
    );

    // PaymentIntent
    const paymentIntent = await stripe.paymentIntents.create({
      amount:   pack.amountCents,
      currency: "eur",
      customer: customerId,
      automatic_payment_methods: {enabled: true},
      metadata: {
        firebaseUid: uid,
        packId,
        credits: String(pack.credits),
      },
    });

    return {
      clientSecret: paymentIntent.client_secret,
      ephemeralKey: ephemeralKey.secret,
      customerId,
    };
  }
);

export const stripeWebhook = onRequest(
  {region: "europe-west3", secrets: [stripeSecretKey, stripeWebhookSecret]},
  async (req, res) => {
    const stripe = new Stripe(stripeSecretKey.value());
    const sig = req.headers["stripe-signature"] as string;

    let event: Stripe.Event;
    try {
      event = stripe.webhooks.constructEvent(
        req.rawBody,
        sig,
        stripeWebhookSecret.value(),
      );
    } catch (err) {
      console.error("Webhook signature error:", err);
      res.status(400).send(`Webhook Error: ${err}`);
      return;
    }

    const db = getDb();

    if (event.type === "payment_intent.succeeded") {
      const pi = event.data.object as Stripe.PaymentIntent;
      const {firebaseUid, credits, packId, type: piType, tournamentId, fftLicense} = pi.metadata;

      if (piType === "tournamentEntry" && firebaseUid && tournamentId) {
        // Inscription tournoi confirmée
        await db.collection("tournamentRegistrations").add({
          tournamentId,
          userId:          firebaseUid,
          fftLicense:      fftLicense ?? "",
          status:          "paid",
          paymentIntentId: pi.id,
          createdAt:       admin.firestore.FieldValue.serverTimestamp(),
        });
        await sendNotification(firebaseUid, {
          title: "Inscription confirmée ! 🏆",
          body:  "Ton paiement est validé. Bonne chance au tournoi !",
          type:  "tournaments",
          data:  {tournamentId},
        });
      } else if (firebaseUid && credits) {
        // Achat pack crédits
        const creditsToAdd = parseInt(credits);
        const userRef  = db.collection("users").doc(firebaseUid);
        const userDoc  = await userRef.get();
        const current  = userDoc.data()?.credits as number ?? 0;
        const batch = db.batch();
        batch.update(userRef, {credits: admin.firestore.FieldValue.increment(creditsToAdd)});
        batch.set(db.collection("creditTransactions").doc(), {
          userId:        firebaseUid,
          type:          "purchase",
          amount:        creditsToAdd,
          balanceBefore: current,
          balanceAfter:  current + creditsToAdd,
          refId:         pi.id,
          description:   `Achat pack ${packId ?? "?"} — ${creditsToAdd} crédits`,
          createdAt:     admin.firestore.FieldValue.serverTimestamp(),
        });
        await batch.commit();
        console.log(`+${creditsToAdd} crédits pour ${firebaseUid}`);
      }
    }

    if (event.type === "invoice.payment_succeeded") {
      // Abonnement coach renouvelé / activé
      const invoice = event.data.object as Stripe.Invoice;
      const stripe  = new Stripe(stripeSecretKey.value());
      const subId   = invoice.subscription as string | null;
      if (!subId) { res.sendStatus(200); return; }
      const sub = await stripe.subscriptions.retrieve(subId);
      const {firebaseUid, coachId} = sub.metadata;
      if (firebaseUid && coachId) {
        const nextMonth = new Date();
        nextMonth.setMonth(nextMonth.getMonth() + 1);
        await db.collection("coaches").doc(coachId).update({
          subscribedUntil: admin.firestore.Timestamp.fromDate(nextMonth),
          isActive:        true,
        });
        await sendNotification(firebaseUid, {
          title: "Abonnement coach actif ! 🏋️",
          body:  "Ton profil coach est visible jusqu'au " + nextMonth.toLocaleDateString("fr-FR"),
          type:  "coaching",
        });
      }
    }

    res.sendStatus(200);
  }
);

// ══════════════════════════════════════════════
//  ABONNEMENT COACH (10€/mois)
// ══════════════════════════════════════════════

export const createCoachSubscription = onCall(
  {region: "europe-west3", secrets: [stripeSecretKey]},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Non authentifié");
    const {coachId} = request.data as {coachId: string};
    const stripe    = new Stripe(stripeSecretKey.value());
    const db        = getDb();
    const uid       = request.auth.uid;

    const userRef  = db.collection("users").doc(uid);
    const userDoc  = await userRef.get();
    const userData = userDoc.data()!;

    let customerId = userData.stripeCustomerId as string | undefined;
    if (!customerId) {
      const customer = await stripe.customers.create({
        email:    userData.email as string,
        name:     `${userData.firstName ?? ""} ${userData.lastName ?? ""}`.trim(),
        metadata: {firebaseUid: uid},
      });
      customerId = customer.id;
      await userRef.update({stripeCustomerId: customerId});
    }

    const ephemeralKey = await stripe.ephemeralKeys.create(
      {customer: customerId},
      {apiVersion: "2024-06-20"},
    );

    // Abonnement mensuel à 10€
    const subscription = await stripe.subscriptions.create({
      customer:         customerId,
      items:            [{
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        price_data: {
          currency:     "eur",
          product_data: {name: "Abonnement Coach Zupadel"},
          unit_amount:  1000, // 10€
          recurring:    {interval: "month"},
        } as any,
      }],
      payment_behavior: "default_incomplete",
      expand:           ["latest_invoice.payment_intent"],
      metadata:         {firebaseUid: uid, coachId},
    });

    const invoice       = subscription.latest_invoice as Stripe.Invoice;
    const paymentIntent = invoice.payment_intent as Stripe.PaymentIntent;

    return {
      clientSecret:   paymentIntent.client_secret,
      ephemeralKey:   ephemeralKey.secret,
      customerId,
      subscriptionId: subscription.id,
    };
  }
);

// ══════════════════════════════════════════════
//  PAIEMENT INSCRIPTION TOURNOI (+ 10% commission)
// ══════════════════════════════════════════════

export const createTournamentPaymentIntent = onCall(
  {region: "europe-west3", secrets: [stripeSecretKey]},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Non authentifié");
    const {tournamentId, fftLicense} = request.data as {tournamentId: string; fftLicense: string};
    const stripe = new Stripe(stripeSecretKey.value());
    const db     = getDb();
    const uid    = request.auth.uid;

    const tDoc = await db.collection("tournaments").doc(tournamentId).get();
    if (!tDoc.exists) throw new HttpsError("not-found", "Tournoi introuvable");
    const entryFee = (tDoc.data()?.entryFee ?? 0) as number;
    if (entryFee <= 0) throw new HttpsError("invalid-argument", "Ce tournoi est gratuit");

    const amountCents     = Math.round(entryFee * 100);
    const commissionCents = Math.round(amountCents * 0.1); // 10%

    const userRef  = db.collection("users").doc(uid);
    const userDoc  = await userRef.get();
    const userData = userDoc.data()!;

    let customerId = userData.stripeCustomerId as string | undefined;
    if (!customerId) {
      const customer = await stripe.customers.create({
        email:    userData.email as string,
        metadata: {firebaseUid: uid},
      });
      customerId = customer.id;
      await userRef.update({stripeCustomerId: customerId});
    }

    const ephemeralKey = await stripe.ephemeralKeys.create(
      {customer: customerId},
      {apiVersion: "2024-06-20"},
    );

    const paymentIntent = await stripe.paymentIntents.create({
      amount:                    amountCents,
      currency:                  "eur",
      customer:                  customerId,
      automatic_payment_methods: {enabled: true},
      metadata: {
        firebaseUid: uid, tournamentId, fftLicense,
        type:        "tournamentEntry",
        commission:  String(commissionCents),
      },
    });

    return {
      clientSecret: paymentIntent.client_secret,
      ephemeralKey: ephemeralKey.secret,
      customerId,
      amountCents,
    };
  }
);

// ══════════════════════════════════════════════
//  VALIDATION ACHAT IAP (Apple / Google)
// ══════════════════════════════════════════════

const IAP_CREDITS: Record<string, number> = {
  credits_starter: 10,
  credits_joueur:  25,
  credits_pro:     60,
  credits_elite:   150,
};

export const validateIAPPurchase = onCall(
  {region: "europe-west3", secrets: [appleSharedSecret]},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Non authentifié");
    const {platform, productId, verificationData} = request.data as {
      platform: string;
      productId: string;
      verificationData: string;
    };

    const credits = IAP_CREDITS[productId];
    if (!credits) throw new HttpsError("invalid-argument", "Produit inconnu : " + productId);

    // ── Vérification du receipt côté store ───────────────────────
    if (platform === "app_store") {
      const valid = await verifyAppleReceipt(verificationData, appleSharedSecret.value());
      if (!valid) throw new HttpsError("invalid-argument", "Receipt Apple invalide");
    } else if (platform === "google_play") {
      const valid = await verifyGooglePurchase(productId, verificationData);
      if (!valid) throw new HttpsError("invalid-argument", "Achat Google invalide");
    } else {
      throw new HttpsError("invalid-argument", `Plateforme inconnue : ${platform}`);
    }

    const db  = getDb();
    const uid = request.auth.uid;

    // Idempotence : vérifier que ce verificationData n'a pas déjà été traité
    const receiptKey = verificationData.substring(0, 100).replace(/[/\\. ]/g, "_");
    const txRef  = db.collection("iapReceipts").doc(receiptKey);
    const txSnap = await txRef.get();
    if (txSnap.exists) {
      console.log(`IAP déjà traité pour ${uid} — ${productId}`);
      return {success: true, creditsAdded: 0, alreadyProcessed: true};
    }

    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    const current = userDoc.data()?.credits as number ?? 0;

    const batch = db.batch();
    batch.update(userRef, {credits: admin.firestore.FieldValue.increment(credits)});
    batch.set(db.collection("creditTransactions").doc(), {
      userId:        uid,
      type:          "purchase",
      amount:        credits,
      balanceBefore: current,
      balanceAfter:  current + credits,
      refId:         receiptKey,
      description:   `Achat IAP ${platform} — ${productId} (${credits} crédits)`,
      createdAt:     admin.firestore.FieldValue.serverTimestamp(),
    });
    batch.set(txRef, {uid, productId, platform, processedAt: admin.firestore.FieldValue.serverTimestamp()});
    await batch.commit();

    console.log(`IAP +${credits} crédits pour ${uid} (${productId} / ${platform})`);
    return {success: true, creditsAdded: credits};
  }
);

// ══════════════════════════════════════════════
//  MATCHS — AUTOMATISATIONS
// ══════════════════════════════════════════════

export const autoValidateMatches = onSchedule(
  {schedule: "0 0 * * *", timeZone: "Europe/Paris", region: "europe-west3"},
  async () => {
    const db = getDb();
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
    const db = getDb();
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
          type: "matchAccepted",
        });
      }
      await batch.commit();
    }
  }
);

export const onMatchCreated = onDocumentCreated(
  {document: "matches/{matchId}", region: "europe-west3"},
  async (event) => {
    const db = getDb();
    const match = event.data?.data();
    if (!match) return;
    if (match.visibility !== "public") return;

    const matchId      = event.params.matchId;
    const organizerId  = match.organizerId as string;
    const matchLat     = match.location?._lat  as number | undefined;
    const matchLng     = match.location?._long as number | undefined;
    const now          = new Date();

    // Cherche les joueurs disponibles avec le bon niveau
    const availSnap = await db.collection("userAvailability")
      .where("isAvailable", "==", true)
      .where("expiresAt",   ">",  admin.firestore.Timestamp.fromDate(now))
      .where("level",       ">=", match.levelMin - 1)
      .where("level",       "<=", match.levelMax + 1)
      .get();

    // Filtre par distance (30 km) si le match a une localisation
    const candidates = availSnap.docs.filter((doc) => {
      if (doc.id === organizerId) return false;
      if (!matchLat || !matchLng) return true; // pas de filtre geo si match sans location
      const loc = doc.data().location;
      if (!loc) return true; // inclus si l'user n'a pas de location
      const dist = haversineKm(matchLat, matchLng, loc._lat as number, loc._long as number);
      return dist <= 30;
    });

    let notifiedCount = 0;
    const notifications = candidates.map(async (doc) => {
      await sendNotification(doc.id, {
        title: "Nouveau match près de toi ! 🎾",
        body:  `${match.club} · Niveau ${match.levelMin}-${match.levelMax}`,
        type:  "matchInvites",
        data:  {matchId},
      });
      notifiedCount++;
    });
    await Promise.allSettled(notifications);

    // Enregistre le nombre de joueurs notifiés pour affichage dans l'app
    if (notifiedCount > 0) {
      await db.collection("matches").doc(matchId).update({
        notifiedCount: notifiedCount,
      });
    }
  }
);

// ─── MATCHMAKING CALLABLES ────────────────────────────────────────

/** Définit la disponibilité de l'utilisateur courant. */
export const setUserAvailability = onCall(
  {region: "europe-west3"},
  async (req: CallableRequest) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Login required");

    const {available, hours = 24} = req.data as {available: boolean; hours?: number};
    const db = getDb();

    const expiresAt = new Date(Date.now() + hours * 3600 * 1000);
    await db.collection("userAvailability").doc(uid).set({
      isAvailable: available,
      expiresAt:   admin.firestore.Timestamp.fromDate(expiresAt),
      updatedAt:   admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    return {success: true};
  }
);

/** Retourne les top 10 joueurs les mieux scorés pour un match donné. */
export const getMatchSuggestions = onCall(
  {region: "europe-west3"},
  async (req: CallableRequest) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Login required");

    const {matchId} = req.data as {matchId: string};
    const db = getDb();

    const matchDoc = await db.collection("matches").doc(matchId).get();
    if (!matchDoc.exists) throw new HttpsError("not-found", "Match not found");
    const match = matchDoc.data()!;

    const matchLat = match.location?._lat  as number | undefined;
    const matchLng = match.location?._long as number | undefined;
    const now      = new Date();

    // Joueurs disponibles du bon niveau
    const availSnap = await db.collection("userAvailability")
      .where("isAvailable", "==", true)
      .where("expiresAt",   ">",  admin.firestore.Timestamp.fromDate(now))
      .where("level",       ">=", match.levelMin - 1)
      .where("level",       "<=", match.levelMax + 1)
      .get();

    // Exclut les joueurs déjà dans le match
    const playerIds: string[] = match.playerIds || [];
    const alreadyIn = new Set(playerIds);

    const scored = availSnap.docs
      .filter((d) => !alreadyIn.has(d.id))
      .map((d) => {
        const data = d.data();
        let score = 0;

        // Level score (0–50)
        const level = data.level as number;
        if (level >= match.levelMin && level <= match.levelMax) score += 50;
        else score += 25; // niveau adjacent

        // Distance score (0–30)
        const loc = data.location;
        if (loc && matchLat && matchLng) {
          const dist = haversineKm(matchLat, matchLng, loc._lat as number, loc._long as number);
          if (dist < 3)       score += 30;
          else if (dist < 10) score += 20;
          else if (dist < 20) score += 10;
          else if (dist < 30) score += 5;
        }

        // Availability bonus (20)
        score += 20;

        return {uid: d.id, score};
      })
      .sort((a, b) => b.score - a.score)
      .slice(0, 10);

    // Récupère les profils des joueurs suggérés
    const profiles = await Promise.all(
      scored.map(async ({uid: suggestedUid, score}) => {
        const userDoc = await db.collection("users").doc(suggestedUid).get();
        const u = userDoc.data() || {};
        return {
          uid:       suggestedUid,
          firstName: u.firstName || "",
          lastName:  u.lastName  || "",
          level:     u.level     || 1,
          photoUrl:  u.photoUrl  || null,
          score,
        };
      })
    );

    return {suggestions: profiles};
  }
);

/** Invite un joueur spécifique à rejoindre un match. */
export const invitePlayerToMatch = onCall(
  {region: "europe-west3"},
  async (req: CallableRequest) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Login required");

    const {matchId, invitedUid} = req.data as {matchId: string; invitedUid: string};
    const db = getDb();

    const matchDoc = await db.collection("matches").doc(matchId).get();
    if (!matchDoc.exists) throw new HttpsError("not-found", "Match not found");
    const match = matchDoc.data()!;

    if (match.organizerId !== uid) {
      throw new HttpsError("permission-denied", "Only organizer can invite");
    }

    // Crée l'invitation
    await db.collection("matchInvitations").add({
      matchId,
      fromUid:   uid,
      toUid:     invitedUid,
      status:    "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Notifie le joueur invité
    const organizerDoc = await db.collection("users").doc(uid).get();
    const organizer    = organizerDoc.data() || {};
    const firstName    = organizer.firstName || "Un joueur";

    await sendNotification(invitedUid, {
      title: "Tu as été invité ! 🎾",
      body:  `${firstName} t'invite à rejoindre un match à ${match.club}`,
      type:  "matchInvites",
      data:  {matchId, action: "invitation"},
    });

    return {success: true};
  }
);

// ─── Haversine ────────────────────────────────────────────────────
function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R  = 6371;
  const dL = (lat2 - lat1) * Math.PI / 180;
  const dG = (lng2 - lng1) * Math.PI / 180;
  const a  = Math.sin(dL / 2) ** 2 +
             Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
             Math.sin(dG / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export const onMatchCancelled = onDocumentUpdated(
  {document: "matches/{matchId}", region: "europe-west3"},
  async (event) => {
    const db = getDb();
    const before = event.data?.before.data();
    const after  = event.data?.after.data();
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
      batch.update(userRef, {credits: admin.firestore.FieldValue.increment(1)});
      batch.set(db.collection("creditTransactions").doc(), {
        userId: uid, type: "refund", amount: 1,
        balanceBefore: credits, balanceAfter: credits + 1,
        refId: event.params.matchId,
        description: "Remboursement : match annulé",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      await sendNotification(uid, {
        title: "Match annulé 😔",
        body: `Le match à ${after.club} a été annulé. 1 crédit remboursé.`,
        type: "matchCancelled",
      });
    }
    await batch.commit();
  }
);

export const onMatchFinished = onDocumentUpdated(
  {document: "matches/{matchId}", region: "europe-west3"},
  async (event) => {
    const before = event.data?.before.data();
    const after  = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return;
    if (after.status !== "finished") return;
    const playerIds: string[] = after.playerIds || [];
    const notifications = playerIds.map((uid) =>
      sendNotification(uid, {
        title: "Match terminé ! Laisse un avis 🌟",
        body: `+1 crédit offert pour ton avis sur le match à ${after.club}`,
        type: "matchReview",
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
    const after  = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return;
    const organizerId = after.organizerId;
    const isApproved  = after.status === "published";
    await sendNotification(organizerId, {
      title: isApproved ? "Tournoi approuvé ! 🏆" : "Tournoi refusé",
      body: isApproved
        ? `Ton tournoi "${after.title}" est maintenant visible.`
        : `Ton tournoi "${after.title}" n'a pas été approuvé.`,
      type: "tournaments",
    });
  }
);

// ── Helpers ELO ──────────────────────────────────────────────────

/**
 * Calcule le nouvel ELO après un match.
 * Pour un match en équipe, on passe l'ELO moyen de l'équipe adverse.
 */
function newElo(myElo: number, opponentAvgElo: number, won: boolean, k = 32): number {
  const expected = 1 / (1 + Math.pow(10, (opponentAvgElo - myElo) / 400));
  const actual   = won ? 1 : 0;
  return Math.round(myElo + k * (actual - expected));
}

/**
 * Parse un score "6-3 7-5" ou "6-3 / 7-5" → [[6,3],[7,5]]
 */
function parseSets(score: string): [number, number][] {
  return score.split(/[\s/]+/).map((s) => {
    const parts = s.split("-").map(Number);
    return [parts[0] || 0, parts[1] || 0] as [number, number];
  });
}

/**
 * Compte les sets gagnés pour chaque équipe à partir des sets parsés.
 * L'équipe 1 joue avec les scores à gauche (team1Score-team2Score).
 */
function countSetsWon(sets: [number, number][]): [number, number] {
  let t1 = 0; let t2 = 0;
  for (const [a, b] of sets) {
    if (a > b) t1++; else if (b > a) t2++;
  }
  return [t1, t2];
}

export const updateStatsOnMatchFinish = onDocumentUpdated(
  {document: "matches/{matchId}", region: "europe-west3"},
  async (event) => {
    const db     = getDb();
    const before = event.data?.before.data();
    const after  = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return;
    if (after.status !== "finished") return;
    if (!after.score) return;

    const matchType: string  = after.type || "leisure";
    const duration: number   = after.durationMinutes || 90;
    const winnerTeam: number = after.winnerTeam || 1;
    const team1Ids: string[] = after.team1Ids || [];
    const team2Ids: string[] = after.team2Ids || [];
    const allIds             = [...team1Ids, ...team2Ids];
    if (allIds.length === 0) return;

    // Points selon le type de match
    const winPoints  = matchType === "competitive" ? 10 : 5;
    const lossPoints = 2;

    // Parser le score
    const sets          = parseSets(after.score as string);
    const [t1Sets, t2Sets] = countSetsWon(sets);
    const setsForTeam   = (teamIdx: 1 | 2) => teamIdx === 1 ? [t1Sets, t2Sets] : [t2Sets, t1Sets];

    // Récupérer les ELO actuels de tous les joueurs
    const statsSnaps = await Promise.all(allIds.map((uid) => db.collection("userStats").doc(uid).get()));
    const eloMap: Record<string, number> = {};
    for (const snap of statsSnaps) {
      eloMap[snap.id] = (snap.data()?.eloRating as number | undefined) ?? 1200;
    }

    const team1AvgElo = team1Ids.length
      ? team1Ids.reduce((s, uid) => s + eloMap[uid], 0) / team1Ids.length
      : 1200;
    const team2AvgElo = team2Ids.length
      ? team2Ids.reduce((s, uid) => s + eloMap[uid], 0) / team2Ids.length
      : 1200;

    // Récupérer les niveaux moyens des adversaires pour avgOpponentLevel
    const userSnaps = await Promise.all(allIds.map((uid) => db.collection("users").doc(uid).get()));
    const levelMap: Record<string, number> = {};
    for (const snap of userSnaps) {
      levelMap[snap.id] = (snap.data()?.level as number | undefined) ?? 1;
    }
    const team1AvgLevel = team1Ids.length
      ? team1Ids.reduce((s, uid) => s + (levelMap[uid] || 1), 0) / team1Ids.length : 1;
    const team2AvgLevel = team2Ids.length
      ? team2Ids.reduce((s, uid) => s + (levelMap[uid] || 1), 0) / team2Ids.length : 1;

    const batch = db.batch();

    const processTeam = async (teamIds: string[], teamIdx: 1 | 2) => {
      const won       = winnerTeam === teamIdx;
      const oppAvgElo = teamIdx === 1 ? team2AvgElo : team1AvgElo;
      const oppAvgLvl = teamIdx === 1 ? team2AvgLevel : team1AvgLevel;
      const [mySets, oppSets] = setsForTeam(teamIdx);

      for (const uid of teamIds) {
        const myElo   = eloMap[uid] ?? 1200;
        const newEloV = newElo(myElo, oppAvgElo, won);
        const pts     = won ? winPoints : lossPoints;

        // Calcul de la nouvelle moyenne de niveau adversaire (rolling average)
        const curSnap  = statsSnaps.find((s) => s.id === uid);
        const curData  = curSnap?.data() ?? {};
        const curPlayed  = (curData.matchesPlayed as number | undefined) ?? 0;
        const curAvgOpp  = (curData.avgOpponentLevel as number | undefined) ?? 0;
        const newAvgOpp  = curPlayed === 0
          ? oppAvgLvl
          : (curAvgOpp * curPlayed + oppAvgLvl) / (curPlayed + 1);

        const curStreak = (curData.currentStreak as number | undefined) ?? 0;
        const curBest   = (curData.bestStreak as number | undefined) ?? 0;
        const newStreak = won ? curStreak + 1 : 0;
        const newBest   = Math.max(curBest, newStreak);

        const statsRef = db.collection("userStats").doc(uid);
        batch.set(statsRef, {
          matchesPlayed:    admin.firestore.FieldValue.increment(1),
          matchesWon:       admin.firestore.FieldValue.increment(won ? 1 : 0),
          matchesLost:      admin.firestore.FieldValue.increment(won ? 0 : 1),
          minutesPlayed:    admin.firestore.FieldValue.increment(duration),
          setsWon:          admin.firestore.FieldValue.increment(mySets),
          setsLost:         admin.firestore.FieldValue.increment(oppSets),
          avgOpponentLevel: newAvgOpp,
          eloRating:        newEloV,
          rankingPoints:    admin.firestore.FieldValue.increment(pts),
          weeklyPoints:     admin.firestore.FieldValue.increment(pts),
          currentStreak:    newStreak,
          bestStreak:       newBest,
        }, {merge: true});

        // Mise à jour du ranking public
        const rankingRef = db.collection("rankings").doc(uid);
        const userData   = userSnaps.find((s) => s.id === uid)?.data() ?? {};
        const newPlayed  = curPlayed + 1;
        const newWon     = ((curData.matchesWon as number | undefined) ?? 0) + (won ? 1 : 0);
        batch.set(rankingRef, {
          uid,
          firstName:     userData.firstName ?? "",
          lastName:      userData.lastName ?? "",
          photoUrl:      userData.photoUrl ?? null,
          level:         userData.level ?? 1,
          city:          userData.city ?? null,
          fftRank:       userData.fftRank ?? null,
          location:      userData.lastKnownLocation ?? null,
          eloRating:     newEloV,
          rankingPoints: admin.firestore.FieldValue.increment(pts),
          weeklyPoints:  admin.firestore.FieldValue.increment(pts),
          matchesPlayed: newPlayed,
          matchesWon:    newWon,
          winRate:       newPlayed > 0 ? newWon / newPlayed : 0,
          currentStreak: newStreak,
          bestStreak:    newBest,
          updatedAt:     admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      }
    };

    await processTeam(team1Ids, 1);
    await processTeam(team2Ids, 2);
    await batch.commit();

    console.log(`Stats + ELO mis à jour pour le match ${event.params.matchId}`);
  }
);

// ── Calcul des positions dans le classement (quotidien) ──────────

export const computeRankPositions = onSchedule(
  {schedule: "30 6 * * *", timeZone: "Europe/Paris", region: "europe-west3"},
  async () => {
    const db   = getDb();
    const snap = await db.collection("rankings").orderBy("eloRating", "desc").get();

    const batchSize = 400;
    let batch       = db.batch();
    let count       = 0;

    for (let i = 0; i < snap.docs.length; i++) {
      batch.update(snap.docs[i].ref, {rankPosition: i + 1});
      count++;
      if (count >= batchSize) {
        await batch.commit();
        batch = db.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();

    console.log(`Positions classement recalculées pour ${snap.size} joueurs`);
  }
);

// ── Reset hebdomadaire des weeklyPoints (chaque lundi 00h01) ─────

export const resetWeeklyPoints = onSchedule(
  {schedule: "1 0 * * 1", timeZone: "Europe/Paris", region: "europe-west3"},
  async () => {
    const db   = getDb();
    const snap = await db.collection("rankings").get();

    const batchSize = 400;
    let batch       = db.batch();
    let count       = 0;

    for (const doc of snap.docs) {
      batch.update(doc.ref, {weeklyPoints: 0});
      db.collection("userStats").doc(doc.id);
      batch.update(db.collection("userStats").doc(doc.id), {weeklyPoints: 0});
      count += 2;
      if (count >= batchSize) {
        await batch.commit();
        batch = db.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();
    console.log(`weeklyPoints remis à zéro pour ${snap.size} joueurs`);
  }
);

// ══════════════════════════════════════════════
//  SEED — CLUBS PARTENAIRES (à appeler une seule fois)
// ══════════════════════════════════════════════

const CLUBS_DATA = [
  {
    name: "Padel Station Paris 15",
    address: "120 avenue Félix Faure",
    city: "Paris",
    location: {latitude: 48.8397, longitude: 2.2937},
    phoneNumber: "+33 1 45 57 00 15",
    website: "https://padelstationparis15.fr",
    amenities: ["Parking", "Vestiaires", "Douches", "Bar", "Pro shop"],
    isActive: true,
    pricePerSlotCredits: 6,
    slotDurationMinutes: 90,
    openingHours: {
      monday: "08:00-23:00", tuesday: "08:00-23:00", wednesday: "08:00-23:00",
      thursday: "08:00-23:00", friday: "08:00-23:00",
      saturday: "08:00-22:00", sunday: "09:00-21:00",
    },
    courts: [
      {name: "Court 1", surface: "Gazon synthétique", isIndoor: true,  isActive: true},
      {name: "Court 2", surface: "Gazon synthétique", isIndoor: true,  isActive: true},
      {name: "Court 3", surface: "Gazon synthétique", isIndoor: false, isActive: true},
      {name: "Court 4", surface: "Gazon synthétique", isIndoor: false, isActive: true},
    ],
  },
  {
    name: "Club Padel Boulogne",
    address: "35 rue de Billancourt",
    city: "Boulogne-Billancourt",
    location: {latitude: 48.8379, longitude: 2.2390},
    phoneNumber: "+33 1 46 08 12 35",
    website: "https://clubpadelboulogne.fr",
    amenities: ["Parking", "Vestiaires", "Douches", "Cafétéria"],
    isActive: true,
    pricePerSlotCredits: 5,
    slotDurationMinutes: 90,
    openingHours: {
      monday: "09:00-22:00", tuesday: "09:00-22:00", wednesday: "09:00-22:00",
      thursday: "09:00-22:00", friday: "09:00-22:00",
      saturday: "09:00-21:00", sunday: "10:00-20:00",
    },
    courts: [
      {name: "Court A", surface: "Gazon synthétique", isIndoor: true,  isActive: true},
      {name: "Court B", surface: "Gazon synthétique", isIndoor: true,  isActive: true},
      {name: "Court C", surface: "Béton poreux",      isIndoor: false, isActive: true},
    ],
  },
  {
    name: "Padel Indoor Vincennes",
    address: "8 avenue de Paris",
    city: "Vincennes",
    location: {latitude: 48.8479, longitude: 2.4386},
    phoneNumber: "+33 1 43 28 55 08",
    website: "https://padelindoorvincennes.fr",
    amenities: ["Parking gratuit", "Vestiaires", "Douches", "Distributeur", "Location raquettes"],
    isActive: true,
    pricePerSlotCredits: 4,
    slotDurationMinutes: 60,
    openingHours: {
      monday: "07:00-23:00", tuesday: "07:00-23:00", wednesday: "07:00-23:00",
      thursday: "07:00-23:00", friday: "07:00-23:00",
      saturday: "08:00-22:00", sunday: "09:00-21:00",
    },
    courts: [
      {name: "Court 1", surface: "Moquette acrylique", isIndoor: true, isActive: true},
      {name: "Court 2", surface: "Moquette acrylique", isIndoor: true, isActive: true},
    ],
  },
  {
    name: "Urban Padel Levallois",
    address: "22 rue Anatole France",
    city: "Levallois-Perret",
    location: {latitude: 48.8969, longitude: 2.2853},
    phoneNumber: "+33 1 47 57 30 22",
    website: "https://urbanpadellevallois.fr",
    amenities: ["Parking", "Vestiaires", "Bar sportif", "Cours collectifs"],
    isActive: true,
    pricePerSlotCredits: 7,
    slotDurationMinutes: 90,
    openingHours: {
      monday: "08:00-22:30", tuesday: "08:00-22:30", wednesday: "08:00-22:30",
      thursday: "08:00-22:30", friday: "08:00-22:30",
      saturday: "09:00-21:00", sunday: "09:00-20:00",
    },
    courts: [
      {name: "Court 1 — Panorama", surface: "Gazon synthétique", isIndoor: true,  isActive: true},
      {name: "Court 2 — Panorama", surface: "Gazon synthétique", isIndoor: true,  isActive: true},
      {name: "Court Terrasse",     surface: "Gazon synthétique", isIndoor: false, isActive: true},
    ],
  },
];

export const seedClubs = onCall(
  {region: "europe-west3"},
  async (request) => {
    assertAdmin(request);
    const db = getDb();

    let clubsCreated  = 0;
    let courtsCreated = 0;

    for (const club of CLUBS_DATA) {
      const {courts, location, ...clubData} = club;
      const clubRef = db.collection("clubs").doc();

      await clubRef.set({
        ...clubData,
        location: new admin.firestore.GeoPoint(location.latitude, location.longitude),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      clubsCreated++;

      for (const court of courts) {
        await clubRef.collection("courts").add({
          ...court,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        courtsCreated++;
      }
    }

    return {success: true, clubsCreated, courtsCreated};
  }
);

// ══════════════════════════════════════════════
//  USER LIFECYCLE
// ══════════════════════════════════════════════

/** Crée la transaction de crédits d'inscription quand le doc user est créé côté client.
 *  (Le client ne peut pas écrire dans creditTransactions directement.) */
export const onUserCreated = onDocumentCreated(
  {document: "users/{uid}", region: "europe-west3"},
  async (event) => {
    const db = getDb();
    const uid = event.params.uid;
    const data = event.data?.data();
    if (!data) return;
    await db.collection("creditTransactions").add({
      userId:        uid,
      type:          "registration",
      amount:        10,
      balanceBefore: 0,
      balanceAfter:  10,
      description:   "Crédits offerts à l'inscription",
      createdAt:     admin.firestore.FieldValue.serverTimestamp(),
    });
  }
);

// ══════════════════════════════════════════════
//  ADMIN — RÔLES ET OPÉRATIONS SÉCURISÉES
// ══════════════════════════════════════════════

function assertAdmin(request: CallableRequest) {
  if (!request.auth) throw new HttpsError("unauthenticated", "Non authentifié");
  if (!request.auth.token.admin) throw new HttpsError("permission-denied", "Accès refusé : rôle admin requis");
}

/** Attribue ou retire le rôle admin (custom claim).
 *  Seul un admin existant peut appeler cette fonction.
 *  Le premier admin doit être défini manuellement via Firebase Admin SDK ou la console. */
export const setAdminClaim = onCall(
  {region: "europe-west3"},
  async (request) => {
    assertAdmin(request);
    const {uid, isAdmin} = request.data as {uid: string; isAdmin: boolean};
    if (!uid) throw new HttpsError("invalid-argument", "uid requis");
    await admin.auth().setCustomUserClaims(uid, {admin: isAdmin ?? true});
    return {success: true};
  }
);

export const adminBanUser = onCall(
  {region: "europe-west3"},
  async (request) => {
    assertAdmin(request);
    const {uid, ban} = request.data as {uid: string; ban: boolean};
    if (!uid) throw new HttpsError("invalid-argument", "uid requis");
    const db = getDb();
    await db.collection("users").doc(uid).update({status: ban ? "banned" : "active"});
    return {success: true};
  }
);

export const adminAddCredits = onCall(
  {region: "europe-west3"},
  async (request) => {
    assertAdmin(request);
    const {uid, amount, description} = request.data as {uid: string; amount: number; description: string};
    if (!uid || typeof amount !== "number" || amount <= 0) {
      throw new HttpsError("invalid-argument", "uid, amount (>0) et description requis");
    }
    const db = getDb();
    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    const cur = (userDoc.data()?.credits as number) ?? 0;
    const batch = db.batch();
    batch.update(userRef, {credits: admin.firestore.FieldValue.increment(amount)});
    batch.set(db.collection("creditTransactions").doc(), {
      userId:        uid,
      type:          "concours",
      amount,
      balanceBefore: cur,
      balanceAfter:  cur + amount,
      description:   description || "Ajout admin",
      createdAt:     admin.firestore.FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return {success: true};
  }
);

export const adminUpdateTournamentStatus = onCall(
  {region: "europe-west3"},
  async (request) => {
    assertAdmin(request);
    const {tournamentId, status} = request.data as {tournamentId: string; status: string};
    const allowed = ["pending", "published", "refused"];
    if (!tournamentId || !allowed.includes(status)) {
      throw new HttpsError("invalid-argument", "tournamentId et status valide requis");
    }
    const db = getDb();
    await db.collection("tournaments").doc(tournamentId).update({status});
    return {success: true};
  }
);

export const adminUpdateRegistrationStatus = onCall(
  {region: "europe-west3"},
  async (request) => {
    assertAdmin(request);
    const {registrationId, status} = request.data as {registrationId: string; status: string};
    const allowed = ["pending", "accepted", "refused"];
    if (!registrationId || !allowed.includes(status)) {
      throw new HttpsError("invalid-argument", "registrationId et status valide requis");
    }
    const db = getDb();
    await db.collection("tournamentRegistrations").doc(registrationId).update({status});
    return {success: true};
  }
);

export const adminUpdateCoachStatus = onCall(
  {region: "europe-west3"},
  async (request) => {
    assertAdmin(request);
    const {coachId, isActive} = request.data as {coachId: string; isActive: boolean};
    if (!coachId || typeof isActive !== "boolean") {
      throw new HttpsError("invalid-argument", "coachId et isActive requis");
    }
    const db = getDb();
    await db.collection("coaches").doc(coachId).update({isActive});
    return {success: true};
  }
);

// ══════════════════════════════════════════════
//  RÉSERVATION TERRAIN — BOOKING ATOMIQUE
// ══════════════════════════════════════════════

export const bookCourtSlot = onCall(
  {region: "europe-west3"},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Non authentifié");

    const {clubId, clubName, courtId, courtName, startTime, durationMinutes, priceCredits} =
      request.data as {
        clubId: string; clubName: string;
        courtId: string; courtName: string;
        startTime: string;
        durationMinutes: number;
        priceCredits: number;
      };

    const db  = getDb();
    const uid = request.auth.uid;

    const start  = new Date(startTime);
    const end    = new Date(start.getTime() + durationMinutes * 60 * 1000);

    const reservationId = await db.runTransaction(async (tx) => {
      // ── Vérification de conflit ──────────────────────────────
      const conflictSnap = await db.collection("reservations")
        .where("courtId", "==", courtId)
        .where("status", "==", "confirmed")
        .where("startTime", "<", admin.firestore.Timestamp.fromDate(end))
        .get();

      const hasConflict = conflictSnap.docs.some((doc) => {
        const data = doc.data();
        const existingEnd = new Date(
          data.startTime.toDate().getTime() + data.durationMinutes * 60 * 1000
        );
        return existingEnd > start;
      });

      if (hasConflict) {
        throw new HttpsError("already-exists", "Ce créneau est déjà réservé");
      }

      // ── Vérification des crédits ─────────────────────────────
      const userRef = db.collection("users").doc(uid);
      const userDoc = await tx.get(userRef);
      const credits = userDoc.data()?.credits as number ?? 0;

      if (credits < priceCredits) {
        throw new HttpsError("failed-precondition", "Crédits insuffisants");
      }

      // ── Débit et création de la réservation ──────────────────
      const resRef = db.collection("reservations").doc();
      tx.set(resRef, {
        userId:          uid,
        clubId, clubName, courtId, courtName,
        startTime:       admin.firestore.Timestamp.fromDate(start),
        durationMinutes,
        priceCredits,
        status:          "confirmed",
        matchId:         null,
        createdAt:       admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.update(userRef, {credits: admin.firestore.FieldValue.increment(-priceCredits)});

      tx.set(db.collection("creditTransactions").doc(), {
        userId:        uid,
        type:          "courtBooking",
        amount:        -priceCredits,
        balanceBefore: credits,
        balanceAfter:  credits - priceCredits,
        refId:         resRef.id,
        description:   `Réservation ${courtName} @ ${clubName}`,
        createdAt:     admin.firestore.FieldValue.serverTimestamp(),
      });

      return resRef.id;
    });

    // Notification de confirmation
    await sendNotification(uid, {
      title: "Terrain réservé ! 🎾",
      body:  `${courtName} @ ${clubName} — ${new Date(startTime).toLocaleTimeString("fr-FR", {hour: "2-digit", minute: "2-digit"})}`,
      type:  "courtBooking",
    });

    return {reservationId};
  }
);

// ══════════════════════════════════════════════
//  NOTIFICATIONS MATCHS — ACCEPT / REFUSE
// ══════════════════════════════════════════════

export const notifyPlayerAccepted = onCall(
  {region: "europe-west3"},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Non authentifié");
    const {matchId, playerId} = request.data as {matchId: string; playerId: string};
    const db = getDb();
    const matchDoc = await db.collection("matches").doc(matchId).get();
    const club = matchDoc.data()?.club ?? "?";
    await sendNotification(playerId, {
      title: "Demande acceptée ! 🎾",
      body: `Tu es accepté dans le match à ${club}`,
      type: "matchAccepted",
      data: {matchId},
    });
    return {success: true};
  }
);

export const notifyPlayerRefused = onCall(
  {region: "europe-west3"},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Non authentifié");
    const {matchId, playerId} = request.data as {matchId: string; playerId: string};
    const db = getDb();
    const matchDoc = await db.collection("matches").doc(matchId).get();
    const club = matchDoc.data()?.club ?? "?";
    await sendNotification(playerId, {
      title: "Demande refusée",
      body: `Ta demande pour le match à ${club} a été refusée. 1 crédit remboursé.`,
      type: "matchAccepted",
      data: {matchId},
    });
    return {success: true};
  }
);

// ── Helpers ──────────────────────────────────────────────────────

/**
 * Vérifie un receipt Apple via l'API App Store.
 * Essaie d'abord la production, puis le sandbox (status 21007).
 * Doc : https://developer.apple.com/documentation/appstorereceipts/verifyreceipt
 */
async function verifyAppleReceipt(receiptData: string, sharedSecret: string): Promise<boolean> {
  const payload = {"receipt-data": receiptData, password: sharedSecret};

  const tryVerify = async (url: string): Promise<{status: number}> => {
    const res = await fetch(url, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(payload),
    });
    return res.json() as Promise<{status: number}>;
  };

  let result = await tryVerify("https://buy.itunes.apple.com/verifyReceipt");
  // 21007 = receipt sandbox soumis à la production → réessayer avec sandbox
  if (result.status === 21007) {
    result = await tryVerify("https://sandbox.itunes.apple.com/verifyReceipt");
  }

  if (result.status !== 0) {
    console.error(`Apple receipt invalid, status: ${result.status}`);
    return false;
  }
  return true;
}

/**
 * Vérifie un achat Google Play via l'API Android Publisher.
 * Prérequis : le compte de service Firebase doit avoir le rôle
 * "Lecteur de données financières" dans Google Play Console.
 * Doc : https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.products/get
 */
async function verifyGooglePurchase(productId: string, purchaseToken: string): Promise<boolean> {
  try {
    const auth = new google.auth.GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });
    const publisher = google.androidpublisher({version: "v3", auth});
    const result = await publisher.purchases.products.get({
      packageName: ANDROID_PACKAGE_NAME,
      productId,
      token: purchaseToken,
    });
    // purchaseState : 0 = acheté, 1 = annulé, 2 = en attente
    if (result.data.purchaseState !== 0) {
      console.error(`Google purchase invalid, state: ${result.data.purchaseState}`);
      return false;
    }
    return true;
  } catch (e) {
    console.error("Google Play verification error:", e);
    return false;
  }
}

// ══════════════════════════════════════════════
//  SYNCHRONISATION CLASSEMENTS FFT
// ══════════════════════════════════════════════

/**
 * Appelle l'API FFT pour récupérer le classement padel numérique d'un licencié.
 * Retourne le rang national (ex: "1 542") ou null si indisponible.
 */
async function fetchFftRanking(licence: string): Promise<string | null> {
  const url = `https://www.fft.fr/backend/api/classements/search?licence=${encodeURIComponent(licence)}`;
  const res = await fetch(url, {
    headers: {
      Accept: "application/json",
      "User-Agent": "Zupadel/1.0 (contact@zupadel.fr)",
    },
  });
  if (!res.ok) return null;
  const data = await res.json() as Record<string, unknown>;

  // Chercher le rang numérique national en priorité
  const position =
    data?.rangNational ??
    data?.rang ??
    data?.position ??
    data?.classementNational ??
    data?.rankPadel ??
    data?.rank;

  if (position != null) {
    // Formater en nombre français avec espace comme séparateur de milliers (1 542)
    const num = Number(position);
    if (!isNaN(num) && num > 0) {
      return num.toLocaleString("fr-FR");
    }
  }

  // Fallback : série (P100, P250…) si pas de rang numérique disponible
  const serie =
    data?.classementPadel ??
    data?.seriePadel ??
    data?.classementSimple ??
    data?.classement;

  return serie != null ? String(serie) : null;
}

/**
 * Tâche planifiée : met à jour le classement FFT de tous les joueurs
 * ayant une licence FFT enregistrée. S'exécute chaque jour à 6h (Paris).
 */
export const syncFftRankings = onSchedule(
  {schedule: "0 6 * * *", timeZone: "Europe/Paris", region: "europe-west3"},
  async () => {
    const db = getDb();
    const snap = await db.collection("users")
      .where("fftLicense", "!=", null)
      .get();

    let updated = 0;
    let failed  = 0;

    for (const docSnap of snap.docs) {
      const licence = docSnap.data().fftLicense as string | undefined;
      if (!licence) continue;

      // Pause 300ms entre chaque appel pour ne pas surcharger l'API FFT
      await new Promise((r) => setTimeout(r, 300));

      try {
        const rank = await fetchFftRanking(licence);
        if (rank) {
          await docSnap.ref.update({
            fftRank: rank,
            fftRankUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          updated++;
        }
      } catch (e) {
        console.warn(`FFT sync échoué pour ${docSnap.id} (licence ${licence}):`, e);
        failed++;
      }
    }

    console.log(`FFT rankings sync terminé : ${updated} mis à jour, ${failed} erreurs, ${snap.size} total`);
  }
);

// ══════════════════════════════════════════════
//  NOTIFICATIONS MESSAGES (trigger Firestore)
// ══════════════════════════════════════════════

export const onNewMessage = onDocumentCreated(
  {document: "conversations/{convId}/messages/{msgId}", region: "europe-west3"},
  async (event) => {
    const data = event.data?.data();
    if (!data || data.type === "system") return;

    const db       = getDb();
    const convId   = event.params.convId;
    const senderId = data.senderId as string;
    const text     = (data.text as string | undefined) ?? "";

    const convDoc = await db.collection("conversations").doc(convId).get();
    if (!convDoc.exists) return;

    const participantIds = (convDoc.data()?.participantIds as string[]) ?? [];
    const matchClub      = convDoc.data()?.matchClub as string | undefined;

    const senderDoc = await db.collection("users").doc(senderId).get();
    const firstName = (senderDoc.data()?.firstName as string | undefined) ?? "Quelqu'un";

    const title = matchClub ? `${firstName} · ${matchClub}` : firstName;
    const body  = text.length > 100 ? `${text.substring(0, 97)}…` : text;

    await Promise.all(
      participantIds
        .filter((uid) => uid !== senderId)
        .map((uid) => sendNotification(uid, {
          title,
          body,
          type: "messages",
          data: {convId, senderId},
        }))
    );
  }
);

// ── Helper notifications (respecte les préférences utilisateur) ───

async function sendNotification(
  uid: string,
  payload: {title: string; body: string; data?: Record<string, string>; type?: string}
) {
  const db = getDb();
  try {
    const userDoc  = await db.collection("users").doc(uid).get();
    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken as string | undefined;
    if (!fcmToken) return;

    // Vérifier les préférences de l'utilisateur
    if (payload.type) {
      const prefs = userData?.notifPrefs as Record<string, boolean> | undefined;
      if (prefs && prefs[payload.type] === false) {
        console.log(`Notif '${payload.type}' désactivée pour ${uid} — ignorée`);
        return;
      }
    }

    await admin.messaging().send({
      token: fcmToken,
      notification: {title: payload.title, body: payload.body},
      data: payload.data ?? {},
    });
  } catch (e) {
    console.error(`Erreur notification pour ${uid}:`, e);
  }
}
