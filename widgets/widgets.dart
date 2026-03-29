import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/zu_theme.dart';
import '../models/models.dart';
import 'package:intl/intl.dart';

// ─── ZuCard ─────────────────────────────────────────────────────

class ZuCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  const ZuCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: ZuTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? ZuTheme.borderColor),
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }
}

// ─── ZuTag ──────────────────────────────────────────────────────

enum ZuTagStyle { green, blue, red, gold, neutral }

class ZuTag extends StatelessWidget {
  final String label;
  final ZuTagStyle style;

  const ZuTag(this.label, {super.key, this.style = ZuTagStyle.neutral});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (style) {
      ZuTagStyle.green   => (ZuTheme.accent.withOpacity(0.15),  ZuTheme.accent),
      ZuTagStyle.blue    => (ZuTheme.accent2.withOpacity(0.12), ZuTheme.accent2),
      ZuTagStyle.red     => (ZuTheme.accentRed.withOpacity(0.15), ZuTheme.accentRed),
      ZuTagStyle.gold    => (ZuTheme.accentGold.withOpacity(0.15), ZuTheme.accentGold),
      ZuTagStyle.neutral => (Colors.white.withOpacity(0.06), ZuTheme.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: GoogleFonts.syne(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// ─── ZuCreditChip ───────────────────────────────────────────────

class ZuCreditChip extends StatelessWidget {
  final int credits;
  final VoidCallback? onTap;

  const ZuCreditChip({super.key, required this.credits, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ZuTheme.accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ZuTheme.accent.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('⬡', style: TextStyle(fontSize: 12, color: ZuTheme.accent)),
            const SizedBox(width: 5),
            Text(
              '$credits crédits',
              style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w700, color: ZuTheme.accent),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ZuButton ───────────────────────────────────────────────────

class ZuButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool loading;
  final Widget? icon;
  final Color? color;

  const ZuButton({
    super.key,
    required this.label,
    this.onPressed,
    this.outlined = false,
    this.loading = false,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? ZuTheme.accent;
    final child = loading
        ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: outlined ? c : ZuTheme.bgPrimary,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 8)],
              Text(label),
            ],
          );

    if (outlined) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: c,
            side: BorderSide(color: c),
          ),
          child: child,
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: c),
        child: child,
      ),
    );
  }
}

// ─── ZuAvatar ───────────────────────────────────────────────────

class ZuAvatar extends StatelessWidget {
  final String? photoUrl;
  final String initials;
  final double size;
  final Color? bgColor;

  const ZuAvatar({
    super.key,
    this.photoUrl,
    required this.initials,
    this.size = 40,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          photoUrl!,
          width: size, height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: bgColor ?? ZuTheme.bgCard,
      borderRadius: BorderRadius.circular(size / 2),
      border: Border.all(color: ZuTheme.borderColor),
    ),
    child: Center(
      child: Text(
        initials.toUpperCase(),
        style: GoogleFonts.syne(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w700,
          color: ZuTheme.accent,
        ),
      ),
    ),
  );
}

// ─── ZuSectionTitle ─────────────────────────────────────────────

class ZuSectionTitle extends StatelessWidget {
  final String title;
  final Widget? action;

  const ZuSectionTitle(this.title, {super.key, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.syne(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ZuTheme.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

// ─── ZuStarRating ───────────────────────────────────────────────

class ZuStarRating extends StatefulWidget {
  final int initialValue;
  final ValueChanged<int>? onChanged;
  final double size;

  const ZuStarRating({
    super.key,
    this.initialValue = 0,
    this.onChanged,
    this.size = 28,
  });

  @override
  State<ZuStarRating> createState() => _ZuStarRatingState();
}

class _ZuStarRatingState extends State<ZuStarRating> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < _value;
        return GestureDetector(
          onTap: () {
            setState(() => _value = i + 1);
            widget.onChanged?.call(i + 1);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              color: filled ? ZuTheme.accentGold : ZuTheme.textMuted,
              size: widget.size,
            ),
          ),
        );
      }),
    );
  }
}

// ─── ZuPlayerSlots ──────────────────────────────────────────────

class ZuPlayerSlots extends StatelessWidget {
  final int maxPlayers;
  final List<String> playerIds;
  final double avatarSize;

