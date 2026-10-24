import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../models/player.dart';
import '../../services/providers.dart';
import '../../widgets/common.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final content = ref.watch(contentProvider);
    final backend = ref.watch(backendProvider);
    final theme = Theme.of(context);
    final doneChallenges = player.challenges.values.where((c) => c.status == ChallengeStatus.done).length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.purple100,
                child: Text(
                  player.firstName.isEmpty ? '?' : player.firstName[0].toUpperCase(),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.purple500),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(player.firstName, style: theme.textTheme.titleLarge),
                    Text(
                      player.isSenior ? 'Aîné' : 'Jeune',
                      style: const TextStyle(color: AppColors.gray500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.section),
          Row(
            children: [
              Expanded(child: _Metric(value: '${GameRules.playerLevel(player.xp)}', label: 'Niveau')),
              const SizedBox(width: 10),
              Expanded(child: _Metric(value: '${player.xp}', label: 'XP', color: AppColors.green500)),
              const SizedBox(width: 10),
              Expanded(child: _Metric(value: '${player.streak}', label: 'Série', color: AppColors.warning)),
              const SizedBox(width: 10),
              Expanded(child: _Metric(value: '$doneChallenges', label: 'Défis')),
            ],
          ),
          const SizedBox(height: AppSpacing.section),
          Text('Badges', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.95,
            children: [
              for (final badge in GameRules.badges)
                GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text('${badge.title} : ${badge.description}'))),
                  child: BadgeTile(badge: badge, unlocked: player.badges.contains(badge.id)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.section),
          Text('Mes langues', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final language in content.languages) ...[
            _DomainProgress(
              name: language.name,
              color: Color(language.color),
              value: GameRules.languageMastery(content, player, language),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: AppSpacing.section),
          if (backend.enabled)
            AppCard(
              onTap: () => context.push('/account'),
              child: Row(
                children: [
                  Icon(
                    backend.isAnonymous ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                    color: backend.isAnonymous ? AppColors.warning : AppColors.green500,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          backend.isAnonymous ? 'Sauvegarde ta progression' : 'Compte connecté',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          backend.isAnonymous ? 'Crée un compte pour ne rien perdre.' : backend.email ?? '',
                          style: const TextStyle(color: AppColors.gray500, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Recommencer à zéro ?'),
                    content: const Text('Toute ta progression sur ce téléphone sera effacée.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Effacer')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(playerProvider.notifier).reset();
                  if (context.mounted) context.go('/');
                }
              },
              child: const Text('Recommencer à zéro', style: TextStyle(color: AppColors.gray500)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, this.color = AppColors.purple500});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: const TextStyle(color: AppColors.gray500, fontSize: 12)),
        ],
      ),
    );
  }
}

class _DomainProgress extends StatelessWidget {
  const _DomainProgress({required this.name, required this.value, required this.color});

  final String name;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500))),
            Text('${(value * 100).round()} %', style: const TextStyle(color: AppColors.gray500)),
          ],
        ),
        const SizedBox(height: 6),
        KpProgressBar(value: value, color: color),
      ],
    );
  }
}
