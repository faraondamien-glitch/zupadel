import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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

  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      return await _auth.signInWithPopup(provider);
    }
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null; // annulé par l'utilisateur
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken:     googleAuth.idToken,
    );
    return await _auth.signInWithCredential(credential);
  }

  /// Sign in with Apple — disponible sur iOS 13+, macOS 10.15+, web.
  /// À appeler uniquement sur les plateformes supportées.
  Future<UserCredential?> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken:     appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    return await _auth.signInWithCredential(oauthCredential);
  }

  /// Vérifie si Apple Sign-In est disponible sur la plateforme courante.
  static bool get isAppleSignInAvailable =>
      kIsWeb || (!kIsWeb && (Platform.isIOS || Platform.isMacOS));
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
    String? photoUrl,
  }) async {
    final code = _generateCode(firstName);
    final batch = _db.batch();
    final userRef = _db.collection('users').doc(uid);

    batch.set(userRef, {
      'firstName':     firstName,
      'lastName':      lastName,
      'email':         email,
      'photoUrl':      photoUrl,
      'level':         1,
      'credits':       10, // C1 : crédits offerts à l'inscription
      'referralCode':  code,
      'referralCount': 0,
      'createdAt':     FieldValue.serverTimestamp(),
    });
    // Note: la transaction creditTransactions de type 'registration' est créée
    // par la Cloud Function onUserCreated (règle Firestore interdit l'écriture client).

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

  /// Télécharge la photo de profil sur Firebase Storage et retourne l'URL publique.
  Future<String> uploadProfilePhoto({required String uid, required XFile image}) async {
    final ref   = FirebaseStorage.instance.ref().child('profile_photos/$uid.jpg');
    final bytes = await image.readAsBytes();
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    await _db.collection('users').doc(uid).update({'photoUrl': url});
    return url;
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

// ══════════════════════════════════════════════
//  LOCATION SERVICE
// ══════════════════════════════════════════════

class LocationService {
  static const double radiusKm = 30.0;

  Future<Position?> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
  }

  static bool withinRadius(GeoPoint point, Position pos) {
    final distM = Geolocator.distanceBetween(
      pos.latitude, pos.longitude,
      point.latitude, point.longitude,
    );
    return distM / 1000 <= radiusKm;
  }
}

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

final userPositionProvider = FutureProvider<Position?>((ref) async {
  if (kIsWeb) return null;
  return ref.read(locationServiceProvider).getCurrentPosition();
});

// ──────────────────────────────────────────────

class MatchFilter {
  final MatchType? type;
  final bool todayOnly;
  final int? level;

  const MatchFilter({this.type, this.todayOnly = false, this.level});
}

class MatchService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west3');

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

      // Ajout en pending + tracking pari
      final matchUpdate = <String, dynamic>{'pendingIds': FieldValue.arrayUnion([_uid])};
      if (placeBet) matchUpdate['bettorIds'] = FieldValue.arrayUnion([_uid]);
      tx.update(matchRef, matchUpdate);

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
    _functions.httpsCallable('notifyPlayerAccepted')
        .call({'matchId': matchId, 'playerId': playerId})
        .catchError((e) => debugPrint('[FCM] notifyPlayerAccepted: $e'));

    // Si le match est maintenant complet → crée/met à jour la conversation de groupe
    final snap = await _db.collection('matches').doc(matchId).get();
    final data = snap.data();
    if (data == null) return;
    final playerIds  = List<String>.from(data['playerIds'] ?? []);
    final maxPlayers = data['maxPlayers'] as int? ?? 4;
    if (playerIds.length >= maxPlayers) {
      await MessagingService().createMatchConversation(
        matchId:   matchId,
        matchClub: data['club'] ?? 'Match',
        playerIds: playerIds,
      );
    }
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
    _functions.httpsCallable('notifyPlayerRefused')
        .call({'matchId': matchId, 'playerId': playerId})
        .catchError((e) => debugPrint('[FCM] notifyPlayerRefused: $e'));
  }

  Future<void> removePlayer({required String matchId, required String playerId}) async {
    await _db.collection('matches').doc(matchId).update({
      'playerIds': FieldValue.arrayRemove([playerId]),
    });
  }

  /// [winnerTeam] : 1 = joueurs[0..half-1] ont gagné, 2 = joueurs[half..n-1] ont gagné.
  Future<void> finishMatch({
    required String matchId,
    required String score,
    required int winnerTeam,
  }) async {
    final matchRef = _db.collection('matches').doc(matchId);
    final matchDoc = await matchRef.get();
    final match    = ZuMatch.fromFirestore(matchDoc);
    final players  = match.playerIds;
    final half     = (players.length / 2).ceil();
    final team1    = players.sublist(0, half);
    final team2    = players.length > half ? players.sublist(half) : <String>[];
    final winners  = winnerTeam == 1 ? team1 : team2;
    final losers   = winnerTeam == 1 ? team2 : team1;

    final batch = _db.batch();
    batch.update(matchRef, {
      'status':     MatchStatus.finished.name,
      'score':      score,
      'team1Ids':   team1,
      'team2Ids':   team2,
      'winnerTeam': winnerTeam,
    });

    // Distribution des paris
    final winBettors  = winners.where((id) => match.bettorIds.contains(id)).toList();
    final loseBettors = losers.where((id) => match.bettorIds.contains(id)).toList();
    if (winBettors.isNotEmpty && loseBettors.isNotEmpty) {
      // Chaque gagnant-parieur récupère (nb perdants-parieurs / nb gagnants-parieurs) crédits
      final gain = (loseBettors.length / winBettors.length).ceil();
      for (final uid in winBettors) {
        final uDoc = await _db.collection('users').doc(uid).get();
        final cur  = uDoc.data()?['credits'] as int? ?? 0;
        batch.update(_db.collection('users').doc(uid), {'credits': FieldValue.increment(gain)});
        batch.set(_db.collection('creditTransactions').doc(), {
          'userId': uid, 'type': 'betWin', 'amount': gain,
          'balanceBefore': cur, 'balanceAfter': cur + gain,
          'refId': matchId, 'description': 'Pari gagné — ${match.club}',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  Future<void> cancelMatch({required String matchId}) async {
    // Le remboursement des crédits et les notifications sont gérés
    // par le trigger onMatchCancelled dans les Cloud Functions (index.ts).
    await _db.collection('matches').doc(matchId).update({
      'status': MatchStatus.cancelled.name,
    });
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

  Stream<List<ZuMatch>> watchNearbyMatches({Position? userPosition}) {
    return _db.collection('matches')
        .where('status', isEqualTo: MatchStatus.open.name)
        .limit(50)
        .snapshots()
        .map((s) {
          final all = s.docs.map(ZuMatch.fromFirestore).toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));
          if (userPosition == null) return all;
          return all.where((m) {
            if (m.location == null) return true;
            return LocationService.withinRadius(m.location!, userPosition);
          }).toList();
        });
  }

  Stream<List<ZuMatch>> watchMyMatches(String uid) {
    // Firestore n'autorise pas arrayContains + whereIn + orderBy sans index composite.
    // On filtre uniquement par joueur et on trie/filtre côté client.
    return _db.collection('matches')
        .where('playerIds', arrayContains: uid)
        .orderBy('startTime')
        .snapshots()
        .map((s) => s.docs
            .map(ZuMatch.fromFirestore)
            .where((m) =>
                m.status == MatchStatus.open ||
                m.status == MatchStatus.ongoing)
            .toList());
  }

  Stream<List<ZuMatch>> watchFilteredMatches(MatchFilter filter) {
    Query<Map<String, dynamic>> query = _db.collection('matches')
        .where('status', isEqualTo: MatchStatus.open.name);

    if (filter.type != null) {
      query = query.where('type', isEqualTo: filter.type!.name);
    }

    return query.snapshots().map((s) {
      var list = s.docs.map(ZuMatch.fromFirestore).toList();
      // Tri et filtres client-side (évite les index composites Firestore)
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
      if (filter.todayOnly) {
        final start = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
        final end   = start.add(const Duration(days: 1));
        list = list.where((m) =>
            m.startTime.isAfter(start) && m.startTime.isBefore(end)).toList();
      }
      if (filter.level != null) {
        list = list.where((m) =>
            m.levelMin <= filter.level! && filter.level! <= m.levelMax).toList();
      }
      return list;
    });
  }

  Stream<ZuMatch?> watchMatch(String matchId) => _db.collection('matches')
      .doc(matchId)
      .snapshots()
      .map((doc) => doc.exists ? ZuMatch.fromFirestore(doc) : null);
}

final matchServiceProvider = Provider<MatchService>((ref) => MatchService());

final nearbyMatchesProvider = StreamProvider<List<ZuMatch>>((ref) {
  final position = ref.watch(userPositionProvider).valueOrNull;
  return ref.watch(matchServiceProvider).watchNearbyMatches(userPosition: position);
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
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west3');

  String get _uid => _auth.currentUser!.uid;

  /// Retourne `true` si paiement Stripe lancé (web), `false` si inscription directe (tournoi gratuit).
  /// Lève [StripeException] ou [Exception] en cas d'erreur.
  Future<bool> register({
    required String tournamentId,
    required String fftLicense,
  }) async {
    final tRef = _db.collection('tournaments').doc(tournamentId);
    final t    = await tRef.get();
    final data = t.data()!;
    final entryFee = (data['entryFee'] as num?)?.toDouble() ?? 0;

    if (entryFee > 0) {
      if (!kIsWeb) {
        throw Exception(
          'Le paiement de l\'inscription est disponible sur le web uniquement pour le moment.',
        );
      }
      // Web → Stripe PaymentSheet
      final result = await _functions
          .httpsCallable('createTournamentPaymentIntent')
          .call({'tournamentId': tournamentId, 'fftLicense': fftLicense});

      final d             = Map<String, dynamic>.from(result.data as Map);
      final clientSecret  = d['clientSecret'] as String;
      final ephemeralKey  = d['ephemeralKey'] as String;
      final customerId    = d['customerId']   as String;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          customerEphemeralKeySecret: ephemeralKey,
          customerId:                customerId,
          merchantDisplayName:       'Zupadel',
          style:                     ThemeMode.dark,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary:             Color(0xFF4EE06E),
              background:          Color(0xFF0D0F14),
              componentBackground: Color(0xFF1A1D24),
            ),
          ),
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      // La confirmation d'inscription est faite par le webhook stripeWebhook
      return true;
    }

    // Tournoi gratuit → inscription directe
    await _db.collection('tournamentRegistrations').add({
      'tournamentId': tournamentId,
      'userId':       _uid,
      'fftLicense':   fftLicense,
      'status':       'pending',
      'createdAt':    FieldValue.serverTimestamp(),
    });
    return false;
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

  Stream<ZuCoach?> watchCoach(String id) => _db.collection('coaches')
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? ZuCoach.fromFirestore(d) : null);
}

final coachServiceProvider = Provider<CoachService>((ref) => CoachService());

final coachesProvider = StreamProvider<List<ZuCoach>>((ref) =>
    ref.watch(coachServiceProvider).watchCoaches());

final coachDetailProvider = StreamProvider.family<ZuCoach?, String>((ref, id) =>
    ref.watch(coachServiceProvider).watchCoach(id));

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
//  IAP SERVICE — iOS + Android
//  Apple In-App Purchase / Google Play Billing
// ══════════════════════════════════════════════

class IAPService {
  final _iap       = InAppPurchase.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west3');
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final _errorCtrl = StreamController<String>.broadcast();

  /// Émettre les erreurs d'achat → écouter dans l'UI (CreditsScreen)
  Stream<String> get purchaseErrors => _errorCtrl.stream;

  /// IDs produits — doivent correspondre exactement à
  /// App Store Connect (iOS) et Google Play Console (Android)
  static const productIds = <String>{
    'credits_starter', // 10 crédits
    'credits_joueur',  // 25 crédits
    'credits_pro',     // 60 crédits
    'credits_elite',   // 150 crédits
  };

  /// Métadonnées locales associées à chaque product ID
  static const meta = <String, ({int credits, String name, bool popular, bool gold})>{
    'credits_starter': (credits: 10,  name: 'Starter', popular: false, gold: false),
    'credits_joueur':  (credits: 25,  name: 'Joueur',  popular: true,  gold: false),
    'credits_pro':     (credits: 60,  name: 'Pro',     popular: false, gold: false),
    'credits_elite':   (credits: 150, name: 'Elite',   popular: false, gold: true),
  };

  void initialize() {
    _subscription = _iap.purchaseStream.listen(
      _handlePurchases,
      onError: (e) => debugPrint('[IAP] stream error: $e'),
    );
  }

  void dispose() {
    _subscription?.cancel();
    _errorCtrl.close();
  }

  /// Récupère les produits depuis le store (prix localisés)
  Future<List<ProductDetails>> loadProducts() async {
    final available = await _iap.isAvailable();
    if (!available) return [];
    final response = await _iap.queryProductDetails(productIds);
    if (response.error != null) {
      debugPrint('[IAP] queryProductDetails error: ${response.error}');
    }
    return response.productDetails
      ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
  }

  /// Lance l'achat d'un produit (affiche la sheet native du store)
  Future<void> buyProduct(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    await _iap.buyConsumable(purchaseParam: param);
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Valider côté serveur → Firebase Function crédite l'utilisateur
        try {
          await _functions.httpsCallable('validateIAPPurchase').call({
            'productId':        purchase.productID,
            'verificationData': purchase.verificationData.serverVerificationData,
            'platform':         purchase.verificationData.source,
          });
        } catch (e) {
          debugPrint('[IAP] validation error: $e');
          _errorCtrl.add('Erreur de validation. Contacte le support si les crédits n\'arrivent pas.');
        }
      } else if (purchase.status == PurchaseStatus.error) {
        final msg = purchase.error?.message ?? 'Erreur inconnue';
        // Ne pas afficher "annulé" comme une erreur
        if (!msg.toLowerCase().contains('cancel') &&
            !msg.toLowerCase().contains('user_cancel')) {
          _errorCtrl.add('Erreur achat : $msg');
        }
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }
}

final iapServiceProvider = Provider<IAPService>((ref) {
  final service = IAPService();
  if (!kIsWeb) service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Liste des produits disponibles (prix localisés depuis le store)
final iapProductsProvider = FutureProvider<List<ProductDetails>>((ref) async {
  if (kIsWeb) return [];
  return ref.watch(iapServiceProvider).loadProducts();
});

// ══════════════════════════════════════════════
//  PAYMENT SERVICE — Web uniquement (Stripe)
//  Sur iOS/Android → utiliser IAPService
// ══════════════════════════════════════════════

class PaymentService {
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west3');

  static const PaymentSheetAppearance _appearance = PaymentSheetAppearance(
    colors: PaymentSheetAppearanceColors(
      primary:             Color(0xFF4EE06E),
      background:          Color(0xFF0D0F14),
      componentBackground: Color(0xFF1A1D24),
    ),
  );

  Future<void> _openPaymentSheet(Map<String, dynamic> d) async {
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: d['clientSecret'] as String,
        customerEphemeralKeySecret: d['ephemeralKey'] as String,
        customerId:                d['customerId']   as String,
        merchantDisplayName:       'Zupadel',
        style:                     ThemeMode.dark,
        appearance:                _appearance,
      ),
    );
    await Stripe.instance.presentPaymentSheet();
  }

  /// Web only — achat pack crédits via Stripe.
  Future<void> buyCredits(String packId) async {
    assert(kIsWeb, 'PaymentService.buyCredits est réservé au web — utiliser IAPService sur mobile');
    final result = await _functions.httpsCallable('createPaymentIntent').call({'packId': packId});
    await _openPaymentSheet(Map<String, dynamic>.from(result.data as Map));
  }

  /// Web only — abonnement coach mensuel 10€.
  Future<void> subscribeCoach(String coachId) async {
    assert(kIsWeb, 'Abonnement coach web uniquement');
    final result = await _functions.httpsCallable('createCoachSubscription').call({'coachId': coachId});
    await _openPaymentSheet(Map<String, dynamic>.from(result.data as Map));
  }
}

final paymentServiceProvider = Provider<PaymentService>((ref) => PaymentService());

// ══════════════════════════════════════════════
//  CLUB SERVICE
// ══════════════════════════════════════════════

class ClubService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<ZuClub>> watchClubs() => _db.collection('clubs')
      .where('isActive', isEqualTo: true)
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(ZuClub.fromFirestore).toList());

  Stream<ZuClub?> watchClub(String id) => _db.collection('clubs')
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? ZuClub.fromFirestore(d) : null);

  Stream<List<ZuCourt>> watchCourts(String clubId) => _db
      .collection('clubs')
      .doc(clubId)
      .collection('courts')
      .where('isActive', isEqualTo: true)
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(ZuCourt.fromFirestore).toList());
}

