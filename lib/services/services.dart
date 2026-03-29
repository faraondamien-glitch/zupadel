import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../models/models.dart';

// ══════════════════════════════════════════════
//  AUTH SERVICE
// ══════════════════════════════════════════════

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> registerWithEmail(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) =>
    ref.watch(authServiceProvider).authStateChanges);

// ══════════════════════════════════════════════
//  USER SERVICE
// ══════════════════════════════════════════════

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<ZuUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return ZuUser.fromFirestore(doc);
  }

  Stream<ZuUser?> watchUser(String uid) => _db.collection('users').doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? ZuUser.fromFirestore(doc) : null);

  Future<void> createUser({
    required String uid,
    required String email,
    required String firstName,
    required String lastName,
    String? referralCode,
  }) async {
    final code = _generateCode(firstName);
    final batch = _db.batch();
    final userRef = _db.collection('users').doc(uid);

    batch.set(userRef, {
      'firstName':     firstName,
      'lastName':      lastName,
      'email':         email,
      'level':         1,
      'credits':       10, // C1 : crédits offerts à l'inscription
      'referralCode':  code,
      'referralCount': 0,
      'createdAt':     FieldValue.serverTimestamp(),
    });

    // Credit transaction C1
    batch.set(_db.collection('creditTransactions').doc(), {
      'userId':        uid,
      'type':          'registration',
      'amount':        10,
      'balanceBefore': 0,
      'balanceAfter':  10,
      'description':   'Crédits offerts à l\'inscription',
      'createdAt':     FieldValue.serverTimestamp(),
    });

    // Parrainage
    if (referralCode != null && referralCode.isNotEmpty) {
      await _processReferral(uid, referralCode, batch);
    }

    await batch.commit();
  }

  Future<void> _processReferral(String newUserId, String code, WriteBatch batch) async {
    final q = await _db.collection('users')
        .where('referralCode', isEqualTo: code)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return;

    final parentRef = q.docs.first.reference;
    final parentData = q.docs.first.data();
    final parentCredits = parentData['credits'] as int? ?? 0;

    // +5 crédits au parrain (C3)
    batch.update(parentRef, {
      'credits': FieldValue.increment(5),
      'referralCount': FieldValue.increment(1),
    });
    batch.set(_db.collection('creditTransactions').doc(), {
      'userId':        q.docs.first.id,
      'type':          'referral',
      'amount':        5,
      'balanceBefore': parentCredits,
      'balanceAfter':  parentCredits + 5,
      'description':   'Parrainage accepté',
      'createdAt':     FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProfile({
    required String uid,
    String? firstName,
    String? lastName,
    int? level,
    String? city,
    String? fftLicense,
    String? fftRank,
    String? photoUrl,
  }) async {
    final data = <String, dynamic>{};
    if (firstName != null)   data['firstName']  = firstName;
    if (lastName != null)    data['lastName']   = lastName;
    if (level != null)       data['level']      = level;
    if (city != null)        data['city']       = city;
    if (fftLicense != null)  data['fftLicense'] = fftLicense;
    if (fftRank != null)     data['fftRank']    = fftRank;
    if (photoUrl != null)    data['photoUrl']   = photoUrl;
    if (data.isEmpty) return;
    await _db.collection('users').doc(uid).update(data);
  }

  String _generateCode(String pseudo) {
    final prefix = pseudo.length >= 3 ? pseudo.substring(0, 3).toUpperCase() : pseudo.toUpperCase();
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(9);
    return 'ZUP-$prefix$suffix';
  }
}

final userServiceProvider = Provider<UserService>((ref) => UserService());

final currentUserProvider = StreamProvider<ZuUser?>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value(null);
  return ref.watch(userServiceProvider).watchUser(auth.uid);
});

// ══════════════════════════════════════════════
//  MATCH SERVICE
// ══════════════════════════════════════════════

class MatchFilter {
  final MatchType? type;
  final bool todayOnly;
  final int? level;

  const MatchFilter({this.type, this.todayOnly = false, this.level});
}

