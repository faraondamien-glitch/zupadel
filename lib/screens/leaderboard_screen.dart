import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, size: 22),
            tooltip: 'Comment ça marche ?',
            onPressed: () => _showRankingInfo(context),
          ),
        ],
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
                const _LocalLeaderboardTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRankingInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ZuTheme.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _RankingInfoSheet(),
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

// ══════════════════════════════════════════════
//  TAB "Ma région" — ville ou géolocalisation
// ══════════════════════════════════════════════

class _LocalLeaderboardTab extends ConsumerStatefulWidget {
  const _LocalLeaderboardTab();

  @override
  ConsumerState<_LocalLeaderboardTab> createState() => _LocalLeaderboardTabState();
}

class _LocalLeaderboardTabState extends ConsumerState<_LocalLeaderboardTab> {
  // Mode : 'city' (nom de la ville) ou 'geo' (géolocalisation)
  String _mode = 'city';
  double _radiusKm = 30;
  Position? _position;
  bool _loadingGeo = false;
  String? _geoError;

  static const _radii = [10.0, 30.0, 50.0, 100.0];

  Future<void> _requestGeo() async {
    setState(() { _loadingGeo = true; _geoError = null; });
    try {
      final svc = ref.read(locationServiceProvider);
      final pos = await svc.getCurrentPosition();
      if (pos == null) {
        setState(() { _geoError = 'Localisation refusée ou indisponible.'; });
      } else {
        setState(() { _position = pos; _mode = 'geo'; });
      }
    } catch (e) {
      setState(() { _geoError = 'Impossible d\'obtenir la position.'; });
    } finally {
      setState(() { _loadingGeo = false; });
    }
  }

  List<ZuRanking> _filterByDistance(List<ZuRanking> all) {
    if (_position == null) return [];
    return all.where((r) {
      if (r.location == null) return false;
      final distM = Geolocator.distanceBetween(
        _position!.latitude, _position!.longitude,
        r.location!.latitude, r.location!.longitude,
      );
      return distM / 1000 <= _radiusKm;
    }).toList();
  }

  double _distanceKm(ZuRanking r) {
    if (_position == null || r.location == null) return 0;
    return Geolocator.distanceBetween(
      _position!.latitude, _position!.longitude,
      r.location!.latitude, r.location!.longitude,
    ) / 1000;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Column(
      children: [
        // Toggle ville / géo
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              _ModeChip(
                label: '🏙 Ma ville',
                selected: _mode == 'city',
                onTap: () => setState(() => _mode = 'city'),
              ),
              const SizedBox(width: 8),
              _ModeChip(
                label: '📍 Autour de moi',
                selected: _mode == 'geo',
                onTap: _mode == 'geo'
                    ? null
                    : _loadingGeo
                        ? null
                        : _requestGeo,
                loading: _loadingGeo,
              ),
            ],
          ),
        ),

        // Sélecteur de rayon (visible uniquement en mode géo)
        if (_mode == 'geo' && _position != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: _radii.map((r) {
                final sel = r == _radiusKm;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _radiusKm = r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: sel ? ZuTheme.accent : ZuTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? ZuTheme.accent : ZuTheme.borderColor),
                      ),
                      child: Center(
                        child: Text(
                          r < 100 ? '${r.round()} km' : '100 km',
                          style: GoogleFonts.syne(fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: sel ? ZuTheme.bgPrimary : ZuTheme.textSecondary),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        const SizedBox(height: 8),

        // Contenu
        Expanded(child: _buildContent(context, user)),
      ],
    );
  }

  Widget _buildContent(BuildContext context, ZuUser? user) {
    // Mode géo
    if (_mode == 'geo') {
      if (_geoError != null) return _GeoError(message: _geoError!, onRetry: _requestGeo);
      if (_position == null) return _GeoPrompt(onTap: _requestGeo, loading: _loadingGeo);

      final allAsync = ref.watch(allRankingsProvider);
      return allAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (all) {
          final nearby = _filterByDistance(all);
          if (nearby.isEmpty) {
            return _EmptyNearby(radiusKm: _radiusKm);
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: nearby.length,
            itemBuilder: (ctx, i) {
              final r = nearby[i];
              return _RankingTile(
                ranking: r,
                position: i + 1,
                onTap: () => ctx.push('/players/${r.uid}'),
                distanceKm: _distanceKm(r),
              );
            },
          );
        },
      );
    }

