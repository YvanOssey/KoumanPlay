import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../models/avatar.dart';
import '../../models/content.dart';
import '../../models/player.dart';
import '../../services/providers.dart';
import '../../widgets/avatar_view.dart';
import '../../widgets/common.dart';
import '../../widgets/cauris.dart';
import '../../widgets/energy.dart';
import '../../widgets/language_option.dart';

// Géométrie de la carte : chaque langue est une « zone » ; ses niveaux
// montent en zigzag du bas (niveau 1) vers le haut, au-dessus de son bandeau.
const _nodeSpacing = 118.0;
const _zoneTopPadding = 70.0;
const _bannerHeight = 176.0;
const _firstNodeFromBottom = _bannerHeight + 90.0;

enum NodeState { done, current, open, locked, preparing }

NodeState nodeStateOf(ContentPack content, PlayerState player, Level level, Level? current) {
  if (!content.isPlayable(level)) return NodeState.preparing;
  if (player.isLevelPassed(level.id)) return NodeState.done;
  if (!GameRules.isLevelUnlocked(content, player, level)) return NodeState.locked;
  return level.id == current?.id ? NodeState.current : NodeState.open;
}

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.showBack = false});

  /// Ouverte hors des onglets (espace aîné) : bouton retour.
  final bool showBack;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _scroll = ScrollController();
  final _offset = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _offset.value = _scroll.offset);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _offset.dispose();
    super.dispose();
  }

  /// Amène le niveau en cours vers le bas du tiers de l'écran.
  void _scrollToCurrent() {
    if (!_scroll.hasClients) return;
    final content = ref.read(contentProvider);
    final current = GameRules.nextLevel(content, ref.read(playerProvider));
    if (current == null) return;
    final levels = content.levelsOf(current.languageId);
    final offset = _firstNodeFromBottom + levels.indexWhere((l) => l.id == current.id) * _nodeSpacing;
    final target = (offset - _scroll.position.viewportDimension * 0.35).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic);
  }

  Future<void> _chooseLanguage() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LanguagePickerSheet(),
    );
    if (chosen == null) return;
    await ref.read(playerProvider.notifier).setLearningLanguage(chosen);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentProvider);
    final player = ref.watch(playerProvider);
    final current = GameRules.nextLevel(content, player);
    final language = GameRules.learningLanguage(content, player);
    if (language == null) return const SizedBox.shrink();

    return Stack(
      children: [
        Positioned.fill(
          child: ValueListenableBuilder<double>(
            valueListenable: _offset,
            builder: (context, offset, _) => CustomPaint(painter: _ParallaxBackground(offset)),
          ),
        ),
        CustomScrollView(
          controller: _scroll,
          reverse: true,
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: _LanguageZone(
                language: language,
                stepNumber: content.languages.indexOf(language) + 1,
                content: content,
                player: player,
                current: current,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _MapHeader(
            language: language,
            cauris: player.cauris,
            onBack: widget.showBack ? () => context.pop() : null,
            onChangeLanguage: _chooseLanguage,
          ),
        ),
      ],
    );
  }
}