final clubServiceProvider    = Provider<ClubService>((ref) => ClubService());

final clubsProvider = StreamProvider<List<ZuClub>>((ref) =>
    ref.watch(clubServiceProvider).watchClubs());

final clubDetailProvider = StreamProvider.family<ZuClub?, String>((ref, id) =>
    ref.watch(clubServiceProvider).watchClub(id));

final clubCourtsProvider = StreamProvider.family<List<ZuCourt>, String>((ref, clubId) =>
    ref.watch(clubServiceProvider).watchCourts(clubId));

// ══════════════════════════════════════════════
//  RESERVATION SERVICE
// ══════════════════════════════════════════════

class ReservationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west3');

  String get _uid => _auth.currentUser!.uid;

  Stream<List<ZuReservation>> watchMyReservations() => _db
      .collection('reservations')
      .where('userId', isEqualTo: _uid)
      .where('status', isEqualTo: ReservationStatus.confirmed.name)
      .orderBy('startTime')
      .snapshots()
      .map((s) => s.docs
          .map(ZuReservation.fromFirestore)
          .where((r) => r.startTime.isAfter(DateTime.now()))
          .toList());

  /// Retourne les startTime déjà réservés pour un court sur un jour donné.
  Future<List<DateTime>> bookedSlots({
    required String courtId,
    required DateTime day,
  }) async {
    final start = DateTime(day.year, day.month, day.day);
    final end   = start.add(const Duration(days: 1));
    final snap  = await _db.collection('reservations')
        .where('courtId', isEqualTo: courtId)
        .where('status', isEqualTo: ReservationStatus.confirmed.name)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs
        .map(ZuReservation.fromFirestore)
        .map((r) => r.startTime)
        .toList();
  }

  /// Réserve atomiquement un créneau via Cloud Function (détection de conflit).
  Future<String> bookSlot({
    required String clubId,
    required String clubName,
    required String courtId,
    required String courtName,
    required DateTime startTime,
    required int durationMinutes,
    required int priceCredits,
  }) async {
    final result = await _functions.httpsCallable('bookCourtSlot').call({
      'clubId':          clubId,
      'clubName':        clubName,
      'courtId':         courtId,
      'courtName':       courtName,
      'startTime':       startTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'priceCredits':    priceCredits,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['reservationId'] as String;
  }

  /// Annule une réservation et rembourse les crédits.
  Future<void> cancelReservation(String reservationId) async {
    final resRef  = _db.collection('reservations').doc(reservationId);
    final userRef = _db.collection('users').doc(_uid);

    await _db.runTransaction((tx) async {
      final resDoc  = await tx.get(resRef);
      final userDoc = await tx.get(userRef);
      final res     = ZuReservation.fromFirestore(resDoc);
      if (res.userId != _uid) throw Exception('Non autorisé');
      if (res.status != ReservationStatus.confirmed) {
        throw Exception('Réservation non annulable');
      }
      final credits = userDoc.data()?['credits'] as int? ?? 0;
      tx.update(resRef, {'status': ReservationStatus.cancelled.name});
      tx.update(userRef, {'credits': FieldValue.increment(res.priceCredits)});
      tx.set(_db.collection('creditTransactions').doc(), {
        'userId':        _uid,
        'type':          CreditOpType.courtBookingRefund.name,
        'amount':        res.priceCredits,
        'balanceBefore': credits,
        'balanceAfter':  credits + res.priceCredits,
        'refId':         reservationId,
        'description':   'Annulation terrain — ${res.courtName} @ ${res.clubName}',
        'createdAt':     FieldValue.serverTimestamp(),
      });
    });
  }
}

final reservationServiceProvider = Provider<ReservationService>((ref) => ReservationService());

final myReservationsProvider = StreamProvider<List<ZuReservation>>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value([]);
  return ref.watch(reservationServiceProvider).watchMyReservations();
});

