import 'package:flutter_test/flutter_test.dart';
import 'package:zupadel/models/models.dart';

ZuTournament _tournament({
  TournamentStatus status = TournamentStatus.published,
  int maxPlayers = 16,
  List<String> registeredIds = const [],
  double entryFee = 0,
}) =>
    ZuTournament(
      id:             't1',
      organizerId:    'u1',
      title:          'Open Test',
      club:           'Club Test',
      level:          'P250',
      startDate:      DateTime(2026, 7, 1),
      endDate:        DateTime(2026, 7, 3),
      category:       'Mixte',
      surface:        'Indoor',
      maxPlayers:     maxPlayers,
      entryFee:       entryFee,
      description:    'Test',
      contactName:    'Bob',
      contactEmail:   'bob@test.com',
      status:         status,
      registeredIds:  registeredIds,
      createdAt:      DateTime(2026, 1, 1),
    );

void main() {
  group('ZuTournament — computed properties', () {
    test('spotsLeft returns maxPlayers - registeredIds.length', () {
      expect(
        _tournament(maxPlayers: 16, registeredIds: ['a', 'b', 'c']).spotsLeft,
        13,
      );
    });

    test('isOpen is true when published and spots remain', () {
      expect(
        _tournament(status: TournamentStatus.published, maxPlayers: 16).isOpen,
        isTrue,
      );
    });

    test('isOpen is false when status is pending', () {
      expect(
        _tournament(status: TournamentStatus.pending).isOpen,
        isFalse,
      );
    });

    test('isOpen is false when full (no spots left)', () {
      final ids = List.generate(16, (i) => 'p$i');
      expect(
        _tournament(maxPlayers: 16, registeredIds: ids).isOpen,
        isFalse,
      );
    });

    test('isFree is true when entryFee is 0', () {
      expect(_tournament(entryFee: 0).isFree, isTrue);
    });

    test('isFree is false when entryFee > 0', () {
      expect(_tournament(entryFee: 25).isFree, isFalse);
    });
  });
}
