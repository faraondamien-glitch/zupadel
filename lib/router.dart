import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../screens/home_screen.dart';
import '../screens/match_screens.dart';
import '../screens/messages_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/other_screens.dart';
import '../services/services.dart';
import '../theme/zu_theme.dart';
import '../widgets/widgets.dart';

Future<void> _saveFcmToken(String uid) async {
  if (kIsWeb) return;
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': token,
      });
    }
  } catch (_) {
    // Pas de certificat APNS sur simulateur — ignoré
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
          GoRoute(path: '/messages', builder: (_, __) => const MessagesScreen()),
          GoRoute(path: '/clubs', builder: (_, __) => const ClubListScreen()),
          GoRoute(path: '/leaderboard', builder: (_, __) => const LeaderboardScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      // Routes hors shell — avec bouton retour
      GoRoute(path: '/credits', builder: (_, __) => const CreditsScreen()),
      // Routes terrains
      GoRoute(
        path: '/clubs/:clubId',
        builder: (_, state) => ClubDetailScreen(clubId: state.pathParameters['clubId']!),
      ),
      GoRoute(
        path: '/clubs/:clubId/courts/:courtId',
        builder: (_, state) => CourtSlotsScreen(
          clubId:  state.pathParameters['clubId']!,
          courtId: state.pathParameters['courtId']!,
        ),
      ),
      GoRoute(
        path: '/clubs/:clubId/courts/:courtId/book',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return BookSlotScreen(
            clubId:  state.pathParameters['clubId']!,
            courtId: state.pathParameters['courtId']!,
            slot:    extra['slot'] as DateTime,
            club:    extra['club'] as ZuClub,
            court:   extra['court'] as ZuCourt,
          );
        },
      ),
      GoRoute(
        path: '/clubs/:clubId/reservations/:resId',
        builder: (_, state) => ReservationConfirmScreen(
          reservationId: state.pathParameters['resId']!,
        ),
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
        path: '/messages/:id',
        builder: (_, state) => ConversationScreen(convId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/matches/:id/finish',
        builder: (_, state) => FinishMatchScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/matches/:id/review',
        builder: (_, state) => PostMatchReviewScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/tournaments',
        builder: (_, __) => const TournamentListScreen(),
      ),
      GoRoute(
        path: '/tournaments/:id',
        builder: (_, state) => TournamentDetailScreen(tournamentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/players/:uid',
        builder: (_, state) => PlayerProfileScreen(uid: state.pathParameters['uid']!),
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
        path: '/profile/edit',
        builder: (_, __) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, __) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/my-reservations',
        builder: (_, __) => const MyReservationsScreen(),
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

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = ['/', '/matches', '/messages', '/clubs', '/leaderboard', '/profile'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location   = GoRouterState.of(context).matchedLocation;
    final idx        = _tabs.indexWhere((t) => location == t || (t != '/' && location.startsWith(t)));
    final currentIdx = idx < 0 ? 0 : idx;
    final unread     = ref.watch(unreadTotalProvider);

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
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home_rounded),          label: 'Accueil'),
            const BottomNavigationBarItem(icon: Icon(Icons.sports_tennis_rounded), label: 'Matchs'),
            BottomNavigationBarItem(
              label: 'Messages',
              icon: unread > 0
                  ? Badge(
                      label: Text(unread > 9 ? '9+' : '$unread',
                        style: GoogleFonts.syne(fontSize: 9, fontWeight: FontWeight.w800)),
                      backgroundColor: ZuTheme.accent,
                      textColor: ZuTheme.bgPrimary,
                      child: const Icon(Icons.chat_bubble_outline_rounded),
                    )
                  : const Icon(Icons.chat_bubble_outline_rounded),
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded),         label: 'Terrains'),
            const BottomNavigationBarItem(icon: Icon(Icons.leaderboard_rounded),      label: 'Classement'),
            const BottomNavigationBarItem(icon: Icon(Icons.person_rounded),           label: 'Profil'),
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
  bool _loading       = false;
  bool _loadingGoogle = false;
  bool _loadingApple  = false;
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
                      onPressed: _sendPasswordReset,
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
                  const SizedBox(height: 20),
                  _OrDivider(),
                  const SizedBox(height: 16),
                  _SocialButton.google(
                    loading: _loadingGoogle,
                    onPressed: _signInWithGoogle,
                  ),
                  if (AuthService.isAppleSignInAvailable) ...[
                    const SizedBox(height: 10),
                    _SocialButton.apple(
                      loading: _loadingApple,
                      onPressed: _signInWithApple,
                    ),
                  ],
                  const SizedBox(height: 20),
                  _OrDivider(),
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

  Future<void> _sendPasswordReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisis ton email d\'abord.')),
      );
      return;
    }
    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email de réinitialisation envoyé à $email')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_authError(e.code))),
        );
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loadingGoogle = true);
    try {
      final cred = await ref.read(authServiceProvider).signInWithGoogle();
      if (cred == null) return;
      await _handleSocialSignIn(cred);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connexion Google échouée : $e')));
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _loadingApple = true);
    try {
      final cred = await ref.read(authServiceProvider).signInWithApple();
      if (cred == null) return;
      await _handleSocialSignIn(cred);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connexion Apple échouée : $e')));
    } finally {
      if (mounted) setState(() => _loadingApple = false);
    }
  }

  Future<void> _handleSocialSignIn(UserCredential cred) async {
    final uid = cred.user!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) {
      // Première connexion sociale → crée le profil
      final displayName = cred.user!.displayName ?? '';
      final parts       = displayName.split(' ');
      final firstName   = parts.isNotEmpty ? parts.first : 'Joueur';
      final lastName    = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      await ref.read(userServiceProvider).createUser(
        uid:       uid,
        email:     cred.user!.email ?? '',
        firstName: firstName,
        lastName:  lastName,
        photoUrl:  cred.user!.photoURL,
      );
    }
    await _saveFcmToken(uid);
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
  bool _loadingGoogle  = false;
  bool _loadingApple   = false;
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
                const SizedBox(height: 20),
                _OrDivider(),
                const SizedBox(height: 16),
                _SocialButton.google(
                  loading: _loadingGoogle,
                  onPressed: _signInWithGoogle,
                ),
                if (AuthService.isAppleSignInAvailable) ...[
                  const SizedBox(height: 10),
                  _SocialButton.apple(
                    loading: _loadingApple,
                    onPressed: _signInWithApple,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loadingGoogle = true);
    try {
      final cred = await ref.read(authServiceProvider).signInWithGoogle();
      if (cred == null) return;
      await _handleSocialSignIn(cred);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connexion Google échouée : $e')));
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _loadingApple = true);
    try {
      final cred = await ref.read(authServiceProvider).signInWithApple();
      if (cred == null) return;
      await _handleSocialSignIn(cred);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connexion Apple échouée : $e')));
    } finally {
      if (mounted) setState(() => _loadingApple = false);
    }
  }

  Future<void> _handleSocialSignIn(UserCredential cred) async {
    final uid = cred.user!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) {
      final displayName = cred.user!.displayName ?? '';
      final parts       = displayName.split(' ');
      final firstName   = parts.isNotEmpty ? parts.first : 'Joueur';
      final lastName    = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      await ref.read(userServiceProvider).createUser(
        uid:       uid,
        email:     cred.user!.email ?? '',
        firstName: firstName,
        lastName:  lastName,
        photoUrl:  cred.user!.photoURL,
      );
    }
    await _saveFcmToken(uid);
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

