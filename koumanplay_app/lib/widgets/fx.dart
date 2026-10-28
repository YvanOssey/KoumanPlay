import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../models/content.dart';
import '../services/providers.dart';

/// Effets sonores du jeu (assets/sounds, générés par tool/make_sounds.py) et
/// encouragements enregistrés par les aînés dans la langue jouée.
class SoundFx {
  SoundFx(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'sound_on';
  final _players = <String, AudioPlayer>{};
  final _loaded = <String>{};
  AudioPlayer? _voice;
  final _rng = Random();

  bool get enabled => _prefs.getBool(_key) ?? true;

  Future<void> setEnabled(bool on) => _prefs.setBool(_key, on);

  /// [name] : correct, wrong, win, lose, pull, flip, match, tick, go.
  Future<void> play(String name) async {
    if (!enabled) return;
    try {
      final player = _players[name] ??= AudioPlayer();
      if (_loaded.add(name)) await player.setAsset('assets/sounds/$name.wav');
      await player.seek(Duration.zero);
      unawaited(player.play());
    } catch (e) {
      debugPrint('Son $name non joué : $e');
    }
  }

  /// Le son de [kind] (correct, wrong, win), puis, avec la probabilité
  /// [voiceChance], un encouragement d'aîné enregistré dans la langue.
  Future<void> cheer(String kind, {ContentPack? content, String? languageId, double voiceChance = 1}) async {
    await play(kind);
    if (!enabled || content == null || languageId == null) return;
    final clips = content.soundsOf(languageId, kind);
    if (clips.isEmpty || _rng.nextDouble() > voiceChance) return;
    final clip = clips[_rng.nextInt(clips.length)];
    await Future<void>.delayed(Duration(milliseconds: kind == 'win' ? 900 : 350));
    try {
      final voice = _voice ??= AudioPlayer();
      if (clip.audio.startsWith('assets/')) {
        await voice.setAsset(clip.audio);
      } else {
        await voice.setUrl(clip.audio);
      }
      unawaited(voice.play());
    } catch (e) {
      debugPrint('Encouragement non joué : $e');
    }
  }
}

final soundProvider = Provider<SoundFx>((ref) => SoundFx(ref.read(prefsProvider)));

/// Pluie de confettis aux couleurs du jeu, relancée à chaque nouvelle valeur
/// de [trigger] (0 = rien). [big] : victoire, plein écran.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, required this.trigger, this.big = false});

  final int trigger;
  final bool big;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  List<_Piece> _pieces = const [];

  static const _colors = [
    AppColors.purple500,
    AppColors.gold,
    AppColors.green500,
    Color(0xFFB5541B),
    Color(0xFFFFD66B),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.trigger > 0) _burst();
  }

  @override
  void didUpdateWidget(covariant ConfettiBurst old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger > 0) _burst();
  }

  void _burst() {
    final rng = Random(widget.trigger);
    final count = widget.big ? 140 : 36;
    _pieces = [
      for (var i = 0; i < count; i++)
        _Piece(
          // Victoire : tombe du haut ; bonne réponse : jaillit du centre.
          x: widget.big ? rng.nextDouble() : 0.5 + (rng.nextDouble() - 0.5) * 0.2,
          y: widget.big ? -0.05 - rng.nextDouble() * 0.3 : 0.55,
          vx: (rng.nextDouble() - 0.5) * (widget.big ? 0.3 : 1.1),
          vy: widget.big ? 0.2 + rng.nextDouble() * 0.5 : -0.6 - rng.nextDouble() * 0.7,
          spin: (rng.nextDouble() - 0.5) * 14,
          size: 5 + rng.nextDouble() * 6,
          color: _colors[rng.nextInt(_colors.length)],
        ),
    ];
    _c
      ..duration = Duration(milliseconds: widget.big ? 2600 : 1100)
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => _c.isAnimating
            ? CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_pieces, _c.value, widget.big))
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.spin,
    required this.size,
    required this.color,
  });

  final double x, y, vx, vy, spin, size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t, this.big);

  final List<_Piece> pieces;
  final double t;
  final bool big;

  @override
  void paint(Canvas canvas, Size size) {
    final time = t * (big ? 2.6 : 1.1);
    final gravity = big ? 0.35 : 1.6;
    final paint = Paint();
    for (final p in pieces) {
      final x = (p.x + p.vx * time) * size.width;
      final y = (p.y + p.vy * time + 0.5 * gravity * time * time) * size.height;
      paint.color = p.color.withValues(alpha: (1 - t * t).clamp(0, 1));
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p.spin * time);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

/// Secoue [child] de gauche à droite à chaque nouvelle valeur de [trigger]
/// (mauvaise réponse).
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void didUpdateWidget(covariant Shake old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger > 0) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) =>
          Transform.translate(offset: Offset(sin(_c.value * pi * 6) * 10 * (1 - _c.value), 0), child: child),
      child: widget.child,
    );
  }
}

/// Fin de partie : fanfare et confettis si [won], sinon un son plus doux.
class Celebration extends ConsumerStatefulWidget {
  const Celebration({super.key, required this.won, required this.child, this.languageId});

  final bool won;
  final String? languageId;
  final Widget child;

  @override
  ConsumerState<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends ConsumerState<Celebration> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(soundProvider)
          .cheer(widget.won ? 'win' : 'lose', content: ref.read(contentProvider), languageId: widget.languageId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(child: ConfettiBurst(trigger: widget.won ? 1 : 0, big: true)),
      ],
    );
  }
}

/// Fait apparaître [child] après [delay], en glissant vers le haut ; [pop] :
/// en grossissant (badge, récompense).
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.delay, required this.child, this.pop = false});

  final Duration delay;
  final bool pop;
  final Widget child;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final curved = (widget.pop ? Curves.elasticOut : Curves.easeOutCubic).transform(t);
        return Opacity(
          opacity: Curves.easeOut.transform(t),
          child: widget.pop
              ? Transform.scale(
                  scale: 0.3 + 0.7 * curved,
                  child: Transform.rotate(angle: (1 - curved) * 0.3, child: child),
                )
              : Transform.translate(offset: Offset(0, 24 * (1 - curved)), child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Nombre qui monte de 0 jusqu'à [value], après [delay].
class CountUp extends StatefulWidget {
  const CountUp({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.delay = Duration.zero,
  });

  final int value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration delay;

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 500 + min(widget.value, 100) * 8),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Text(
        '${widget.prefix}${(widget.value * Curves.easeOut.transform(_c.value)).round()}${widget.suffix}',
        style: widget.style,
      ),
    );
  }
}

/// Quelques [child] (cauris) qui s'envolent et s'effacent, après [delay].
class FlyingIcons extends StatefulWidget {
  const FlyingIcons({super.key, required this.child, this.count = 5, this.delay = Duration.zero});

  final Widget child;
  final int count;
  final Duration delay;

  @override
  State<FlyingIcons> createState() => _FlyingIconsState();
}

class _FlyingIconsState extends State<FlyingIcons> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < widget.count; i++)
              Builder(
                builder: (context) {
                  final start = i / (widget.count * 2);
                  final t = ((_c.value - start) / (1 - start)).clamp(0.0, 1.0);
                  if (t == 0 || t == 1) return const SizedBox.shrink();
                  return Transform.translate(
                    offset: Offset((i - widget.count / 2) * 12 * t, -70 * Curves.easeOut.transform(t)),
                    child: Opacity(opacity: 1 - t, child: widget.child),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