// ══════════════════════════════════════════════
//  MATCHMAKING SERVICE
// ══════════════════════════════════════════════

class MatchmakingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  /// Définit la disponibilité de l'utilisateur dans `userAvailability/{uid}`.
  /// Récupère la position GPS actuelle si disponible.
  Future<void> setAvailability({
    required bool available,
    int hours = 24,
  }) async {
    final expiresAt = DateTime.now().add(Duration(hours: hours));

    // Récupère le niveau de l'user
    final userDoc = await _db.collection('users').doc(_uid).get();
    final level = userDoc.data()?['level'] as int? ?? 1;

    GeoPoint? location;
    if (!kIsWeb && available) {
      try {
        final locService = LocationService();
        final pos = await locService.getCurrentPosition();
        if (pos != null) {
          location = GeoPoint(pos.latitude, pos.longitude);
        }
      } catch (_) {}
    }

    final data = <String, dynamic>{
      'isAvailable': available,
      'expiresAt':   Timestamp.fromDate(expiresAt),
      'level':       level,
      'updatedAt':   FieldValue.serverTimestamp(),
    };
    if (location != null) data['location'] = location;

    await _db.collection('userAvailability').doc(_uid).set(data, SetOptions(merge: true));

    // Met aussi à jour lastKnownLocation dans users/{uid} si on a la position
    if (location != null) {
      await _db.collection('users').doc(_uid).update({
        'lastKnownLocation': location,
      });
    }
  }

  /// Met à jour `users/{uid}.lastKnownLocation` et `userAvailability/{uid}.location`.
  Future<void> updateUserLocation() async {
    if (kIsWeb) return;
    try {
      final locService = LocationService();
      final pos = await locService.getCurrentPosition();
      if (pos == null) return;
      final geo = GeoPoint(pos.latitude, pos.longitude);

      await _db.collection('users').doc(_uid).update({
        'lastKnownLocation': geo,
      });

      // Met à jour la location dans userAvailability si le doc existe
      final availDoc = await _db.collection('userAvailability').doc(_uid).get();
      if (availDoc.exists) {
        await _db.collection('userAvailability').doc(_uid).update({
          'location': geo,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('[MatchmakingService] updateUserLocation error: $e');
    }
  }

  /// Retourne un stream de matchs ouverts scorés par compatibilité.
  Stream<List<ScoredMatch>> watchSuggestedMatches({
    required int userLevel,
    GeoPoint? userLocation,
    bool isAvailable = false,
  }) {
    return _db
        .collection('matches')
        .where('status', isEqualTo: MatchStatus.open.name)
        .limit(50)
        .snapshots()
        .map((snap) {
          final scored = snap.docs
              .map(ZuMatch.fromFirestore)
              .map((match) => _scoreMatch(
                    match: match,
                    userLevel: userLevel,
                    userLocation: userLocation,
                    isAvailable: isAvailable,
                  ))
              .where((sm) => sm.score > 0)
              .toList()
            ..sort((a, b) => b.score.compareTo(a.score));
          return scored;
        });
  }

  /// Calcule le score de compatibilité entre un joueur et un match.
  ScoredMatch _scoreMatch({
    required ZuMatch match,
    required int userLevel,
    required GeoPoint? userLocation,
    required bool isAvailable,
  }) {
    // ── Level score (0–50) ──────────────────────────
    int levelScore;
    final bool exactLevel = userLevel >= match.levelMin && userLevel <= match.levelMax;
    if (exactLevel) {
      levelScore = 50;
    } else if ((userLevel - match.levelMin).abs() == 1 ||
               (userLevel - match.levelMax).abs() == 1) {
      levelScore = 30;
    } else {
      levelScore = 0;
    }

    // ── Distance score (0–30) ───────────────────────
    int distanceScore = 0;
    double? distanceKm;
    if (userLocation != null && match.location != null) {
      final distM = Geolocator.distanceBetween(
        userLocation.latitude, userLocation.longitude,
        match.location!.latitude, match.location!.longitude,
      );
      distanceKm = distM / 1000;
      if (distanceKm < 3) {
        distanceScore = 30;
      } else if (distanceKm < 10) {
        distanceScore = 20;
      } else if (distanceKm < 20) {
        distanceScore = 10;
      } else if (distanceKm < 30) {
        distanceScore = 5;
      } else {
        distanceScore = 0;
      }
    }

    // ── Availability bonus (0–20) ───────────────────
    final int availBonus = isAvailable ? 20 : 0;

    final int total = levelScore + distanceScore + availBonus;

    return ScoredMatch(
      match:      match,
      score:      total,
      distanceKm: distanceKm,
      levelMatch: exactLevel,
    );
  }

  /// Appelle la CF `getMatchSuggestions` et retourne les profils scorés.
  Future<List<Map<String, dynamic>>> getMatchSuggestions(String matchId) async {
    final result = await FirebaseFunctions.instanceFor(region: 'europe-west3')
        .httpsCallable('getMatchSuggestions')
        .call({'matchId': matchId});
    final data = result.data as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['suggestions'] as List);
  }

  /// Appelle la CF `invitePlayerToMatch`.
  Future<void> invitePlayer({
    required String matchId,
    required String invitedUid,
  }) async {
    await FirebaseFunctions.instanceFor(region: 'europe-west3')
        .httpsCallable('invitePlayerToMatch')
        .call({'matchId': matchId, 'invitedUid': invitedUid});
  }
}

final matchmakingServiceProvider = Provider<MatchmakingService>((ref) => MatchmakingService());

/// Provider qui indique si l'utilisateur courant est disponible.
final availabilityProvider = StreamProvider<UserAvailability?>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('userAvailability')
      .doc(auth.uid)
      .snapshots()
      .map((d) => d.exists ? UserAvailability.fromFirestore(d) : null);
});

