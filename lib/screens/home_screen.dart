import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/zu_theme.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import '../services/services.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _togglingAvail = false;

  Future<void> _toggleAvailability(UserAvailability? current) async {
    final isCurrentlyAvail = current?.isStillValid ?? false;

    if (!isCurrentlyAvail) {
      // Activation → choisir la durée d'abord
      final hours = await showModalBottomSheet<int>(
        context: context,
        backgroundColor: ZuTheme.bgCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => const _DispoPickerSheet(),
      );
      if (hours == null) return; // annulé
      setState(() => _togglingAvail = true);
      try {
        await ref.read(matchmakingServiceProvider)
            .setAvailability(available: true, hours: hours);
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'activer la disponibilité. Réessaie.')),
        );
      } finally {
        if (mounted) setState(() => _togglingAvail = false);
      }
    } else {
      // Désactivation → immédiate, pas besoin de bottom sheet
      setState(() => _togglingAvail = true);
      try {
        await ref.read(matchmakingServiceProvider)
            .setAvailability(available: false);
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de désactiver. Réessaie.')),
        );
      } finally {
        if (mounted) setState(() => _togglingAvail = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user      = ref.watch(currentUserProvider);
    final matches   = ref.watch(nearbyMatchesProvider);
    final avail     = ref.watch(availabilityProvider).valueOrNull;
    final suggested = ref.watch(suggestedMatchesProvider);
    final position  = ref.watch(userPositionProvider); // AsyncValue<Position?>

    return Scaffold(
      backgroundColor: ZuTheme.bgPrimary,
      body: CustomScrollView(
        slivers: [
          // ── AppBar Hero ──────────────────────────────────────
          SliverToBoxAdapter(
            child: _HeroHeader(
              user:             user,
              avail:            avail,
              togglingAvail:    _togglingAvail,
              onToggleAvail:    () => _toggleAvailability(avail),
            ),
          ),

          // ── Section : Matchs pour toi (matchmaking) ──────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: ZuSectionTitle(
                'Matchs pour toi',
                action: (avail?.isStillValid ?? false)
                    ? null
                    : TextButton(
                        onPressed: () => _toggleAvailability(avail),
                        child: Text(
                          'Je suis dispo',
                          style: GoogleFonts.syne(fontSize: 12, color: ZuTheme.accent),
                        ),
                      ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: suggested.when(
              loading: () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: ZuShimmerCard(),
                  ),
                  childCount: 2,
                ),
              ),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              data: (list) => list.isEmpty
                  ? SliverToBoxAdapter(
                      child: _SuggestedEmptyState(
                        isAvailable:       avail?.isStillValid ?? false,
                        onActivate:        () => _toggleAvailability(avail),
                        togglingAvail:     _togglingAvail,
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final sm = list[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ScoredMatchCard(
                              scored: sm,
                              onTap:  () => context.go('/matches/${sm.match.id}'),
                              onJoin: sm.match.status == MatchStatus.open
                                  ? () => _handleJoin(ctx, sm.match)
                                  : null,
                            ),
                          );
                        },
                        childCount: list.take(5).length,
                      ),
                    ),
            ),
          ),

          // ── Section : Match à proximité ──────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: ZuSectionTitle(
                'Matchs près de toi',
                action: TextButton(
                  onPressed: () => context.go('/matches'),
                  child: Text(
                    'Voir tout',
                    style: GoogleFonts.syne(fontSize: 12, color: ZuTheme.accent),
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: matches.when(
              loading: () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: ZuShimmerCard(),
                  ),
                  childCount: 2,
                ),
              ),
              error: (_, __) => SliverToBoxAdapter(
                child: ZuEmptyState(
                  emoji: '⚠️',
                  title: 'Impossible de charger',
                  subtitle: 'Vérifie ta connexion et tire vers le bas pour réessayer.',
                ),
              ),
              data: (list) => list.isEmpty
                  ? SliverToBoxAdapter(
                      child: _NearbyEmptyState(
                        position:  position,
                        onCreate:  () => context.go('/matches/create'),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ZuMatchCard(
                            match: list[i],
                            onTap:  () => context.go('/matches/${list[i].id}'),
                            onJoin: list[i].status == MatchStatus.open
                                ? () => _handleJoin(ctx, list[i])
                                : null,
                          ),
                        ),
                        childCount: list.take(3).length,
                      ),
                    ),
            ),
          ),

          // ── Section : Mes matchs ─────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(child: ZuSectionTitle('Mes prochains matchs')),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(child: _MyMatchesSection()),
          ),

          // ── Section : Tournois à venir ────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: ZuSectionTitle(
                'Tournois à venir',
                action: TextButton(
                  onPressed: () => context.go('/tournaments'),
                  child: Text('Voir tout', style: GoogleFonts.syne(fontSize: 12, color: ZuTheme.accent)),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverToBoxAdapter(child: _TournamentsPreview()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/matches/create'),
        backgroundColor: ZuTheme.accent,
        foregroundColor: ZuTheme.bgPrimary,
        icon: const Icon(Icons.add),
        label: Text('Créer un match', style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _handleJoin(BuildContext context, ZuMatch match) {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    if (user.credits < 1) {
      _showInsufficientCreditsDialog(context);
      return;
    }
    _showJoinConfirmDialog(context, match);
  }

  void _showJoinConfirmDialog(BuildContext context, ZuMatch match) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ZuTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _JoinMatchSheet(match: match, ref: ref),
    );
  }

  void _showInsufficientCreditsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ZuTheme.bgCard,
        title: Text('Crédits insuffisants', style: GoogleFonts.syne(fontWeight: FontWeight.w700, color: ZuTheme.textPrimary)),
        content: const Text('Vous n\'avez pas assez de crédits pour rejoindre ce match.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); context.go('/credits'); },
            child: const Text('Acheter des crédits'),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom sheet — choix durée disponibilité ───────────────────

class _DispoPickerSheet extends StatefulWidget {
  const _DispoPickerSheet();

  @override
  State<_DispoPickerSheet> createState() => _DispoPickerSheetState();
}

class _DispoPickerSheetState extends State<_DispoPickerSheet> {
  int _selected = 3;

  static const _options = [
    (hours: 1,  label: '1 heure',   sublabel: 'Pour un match rapide'),
    (hours: 3,  label: '3 heures',  sublabel: 'Le plus courant'),
    (hours: 8,  label: '8 heures',  sublabel: 'Toute la journée'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pendant combien de temps ?',
            style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 4),
          Text(
            'Tu resteras visible pour les matchs compatibles pendant cette durée.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          ..._options.map((opt) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => setState(() => _selected = opt.hours),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _selected == opt.hours
                      ? ZuTheme.accent.withOpacity(0.12)
                      : ZuTheme.bgPrimary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selected == opt.hours
                        ? ZuTheme.accent
                        : ZuTheme.borderColor,
                    width: _selected == opt.hours ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opt.label,
                            style: GoogleFonts.syne(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _selected == opt.hours
                                  ? ZuTheme.accent
                                  : ZuTheme.textPrimary,
                            )),
                          const SizedBox(height: 2),
                          Text(opt.sublabel,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: ZuTheme.textSecondary,
                            )),
                        ],
                      ),
                    ),
                    if (_selected == opt.hours)
                      Icon(Icons.check_circle, color: ZuTheme.accent, size: 20),
                  ],
                ),
              ),
            ),
          )),
          const SizedBox(height: 8),
          ZuButton(
            label: 'Je suis dispo — $_selected h',
            onPressed: () => Navigator.pop(context, _selected),
          ),
        ],
      ),
    );
  }
}

