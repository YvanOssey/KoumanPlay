import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/game_rules.dart';
import '../core/theme.dart';
import '../services/providers.dart';
import 'cauris.dart';
import 'fx.dart';
import 'guide.dart';
import 'mascot.dart';

/// Couleurs de la flamme selon son palier : simple, 7 jours, dorée, éternelle.
const _flameColors = [
  [Color(0xFFFF8A00), Color(0xFFFFD166)],
  [Color(0xFFE5482A), Color(0xFFFFB13B)],
  [Color(0xFFD4A017), Color(0xFFFFF1A8)],
  [Color(0xFF6C3BFF), Color(0xFF9BE7FF)],
];

/// La Flamme du savoir, qui danse. [lit] : déjà nourrie aujourd'hui ; sinon
/// elle vacille, plus pâle.
class FlameIcon extends StatefulWidget {
  const FlameIcon({super.key, required this.tier, this.lit = true, this.size = 24});

  final int tier;
  final bool lit;
  final double size;

  @override
  State<FlameIcon> createState() => _FlameIconState();
}

class _FlameIconState extends State<FlameIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size(widget.size * 0.8, widget.size),
          painter: _FlamePainter(t: _c.value, colors: _flameColors[widget.tier.clamp(0, 3)], lit: widget.lit),
        ),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  _FlamePainter({required this.t, required this.colors, required this.lit});

  final double t;
  final List<Color> colors;
  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final sway = sin(t * 2 * pi) * w * (lit ? 0.08 : 0.04);
    final stretch = 1 + sin(t * 4 * pi) * (lit ? 0.05 : 0.02);
    Path flame(double scale, double dx) {
      final fw = w * scale, fh = h * scale * stretch;
      final cx = w / 2 + dx, bottom = h;
      return Path()
        ..moveTo(cx, bottom - fh)
        ..cubicTo(
          cx + fw * 0.15 + sway,
          bottom - fh * 0.6,
          cx + fw * 0.55,
          bottom - fh * 0.45,
          cx + fw * 0.45,
          bottom - fh * 0.2,
        )
        ..quadraticBezierTo(cx + fw * 0.4, bottom, cx, bottom)
        ..quadraticBezierTo(cx - fw * 0.4, bottom, cx - fw * 0.45, bottom - fh * 0.2)
        ..cubicTo(cx - fw * 0.55, bottom - fh * 0.45, cx - fw * 0.1 + sway, bottom - fh * 0.55, cx, bottom - fh)
        ..close();
    }

    final outer = lit ? colors[0] : const Color(0xFFB8B2C4);
    final inner = lit ? colors[1] : const Color(0xFFE2DEE8);
    canvas.drawPath(flame(1, 0), Paint()..color = outer);
    canvas.drawPath(flame(0.58, sway * 0.4), Paint()..color = inner);
  }

  @override
  bool shouldRepaint(covariant _FlamePainter old) => true;
}

