import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/zu_theme.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import '../services/services.dart';

// ══════════════════════════════════════════════
//  LISTE DES MATCHS
// ══════════════════════════════════════════════

class MatchListScreen extends ConsumerStatefulWidget {
  const MatchListScreen({super.key});

  @override
  ConsumerState<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends ConsumerState<MatchListScreen> {
  MatchType? _filterType;
  bool _todayOnly = false;
  int? _filterLevel;

  @override
  Widget build(BuildContext context) {
    final matches = ref.watch(filteredMatchesProvider(
      MatchFilter(type: _filterType, todayOnly: _todayOnly, level: _filterLevel),
    ));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trouver un match'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: _showFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter chips ──────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Aujourd\'hui',
                  active: _todayOnly,
                  onTap: () => setState(() => _todayOnly = !_todayOnly),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Compétitif',
                  active: _filterType == MatchType.competitive,
                  onTap: () => setState(() => _filterType =
                    _filterType == MatchType.competitive ? null : MatchType.competitive),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Loisir',
                  active: _filterType == MatchType.leisure,
                  onTap: () => setState(() => _filterType =
                    _filterType == MatchType.leisure ? null : MatchType.leisure),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Mon niveau',
                  active: _filterLevel != null,
                  onTap: () => setState(() => _filterLevel = _filterLevel == null ? 4 : null),
                ),
              ],
            ),
          ),

          // ── Match list ────────────────────────────────────
          Expanded(
            child: matches.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 4,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: ZuShimmerCard(),
                ),
              ),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (list) => list.isEmpty
                  ? ZuEmptyState(
                      emoji: '🎾',
                      title: 'Aucun match disponible',
                      subtitle: 'Sois le premier à créer un match dans ta zone !',
                      buttonLabel: 'Créer un match',
                      onButton: () => context.go('/matches/create'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: list.length,
                      itemBuilder: (ctx, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ZuMatchCard(
                          match: list[i],
                          onTap:  () => context.go('/matches/${list[i].id}'),
                          onJoin: list[i].status == MatchStatus.open
                              ? () => _joinMatch(ctx, list[i])
                              : null,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/matches/create'),
        backgroundColor: ZuTheme.accent,
        foregroundColor: ZuTheme.bgPrimary,
        icon: const Icon(Icons.add),
        label: Text('Créer', style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _joinMatch(BuildContext context, ZuMatch match) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ZuTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _JoinSheet(match: match, ref: ref),
    );
  }

  void _showFilters() {
    // TODO: Sheet filtres avancés (distance, niveau range, date)
  }
}

// ══════════════════════════════════════════════
//  CRÉER UN MATCH
// ══════════════════════════════════════════════

class CreateMatchScreen extends ConsumerStatefulWidget {
  const CreateMatchScreen({super.key});

  @override
  ConsumerState<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends ConsumerState<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clubController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _startTime = DateTime.now().add(const Duration(hours: 2));
  int _duration = 90;
  int _levelMin = 3;
  int _levelMax = 5;
  int _maxPlayers = 4;
  MatchType _type = MatchType.competitive;
  MatchVisibility _visibility = MatchVisibility.public;
  bool _loading = false;

  @override
  void dispose() {
    _clubController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un match')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Club
            TextFormField(
              controller: _clubController,
              decoration: const InputDecoration(
                labelText: 'Club / Lieu',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (v) => v?.isEmpty == true ? 'Requis' : null,
            ),
            const SizedBox(height: 16),

            // Date & heure
            ZuCard(
              onTap: _pickDateTime,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, color: ZuTheme.accent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date et heure', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('EEE d MMM à HH:mm', 'fr_FR').format(_startTime),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: ZuTheme.textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Durée
            ZuCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Durée : $_duration min', style: Theme.of(context).textTheme.headlineSmall),
                  Slider(
                    value: _duration.toDouble(),
                    min: 60, max: 180, divisions: 4,
                    activeColor: ZuTheme.accent,
                    inactiveColor: ZuTheme.borderColor,
                    label: '$_duration min',
                    onChanged: (v) => setState(() => _duration = v.toInt()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Niveau min
            ZuCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Niveau minimum', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  ZuLevelSelector(
                    initialLevel: _levelMin,
                    onChanged: (l) => setState(() {
                      _levelMin = l;
                      if (_levelMax < l) _levelMax = l;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Niveau max
            ZuCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Niveau maximum', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  ZuLevelSelector(
                    initialLevel: _levelMax,
                    onChanged: (l) => setState(() {
                      _levelMax = l;
                      if (_levelMin > l) _levelMin = l;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Type
            ZuCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Type de match', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Row(
                    children: MatchType.values.map((t) {
                      final label = switch (t) {
                        MatchType.competitive => 'Compétitif',
                        MatchType.leisure     => 'Loisir',
                        MatchType.training    => 'Training',
                      };
                      final selected = _type == t;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: GestureDetector(
                            onTap: () => setState(() => _type = t),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selected ? ZuTheme.accent : ZuTheme.bgCard,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected ? ZuTheme.accent : ZuTheme.borderColor,
                                ),
                              ),
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.syne(
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                  color: selected ? ZuTheme.bgPrimary : ZuTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Nb joueurs
            ZuCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nombre de joueurs max', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Row(
                    children: [2, 4].map((n) {
                      final sel = _maxPlayers == n;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () => setState(() => _maxPlayers = n),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: sel ? ZuTheme.accent : ZuTheme.bgCard,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: sel ? ZuTheme.accent : ZuTheme.borderColor),
                              ),
                              child: Text(
                                '$n joueurs',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.syne(
                                  fontSize: 13, fontWeight: FontWeight.w700,
                                  color: sel ? ZuTheme.bgPrimary : ZuTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Visibilité
            ZuCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Visibilité', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 3),
                        Text(
                          _visibility == MatchVisibility.public
                            ? 'Visible par tous les joueurs à proximité'
                            : 'Sur invitation uniquement',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _visibility == MatchVisibility.public,
                    onChanged: (v) => setState(() =>
                      _visibility = v ? MatchVisibility.public : MatchVisibility.private,
                    ),
                    activeColor: ZuTheme.accent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Note libre
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Commentaire (optionnel)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),

            // Info auto-validation
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ZuTheme.accent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ZuTheme.accent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Le match sera auto-validé à minuit si tu ne le confirmes pas toi-même.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ZuTheme.accent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            ZuButton(
              label: 'Publier le match',
              loading: _loading,
              onPressed: _submit,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (ctx, child) => Theme(
        data: ZuTheme.theme.copyWith(
          colorScheme: const ColorScheme.dark(primary: ZuTheme.accent),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (time == null) return;
    setState(() => _startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final id = await ref.read(matchServiceProvider).createMatch(
        club:       _clubController.text.trim(),
        startTime:  _startTime,
        duration:   _duration,
        levelMin:   _levelMin,
        levelMax:   _levelMax,
        maxPlayers: _maxPlayers,
        type:       _type,
        visibility: _visibility,
        note:       _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );
      if (mounted) context.go('/matches/$id');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ══════════════════════════════════════════════
//  DÉTAIL D'UN MATCH
// ══════════════════════════════════════════════

class MatchDetailScreen extends ConsumerWidget {
  final String matchId;
  const MatchDetailScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchDetailProvider(matchId));
    final user = ref.watch(currentUserProvider).valueOrNull;

    return matchAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Erreur: $e'))),
      data: (match) {
        if (match == null) return const Scaffold(body: Center(child: Text('Match introuvable')));
        final isOrganizer = user?.id == match.organizerId;
        final isPlayer    = match.playerIds.contains(user?.id);
        final df = DateFormat('EEEE d MMMM à HH:mm', 'fr_FR');

        return Scaffold(
          appBar: AppBar(
            title: Text(match.club),
            actions: [
              if (isOrganizer)
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showOrganizerMenu(context, ref, match),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Status & info
              ZuCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(match.club, style: Theme.of(context).textTheme.displaySmall),
                        ),
                        ZuTag(match.statusLabel,
                          style: match.status == MatchStatus.open ? ZuTagStyle.green : ZuTagStyle.neutral),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(icon: '📅', text: df.format(match.startTime)),
                    const SizedBox(height: 4),
                    _InfoRow(icon: '⏱️', text: '${match.durationMinutes} minutes'),
                    if (match.city != null) ...[
                      const SizedBox(height: 4),
                      _InfoRow(icon: '📍', text: match.city!),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        ZuTag(match.levelRange,  style: ZuTagStyle.blue),
                        ZuTag(match.typeLabel,   style: ZuTagStyle.gold),
                        ZuTag(
                          match.visibility == MatchVisibility.public ? 'Public' : 'Sur invitation',
                          style: ZuTagStyle.neutral,
                        ),
                      ],
                    ),
                    if (match.note != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        match.note!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ZuTheme.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Joueurs
              ZuSectionTitle('Joueurs (${match.playerIds.length}/${match.maxPlayers})'),
              const SizedBox(height: 8),
              ZuCard(
                child: Column(
                  children: [
                    ...List.generate(match.maxPlayers, (i) {
                      final filled = i < match.playerIds.length;
                      final isOrg = filled && match.playerIds[i] == match.organizerId;
                      return Column(
                        children: [
                          if (i > 0) const Divider(height: 16),
                          Row(
                            children: [
                              ZuAvatar(initials: filled ? 'J${i+1}' : '', size: 36),
                              const SizedBox(width: 12),
                              Expanded(
                                child: filled
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Joueur ${i + 1}',
                                            style: Theme.of(context).textTheme.headlineSmall),
                                          if (isOrg)
                                            Text('Organisateur', style: Theme.of(context).textTheme.bodySmall),
                                        ],
                                      )
                                    : Text('Place disponible',
                                        style: Theme.of(context).textTheme.bodySmall),
                              ),
                              if (isOrg) const Text('👑'),
                              if (isOrganizer && filled && !isOrg)
                                TextButton(
                                  onPressed: () => _kickPlayer(context, ref, match, match.playerIds[i]),
                                  child: Text('Retirer',
                                    style: GoogleFonts.syne(fontSize: 11, color: ZuTheme.accentRed)),
                                ),
                            ],
                          ),
                        ],
                      );
                    }),
                    // Pending
                    if (match.pendingIds.isNotEmpty && isOrganizer) ...[
                      const Divider(height: 20),
                      Text('En attente (${match.pendingIds.length})',
                        style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 10),
                      ...match.pendingIds.map((pid) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            ZuAvatar(initials: '?', size: 32),
                            const SizedBox(width: 10),
                            const Expanded(child: Text('Joueur en attente')),
                            TextButton(
                              onPressed: () => _acceptPlayer(context, ref, match.id, pid),
                              child: Text('Accepter',
                                style: GoogleFonts.syne(fontSize: 11, color: ZuTheme.accent)),
                            ),
                            TextButton(
                              onPressed: () => _refusePlayer(context, ref, match.id, pid),
                              child: Text('Refuser',
                                style: GoogleFonts.syne(fontSize: 11, color: ZuTheme.accentRed)),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Mise enjeu (si match ouvert, joueur non inscrit)
              if (match.status == MatchStatus.open && !isPlayer && !isOrganizer) ...[
                ZuSectionTitle('Mise enjeu'),
                const SizedBox(height: 8),
                ZuCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Parie sur ta victoire',
                                  style: Theme.of(context).textTheme.headlineSmall),
                                const SizedBox(height: 4),
                                Text('Gagne les crédits misés par les perdants',
                                  style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                          ZuTag('+1 ⬡ si victoire', style: ZuTagStyle.green),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Score (match terminé)
              if (match.status == MatchStatus.finished && match.score != null) ...[
                ZuSectionTitle('Résultat'),
                const SizedBox(height: 8),
                ZuCard(
                  child: Center(
                    child: Text(
                      match.score!,
                      style: GoogleFonts.syne(
                        fontSize: 28, fontWeight: FontWeight.w800, color: ZuTheme.accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Actions
              if (match.status == MatchStatus.open && !isPlayer && !isOrganizer)
                ZuButton(
                  label: 'Rejoindre ce match · −1 crédit',
                  onPressed: () => _joinMatch(context, ref, match),
                )
              else if (isOrganizer && match.status == MatchStatus.open)
                Column(
                  children: [
                    ZuButton(
                      label: 'Terminer le match',
                      onPressed: () => context.go('/matches/$matchId/finish'),
                    ),
                    const SizedBox(height: 10),
                    ZuButton(
                      label: 'Annuler le match',
                      outlined: true,
                      color: ZuTheme.accentRed,
                      onPressed: () => _cancelMatch(context, ref, matchId),
                    ),
                  ],
                )
              else if (isPlayer && match.status == MatchStatus.finished) ...[
                ZuButton(
                  label: 'Laisser un avis · +1 crédit',
                  onPressed: () => context.go('/matches/$matchId/review'),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  void _joinMatch(BuildContext context, WidgetRef ref, ZuMatch match) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ZuTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _JoinSheet(match: match, ref: ref),
    );
  }

  void _showOrganizerMenu(BuildContext ctx, WidgetRef ref, ZuMatch match) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: ZuTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _OrganizerMenuSheet(match: match, ref: ref),
    );
  }

  Future<void> _acceptPlayer(BuildContext ctx, WidgetRef ref, String matchId, String playerId) async {
    await ref.read(matchServiceProvider).acceptPlayer(matchId: matchId, playerId: playerId);
  }

  Future<void> _refusePlayer(BuildContext ctx, WidgetRef ref, String matchId, String playerId) async {
    await ref.read(matchServiceProvider).refusePlayer(matchId: matchId, playerId: playerId);
  }

  Future<void> _kickPlayer(BuildContext ctx, WidgetRef ref, ZuMatch match, String playerId) async {
    // TODO: confirm dialog
    await ref.read(matchServiceProvider).removePlayer(matchId: match.id, playerId: playerId);
  }

  Future<void> _cancelMatch(BuildContext ctx, WidgetRef ref, String matchId) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: ZuTheme.bgCard,
        title: const Text('Annuler le match ?'),
        content: const Text('Tous les joueurs seront remboursés automatiquement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ZuTheme.accentRed),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(matchServiceProvider).cancelMatch(matchId: matchId);
      if (ctx.mounted) ctx.pop();
    }
  }
}

// ══════════════════════════════════════════════
//  AVIS POST-MATCH
// ══════════════════════════════════════════════

class PostMatchReviewScreen extends ConsumerStatefulWidget {
  final String matchId;
  const PostMatchReviewScreen({super.key, required this.matchId});

  @override
  ConsumerState<PostMatchReviewScreen> createState() => _PostMatchReviewScreenState();
}

class _PostMatchReviewScreenState extends ConsumerState<PostMatchReviewScreen> {
  int _stars = 0;
  final _commentController = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final matchAsync = ref.watch(matchDetailProvider(widget.matchId));

    return Scaffold(
      appBar: AppBar(title: const Text('Avis post-match')),
      body: matchAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (match) => match == null
            ? const Center(child: Text('Match introuvable'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Match recap
                  ZuCard(
                    child: Column(
                      children: [
                        const Text('🏓', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        Text('Match terminé !', style: Theme.of(context).textTheme.headlineLarge),
                        if (match.score != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            match.score!,
                            style: GoogleFonts.syne(
                              fontSize: 18, fontWeight: FontWeight.w800, color: ZuTheme.accent,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          'Laisse un avis et gagne +1 crédit',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Note globale
                  ZuSectionTitle('Ta note globale'),
                  const SizedBox(height: 8),
                  ZuCard(
                    child: Column(
                      children: [
                        ZuStarRating(
                          initialValue: _stars,
                          onChanged: (v) => setState(() => _stars = v),
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _starLabel(_stars),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Commentaire
                  TextFormField(
                    controller: _commentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Commentaire (optionnel)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),

                  ZuButton(
                    label: 'Envoyer · +1 crédit offert',
                    loading: _loading,
                    onPressed: _stars == 0 ? null : _submit,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }

  String _starLabel(int s) => switch (s) {
    1 => 'Très décevant',
    2 => 'Décevant',
    3 => 'Correct',
    4 => 'Très bien',
    5 => 'Excellent !',
    _ => 'Sélectionne une note',
  };

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref.read(matchServiceProvider).leaveReview(
        matchId: widget.matchId,
        stars:   _stars,
        comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      );
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZuTheme.bgCard,
            content: Row(
              children: [
                const Text('⬡ ', style: TextStyle(fontSize: 16)),
                Text('+1 crédit offert pour ton avis !',
                  style: TextStyle(color: ZuTheme.accent, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─── Helpers ────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(icon, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 8),
      Text(text, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? ZuTheme.accent.withOpacity(0.15) : ZuTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? ZuTheme.accent : ZuTheme.borderColor,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: active ? ZuTheme.accent : ZuTheme.textSecondary,
        ),
      ),
    ),
  );
}

class _JoinSheet extends StatefulWidget {
  final ZuMatch match;
  final WidgetRef ref;
  const _JoinSheet({required this.match, required this.ref});

  @override
  State<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends State<_JoinSheet> {
  bool _bet = false;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(context).viewInsets.bottom + 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rejoindre', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 4),
          Text(widget.match.club, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          ZuCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mise enjeu (optionnel)', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 3),
                      Text('−1 crédit · gagner si victoire', style: Theme.of(context).textTheme.bodySmall),
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
          ZuButton(
            label: 'Rejoindre · −${_bet ? 2 : 1} crédit${_bet ? 's' : ''}',
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
          const SnackBar(content: Text('Demande envoyée !')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _OrganizerMenuSheet extends StatelessWidget {
  final ZuMatch match;
  final WidgetRef ref;
  const _OrganizerMenuSheet({required this.match, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Gérer le match', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 16),
          _MenuItem(icon: '✅', label: 'Valider le match', onTap: () {
            Navigator.pop(context);
            ref.read(matchServiceProvider).finishMatch(matchId: match.id);
          }),
          _MenuItem(icon: '🔗', label: 'Partager le match', onTap: () {
            Navigator.pop(context);
          }),
          _MenuItem(icon: '❌', label: 'Annuler le match', color: ZuTheme.accentRed, onTap: () {
            Navigator.pop(context);
            ref.read(matchServiceProvider).cancelMatch(matchId: match.id);
          }),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _MenuItem({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Text(icon, style: const TextStyle(fontSize: 20)),
    title: Text(
      label,
      style: GoogleFonts.syne(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: color ?? ZuTheme.textPrimary,
      ),
    ),
    onTap: onTap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}