/// Choix de la langue de la carte ; renvoie l'id choisi.
class LanguagePickerSheet extends ConsumerWidget {
  const LanguagePickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider);
    final current = GameRules.learningLanguage(content, ref.watch(playerProvider));
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(AppSpacing.screen),
      decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(AppRadius.largeCard)),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Quelle langue veux-tu apprendre ?', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('Ta progression dans chaque langue est gardée.', style: TextStyle(color: AppColors.gray500)),
            const SizedBox(height: 14),
            for (final l in content.languages) ...[
              LanguageOption(
                language: l,
                ready: content.playableLevelsOf(l.id).isNotEmpty,
                selected: l.id == current?.id,
                onTap: () => Navigator.pop(context, l.id),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.language, required this.cauris, required this.onChangeLanguage, this.onBack});

  final Language language;
  final int cauris;
  final VoidCallback onChangeLanguage;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.cream, AppColors.cream.withValues(alpha: 0)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 24),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                if (onBack != null) ...[
                  IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: onBack),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Material(
                      color: AppColors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onChangeLanguage,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  language.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Color(language.color)),
                                ),
                              ),
                              Icon(Icons.expand_more_rounded, color: Color(language.color)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Le nom de la langue passe avant le temps d'attente sur les petits écrans.
                EnergyPill(showWait: constraints.maxWidth >= 340),
                const SizedBox(width: 8),
                GestureDetector(onTap: () => context.push('/boutique'), child: CauriPill(cauris: cauris)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Une étape : les niveaux d'une langue sur leur chemin, puis son bandeau.
class _LanguageZone extends StatelessWidget {
  const _LanguageZone({
    required this.language,
    required this.stepNumber,
    required this.content,
    required this.player,
    required this.current,
  });

  final Language language;
  final int stepNumber;
  final ContentPack content;
  final PlayerState player;
  final Level? current;

  @override
  Widget build(BuildContext context) {
    final levels = content.levelsOf(language.id);
    final color = Color(language.color);
    final nodesHeight = levels.length * _nodeSpacing + _zoneTopPadding;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Centre de chaque niveau, i = 0 en bas.
        final centers = [
          for (var i = 0; i < levels.length; i++)
            Offset(
              width / 2 + sin(i * 1.15 + stepNumber) * width * 0.27,
              nodesHeight - (_firstNodeFromBottom - _bannerHeight) - i * _nodeSpacing,
            ),
        ];
        final states = [for (final l in levels) nodeStateOf(content, player, l, current)];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: nodesHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RoadPainter(centers: centers, states: states, color: color),
                    ),
                  ),
                  for (var i = 0; i < levels.length; i++)
                    Positioned(
                      left: centers[i].dx - 80,
                      top: centers[i].dy - 44,
                      width: 160,
                      child: _LevelNode(
                        level: levels[i],
                        state: states[i],
                        color: color,
                        index: i,
                        avatar: player.avatarOrDefault,
                        result: player.levels[levels[i].id],
                        itemCount: content.itemsOf(levels[i].id).length,
                        languageName: language.name,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: _bannerHeight,
              child: _ZoneBanner(language: language, stepNumber: stepNumber, content: content, player: player),
            ),
          ],
        );
      },
    );
  }
}

/// Bandeau d'étape incliné en perspective (effet 3D).
class _ZoneBanner extends StatelessWidget {
  const _ZoneBanner({required this.language, required this.stepNumber, required this.content, required this.player});

  final Language language;
  final int stepNumber;
  final ContentPack content;
  final PlayerState player;