/// Provider de matchs suggérés (scorés) pour l'utilisateur courant.
final suggestedMatchesProvider = StreamProvider<List<ScoredMatch>>((ref) {
  final user     = ref.watch(currentUserProvider).valueOrNull;
  final avail    = ref.watch(availabilityProvider).valueOrNull;
  final position = ref.watch(userPositionProvider).valueOrNull;

  if (user == null) return Stream.value([]);

  GeoPoint? geo;
  if (position != null) {
    geo = GeoPoint(position.latitude, position.longitude);
  } else if (user.lastKnownLocation != null) {
    geo = user.lastKnownLocation;
  }

  return ref.watch(matchmakingServiceProvider).watchSuggestedMatches(
    userLevel:    user.level,
    userLocation: geo,
    isAvailable:  avail?.isStillValid ?? false,
  );
});

// ══════════════════════════════════════════════
//  PLAYER MINI PROFILE (pour avatars dans les cards)
// ══════════════════════════════════════════════

/// Mini-profil léger pour affichage d'avatar dans les match cards.
/// Mis en cache par Riverpod — un seul read Firestore par UID.
class PlayerMini {
  final String  firstName;
  final String  lastName;
  final String? photoUrl;

  const PlayerMini({
    required this.firstName,
    required this.lastName,
    this.photoUrl,
  });

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty  ? lastName[0].toUpperCase()  : '';
    return '$f$l'.isEmpty ? '?' : '$f$l';
  }
}

