import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/zu_theme.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import '../services/services.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user    = ref.watch(currentUserProvider);
    final matches = ref.watch(nearbyMatchesProvider);

    return Scaffold(
      backgroundColor: ZuTheme.bgPrimary,
      body: CustomScrollView(
        slivers: [
          // ── AppBar Hero ──────────────────────────────────────
          SliverToBoxAdapter(child: _HeroHeader(user: user)),

          // ── Section : Match à proximité ──────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
              error: (e, _) => SliverToBoxAdapter(
                child: ZuEmptyState(
                  emoji: '⚠️',
                  title: 'Erreur de chargement',
                  subtitle: e.toString(),
                ),
              ),
              data: (list) => list.isEmpty
                  ? SliverToBoxAdapter(
                      child: ZuEmptyState(
                        emoji: '🎾',
                        title: 'Aucun match à proximité',
                        subtitle: 'Sois le premier à créer un match !',
                        buttonLabel: 'Créer un match',
                        onButton: () => context.go('/matches/create'),
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
                                ? () => _handleJoin(ctx, ref, list[i])
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

  void _handleJoin(BuildContext context, WidgetRef ref, ZuMatch match) {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    if (user.credits < 1) {
      _showInsufficientCreditsDialog(context);
      return;
    }
    _showJoinConfirmDialog(context, ref, match);
  }

  void _showJoinConfirmDialog(BuildContext context, WidgetRef ref, ZuMatch match) {
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

// ─── Hero Header ────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final AsyncValue<ZuUser?> user;

  const _HeroHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2A18), Color(0xFF0D0F14)],
        ),
        border: Border(bottom: BorderSide(color: ZuTheme.borderColor)),
      ),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 20),
      child: user.when(
        loading: () => const SizedBox(height: 72),
        error: (_, __) => const SizedBox(height: 72),
        data: (u) => Row(
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
                    u?.pseudo ?? 'Joueur',
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
                initials: u?.pseudo.substring(0, 2) ?? 'ZP',
                size: 48,
              ),
            ),
          ],
        ),
      ),
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
