import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../services/providers.dart';
import '../../widgets/avatar_view.dart';
import '../../widgets/common.dart';
import '../../widgets/cauris.dart';
import '../play/map_screen.dart';
import '../../services/reminders.dart';
import '../../widgets/fx.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final content = ref.watch(contentProvider);
    final backend = ref.watch(backendProvider);
    final theme = Theme.of(context);
    final learning = GameRules.learningLanguage(content, player);
    final level = GameRules.playerLevel(player.xp);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          Row(
            children: [
              // Toucher l'avatar ouvre l'éditeur ; le crayon le rend visible.
              Semantics(
                button: true,
                label: 'Modifier mon avatar',
                child: GestureDetector(
                  onTap: () => context.push('/avatar'),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AvatarView(config: player.avatarOrDefault, size: 76),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.purple500,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.white, width: 2),
                          ),
                          child: const Icon(Icons.edit_rounded, size: 14, color: AppColors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(player.firstName, style: theme.textTheme.titleLarge),
                    Text(player.isSenior ? 'Aîné' : 'Jeune', style: const TextStyle(color: AppColors.gray500)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => context.push('/avatar'),
                      child: const Text(
                        'Personnaliser mon avatar',
                        style: TextStyle(color: AppColors.purple500, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.section),
          Row(
            children: [
              Expanded(
                child: _Metric(value: '$level', label: 'Niveau'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(value: '${player.xp}', label: 'XP', color: AppColors.green500),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(value: '${player.cauris}', label: 'Cauris', color: caurisColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(value: '${player.streak}', label: 'Série', color: AppColors.warning),
              ),
            ],
          ),
          const SizedBox(height: 12),
          KpProgressBar(value: GameRules.levelProgress(player.xp), color: AppColors.green500),
          const SizedBox(height: 6),
          Text(
            '${GameRules.xpIntoLevel(player.xp)} / ${GameRules.xpPerPlayerLevel} XP avant le niveau ${level + 1}',
            style: const TextStyle(color: AppColors.gray500, fontSize: 13),
          ),
          if (learning != null) ...[
            const SizedBox(height: AppSpacing.section),
            AppCard(
              onTap: () async {
                final chosen = await showModalBottomSheet<String>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const LanguagePickerSheet(),
                );
                if (chosen != null) await ref.read(playerProvider.notifier).setLearningLanguage(chosen);
              },
              child: Row(
                children: [
                  Icon(Icons.translate_rounded, color: Color(learning.color)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('J\'apprends', style: TextStyle(color: AppColors.gray500, fontSize: 13)),
                        Text(learning.name, style: theme.textTheme.titleMedium?.copyWith(color: Color(learning.color))),
                      ],
                    ),
                  ),
                  const Text(
                    'Changer',
                    style: TextStyle(color: AppColors.purple500, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          AppCard(
            onTap: () => context.push('/boutique'),
            child: Row(
              children: [
                const CauriIcon(size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Boutique', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        GameRules.isPremium(player, DateTime.now())
                            ? "KoumanPlay+ actif · objets d'avatar, cauris"
                            : "Objets d'avatar, cauris et KoumanPlay+",
                        style: const TextStyle(color: AppColors.gray500, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
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
          const _Settings(),
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
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color),
          ),
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
            Expanded(
              child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            Text('${(value * 100).round()} %', style: const TextStyle(color: AppColors.gray500)),
          ],
        ),
        const SizedBox(height: 6),
        KpProgressBar(value: value, color: color),
      ],
    );
  }
}

/// Réglages : sons du jeu et notifications de relance.
class _Settings extends ConsumerStatefulWidget {
  const _Settings();

  @override
  ConsumerState<_Settings> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<_Settings> {
  @override
  Widget build(BuildContext context) {
    final sound = ref.watch(soundProvider);
    final reminders = ref.watch(remindersProvider);
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_rounded, color: AppColors.purple500),
            title: const Text('Sons du jeu'),
            value: sound.enabled,
            onChanged: (on) async {
              await sound.setEnabled(on);
              setState(() {});
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_rounded, color: AppColors.purple500),
            title: const Text('Rappels de jeu'),
            subtitle: const Text('Énergie pleine, Flamme du savoir : une fois par jour au plus.'),
            value: reminders.enabled,
            onChanged: (on) async {
              await reminders.setEnabled(on);
              if (on) await reminders.reschedule(ref.read(playerProvider));
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}
