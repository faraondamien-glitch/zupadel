import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';
import '../services/services.dart';
import '../theme/zu_theme.dart';
import '../widgets/widgets.dart';

// ══════════════════════════════════════════════
//  LEADERBOARD SCREEN
// ══════════════════════════════════════════════

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  int _selectedLevel = 1;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myRanking = ref.watch(myRankingProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text('Classement', style: GoogleFonts.syne(fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: ZuTheme.accent,
          labelColor: ZuTheme.accent,
          unselectedLabelColor: ZuTheme.textSecondary,
          labelStyle: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Général'),
            Tab(text: 'Par niveau'),
            Tab(text: 'Cette semaine'),
            Tab(text: 'Ma ville'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Mon rang — épinglé en haut
          if (myRanking != null) _MyRankBanner(ranking: myRanking),

          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _LeaderboardTab(filter: const LeaderboardFilter('global')),
                _LevelLeaderboardTab(
                  selectedLevel: _selectedLevel,
                  onLevelChanged: (l) => setState(() => _selectedLevel = l),
                ),
                _LeaderboardTab(filter: const LeaderboardFilter('weekly')),
                _CityLeaderboardTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bandeau "Mon classement" épinglé ─────────────────────────────

class _MyRankBanner extends StatelessWidget {
  final ZuRanking ranking;
  const _MyRankBanner({required this.ranking});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [ZuTheme.accent.withOpacity(0.15), ZuTheme.accent.withOpacity(0.05)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ZuTheme.accent.withOpacity(0.4)),
    ),
    child: Row(
      children: [
        ZuRankBadge(position: ranking.rankPosition, size: 38, highlighted: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ta position', style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ZuTheme.textSecondary)),
              Text(ranking.displayName,
                style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700,
                  color: ZuTheme.textPrimary)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${ranking.eloRating}',
              style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w800,
                color: ZuTheme.accent)),
            Text('ELO', style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ZuTheme.textSecondary, fontSize: 10)),
          ],
        ),
      ],
    ),
  );
}

// ── Tab classement générique ──────────────────────────────────────

class _LeaderboardTab extends ConsumerWidget {
  final LeaderboardFilter filter;
  const _LeaderboardTab({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaderboardProvider(filter));

    return async.when(
      loading: () => ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 10,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ZuShimmerCard(height: 72),
        ),
      ),
      error: (e, _) => Center(child: Text('Erreur : $e',
        style: Theme.of(context).textTheme.bodySmall)),
      data: (list) {
        if (list.isEmpty) return _EmptyLeaderboard();
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: list.length,
          itemBuilder: (ctx, i) => _RankingTile(
            ranking: list[i],
            position: i + 1,
            onTap: () => ctx.push('/players/${list[i].uid}'),
          ),
        );
      },
    );
  }
}

// ── Tab par niveau ────────────────────────────────────────────────

class _LevelLeaderboardTab extends ConsumerWidget {
  final int selectedLevel;
  final ValueChanged<int> onLevelChanged;
  const _LevelLeaderboardTab({required this.selectedLevel, required this.onLevelChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = LeaderboardFilter('level', level: selectedLevel);
    final async  = ref.watch(leaderboardProvider(filter));

    return Column(
      children: [
        // Sélecteur de niveau
        SizedBox(
          height: 44,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            scrollDirection: Axis.horizontal,
            children: List.generate(7, (i) {
              final lvl      = i + 1;
              final selected = lvl == selectedLevel;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onLevelChanged(lvl),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    decoration: BoxDecoration(
                      color: selected ? ZuTheme.accent : ZuTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? ZuTheme.accent : ZuTheme.borderColor),
                    ),
                    child: Center(
                      child: Text('Niveau $lvl',
                        style: GoogleFonts.syne(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected ? ZuTheme.bgPrimary : ZuTheme.textSecondary,
                        )),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (list) {
              if (list.isEmpty) return _EmptyLeaderboard();
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: list.length,
                itemBuilder: (ctx, i) => _RankingTile(
                  ranking: list[i],
                  position: i + 1,
                  onTap: () => ctx.push('/players/${list[i].uid}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Tab ma ville ─────────────────────────────────────────────────

class _CityLeaderboardTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user?.city == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_outlined, size: 48,
                color: ZuTheme.textSecondary),
              const SizedBox(height: 12),
              Text('Ville non renseignée',
                style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700,
                  color: ZuTheme.textPrimary)),
              const SizedBox(height: 8),
              Text('Ajoute ta ville dans ton profil pour voir\nle classement de ta région.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              ZuButton(
                label: 'Modifier le profil',
                onPressed: () => context.push('/profile/edit'),
              ),
            ],
          ),
        ),
      );
    }

    final filter = LeaderboardFilter('city', city: user!.city);
    final async  = ref.watch(leaderboardProvider(filter));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (list) {
        if (list.isEmpty) return _EmptyLeaderboard();
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: list.length,
          itemBuilder: (ctx, i) => _RankingTile(
            ranking: list[i],
            position: i + 1,
            onTap: () => ctx.push('/players/${list[i].uid}'),
          ),
        );
      },
    );
  }
}

