import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/home_screen.dart';
import '../screens/match_screens.dart';
import '../screens/other_screens.dart';
import '../services/services.dart';
import '../theme/zu_theme.dart';
import '../widgets/widgets.dart';

Future<void> _saveFcmToken(String uid) async {
  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'fcmToken': token,
    });
  }
}

// ══════════════════════════════════════════════
//  ROUTER
// ══════════════════════════════════════════════

/// Clé globale pour la navigation depuis les notifications FCM
final routerNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: routerNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = auth.valueOrNull != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      if (!isLoggedIn && !isAuthRoute) return '/auth/login';
      if (isLoggedIn && isAuthRoute) return '/';
      return null;
    },
    routes: [
      // Shell avec bottom nav
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/matches', builder: (_, __) => const MatchListScreen()),
          GoRoute(path: '/tournaments', builder: (_, __) => const TournamentListScreen()),
          GoRoute(path: '/coaching', builder: (_, __) => const CoachListScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(path: '/credits', builder: (_, __) => const CreditsScreen()),
        ],
      ),
      // Routes hors shell
      GoRoute(
        path: '/matches/create',
        builder: (_, __) => const CreateMatchScreen(),
      ),
      GoRoute(
        path: '/matches/:id',
        builder: (_, state) => MatchDetailScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/matches/:id/finish',
        builder: (_, state) => _FinishMatchScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/matches/:id/review',
        builder: (_, state) => PostMatchReviewScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/tournaments/:id',
        builder: (_, state) => _TournamentDetailScreen(tournamentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/tournaments/:id/register',
        builder: (_, state) => TournamentRegisterScreen(tournamentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/profile/share-stats',
        builder: (_, __) => const ShareStatsScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, __) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/coaching/:id',
        builder: (_, state) => CoachDetailScreen(coachId: state.pathParameters['id']!),
      ),
      // Auth
      GoRoute(path: '/auth/login',    builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),
    ],
  );
});

// ══════════════════════════════════════════════
//  MAIN SHELL (Bottom Nav)
// ══════════════════════════════════════════════

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = ['/', '/matches', '/tournaments', '/coaching', '/profile'];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _tabs.indexWhere((t) => location == t || (t != '/' && location.startsWith(t)));
    final currentIdx = idx < 0 ? 0 : idx;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: ZuTheme.bgSurface,
          border: Border(top: BorderSide(color: ZuTheme.borderColor)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIdx,
          backgroundColor: Colors.transparent,
          elevation: 0,
          onTap: (i) => context.go(_tabs[i]),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded),             label: 'Accueil'),
            BottomNavigationBarItem(icon: Icon(Icons.sports_tennis_rounded),    label: 'Matchs'),
            BottomNavigationBarItem(icon: Icon(Icons.emoji_events_rounded),     label: 'Tournois'),
            BottomNavigationBarItem(icon: Icon(Icons.fitness_center_rounded),   label: 'Coaching'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded),           label: 'Profil'),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  AUTH SCREENS
// ══════════════════════════════════════════════

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading    = false;
  bool _obscure    = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 48),
            // Logo
            Text(
              'ZUPADEL',
              style: GoogleFonts.syne(
                fontSize: 40, fontWeight: FontWeight.w800, color: ZuTheme.accent,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Le padel, simplement.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: ZuTheme.textSecondary),
            ),
            const SizedBox(height: 48),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) => v?.contains('@') == true ? null : 'Email invalide',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v?.length ?? 0) >= 6 ? null : 'Minimum 6 caractères',
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: Text(
                        'Mot de passe oublié ?',
                        style: GoogleFonts.dmSans(fontSize: 12, color: ZuTheme.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ZuButton(
                    label: 'Se connecter',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('ou', style: Theme.of(context).textTheme.bodySmall),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ZuButton(
                    label: 'Créer un compte',
                    outlined: true,
                    onPressed: () => context.go('/auth/register'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final cred = await ref.read(authServiceProvider).signInWithEmail(
        _emailCtrl.text.trim(),
        _passCtrl.text,
      );
      await _saveFcmToken(cred.user!.uid);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_authError(e.code))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authError(String code) => switch (code) {
    'user-not-found'  => 'Aucun compte avec cet email',
    'wrong-password'  => 'Mot de passe incorrect',
    'too-many-requests' => 'Trop de tentatives. Réessaie plus tard.',
    _ => 'Erreur de connexion',
  };
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _referralCtrl  = TextEditingController();
  bool _loading        = false;
  bool _obscure        = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _firstNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Prénom',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => (v?.length ?? 0) >= 2 ? null : 'Minimum 2 caractères',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _lastNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => (v?.length ?? 0) >= 2 ? null : 'Minimum 2 caractères',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) => v?.contains('@') == true ? null : 'Email invalide',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v?.length ?? 0) >= 6 ? null : 'Minimum 6 caractères',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _referralCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Code parrainage (optionnel)',
                    prefixIcon: Icon(Icons.card_giftcard_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ZuTheme.accent.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ZuTheme.accent.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Text('🎁', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '10 crédits offerts à l\'inscription !',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ZuTheme.accent, fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ZuButton(
                  label: 'Créer mon compte',
                  loading: _loading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final cred = await ref.read(authServiceProvider).registerWithEmail(
        _emailCtrl.text.trim(),
        _passCtrl.text,
      );
      await ref.read(userServiceProvider).createUser(
        uid:          cred.user!.uid,
        email:        _emailCtrl.text.trim(),
        firstName:    _firstNameCtrl.text.trim(),
        lastName:     _lastNameCtrl.text.trim(),
        referralCode: _referralCtrl.text.trim().isEmpty ? null : _referralCtrl.text.trim(),
      );
      await _saveFcmToken(cred.user!.uid);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Placeholders ─────────────────────────────────────────────────

class _FinishMatchScreen extends StatelessWidget {
  final String matchId;
  const _FinishMatchScreen({required this.matchId});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Terminer le match')),
    body: const Center(child: Text('Saisie du score — TODO')),
  );
}

class _TournamentDetailScreen extends StatelessWidget {
  final String tournamentId;
  const _TournamentDetailScreen({required this.tournamentId});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tournoi')),
    body: const Center(child: Text('Détail tournoi — TODO')),
  );
}

// Needed import for FirebaseAuthException usage in login