final playerMiniProvider = FutureProvider.family<PlayerMini?, String>((ref, uid) async {
  if (uid.isEmpty) return null;
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  if (!doc.exists) return null;
  final d = doc.data()!;
  return PlayerMini(
    firstName: d['firstName'] as String? ?? '',
    lastName:  d['lastName']  as String? ?? '',
    photoUrl:  d['photoUrl']  as String?,
  );
});

// ══════════════════════════════════════════════
//  USER STATS
// ══════════════════════════════════════════════

// ══════════════════════════════════════════════
//  MESSAGING SERVICE
// ══════════════════════════════════════════════

class MessagingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Conversations ────────────────────────────────────────────

  Stream<List<ZuConversation>> watchConversations(String uid) {
    return _db
        .collection('conversations')
        .where('participantIds', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ZuConversation.fromFirestore).toList());
  }

  /// Retourne l'ID de la conversation DM existante entre [uid1] et [uid2],
  /// ou en crée une nouvelle.
  Future<String> getOrCreateDM(String uid1, String uid2) async {
    // Cherche une conv directe existante entre ces deux users
    final existing = await _db
        .collection('conversations')
        .where('type', isEqualTo: 'direct')
        .where('participantIds', arrayContains: uid1)
        .limit(20)
        .get();

    for (final doc in existing.docs) {
      final ids = List<String>.from(doc.data()['participantIds'] ?? []);
      if (ids.contains(uid2) && ids.length == 2) return doc.id;
    }

    // Crée la conversation
    final ref = await _db.collection('conversations').add({
      'type':            'direct',
      'participantIds':  [uid1, uid2],
      'lastMessage':     '',
      'lastMessageAt':   FieldValue.serverTimestamp(),
      'unreadCounts':    {uid1: 0, uid2: 0},
      'createdAt':       FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Crée (ou met à jour) la conversation de groupe d'un match.
  Future<void> createMatchConversation({
    required String matchId,
    required String matchClub,
    required List<String> playerIds,
  }) async {
    final existing = await _db
        .collection('conversations')
        .where('matchId', isEqualTo: matchId)
        .limit(1)
        .get();

    final unreadCounts = {for (final uid in playerIds) uid: 0};

    if (existing.docs.isNotEmpty) {
      // Met à jour les participants si quelqu'un a été ajouté
      await existing.docs.first.reference.update({
        'participantIds': playerIds,
        'unreadCounts':   unreadCounts,
      });
    } else {
      await _db.collection('conversations').add({
        'type':           'match',
        'matchId':        matchId,
        'matchClub':      matchClub,
        'participantIds': playerIds,
        'lastMessage':    '🎾 Le groupe est prêt !',
        'lastMessageAt':  FieldValue.serverTimestamp(),
        'unreadCounts':   unreadCounts,
        'createdAt':      FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Messages ─────────────────────────────────────────────────

  Stream<List<ZuMessage>> watchMessages(String convId) {
    return _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(ZuMessage.fromFirestore).toList());
  }

  Future<void> sendMessage({
    required String convId,
    required String senderId,
    required String text,
    required List<String> participantIds,
  }) async {
    final batch = _db.batch();

    // Ajoute le message
    final msgRef = _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .doc();
    batch.set(msgRef, {
      'senderId':  senderId,
      'text':      text.trim(),
      'type':      'text',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Met à jour la conversation — incrémente les unread des autres participants
    final unreadUpdate = <String, dynamic>{
      'lastMessage':    text.trim(),
      'lastMessageAt':  FieldValue.serverTimestamp(),
      'lastSenderId':   senderId,
    };
    for (final uid in participantIds) {
      if (uid != senderId) {
        unreadUpdate['unreadCounts.$uid'] = FieldValue.increment(1);
      }
    }
    batch.update(_db.collection('conversations').doc(convId), unreadUpdate);

    await batch.commit();
  }

  Future<void> markAsRead(String convId, String uid) async {
    await _db.collection('conversations').doc(convId).update({
      'unreadCounts.$uid': 0,
    });
  }
}

final messagingServiceProvider = Provider<MessagingService>(
  (_) => MessagingService(),
);

final conversationsProvider = StreamProvider<List<ZuConversation>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(messagingServiceProvider).watchConversations(uid);
});

final messagesProvider = StreamProvider.family<List<ZuMessage>, String>((ref, convId) {
  return ref.watch(messagingServiceProvider).watchMessages(convId);
});

final unreadTotalProvider = Provider<int>((ref) {
  final uid   = ref.watch(authStateProvider).valueOrNull?.uid;
  final convs = ref.watch(conversationsProvider).valueOrNull ?? [];
  if (uid == null) return 0;
  return convs.fold(0, (sum, c) => sum + c.unreadFor(uid));
});

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

// ══════════════════════════════════════════════
//  LEADERBOARD SERVICE
// ══════════════════════════════════════════════

class LeaderboardService {
  final _db = FirebaseFirestore.instance;

  /// Classement général — trié par ELO, limité à [limit] entrées
  Stream<List<ZuRanking>> watchLeaderboard({int limit = 50}) =>
      _db.collection('rankings')
          .orderBy('eloRating', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(ZuRanking.fromFirestore).toList());

  /// Classement filtré par niveau
  Stream<List<ZuRanking>> watchLeaderboardByLevel(int level, {int limit = 50}) =>
      _db.collection('rankings')
          .where('level', isEqualTo: level)
          .orderBy('eloRating', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(ZuRanking.fromFirestore).toList());

  /// Classement filtré par ville
  Stream<List<ZuRanking>> watchLeaderboardByCity(String city, {int limit = 50}) =>
      _db.collection('rankings')
          .where('city', isEqualTo: city)
          .orderBy('eloRating', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(ZuRanking.fromFirestore).toList());

  /// Top classement hebdomadaire
  Stream<List<ZuRanking>> watchWeeklyLeaderboard({int limit = 50}) =>
      _db.collection('rankings')
          .orderBy('weeklyPoints', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(ZuRanking.fromFirestore).toList());

  /// Classement d'un joueur spécifique (pour profil public)
  Future<ZuRanking?> getPlayerRanking(String uid) async {
    final doc = await _db.collection('rankings').doc(uid).get();
    return doc.exists ? ZuRanking.fromFirestore(doc) : null;
  }

  /// Tous les classements (pour filtre géographique côté client)
  Stream<List<ZuRanking>> watchAllRankings({int limit = 300}) =>
      _db.collection('rankings')
          .orderBy('eloRating', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(ZuRanking.fromFirestore).toList());

  /// Stream du classement de l'utilisateur connecté
  Stream<ZuRanking?> watchMyRanking(String uid) =>
      _db.collection('rankings')
          .doc(uid)
          .snapshots()
          .map((d) => d.exists ? ZuRanking.fromFirestore(d) : null);
}

final leaderboardServiceProvider = Provider<LeaderboardService>((ref) => LeaderboardService());

/// Filtre pour le classement
class LeaderboardFilter {
  final String type;  // 'global' | 'level' | 'city' | 'weekly'
  final int? level;
  final String? city;
  const LeaderboardFilter(this.type, {this.level, this.city});

  @override
  bool operator ==(Object other) =>
      other is LeaderboardFilter && other.type == type &&
      other.level == level && other.city == city;
  @override
  int get hashCode => Object.hash(type, level, city);
}

final leaderboardProvider = StreamProvider.family<List<ZuRanking>, LeaderboardFilter>(
  (ref, filter) {
    final svc = ref.watch(leaderboardServiceProvider);
    return switch (filter.type) {
      'level'  => svc.watchLeaderboardByLevel(filter.level ?? 1),
      'city'   => svc.watchLeaderboardByCity(filter.city ?? ''),
      'weekly' => svc.watchWeeklyLeaderboard(),
      _        => svc.watchLeaderboard(),
    };
  },
);

final allRankingsProvider = StreamProvider<List<ZuRanking>>((ref) =>
    ref.watch(leaderboardServiceProvider).watchAllRankings());

final myRankingProvider = StreamProvider<ZuRanking?>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(leaderboardServiceProvider).watchMyRanking(uid);
});

final playerRankingProvider = FutureProvider.family<ZuRanking?, String>((ref, uid) =>
    ref.watch(leaderboardServiceProvider).getPlayerRanking(uid));