// ══════════════════════════════════════════════
//  SHARED AUTH WIDGETS
// ══════════════════════════════════════════════

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('ou', style: Theme.of(context).textTheme.bodySmall),
      ),
      const Expanded(child: Divider()),
    ],
  );
}

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final bool loading;
  final VoidCallback? onPressed;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
    required this.loading,
    required this.onPressed,
  });

  factory _SocialButton.google({
    required bool loading,
    required VoidCallback? onPressed,
  }) => _SocialButton(
    label: 'Continuer avec Google',
    icon: _GoogleIcon(),
    backgroundColor: Colors.white,
    textColor: const Color(0xFF3C4043),
    borderColor: const Color(0xFFDADCE0),
    loading: loading,
    onPressed: onPressed,
  );

  factory _SocialButton.apple({
    required bool loading,
    required VoidCallback? onPressed,
  }) => _SocialButton(
    label: 'Continuer avec Apple',
    icon: const Icon(Icons.apple_rounded, color: Colors.white, size: 20),
    backgroundColor: Colors.black,
    textColor: Colors.white,
    borderColor: Colors.black,
    loading: loading,
    onPressed: onPressed,
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 48,
    child: OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: backgroundColor,
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: loading
          ? SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: textColor.withOpacity(0.7),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.syne(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
    ),
  );
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 20, height: 20,
    child: CustomPaint(painter: _GoogleLogoPainter()),
  );
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Clip to circle
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    // White background
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);

    // Draw the 4 colored arcs of the Google "G"
    const strokeW = 3.5;
    final rect    = Rect.fromCircle(center: center, radius: radius * 0.72);

    void arc(double start, double sweep, Color color) {
      canvas.drawArc(
        rect, start, sweep, false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round,
      );
    }

    const pi = 3.14159265;
    // Red top-right
    arc(-0.35, 1.2, const Color(0xFFEA4335));
    // Yellow bottom
    arc(0.85, 1.0, const Color(0xFFFBBC05));
    // Green bottom-left
    arc(1.85, 0.7, const Color(0xFF34A853));
    // Blue left-top
    arc(2.55, 1.0, const Color(0xFF4285F4));

    // Horizontal bar of the "G"
    final barY = center.dy + radius * 0.03;
    canvas.drawLine(
      Offset(center.dx, barY),
      Offset(center.dx + radius * 0.72, barY),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


