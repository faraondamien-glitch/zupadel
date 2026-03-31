import 'dart:async';
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
import 'package:image_picker/image_picker.dart';
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
    batch.update(matchRef, {'status': MatchStatus.finished.name, 'score': score});

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
            'source':           purchase.verificationData.source,
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
