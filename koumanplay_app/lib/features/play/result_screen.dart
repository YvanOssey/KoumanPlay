import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../services/providers.dart';
import '../../widgets/common.dart';

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
                    child: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => context.go('/home')),
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
                  Center(child: Eyebrow('${content.language(level?.languageId ?? '')?.name ?? ''} · Niveau ${level?.order ?? ''}')),
                  const SizedBox(height: 6),
                  Center(child: Text(title, style: theme.textTheme.headlineMedium)),
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
                      Expanded(child: _Stat(label: 'Score', value: '${outcome.correct}/${outcome.total}')),
                      const SizedBox(width: 12),
                      Expanded(child: _Stat(label: 'XP gagnés', value: '+${outcome.xpGained}', color: AppColors.green500)),
                    ],
                  ),
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
                      onPressed: () => context.pushReplacement('/quiz/${outcome.levelId}'),
                      child: const Text('Réessayer'),
                    )
                  else if (next != null)
                    FilledButton(
                      onPressed: () => context.pushReplacement('/quiz/${next.id}'),
                      child: const Text('Niveau suivant'),
                    ),
                  const SizedBox(height: 10),
                  OutlinedButton(onPressed: () => context.go('/home'), child: const Text('Retour à l\'accueil')),
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
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: const TextStyle(color: AppColors.gray500)),
        ],
      ),
    );
  }
}
