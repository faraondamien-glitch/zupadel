import 'package:flutter_test/flutter_test.dart';
import 'package:zupadel/models/models.dart';

UserAvailability _avail({
  required bool isAvailable,
  required DateTime expiresAt,
}) =>
    UserAvailability(
      userId:      'u1',
      isAvailable: isAvailable,
      expiresAt:   expiresAt,
      level:       3,
      updatedAt:   DateTime.now(),
    );

void main() {
  group('UserAvailability.isStillValid', () {
    test('returns true when available and not expired', () {
      final avail = _avail(
        isAvailable: true,
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
      );
      expect(avail.isStillValid, isTrue);
    });

    test('returns false when expired', () {
      final avail = _avail(
        isAvailable: true,
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(avail.isStillValid, isFalse);
    });

    test('returns false when isAvailable is false (even if not expired)', () {
      final avail = _avail(
        isAvailable: false,
        expiresAt: DateTime.now().add(const Duration(hours: 3)),
      );
      expect(avail.isStillValid, isFalse);
    });

    test('returns false when both expired and not available', () {
      final avail = _avail(
        isAvailable: false,
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(avail.isStillValid, isFalse);
    });

    test('expiry exactly at now is considered expired', () {
      // expiresAt == now → isAfter returns false → not valid
      final now = DateTime.now();
      // We can't freeze time perfectly, but expiresAt in the past by a tiny bit
      final avail = _avail(
        isAvailable: true,
        expiresAt: now.subtract(const Duration(milliseconds: 1)),
      );
      expect(avail.isStillValid, isFalse);
    });
  });
}
