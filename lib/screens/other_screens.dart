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
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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
    super.dispose();
  }

  void _initFromUser(ZuUser user) {
    if (_initialized) return;
    _firstNameCtrl.text  = user.firstName;
    _lastNameCtrl.text   = user.lastName;
    _cityCtrl.text       = user.city ?? '';
    _fftLicenseCtrl.text = user.fftLicense ?? '';
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

              // Classement FFT — lecture seule, synchronisé automatiquement
              _FftRankTile(user: user),
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
    final user    = ref.watch(currentUserProvider).valueOrNull;
    final stats   = ref.watch(userStatsProvider).valueOrNull;
    final ranking = ref.watch(myRankingProvider).valueOrNull;

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
                    'Niveau ${user?.level ?? 1}${user?.city != null ? ' · ${user!.city}' : ''}',
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

          // ELO + position
          if (ranking != null && ranking.matchesPlayed > 0)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _EloRankCard(ranking: ranking),
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
                  : stats.matchesPlayed == 0
                      ? ZuCard(
                          child: Column(
                            children: [
                              const Text('🎾', style: TextStyle(fontSize: 36)),
                              const SizedBox(height: 10),
                              Text(
                                'Pas encore de stats',
                                style: GoogleFonts.syne(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: ZuTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Joue ton premier match pour voir tes statistiques ici !',
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
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
                      trailing: (user?.referralCode.isNotEmpty ?? false)
                          ? ZuTag(user!.referralCode, style: ZuTagStyle.green)
                          : ZuTag('Génération…', style: ZuTagStyle.neutral),
                      onTap: (user?.referralCode.isNotEmpty ?? false)
                          ? () => _shareReferral(context, user?.referralCode)
                          : null,
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
                      label: 'Classement FFT Padel',
                      trailing: user?.fftRank != null
                          ? ZuTag('#${user!.fftRank!}', style: ZuTagStyle.green)
                          : user?.fftLicense != null
                              ? ZuTag('En attente de synchro', style: ZuTagStyle.neutral)
                              : ZuTag('Ajouter ma licence', style: ZuTagStyle.neutral),
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
      'Rejoins-moi sur Zupadel ! Utilise mon code $code pour recevoir 5 crédits offerts.\n\nhttps://zupadel.fr',
      subject: 'Code parrainage Zupadel',
    );
  }
}

// ── ELO + position card ─────────────────────────────────────────

class _EloRankCard extends StatelessWidget {
  final ZuRanking ranking;
  const _EloRankCard({required this.ranking});

  void _showInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ZuTheme.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _RankingInfoSheetSimple(),
    );
  }

  @override
  Widget build(BuildContext context) => ZuCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Mon classement',
              style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w700,
                color: ZuTheme.textPrimary)),
            GestureDetector(
              onTap: () => _showInfo(context),
              child: const Icon(Icons.info_outline_rounded, size: 18,
                color: ZuTheme.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
        Expanded(
          child: _EloStat(
            value: '${ranking.eloRating}',
            label: 'ELO',
            color: ZuTheme.accent,
          ),
        ),
        Container(width: 1, height: 40, color: ZuTheme.borderColor),
        Expanded(
          child: _EloStat(
            value: '#${ranking.rankPosition}',
            label: 'Classement mondial',
            color: ZuTheme.textPrimary,
          ),
        ),
        Container(width: 1, height: 40, color: ZuTheme.borderColor),
        Expanded(
          child: _EloStat(
            value: '${ranking.rankingPoints}',
            label: 'Points ligue',
            color: Colors.amber,
          ),
        ),
        if (ranking.currentStreak >= 3) ...[
          Container(width: 1, height: 40, color: ZuTheme.borderColor),
          Expanded(
            child: _EloStat(
              value: '🔥 ${ranking.currentStreak}',
              label: 'Série',
              color: Colors.orange,
              isEmoji: true,
            ),
          ),
        ],
      ],
        ),
      ],
    ),
  );
}

class _EloStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final bool isEmoji;
  const _EloStat({required this.value, required this.label,
    required this.color, this.isEmoji = false});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: isEmoji
          ? const TextStyle(fontSize: 18)
          : GoogleFonts.syne(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label, textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: ZuTheme.textSecondary, fontSize: 10)),
    ],
  );
}

// ── Fiche info classement (version compacte pour le profil) ─────

