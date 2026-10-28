import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/player.dart';
import '../../services/providers.dart';
import '../social/duels_screen.dart';
import '../social/league_screen.dart';
import 'challenge_card.dart';
import 'daily_board.dart';

/// Onglet Défis : quêtes du jour, défis avec les aînés, duels et ligue,
/// chacun dans son propre onglet.
class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const tabs = [
      (Icons.task_alt_rounded, 'Quêtes'),
      (Icons.diversity_3_rounded, 'Défis'),
      (Icons.sports_kabaddi_rounded, 'Duels'),
      (Icons.shield_rounded, 'Ligue'),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.screen, AppSpacing.screen, 4),
              child: Text('Défis', style: Theme.of(context).textTheme.headlineSmall),
            ),
            TabBar(
              labelColor: AppColors.purple500,
              unselectedLabelColor: AppColors.gray500,
              indicatorColor: AppColors.purple500,
              labelPadding: EdgeInsets.zero,
              tabs: [
                for (final (icon, label) in tabs)
                  Tab(
                    height: 56,
                    icon: Icon(icon, size: 22),
                    // Libellés réduits plutôt que coupés sur les petits écrans.
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, softWrap: false)),
                  ),
              ],
            ),
            const Expanded(
              child: TabBarView(children: [_QuestsTab(), _ElderChallengesTab(), DuelLobby(), LeagueView()]),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestsTab extends StatelessWidget {
  const _QuestsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: const [
        DailyBoard(),
        SizedBox(height: 12),
        Text(
          'Les quêtes changent chaque jour à minuit. Chaque quête terminée te donne ses cauris tout de suite.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.gray500, fontSize: 12),
        ),
      ],
    );
  }
}

enum _Filter { todo, inProgress, done }

/// Défis intergénérationnels, filtrés par état.
class _ElderChallengesTab extends ConsumerStatefulWidget {
  const _ElderChallengesTab();

  @override
  ConsumerState<_ElderChallengesTab> createState() => _ElderChallengesTabState();
}

class _ElderChallengesTabState extends ConsumerState<_ElderChallengesTab> {
  _Filter _filter = _Filter.todo;

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final content = ref.watch(contentProvider);
    final mine = GameRules.challengesFor(content, player);
    ChallengeStatus? statusOf(Challenge c) => player.challenges[c.id]?.status;
    final byFilter = {
      _Filter.todo: mine.where((c) => statusOf(c) == null).toList(),
      _Filter.inProgress: mine.where((c) => statusOf(c) == ChallengeStatus.inProgress).toList(),
      _Filter.done: mine.where((c) => statusOf(c) == ChallengeStatus.done).toList(),
    };
    final items = byFilter[_filter]!;
    final empty = switch (_filter) {
      _Filter.todo => 'Tous les défis sont lancés. Bravo !',
      _Filter.inProgress => 'Aucun défi en cours.\nLance-toi depuis « À faire ».',
      _Filter.done => 'Tes défis terminés apparaîtront ici.',
    };

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        Text(
          player.isSenior
              ? 'Transmets tes savoirs à un jeune de ton entourage.'
              : 'Apprends auprès d\'un aîné de ton entourage.',
          style: const TextStyle(color: AppColors.gray500),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (final (filter, label) in [
              (_Filter.todo, 'À faire'),
              (_Filter.inProgress, 'En cours'),
              (_Filter.done, 'Terminés'),
            ])
              ChoiceChip(
                label: Text('$label (${byFilter[filter]!.length})'),
                selected: _filter == filter,
                onSelected: (_) => setState(() => _filter = filter),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              empty,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.gray500),
            ),
          )
        else
          for (final c in items) ...[
            ChallengeCard(
              challenge: c,
              unlocked: GameRules.isChallengeUnlocked(player, c),
              status: statusOf(c),
              lockedHint: lockedHintFor(content, c),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}
