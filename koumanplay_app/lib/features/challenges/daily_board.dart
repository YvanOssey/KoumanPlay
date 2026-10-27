import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../services/providers.dart';
import '../../widgets/cauris.dart';
import '../../widgets/common.dart';

/// Quêtes du jour (3, renouvelées chaque jour) et accès à l'entraînement.
class DailyBoard extends ConsumerWidget {
  const DailyBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final today = GameRules.dayKey(DateTime.now());
    final progress = player.quests?.day == today ? player.quests! : null;
    final quests = GameRules.questsOfDay(today);
    final toReview = player.toReview.length;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Eyebrow('Quêtes du jour')),
              CauriPill(cauris: player.cauris),
            ],
          ),
          const SizedBox(height: 8),
          for (final quest in quests) ...[
            _QuestRow(
              title: quest.title,
              done: progress?.claimed.contains(quest.id) ?? false,
              value: (progress?.progress[quest.id] ?? 0).clamp(0, quest.target),
              target: quest.target,
              reward: quest.reward,
            ),
            const SizedBox(height: 8),
          ],
          const Divider(height: 16),
          Row(
            children: [
              const Icon(Icons.autorenew_rounded, color: AppColors.purple500, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  toReview > 0
                      ? 'Entraînement : $toReview question${toReview > 1 ? 's' : ''} à revoir'
                      : 'Entraînement',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(onPressed: () => context.push('/entrainement'), child: const Text('S\'entraîner')),
            ],
          ),
          const Text(
            'Sans perte d\'énergie : il en rend une, avec 3 cauris.',
            style: TextStyle(color: AppColors.gray500, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({
    required this.title,
    required this.done,
    required this.value,
    required this.target,
    required this.reward,
  });

  final String title;
  final bool done;
  final int value;
  final int target;
  final int reward;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 20,
          color: done ? AppColors.green500 : AppColors.gray400,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: done ? AppColors.gray500 : AppColors.black,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
              if (!done && target > 1) ...[
                const SizedBox(height: 4),
                KpProgressBar(value: value / target, color: caurisColor),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(done ? 'Gagné' : '$value/$target', style: const TextStyle(color: AppColors.gray500, fontSize: 12)),
        const SizedBox(width: 6),
        const CauriIcon(size: 16),
        Text(
          ' $reward',
          style: const TextStyle(fontWeight: FontWeight.w700, color: caurisColor, fontSize: 13),
        ),
      ],
    );
  }
}