class _RankingInfoSheetSimple extends StatelessWidget {
  const _RankingInfoSheetSimple();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20, 12, 20, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: ZuTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Comment est calculé ton classement ?',
            style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800,
              color: ZuTheme.textPrimary)),
          const SizedBox(height: 16),
          _InfoRow(emoji: '⚡', title: 'ELO',
            body: 'Démarre à 1 200. Chaque victoire ou défaite '
                'ajuste tes points selon le niveau de tes adversaires. '
                'Battre plus fort = gagner plus.'),
          const SizedBox(height: 12),
          _InfoRow(emoji: '🏆', title: 'Points ligue',
            body: 'Victoire compétitive +10 · Victoire loisir +5 · '
                'Défaite +2. Remis à zéro chaque lundi.'),
          const SizedBox(height: 12),
          _InfoRow(emoji: '🔥', title: 'Série',
            body: 'Nombre de victoires consécutives. '
                'La flamme apparaît à partir de 3 d\'affilée.'),
          const SizedBox(height: 12),
          _InfoRow(emoji: '🎾', title: 'Important',
            body: 'Seuls les matchs avec un score saisi comptent '
                'pour l\'ELO et les points.'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;
  const _InfoRow({required this.emoji, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(emoji, style: const TextStyle(fontSize: 20)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.syne(fontSize: 12,
              fontWeight: FontWeight.w700, color: ZuTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(body, style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ZuTheme.textSecondary, height: 1.5)),
          ],
        ),
      ),
    ],
  );
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
  int _visibleTxCount = 10;

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
                  '≈ ${((user?.credits ?? 0) * 0.5).toStringAsFixed(2)} € de valeur',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ZuTheme.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  '1 crédit ≈ 0,50 € à l\'achat',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ZuTheme.textSecondary, fontSize: 11,
                  ),
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
            data: (list) {
              if (list.isEmpty) {
                return ZuCard(
                  child: Text('Aucune transaction', style: Theme.of(context).textTheme.bodySmall),
                );
              }
              final visible  = list.take(_visibleTxCount).toList();
              final hasMore  = list.length > _visibleTxCount;
              return Column(
                children: [
                  ZuCard(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Column(
                      children: visible.map((tx) => _TxRow(tx: tx)).toList(),
                    ),
                  ),
                  if (hasMore) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setState(() => _visibleTxCount += 10),
                      child: Text(
                        'Voir ${(list.length - _visibleTxCount).clamp(0, 10)} transaction${list.length - _visibleTxCount > 1 ? 's' : ''} de plus',
                        style: GoogleFonts.syne(fontSize: 13, color: ZuTheme.accent),
                      ),
                    ),
                  ] else if (list.length > 10) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Toutes les transactions affichées (${list.length})',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              );
            },
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