  @override
  Widget build(BuildContext context) {
    final color = Color(language.color);
    final playable = content.playableLevelsOf(language.id);
    final passed = playable.where((l) => player.isLevelPassed(l.id)).length;
    final unlocked = playable.isNotEmpty;
    final status = playable.isEmpty
        ? 'Bientôt · contenu en collecte avec les aînés'
        : '$passed / ${playable.length} niveaux validés';

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 8, AppSpacing.screen, 24),
      child: Transform(
        alignment: Alignment.bottomCenter,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateX(0.32),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.largeCard),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: unlocked && playable.isNotEmpty
                  ? [color, Color.lerp(color, Colors.black, 0.35)!]
                  : [AppColors.gray400, AppColors.gray500],
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.25), offset: const Offset(0, 10), blurRadius: 16),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'MA LANGUE · ${language.group.toUpperCase()}',
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      language.name,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      language.region,
                      style: TextStyle(color: AppColors.white.withValues(alpha: 0.85), fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status,
                      style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Icon(
                !unlocked || playable.isEmpty ? Icons.lock_rounded : Icons.translate_rounded,
                color: AppColors.white.withValues(alpha: 0.9),
                size: 34,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton de niveau en relief : une face, une tranche plus sombre et une
/// ombre au sol. Le niveau en cours flotte et porte l'avatar du joueur.
class _LevelNode extends StatefulWidget {
  const _LevelNode({
    required this.level,
    required this.state,
    required this.color,
    required this.index,
    required this.avatar,
    required this.result,
    required this.itemCount,
    required this.languageName,
  });

  final Level level;
  final NodeState state;
  final Color color;
  final int index;
  final AvatarConfig avatar;
  final LevelResult? result;
  final int itemCount;
  final String languageName;

  @override
  State<_LevelNode> createState() => _LevelNodeState();
}

class _LevelNodeState extends State<_LevelNode> with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  bool _pressed = false;

  static const _size = 72.0;
  static const _depth = 7.0;

  @override
  void initState() {
    super.initState();
    if (widget.state == NodeState.current) _float.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _LevelNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == NodeState.current && !_float.isAnimating) {
      _float.repeat(reverse: true);
    } else if (widget.state != NodeState.current && _float.isAnimating) {
      _float.stop();
      _float.value = 0;
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  void _onTap() {
    final messenger = ScaffoldMessenger.of(context);
    switch (widget.state) {
      case NodeState.locked:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Valide les niveaux précédents pour débloquer celui-ci.')));
      case NodeState.preparing:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Niveau en préparation : les ${widget.level.kindLabel.toLowerCase()} en ${widget.languageName} '
                'sont en cours de collecte avec les aînés.',
              ),
            ),
          );
      case NodeState.done || NodeState.current || NodeState.open:
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => _LevelSheet(
            level: widget.level,
            color: widget.color,
            result: widget.result,
            itemCount: widget.itemCount,
            languageName: widget.languageName,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final active = state == NodeState.done || state == NodeState.current || state == NodeState.open;
    final face = switch (state) {
      NodeState.done => AppColors.green500,
      NodeState.current || NodeState.open => widget.color,
      NodeState.locked => AppColors.gray400,
      NodeState.preparing => AppColors.gray200,
    };
    final icon = switch (state) {
      NodeState.done => Icons.check_rounded,
      NodeState.current || NodeState.open => switch (widget.level.kind) {
        LevelKind.mots => Icons.translate_rounded,
        LevelKind.phrases => Icons.chat_bubble_rounded,
        LevelKind.proverbes => Icons.auto_stories_rounded,
        LevelKind.tresors => Icons.museum_rounded,
      },
      NodeState.locked => Icons.lock_rounded,
      NodeState.preparing => Icons.hourglass_empty_rounded,
    };

    // Apparition en « basculant » vers l'avant, décalée selon le niveau.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + widget.index * 90),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform(
        alignment: Alignment.bottomCenter,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.002)
          ..rotateX((1 - t) * -pi / 2.5),
        child: Opacity(opacity: t.clamp(0, 1), child: child),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTapDown: active ? (_) => setState(() => _pressed = true) : null,
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: _onTap,
            child: AnimatedBuilder(
              animation: _float,
              builder: (context, _) {
                final lift = Curves.easeInOut.transform(_float.value) * 8;
                return SizedBox(
                  width: _size + 24,
                  height: _size + _depth + 14,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      // Ombre au sol : plus petite et plus claire quand le bouton s'élève.
                      Positioned(
                        top: _size + _depth - 10,
                        child: Container(
                          width: _size * (1.05 - lift / 30),
                          height: 16,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.all(Radius.elliptical(60, 10)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.28 - lift / 60),
                                blurRadius: 8,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (state == NodeState.current)
                        Positioned(
                          top: 2 - lift,
                          child: _PulseRing(color: widget.color, size: _size),
                        ),
                      // Tranche du bouton.
                      Positioned(
                        top: _depth - lift,
                        child: _Disc(size: _size, color: Color.lerp(face, Colors.black, 0.28)!),
                      ),
                      // Face du bouton, qui s'enfonce quand on appuie.
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 80),
                        top: (_pressed ? _depth - 2 : 0) - lift,
                        child: _Disc(
                          size: _size,
                          color: face,
                          highlight: true,
                          dashed: state == NodeState.preparing,
                          child: Icon(
                            icon,
                            size: 32,
                            color: state == NodeState.preparing ? AppColors.gray400 : AppColors.white,
                          ),
                        ),
                      ),
                      if (state == NodeState.current)
                        Positioned(
                          top: 16 - lift,
                          right: -30,
                          child: _AvatarBubble(avatar: widget.avatar, color: widget.color),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: active ? AppColors.black.withValues(alpha: 0.85) : AppColors.gray500.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.result?.passed ?? false) ...[
                  StarRow(
                    stars: GameRules.stars(widget.result!.bestCorrect, widget.result!.total, passed: true),
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    'Niv. ${widget.level.order} · ${widget.level.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.size, required this.color, this.highlight = false, this.dashed = false, this.child});

  final double size;
  final Color color;
  final bool highlight;
  final bool dashed;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: dashed ? Border.all(color: AppColors.gray400, width: 2) : null,
        gradient: highlight
            ? RadialGradient(
                center: const Alignment(-0.35, -0.45),
                radius: 0.9,
                colors: [Color.lerp(color, Colors.white, 0.35)!, color],
              )
            : null,
        color: highlight ? null : color,
      ),
      child: child,
    );
  }
}

class _PulseRing extends StatefulWidget {
  const _PulseRing({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final scale = 1 + _c.value * 0.45;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: widget.color.withValues(alpha: 1 - _c.value), width: 4),
            ),
          ),
        );
      },
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({required this.avatar, required this.color});

  final AvatarConfig avatar;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      child: AvatarView(config: avatar, size: 38),
    );
  }
}

class _LevelSheet extends StatelessWidget {
  const _LevelSheet({
    required this.level,
    required this.color,
    required this.result,
    required this.itemCount,
    required this.languageName,
  });

