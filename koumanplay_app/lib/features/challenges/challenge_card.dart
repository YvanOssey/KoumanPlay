import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/player.dart';
import '../../widgets/common.dart';

/// Explique quel niveau valider pour débloquer [challenge].
String? lockedHintFor(ContentPack content, Challenge challenge) {
  final level = content.level(challenge.unlockAfterLevel ?? '');
  if (level == null) return null;
  final language = content.language(level.languageId)?.name ?? '';
  return 'Valide le niveau ${level.order} en $language (${level.title}) pour débloquer ce défi.';
}

class ChallengeCard extends StatelessWidget {
  const ChallengeCard({super.key, required this.challenge, required this.unlocked, this.status, this.lockedHint});

  final Challenge challenge;
  final bool unlocked;
  final ChallengeStatus? status;
  final String? lockedHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = status == ChallengeStatus.done;
    final action = switch (status) {
      ChallengeStatus.done => 'Revoir',
      ChallengeStatus.inProgress => 'Continuer',
      null => 'Commencer',
    };
    return AppCard(
      color: unlocked ? AppColors.white : AppColors.gray100,
      onTap: unlocked ? () => context.push('/challenge/${challenge.id}') : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Eyebrow('Défi intergénérationnel', color: AppColors.green500)),
              if (!unlocked) const Icon(Icons.lock_rounded, size: 18, color: AppColors.gray400),
              if (done) const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.green500),
            ],
          ),
          const SizedBox(height: 6),
          Text(challenge.title, style: theme.textTheme.titleMedium?.copyWith(color: unlocked ? null : AppColors.gray500)),
          const SizedBox(height: 4),
          Text(challenge.description, style: const TextStyle(color: AppColors.gray500)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatPill(icon: Icons.star_rounded, label: '+${challenge.rewardXp} XP', color: AppColors.green500),
              StatPill(icon: Icons.schedule_rounded, label: '${challenge.durationMin} min', color: AppColors.gray700),
              StatPill(icon: Icons.signal_cellular_alt_rounded, label: challenge.difficulty, color: AppColors.gray700),
            ],
          ),
          const SizedBox(height: 12),
          if (unlocked)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$action →',
                style: const TextStyle(color: AppColors.purple500, fontWeight: FontWeight.w600),
              ),
            )
          else if (lockedHint != null)
            Text(lockedHint!, style: const TextStyle(color: AppColors.gray500, fontSize: 13)),
        ],
      ),
    );
  }
}