// ─── Hero Header ────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final AsyncValue<ZuUser?> user;
  final UserAvailability?   avail;
  final bool                togglingAvail;
  final VoidCallback        onToggleAvail;

  const _HeroHeader({
    required this.user,
    required this.avail,
    required this.togglingAvail,
    required this.onToggleAvail,
  });

  @override
  Widget build(BuildContext context) {
    final isAvail = avail?.isStillValid ?? false;

    return Container(
      decoration: BoxDecoration(
        gradient: ZuTheme.heroGradient,
        border: Border(bottom: BorderSide(color: ZuTheme.borderColor)),
      ),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 20),
      child: user.when(
        loading: () => const SizedBox(height: 72),
        error: (_, __) => const SizedBox(height: 72),
        data: (u) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bonjour 👋',
                        style: GoogleFonts.dmSans(fontSize: 13, color: ZuTheme.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        u?.displayName ?? 'Joueur',
                        style: GoogleFonts.syne(fontSize: 22, fontWeight: FontWeight.w800, color: ZuTheme.textPrimary),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ZuCreditChip(
                            credits: u?.credits ?? 0,
                            onTap: () => context.go('/credits'),
                          ),
                          const SizedBox(width: 10),
                          ZuTag('Niveau ${u?.level ?? 1}', style: ZuTagStyle.green),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/profile'),
                  child: ZuAvatar(
                    photoUrl: u?.photoUrl,
                    initials: u?.initials ?? 'ZP',
                    size: 48,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Toggle disponibilité ─────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              decoration: BoxDecoration(
                color: isAvail
                    ? ZuTheme.accent.withOpacity(0.12)
                    : ZuTheme.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isAvail ? ZuTheme.accent.withOpacity(0.5) : ZuTheme.borderColor,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bolt,
                    size: 18,
                    color: isAvail ? ZuTheme.accent : ZuTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Je suis disponible',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isAvail ? ZuTheme.accent : ZuTheme.textPrimary,
                          ),
                        ),
                        if (isAvail && avail != null)
                          Text(
                            'Expire ${_formatExpiry(avail!.expiresAt)}',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: ZuTheme.textSecondary,
                            ),
                          )
                        else
                          Text(
                            'Active pour trouver un match',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: ZuTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (togglingAvail)
                    const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Switch(
                      value: isAvail,
                      onChanged: (_) => onToggleAvail(),
                      activeColor: ZuTheme.accent,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatExpiry(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.inMinutes < 60) return 'dans ${diff.inMinutes} min';
    return 'dans ${diff.inHours}h';
  }
}

// ─── Empty states contextuels ───────────────────────────────────

/// Empty state "Matchs pour toi" — distingue dispo inactive vs vraiment vide.
class _SuggestedEmptyState extends StatelessWidget {
  final bool         isAvailable;
  final VoidCallback onActivate;
  final bool         togglingAvail;

  const _SuggestedEmptyState({
    required this.isAvailable,
    required this.onActivate,
    required this.togglingAvail,
  });

  @override
  Widget build(BuildContext context) {
    if (!isAvailable) {
      // L'utilisateur n'est pas disponible → CTA pour activer
      return ZuCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚡ Active ta disponibilité',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Dis-nous que tu es prêt à jouer et on te trouve les meilleurs matchs compatibles avec ton niveau.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ZuButton(
                label: togglingAvail ? 'Activation…' : 'Je suis disponible maintenant',
                onPressed: togglingAvail ? null : onActivate,
              ),
            ),
          ],
        ),
      );
    }

    // Disponible mais aucun match compatible trouvé
    return ZuCard(
      child: Row(
        children: [
          const Text('🔍', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aucun match compatible',
                  style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'Pas de match ouvert à ton niveau pour l\'instant. On te notifiera dès qu\'un match apparaît.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state "Matchs près de toi" — distingue géo refusée vs vraiment vide.
class _NearbyEmptyState extends StatelessWidget {
  final AsyncValue<Position?> position;
  final VoidCallback          onCreate;

  const _NearbyEmptyState({required this.position, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    // Géo en cours de chargement → ne rien afficher (shimmer déjà géré ailleurs)
    if (position.isLoading) return const SizedBox.shrink();

    // Géo chargée mais null → permission refusée
    final pos = position.valueOrNull;
    if (pos == null && !kIsWeb) {
      return ZuCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📍 Géolocalisation désactivée',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Active la géolocalisation pour voir les matchs près de chez toi.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ZuButton(
                    label: 'Ouvrir les réglages',
                    outlined: true,
                    onPressed: () => Geolocator.openAppSettings(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ZuButton(
                    label: 'Créer un match',
                    onPressed: onCreate,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Géo ok mais vraiment aucun match → inviter à créer
    return ZuEmptyState(
      emoji: '🎾',
      title: 'Aucun match à proximité',
      subtitle: 'Sois le premier à créer un match !',
      buttonLabel: 'Créer un match',
      onButton: onCreate,
    );
  }
}

// ─── Scored Match Card ──────────────────────────────────────────

class _ScoredMatchCard extends StatelessWidget {
  final ScoredMatch scored;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;

  const _ScoredMatchCard({required this.scored, this.onTap, this.onJoin});

  @override
  Widget build(BuildContext context) {
    final m = scored.match;
    return ZuMatchCard(
      match:        m,
      onTap:        onTap,
      onJoin:       onJoin,
      trailingBadge: _ScoreBadge(
        score:      scored.score,
        distanceKm: scored.distanceKm,
        levelMatch: scored.levelMatch,
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final int score;
  final double? distanceKm;
  final bool levelMatch;

  const _ScoreBadge({required this.score, this.distanceKm, required this.levelMatch});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (score >= 80)      color = ZuTheme.accent;
    else if (score >= 50) color = Colors.orange;
    else                  color = ZuTheme.textSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color:        color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border:       Border.all(color: color.withOpacity(0.4)),
          ),
          child: Text(
            '$score pts',
            style: GoogleFonts.syne(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        if (distanceKm != null) ...[
          const SizedBox(height: 4),
          Text(
            '${distanceKm!.toStringAsFixed(1)} km',
            style: GoogleFonts.dmSans(fontSize: 10, color: ZuTheme.textSecondary),
          ),
        ],
      ],
    );
  }
}

// ─── Mes matchs section ─────────────────────────────────────────

class _MyMatchesSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myMatches = ref.watch(myUpcomingMatchesProvider);

    return myMatches.when(
      loading: () => const ZuShimmerCard(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) {
          return ZuCard(
            child: Text(
              'Aucun match prévu. Rejoins ou crée un match !',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ZuTheme.textSecondary),
            ),
          );
        }
        return Column(
          children: list.map((m) {
            final df = DateFormat('EEE d MMM · HH:mm', 'fr_FR');
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ZuCard(
                onTap: () => context.go('/matches/${m.id}'),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.club, style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 3),
                          Text(df.format(m.startTime), style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    ZuTag(m.statusLabel,
                      style: m.status == MatchStatus.finished ? ZuTagStyle.neutral : ZuTagStyle.green,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─── Tournaments preview ─────────────────────────────────────────

class _TournamentsPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournaments = ref.watch(upcomingTournamentsProvider);

    return tournaments.when(
      loading: () => const ZuShimmerCard(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) => list.isEmpty
          ? const SizedBox.shrink()
          : ZuTournamentCard(
              tournament: list.first,
              onTap:      () => context.go('/tournaments/${list.first.id}'),
              onRegister: () => context.go('/tournaments/${list.first.id}/register'),
            ),
    );
  }
}

// ─── Join Match Bottom Sheet ─────────────────────────────────────

class _JoinMatchSheet extends StatefulWidget {
  final ZuMatch match;
  final WidgetRef ref;

  const _JoinMatchSheet({required this.match, required this.ref});

  @override
  State<_JoinMatchSheet> createState() => _JoinMatchSheetState();
}

class _JoinMatchSheetState extends State<_JoinMatchSheet> {
  bool _bet = false;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rejoindre ce match', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 4),
          Text(
            '${widget.match.club} · ${DateFormat('d MMM à HH:mm', 'fr_FR').format(widget.match.startTime)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          ZuCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mise enjeu (optionnel)', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text('Parie 1 crédit sur ta victoire', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Switch(
                  value: _bet,
                  onChanged: (v) => setState(() => _bet = v),
                  activeColor: ZuTheme.accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ZuCard(
            child: Column(
              children: [
                _CostRow(label: 'Rejoindre le match', amount: -1),
                if (_bet) _CostRow(label: 'Mise enjeu', amount: -1),
                const Divider(height: 16),
                _CostRow(
                  label: 'Total débité',
                  amount: _bet ? -2 : -1,
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ZuButton(
            label: 'Confirmer · ${_bet ? 2 : 1} crédit${_bet ? 's' : ''}',
            loading: _loading,
            onPressed: _confirm,
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    setState(() => _loading = true);
    try {
      await widget.ref.read(matchServiceProvider).joinMatch(
        matchId: widget.match.id,
        placeBet: _bet,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZuTheme.bgCard,
            content: Text('Demande envoyée ! L\'organisateur a 6h pour répondre.',
              style: TextStyle(color: ZuTheme.textPrimary)),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de rejoindre ce match. Réessaie.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _CostRow extends StatelessWidget {
  final String label;
  final int amount;
  final bool bold;

  const _CostRow({required this.label, required this.amount, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final color = amount < 0 ? ZuTheme.accentRed : ZuTheme.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          )),
          Text(
            '${amount < 0 ? '' : '+'}$amount ⬡',
            style: GoogleFonts.syne(
              fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