class MatchService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  Future<String> createMatch({
    required String club,
    required DateTime startTime,
    required int duration,
    required int levelMin,
    required int levelMax,
    required int maxPlayers,
    required MatchType type,
    required MatchVisibility visibility,
    String? note,
  }) async {
    final user = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    final firstName = user.data()?['firstName'] ?? user.data()?['pseudo'] ?? 'Joueur';

    final ref = await _db.collection('matches').add({
      'organizerId':     _uid,
      'organizerPseudo': firstName,
      'club':            club,
      'startTime':       Timestamp.fromDate(startTime),
      'durationMinutes': duration,
      'levelMin':        levelMin,
      'levelMax':        levelMax,
      'maxPlayers':      maxPlayers,
      'type':            type.name,
      'visibility':      visibility.name,
      'status':          MatchStatus.open.name,
      'playerIds':       [_uid],
      'pendingIds':      [],
      'note':            note,
      'ratingCount':     0,
      'createdAt':       FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> joinMatch({required String matchId, required bool placeBet}) async {
    final userRef  = _db.collection('users').doc(_uid);
    final matchRef = _db.collection('matches').doc(matchId);
    final cost     = placeBet ? 2 : 1;

    await _db.runTransaction((tx) async {
      final userDoc  = await tx.get(userRef);
      final matchDoc = await tx.get(matchRef);

      final credits = userDoc.data()?['credits'] as int? ?? 0;
      if (credits < cost) throw Exception('Crédits insuffisants');

      final match = ZuMatch.fromFirestore(matchDoc);
      if (match.isFull) throw Exception('Match complet');
      if (match.pendingIds.contains(_uid) || match.playerIds.contains(_uid)) {
        throw Exception('Déjà inscrit ou en attente');
      }

      // Débit D1
      tx.update(userRef, {'credits': FieldValue.increment(-cost)});

      // Ajout en pending
      tx.update(matchRef, {'pendingIds': FieldValue.arrayUnion([_uid])});

      // Log transaction
      tx.set(_db.collection('creditTransactions').doc(), {
        'userId':        _uid,
        'type':          'joinMatch',
        'amount':        -cost,
        'balanceBefore': credits,
        'balanceAfter':  credits - cost,
        'refId':         matchId,
        'description':   'Rejoindre un match',
        'createdAt':     FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> acceptPlayer({required String matchId, required String playerId}) async {
    await _db.collection('matches').doc(matchId).update({
      'pendingIds': FieldValue.arrayRemove([playerId]),
      'playerIds':  FieldValue.arrayUnion([playerId]),
    });
    // TODO: send FCM N3
  }

  Future<void> refusePlayer({required String matchId, required String playerId}) async {
    final matchRef  = _db.collection('matches').doc(matchId);
    final playerRef = _db.collection('users').doc(playerId);

    await _db.runTransaction((tx) async {
      final playerDoc = await tx.get(playerRef);
      final credits   = playerDoc.data()?['credits'] as int? ?? 0;

      // Remboursement 1 crédit
      tx.update(playerRef, {'credits': FieldValue.increment(1)});
      tx.update(matchRef, {'pendingIds': FieldValue.arrayRemove([playerId])});
      tx.set(_db.collection('creditTransactions').doc(), {
        'userId':        playerId,
        'type':          'refund',
        'amount':        1,
        'balanceBefore': credits,
        'balanceAfter':  credits + 1,
        'refId':         matchId,
        'description':   'Remboursement : demande refusée',
        'createdAt':     FieldValue.serverTimestamp(),
      });
    });
    // TODO: send FCM N3
  }

  Future<void> removePlayer({required String matchId, required String playerId}) async {
    await _db.collection('matches').doc(matchId).update({
      'playerIds': FieldValue.arrayRemove([playerId]),
    });
  }

  Future<void> finishMatch({required String matchId}) async {
    await _db.collection('matches').doc(matchId).update({
      'status': MatchStatus.finished.name,
    });
    // TODO: send FCM N4, N5
  }

  Future<void> cancelMatch({required String matchId}) async {
    final matchRef = _db.collection('matches').doc(matchId);
    final matchDoc = await matchRef.get();
    final match = ZuMatch.fromFirestore(matchDoc);

    final batch = _db.batch();
    batch.update(matchRef, {'status': MatchStatus.cancelled.name});

    // Remboursement automatique de tous les joueurs (sauf organisateur)
    for (final pid in match.playerIds) {
      if (pid == match.organizerId) continue;
      final playerRef = _db.collection('users').doc(pid);
      batch.update(playerRef, {'credits': FieldValue.increment(1)});
      batch.set(_db.collection('creditTransactions').doc(), {
        'userId':      pid,
        'type':        'refund',
        'amount':      1,
        'refId':       matchId,
        'description': 'Remboursement : match annulé',
        'createdAt':   FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    // TODO: send FCM N4 à tous les joueurs
  }

  Future<void> leaveReview({
    required String matchId,
    required int stars,
    String? comment,
  }) async {
    final userRef  = _db.collection('users').doc(_uid);
    final matchRef = _db.collection('matches').doc(matchId);
    final batch    = _db.batch();

    // Avis
    batch.set(_db.collection('matchReviews').doc('${matchId}_$_uid'), {
      'matchId':    matchId,
      'reviewerId': _uid,
      'stars':      stars,
      'comment':    comment,
      'createdAt':  FieldValue.serverTimestamp(),
    });

    // +1 crédit C2
    final userDoc = await userRef.get();
    final credits = userDoc.data()?['credits'] as int? ?? 0;
    batch.update(userRef, {'credits': FieldValue.increment(1)});
    batch.set(_db.collection('creditTransactions').doc(), {
      'userId':        _uid,
      'type':          'postMatchReview',
      'amount':        1,
      'balanceBefore': credits,
      'balanceAfter':  credits + 1,
      'refId':         matchId,
      'description':   'Avis post-match laissé',
      'createdAt':     FieldValue.serverTimestamp(),
    });

    // Mise à jour note moyenne du match
    batch.update(matchRef, {
      'ratingCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  Stream<List<ZuMatch>> watchNearbyMatches(String? city) {
    var query = _db.collection('matches')
        .where('status', isEqualTo: MatchStatus.open.name)
        .orderBy('startTime')
        .limit(20);

    return query.snapshots().map(
      (s) => s.docs.map(ZuMatch.fromFirestore).toList(),
    );
  }

  Stream<List<ZuMatch>> watchMyMatches(String uid) {
    return _db.collection('matches')
        .where('playerIds', arrayContains: uid)
        .where('status', whereIn: [MatchStatus.open.name, MatchStatus.ongoing.name])
        .orderBy('startTime')
        .snapshots()
        .map((s) => s.docs.map(ZuMatch.fromFirestore).toList());
  }

  Stream<List<ZuMatch>> watchFilteredMatches(MatchFilter filter) {
    Query<Map<String, dynamic>> query = _db.collection('matches')
        .where('status', isEqualTo: MatchStatus.open.name)
        .orderBy('startTime');

    if (filter.type != null) {
      query = query.where('type', isEqualTo: filter.type!.name);
    }
    if (filter.todayOnly) {
      final start = DateTime.now().copyWith(hour: 0, minute: 0);
      final end   = start.add(const Duration(days: 1));
      query = query
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('startTime', isLessThan: Timestamp.fromDate(end));
    }

    return query.snapshots().map(
      (s) => s.docs.map(ZuMatch.fromFirestore).toList(),
    );
  }

  Stream<ZuMatch?> watchMatch(String matchId) => _db.collection('matches')
      .doc(matchId)
      .snapshots()
      .map((doc) => doc.exists ? ZuMatch.fromFirestore(doc) : null);
}

final matchServiceProvider = Provider<MatchService>((ref) => MatchService());

final nearbyMatchesProvider = StreamProvider<List<ZuMatch>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  return ref.watch(matchServiceProvider).watchNearbyMatches(user?.city);
});

final myUpcomingMatchesProvider = StreamProvider<List<ZuMatch>>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value([]);
  return ref.watch(matchServiceProvider).watchMyMatches(auth.uid);
});

final filteredMatchesProvider = StreamProvider.family<List<ZuMatch>, MatchFilter>((ref, filter) =>
    ref.watch(matchServiceProvider).watchFilteredMatches(filter));

final matchDetailProvider = StreamProvider.family<ZuMatch?, String>((ref, id) =>
    ref.watch(matchServiceProvider).watchMatch(id));

// ══════════════════════════════════════════════
//  TOURNAMENT SERVICE
// ══════════════════════════════════════════════

class TournamentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  Future<void> register({
    required String tournamentId,
    required String fftLicense,
  }) async {
    final tRef = _db.collection('tournaments').doc(tournamentId);
    final t    = await tRef.get();
    final data = t.data()!;
    final entryFee = (data['entryFee'] as num?)?.toDouble() ?? 0;

    if (entryFee > 0) {
      // TODO: Stripe PaymentSheet, webhook pour confirmer
      throw UnimplementedError('Paiement Stripe non configuré');
    }

    await _db.collection('tournamentRegistrations').add({
      'tournamentId': tournamentId,
      'userId':       _uid,
      'fftLicense':   fftLicense,
      'status':       'pending',
      'createdAt':    FieldValue.serverTimestamp(),
    });
    // TODO: send FCM N7 si accepté
  }

  Stream<List<ZuTournament>> watchUpcoming() => _db.collection('tournaments')
      .where('status', isEqualTo: TournamentStatus.published.name)
      .where('startDate', isGreaterThan: Timestamp.now())
      .orderBy('startDate')
      .snapshots()
      .map((s) => s.docs.map(ZuTournament.fromFirestore).toList());

  Stream<ZuTournament?> watchTournament(String id) =>
      _db.collection('tournaments').doc(id)
          .snapshots()
          .map((d) => d.exists ? ZuTournament.fromFirestore(d) : null);
}

final tournamentServiceProvider = Provider<TournamentService>((ref) => TournamentService());

final tournamentsProvider = StreamProvider<List<ZuTournament>>((ref) =>
    ref.watch(tournamentServiceProvider).watchUpcoming());

final upcomingTournamentsProvider = StreamProvider<List<ZuTournament>>((ref) =>
    ref.watch(tournamentServiceProvider).watchUpcoming());

final tournamentDetailProvider = StreamProvider.family<ZuTournament?, String>((ref, id) =>
    ref.watch(tournamentServiceProvider).watchTournament(id));

// ══════════════════════════════════════════════
//  COACH SERVICE
// ══════════════════════════════════════════════

class CoachService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<ZuCoach>> watchCoaches() => _db.collection('coaches')
      .where('isActive', isEqualTo: true)
      .orderBy('avgRating', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ZuCoach.fromFirestore).toList());
}

final coachServiceProvider = Provider<CoachService>((ref) => CoachService());

final coachesProvider = StreamProvider<List<ZuCoach>>((ref) =>
    ref.watch(coachServiceProvider).watchCoaches());

// ══════════════════════════════════════════════
//  CREDIT TRANSACTIONS
// ══════════════════════════════════════════════

final creditTransactionsProvider = StreamProvider<List<CreditTransaction>>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('creditTransactions')
      .where('userId', isEqualTo: auth.uid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(CreditTransaction.fromFirestore).toList());
});

// ══════════════════════════════════════════════
//  PAYMENT SERVICE (Stripe)
// ══════════════════════════════════════════════

class PaymentService {
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west3');

  /// Lance le paiement Stripe pour un pack de crédits.
  /// Lève une [StripeException] si l'utilisateur annule.
  Future<void> buyCredits(String packId) async {
    // 1. Crée le PaymentIntent côté serveur
    final result = await _functions
        .httpsCallable('createPaymentIntent')
        .call({'packId': packId});

    final data         = Map<String, dynamic>.from(result.data as Map);
    final clientSecret = data['clientSecret'] as String;
    final ephemeralKey = data['ephemeralKey'] as String;
    final customerId   = data['customerId'] as String;

    // 2. Initialise le Payment Sheet
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        ephemeralKeySecret:        ephemeralKey,
        customerId:                customerId,
        merchantDisplayName:       'Zupadel',
        style:                     ThemeMode.dark,
        appearance: const PaymentSheetAppearance(
          colors: PaymentSheetAppearanceColors(
            primary: Color(0xFF4EE06E),
            background: Color(0xFF0D0F14),
            componentBackground: Color(0xFF1A1D24),
          ),
        ),
      ),
    );

    // 3. Affiche le Payment Sheet → peut lancer StripeException si annulé
    await Stripe.instance.presentPaymentSheet();
  }
}

final paymentServiceProvider = Provider<PaymentService>((ref) => PaymentService());

// ══════════════════════════════════════════════
//  USER STATS
// ══════════════════════════════════════════════

final userStatsProvider = StreamProvider<UserStats?>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('userStats')
      .doc(auth.uid)
      .snapshots()
      .map((d) => d.exists ? UserStats.fromFirestore(d.data()!) : null);
});