/// Pastille de la flamme pour l'en-tête de la carte ; ouvre son explication.
class FlameChip extends ConsumerWidget {
  const FlameChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final now = DateTime.now();
    final days = GameRules.flameOf(player, now);
    final lit = days > 0 && GameRules.isFlameFed(player, now);
    return Material(
      color: AppColors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const FlameSheet(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FlameIcon(tier: GameRules.flameTier(days), lit: lit, size: 20),
              const SizedBox(width: 4),
              Text(
                '$days',
                style: TextStyle(fontWeight: FontWeight.w800, color: lit ? const Color(0xFFE5482A) : AppColors.gray500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Explication de la Flamme du savoir : série, paliers, protège-flammes.
class FlameSheet extends ConsumerWidget {
  const FlameSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final now = DateTime.now();
    final days = GameRules.flameOf(player, now);
    final fed = GameRules.isFlameFed(player, now);
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(AppSpacing.screen),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(AppRadius.largeCard)),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FlameIcon(tier: GameRules.flameTier(days), lit: days > 0 && fed, size: 54),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('La Flamme du savoir', style: theme.textTheme.titleLarge),
                      Text(
                        days == 0
                            ? 'Joue aujourd\'hui pour l\'allumer.'
                            : '$days jour${days > 1 ? 's' : ''} d\'affilée${fed ? '' : ' · joue aujourd\'hui pour la garder'}',
                        style: const TextStyle(color: AppColors.gray700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.section),
            for (final MapEntry(key: m, value: cauris) in GameRules.flameMilestones.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      player.flameClaimed.contains(m)
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: player.flameClaimed.contains(m) ? AppColors.green500 : AppColors.gray400,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(switch (m) {
                        3 => '3 jours : la flamme s\'allume',
                        7 => '7 jours : badge Gardien de la flamme',
                        30 => '30 jours : la flamme devient dorée',
                        _ => '100 jours : la flamme éternelle',
                      }, style: const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    if (cauris > 0) ...[
                      const CauriIcon(size: 16),
                      Text(
                        ' $cauris',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: caurisColor),
                      ),
                    ],
                  ],
                ),
              ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.shield_rounded, color: AppColors.purple500),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Protège-flamme : ${player.flameShields}/${GameRules.flameShieldMax}\n'
                    'Sauve ta série si tu manques un jour.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: player.flameShields >= GameRules.flameShieldMax
                      ? null
                      : () async {
                          final ok = await ref.read(playerProvider.notifier).buyFlameShield();
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Pas assez de cauris pour un protège-flamme.')),
                            );
                          }
                        },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [const CauriIcon(size: 16), Text(' ${GameRules.flameShieldPrice}')],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Place l'écran de fête d'un palier de la flamme au-dessus de toute l'app.
class FlameCelebrationHost extends ConsumerWidget {
  const FlameCelebrationHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(flameEventProvider);
    return Stack(
      children: [
        child,
        if (days != null)
          Positioned.fill(
            child: _FlameCelebration(
              key: ValueKey(days),
              days: days,
              onClose: () => ref.read(flameEventProvider.notifier).clear(),
            ),
          ),
      ],
    );
  }
}

class _FlameCelebration extends ConsumerStatefulWidget {
  const _FlameCelebration({super.key, required this.days, required this.onClose});

  final int days;
  final VoidCallback onClose;

  @override
  ConsumerState<_FlameCelebration> createState() => _FlameCelebrationState();
}

class _FlameCelebrationState extends ConsumerState<_FlameCelebration> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(soundProvider).play(widget.days >= 7 ? 'win' : 'match');
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    final big = days >= 100;
    final cauris = GameRules.flameMilestones[days] ?? 0;
    final (title, text) = switch (days) {
      3 => ('Ta flamme s\'allume !', '3 jours d\'affilée. Reviens demain pour la faire grandir.'),
      7 => ('Gardien de la flamme', '7 jours d\'affilée ! Tu gagnes un nouveau badge.'),
      30 => ('Flamme dorée', '30 jours d\'affilée : ta flamme brille d\'or. Les aînés sont fiers de toi.'),
      _ => ('Flamme éternelle', '100 jours d\'affilée ! Tu es un vrai gardien du savoir de nos aînés.'),
    };
    return Material(
      color: const Color(0xFF160D2B).withValues(alpha: 0.97),
      child: Stack(
        children: [
          Positioned.fill(child: ConfettiBurst(trigger: days >= 7 ? days : 0, big: true)),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Reveal(
                      delay: Duration.zero,
                      pop: true,
                      child: FlameIcon(tier: GameRules.flameTier(days), size: big ? 150 : 110),
                    ),
                    const SizedBox(height: 8),
                    Reveal(
                      delay: const Duration(milliseconds: 250),
                      child: Text(
                        '$days',
                        style: const TextStyle(color: AppColors.white, fontSize: 56, fontWeight: FontWeight.w900),
                      ),
                    ),
                    Reveal(
                      delay: const Duration(milliseconds: 400),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.gold, fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Reveal(
                      delay: const Duration(milliseconds: 550),
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.white.withValues(alpha: 0.85)),
                      ),
                    ),
                    if (cauris > 0) ...[
                      const SizedBox(height: 14),
                      Reveal(
                        delay: const Duration(milliseconds: 700),
                        pop: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CauriIcon(size: 26),
                            CountUp(
                              value: cauris,
                              prefix: ' +',
                              delay: const Duration(milliseconds: 800),
                              style: const TextStyle(color: AppColors.gold, fontSize: 22, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // La mascotte fête chaque palier ; Grand-père Kouman vient pour les 100 jours.
                    Reveal(
                      delay: const Duration(milliseconds: 600),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Mascot(mood: MascotMood.cheer, size: big ? 110 : 90),
                          if (big) ...[const SizedBox(width: 8), const ElderGuide(size: 150, wave: 1)],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(onPressed: widget.onClose, child: const Text('Merci !')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
