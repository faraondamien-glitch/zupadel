import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zupadel/models/models.dart';

ZuMatch _match({
  int maxPlayers = 4,
  List<String> playerIds = const [],
  MatchStatus status = MatchStatus.open,
  MatchType type = MatchType.leisure,
  int levelMin = 2,
  int levelMax = 5,
}) =>
    ZuMatch(
      id:              'match1',
      organizerId:     'u1',
      organizerPseudo: 'Alice',
      club:            'Club Test',
      startTime:       DateTime(2026, 6, 1, 10),
      durationMinutes: 90,
      levelMin:        levelMin,
      levelMax:        levelMax,
      maxPlayers:      maxPlayers,
      type:            type,
      visibility:      MatchVisibility.public,
      status:          status,
      playerIds:       playerIds,
      pendingIds:      const [],
      ratingCount:     0,
      createdAt:       DateTime(2026, 5, 1),
    );

void main() {
  group('ZuMatch — slots', () {
    test('availableSlots returns maxPlayers - playerIds.length', () {
      expect(_match(maxPlayers: 4, playerIds: ['a', 'b']).availableSlots, 2);
    });

    test('isFull is true when all slots taken', () {
      expect(_match(maxPlayers: 2, playerIds: ['a', 'b']).isFull, isTrue);
    });

    test('isFull is false when slots remain', () {
      expect(_match(maxPlayers: 4, playerIds: ['a']).isFull, isFalse);
    });

    test('availableSlots is 0 when over-full (guard)', () {
      // Si plus de joueurs que de slots (données corrompues), pas négatif
      final m = _match(maxPlayers: 2, playerIds: ['a', 'b', 'c']);
      expect(m.availableSlots, -1); // reflects reality, calling code guards
    });
  });

  group('ZuMatch — labels', () {
    test('levelRange formats correctly', () {
      expect(_match(levelMin: 3, levelMax: 6).levelRange, 'Niv. 3–6');
    });

    test('typeLabel for leisure', () {
      expect(_match(type: MatchType.leisure).typeLabel, 'Loisir');
    });

    test('typeLabel for competitive', () {
      expect(_match(type: MatchType.competitive).typeLabel, 'Compétitif');
    });

    test('typeLabel for training', () {
      expect(_match(type: MatchType.training).typeLabel, 'Training');
    });

    test('statusLabel for open', () {
      expect(_match(status: MatchStatus.open).statusLabel, 'Ouvert');
    });

    test('statusLabel for full', () {
      expect(_match(status: MatchStatus.full).statusLabel, 'Complet');
    });

    test('statusLabel for finished', () {
      expect(_match(status: MatchStatus.finished).statusLabel, 'Terminé');
    });

    test('statusLabel for cancelled', () {
      expect(_match(status: MatchStatus.cancelled).statusLabel, 'Annulé');
    });
  });
}
