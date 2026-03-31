import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../theme/zu_theme.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import '../services/services.dart';

// ══════════════════════════════════════════════
//  TOURNOIS
// ══════════════════════════════════════════════

class TournamentListScreen extends ConsumerStatefulWidget {
  const TournamentListScreen({super.key});

  @override
  ConsumerState<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends ConsumerState<TournamentListScreen> {
  String? _levelFilter;
  String? _surfaceFilter;
  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final tournaments = ref.watch(tournamentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournois'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/tournaments/create'),
            icon: const Icon(Icons.add, size: 18),
            label: Text('Créer', style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(foregroundColor: ZuTheme.accent),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                _Chip('Tous niveaux', _levelFilter == null, () => setState(() => _levelFilter = null)),
                const SizedBox(width: 8),
                ...['P250', 'P500', 'P1000', 'P2000'].map((l) =>
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Chip(l, _levelFilter == l, () => setState(() =>
                      _levelFilter = _levelFilter == l ? null : l)),
                  ),
                ),
                _Chip('Indoor', _surfaceFilter == 'Indoor', () => setState(() =>
                  _surfaceFilter = _surfaceFilter == 'Indoor' ? null : 'Indoor')),
                const SizedBox(width: 8),
                _Chip('Outdoor', _surfaceFilter == 'Outdoor', () => setState(() =>
                  _surfaceFilter = _surfaceFilter == 'Outdoor' ? null : 'Outdoor')),
              ],
            ),
          ),
          Expanded(
            child: tournaments.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (list) {
                final filtered = list.where((t) {
                  if (_levelFilter != null && t.level != _levelFilter) return false;
                  if (_surfaceFilter != null && t.surface != _surfaceFilter) return false;
                  return true;
                }).toList();

                return filtered.isEmpty
                    ? ZuEmptyState(
                        emoji: '🏆',
                        title: 'Aucun tournoi',
                        subtitle: 'Organise le premier tournoi de ta région !',
                        buttonLabel: 'Créer un tournoi',
                        onButton: () => context.go('/tournaments/create'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ZuTournamentCard(
                            tournament: filtered[i],
                            onTap: () => context.go('/tournaments/${filtered[i].id}'),
                            onRegister: filtered[i].isOpen
                                ? () => context.go('/tournaments/${filtered[i].id}/register')
                                : null,
                          ),
                        ),
                      );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TournamentRegisterScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  const TournamentRegisterScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<TournamentRegisterScreen> createState() => _TournamentRegisterScreenState();
}

class _TournamentRegisterScreenState extends ConsumerState<TournamentRegisterScreen> {
  final _licenseController = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tournamentDetailProvider(widget.tournamentId));
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Inscription')),
      body: t.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('$e')),
        data: (tournament) => tournament == null
            ? const Center(child: Text('Tournoi introuvable'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ZuCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              tournament.level,
                              style: GoogleFonts.syne(
                                fontSize: 22, fontWeight: FontWeight.w800, color: ZuTheme.accentGold,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(tournament.title, style: Theme.of(context).textTheme.headlineMedium)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 6,
                          children: [
                            ZuTag(tournament.category, style: ZuTagStyle.blue),
                            ZuTag(tournament.surface,  style: ZuTagStyle.neutral),
                            ZuTag(
                              DateFormat('d MMM', 'fr_FR').format(tournament.startDate),
                              style: ZuTagStyle.green,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  ZuSectionTitle('Informations'),
                  const SizedBox(height: 8),
                  ZuCard(
                    child: Column(
                      children: [
                        _FormField(
                          label: 'Prénom Nom',
                          value: user?.fullName ?? '',
                          readOnly: true,
                        ),
                        const Divider(height: 16),
                        TextFormField(
                          controller: _licenseController
                            ..text = user?.fftLicense ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Numéro de licence FFT',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FormField(
                          label: 'Classement FFT',
                          value: user?.fftRank ?? 'Non renseigné',
                          readOnly: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  ZuCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Prix d\'inscription', style: Theme.of(context).textTheme.headlineSmall),
                              const SizedBox(height: 3),
                              Text(
                                tournament.isFree
                                    ? 'Tournoi gratuit'
                                    : 'Commission Zupadel 10% incluse',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              tournament.isFree ? 'Gratuit' : '${tournament.entryFee.toStringAsFixed(0)}€',
                              style: GoogleFonts.syne(
                                fontSize: 20, fontWeight: FontWeight.w800,
                                color: tournament.isFree ? ZuTheme.accent : ZuTheme.textPrimary,
                              ),
                            ),
                            if (!tournament.isFree)
                              Text('via Stripe', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ZuTheme.accent.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ZuTheme.accent.withOpacity(0.2)),
                    ),
                    child: Text(
                      '⚡ Ta candidature sera examinée par l\'organisateur. Tu seras notifié par email et notification push.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ZuTheme.accent),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ZuButton(
                    label: tournament.isFree
                        ? 'S\'inscrire gratuitement'
                        : 'Payer ${tournament.entryFee.toStringAsFixed(0)}€ et s\'inscrire',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final paid = await ref.read(tournamentServiceProvider).register(
        tournamentId: widget.tournamentId,
        fftLicense: _licenseController.text.trim(),
      );
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(paid
                ? 'Paiement validé ! Inscription confirmée.'
                : 'Inscription envoyée ! Tu seras notifié de la réponse.'),
          ),
        );
      }
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur paiement : ${e.error.localizedMessage ?? e.error.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ══════════════════════════════════════════════
//  DÉTAIL TOURNOI
// ══════════════════════════════════════════════

class TournamentDetailScreen extends ConsumerWidget {
  final String tournamentId;
  const TournamentDetailScreen({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tAsync = ref.watch(tournamentDetailProvider(tournamentId));
    final uid    = ref.watch(authStateProvider).valueOrNull?.uid;
    final df     = DateFormat('d MMM yyyy', 'fr_FR');

    return tAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:   (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (t) {
        if (t == null) return const Scaffold(body: Center(child: Text('Tournoi introuvable')));
        final isRegistered = uid != null && t.registeredIds.contains(uid);

        return Scaffold(
          appBar: AppBar(
            title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              if (t.isOpen && !isRegistered)
                TextButton(
                  onPressed: () => context.go('/tournaments/$tournamentId/register'),
                  child: Text('S\'inscrire',
                    style: GoogleFonts.syne(fontWeight: FontWeight.w700, color: ZuTheme.accent)),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Status banner
              ZuCard(
                borderColor: t.isOpen ? ZuTheme.accent.withOpacity(0.3) : ZuTheme.borderColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(t.title, style: Theme.of(context).textTheme.displaySmall),
                        ),
                        ZuTag(
                          t.isOpen ? 'Inscriptions ouvertes' : 'Complet',
                          style: t.isOpen ? ZuTagStyle.green : ZuTagStyle.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(icon: '📍', text: t.club),
                    const SizedBox(height: 4),
                    _InfoRow(icon: '📅', text: '${df.format(t.startDate)} → ${df.format(t.endDate)}'),
                    const SizedBox(height: 4),
                    _InfoRow(icon: '👥', text: '${t.registeredIds.length} / ${t.maxPlayers} joueurs inscrits'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        ZuTag(t.level,    style: ZuTagStyle.gold),
                        ZuTag(t.category, style: ZuTagStyle.blue),
                        ZuTag(t.surface,  style: ZuTagStyle.neutral),
                        if (!t.isFree)
                          ZuTag('${t.entryFee.toStringAsFixed(0)} €', style: ZuTagStyle.green),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Description
              if (t.description.isNotEmpty) ...[
                ZuSectionTitle('Description'),
                const SizedBox(height: 8),
                ZuCard(
                  child: Text(t.description, style: Theme.of(context).textTheme.bodyMedium),
                ),
                const SizedBox(height: 16),
              ],

              // Contact
              ZuSectionTitle('Contact'),
              const SizedBox(height: 8),
              ZuCard(
                child: Column(
                  children: [
                    _InfoRow(icon: '👤', text: t.contactName),
                    const SizedBox(height: 4),
                    _InfoRow(icon: '✉️', text: t.contactEmail),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // CTA
              if (isRegistered)
                ZuCard(
                  borderColor: ZuTheme.accent.withOpacity(0.3),
                  child: Row(
                    children: [
                      const Text('✅', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Text('Tu es inscrit à ce tournoi !',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ZuTheme.accent)),
                    ],
                  ),
                )
              else if (t.isOpen)
                ZuButton(
                  label: t.isFree
                      ? 'S\'inscrire gratuitement'
                      : 'Payer ${t.entryFee.toStringAsFixed(0)} € et s\'inscrire',
                  onPressed: () => context.go('/tournaments/$tournamentId/register'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(icon, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
    ],
  );
}

// ══════════════════════════════════════════════
//  ÉDITION DU PROFIL
// ══════════════════════════════════════════════

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _firstNameCtrl  = TextEditingController();
  final _lastNameCtrl   = TextEditingController();
  final _cityCtrl       = TextEditingController();
  final _fftLicenseCtrl = TextEditingController();
  final _fftRankCtrl    = TextEditingController();
  int   _level          = 1;
  bool  _loading        = false;
  bool  _photoLoading   = false;
  bool  _initialized    = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _cityCtrl.dispose();
    _fftLicenseCtrl.dispose();
    _fftRankCtrl.dispose();
    super.dispose();
  }

  void _initFromUser(ZuUser user) {
    if (_initialized) return;
    _firstNameCtrl.text  = user.firstName;
    _lastNameCtrl.text   = user.lastName;
    _cityCtrl.text       = user.city ?? '';
    _fftLicenseCtrl.text = user.fftLicense ?? '';
    _fftRankCtrl.text    = user.fftRank ?? '';
    _level               = user.level;
    _initialized         = true;
  }

  Future<void> _pickPhoto(String uid) async {
    final picker = ImagePicker();
    final image  = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;
    setState(() => _photoLoading = true);
    try {
      await ref.read(userServiceProvider).uploadProfilePhoto(uid: uid, image: image);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo mise à jour !')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _photoLoading = false);
    }
  }

  Future<void> _save(String uid) async {
    setState(() => _loading = true);
    try {
      await ref.read(userServiceProvider).updateProfile(
        uid:        uid,
        firstName:  _firstNameCtrl.text.trim(),
        lastName:   _lastNameCtrl.text.trim(),
        level:      _level,
        city:       _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        fftLicense: _fftLicenseCtrl.text.trim().isEmpty ? null : _fftLicenseCtrl.text.trim(),
        fftRank:    _fftRankCtrl.text.trim().isEmpty ? null : _fftRankCtrl.text.trim(),
      );
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour !')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:   (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (user) {
        if (user == null) return const Scaffold(body: Center(child: Text('Non connecté')));
        _initFromUser(user);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Modifier le profil'),
            actions: [
              TextButton(
                onPressed: _loading ? null : () => _save(user.id),
                child: Text('Sauvegarder',
                  style: GoogleFonts.syne(fontWeight: FontWeight.w700, color: ZuTheme.accent)),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Avatar + photo picker
              Center(
                child: GestureDetector(
                  onTap: () => _pickPhoto(user.id),
                  child: Stack(
                    children: [
                      Container(
                        width: 88, height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: user.photoUrl == null
                              ? const LinearGradient(colors: [ZuTheme.accent, ZuTheme.accent2])
                              : null,
                          image: user.photoUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(user.photoUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: user.photoUrl == null
                            ? Center(
                                child: Text(user.initials,
                                  style: GoogleFonts.syne(
                                    fontSize: 28, fontWeight: FontWeight.w800,
                                    color: ZuTheme.bgPrimary,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      if (_photoLoading)
                        const Positioned.fill(
                          child: CircularProgressIndicator(strokeWidth: 3, color: ZuTheme.accent),
                        ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 26, height: 26,
                          decoration: const BoxDecoration(
                            color: ZuTheme.bgCard, shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 14, color: ZuTheme.accent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Prénom / Nom
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameCtrl,
                      decoration: const InputDecoration(labelText: 'Prénom'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameCtrl,
                      decoration: const InputDecoration(labelText: 'Nom'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Ville
              TextFormField(
                controller: _cityCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ville',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
              ),
              const SizedBox(height: 20),

              // Niveau
              ZuCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Niveau de jeu', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    ZuLevelSelector(
                      initialLevel: _level,
                      onChanged: (l) => setState(() => _level = l),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Licence FFT
              TextFormField(
                controller: _fftLicenseCtrl,
                decoration: const InputDecoration(
                  labelText: 'Numéro de licence FFT (optionnel)',
                  prefixIcon: Icon(Icons.card_membership_outlined),
                ),
              ),
              const SizedBox(height: 14),

              // Classement FFT
              TextFormField(
                controller: _fftRankCtrl,
                decoration: const InputDecoration(
                  labelText: 'Classement FFT (ex: P25, P100…)',
                  prefixIcon: Icon(Icons.emoji_events_outlined),
                ),
              ),
              const SizedBox(height: 28),

              ZuButton(
                label: 'Sauvegarder',
                loading: _loading,
                onPressed: () => _save(user.id),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════
//  COACHING
// ══════════════════════════════════════════════

class CoachListScreen extends ConsumerStatefulWidget {
  const CoachListScreen({super.key});

  @override
  ConsumerState<CoachListScreen> createState() => _CoachListScreenState();
}

class _CoachListScreenState extends ConsumerState<CoachListScreen> {
  String? _filterLevel;
  String? _filterSpec;

  @override
  Widget build(BuildContext context) {
    final coaches = ref.watch(coachesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Coaching')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                _Chip('Tous', _filterLevel == null && _filterSpec == null, () => setState(() {
                  _filterLevel = null;
                  _filterSpec  = null;
                })),
                const SizedBox(width: 8),
                ...['Débutant', 'Intermédiaire', 'Avancé'].map((l) =>
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Chip(l, _filterLevel == l, () => setState(() =>
                      _filterLevel = _filterLevel == l ? null : l)),
                  ),
                ),
                ...['Technique', 'Tactique', 'Mental', 'Physique'].map((s) =>
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Chip(s, _filterSpec == s, () => setState(() =>
                      _filterSpec = _filterSpec == s ? null : s)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: coaches.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (list) {
                final filtered = list.where((c) {
                  if (_filterLevel != null && !c.playerLevels.contains(_filterLevel)) return false;
                  if (_filterSpec != null && !c.specialties.contains(_filterSpec)) return false;
                  return true;
                }).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    ...filtered.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ZuCoachCard(
                        coach: c,
                        onTap: () => context.go('/coaching/${c.id}'),
                      ),
                    )),
                    // CTA devenir coach
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ZuTheme.accent.withOpacity(0.3), style: BorderStyle.solid),
                        color: ZuTheme.accent.withOpacity(0.04),
                      ),
                      child: Column(
                        children: [
                          Text('Tu es coach ?', style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: ZuTheme.accent)),
                          const SizedBox(height: 6),
                          Text(
                            'Rejoins l\'annuaire et trouve tes élèves.\nAbonnement 10€/mois.',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ZuButton(
                            label: 'Créer mon profil coach',
                            onPressed: () => context.go('/coaching/create-profile'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  PROFIL & STATS
// ══════════════════════════════════════════════

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user  = ref.watch(currentUserProvider).valueOrNull;
    final stats = ref.watch(userStatsProvider).valueOrNull;

    return Scaffold(
      backgroundColor: ZuTheme.bgPrimary,
      body: CustomScrollView(
        slivers: [
          // Profile hero
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF161F14), Color(0xFF0D0F14)],
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 20, 20, 24,
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/profile/edit'),
                    child: Stack(
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [ZuTheme.accent, ZuTheme.accent2],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              user?.initials ?? 'ZP',
                              style: GoogleFonts.syne(
                                fontSize: 28, fontWeight: FontWeight.w800,
                                color: ZuTheme.bgPrimary,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            width: 24, height: 24,
                            decoration: const BoxDecoration(
                              color: ZuTheme.bgCard, shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, size: 12, color: ZuTheme.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(user?.fullName ?? 'Joueur', style: Theme.of(context).textTheme.displayMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Niveau ${user?.level ?? 1}${user?.city != null ? ' · ${user!.city}' : ''}${user?.fftRank != null ? ' · FFT ${user!.fftRank}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  ZuCreditChip(
                    credits: user?.credits ?? 0,
                    onTap: () => context.go('/credits'),
                  ),
                ],
              ),
            ),
          ),

          // Stats grid
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(child: ZuSectionTitle('Mes statistiques')),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: stats == null
                  ? const ZuShimmerCard()
                  : _StatsGrid(stats: stats),
            ),
          ),

          // Win rate chart
          if (stats != null && stats.matchesPlayed > 0) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(child: ZuSectionTitle('Répartition victoires')),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(child: _WinRateChart(stats: stats)),
            ),
          ],

          // Menu
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(child: ZuSectionTitle('Mon compte')),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverToBoxAdapter(
              child: ZuCard(
                child: Column(
                  children: [
                    _MenuRow(
                      icon: '⬡',
                      label: 'Crédits & transactions',
                      trailing: ZuCreditChip(credits: user?.credits ?? 0),
                      onTap: () => context.go('/credits'),
                    ),
                    const Divider(height: 1),
                    _MenuRow(
                      icon: '🤝',
                      label: 'Code parrainage',
                      trailing: ZuTag(user?.referralCode ?? '...', style: ZuTagStyle.green),
                      onTap: () => _shareReferral(context, user?.referralCode),
                    ),
                    const Divider(height: 1),
                    _MenuRow(
                      icon: '📊',
                      label: 'Partager mes stats',
                      onTap: () => context.go('/profile/share-stats'),
                    ),
                    const Divider(height: 1),
                    _MenuRow(
                      icon: '🏅',
                      label: 'Licence FFT',
                      trailing: user?.fftLicense != null
                          ? ZuTag('Enregistrée', style: ZuTagStyle.green)
                          : ZuTag('Ajouter', style: ZuTagStyle.neutral),
                      onTap: () => context.go('/profile/edit'),
                    ),
                    const Divider(height: 1),
                    _MenuRow(
                      icon: '🔔',
                      label: 'Notifications',
                      onTap: () => context.go('/settings/notifications'),
                    ),
                    const Divider(height: 1),
                    _MenuRow(
                      icon: '⚙️',
                      label: 'Paramètres',
                      onTap: () => context.go('/settings'),
                    ),
                    const Divider(height: 1),
                    _MenuRow(
                      icon: '🚪',
                      label: 'Déconnexion',
                      color: ZuTheme.accentRed,
                      onTap: () => ref.read(authServiceProvider).signOut(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _shareReferral(BuildContext context, String? code) {
    if (code == null) return;
    Share.share(
      'Rejoins-moi sur Zupadel ! Utilise mon code $code pour recevoir 5 crédits offerts.\n\nhttps://zupadel.app',
      subject: 'Code parrainage Zupadel',
    );
  }
}

// ── Stats grid ──────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final UserStats stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final pct = (stats.winRate * 100).toStringAsFixed(0);
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.2,
      children: [
        _StatBox('${stats.matchesPlayed}', 'Matchs'),
        _StatBox('${stats.matchesWon}', 'Victoires'),
        _StatBox('$pct%', 'Win rate'),
        _StatBox('${stats.hoursPlayed}h', 'Jouées'),
        _StatBox('${stats.setsWon}', 'Sets gagnés'),
        _StatBox('${stats.setsLost}', 'Sets perdus'),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;

  const _StatBox(this.value, this.label);

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: ZuTheme.bgCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ZuTheme.borderColor),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: GoogleFonts.syne(
            fontSize: 22, fontWeight: FontWeight.w800, color: ZuTheme.accent,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

// ── Win rate chart ───────────────────────────────────────────────

class _WinRateChart extends StatelessWidget {
  final UserStats stats;

  const _WinRateChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    return ZuCard(
      child: SizedBox(
        height: 160,
        child: PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 40,
            sections: [
              PieChartSectionData(
                value: stats.matchesWon.toDouble(),
                color: ZuTheme.accent,
                title: '${stats.matchesWon}',
                titleStyle: GoogleFonts.syne(
                  fontSize: 12, fontWeight: FontWeight.w700, color: ZuTheme.bgPrimary,
                ),
                radius: 50,
              ),
              PieChartSectionData(
                value: stats.matchesLost.toDouble(),
                color: ZuTheme.bgSurface,
                title: '${stats.matchesLost}',
                titleStyle: GoogleFonts.syne(
                  fontSize: 12, fontWeight: FontWeight.w700, color: ZuTheme.textSecondary,
                ),
                radius: 50,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  CRÉDITS
// ══════════════════════════════════════════════

class CreditsScreen extends ConsumerStatefulWidget {
  const CreditsScreen({super.key});

  @override
  ConsumerState<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends ConsumerState<CreditsScreen> {
  String? _loadingPack;
  StreamSubscription<String>? _iapErrorSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!kIsWeb && _iapErrorSub == null) {
      _iapErrorSub = ref.read(iapServiceProvider).purchaseErrors.listen((error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
          setState(() => _loadingPack = null);
        }
      });
    }
  }

  @override
  void dispose() {
    _iapErrorSub?.cancel();
    super.dispose();
  }

  // ── Achat mobile via Apple IAP / Google Play ──────────────────────
  Future<void> _buyIAP(ProductDetails product) async {
    setState(() => _loadingPack = product.id);
    try {
      await ref.read(iapServiceProvider).buyProduct(product);
      // Le résultat arrive via le purchase stream → crédits mis à jour en temps réel
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPack = null);
    }
  }

  // ── Achat web via Stripe ──────────────────────────────────────────
  Future<void> _buyStripe(String packId) async {
    setState(() => _loadingPack = packId);
    try {
      await ref.read(paymentServiceProvider).buyCredits(packId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZuTheme.bgCard,
            content: Text(
              'Paiement réussi ! Tes crédits arrivent dans quelques secondes.',
              style: TextStyle(color: ZuTheme.textPrimary),
            ),
          ),
        );
      }
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur paiement : ${e.error.localizedMessage ?? e.error.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPack = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final txs  = ref.watch(creditTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes crédits')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Solde ────────────────────────────────────────────
          ZuCard(
            child: Column(
              children: [
                Text(
                  '${user?.credits ?? 0}',
                  style: GoogleFonts.syne(
                    fontSize: 64, fontWeight: FontWeight.w800, color: ZuTheme.accent,
                    height: 1,
                  ),
                ),
                Text('crédits', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  '≈ ${((user?.credits ?? 0) * 0.5).toStringAsFixed(2)} €',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ZuTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          ZuSectionTitle('Acheter des crédits'),
          const SizedBox(height: 10),

          // ── Packs ─────────────────────────────────────────────
          if (kIsWeb)
            // Web → Stripe, prix hardcodés
            _WebPackGrid(loadingPack: _loadingPack, onBuy: _buyStripe)
          else
            // iOS/Android → Apple IAP / Google Play, prix du store
            _MobilePackGrid(loadingPack: _loadingPack, onBuy: _buyIAP),

          const SizedBox(height: 20),

          // ── Historique ────────────────────────────────────────
          ZuSectionTitle('Historique'),
          const SizedBox(height: 10),
          txs.when(
            loading: () => const ZuShimmerCard(),
            error: (e, _) => Text('$e'),
            data: (list) => list.isEmpty
                ? ZuCard(child: Text('Aucune transaction', style: Theme.of(context).textTheme.bodySmall))
                : ZuCard(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Column(
                      children: list.take(20).map((tx) => _TxRow(tx: tx)).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Grille packs Web (Stripe) ─────────────────────────────────────
class _WebPackGrid extends StatelessWidget {
  final String? loadingPack;
  final void Function(String packId) onBuy;
  const _WebPackGrid({required this.loadingPack, required this.onBuy});

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2, shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.4,
    children: [
      _PackCard(name: 'Starter', credits: 10,  priceLabel: '4,99 €',  popular: false, id: 'starter', loading: loadingPack == 'starter', onTap: () => onBuy('starter')),
      _PackCard(name: 'Joueur',  credits: 25,  priceLabel: '9,99 €',  popular: true,  id: 'joueur',  loading: loadingPack == 'joueur',  onTap: () => onBuy('joueur')),
      _PackCard(name: 'Pro',     credits: 60,  priceLabel: '19,99 €', popular: false, id: 'pro',     loading: loadingPack == 'pro',     onTap: () => onBuy('pro')),
      _PackCard(name: 'Elite',   credits: 150, priceLabel: '39,99 €', popular: false, id: 'elite',   loading: loadingPack == 'elite',   onTap: () => onBuy('elite'), gold: true),
    ],
  );
}

// ── Grille packs Mobile (IAP) ─────────────────────────────────────
class _MobilePackGrid extends ConsumerWidget {
  final String? loadingPack;
  final void Function(ProductDetails product) onBuy;
  const _MobilePackGrid({required this.loadingPack, required this.onBuy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(iapProductsProvider);
    return products.when(
      loading: () => const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ZuCard(
        child: Text(
          'Achats non disponibles pour le moment.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return ZuCard(
            child: Text(
              'Boutique indisponible. Vérifie ta connexion.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }
        return GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.4,
          children: list.map((product) {
            final m = IAPService.meta[product.id];
            if (m == null) return const SizedBox.shrink();
            return _PackCard(
              name:       m.name,
              credits:    m.credits,
              priceLabel: product.price, // prix localisé du store
              popular:    m.popular,
              gold:       m.gold,
              id:         product.id,
              loading:    loadingPack == product.id,
              onTap:      () => onBuy(product),
            );
          }).toList(),
        );
      },
    );
  }
}

class _PackCard extends StatelessWidget {
  final String name;
  final int credits;
  final String priceLabel;
  final bool popular;
  final bool gold;
  final String id;
  final bool loading;
  final VoidCallback? onTap;

  const _PackCard({
    required this.name,
    required this.credits,
    required this.priceLabel,
    required this.popular,
    required this.id,
    this.gold = false,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = gold ? ZuTheme.accentGold : ZuTheme.accent;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: ZuTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: popular ? ZuTheme.accent : ZuTheme.borderColor, width: popular ? 1.5 : 1),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('⬡', style: TextStyle(fontSize: 18, color: color)),
                const SizedBox(width: 6),
                Text(
                  '$credits',
                  style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w800, color: color),
                ),
              ],
            ),
            const Spacer(),
            Text(name, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  priceLabel,
                  style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                if (loading)
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (popular)
                  ZuTag('Populaire', style: ZuTagStyle.green),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final CreditTransaction tx;

  const _TxRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.amount > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: (isCredit ? ZuTheme.accent : ZuTheme.accentRed).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                isCredit ? '⬆' : '⬇',
                style: TextStyle(
                  fontSize: 14,
                  color: isCredit ? ZuTheme.accent : ZuTheme.accentRed,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.description, style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  DateFormat('d MMM à HH:mm', 'fr_FR').format(tx.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : ''}${tx.amount} ⬡',
            style: GoogleFonts.syne(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: isCredit ? ZuTheme.accent : ZuTheme.accentRed,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared helpers ─────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Chip(this.label, this.active, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? ZuTheme.accent.withOpacity(0.15) : ZuTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? ZuTheme.accent : ZuTheme.borderColor),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 12, fontWeight: FontWeight.w500,
          color: active ? ZuTheme.accent : ZuTheme.textSecondary,
        ),
      ),
    ),
  );
}

class _FormField extends StatelessWidget {
  final String label;
  final String value;
  final bool readOnly;

  const _FormField({required this.label, required this.value, this.readOnly = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: readOnly ? ZuTheme.textSecondary : ZuTheme.textPrimary,
      )),
    ],
  );
}

class _MenuRow extends StatelessWidget {
  final String icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;

  const _MenuRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 2),
    leading: Text(icon, style: const TextStyle(fontSize: 20)),
    title: Text(
      label,
      style: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w500,
        color: color ?? ZuTheme.textPrimary,
      ),
    ),
    trailing: trailing ?? const Icon(Icons.chevron_right, color: ZuTheme.textSecondary, size: 18),
    onTap: onTap,
  );
}

// ══════════════════════════════════════════════
//  PARTAGE STATS
// ══════════════════════════════════════════════

class ShareStatsScreen extends ConsumerStatefulWidget {
  const ShareStatsScreen({super.key});

  @override
  ConsumerState<ShareStatsScreen> createState() => _ShareStatsScreenState();
}

class _ShareStatsScreenState extends ConsumerState<ShareStatsScreen> {
  final _repaintKey = GlobalKey();
  bool _sharing = false;

  Future<void> _shareCard() async {
    setState(() => _sharing = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();

      if (kIsWeb) {
        // Sur le web, on ne peut pas écrire de fichier — on partage via XFile en mémoire
        await Share.shareXFiles(
          [XFile.fromData(pngBytes, mimeType: 'image/png', name: 'zupadel_stats.png')],
          text: 'Mes stats Zupadel 🎾',
        );
      } else {
        final dir  = await getTemporaryDirectory();
        final file = File('${dir.path}/zupadel_stats.png');
        await file.writeAsBytes(pngBytes);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'image/png')],
          text: 'Mes stats Zupadel 🎾',
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user  = ref.watch(currentUserProvider).valueOrNull;
    final stats = ref.watch(userStatsProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Partager mes stats')),
      body: Column(
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: RepaintBoundary(
              key: _repaintKey,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF161F14), Color(0xFF0D0F14)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ZuTheme.accent.withOpacity(0.3)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'ZUPADEL',
                          style: GoogleFonts.syne(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: ZuTheme.accent, letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          user?.fullName ?? '',
                          style: GoogleFonts.dmSans(
                            fontSize: 13, color: ZuTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (stats != null) ...[
                      _ShareStatRow('Matchs joués', '${stats.matchesPlayed}'),
                      _ShareStatRow('Victoires',    '${stats.matchesWon}'),
                      _ShareStatRow('Win rate',     '${(stats.winRate * 100).toStringAsFixed(0)}%'),
                      _ShareStatRow('Heures jouées','${stats.hoursPlayed}h'),
                      _ShareStatRow('Sets gagnés',  '${stats.setsWon}'),
                    ] else ...[
                      const Center(child: Text('Aucune stat disponible')),
                    ],
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'zupadel.app',
                        style: GoogleFonts.dmSans(
                          fontSize: 11, color: ZuTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ZuButton(
              label: 'Partager',
              loading: _sharing,
              onPressed: _shareCard,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareStatRow extends StatelessWidget {
  final String label;
  final String value;
  const _ShareStatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 14, color: ZuTheme.textSecondary)),
        Text(value,  style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700, color: ZuTheme.textPrimary)),
      ],
    ),
  );
}

// ══════════════════════════════════════════════
//  DÉTAIL COACH + ABONNEMENT
// ══════════════════════════════════════════════

class CoachDetailScreen extends ConsumerStatefulWidget {
  final String coachId;
  const CoachDetailScreen({super.key, required this.coachId});

  @override
  ConsumerState<CoachDetailScreen> createState() => _CoachDetailScreenState();
}

class _CoachDetailScreenState extends ConsumerState<CoachDetailScreen> {
  bool _loading = false;

  Future<void> _subscribe(ZuCoach coach) async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Abonnement coach disponible sur le web uniquement pour le moment.'),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(paymentServiceProvider).subscribeCoach(coach.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Abonnement activé ! Ton profil coach est en ligne.')),
        );
        context.pop();
      }
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${e.error.localizedMessage ?? e.error.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coachAsync = ref.watch(coachesProvider);
    final myUid      = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Coach')),
      body: coachAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('$e')),
        data:    (list) {
          final coach = list.firstWhere(
            (c) => c.id == widget.coachId,
            orElse: () => list.first,
          );
          final isMyCoach  = coach.userId == myUid;
          final isExpired  = coach.subscribedUntil == null ||
              coach.subscribedUntil!.isBefore(DateTime.now());

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              ZuCoachCard(coach: coach),
              const SizedBox(height: 20),
              if (isMyCoach) ...[
                ZuCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mon abonnement coach', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ZuTag(
                            isExpired ? 'Expiré' : 'Actif',
                            style: isExpired ? ZuTagStyle.red : ZuTagStyle.green,
                          ),
                          if (!isExpired && coach.subscribedUntil != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              'jusqu\'au ${DateFormat('d MMM yyyy', 'fr_FR').format(coach.subscribedUntil!)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      ZuButton(
                        label: isExpired ? 'Renouveler — 10€/mois' : 'Gérer l\'abonnement',
                        loading: _loading,
                        onPressed: () => _subscribe(coach),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ZuCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Spécialités', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: coach.specialties.map((s) => ZuTag(s, style: ZuTagStyle.neutral)).toList(),
                      ),
                      const SizedBox(height: 12),
                      Text('Niveaux accompagnés', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: coach.playerLevels.map((l) => ZuTag(l, style: ZuTagStyle.green)).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  PARAMÈTRES NOTIFICATIONS
// ══════════════════════════════════════════════

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _matchInvites    = true;
  bool _matchAccepted   = true;
  bool _matchCancelled  = true;
  bool _matchFinished   = true;
  bool _tournaments     = true;
  bool _coaching        = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          ZuCard(
            child: Column(
              children: [
                _NotifRow('Nouveaux matchs près de moi', _matchInvites,
                    (v) => setState(() => _matchInvites = v)),
                _NotifRow('Demande acceptée', _matchAccepted,
                    (v) => setState(() => _matchAccepted = v)),
                _NotifRow('Match annulé', _matchCancelled,
                    (v) => setState(() => _matchCancelled = v)),
                _NotifRow('Match terminé (avis)', _matchFinished,
                    (v) => setState(() => _matchFinished = v)),
                _NotifRow('Tournois', _tournaments,
                    (v) => setState(() => _tournaments = v)),
                _NotifRow('Coaching', _coaching,
                    (v) => setState(() => _coaching = v)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Les préférences de notifications sont sauvegardées localement.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _NotifRow(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) => SwitchListTile(
    title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    value: value,
    onChanged: onChanged,
    activeColor: ZuTheme.accent,
    contentPadding: EdgeInsets.zero,
  );
}
