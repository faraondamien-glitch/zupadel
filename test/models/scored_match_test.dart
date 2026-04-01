import 'package:flutter_test/flutter_test.dart';
import 'package:zupadel/models/models.dart';

ZuMatch _match({int levelMin = 2, int levelMax = 5}) => ZuMatch(
      id:              'match1',
      organizerId:     'u1',
      organizerPseudo: 'Alice',
      club:            'Club Test',
      startTime:       DateTime(2026, 6, 1, 10),
      durationMinutes: 90,
      levelMin:        levelMin,
      levelMax:        levelMax,
      maxPlayers:      4,
      type:            MatchType.leisure,
      visibility:      MatchVisibility.public,
      status:          MatchStatus.open,
      playerIds:       const [],
      pendingIds:      const [],
      ratingCount:     0,
      createdAt:       DateTime(2026, 5, 1),
    );

void main() {
  group('ScoredMatch', () {
    test('stores match, score, distanceKm and levelMatch', () {
      final m = _match();
      final sm = ScoredMatch(
        match:      m,
        score:      85,
        distanceKm: 3.2,
        levelMatch: true,
      );
      expect(sm.match, m);
      expect(sm.score, 85);
      expect(sm.distanceKm, closeTo(3.2, 0.001));
      expect(sm.levelMatch, isTrue);
    });

    test('distanceKm can be null', () {
      final sm = ScoredMatch(
        match:      _match(),
        score:      50,
        distanceKm: null,
        levelMatch: false,
      );
      expect(sm.distanceKm, isNull);
    });
  });
}