    // Mode ville
    if (user?.city == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_city_outlined, size: 48,
                color: ZuTheme.textSecondary),
              const SizedBox(height: 12),
              Text('Ville non renseignée',
                style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Ajoute ta ville dans ton profil ou\nutilise la géolocalisation.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              ZuButton(label: 'Modifier le profil',
                onPressed: () => context.push('/profile/edit')),
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
  final double? distanceKm; // null = pas affiché

  const _RankingTile({
    required this.ranking,
    required this.position,
    required this.onTap,
    this.distanceKm,
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
                      if (distanceKm != null) ...[
                        const SizedBox(width: 6),
                        _DistanceBadge(km: distanceKm!),
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

// ── Badge distance ────────────────────────────────────────────────

class _DistanceBadge extends StatelessWidget {
  final double km;
  const _DistanceBadge({required this.km});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.blue.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      km < 1 ? '<1 km' : '${km.round()} km',
      style: const TextStyle(fontSize: 10, color: Colors.blue,
        fontWeight: FontWeight.w700),
    ),
  );
}

// ── Chip de mode (ville / géo) ────────────────────────────────────

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool loading;
  const _ModeChip({required this.label, required this.selected,
    this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? ZuTheme.accent : ZuTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? ZuTheme.accent : ZuTheme.borderColor),
      ),
      child: loading
          ? SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: selected ? ZuTheme.bgPrimary : ZuTheme.textSecondary,
              ),
            )
          : Text(label,
              style: GoogleFonts.syne(fontSize: 12, fontWeight: FontWeight.w700,
                color: selected ? ZuTheme.bgPrimary : ZuTheme.textSecondary)),
    ),
  );
}

// ── Invite à activer la géolocalisation ───────────────────────────

class _GeoPrompt extends StatelessWidget {
  final VoidCallback onTap;
  final bool loading;
  const _GeoPrompt({required this.onTap, required this.loading});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.my_location_rounded, size: 52,
            color: ZuTheme.textSecondary),
          const SizedBox(height: 16),
          Text('Joueurs autour de toi',
            style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800,
              color: ZuTheme.textPrimary)),
          const SizedBox(height: 8),
          Text('Autorise la localisation pour voir\nles joueurs près de chez toi.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          ZuButton(
            label: loading ? 'Localisation…' : 'Activer la localisation',
            loading: loading,
            onPressed: loading ? null : onTap,
          ),
        ],
      ),
    ),
  );
}

class _GeoError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _GeoError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_off_rounded, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          ZuButton(label: 'Réessayer', onPressed: onRetry),
        ],
      ),
    ),
  );
}

class _EmptyNearby extends StatelessWidget {
  final double radiusKm;
  const _EmptyNearby({required this.radiusKm});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 12),
          Text('Aucun joueur à ${radiusKm.round()} km',
            style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700,
              color: ZuTheme.textPrimary)),
          const SizedBox(height: 8),
          Text('Élargis le rayon ou invite des amis\nà rejoindre Zupadel !',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

// ── Fiche explicative du classement ──────────────────────────────

class _RankingInfoSheet extends StatelessWidget {
  const _RankingInfoSheet();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20, 12, 20, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poignée
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

          Text('Comment fonctionne le classement ?',
            style: GoogleFonts.syne(fontSize: 17, fontWeight: FontWeight.w800,
              color: ZuTheme.textPrimary)),
          const SizedBox(height: 20),

          _InfoSection(
            emoji: '⚡',
            title: 'ELO — ta cote',
            body: 'Chaque joueur commence à 1 200 points ELO. '
                'Après chaque match tu gagnes ou perds des points selon '
                'le niveau de tes adversaires : battre un joueur plus fort '
                'rapporte plus, perdre contre plus faible coûte plus.',
          ),
          const SizedBox(height: 16),

          _InfoSection(
            emoji: '🏆',
            title: 'Points ligue',
            body: 'En plus de l\'ELO, tu accumules des points ligue :\n'
                '• Victoire compétitive → +10 pts\n'
                '• Victoire loisir / training → +5 pts\n'
                '• Défaite (participation) → +2 pts\n\n'
                'Ces points se remettent à zéro chaque lundi — '
                'l\'onglet "Cette semaine" reflète ce classement hebdo.',
          ),
          const SizedBox(height: 16),

          _InfoSection(
            emoji: '🔥',
            title: 'Série de victoires',
            body: 'À partir de 3 victoires d\'affilée, '
                'une flamme apparaît à côté de ton nom. '
                'Ta meilleure série est conservée dans ton profil.',
          ),
          const SizedBox(height: 16),

          _InfoSection(
            emoji: '📍',
            title: 'Position globale',
            body: 'Les positions (#1, #2…) sont recalculées chaque nuit '
                'selon l\'ELO de tous les joueurs. '
                'L\'onglet "Ma ville" filtre uniquement les joueurs '
                'qui ont renseigné la même ville que toi.',
          ),
          const SizedBox(height: 16),

          _InfoSection(
            emoji: '🎾',
            title: 'Seuls les matchs avec score comptent',
            body: 'Un match doit être terminé avec un score saisi '
                'pour impacter le classement. '
                'Les matchs loisir sans résultat ne changent pas l\'ELO.',
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;
  const _InfoSection({required this.emoji, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(emoji, style: const TextStyle(fontSize: 22)),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.syne(fontSize: 13,
              fontWeight: FontWeight.w700, color: ZuTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(body, style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ZuTheme.textSecondary, height: 1.5)),
          ],
        ),
      ),
    ],
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
                  ZuTag('#${ranking.fftRank} FFT', style: ZuTagStyle.green),
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
