import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/language_option.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _name = TextEditingController();
  final _village = TextEditingController();
  String? _role;

  /// Aîné : la langue qu'il parle et va transmettre.
  String? _spoken;

  /// Jeune : la langue qu'il veut apprendre.
  String? _learning;

  @override
  void dispose() {
    _name.dispose();
    _village.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _role != null &&
      (_role == 'senior' ? _spoken != null : _learning != null);

  Future<void> _submit() async {
    final senior = _role == 'senior';
    await ref.read(playerProvider.notifier).completeOnboarding(
          firstName: _name.text,
          role: _role!,
          spokenLanguageId: senior ? _spoken : null,
          learningLanguageId: senior ? null : _learning,
          village: senior ? _village.text : null,
        );
    if (mounted) context.go('/play');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = ref.watch(contentProvider);
    final languages = content.languages;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/onboarding')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text('Faisons connaissance', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Ça prend 30 secondes.', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.gray500)),
            const SizedBox(height: AppSpacing.section),
            Text('Ton prénom', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Ex. Aya'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.section),
            Text('Tu es…', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _RoleCard(
              emoji: '🧑🏾',
              title: 'Jeune',
              subtitle: 'Je veux apprendre et partager',
              selected: _role == 'jeune',
              onTap: () => setState(() => _role = 'jeune'),
            ),
            const SizedBox(height: 12),
            _RoleCard(
              emoji: '👴🏾',
              title: 'Aîné',
              subtitle: 'Je veux transmettre et découvrir',
              selected: _role == 'senior',
              onTap: () => setState(() => _role = 'senior'),
            ),
            if (_role == 'senior') ...[
              const SizedBox(height: AppSpacing.section),
              Text('Quelle langue parles-tu ?', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text("C'est la langue que tu vas transmettre aux jeunes.", style: TextStyle(color: AppColors.gray500)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final l in languages)
                    ChoiceChip(
                      label: Text(l.name, style: const TextStyle(fontSize: 16)),
                      selected: _spoken == l.id,
                      selectedColor: Color(l.color).withValues(alpha: 0.2),
                      onSelected: (_) => setState(() => _spoken = l.id),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.section),
              Text('Ton village ou ta ville (facultatif)', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _village,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Ex. Sakassou'),
              ),
            ] else if (_role == 'jeune') ...[
              const SizedBox(height: AppSpacing.section),
              Text('Quelle langue veux-tu apprendre ?', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text('Ta carte suivra cette langue. Tu pourras en changer dans ton profil.',
                  style: TextStyle(color: AppColors.gray500)),
              const SizedBox(height: 10),
              for (final l in languages) ...[
                LanguageOption(
                  language: l,
                  ready: content.playableLevelsOf(l.id).isNotEmpty,
                  selected: _learning == l.id,
                  onTap: () => setState(() => _learning = l.id),
                ),
                const SizedBox(height: 8),
              ],
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _valid ? _submit : null,
              child: Text(_role == 'senior' ? 'Commencer à transmettre' : 'Commencer à jouer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.emoji, required this.title, required this.subtitle, required this.selected, required this.onTap});

  final String emoji;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: selected ? AppColors.purple500 : Colors.transparent, width: 2),
      ),
      child: AppCard(
        onTap: onTap,
        color: selected ? AppColors.purple100 : AppColors.white,
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 34)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(subtitle, style: const TextStyle(color: AppColors.gray500)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? AppColors.purple500 : AppColors.gray400,
            ),
          ],
        ),
      ),
    );
  }
}