// ── Tile d'un joueur dans le classement ──────────────────────────

class _RankingTile extends ConsumerWidget {
  final ZuRanking ranking;
  final int position;
  final VoidCallback onTap;

  const _RankingTile({
    required this.ranking,
    required this.position,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final isMe  = ranking.uid == myUid;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? ZuTheme.accent.withOpacity(0.08)
              : ZuTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isMe ? ZuTheme.accent.withOpacity(0.4) : ZuTheme.borderColor),
        ),
        child: Row(
          children: [
            ZuRankBadge(position: position, size: 34, highlighted: isMe),
            const SizedBox(width: 12),
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: ZuTheme.accent.withOpacity(0.15),
              backgroundImage: ranking.photoUrl != null
                  ? NetworkImage(ranking.photoUrl!) : null,
              child: ranking.photoUrl == null
                  ? Text(ranking.initials,
                      style: GoogleFonts.syne(fontSize: 12,
                        fontWeight: FontWeight.w700, color: ZuTheme.accent))
                  : null,
            ),
            const SizedBox(width: 10),
            // Nom + badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(ranking.displayName,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.syne(fontSize: 13,
                            fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                            color: ZuTheme.textPrimary)),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        ZuTag('Toi', style: ZuTagStyle.green),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text('Niv. ${ranking.level}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ZuTheme.textSecondary, fontSize: 11)),
                      if (ranking.city != null) ...[
                        Text(' · ', style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: ZuTheme.textSecondary, fontSize: 11)),
                        Text(ranking.city!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ZuTheme.textSecondary, fontSize: 11)),
                      ],
                      if (ranking.currentStreak >= 3) ...[
                        const SizedBox(width: 6),
                        _StreakBadge(streak: ranking.currentStreak),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // ELO + win rate
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${ranking.eloRating}',
                  style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w800,
                    color: isMe ? ZuTheme.accent : ZuTheme.textPrimary)),
                Text('${(ranking.winRate * 100).round()}% V',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ZuTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Badge de position (1er, 2e, 3e avec médailles) ───────────────

class ZuRankBadge extends StatelessWidget {
  final int position;
  final double size;
  final bool highlighted;
  const ZuRankBadge({required this.position, required this.size, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final (color, emoji) = switch (position) {
      1 => (const Color(0xFFFFD700), '🥇'),
      2 => (const Color(0xFFC0C0C0), '🥈'),
      3 => (const Color(0xFFCD7F32), '🥉'),
      _ => (highlighted ? ZuTheme.accent : ZuTheme.textSecondary, null),
    };

    return SizedBox(
      width: size,
      height: size,
      child: emoji != null
          ? Center(child: Text(emoji, style: TextStyle(fontSize: size * 0.7)))
          : Center(
              child: Text('#$position',
                style: GoogleFonts.syne(
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w800,
                  color: color,
                )),
            ),
    );
  }
}

// ── Badge de série de victoires ───────────────────────────────────

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.orange.withOpacity(0.15),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text('🔥 $streak',
      style: const TextStyle(fontSize: 10, color: Colors.orange,
        fontWeight: FontWeight.w700)),
  );
}

// ── État vide ─────────────────────────────────────────────────────

class _EmptyLeaderboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.emoji_events_outlined, size: 48, color: ZuTheme.textSecondary),
        const SizedBox(height: 12),
        Text('Pas encore de joueurs ici',
          style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700,
            color: ZuTheme.textPrimary)),
        const SizedBox(height: 8),
        Text('Joue des matchs compétitifs pour apparaître\ndans le classement.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

// ══════════════════════════════════════════════
//  PROFIL PUBLIC D'UN JOUEUR
// ══════════════════════════════════════════════

class PlayerProfileScreen extends ConsumerWidget {
  final String uid;
  const PlayerProfileScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankAsync = ref.watch(playerRankingProvider(uid));
    final myUid     = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil joueur'),
        actions: [
          if (myUid != null && myUid != uid)
            TextButton.icon(
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: Text('Message', style: GoogleFonts.syne(fontSize: 13,
                fontWeight: FontWeight.w700)),
              onPressed: () async {
                final svc = ref.read(messagingServiceProvider);
                final convId = await svc.getOrCreateDM(myUid, uid);
                if (context.mounted) context.push('/messages/$convId');
              },
            ),
        ],
      ),
      body: rankAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (ranking) {
          if (ranking == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_off_outlined, size: 48,
                    color: ZuTheme.textSecondary),
                  const SizedBox(height: 12),
                  Text('Joueur introuvable',
                    style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            );
          }
          return _PlayerProfileBody(ranking: ranking);
        },
      ),
    );
  }
}

