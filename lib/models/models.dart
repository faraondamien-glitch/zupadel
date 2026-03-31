import 'package:cloud_firestore/cloud_firestore.dart';

// ─── ENUMS ───────────────────────────────────────────────────────

enum MatchStatus { open, full, ongoing, finished, cancelled }
enum MatchType   { leisure, competitive, training }
enum MatchVisibility { public, private }
enum TournamentStatus { pending, published, refused }
enum CreditOpType {
  registration, joinMatch, postMatchReview, referral,
  betWin, purchase, refund, coachSubscription, tournamentEntry, send, receive
}

// ─── USER ────────────────────────────────────────────────────────

class ZuUser {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? photoUrl;
  final int level;           // 1–7
  final String? fftLicense;
  final String? fftRank;     // P25, P100, P250...
  final GeoPoint? location;
  final String? city;
  final int credits;
  final String referralCode;
  final int referralCount;
  final DateTime createdAt;

  const ZuUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.photoUrl,
    required this.level,
    this.fftLicense,
    this.fftRank,
    this.location,
    this.city,
    required this.credits,
    required this.referralCode,
    required this.referralCount,
    required this.createdAt,
  });

  /// Prénom seul — pour les contextes informels (match, chat…)
  String get displayName => firstName;

  /// Prénom + Nom — pour le profil
  String get fullName => '$firstName $lastName';

  /// Initiales pour l'avatar
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$f$l';
  }

  factory ZuUser.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ZuUser(
      id:            doc.id,
      firstName:     d['firstName'] ?? d['pseudo'] ?? '',
      lastName:      d['lastName'] ?? '',
      email:         d['email'] ?? '',
      photoUrl:      d['photoUrl'],
      level:         d['level'] ?? 1,
      fftLicense:    d['fftLicense'],
      fftRank:       d['fftRank'],
      location:      d['location'],
      city:          d['city'],
      credits:       d['credits'] ?? 0,
      referralCode:  d['referralCode'] ?? '',
      referralCount: d['referralCount'] ?? 0,
      createdAt:     (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'firstName':     firstName,
    'lastName':      lastName,
    'email':         email,
    'photoUrl':      photoUrl,
    'level':         level,
    'fftLicense':    fftLicense,
    'fftRank':       fftRank,
    'location':      location,
    'city':          city,
    'credits':       credits,
    'referralCode':  referralCode,
    'referralCount': referralCount,
    'createdAt':     Timestamp.fromDate(createdAt),
  };

  ZuUser copyWith({int? credits, int? level, String? fftLicense, String? fftRank}) => ZuUser(
    id: id, firstName: firstName, lastName: lastName, email: email, photoUrl: photoUrl,
    level: level ?? this.level,
    fftLicense: fftLicense ?? this.fftLicense,
    fftRank: fftRank ?? this.fftRank,
    location: location, city: city,
    credits: credits ?? this.credits,
    referralCode: referralCode,
    referralCount: referralCount,
    createdAt: createdAt,
  );
}

// ─── MATCH ───────────────────────────────────────────────────────

class ZuMatch {
  final String id;
  final String organizerId;
  final String organizerPseudo;
  final String club;
  final GeoPoint? location;
  final String? city;
  final DateTime startTime;
  final int durationMinutes;
  final int levelMin;
  final int levelMax;
  final int maxPlayers;
  final MatchType type;
  final MatchVisibility visibility;
  final MatchStatus status;
  final List<String> playerIds;
  final List<String> pendingIds;
  final String? note;
  final String? score;
  final double? avgRating;
  final int ratingCount;
  final DateTime createdAt;

  const ZuMatch({
    required this.id,
    required this.organizerId,
    required this.organizerPseudo,
    required this.club,
    this.location,
    this.city,
    required this.startTime,
    required this.durationMinutes,
    required this.levelMin,
    required this.levelMax,
    required this.maxPlayers,
    required this.type,
    required this.visibility,
    required this.status,
    required this.playerIds,
    required this.pendingIds,
    this.note,
    this.score,
    this.avgRating,
    required this.ratingCount,
    required this.createdAt,
  });

