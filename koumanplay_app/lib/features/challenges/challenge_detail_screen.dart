import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../models/player.dart';
import '../../services/providers.dart';
import '../../widgets/common.dart';

class ChallengeDetailScreen extends ConsumerStatefulWidget {
  const ChallengeDetailScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  ConsumerState<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends ConsumerState<ChallengeDetailScreen> {
  final _note = TextEditingController();
  bool _shareNote = false;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    setState(() => _saving = true);
    final outcome = await ref
        .read(playerProvider.notifier)
        .completeChallenge(widget.challengeId, note: _note.text.trim(), shareNote: _shareNote);
    if (!mounted) return;
    setState(() => _saving = false);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Défi réussi ! 🤝', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '+${outcome.xpGained} XP',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.green500),
            ),
            const SizedBox(height: 8),
            const Text('Merci d\'avoir fait vivre la transmission entre générations.', textAlign: TextAlign.center),
            for (final badge in outcome.newBadges) ...[
              const SizedBox(height: 12),
              Text('${badge.emoji}  Nouveau badge : ${badge.title}', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Super !'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentProvider);
    final player = ref.watch(playerProvider);
    final challenge = content.challenge(widget.challengeId);
    final theme = Theme.of(context);
    if (challenge == null || !GameRules.isChallengeUnlocked(player, challenge)) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Ce défi n\'est pas disponible.')));
    }
    final progress = player.challenges[challenge.id];
    final started = progress != null;
    final done = progress?.status == ChallengeStatus.done;
    final allSteps = started && progress.stepsDone.length == challenge.steps.length;
    final controller = ref.read(playerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/challenges'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.screen),
          children: [
            const Eyebrow('Défi intergénérationnel', color: AppColors.green500),
            const SizedBox(height: 6),
            Text(challenge.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(challenge.description, style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.gray700)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatPill(icon: Icons.star_rounded, label: '+${challenge.rewardXp} XP', color: AppColors.green500),
                StatPill(icon: Icons.schedule_rounded, label: '${challenge.durationMin} min', color: AppColors.gray700),
                StatPill(icon: Icons.signal_cellular_alt_rounded, label: challenge.difficulty, color: AppColors.gray700),
              ],
            ),
            const SizedBox(height: AppSpacing.section),
            Text('Étapes', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var i = 0; i < challenge.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  onTap: started && !done ? () => controller.toggleChallengeStep(challenge.id, i) : null,
                  child: Row(
                    children: [
                      Checkbox(
                        value: progress?.stepsDone.contains(i) ?? false,
                        onChanged: started && !done ? (_) => controller.toggleChallengeStep(challenge.id, i) : null,
                        activeColor: AppColors.green500,
                      ),
                      Expanded(child: Text(challenge.steps[i])),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (!started)
              FilledButton(onPressed: () => controller.startChallenge(challenge.id), child: const Text('Commencer le défi'))
            else if (done) ...[
              AppCard(
                color: AppColors.green100,
                border: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: AppColors.green500, size: 20),
                        SizedBox(width: 8),
                        Text('Défi terminé', style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    if (progress.note?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 8),
                      Text(challenge.notePrompt, style: const TextStyle(color: AppColors.gray500, fontSize: 13)),
                      Text(progress.note!, style: const TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              ),
            ] else ...[
              Text(challenge.notePrompt, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                minLines: 3,
                maxLines: 6,
                maxLength: 600,
                decoration: const InputDecoration(hintText: 'Écris ici ce que tu as appris…'),
                onChanged: (_) => setState(() {}),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.purple500,
                value: _shareNote,
                onChanged: (v) => setState(() => _shareNote = v ?? false),
                title: const Text(
                  'J\'accepte que l\'équipe KoumanPlay utilise ce texte pour enrichir l\'app, après validation par un référent culturel.',
                  style: TextStyle(fontSize: 13, color: AppColors.gray700),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: allSteps && _note.text.trim().length >= 5 && !_saving ? _complete : null,
                child: const Text('Valider le défi'),
              ),
              if (!allSteps)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Coche toutes les étapes pour valider.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.gray500, fontSize: 13),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
