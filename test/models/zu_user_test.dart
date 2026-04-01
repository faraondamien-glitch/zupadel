import 'package:flutter_test/flutter_test.dart';
import 'package:zupadel/models/models.dart';

ZuUser _user({
  String firstName = 'Alice',
  String lastName  = 'Dupont',
  int credits      = 10,
}) =>
    ZuUser(
      id:            'u1',
      firstName:     firstName,
      lastName:      lastName,
      email:         'alice@test.com',
      level:         3,
      credits:       credits,
      referralCode:  'ALICE42',
      referralCount: 0,
      createdAt:     DateTime(2026, 1, 1),
    );

void main() {
  group('ZuUser — computed properties', () {
    test('displayName returns firstName', () {
      expect(_user().displayName, 'Alice');
    });

    test('fullName returns "Prénom Nom"', () {
      expect(_user().fullName, 'Alice Dupont');
    });

    test('initials returns uppercase first chars', () {
      expect(_user().initials, 'AD');
    });

    test('initials with single-char name', () {
      expect(_user(firstName: 'A', lastName: 'B').initials, 'AB');
    });

    test('initials with empty firstName returns only last initial', () {
      expect(_user(firstName: '', lastName: 'Dupont').initials, 'D');
    });

    test('initials with empty lastName returns only first initial', () {
      expect(_user(firstName: 'Alice', lastName: '').initials, 'A');
    });
  });

  group('ZuUser — copyWith', () {
    test('copyWith credits updates credits only', () {
      final u = _user(credits: 5).copyWith(credits: 20);
      expect(u.credits, 20);
      expect(u.firstName, 'Alice');
      expect(u.level, 3);
    });

    test('copyWith level updates level only', () {
      final u = _user().copyWith(level: 7);
      expect(u.level, 7);
      expect(u.credits, 10);
    });
  });
}