  factory ZuMatch.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ZuMatch(
      id:              doc.id,
      organizerId:     d['organizerId'] ?? '',
      organizerPseudo: d['organizerPseudo'] ?? '',
      club:            d['club'] ?? '',
      location:        d['location'],
      city:            d['city'],
      startTime:       (d['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationMinutes: d['durationMinutes'] ?? 90,
      levelMin:        d['levelMin'] ?? 1,
      levelMax:        d['levelMax'] ?? 7,
      maxPlayers:      d['maxPlayers'] ?? 4,
      type:            MatchType.values.byName(d['type'] ?? 'leisure'),
      visibility:      MatchVisibility.values.byName(d['visibility'] ?? 'public'),
      status:          MatchStatus.values.byName(d['status'] ?? 'open'),
      playerIds:       List<String>.from(d['playerIds'] ?? []),
      pendingIds:      List<String>.from(d['pendingIds'] ?? []),
      note:            d['note'],
      score:           d['score'],
      avgRating:       (d['avgRating'] as num?)?.toDouble(),
      ratingCount:     d['ratingCount'] ?? 0,
      createdAt:       (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'organizerId':     organizerId,
    'organizerPseudo': organizerPseudo,
    'club':            club,
    'location':        location,
    'city':            city,
    'startTime':       Timestamp.fromDate(startTime),
    'durationMinutes': durationMinutes,
    'levelMin':        levelMin,
    'levelMax':        levelMax,
    'maxPlayers':      maxPlayers,
    'type':            type.name,
    'visibility':      visibility.name,
    'status':          status.name,
    'playerIds':       playerIds,
    'pendingIds':      pendingIds,
    'note':            note,
    'score':           score,
    'avgRating':       avgRating,
    'ratingCount':     ratingCount,
    'createdAt':       Timestamp.fromDate(createdAt),
  };

  int get availableSlots  => maxPlayers - playerIds.length;
  bool get isFull         => availableSlots <= 0;
  String get levelRange   => 'Niv. $levelMin–$levelMax';
  String get typeLabel    => switch (type) {
    MatchType.leisure     => 'Loisir',
    MatchType.competitive => 'Compétitif',
    MatchType.training    => 'Training',
  };
  String get statusLabel  => switch (status) {
    MatchStatus.open      => 'Ouvert',
    MatchStatus.full      => 'Complet',
    MatchStatus.ongoing   => 'En cours',
    MatchStatus.finished  => 'Terminé',
    MatchStatus.cancelled => 'Annulé',
  };
}

// ─── TOURNAMENT ──────────────────────────────────────────────────

class ZuTournament {
  final String id;
  final String organizerId;
  final String title;
  final String club;
  final String level;         // P25, P100, P250, P500, P1000, P2000
  final DateTime startDate;
  final DateTime endDate;
  final String category;      // Masculin, Féminin, Mixte
  final String surface;       // Indoor, Outdoor
  final int maxPlayers;
  final double entryFee;
  final String description;
  final String? rulesUrl;
  final String contactName;
  final String contactEmail;
  final TournamentStatus status;
  final List<String> registeredIds;
  final DateTime createdAt;

  const ZuTournament({
    required this.id,
    required this.organizerId,
    required this.title,
    required this.club,
    required this.level,
    required this.startDate,
    required this.endDate,
    required this.category,
    required this.surface,
    required this.maxPlayers,
    required this.entryFee,
    required this.description,
    this.rulesUrl,
    required this.contactName,
    required this.contactEmail,
    required this.status,
    required this.registeredIds,
    required this.createdAt,
  });

  factory ZuTournament.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ZuTournament(
      id:            doc.id,
      organizerId:   d['organizerId'] ?? '',
      title:         d['title'] ?? '',
      club:          d['club'] ?? '',
      level:         d['level'] ?? 'P100',
      startDate:     (d['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate:       (d['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category:      d['category'] ?? 'Mixte',
      surface:       d['surface'] ?? 'Indoor',
      maxPlayers:    d['maxPlayers'] ?? 16,
      entryFee:      (d['entryFee'] as num?)?.toDouble() ?? 0,
      description:   d['description'] ?? '',
      rulesUrl:      d['rulesUrl'],
      contactName:   d['contactName'] ?? '',
      contactEmail:  d['contactEmail'] ?? '',
      status:        TournamentStatus.values.byName(d['status'] ?? 'pending'),
      registeredIds: List<String>.from(d['registeredIds'] ?? []),
      createdAt:     (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  int get spotsLeft => maxPlayers - registeredIds.length;
  bool get isOpen   => status == TournamentStatus.published && spotsLeft > 0;
  bool get isFree   => entryFee == 0;
}

// ─── COACH ───────────────────────────────────────────────────────

class ZuCoach {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final String city;
  final int radiusKm;
  final List<String> playerLevels;    // débutant, intermédiaire, avancé
  final List<String> specialties;     // technique, tactique, physique, mental
  final double hourlyRate;
  final String bio;
  final String? availabilities;
  final String? instagram;
  final String? youtube;
  final double avgRating;
  final int ratingCount;
  final bool isActive;
  final DateTime subscribedUntil;

  const ZuCoach({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.photoUrl,
    required this.city,
    required this.radiusKm,
    required this.playerLevels,
    required this.specialties,
    required this.hourlyRate,
    required this.bio,
    this.availabilities,
    this.instagram,
    this.youtube,
    required this.avgRating,
    required this.ratingCount,
    required this.isActive,
    required this.subscribedUntil,
  });

  factory ZuCoach.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ZuCoach(
      id:              doc.id,
      userId:          d['userId'] ?? '',
      firstName:       d['firstName'] ?? '',
      lastName:        d['lastName'] ?? '',
      photoUrl:        d['photoUrl'],
      city:            d['city'] ?? '',
      radiusKm:        d['radiusKm'] ?? 30,
      playerLevels:    List<String>.from(d['playerLevels'] ?? []),
      specialties:     List<String>.from(d['specialties'] ?? []),
      hourlyRate:      (d['hourlyRate'] as num?)?.toDouble() ?? 0,
      bio:             d['bio'] ?? '',
      availabilities:  d['availabilities'],
      instagram:       d['instagram'],
      youtube:         d['youtube'],
      avgRating:       (d['avgRating'] as num?)?.toDouble() ?? 0,
      ratingCount:     d['ratingCount'] ?? 0,
      isActive:        d['isActive'] ?? false,
      subscribedUntil: (d['subscribedUntil'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String get fullName => '$firstName $lastName';
}

// ─── CREDIT TRANSACTION ──────────────────────────────────────────

class CreditTransaction {
  final String id;
  final String userId;
  final CreditOpType type;
  final int amount;         // positif = crédit, négatif = débit
  final int balanceBefore;
  final int balanceAfter;
  final String? refId;      // matchId, tournamentId, etc.
  final String description;
  final DateTime createdAt;

  const CreditTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.refId,
    required this.description,
    required this.createdAt,
  });

  factory CreditTransaction.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CreditTransaction(
      id:            doc.id,
      userId:        d['userId'] ?? '',
      type:          CreditOpType.values.byName(d['type'] ?? 'purchase'),
      amount:        d['amount'] ?? 0,
      balanceBefore: d['balanceBefore'] ?? 0,
      balanceAfter:  d['balanceAfter'] ?? 0,
      refId:         d['refId'],
      description:   d['description'] ?? '',
      createdAt:     (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ─── MATCH REVIEW ────────────────────────────────────────────────

class MatchReview {
  final String id;
  final String matchId;
  final String reviewerId;
  final int stars;           // 1–5
  final String? comment;
  final DateTime createdAt;

  const MatchReview({
    required this.id,
    required this.matchId,
    required this.reviewerId,
    required this.stars,
    this.comment,
    required this.createdAt,
  });
}

// ─── USER STATS ──────────────────────────────────────────────────

class UserStats {
  final int matchesPlayed;
  final int matchesWon;
  final int matchesLost;
  final int minutesPlayed;
  final int setsWon;
  final int setsLost;
  final double avgOpponentLevel;

  const UserStats({
    required this.matchesPlayed,
    required this.matchesWon,
    required this.matchesLost,
    required this.minutesPlayed,
    required this.setsWon,
    required this.setsLost,
    required this.avgOpponentLevel,
  });

  double get winRate => matchesPlayed == 0 ? 0 : matchesWon / matchesPlayed;
  int get hoursPlayed => minutesPlayed ~/ 60;

  factory UserStats.fromFirestore(Map<String, dynamic> d) => UserStats(
    matchesPlayed:      d['matchesPlayed'] ?? 0,
    matchesWon:         d['matchesWon'] ?? 0,
    matchesLost:        d['matchesLost'] ?? 0,
    minutesPlayed:      d['minutesPlayed'] ?? 0,
    setsWon:            d['setsWon'] ?? 0,
    setsLost:           d['setsLost'] ?? 0,
    avgOpponentLevel:   (d['avgOpponentLevel'] as num?)?.toDouble() ?? 0,
  );
}
