import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/contribution.dart';
import '../../services/contributions.dart';
import '../../services/providers.dart';
import '../../widgets/common.dart';

/// Ouvre un écran de transmission, en passant d'abord par l'accord si
/// l'aîné ne l'a pas encore donné.
void openTransmission(BuildContext context, WidgetRef ref, String route) {
  if (ref.read(playerProvider).consentAt == null) {
    context.push('/transmettre/accord?next=${Uri.encodeComponent(route)}');
  } else {
    context.push(route);
  }
}

/// Accueil du profil Aîné : transmettre d'abord, jouer ensuite.
class ElderHomeScreen extends ConsumerWidget {
  const ElderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final content = ref.watch(contentProvider);
    final contributions = ref.watch(contributionsProvider);
    final language = content.language(player.spokenLanguageId ?? '');
    final theme = Theme.of(context);
    final published = contributions.where((c) => c.status == ContributionStatus.publie).length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          Row(
            children: [
              const BrandLogo(size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Akwaba,', style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.gray500)),
                    Text(player.firstName, style: theme.textTheme.headlineSmall, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.section),
          if (language == null)
            _LanguagePicker(languages: content.languages)
          else ...[
            _ImpactCard(total: player.transmittedTotal, published: published, xp: player.xp, language: language),
            const SizedBox(height: AppSpacing.section),
            Text('Que veux-tu transmettre ?', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _BigAction(
              icon: Icons.record_voice_over_rounded,
              color: Color(language.color),
              title: 'Des mots',
              subtitle: 'Dis des mots du quotidien en ${language.name}',
              onTap: () => openTransmission(context, ref, '/transmettre/mots'),
            ),
            const SizedBox(height: 12),
            _BigAction(
              icon: Icons.format_quote_rounded,
              color: AppColors.purple500,
              title: 'Un proverbe',
              subtitle: 'Partage un proverbe et ce qu\'il veut dire',
              onTap: () => openTransmission(context, ref, '/transmettre/proverbe'),
            ),
            const SizedBox(height: 12),
            _BigAction(
              icon: Icons.auto_stories_rounded,
              color: AppColors.warning,
              title: 'Un conte',
              subtitle: 'Raconte une histoire de ton enfance',
              onTap: () => openTransmission(context, ref, '/transmettre/conte'),
            ),
            const SizedBox(height: 12),
            _BigAction(
              icon: Icons.sports_esports_rounded,
              color: AppColors.green500,
              title: 'Jouer',
              subtitle: 'Découvre les langues sur la carte',
              onTap: () => context.push('/carte'),
            ),
            if (contributions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.section),
              Center(
                child: TextButton.icon(
                  onPressed: () => context.push('/transmettre/envois'),
                  icon: const Icon(Icons.inbox_rounded),
                  label: Text('Mes transmissions (${contributions.length})', style: const TextStyle(fontSize: 17)),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ImpactCard extends StatelessWidget {
  const _ImpactCard({required this.total, required this.published, required this.xp, required this.language});

  final int total;
  final int published;
  final int xp;
  final Language language;

  @override
  Widget build(BuildContext context) {
    final color = Color(language.color);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.3)!]),
        borderRadius: BorderRadius.circular(AppRadius.largeCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu transmets le ${language.name}',
            style: const TextStyle(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            total == 0 ? 'Ton premier savoir t\'attend' : '$total savoir${total > 1 ? 's' : ''} transmis',
            style: const TextStyle(color: AppColors.white, fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatPill(
                icon: Icons.verified_rounded,
                label: '$published publié${published > 1 ? 's' : ''} dans le jeu',
                color: AppColors.white,
                background: AppColors.white.withValues(alpha: 0.18),
              ),
              StatPill(
                icon: Icons.star_rounded,
                label: '$xp XP · niveau ${GameRules.playerLevel(xp)}',
                color: AppColors.white,
                background: AppColors.white.withValues(alpha: 0.18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 34),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                Text(subtitle, style: const TextStyle(fontSize: 15, color: AppColors.gray500)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 32, color: AppColors.gray400),
        ],
      ),
    );
  }
}

/// Profils aînés créés avant cette version : on demande la langue une fois.
class _LanguagePicker extends ConsumerWidget {
  const _LanguagePicker({required this.languages});

  final List<Language> languages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quelle langue parles-tu ?', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text('C\'est la langue que tu vas transmettre aux jeunes.', style: TextStyle(fontSize: 16, color: AppColors.gray500)),
        const SizedBox(height: 16),
        for (final l in languages) ...[
          AppCard(
            onTap: () => ref.read(playerProvider.notifier).setSpokenLanguage(l.id),
            child: Row(
              children: [
                CircleAvatar(radius: 10, backgroundColor: Color(l.color)),
                const SizedBox(width: 14),
                Text(l.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
