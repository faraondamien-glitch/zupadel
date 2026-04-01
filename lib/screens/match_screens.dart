import 'dart:async';
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
  bool _todayOnly    = false;
  int? _filterLevel;
  bool _geoDisabled  = false; // "Voir tous les matchs" — désactive le filtre 30 km
  final _searchCtrl  = TextEditingController();
  String _search     = '';
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posAsync = ref.watch(userPositionProvider);
    final matches  = ref.watch(filteredMatchesProvider(
      MatchFilter(type: _filterType, todayOnly: _todayOnly, level: _filterLevel),
    ));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trouver un match'),
        actions: [
          // Indicateur GPS chargement
          if (posAsync.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ZuTheme.accent),
                ),
              ),
            )
          else if (posAsync.valueOrNull != null && !_geoDisabled)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Tooltip(
                message: 'Filtre 30 km actif',
                child: const Icon(Icons.location_on, color: ZuTheme.accent, size: 20),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Barre de recherche ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() => _search = v.trim().toLowerCase());
                });
              },
              decoration: InputDecoration(
                hintText: 'Rechercher un club...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),

          // ── Filter chips ──────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
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
                Tooltip(
                  message: 'Affiche uniquement les matchs compatibles avec ton niveau (±1)',
                  child: _FilterChip(
                    label: 'Niveau compatible',
                    active: _filterLevel != null,
                    onTap: () => setState(() => _filterLevel = _filterLevel == null ? 4 : null),
                  ),
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
              data: (list) {
                // Filtre recherche
                var filtered = _search.isEmpty
                    ? list
                    : list.where((m) =>
                        m.club.toLowerCase().contains(_search) ||
                        (m.city?.toLowerCase().contains(_search) ?? false)).toList();

                // Filtre géo (si position disponible et non désactivé)
                final pos = ref.watch(userPositionProvider).valueOrNull;
                if (pos != null && !_geoDisabled) {
                  filtered = filtered.where((m) {
                    if (m.location == null) return true;
                    return LocationService.withinRadius(m.location!, pos);
                  }).toList();
                }

                if (filtered.isEmpty) {
                  // Si filtre géo actif → proposer d'élargir
                  if (pos != null && !_geoDisabled) {
                    return ZuEmptyState(
                      emoji: '📍',
                      title: 'Aucun match à 30 km',
                      subtitle: 'Pas de match dans ta zone pour le moment.',
                      buttonLabel: 'Voir tous les matchs',
                      onButton: () => setState(() => _geoDisabled = true),
                    );
                  }
                  return ZuEmptyState(
                    emoji: '🎾',
                    title: 'Aucun match disponible',
                    subtitle: 'Sois le premier à créer un match !',
                    buttonLabel: 'Créer un match',
                    onButton: () => context.go('/matches/create'),
                  );
                }
                return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ZuMatchCard(
                          match: filtered[i],
                          onTap:  () => context.go('/matches/${filtered[i].id}'),
                          onJoin: filtered[i].status == MatchStatus.open
                              ? () => _joinMatch(ctx, filtered[i])
                              : null,
                        ),
                      ),
                    );
              },
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
  // ── État du stepper ────────────────────────────────────────────
  int _step = 0;
  static const int _totalSteps = 3;

  // ── Données du match ───────────────────────────────────────────
  final _clubController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _startTime = DateTime.now().add(const Duration(hours: 2));
  int _duration  = 90;
  int _levelMin  = 3;
  int _levelMax  = 5;
  int _maxPlayers = 4;
  MatchType       _type       = MatchType.competitive;
  MatchVisibility _visibility = MatchVisibility.public;
  bool _loading = false;

  // ── Validation par étape ───────────────────────────────────────
  bool get _step0Valid => _clubController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _clubController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_stepTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == 0) {
              context.pop();
            } else {
              setState(() => _step--);
            }
          },
        ),
      ),
      body: Column(
        children: [
          // ── Barre de progression ─────────────────────────────
          _StepProgressBar(current: _step, total: _totalSteps),

          // ── Contenu de l'étape ───────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.08, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: KeyedSubtree(
                key: ValueKey(_step),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: _buildStepContent(context),
                ),
              ),
            ),
          ),
        ],
      ),

      // ── Bouton de navigation flottant ────────────────────────
      bottomNavigationBar: _BottomNavBar(
        step:      _step,
        totalSteps: _totalSteps,
        canNext:   _step == 0 ? _step0Valid : true,
        loading:   _loading,
        onNext:    _goNext,
      ),
    );
  }

  String get _stepTitle => switch (_step) {
    0 => 'Où et quand ?',
    1 => 'Le match',
    _ => 'Récapitulatif',
  };

  List<Widget> _buildStepContent(BuildContext context) => switch (_step) {
    0 => _buildStep0(context),
    1 => _buildStep1(context),
    _ => _buildStep2(context),
  };

  // ── Étape 0 : Où & Quand ──────────────────────────────────────
  List<Widget> _buildStep0(BuildContext context) => [
    TextFormField(
      controller: _clubController,
      onChanged: (_) => setState(() {}), // refresh "canNext"
      decoration: const InputDecoration(
        labelText: 'Club / Lieu',
        prefixIcon: Icon(Icons.location_on_outlined),
        helperText: 'Ex : Padel de Paris, Boulogne…',
      ),
      textInputAction: TextInputAction.done,
    ),
    const SizedBox(height: 16),

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

    Text('Durée', style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 10),
    Row(
      children: [60, 90, 120].map((d) {
        final sel = _duration == d;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => setState(() => _duration = d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: sel ? ZuTheme.accent.withOpacity(0.15) : ZuTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel ? ZuTheme.accent : ZuTheme.borderColor,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$d',
                      style: GoogleFonts.syne(
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: sel ? ZuTheme.accent : ZuTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'min',
                      style: GoogleFonts.dmSans(
                        fontSize: 11, color: ZuTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  ];

  // ── Étape 1 : Le match ────────────────────────────────────────
  List<Widget> _buildStep1(BuildContext context) => [
    Text('Niveaux acceptés', style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 4),
    Text(
      'Niveau $_levelMin → $_levelMax  (sur 7)',
      style: Theme.of(context).textTheme.bodySmall,
    ),
    const SizedBox(height: 8),
    RangeSlider(
      values: RangeValues(_levelMin.toDouble(), _levelMax.toDouble()),
      min: 1, max: 7, divisions: 6,
      activeColor: ZuTheme.accent,
      inactiveColor: ZuTheme.borderColor,
      labels: RangeLabels('$_levelMin', '$_levelMax'),
      onChanged: (v) => setState(() {
        _levelMin = v.start.round();
        _levelMax = v.end.round();
      }),
    ),
    const SizedBox(height: 20),

    Text('Type de match', style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 10),
    ...MatchType.values.map((t) {
      final sel = _type == t;
      final (emoji, label, sub) = switch (t) {
        MatchType.competitive => ('🏆', 'Compétitif',  'Classement et mise enjeu activés'),
        MatchType.leisure     => ('😊', 'Loisir',      'Détendu, sans enjeu'),
        MatchType.training    => ('🎯', 'Training',    'Entraînement technique'),
      };
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: () => setState(() => _type = t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sel ? ZuTheme.accent.withOpacity(0.1) : ZuTheme.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: sel ? ZuTheme.accent : ZuTheme.borderColor,
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                        style: GoogleFonts.syne(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: sel ? ZuTheme.accent : ZuTheme.textPrimary,
                        )),
                      const SizedBox(height: 2),
                      Text(sub, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (sel) Icon(Icons.check_circle, color: ZuTheme.accent, size: 20),
              ],
            ),
          ),
        ),
      );
    }),
    const SizedBox(height: 20),

    Text('Nombre de joueurs', style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 10),
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
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: sel ? ZuTheme.accent.withOpacity(0.12) : ZuTheme.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: sel ? ZuTheme.accent : ZuTheme.borderColor,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      n == 2 ? '👥' : '👥👥',
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$n joueurs',
                      style: GoogleFonts.syne(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: sel ? ZuTheme.accent : ZuTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  ];

  // ── Étape 2 : Récapitulatif ───────────────────────────────────
  List<Widget> _buildStep2(BuildContext context) => [
    ZuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Récapitulatif', style: Theme.of(context).textTheme.displaySmall),
          const Divider(height: 20),
          _RecapRow(icon: '📍', label: _clubController.text.trim()),
          _RecapRow(
            icon: '📅',
            label: DateFormat('EEE d MMM à HH:mm', 'fr_FR').format(_startTime),
          ),
          _RecapRow(icon: '⏱️', label: '$_duration min'),
          _RecapRow(icon: '📊', label: 'Niveau $_levelMin → $_levelMax'),
          _RecapRow(
            icon: switch (_type) {
              MatchType.competitive => '🏆',
              MatchType.leisure     => '😊',
              MatchType.training    => '🎯',
            },
            label: switch (_type) {
              MatchType.competitive => 'Compétitif',
              MatchType.leisure     => 'Loisir',
              MatchType.training    => 'Training',
            },
          ),
          _RecapRow(icon: '👥', label: '$_maxPlayers joueurs max'),
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

    TextFormField(
      controller: _noteController,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Message pour les joueurs (optionnel)',
        alignLabelWithHint: true,
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
  ];

  // ── Helpers ──────────────────────────────────────────────────
  Future<void> _goNext() async {
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      await _submit();
    }
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
    setState(() =>
      _startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  Future<void> _submit() async {
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

// ── Barre de progression ─────────────────────────────────────────

class _StepProgressBar extends StatelessWidget {
  final int current;
  final int total;
  const _StepProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: List.generate(total, (i) {
          final done   = i < current;
          final active = i == current;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: done || active ? ZuTheme.accent : ZuTheme.borderColor,
                  boxShadow: active ? [
                    BoxShadow(color: ZuTheme.accent.withOpacity(0.4), blurRadius: 4),
                  ] : null,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Barre de navigation bas ───────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final int step;
  final int totalSteps;
  final bool canNext;
  final bool loading;
  final VoidCallback onNext;

  const _BottomNavBar({
    required this.step,
    required this.totalSteps,
    required this.canNext,
    required this.loading,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = step == totalSteps - 1;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: ZuButton(
          label: isLast ? 'Publier le match · −1 crédit' : 'Suivant',
          loading: loading,
          onPressed: canNext ? onNext : null,
        ),
      ),
    );
  }
}

// ── Ligne recap ──────────────────────────────────────────────────

class _RecapRow extends StatelessWidget {
  final String icon;
  final String label;
  const _RecapRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 10),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
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
              // Banner notifiedCount (visible uniquement pour l'organisateur juste après création)
              if (isOrganizer && (match.notifiedCount ?? 0) > 0) ...[
                _NotifiedBanner(count: match.notifiedCount!),
                const SizedBox(height: 12),
              ],
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
                      ...match.pendingIds.map((pid) {
                        final mini = ref.watch(playerMiniProvider(pid)).valueOrNull;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              ZuAvatar(
                                photoUrl: mini?.photoUrl,
                                initials: mini?.initials ?? '?',
                                size: 36,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mini != null
                                          ? '${mini.firstName} ${mini.lastName}'.trim()
                                          : 'Chargement…',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
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
                        );
                      }),
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

              // Joueurs suggérés (organisateur, match pas plein)
              if (isOrganizer && match.status == MatchStatus.open && !match.isFull) ...[
                ZuSectionTitle('Joueurs suggérés'),
                const SizedBox(height: 8),
                _SuggestedPlayersSection(matchId: matchId),
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

// ─── Banner notifiedCount ────────────────────────────────────────

class _NotifiedBanner extends StatelessWidget {
  final int count;
  const _NotifiedBanner({required this.count});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: ZuTheme.accent.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ZuTheme.accent.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        const Text('⚡', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$count joueur${count > 1 ? 's' : ''} compatible${count > 1 ? 's' : ''} notifié${count > 1 ? 's' : ''}',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ZuTheme.accent,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── Joueurs suggérés ────────────────────────────────────────────

class _SuggestedPlayersSection extends ConsumerStatefulWidget {
  final String matchId;
  const _SuggestedPlayersSection({required this.matchId});

  @override
  ConsumerState<_SuggestedPlayersSection> createState() => _SuggestedPlayersSectionState();
}

class _SuggestedPlayersSectionState extends ConsumerState<_SuggestedPlayersSection> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _suggestions = [];
  final Set<String> _invited = {};

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    try {
      final result = await ref.read(matchmakingServiceProvider)
          .getMatchSuggestions(widget.matchId);
      if (mounted) {
        setState(() {
          _suggestions = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _invite(String uid) async {
    setState(() => _invited.add(uid));
    try {
      await ref.read(matchmakingServiceProvider)
          .invitePlayer(matchId: widget.matchId, invitedUid: uid);
    } catch (e) {
      if (mounted) {
        setState(() => _invited.remove(uid));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return const SizedBox.shrink();
    if (_suggestions.isEmpty) {
      return ZuCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aucun joueur disponible pour l\'instant',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Les joueurs compatibles apparaîtront ici quand ils activeront leur disponibilité.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                setState(() => _loading = true);
                _loadSuggestions();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Rafraîchir'),
              style: TextButton.styleFrom(foregroundColor: ZuTheme.accent),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _suggestions.map((s) {
        final uid       = s['uid'] as String;
        final firstName = s['firstName'] as String? ?? '';
        final lastName  = s['lastName'] as String? ?? '';
        final level     = s['level'] as int? ?? 1;
        final photoUrl  = s['photoUrl'] as String?;
        final score     = s['score'] as int? ?? 0;
        final invited   = _invited.contains(uid);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ZuCard(
            child: Row(
              children: [
                ZuAvatar(
                  photoUrl:  photoUrl,
                  initials:  '${firstName.isNotEmpty ? firstName[0] : '?'}${lastName.isNotEmpty ? lastName[0] : ''}',
                  size: 36,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$firstName $lastName',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        'Niveau $level · $score pts de compatibilité',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (invited)
                  ZuTag('Invité', style: ZuTagStyle.green)
                else
                  TextButton(
                    onPressed: () => _invite(uid),
                    child: Text(
                      'Inviter',
                      style: GoogleFonts.syne(fontSize: 12, color: ZuTheme.accent),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
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
            context.push('/matches/${match.id}/finish');
          }),
          _MenuItem(icon: '🔗', label: 'Partager le match', onTap: () {
            Navigator.pop(context);
          }),
          _MenuItem(icon: '❌', label: 'Annuler le match', color: ZuTheme.accentRed, onTap: () {
            Navigator.pop(context);
            ref.read(matchServiceProvider).cancelMatch(matchId: match.id)
                .catchError((e) => debugPrint('cancelMatch error: $e'));
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

// ══════════════════════════════════════════════
//  TERMINER LE MATCH — SAISIE DU SCORE
// ══════════════════════════════════════════════

class FinishMatchScreen extends ConsumerStatefulWidget {
  final String matchId;
  const FinishMatchScreen({super.key, required this.matchId});

  @override
  ConsumerState<FinishMatchScreen> createState() => _FinishMatchScreenState();
}

class _FinishMatchScreenState extends ConsumerState<FinishMatchScreen> {
  // Chaque set : [scoreTeam1, scoreTeam2]
  final _sets = <(int, int)>[(6, 0)];
  int _winnerTeam = 1; // 1 ou 2
  bool _loading = false;

  void _addSet() {
    if (_sets.length >= 3) return;
    setState(() => _sets.add((6, 0)));
  }

  void _removeSet(int i) {
    if (_sets.length <= 1) return;
    setState(() => _sets.removeAt(i));
  }

  String get _scoreString =>
      _sets.map((s) => '${s.$1}-${s.$2}').join(' / ');

  bool get _isValid {
    // Le gagnant de chaque set doit atteindre 6 (ou 7 pour le super TB)
    for (final s in _sets) {
      final hi = s.$1 > s.$2 ? s.$1 : s.$2;
      if (hi < 6) return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Score invalide — le gagnant doit atteindre 6.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(matchServiceProvider).finishMatch(
        matchId:    widget.matchId,
        score:      _scoreString,
        winnerTeam: _winnerTeam,
      );
      if (mounted) {
        context.go('/matches/${widget.matchId}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match terminé ! Les joueurs peuvent laisser un avis.')),
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
    final matchAsync = ref.watch(matchDetailProvider(widget.matchId));

    return Scaffold(
      appBar: AppBar(title: const Text('Terminer le match')),
      body: matchAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('$e')),
        data:    (match) {
          if (match == null) return const Center(child: Text('Match introuvable'));
          final players = match.playerIds;
          final half    = (players.length / 2).ceil();
          final t1Label = 'Équipe 1';
          final t2Label = 'Équipe 2';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Recap match
              ZuCard(
                child: Row(
                  children: [
                    const Text('🎾', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(match.club, style: Theme.of(context).textTheme.headlineMedium),
                          Text(
                            DateFormat('d MMM à HH:mm', 'fr_FR').format(match.startTime),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Score set par set
              ZuSectionTitle('Score par set'),
              const SizedBox(height: 8),
              ...List.generate(_sets.length, (i) => _SetRow(
                index:     i,
                t1:        _sets[i].$1,
                t2:        _sets[i].$2,
                canRemove: _sets.length > 1,
                onRemove:  () => _removeSet(i),
                onChangeT1: (v) => setState(() => _sets[i] = (v, _sets[i].$2)),
                onChangeT2: (v) => setState(() => _sets[i] = (_sets[i].$1, v)),
              )),
              if (_sets.length < 3)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton.icon(
                    onPressed: _addSet,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Ajouter un set'),
                    style: TextButton.styleFrom(foregroundColor: ZuTheme.accent),
                  ),
                ),
              const SizedBox(height: 20),

              // Aperçu score
              ZuCard(
                borderColor: ZuTheme.accent.withOpacity(0.3),
                child: Center(
                  child: Text(
                    _scoreString,
                    style: GoogleFonts.syne(
                      fontSize: 22, fontWeight: FontWeight.w800, color: ZuTheme.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Sélection de l'équipe gagnante
              ZuSectionTitle('Équipe gagnante'),
              const SizedBox(height: 8),
              Row(
                children: [1, 2].map((team) {
                  final selected = _winnerTeam == team;
                  final label    = team == 1 ? t1Label : t2Label;
                  final subs     = team == 1
                      ? players.sublist(0, half)
                      : (players.length > half ? players.sublist(half) : <String>[]);
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: team == 1 ? 8 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() => _winnerTeam = team),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selected ? ZuTheme.accent.withOpacity(0.15) : ZuTheme.bgCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected ? ZuTheme.accent : ZuTheme.borderColor,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              if (selected)
                                const Text('🏆', style: TextStyle(fontSize: 20)),
                              Text(
                                label,
                                style: GoogleFonts.syne(
                                  fontSize: 14, fontWeight: FontWeight.w700,
                                  color: selected ? ZuTheme.accent : ZuTheme.textSecondary,
                                ),
                              ),
                              Text(
                                '${subs.length} joueur${subs.length > 1 ? 's' : ''}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              ZuButton(
                label: 'Confirmer le résultat',
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final int index, t1, t2;
  final bool canRemove;
  final VoidCallback onRemove;
  final ValueChanged<int> onChangeT1;
  final ValueChanged<int> onChangeT2;

  const _SetRow({
    required this.index, required this.t1, required this.t2,
    required this.canRemove, required this.onRemove,
    required this.onChangeT1, required this.onChangeT2,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ZuCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Text('Set ${index + 1}',
              style: GoogleFonts.syne(fontSize: 12, fontWeight: FontWeight.w700,
                color: ZuTheme.textSecondary)),
            const SizedBox(width: 12),
            _ScoreCounter(value: t1, label: 'Éq.1', onChanged: onChangeT1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('–', style: GoogleFonts.syne(fontSize: 18, color: ZuTheme.textSecondary)),
            ),
            _ScoreCounter(value: t2, label: 'Éq.2', onChanged: onChangeT2),
            const Spacer(),
            if (canRemove)
              GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.remove_circle_outline, color: ZuTheme.accentRed, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCounter extends StatelessWidget {
  final int value;
  final String label;
  final ValueChanged<int> onChanged;

  const _ScoreCounter({required this.value, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      Row(
        children: [
          GestureDetector(
            onTap: value > 0 ? () => onChanged(value - 1) : null,
            child: Icon(Icons.remove_circle, size: 28,
              color: value > 0 ? ZuTheme.accent : ZuTheme.borderColor),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          GestureDetector(
            onTap: value < 7 ? () => onChanged(value + 1) : null,
            child: Icon(Icons.add_circle, size: 28,
              color: value < 7 ? ZuTheme.accent : ZuTheme.borderColor),
          ),
        ],
      ),
    ],
  );
}