  final Level level;
  final Color color;
  final LevelResult? result;
  final int itemCount;
  final String languageName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = switch (level.kind) {
      LevelKind.proverbes => '$itemCount proverbes',
      LevelKind.tresors => '$itemCount questions sur les trésors du patrimoine',
      _ => '$itemCount ${level.kindLabel.toLowerCase()} à apprendre',
    };
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(AppSpacing.screen),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(AppRadius.largeCard)),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow('$languageName · Niveau ${level.order} · ${level.kindLabel}', color: color),
            const SizedBox(height: 4),
            Text(level.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(count, style: const TextStyle(color: AppColors.gray500)),
            if (result != null) ...[
              const SizedBox(height: 4),
              Text(
                'Meilleur score : ${result!.bestCorrect}/${result!.total}',
                style: const TextStyle(color: AppColors.gray500),
              ),
            ],
            const SizedBox(height: AppSpacing.section),
            EnergyBuilder(
              builder: (context, energy, nextIn) => FilledButton(
                style: FilledButton.styleFrom(backgroundColor: color),
                onPressed: energy == 0
                    ? null
                    : () {
                        Navigator.pop(context);
                        context.push('/quiz/${level.id}');
                      },
                child: Text(
                  energy == 0
                      ? 'Plus d\'énergie · ${formatWait(nextIn ?? GameRules.energyRefill)}'
                      : result?.passed ?? false
                      ? 'Rejouer'
                      : 'Jouer',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Route du chemin : ombre décalée (relief), bande de terre, pointillés.
class _RoadPainter extends CustomPainter {
  _RoadPainter({required this.centers, required this.states, required this.color});

  final List<Offset> centers;
  final List<NodeState> states;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (centers.isEmpty) return;
    // Le chemin entre dans la zone par le bas (depuis le bandeau) et en sort
    // par le haut (vers l'étape suivante).
    final points = [Offset(size.width / 2, size.height + 40), ...centers, Offset(size.width / 2, -20)];
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final mid = (a.dy + b.dy) / 2;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, mid, b.dx, mid, b.dx, b.dy);
      final reached = i > 0 && i - 1 < states.length && states[i - 1] == NodeState.done;

      canvas.drawPath(
        path.shift(const Offset(0, 6)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = reached ? Color.lerp(color, Colors.white, 0.25)! : const Color(0xFFE6D3A3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round,
      );
      _drawDashes(canvas, path, reached ? AppColors.white : const Color(0xFFB89B5E));
    }
  }

  void _drawDashes(Canvas canvas, Path path, Color dashColor) {
    final paint = Paint()
      ..color = dashColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      for (var d = 8.0; d < metric.length; d += 22) {
        canvas.drawPath(metric.extractPath(d, min(d + 9, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter old) =>
      old.centers != centers || old.states != states || old.color != color;
}

/// Décor en couches qui défilent à des vitesses différentes (profondeur).
class _ParallaxBackground extends CustomPainter {
  _ParallaxBackground(this.offset);

  final double offset;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF9EED8), Color(0xFFE9F3DF)],
        ).createShader(rect),
    );
    _layer(canvas, size, speed: 0.25, spacing: 260, radius: 70, color: const Color(0xFFD9E8C8), seed: 1);
    _layer(canvas, size, speed: 0.5, spacing: 210, radius: 34, color: const Color(0xFFC6DDAF), seed: 2);
    _layer(canvas, size, speed: 0.8, spacing: 170, radius: 16, color: const Color(0xFFE7C98F), seed: 3);
  }

  /// Rangée de collines/buissons qui se répète verticalement. La liste
  /// défile du bas vers le haut, d'où le signe.
  void _layer(
    Canvas canvas,
    Size size, {
    required double speed,
    required double spacing,
    required double radius,
    required Color color,
    required int seed,
  }) {
    final paint = Paint()..color = color;
    final travel = offset * speed;
    final shift = travel % spacing;
    final base = (travel / spacing).floor();
    for (var j = -1; j * spacing < size.height + spacing; j++) {
      final y = j * spacing + shift;
      // Identifiant stable de l'élément pour qu'il ne « saute » pas en défilant.
      final row = j - base + seed * 7;
      final left = (row.isEven ? 0.08 : 0.82) * size.width + sin(row * 1.7) * 20;
      canvas.drawCircle(Offset(left, y), radius, paint);
      canvas.drawCircle(Offset(left + radius * 0.9, y + radius * 0.25), radius * 0.7, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParallaxBackground old) => old.offset != offset;
}