  const ZuPlayerSlots({
    super.key,
    required this.maxPlayers,
    required this.playerIds,
    this.avatarSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: avatarSize,
      child: Stack(
        children: List.generate(maxPlayers, (i) {
          final filled = i < playerIds.length;
          return Positioned(
            left: i * (avatarSize * 0.72),
            child: filled
                ? ZuAvatar(
                    initials: '?',
                    size: avatarSize,
                    bgColor: _colors[i % _colors.length],
                  )
                : Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(avatarSize / 2),
                      border: Border.all(
                        color: ZuTheme.accent.withOpacity(0.3),
                        style: BorderStyle.solid,
                        width: 1.5,
                      ),
                      color: ZuTheme.accent.withOpacity(0.04),
                    ),
                    child: Icon(Icons.add, size: 14, color: ZuTheme.accent.withOpacity(0.4)),
                  ),
          );
        }),
      ),
    );
  }

  static const _colors = [
    Color(0xFF1E3A2A),
    Color(0xFF1E2A3A),
    Color(0xFF2A1E3A),
    Color(0xFF3A2A1E),
  ];
}

// ─── ZuLevelSelector ────────────────────────────────────────────

class ZuLevelSelector extends StatefulWidget {
  final int initialLevel;
  final ValueChanged<int> onChanged;

  const ZuLevelSelector({
    super.key,
    required this.initialLevel,
    required this.onChanged,
  });

  @override
  State<ZuLevelSelector> createState() => _ZuLevelSelectorState();
}

class _ZuLevelSelectorState extends State<ZuLevelSelector> {
  late int _level;

