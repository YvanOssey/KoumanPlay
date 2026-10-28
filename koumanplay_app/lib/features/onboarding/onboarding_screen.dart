import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';
import '../../widgets/cauris.dart';
import '../../widgets/fx.dart';
import '../../widgets/guide.dart';

/// Une réplique du guide, avec une petite illustration en dessous.
class _Line {
  const _Line(this.text, [this.extra]);

  final String text;
  final _Extra? extra;
}

enum _Extra { languages, rewards, social }

const _lines = [
  _Line('Akwaba, mon enfant ! Je suis Grand-père Kouman. Bienvenue sur KoumanPlay.'),
  _Line(
    'Ici, tu apprends nos langues en jouant : des premiers mots jusqu\'aux proverbes de nos anciens.',
    _Extra.languages,
  ),
  _Line(
    'Chaque bonne réponse te rapporte de l\'XP et des cauris. Mais attention : chaque erreur te coûte une énergie !',
    _Extra.rewards,
  ),
  _Line(
    'Relève des défis avec les aînés de ta famille, affronte d\'autres joueurs en duel et grimpe dans les ligues.',
    _Extra.social,
  ),
  _Line('Tout ce que je vais t\'apprendre vient de nos aînés. Prêt à recevoir leurs savoirs ?'),
];

/// Accueil : Grand-père Kouman salue le joueur et lui explique le jeu, une
/// réplique à la fois. Toucher l'écran termine la phrase, puis passe à la
/// suivante.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _index = 0;
  int _shown = 0;
  int _wave = 0;
  Timer? _typing;

  _Line get _line => _lines[_index];
  bool get _typed => _shown >= _line.text.length;
  bool get _last => _index == _lines.length - 1;

  @override
  void initState() {
    super.initState();
    // Laisse le temps au guide d'apparaître avant de parler.
    Timer(const Duration(milliseconds: 700), () {
      if (mounted) _say();
    });
  }

  @override
  void dispose() {
    _typing?.cancel();
    super.dispose();
  }

  /// Écrit la réplique lettre par lettre, comme s'il la disait.
  void _say() {
    _typing?.cancel();
    setState(() => _shown = 0);
    ref.read(soundProvider).play('flip');
    _typing = Timer.periodic(const Duration(milliseconds: 28), (timer) {
      if (!mounted) return;
      setState(() => _shown = (_shown + 1).clamp(0, _line.text.length));
      if (_typed) timer.cancel();
    });
  }

  void _advance() {
    if (!_typed) {
      _typing?.cancel();
      setState(() => _shown = _line.text.length);
      return;
    }
    if (_last) {
      context.go('/setup');
      return;
    }
    setState(() {
      _index++;
      if (_index == _lines.length - 1 || _index == 3) _wave++;
    });
    _say();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _advance,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF4DC), AppColors.cream, Color(0xFFF1DDB0)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: AppSpacing.screen),
                    for (var i = 0; i < _lines.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _index ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i <= _index ? AppColors.purple500 : AppColors.gray200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    const Spacer(),
                    TextButton(onPressed: () => context.go('/setup'), child: const Text('Passer')),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                  child: _Bubble(text: _line.text.substring(0, _shown), full: _line.text),
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _typed && _line.extra != null
                      ? _ExtraRow(key: ValueKey(_index), extra: _line.extra!)
                      : const SizedBox(height: 44),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ElderGuide(
                          size: constraints.maxHeight.clamp(160, 300) - 12,
                          talking: !_typed,
                          wave: _wave,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.screen),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _advance,
                      child: Text(_last && _typed ? 'C\'est parti !' : 'Suivant'),
                    ),
                  ),
                ),
                Text(
                  'Touche l\'écran pour avancer',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.gray500),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bulle de parole. La taille est calculée sur la phrase entière, pour que la
/// bulle ne grandisse pas pendant qu'elle s'écrit.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.full});

  final String text;
  final String full;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.4);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.largeCard),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Stack(
        children: [
          Opacity(opacity: 0, child: Text(full, style: style)),
          Text(text, style: style),
        ],
      ),
    );
  }
}

class _ExtraRow extends ConsumerWidget {
  const _ExtraRow({super.key, required this.extra});

  final _Extra extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget chip(Widget icon, String label, Color color) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w700, color: Color.lerp(color, Colors.black, 0.3)),
          ),
        ],
      ),
    );
    final chips = switch (extra) {
      _Extra.languages => [
        for (final l in ref.watch(contentProvider).languages)
          chip(Icon(Icons.translate_rounded, size: 16, color: Color(l.color)), l.name, Color(l.color)),
      ],
      _Extra.rewards => [
        chip(const Icon(Icons.star_rounded, size: 16, color: AppColors.green500), 'XP', AppColors.green500),
        chip(const CauriIcon(size: 16), 'Cauris', caurisColor),
        chip(const Icon(Icons.bolt_rounded, size: 16, color: AppColors.purple500), 'Énergie', AppColors.purple500),
      ],
      _Extra.social => [
        chip(const Icon(Icons.diversity_3_rounded, size: 16, color: AppColors.green500), 'Défis', AppColors.green500),
        chip(
          const Icon(Icons.sports_kabaddi_rounded, size: 16, color: AppColors.purple500),
          'Duels',
          AppColors.purple500,
        ),
        chip(const Icon(Icons.shield_rounded, size: 16, color: AppColors.gold), 'Ligues', AppColors.gold),
      ],
    };
    return SizedBox(
      height: 44,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisSize: MainAxisSize.min, children: chips),
      ),
    );
  }
}
