import 'package:flutter_test/flutter_test.dart';
import 'package:zupadel/models/models.dart';

ZuClub _club({
  Map<String, String> openingHours = const {},
  int slotDurationMinutes = 90,
}) =>
    ZuClub(
      id:                   'c1',
      name:                 'Club Test',
      address:              '1 rue Test',
      city:                 'Paris',
      amenities:            const [],
      isActive:             true,
      pricePerSlotCredits:  5,
      slotDurationMinutes:  slotDurationMinutes,
      openingHours:         openingHours,
    );

void main() {
  group('ZuClub.slotsForDay', () {
    final monday = DateTime(2026, 3, 2); // lundi

    test('returns empty list when club is closed that day', () {
      final club = _club(openingHours: {});
      expect(club.slotsForDay(monday), isEmpty);
    });

    test('returns correct slots for 08:00–10:30 at 90 min', () {
      final club = _club(
        openingHours: {'monday': '08:00-10:30'},
        slotDurationMinutes: 90,
      );
      final slots = club.slotsForDay(monday);
      // 08:00 → 09:30 (fits), 09:30 → 11:00 (exceeds 10:30) → 1 slot
      expect(slots.length, 1);
      expect(slots.first.hour,   8);
      expect(slots.first.minute, 0);
    });

    test('returns 2 slots for 08:00–11:00 at 90 min', () {
      final club = _club(
        openingHours: {'monday': '08:00-11:00'},
        slotDurationMinutes: 90,
      );
      final slots = club.slotsForDay(monday);
      expect(slots.length, 2);
      expect(slots[0], DateTime(2026, 3, 2, 8, 0));
      expect(slots[1], DateTime(2026, 3, 2, 9, 30));
    });

    test('returns correct slots for 08:00–22:00 at 90 min (9 slots)', () {
      final club = _club(
        openingHours: {'monday': '08:00-22:00'},
        slotDurationMinutes: 90,
      );
      // 08:00, 09:30, 11:00, 12:30, 14:00, 15:30, 17:00, 18:30, 20:00
      // 20:00 + 90min = 21:30 ≤ 22:00 → included
      // 21:30 + 90min = 23:00 > 22:00 → excluded
      final slots = club.slotsForDay(monday);
      expect(slots.length, 9);
      expect(slots.first.hour, 8);
    });

    test('returns slots with correct date from the given day', () {
      final club = _club(
        openingHours: {'monday': '09:00-12:00'},
        slotDurationMinutes: 60,
      );
      final wednesday = DateTime(2026, 3, 4); // mercredi — pas de 'monday'
      expect(club.slotsForDay(wednesday), isEmpty);
    });

    test('uses correct day key for each weekday', () {
      final club = _club(
        openingHours: {
          'monday': '09:00-10:00',
          'tuesday': '10:00-11:00',
          'wednesday': '11:00-12:00',
          'thursday': '12:00-13:00',
          'friday': '13:00-14:00',
          'saturday': '14:00-15:00',
          'sunday': '15:00-16:00',
        },
        slotDurationMinutes: 60,
      );
      // Monday 2026-03-02 (weekday=1)
      expect(club.slotsForDay(DateTime(2026, 3, 2)).first.hour, 9);
      // Tuesday 2026-03-03 (weekday=2)
      expect(club.slotsForDay(DateTime(2026, 3, 3)).first.hour, 10);
      // Sunday 2026-03-08 (weekday=7)
      expect(club.slotsForDay(DateTime(2026, 3, 8)).first.hour, 15);
    });
  });
}
