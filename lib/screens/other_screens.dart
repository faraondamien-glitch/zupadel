import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
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
                          value: user?.pseudo ?? '',
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
      await ref.read(tournamentServiceProvider).register(
        tournamentId: widget.tournamentId,
        fftLicense: _licenseController.text.trim(),
      );
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inscription envoyée ! Tu seras notifié de la réponse.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                              user?.pseudo.substring(0, 2).toUpperCase() ?? 'ZP',
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
                  Text(user?.pseudo ?? 'Joueur', style: Theme.of(context).textTheme.displayMedium),
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
    // TODO: share_plus
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Code copié : $code')),
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

class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user  = ref.watch(currentUserProvider).valueOrNull;
    final txs   = ref.watch(creditTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes crédits')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Solde
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
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: const [
              _PackCard(name: 'Starter', credits: 10, price: 5, popular: false),
              _PackCard(name: 'Joueur',  credits: 25, price: 10, popular: true),
              _PackCard(name: 'Pro',     credits: 60, price: 20, popular: false),
              _PackCard(name: 'Elite',   credits: 150, price: 40, popular: false, gold: true),
            ],
          ),
          const SizedBox(height: 20),

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

class _PackCard extends StatelessWidget {
  final String name;
  final int credits;
  final double price;
  final bool popular;
  final bool gold;

  const _PackCard({
    required this.name,
    required this.credits,
    required this.price,
    required this.popular,
    this.gold = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = gold ? ZuTheme.accentGold : ZuTheme.accent;
    return GestureDetector(
      onTap: () {
        // TODO: Stripe payment sheet
      },
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
                  '${price.toStringAsFixed(0)}€',
                  style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                if (popular)
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
