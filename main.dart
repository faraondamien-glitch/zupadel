import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme/zu_theme.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Barre de statut transparente
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: ZuTheme.bgSurface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Portrait uniquement
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Firebase
  await Firebase.initializeApp();

  // Locale française pour les dates
  await initializeDateFormatting('fr_FR', null);

  runApp(
    const ProviderScope(
      child: ZupadelApp(),
    ),
  );
}

class ZupadelApp extends ConsumerWidget {
  const ZupadelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Zupadel',
      debugShowCheckedModeBanner: false,
      theme: ZuTheme.theme,
      routerConfig: router,
      builder: (context, child) {
        // Force le texte à ne pas grossir selon les préférences système
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        );
      },
    );
  }
}
