import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../models/player.dart';
import '../../services/providers.dart';
import '../../widgets/common.dart';
import '../challenges/challenge_card.dart';
import '../elder/elder_home_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    // Les aînés ont leur propre accueil, tourné vers la transmission.
    if (player.isSenior) return const ElderHomeScreen();
    final content = ref.watch(contentProvider);
    final theme = Theme.of(context);
    final next = GameRules.nextLevel(content, player);
    final featured = GameRules.featuredChallenge(content, player);
    final level = GameRules.playerLevel(player.xp);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          Row(
            children: [
              const BrandLogo(size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Akwaba,', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.gray500)),
                    Text(player.firstName, style: theme.textTheme.titleLarge, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              StatPill(icon: Icons.local_fire_department_rounded, label: '${player.streak}', color: AppColors.warning),
            ],
          ),
          const SizedBox(height: AppSpacing.section),
          _LevelCard(level: level, xp: player.xp),
          const SizedBox(height: AppSpacing.section),
          Text('Continuer ma progression', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          if (next != null)
            AppCard(
              onTap: () => context.go('/play'),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Color(content.language(next.languageId)?.color ?? 0xFF5B2EFF),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Text(
                      '${next.order}',
                      style: const TextStyle(color: AppColors.white, fontSize: 26, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow('${content.language(next.languageId)?.name ?? ''} · Niveau ${next.order} · ${next.kindLabel}'),
                        const SizedBox(height: 2),
                        Text(next.title, style: theme.textTheme.titleMedium),
                        Text(
                          '${content.itemsOf(next.id).length} à apprendre',
                          style: const TextStyle(color: AppColors.gray500),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.play_circle_fill_rounded, size: 40, color: AppColors.purple500),
                ],
              ),
            )
          else
            AppCard(
              color: AppColors.green100,
              border: false,
              child: Row(
                children: [
                  const Text('🌳', style: TextStyle(fontSize: 30)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tu as terminé tous les niveaux disponibles. De nouveaux contenus arrivent bientôt !',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.section),
          Text('Défi à la une', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          if (featured != null)
            ChallengeCard(
              challenge: featured,
              unlocked: GameRules.isChallengeUnlocked(player, featured),
              status: player.challenges[featured.id]?.status,
              lockedHint: lockedHintFor(content, featured),
            ),
          if (player.challenges.values.any((c) => c.status == ChallengeStatus.done)) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton(onPressed: () => context.go('/challenges'), child: const Text('Voir tous mes défis')),
            ),
          ],
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.level, required this.xp});

  final int level;
  final int xp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.purple500, AppColors.purple600]),
        borderRadius: BorderRadius.circular(AppRadius.largeCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Niveau ${level.toString().padLeft(2, '0')}',
                style: const TextStyle(color: AppColors.white, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              StatPill(
                icon: Icons.star_rounded,
                label: '$xp XP',
                color: AppColors.white,
                background: AppColors.white.withValues(alpha: 0.18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          KpProgressBar(value: GameRules.levelProgress(xp), color: AppColors.green500),
          const SizedBox(height: 8),
          Text(
            '${GameRules.xpIntoLevel(xp)} / ${GameRules.xpPerPlayerLevel} XP avant le niveau ${level + 1}',
            style: TextStyle(color: AppColors.white.withValues(alpha: 0.85), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
