import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../services/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/cauris.dart';
import '../../widgets/energy.dart';

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
    final (emoji, title) = !outcome.passed
        ? ('🌱', 'Presque !')
        : ratio == 1
        ? ('🏆', 'Sans-faute !')
        : ('🌿', 'Niveau validé !');

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
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
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.4, end: 1),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (context, s, child) => Transform.scale(scale: s, child: child),
                      child: Text(emoji, style: const TextStyle(fontSize: 84)),
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
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(label: 'Score', value: '${outcome.correct}/${outcome.total}'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Stat(label: 'XP gagnés', value: '+${outcome.xpGained}', color: AppColors.green500),
                      ),
                    ],
                  ),
                  if (outcome.chestCauris > 0) ...[
                    const SizedBox(height: 12),
                    _Chest(cauris: outcome.chestCauris, newStars: outcome.stars > outcome.previousStars),
                  ],
                  for (final quest in outcome.completedQuests) ...[
                    const SizedBox(height: 12),
                    AppCard(
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
                    AppCard(
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
                                Text(badge.description, style: const TextStyle(color: AppColors.gray500, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
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
                  OutlinedButton(onPressed: () => context.go('/play'), child: const Text('Retour à la carte')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color = AppColors.black});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Text(
            value,
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
  const _Chest({required this.cauris, required this.newStars});

  final int cauris;
  final bool newStars;

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
          const CauriIcon(size: 24),
          Text(
            ' +$cauris',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: caurisColor),
          ),
        ],
      ),
    );
  }
}
