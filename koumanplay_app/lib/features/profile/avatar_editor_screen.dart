import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/avatar.dart';
import '../../services/providers.dart';
import '../../widgets/avatar_view.dart';

/// Éditeur d'avatar : aperçu en grand, puis une rangée de choix par pièce.
/// Chaque choix est montré appliqué à l'avatar du joueur.
class AvatarEditorScreen extends ConsumerStatefulWidget {
  const AvatarEditorScreen({super.key});

  @override
  ConsumerState<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends ConsumerState<AvatarEditorScreen> {
  late AvatarConfig _avatar = ref.read(playerProvider).avatarOrDefault;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(playerProvider.notifier).setAvatar(_avatar);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );

    Widget choices(Map<String, String> catalog, String selected, AvatarConfig Function(String id) apply) => SizedBox(
      height: 108,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final e in catalog.entries)
            _Choice(
              label: e.value,
              selected: e.key == selected,
              preview: apply(e.key),
              onTap: () => setState(() => _avatar = apply(e.key)),
            ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Mon avatar')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screen),
                children: [
                  Center(child: AvatarView(config: _avatar, size: 180)),
                  section(
                    'Teint',
                    Wrap(
                      spacing: 12,
                      children: [
                        for (final e in AvatarConfig.skins.entries)
                          _SkinDot(
                            id: e.key,
                            label: e.value,
                            selected: e.key == _avatar.skin,
                            onTap: () => setState(() => _avatar = _avatar.copyWith(skin: e.key)),
                          ),
                      ],
                    ),
                  ),
                  section('Coiffure', choices(AvatarConfig.hairs, _avatar.hair, (id) => _avatar.copyWith(hair: id))),
                  section('Tenue', choices(AvatarConfig.outfits, _avatar.outfit, (id) => _avatar.copyWith(outfit: id))),
                  section(
                    'Décor',
                    choices(AvatarConfig.backgrounds, _avatar.background, (id) => _avatar.copyWith(background: id)),
                  ),
                  section(
                    'Accessoires',
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final e in AvatarConfig.accessoryNames.entries)
                          FilterChip(
                            label: Text(e.value),
                            selected: _avatar.accessories.contains(e.key),
                            onSelected: (on) => setState(
                              () => _avatar = _avatar.copyWith(
                                accessories: on
                                    ? {..._avatar.accessories, e.key}
                                    : (_avatar.accessories.toSet()..remove(e.key)),
                              ),
                            ),
                          ),
                        FilterChip(
                          label: const Text('Cils'),
                          selected: _avatar.lashes,
                          onSelected: (on) => setState(() => _avatar = _avatar.copyWith(lashes: on)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: FilledButton(onPressed: _saving ? null : _save, child: const Text('Enregistrer mon avatar')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.preview, required this.onTap});

  final String label;
  final bool selected;
  final AvatarConfig preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 80,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? AppColors.purple500 : Colors.transparent, width: 3),
                ),
                child: AvatarView(config: preview, size: 64),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.purple500 : AppColors.gray700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkinDot extends StatelessWidget {
  const _SkinDot({required this.id, required this.label, required this.selected, required this.onTap});

  static const _colors = {
    'ebene': Color(0xFF4A2C1D),
    'cacao': Color(0xFF6B3E26),
    'caramel': Color(0xFF8D5524),
    'miel': Color(0xFFA86B3C),
    'sable': Color(0xFFC68642),
  };

  final String id;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        label: 'Teint $label',
        selected: selected,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _colors[id],
              shape: BoxShape.circle,
              border: Border.all(color: selected ? AppColors.purple500 : AppColors.white, width: 4),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: selected ? const Icon(Icons.check_rounded, color: AppColors.white) : null,
          ),
        ),
      ),
    );
  }
}
