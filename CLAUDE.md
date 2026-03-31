# CLAUDE.md — Zupadel

Fichier de contexte persistant pour Claude Code. À mettre à jour après chaque session de debug ou ajout de feature importante.

---

## Projet

Application Flutter mobile de padel (iOS + Android + Web).
- **Nom** : Zupadel
- **Bundle ID iOS** : `com.example.zupadel`
- **Firebase project** : `zupadel2`
- **Branch de dev actuelle** : `claude/fix-stripe-mac-catalyst-pMtOr`

---

## Stack technique

| Domaine | Technologie |
|---|---|
| UI | Flutter 3.x, Riverpod 2, GoRouter 13 |
| Backend | Firebase (Auth, Firestore, Functions, Storage, Messaging) |
| Paiement | flutter_stripe 10.x |
| Navigation | go_router + ShellRoute (bottom nav) |
| Charts | fl_chart |
| Fonts | Google Fonts (Syne, DM Sans) |

---

## Architecture Flutter

```
lib/
  main.dart              # EntryPoint, Firebase.initializeApp, Stripe setup
  firebase_options.dart  # Config générée par FlutterFire CLI (clés iOS/Android/Web)
  router.dart            # GoRouter + LoginScreen + RegisterScreen + MainShell
  theme/zu_theme.dart    # Thème global (dark, accent vert #4EE06E)
  models/models.dart     # Tous les modèles de données
  services/services.dart # Tous les services (Auth, Firestore, Stripe, etc.)
  screens/
    home_screen.dart     # Dashboard principal
    match_screens.dart   # Matchs (liste, création, détail, post-match)
    other_screens.dart   # Tournois, Coaching, Profil, Crédits
  widgets/widgets.dart   # Composants réutilisables (ZuButton, ZuCard, etc.)
  assets/
    images/   # (vide — créer ici les images)
    icons/    # (vide — créer ici les icônes SVG)
    animations/ # (vide — créer ici les Lottie JSON)
```

---

## iOS — Points critiques

### Architecture AppDelegate (IMPORTANT)
Utilise le pattern **FlutterAppDelegate classique** (PAS FlutterSceneDelegate).

**Raison** : L'architecture scene-based (`FlutterSceneDelegate` + `FlutterImplicitEngineDelegate`) provoque une race condition — Dart exécute `Firebase.initializeApp()` avant que `GeneratedPluginRegistrant` soit appelé côté natif → `PlatformException(channel-error)`.

**AppDelegate.swift correct** :
```swift
import Flutter
import UIKit
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()                        // 1. Firebase natif
    GeneratedPluginRegistrant.register(with: self) // 2. Tous les plugins
    return super.application(application, didFinishLaunchingWithOptions: launchOptions) // 3. Engine Flutter
  }
}
```

**SceneDelegate.swift** : UIResponder vide (non utilisé).
**Info.plist** : PAS de `UIApplicationSceneManifest`.

### GoogleService-Info.plist
- Présent dans `ios/Runner/GoogleService-Info.plist`
- Versionné dans le repo (les clés sont déjà publiques via `firebase_options.dart`)
- Généré depuis les valeurs de `firebase_options.dart` (projet `zupadel2`)

### Stripe iOS
- `ephemeralKeySecret` → s'appelle `customerEphemeralKeySecret` dans `stripe_platform_interface` 10.2.0
- Les warnings Mac Catalyst (`#if !TARGET_OS_MACCATALYST`) viennent des Pods Stripe — **ce sont des warnings, pas des erreurs**, ne pas modifier les Pods

---

## Android

- `android/app/google-services.json` est dans `.gitignore` — à récupérer depuis la console Firebase si manquant

---

## Commandes utiles

```bash
# Lancer sur simulateur iOS
flutter run

# Lancer sur Chrome
flutter run -d chrome

# Clean build (après changements natifs iOS)
flutter clean && flutter run

# Générer les providers Riverpod
dart run build_runner build --delete-conflicting-outputs
```

---

## Erreurs connues et solutions

### `PlatformException(channel-error)` Firebase
- **Cause** : Mauvaise architecture AppDelegate (scene-based) ou `GoogleService-Info.plist` manquant
- **Solution** : Vérifier AppDelegate.swift (pattern ci-dessus) + présence du plist

### `Directives must appear before any declarations`
- **Cause** : Imports placés après une déclaration de fonction dans un fichier Dart
- **Solution** : Déplacer tous les `import` en haut du fichier

### `No named parameter 'ephemeralKeySecret'`
- **Cause** : Changement d'API Stripe 10.x
- **Solution** : Remplacer par `customerEphemeralKeySecret`

### `'StripeException' isn't a type`
- **Cause** : Import `flutter_stripe` manquant dans le fichier
- **Solution** : Ajouter `import 'package:flutter_stripe/flutter_stripe.dart';`

### Assets manquants au build
- **Cause** : Dossiers `assets/images/`, `assets/icons/`, `assets/animations/` référencés dans pubspec.yaml mais absents
- **Solution** : `mkdir -p assets/images assets/icons assets/animations && touch assets/**/.gitkeep`

### Crash null sur `fromFirestore` (Timestamp)
- **Cause** : `(d['createdAt'] as Timestamp).toDate()` crash si le champ est null (optimistic write Firestore avec `FieldValue.serverTimestamp()` — premier snapshot avant écriture serveur)
- **Solution** : Toujours utiliser `(d['field'] as Timestamp?)?.toDate() ?? DateTime.now()` dans tous les modèles

### Erreur Firestore sur `watchMyMatches`
- **Cause** : `arrayContains` + `whereIn` + `orderBy` sur des champs différents nécessite un index composite Firestore non créé
- **Solution** : Filtrer côté client — utiliser seulement `arrayContains` + `orderBy` dans la requête, puis `.where()` Dart sur les résultats

---

## À faire / Roadmap MVP

- [ ] Écrans Tournois (détail + inscription)
- [ ] Écran Finish Match (saisie score)
- [ ] Notifications push (FCM configuré, handlers à brancher sur les écrans)
- [ ] Upload photo profil (firebase_storage prêt)
- [ ] Tests unitaires services

---

## Mise à jour de ce fichier

Mettre à jour ce fichier après chaque :
- Bug iOS/Android résolu (ajouter dans "Erreurs connues")
- Changement d'architecture significatif
- Nouvelle dépendance ajoutée
- Décision technique importante
