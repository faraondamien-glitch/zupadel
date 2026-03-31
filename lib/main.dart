import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme/zu_theme.dart';
import 'router.dart';
import 'firebase_options.dart';

// ⚠️ Remplace par ta clé publique Stripe (dashboard.stripe.com → Développeurs → Clés API)
const _stripePublishableKey = 'pk_live_51SjfxgECr8fTdsDdlKJHv6At70VCQ5MEqRQUN0H1wIPvxgW34Wb6Ij4IGb9NS0UddlJEwPQj88A2LrcoQcgIF0d300cQ2jydVe';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Stripe (web uniquement — iOS/Android utilisent Apple IAP / Google Play)
  if (kIsWeb) {
    Stripe.publishableKey = _stripePublishableKey;
    await Stripe.instance.applySettings();
  }

  // Notifications push
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await _initFcm();

  // Locale française pour les dates
  await initializeDateFormatting('fr_FR', null);

  runApp(
    const ProviderScope(
      child: ZupadelApp(),
    ),
  );
}

Future<void> _initFcm() async {
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  final token = await messaging.getToken();
  final user = FirebaseAuth.instance.currentUser;
  if (token != null && user != null) {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'fcmToken': token,
    });
  }

  // Rafraîchir le token si renouvelé
  messaging.onTokenRefresh.listen((newToken) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': newToken,
      });
    }
  });
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
