import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../services/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/cauris.dart';
import '../../widgets/energy.dart';
import '../../widgets/fx.dart';
import '../../widgets/mascot.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.outcome});

  final LevelOutcome outcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final content = ref.watch(contentProvider);
    final level = content.level(outcome.levelId);
    final next = GameRules.nextLevel(content, outcome.player);
    final ratio = outcome.total == 0 ? 0.0 : outcome.correct / outcome.total;
    final title = !outcome.passed
        ? 'Presque !'
        : ratio == 1
        ? 'Sans-faute !'
        : 'Niveau validé !';
    // Les résultats apparaissent l'un après l'autre.
    var step = 0;
    Duration later() => Duration(milliseconds: 500 + 220 * step++);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Celebration(
        won: outcome.passed,
        languageId: level?.languageId,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => context.go('/play')),
                    ),
                    Center(
                      child: Reveal(
                        delay: Duration.zero,
                        pop: true,
                        child: Mascot(mood: outcome.passed ? MascotMood.cheer : MascotMood.sad, size: 130),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Eyebrow(
                        '${content.language(level?.languageId ?? '')?.name ?? ''} · Niveau ${level?.order ?? ''}',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(child: Text(title, style: theme.textTheme.headlineMedium)),
                    if (outcome.passed) ...[
                      const SizedBox(height: 6),
                      Center(child: _AnimatedStars(stars: outcome.stars)),
                    ],
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        outcome.passed
                            ? '${outcome.correct} bonnes réponses sur ${outcome.total}.'
                            : 'Il faut ${(level!.passRatio * outcome.total).ceil()} bonnes réponses pour valider. Tu en as ${outcome.correct}.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.gray700),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.section),
                    Reveal(
                      delay: later(),
                      child: Row(
                        children: [
                          Expanded(
                            child: _Stat(
                              label: 'Score',
                              value: outcome.correct,
                              suffix: '/${outcome.total}',
                              delay: Duration(milliseconds: 500 + 220 * (step - 1)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Stat(
                              label: 'XP gagnés',
                              value: outcome.xpGained,
                              prefix: '+',
                              color: AppColors.green500,
                              delay: Duration(milliseconds: 500 + 220 * (step - 1)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (outcome.chestCauris > 0) ...[
                      const SizedBox(height: 12),
                      Reveal(
                        delay: later(),
                        child: _Chest(
                          cauris: outcome.chestCauris,
                          newStars: outcome.stars > outcome.previousStars,
                          delay: Duration(milliseconds: 500 + 220 * (step - 1)),
                        ),
                      ),
                    ],
                    if (outcome.quickCauris > 0) ...[
                      const SizedBox(height: 12),
                      Reveal(
                        delay: later(),
                        child: AppCard(
                          color: const Color(0xFFFFF4DC),
                          border: false,
                          child: Row(
                            children: [
                              const Icon(Icons.bolt_rounded, size: 34, color: AppColors.gold),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Eyebrow('Bonus éclair', color: caurisColor),
                                    Text(
                                      'Pour tes réponses rapides.',
                                      style: TextStyle(color: AppColors.gray700, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              const CauriIcon(size: 22),
                              Text(
                                ' +${outcome.quickCauris}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: caurisColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    for (final quest in outcome.completedQuests) ...[
                      const SizedBox(height: 12),
                      Reveal(
                        delay: later(),
                        child: AppCard(
                          color: AppColors.green100,
                          border: false,
                          child: Row(
                            children: [
                              const Icon(Icons.task_alt_rounded, color: AppColors.green500),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Eyebrow('Quête du jour terminée', color: AppColors.green500),
                                    Text(quest.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              const CauriIcon(size: 18),
                              Text(
                                ' +${quest.reward}',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: caurisColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (outcome.outOfEnergy) ...[
                      const SizedBox(height: 12),
                      AppCard(
                        color: AppColors.errorLight,
                        border: false,
                        child: EnergyBuilder(
                          builder: (context, energy, nextIn) => Row(
                            children: [
                              const Icon(Icons.bolt_rounded, color: AppColors.error),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  energy > 0
                                      ? 'Ton énergie remonte : tu peux rejouer.'
                                      : 'Plus d\'énergie. La prochaine revient dans ${formatWait(nextIn ?? GameRules.energyRefill)}.',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (outcome.xpGained == 0 && outcome.correct > 0) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Ces réponses étaient déjà maîtrisées : elles ne rapportent plus d\'XP.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.gray500, fontSize: 13),
                      ),
                    ],
                    if (outcome.leveledUp) ...[
                      const SizedBox(height: 12),
                      AppCard(
                        color: AppColors.purple100,
                        border: false,
                        child: Text(
                          '⬆️  Tu passes au niveau ${GameRules.playerLevel(outcome.player.xp)} !',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.purple600),
                        ),
                      ),
                    ],
                    for (final badge in outcome.newBadges) ...[
                      const SizedBox(height: 12),
                      Reveal(
                        delay: later(),
                        pop: true,
                        child: AppCard(
                          color: AppColors.purple100,
                          border: false,
                          child: Row(
                            children: [
                              Text(badge.emoji, style: const TextStyle(fontSize: 32)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Eyebrow('Nouveau badge'),
                                    Text(badge.title, style: theme.textTheme.titleMedium),
                                    Text(
                                      badge.description,
                                      style: const TextStyle(color: AppColors.gray500, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    for (final challenge in outcome.unlockedChallenges) ...[
                      const SizedBox(height: 12),
                      AppCard(
                        color: AppColors.green100,
                        border: false,
                        onTap: () => context.push('/challenge/${challenge.id}'),
                        child: Row(
                          children: [
                            const Text('🤝', style: TextStyle(fontSize: 32)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Eyebrow('Défi débloqué', color: AppColors.green500),
                                  Text(challenge.title, style: theme.textTheme.titleMedium),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screen),
                child: Column(
                  children: [
                    if (!outcome.passed)
                      FilledButton(
                        onPressed: () => startLevel(context, ref, outcome.levelId, replace: true),
                        child: const Text('Réessayer'),
                      )
                    else if (next != null)
                      FilledButton(
                        onPressed: () => startLevel(context, ref, next.id, replace: true),
                        child: const Text('Niveau suivant'),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.go('/play'),
                            icon: const Icon(Icons.map_rounded, size: 18),
                            label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Carte')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.pushReplacement('/duels'),
                            icon: const Icon(Icons.sports_kabaddi_rounded, size: 18),
                            label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Défier un ami')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.delay,
    this.prefix = '',
    this.suffix = '',
    this.color = AppColors.black,
  });

  final String label;
  final int value;
  final String prefix;
  final String suffix;
  final Duration delay;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          CountUp(
            value: value,
            prefix: prefix,
            suffix: suffix,
            delay: delay,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: color),
          ),
          Text(label, style: const TextStyle(color: AppColors.gray500)),
        ],
      ),
    );
  }
}

/// Étoiles qui apparaissent l'une après l'autre.
class _AnimatedStars extends StatelessWidget {
  const _AnimatedStars({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 400 + i * 250),
            curve: Curves.elasticOut,
            builder: (context, t, child) => Transform.scale(scale: i < stars ? t : 1, child: child),
            child: Icon(
              i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 44,
              color: i < stars ? const Color(0xFFF5B301) : AppColors.gray200,
            ),
          ),
      ],
    );
  }
}

/// Coffre de fin de niveau : les cauris gagnés.
class _Chest extends StatelessWidget {
  const _Chest({required this.cauris, required this.newStars, required this.delay});

  final int cauris;
  final bool newStars;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: const Color(0xFFFFF4DC),
      border: false,
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: -0.25, end: 0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (context, t, child) => Transform.rotate(angle: t, child: child),
            child: const Icon(Icons.redeem_rounded, size: 40, color: caurisColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('Coffre ouvert', color: caurisColor),
                Text(
                  newStars ? 'Une récompense pour tes nouvelles étoiles.' : 'Un petit bonus pour avoir rejoué.',
                  style: const TextStyle(color: AppColors.gray700, fontSize: 13),
                ),
              ],
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              const CauriIcon(size: 24),
              FlyingIcons(delay: delay, child: const CauriIcon(size: 18)),
            ],
          ),
          CountUp(
            value: cauris,
            prefix: ' +',
            delay: delay,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: caurisColor),
          ),
        ],
      ),
    );
  }
}
