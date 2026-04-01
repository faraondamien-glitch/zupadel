// Smoke test — vérifie que l'app démarre sans crash en mode test.
// Firebase et Stripe ne sont pas initialisés ici, donc on teste
// uniquement que ZuTheme et les widgets de base sont valides.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zupadel/theme/zu_theme.dart';

void main() {
  testWidgets('ZuTheme — scaffold avec thème Zupadel', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ZuTheme.theme,
        home: const Scaffold(
          body: Center(child: Text('Zupadel')),
        ),
      ),
    );
    expect(find.text('Zupadel'), findsOneWidget);
  });
}
