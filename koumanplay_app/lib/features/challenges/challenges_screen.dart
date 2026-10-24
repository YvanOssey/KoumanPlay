import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/player.dart';
import '../../services/providers.dart';
import 'challenge_card.dart';

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final content = ref.watch(contentProvider);
    final mine = GameRules.challengesFor(content, player);
    ChallengeStatus? statusOf(Challenge c) => player.challenges[c.id]?.status;
    final todo = mine.where((c) => statusOf(c) == null).toList();
    final inProgress = mine.where((c) => statusOf(c) == ChallengeStatus.inProgress).toList();
    final done = mine.where((c) => statusOf(c) == ChallengeStatus.done).toList();

    Widget list(List<Challenge> items, String empty) {
      if (items.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(empty, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.gray500)),
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screen),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final c = items[i];
          return ChallengeCard(
            challenge: c,
            unlocked: GameRules.isChallengeUnlocked(player, c),
            status: statusOf(c),
            lockedHint: lockedHintFor(content, c),
          );
        },
      );
    }

    return DefaultTabController(
      length: 3,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.screen, AppSpacing.screen, 4),
              child: Text('Défis', style: Theme.of(context).textTheme.headlineSmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
              child: Text(
                player.isSenior
                    ? 'Transmets tes savoirs à un jeune de ton entourage.'
                    : 'Apprends auprès d\'un aîné de ton entourage.',
                style: const TextStyle(color: AppColors.gray500),
              ),
            ),
            TabBar(
              labelColor: AppColors.purple500,
              unselectedLabelColor: AppColors.gray500,
              indicatorColor: AppColors.purple500,
              tabs: [
                Tab(text: 'À faire (${todo.length})'),
                Tab(text: 'En cours (${inProgress.length})'),
                Tab(text: 'Terminés (${done.length})'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  list(todo, 'Tous les défis sont lancés. Bravo !'),
                  list(inProgress, 'Aucun défi en cours.\nLance-toi depuis l\'onglet « À faire ».'),
                  list(done, 'Tes défis terminés apparaîtront ici.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