class _PlayerProfileBody extends StatelessWidget {
  final ZuRanking ranking;
  const _PlayerProfileBody({required this.ranking});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      // Hero
      ZuCard(
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: ZuTheme.accent.withOpacity(0.15),
              backgroundImage: ranking.photoUrl != null
                  ? NetworkImage(ranking.photoUrl!) : null,
              child: ranking.photoUrl == null
                  ? Text(ranking.initials,
                      style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w800,
                        color: ZuTheme.accent))
                  : null,
            ),
            const SizedBox(height: 12),
            Text(ranking.displayName,
              style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w800,
                color: ZuTheme.textPrimary)),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                ZuTag('Niveau ${ranking.level}', style: ZuTagStyle.neutral),
                if (ranking.city != null)
                  ZuTag(ranking.city!, style: ZuTagStyle.neutral),
                if (ranking.fftRank != null)
                  ZuTag('FFT ${ranking.fftRank}', style: ZuTagStyle.green),
              ],
            ),
            const SizedBox(height: 12),
            // Position
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ZuRankBadge(position: ranking.rankPosition, size: 28),
                const SizedBox(width: 6),
                Text('Classé #${ranking.rankPosition} mondial',
                  style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w600,
                    color: ZuTheme.textSecondary)),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),

      // Stats ELO
      ZuCard(
        child: Row(
          children: [
            Expanded(child: _StatBlock(
              value: '${ranking.eloRating}',
              label: 'ELO',
              icon: Icons.trending_up_rounded,
              color: ZuTheme.accent,
            )),
            _Divider(),
            Expanded(child: _StatBlock(
              value: '${(ranking.winRate * 100).round()}%',
              label: 'Victoires',
              icon: Icons.emoji_events_rounded,
              color: ranking.winRate >= 0.5 ? ZuTheme.accent : Colors.orange,
            )),
            _Divider(),
            Expanded(child: _StatBlock(
              value: '${ranking.rankingPoints}',
              label: 'Points',
              icon: Icons.stars_rounded,
              color: Colors.amber,
            )),
          ],
        ),
      ),
      const SizedBox(height: 12),

      // Stats détaillées
      ZuCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statistiques',
              style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700,
                color: ZuTheme.textPrimary)),
            const SizedBox(height: 16),
            _StatsRow(label: 'Matchs joués', value: '${ranking.matchesPlayed}'),
            _StatsRow(label: 'Victoires', value: '${ranking.matchesWon}'),
            _StatsRow(label: 'Meilleure série',
              value: '${ranking.bestStreak} victoires consécutives'),
            _StatsRow(label: 'Série actuelle',
              value: ranking.currentStreak > 0
                  ? '🔥 ${ranking.currentStreak} en cours'
                  : 'Aucune'),
          ],
        ),
      ),

      const SizedBox(height: 12),

      // Barre win rate
      ZuCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Taux de victoire',
                  style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700)),
                Text('${(ranking.winRate * 100).round()}%',
                  style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w800,
                    color: ranking.winRate >= 0.5 ? ZuTheme.accent : Colors.orange)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ranking.winRate.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: ZuTheme.surface,
                color: ranking.winRate >= 0.5 ? ZuTheme.accent : Colors.orange,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${ranking.matchesWon} V',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ZuTheme.accent, fontSize: 11)),
                Text('${ranking.matchesPlayed - ranking.matchesWon} D',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ZuTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class _StatBlock extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _StatBlock({required this.value, required this.label,
    required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 4),
      Text(value, style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w800,
        color: ZuTheme.textPrimary)),
      Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: ZuTheme.textSecondary, fontSize: 11)),
    ],
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 40,
    color: ZuTheme.borderColor,
  );
}

class _StatsRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatsRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: ZuTheme.textSecondary)),
        Text(value, style: GoogleFonts.syne(fontSize: 13,
          fontWeight: FontWeight.w700, color: ZuTheme.textPrimary)),
      ],
    ),
  );
}