class _FftRankTile extends StatelessWidget {
  final ZuUser user;
  const _FftRankTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final rank      = user.fftRank;
    final updatedAt = user.fftRankUpdatedAt;
    final syncLabel = updatedAt != null
        ? 'Synchro le ${updatedAt.day.toString().padLeft(2, '0')}/${updatedAt.month.toString().padLeft(2, '0')}/${updatedAt.year}'
        : 'Synchro automatique chaque jour à 6h';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: ZuTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZuTheme.borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_outlined, size: 20, color: ZuTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Classement national FFT Padel',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ZuTheme.textSecondary)),
                const SizedBox(height: 4),
                rank != null
                    ? RichText(text: TextSpan(children: [
                        TextSpan(
                          text: rank,
                          style: GoogleFonts.syne(fontSize: 18,
                              fontWeight: FontWeight.w800, color: ZuTheme.accent),
                        ),
                        TextSpan(
                          text: 'ème au classement FFT',
                          style: GoogleFonts.dmSans(fontSize: 12,
                              color: ZuTheme.textSecondary),
                        ),
                      ]))
                    : Text('Non renseigné',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ZuTheme.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.sync_rounded, size: 12, color: ZuTheme.accent),
                    const SizedBox(width: 4),
                    Text(syncLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ZuTheme.accent, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
      backgroundColor: ZuTheme.bgPrimary,
      appBar: AppBar(title: const Text('Partager mes stats')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: _StatsCard(user: user, stats: stats),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Column(
              children: [
                Text(
                  'Appuyez sur Partager pour envoyer votre carte sur Instagram, X, WhatsApp…',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(fontSize: 12, color: ZuTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                ZuButton(
                  label: 'Partager ma carte',
                  loading: _sharing,
                  onPressed: _shareCard,
                  icon: const Icon(Icons.share_rounded, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Carte de stats à partager ──────────────────────────────────

class _StatsCard extends StatelessWidget {
  final ZuUser? user;
  final UserStats? stats;

  const _StatsCard({required this.user, required this.stats});

  @override
  Widget build(BuildContext context) {
    final winRate = stats?.winRate ?? 0.0;
    final winPct  = (winRate * 100).round();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ZuTheme.accent.withOpacity(0.25), width: 1.5),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141D12), Color(0xFF0D0F18), Color(0xFF0A0F0D)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // ── Décoration fond — cercles diffus ──────────
            Positioned(
              top: -60, right: -60,
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ZuTheme.accent.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -40, left: -40,
              child: Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ZuTheme.accent2.withOpacity(0.05),
                ),
              ),
            ),

            // ── Contenu ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header — avatar + nom + logo
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ZuAvatar(
                        photoUrl: user?.photoUrl,
                        initials: user?.initials ?? 'ZP',
                        size: 44,
                        bgColor: ZuTheme.playerColors[0],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? 'Joueur',
                              style: GoogleFonts.syne(
                                fontSize: 15, fontWeight: FontWeight.w700,
                                color: ZuTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: ZuTheme.accent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Niveau ${user?.level ?? 1}',
                                    style: GoogleFonts.syne(
                                      fontSize: 10, fontWeight: FontWeight.w700,
                                      color: ZuTheme.accent,
                                    ),
                                  ),
                                ),
                                if (user?.fftRank != null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: ZuTheme.accent.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#${user!.fftRank!} FFT',
                                      style: GoogleFonts.syne(
                                        fontSize: 9, fontWeight: FontWeight.w700,
                                        color: ZuTheme.accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'ZUPADEL',
                        style: GoogleFonts.syne(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          color: ZuTheme.accent, letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),

                  // Séparateur
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ZuTheme.accent.withOpacity(0),
                            ZuTheme.accent.withOpacity(0.4),
                            ZuTheme.accent.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Stat héroïque — matchs joués
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${stats?.matchesPlayed ?? 0}',
                        style: GoogleFonts.syne(
                          fontSize: 64, fontWeight: FontWeight.w800,
                          color: ZuTheme.textPrimary, height: 1.0,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10, left: 8),
                        child: Text(
                          'matchs\njoués',
                          style: GoogleFonts.dmSans(
                            fontSize: 13, color: ZuTheme.textSecondary, height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Barre Win Rate
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'WIN RATE',
                            style: GoogleFonts.syne(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: ZuTheme.textSecondary, letterSpacing: 1.2,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$winPct%',
                            style: GoogleFonts.syne(
                              fontSize: 14, fontWeight: FontWeight.w800,
                              color: winPct >= 50 ? ZuTheme.accent : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          children: [
                            Container(
                              height: 6,
                              color: Colors.white.withOpacity(0.08),
                            ),
                            FractionallySizedBox(
                              widthFactor: winRate.clamp(0.0, 1.0),
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: winPct >= 50
                                        ? [ZuTheme.accent.withOpacity(0.7), ZuTheme.accent]
                                        : [Colors.orange.withOpacity(0.7), Colors.orange],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Grille 2×2 stats secondaires
                  Row(
                    children: [
                      Expanded(child: _StatTile(
                        icon: '🏆', value: '${stats?.matchesWon ?? 0}', label: 'Victoires',
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _StatTile(
                        icon: '⏱', value: '${stats?.hoursPlayed ?? 0}h', label: 'Jouées',
                      )),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _StatTile(
                        icon: '🎾', value: '${stats?.setsWon ?? 0}', label: 'Sets gagnés',
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _StatTile(
                        icon: '📊',
                        value: stats?.avgOpponentLevel != null && stats!.avgOpponentLevel > 0
                            ? stats.avgOpponentLevel.toStringAsFixed(1)
                            : '—',
                        label: 'Niv. moyen adv.',
                      )),
                    ],
                  ),

                  // Footer
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'zupadel.fr',
                            style: GoogleFonts.dmSans(
                              fontSize: 10, color: ZuTheme.textSecondary, letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String icon;
  final String value;
  final String label;

  const _StatTile({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
    child: Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.syne(
                  fontSize: 16, fontWeight: FontWeight.w800, color: ZuTheme.textPrimary,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 10, color: ZuTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
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
    final coachAsync = ref.watch(coachDetailProvider(widget.coachId));
    final myUid      = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Coach')),
      body: coachAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('$e')),
        data:    (coach) {
          if (coach == null) return const Center(child: Text('Coach introuvable'));
          final isMyCoach = coach.userId == myUid;
          final isExpired = coach.subscribedUntil.isBefore(DateTime.now());

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              ZuCoachCard(coach: coach),
              const SizedBox(height: 20),
              if (isMyCoach) ...[
                // Vue propriétaire : gestion de l'abonnement
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
                          if (!isExpired) ...[
                            const SizedBox(width: 8),
                            Text(
                              'jusqu\'au ${DateFormat('d MMM yyyy', 'fr_FR').format(coach.subscribedUntil)}',
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
                // Vue joueur : profil complet du coach
                if (coach.bio.isNotEmpty) ...[
                  ZuCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('À propos', style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        Text(coach.bio, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
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
                if (coach.availabilities != null && coach.availabilities!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ZuCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Disponibilités', style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        Text(coach.availabilities!, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
                if (coach.instagram != null || coach.youtube != null) ...[
                  const SizedBox(height: 12),
                  ZuCard(
                    child: Wrap(
                      spacing: 12, runSpacing: 8,
                      children: [
                        if (coach.instagram != null)
                          OutlinedButton.icon(
                            onPressed: () => launchUrl(
                              Uri.parse('https://instagram.com/${coach.instagram}'),
                              mode: LaunchMode.externalApplication,
                            ),
                            icon: const Icon(Icons.photo_camera_outlined, size: 16),
                            label: Text('@${coach.instagram}'),
                          ),
                        if (coach.youtube != null)
                          OutlinedButton.icon(
                            onPressed: () => launchUrl(
                              Uri.parse(coach.youtube!),
                              mode: LaunchMode.externalApplication,
                            ),
                            icon: const Icon(Icons.play_circle_outline, size: 16),
                            label: const Text('YouTube'),
                          ),
                      ],
                    ),
                  ),
                ],
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
  // Valeurs locales (initialisées depuis Firestore au chargement)
  bool _matchInvites   = true;
  bool _matchAccepted  = true;
  bool _matchCancelled = true;
  bool _matchFinished  = true;
  bool _tournaments    = true;
  bool _coaching       = true;
  bool _messages       = true;
  bool _courtBooking   = true;
  bool _loaded         = false;
  bool _saving         = false;

  static const _prefsKey = 'notifPrefs';

  @override
  void initState() {
    super.initState();
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final prefs = doc.data()?[_prefsKey] as Map<String, dynamic>?;
    if (prefs != null && mounted) {
      setState(() {
        _matchInvites   = prefs['matchInvites']   as bool? ?? true;
        _matchAccepted  = prefs['matchAccepted']  as bool? ?? true;
        _matchCancelled = prefs['matchCancelled'] as bool? ?? true;
        _matchFinished  = prefs['matchFinished']  as bool? ?? true;
        _tournaments    = prefs['tournaments']    as bool? ?? true;
        _coaching       = prefs['coaching']       as bool? ?? true;
        _messages       = prefs['messages']       as bool? ?? true;
        _courtBooking   = prefs['courtBooking']   as bool? ?? true;
        _loaded         = true;
      });
    } else if (mounted) {
      setState(() => _loaded = true);
    }
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      _prefsKey: {
        'matchInvites':   _matchInvites,
        'matchAccepted':  _matchAccepted,
        'matchCancelled': _matchCancelled,
        'matchFinished':  _matchFinished,
        'tournaments':    _tournaments,
        'coaching':       _coaching,
        'messages':       _messages,
        'courtBooking':   _courtBooking,
      },
    });
    if (mounted) setState(() => _saving = false);
  }

  void _toggle(bool value, void Function(bool) setter) {
    setter(value);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: _loaded
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                ZuCard(
                  child: Column(
                    children: [
                      _NotifRow('Nouveaux matchs près de moi', _matchInvites,
                          (v) => setState(() => _toggle(v, (x) => _matchInvites = x))),
                      _NotifRow('Demande acceptée', _matchAccepted,
                          (v) => setState(() => _toggle(v, (x) => _matchAccepted = x))),
                      _NotifRow('Match annulé', _matchCancelled,
                          (v) => setState(() => _toggle(v, (x) => _matchCancelled = x))),
                      _NotifRow('Match terminé (avis)', _matchFinished,
                          (v) => setState(() => _toggle(v, (x) => _matchFinished = x))),
                      _NotifRow('Tournois', _tournaments,
                          (v) => setState(() => _toggle(v, (x) => _tournaments = x))),
                      _NotifRow('Coaching', _coaching,
                          (v) => setState(() => _toggle(v, (x) => _coaching = x))),
                      _NotifRow('Messages', _messages,
                          (v) => setState(() => _toggle(v, (x) => _messages = x))),
                      _NotifRow('Réservation terrain', _courtBooking,
                          (v) => setState(() => _toggle(v, (x) => _courtBooking = x))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sauvegardé sur ton compte — synchronisé sur tous tes appareils.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
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

// ══════════════════════════════════════════════
//  PARAMÈTRES
// ══════════════════════════════════════════════

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _defaultDispoHours = 3;
  bool _changingPassword  = false;
  final _emailCtrl        = TextEditingController();
  final _pwCtrl           = TextEditingController();
  final _pwConfirmCtrl    = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [

          // ── Matchmaking ─────────────────────────────────────
          Text('Matchmaking', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          ZuCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Durée de disponibilité par défaut',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Quand tu actives "Je suis disponible", combien de temps rester visible ?',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1,  label: Text('1h')),
                    ButtonSegment(value: 3,  label: Text('3h')),
                    ButtonSegment(value: 8,  label: Text('8h')),
                  ],
                  selected: {_defaultDispoHours},
                  onSelectionChanged: (s) => setState(() => _defaultDispoHours = s.first),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return ZuTheme.accent.withOpacity(0.2);
                      }
                      return null;
                    }),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Notifications ────────────────────────────────────
          Text('Notifications', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          ZuCard(
            onTap: () => context.push('/settings/notifications'),
            child: Row(
              children: [
                const Text('🔔', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Préférences de notifications',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Icon(Icons.chevron_right, color: ZuTheme.textSecondary, size: 20),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Compte ───────────────────────────────────────────
          Text('Compte', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          ZuCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Email affiché
                Text(
                  'Email',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '—',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Divider(height: 24),

                // Changer le mot de passe
                GestureDetector(
                  onTap: () => setState(() => _changingPassword = !_changingPassword),
                  child: Row(
                    children: [
                      const Text('🔑', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Changer le mot de passe',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Icon(
                        _changingPassword ? Icons.expand_less : Icons.expand_more,
                        color: ZuTheme.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),

                if (_changingPassword) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pwCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Nouveau mot de passe',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pwConfirmCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirmer le mot de passe',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ZuButton(
                    label: 'Mettre à jour',
                    onPressed: () => _changePassword(context),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Zone dangereuse ──────────────────────────────────
          Text('Zone dangereuse', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          ZuCard(
            child: Column(
              children: [
                _SettingsRow(
                  icon: '🚪',
                  label: 'Se déconnecter',
                  color: ZuTheme.accentRed,
                  onTap: () => _confirmSignOut(context),
                ),
                const Divider(height: 1),
                _SettingsRow(
                  icon: '🗑️',
                  label: 'Supprimer mon compte',
                  color: ZuTheme.accentRed,
                  onTap: () => _confirmDeleteAccount(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── À propos ─────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Text(
                  'Zupadel',
                  style: GoogleFonts.syne(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ZuTheme.textSecondary,
                  ),
                ),
                Text(
                  'v1.0.0 · Fait avec ❤️ pour le padel',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    if (_pwCtrl.text.isEmpty) return;
    if (_pwCtrl.text != _pwConfirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les mots de passe ne correspondent pas.')),
      );
      return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.updatePassword(_pwCtrl.text);
      _pwCtrl.clear();
      _pwConfirmCtrl.clear();
      if (context.mounted) {
        setState(() => _changingPassword = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe mis à jour.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ZuTheme.bgCard,
        title: Text('Se déconnecter ?',
          style: GoogleFonts.syne(fontWeight: FontWeight.w700, color: ZuTheme.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authServiceProvider).signOut();
            },
            child: Text('Déconnecter', style: TextStyle(color: ZuTheme.accentRed)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ZuTheme.bgCard,
        title: Text('Supprimer le compte ?',
          style: GoogleFonts.syne(fontWeight: FontWeight.w700, color: ZuTheme.accentRed)),
        content: const Text(
          'Cette action est irréversible. Tous tes matchs, crédits et statistiques seront perdus.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseAuth.instance.currentUser?.delete();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Re-connecte-toi avant de supprimer le compte.')),
                  );
                }
              }
            },
            child: Text('Supprimer', style: TextStyle(color: ZuTheme.accentRed)),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String     icon;
  final String     label;
  final Color?     color;
  final VoidCallback onTap;

  const _SettingsRow({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Text(icon, style: const TextStyle(fontSize: 18)),
    title: Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: color ?? ZuTheme.textPrimary,
      ),
    ),
    onTap: onTap,
  );
}

// ══════════════════════════════════════════════
//  TERRAINS — LISTE DES CLUBS PARTENAIRES
// ══════════════════════════════════════════════

class ClubListScreen extends ConsumerWidget {
  const ClubListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubsAsync = ref.watch(clubsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Clubs partenaires')),
      body: clubsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('$e')),
        data: (clubs) {
          if (clubs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sports_tennis_rounded, size: 48, color: ZuTheme.textSecondary),
                  const SizedBox(height: 12),
                  Text('Aucun club partenaire', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: clubs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _ClubCard(club: clubs[i]),
          );
        },
      ),
    );
  }
}

class _ClubCard extends StatelessWidget {
  final ZuClub club;
  const _ClubCard({required this.club});

  @override
  Widget build(BuildContext context) {
    return ZuCard(
      onTap: () => context.push('/clubs/${club.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: ZuTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sports_tennis_rounded, color: ZuTheme.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(club.name, style: Theme.of(context).textTheme.headlineSmall),
                    Text('📍 ${club.city}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${club.pricePerSlotCredits} crédits',
                    style: GoogleFonts.syne(
                      fontSize: 13, fontWeight: FontWeight.w700, color: ZuTheme.accent,
                    ),
                  ),
                  Text(
                    '/ ${club.slotDurationMinutes} min',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          if (club.amenities.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: club.amenities
                  .map((a) => ZuTag(a, style: ZuTagStyle.neutral))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  TERRAINS — DÉTAIL CLUB + COURTS
// ══════════════════════════════════════════════

class ClubDetailScreen extends ConsumerWidget {
  final String clubId;
  const ClubDetailScreen({super.key, required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubAsync   = ref.watch(clubDetailProvider(clubId));
    final courtsAsync = ref.watch(clubCourtsProvider(clubId));

    return Scaffold(
      appBar: AppBar(title: const Text('Club')),
      body: clubAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('$e')),
        data: (club) {
          if (club == null) return const Center(child: Text('Club introuvable'));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Infos club
              ZuCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(club.name, style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 4),
                    Text('📍 ${club.address}, ${club.city}',
                        style: Theme.of(context).textTheme.bodySmall),
                    if (club.phoneNumber != null) ...[
                      const SizedBox(height: 4),
                      Text('📞 ${club.phoneNumber}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ZuTag('${club.pricePerSlotCredits} crédits / ${club.slotDurationMinutes} min',
                            style: ZuTagStyle.green),
                        if (club.amenities.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Wrap(
                              spacing: 6, runSpacing: 6,
                              children: club.amenities
                                  .map((a) => ZuTag(a, style: ZuTagStyle.neutral))
                                  .toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Horaires
              if (club.openingHours.isNotEmpty) ...[
                ZuSectionTitle('Horaires'),
                const SizedBox(height: 8),
                ZuCard(
                  child: Column(
                    children: _buildOpeningHours(context, club.openingHours),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Courts
              ZuSectionTitle('Terrains disponibles'),
              const SizedBox(height: 8),
              courtsAsync.when(
                loading: () => const ZuShimmerCard(),
                error:   (e, _) => Text('$e'),
                data: (courts) {
                  if (courts.isEmpty) {
                    return ZuCard(
                      child: Text('Aucun terrain disponible',
                          style: Theme.of(context).textTheme.bodySmall),
                    );
                  }
                  return Column(
                    children: courts.map((court) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ZuCard(
                        onTap: () => context.push('/clubs/${club.id}/courts/${court.id}'),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: ZuTheme.bgSurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                court.isIndoor
                                    ? Icons.house_rounded
                                    : Icons.wb_sunny_rounded,
                                color: ZuTheme.accent, size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(court.name,
                                      style: Theme.of(context).textTheme.headlineSmall),
                                  Text(
                                    '${court.surface} · ${court.isIndoor ? "Couvert" : "Extérieur"}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: ZuTheme.textSecondary),
                          ],
                        ),
                      ),
                    )).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  static List<Widget> _buildOpeningHours(
      BuildContext context, Map<String, String> hours) {
    const days = [
      ('monday', 'Lundi'), ('tuesday', 'Mardi'), ('wednesday', 'Mercredi'),
      ('thursday', 'Jeudi'), ('friday', 'Vendredi'),
      ('saturday', 'Samedi'), ('sunday', 'Dimanche'),
    ];
    return days.map(((key, label)) {
      final h = hours[key];
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Text(
              h?.isNotEmpty == true ? h! : 'Fermé',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: h?.isNotEmpty == true
                    ? ZuTheme.textPrimary
                    : ZuTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

// ══════════════════════════════════════════════
//  TERRAINS — CRÉNEAUX D'UN COURT
// ══════════════════════════════════════════════

class CourtSlotsScreen extends ConsumerStatefulWidget {
  final String clubId;
  final String courtId;
  const CourtSlotsScreen({
    super.key,
    required this.clubId,
    required this.courtId,
  });

  @override
  ConsumerState<CourtSlotsScreen> createState() => _CourtSlotsScreenState();
}

class _CourtSlotsScreenState extends ConsumerState<CourtSlotsScreen> {
  DateTime _selectedDay = DateTime.now();
  List<DateTime> _bookedSlots = [];
  bool _loadingSlots = false;

  @override
  void initState() {
    super.initState();
    _loadBooked();
  }

  Future<void> _loadBooked() async {
    setState(() => _loadingSlots = true);
    try {
      final slots = await ref.read(reservationServiceProvider).bookedSlots(
        courtId: widget.courtId,
        day: _selectedDay,
      );
      if (mounted) setState(() => _bookedSlots = slots);
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  void _changeDay(DateTime day) {
    setState(() {
      _selectedDay = day;
      _bookedSlots = [];
    });
    _loadBooked();
  }

  @override
  Widget build(BuildContext context) {
    final clubAsync   = ref.watch(clubDetailProvider(widget.clubId));
    final courtsAsync = ref.watch(clubCourtsProvider(widget.clubId));

    return Scaffold(
      appBar: AppBar(title: const Text('Choisir un créneau')),
      body: clubAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('$e')),
        data: (club) {
          if (club == null) return const Center(child: Text('Club introuvable'));
          final court = courtsAsync.valueOrNull
              ?.firstWhere((c) => c.id == widget.courtId,
                  orElse: () => courtsAsync.valueOrNull!.first);

          final allSlots     = club.slotsForDay(_selectedDay);
          final bookedSet    = _bookedSlots.map((d) => d.toIso8601String()).toSet();
          final now          = DateTime.now();
          final availableSlots = allSlots
              .where((s) => s.isAfter(now) && !bookedSet.contains(s.toIso8601String()))
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Infos terrain
              if (court != null)
                ZuCard(
                  child: Row(
                    children: [
                      Icon(
                        court.isIndoor ? Icons.house_rounded : Icons.wb_sunny_rounded,
                        color: ZuTheme.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(court.name,
                                style: Theme.of(context).textTheme.headlineSmall),
                            Text(
                              '${court.surface} · ${court.isIndoor ? "Couvert" : "Extérieur"} · '
                              '${club.slotDurationMinutes} min · ${club.pricePerSlotCredits} crédits',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              // Sélecteur de jour
              ZuSectionTitle('Choisir un jour'),
              const SizedBox(height: 8),
              _DayPicker(
                selected: _selectedDay,
                onChanged: _changeDay,
              ),
              const SizedBox(height: 16),
              // Créneaux
              ZuSectionTitle('Créneaux disponibles'),
              const SizedBox(height: 8),
              if (_loadingSlots)
                const Center(child: CircularProgressIndicator())
              else if (allSlots.isEmpty)
                ZuCard(
                  child: Text('Club fermé ce jour',
                      style: Theme.of(context).textTheme.bodySmall),
                )
              else if (availableSlots.isEmpty)
                ZuCard(
                  child: Text('Plus de créneaux disponibles',
                      style: Theme.of(context).textTheme.bodySmall),
                )
              else
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8, crossAxisSpacing: 8,
                  childAspectRatio: 2.2,
                  children: availableSlots.map((slot) => _SlotChip(
                    slot: slot,
                    onTap: () => context.push(
                      '/clubs/${widget.clubId}/courts/${widget.courtId}/book',
                      extra: {
                        'slot': slot,
                        'club': club,
                        'court': court,
                      },
                    ),
                  )).toList(),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DayPicker extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onChanged;
  const _DayPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final days = List.generate(14, (i) => DateTime.now().add(Duration(days: i)));
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final day     = days[i];
          final isToday = i == 0;
          final isSel   = day.year == selected.year &&
              day.month == selected.month &&
              day.day == selected.day;
          return GestureDetector(
            onTap: () => onChanged(day),
            child: Container(
              width: 52,
              decoration: BoxDecoration(
                color: isSel ? ZuTheme.accent : ZuTheme.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSel ? ZuTheme.accent : ZuTheme.borderColor,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('d', 'fr_FR').format(day),
                    style: GoogleFonts.syne(
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: isSel ? ZuTheme.bgPrimary : ZuTheme.textPrimary,
                    ),
                  ),
                  Text(
                    isToday ? 'Auj.' : DateFormat('EEE', 'fr_FR').format(day),
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: isSel ? ZuTheme.bgPrimary : ZuTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  final DateTime slot;
  final VoidCallback onTap;
  const _SlotChip({required this.slot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: ZuTheme.accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ZuTheme.accent.withOpacity(0.4)),
        ),
        child: Center(
          child: Text(
            DateFormat('HH:mm').format(slot),
            style: GoogleFonts.syne(
              fontSize: 14, fontWeight: FontWeight.w700, color: ZuTheme.accent,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  TERRAINS — CONFIRMATION DE RÉSERVATION
// ══════════════════════════════════════════════

class BookSlotScreen extends ConsumerStatefulWidget {
  final String clubId;
  final String courtId;
  final DateTime slot;
  final ZuClub club;
  final ZuCourt court;

  const BookSlotScreen({
    super.key,
    required this.clubId,
    required this.courtId,
    required this.slot,
    required this.club,
    required this.court,
  });

  @override
  ConsumerState<BookSlotScreen> createState() => _BookSlotScreenState();
}

class _BookSlotScreenState extends ConsumerState<BookSlotScreen> {
  bool _loading = false;

  Future<void> _confirm() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    if (user.credits < widget.club.pricePerSlotCredits) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crédits insuffisants. Achète des crédits dans ton profil.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final resId = await ref.read(reservationServiceProvider).bookSlot(
        clubId:          widget.club.id,
        clubName:        widget.club.name,
        courtId:         widget.court.id,
        courtName:       widget.court.name,
        startTime:       widget.slot,
        durationMinutes: widget.club.slotDurationMinutes,
        priceCredits:    widget.club.pricePerSlotCredits,
      );
      if (mounted) {
        context.go('/clubs/${widget.clubId}/reservations/$resId');
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Erreur de réservation')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmer la réservation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ZuCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Récapitulatif',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                _InfoRow(icon: Icons.sports_tennis_rounded,
                    label: widget.club.name),
                const SizedBox(height: 8),
                _InfoRow(icon: Icons.grid_view_rounded,
                    label: widget.court.name),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.calendar_today_rounded,
                  label: DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(widget.slot),
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.access_time_rounded,
                  label:
                    '${DateFormat('HH:mm').format(widget.slot)} → '
                    '${DateFormat('HH:mm').format(widget.slot.add(Duration(minutes: widget.club.slotDurationMinutes)))}',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.toll_rounded,
                  label: '${widget.club.pricePerSlotCredits} crédits',
                  accent: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (user != null)
            ZuCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ton solde actuel',
                      style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    '${user.credits} crédits',
                    style: GoogleFonts.syne(
                      fontWeight: FontWeight.w700,
                      color: user.credits >= widget.club.pricePerSlotCredits
                          ? ZuTheme.accent
                          : ZuTheme.error,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          ZuButton(
            label: 'Réserver — ${widget.club.pricePerSlotCredits} crédits',
            loading: _loading,
            onPressed: _confirm,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool accent;
  const _InfoRow({required this.icon, required this.label, this.accent = false});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18,
          color: accent ? ZuTheme.accent : ZuTheme.textSecondary),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: accent ? ZuTheme.accent : null,
            fontWeight: accent ? FontWeight.w700 : null,
          ),
        ),
      ),
    ],
  );
}

// ══════════════════════════════════════════════
//  TERRAINS — CONFIRMATION APRÈS RÉSERVATION
// ══════════════════════════════════════════════

class ReservationConfirmScreen extends ConsumerWidget {
  final String reservationId;
  const ReservationConfirmScreen({super.key, required this.reservationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resAsync = ref.watch(myReservationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Réservation confirmée'),
        automaticallyImplyLeading: false,
      ),
      body: resAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('$e')),
        data: (list) {
          final res = list.where((r) => r.id == reservationId).firstOrNull;
          if (res == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: ZuTheme.accent.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: ZuTheme.accent, size: 40),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Terrain réservé !',
                  style: GoogleFonts.syne(
                    fontSize: 22, fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ZuCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(icon: Icons.sports_tennis_rounded, label: res.clubName),
                    const SizedBox(height: 8),
                    _InfoRow(icon: Icons.grid_view_rounded, label: res.courtName),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.calendar_today_rounded,
                      label: DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(res.startTime),
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.access_time_rounded,
                      label: '${DateFormat('HH:mm').format(res.startTime)} → '
                          '${DateFormat('HH:mm').format(res.endTime)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ZuButton(
                label: 'Créer un match sur ce créneau',
                outlined: true,
                onPressed: () => context.go(
                  '/matches/create',
                  extra: {'reservationId': res.id, 'club': res.clubName},
                ),
              ),
              const SizedBox(height: 12),
              ZuButton(
                label: 'Retour aux clubs',
                onPressed: () => context.go('/clubs'),
              ),
            ],
          );
        },
      ),
    );
  }
}
}