  @override
  void initState() {
    super.initState();
    _level = widget.initialLevel;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (i) {
        final l = i + 1;
        final selected = l == _level;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _level = l);
              widget.onChanged(l);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? ZuTheme.accent : ZuTheme.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? ZuTheme.accent : ZuTheme.borderColor,
                ),
              ),
              child: Text(
                '$l',
                textAlign: TextAlign.center,
                style: GoogleFonts.syne(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? ZuTheme.bgPrimary : ZuTheme.textSecondary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── ZuMatchCard ─────────────────────────────────────────────────

class ZuMatchCard extends StatelessWidget {
  final ZuMatch match;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;

  const ZuMatchCard({super.key, required this.match, this.onTap, this.onJoin});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM · HH:mm', 'fr_FR');
    final tagStyle = switch (match.status) {
      MatchStatus.open     => ZuTagStyle.green,
      MatchStatus.full     => ZuTagStyle.red,
      MatchStatus.finished => ZuTagStyle.neutral,
      MatchStatus.cancelled=> ZuTagStyle.red,
      _                    => ZuTagStyle.blue,
    };

    return ZuCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(match.club, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 3),
                    Text(
                      '🕐 ${df.format(match.startTime)} · ${match.durationMinutes} min',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              ZuTag(match.statusLabel, style: tagStyle),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: [
              ZuTag(match.levelRange, style: ZuTagStyle.blue),
              ZuTag(match.typeLabel,
                style: match.type == MatchType.competitive ? ZuTagStyle.gold : ZuTagStyle.neutral),
              if (match.city != null) ZuTag('📍 ${match.city!}', style: ZuTagStyle.neutral),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ZuPlayerSlots(
                maxPlayers: match.maxPlayers,
                playerIds: match.playerIds,
              ),
              const Spacer(),
              Text(
                '${match.playerIds.length}/${match.maxPlayers}',
                style: GoogleFonts.syne(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: match.isFull ? ZuTheme.accentRed : ZuTheme.accent,
                ),
              ),
            ],
          ),
          if (onJoin != null && !match.isFull) ...[
            const SizedBox(height: 12),
            ZuButton(
              label: 'Rejoindre · −1 crédit',
              onPressed: onJoin,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── ZuTournamentCard ───────────────────────────────────────────

class ZuTournamentCard extends StatelessWidget {
  final ZuTournament tournament;
  final VoidCallback? onTap;
  final VoidCallback? onRegister;

  const ZuTournamentCard({
    super.key,
    required this.tournament,
    this.onTap,
    this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM', 'fr_FR');
    final levelColor = switch (tournament.level) {
      'P2000' || 'P1000' => ZuTheme.accentRed,
      'P500'             => ZuTheme.accentGold,
      'P250'             => ZuTheme.accent2,
      _                  => ZuTheme.accent,
    };

    return ZuCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1A2510), const Color(0xFF0F1A1A)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Text(
                  tournament.level,
                  style: GoogleFonts.syne(
                    fontSize: 24, fontWeight: FontWeight.w800, color: levelColor,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ZuTag(
                      tournament.isOpen ? 'Inscriptions ouvertes' : 'Complet',
                      style: tournament.isOpen ? ZuTagStyle.green : ZuTagStyle.red,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tournament.surface} · ${tournament.category}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tournament.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _meta(context, '📅', '${df.format(tournament.startDate)}–${df.format(tournament.endDate)}'),
                    const SizedBox(width: 16),
                    _meta(context, '💶', tournament.isFree ? 'Gratuit' : '${tournament.entryFee.toStringAsFixed(0)}€'),
                    const SizedBox(width: 16),
                    _meta(context, '👤', '${tournament.maxPlayers} max'),
                  ],
                ),
                const SizedBox(height: 10),
                // Spot indicators
                _SpotsBar(maxPlayers: tournament.maxPlayers, filled: tournament.registeredIds.length),
                if (onRegister != null && tournament.isOpen) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: ZuButton(label: "S'inscrire", onPressed: onRegister)),
                      const SizedBox(width: 10),
                      Expanded(child: ZuButton(label: 'Détail', outlined: true, onPressed: onTap)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(BuildContext ctx, String icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(icon, style: const TextStyle(fontSize: 12)),
      const SizedBox(width: 4),
      Text(text, style: Theme.of(ctx).textTheme.bodySmall),
    ],
  );
}

class _SpotsBar extends StatelessWidget {
  final int maxPlayers;
  final int filled;

  const _SpotsBar({required this.maxPlayers, required this.filled});

  @override
  Widget build(BuildContext context) {
    final count = maxPlayers.clamp(1, 24);
    return Wrap(
      spacing: 3, runSpacing: 3,
      children: List.generate(count, (i) {
        final taken = i < filled;
        return Container(
          width: 16, height: 6,
          decoration: BoxDecoration(
            color: taken ? ZuTheme.accent : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ─── ZuCoachCard ────────────────────────────────────────────────

class ZuCoachCard extends StatelessWidget {
  final ZuCoach coach;
  final VoidCallback? onTap;

  const ZuCoachCard({super.key, required this.coach, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ZuCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZuAvatar(
                photoUrl: coach.photoUrl,
                initials: '${coach.firstName[0]}${coach.lastName[0]}',
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(coach.fullName, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Row(
                          children: List.generate(5, (i) => Icon(
                            i < coach.avgRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: ZuTheme.accentGold, size: 14,
                          )),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${coach.avgRating.toStringAsFixed(1)} (${coach.ratingCount} avis)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5, runSpacing: 5,
                      children: coach.specialties
                          .map((s) => ZuTag(s, style: ZuTagStyle.blue))
                          .toList(),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: ZuTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ZuTheme.accent.withOpacity(0.3)),
                ),
                child: Text(
                  '${coach.hourlyRate.toStringAsFixed(0)}€/h',
                  style: GoogleFonts.syne(
                    fontSize: 12, fontWeight: FontWeight.w700, color: ZuTheme.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '📍 ${coach.city} · ${coach.playerLevels.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ZuButton(label: 'Voir le profil', outlined: true, onPressed: onTap),
        ],
      ),
    );
  }
}

// ─── ZuEmptyState ───────────────────────────────────────────────

class ZuEmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButton;

  const ZuEmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButton,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ZuTheme.textSecondary), textAlign: TextAlign.center),
            if (buttonLabel != null && onButton != null) ...[
              const SizedBox(height: 24),
              SizedBox(width: 200, child: ZuButton(label: buttonLabel!, onPressed: onButton)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── ZuShimmer ──────────────────────────────────────────────────

class ZuShimmerCard extends StatelessWidget {
  const ZuShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: ZuTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZuTheme.borderColor),
      ),
    );
  }
}
