import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Grand-père Kouman, le guide aîné de KoumanPlay : il respire, cligne des
/// yeux, parle ([talking]) et salue de la main à chaque nouvelle valeur de
/// [wave]. Effet de relief : il se balance légèrement en perspective.
/// Dessin provisoire, à remplacer par celui d'un illustrateur ivoirien.
class ElderGuide extends StatefulWidget {
  const ElderGuide({super.key, this.size = 240, this.talking = false, this.wave = 0});

  /// Hauteur du personnage.
  final double size;
  final bool talking;
  final int wave;

  @override
  State<ElderGuide> createState() => _ElderGuideState();
}

class _ElderGuideState extends State<ElderGuide> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))
    ..repeat();
  late final AnimationController _waveC = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final AnimationController _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();
  Timer? _blinkTimer;
  Timer? _mouthTimer;
  bool _blink = false;
  bool _mouthOpen = false;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _scheduleBlink();
    _syncMouth();
    _waveC.forward();
  }

  void _scheduleBlink() {
    _blinkTimer = Timer(Duration(milliseconds: 2200 + _rng.nextInt(2400)), () {
      if (!mounted) return;
      setState(() => _blink = true);
      Timer(const Duration(milliseconds: 140), () {
        if (mounted) setState(() => _blink = false);
        _scheduleBlink();
      });
    });
  }

  void _syncMouth() {
    _mouthTimer?.cancel();
    if (!widget.talking) {
      if (_mouthOpen) setState(() => _mouthOpen = false);
      return;
    }
    _mouthTimer = Timer.periodic(const Duration(milliseconds: 130), (_) {
      if (mounted) setState(() => _mouthOpen = !_mouthOpen && _rng.nextInt(5) > 0);
    });
  }

  @override
  void didUpdateWidget(covariant ElderGuide old) {
    super.didUpdateWidget(old);
    if (old.talking != widget.talking) _syncMouth();
    if (old.wave != widget.wave) _waveC.forward(from: 0);
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _mouthTimer?.cancel();
    _idle.dispose();
    _waveC.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.size;
    final w = h * 200 / 240;
    return AnimatedBuilder(
      animation: Listenable.merge([_idle, _waveC, _enter]),
      builder: (context, _) {
        final t = _idle.value * 2 * pi;
        final enter = Curves.elasticOut.transform(_enter.value.clamp(0, 1));
        final breathe = sin(t) * 0.012;
        // Au repos, le bras pend le long du corps ; pour saluer, il se lève,
        // la main oscille trois fois, puis il redescend.
        final waveT = _waveC.value;
        final raise = _waveC.isAnimating ? sin(waveT * pi) : 0.0;
        final armAngle = 0.05 + sin(t) * 0.03 + raise * (1.85 + sin(waveT * pi * 6) * 0.25);
        final headTilt = sin(t * 0.5) * 0.04 + (widget.talking ? sin(t * 3) * 0.02 : 0);
        return Transform.scale(
          scale: 0.6 + 0.4 * enter,
          alignment: Alignment.bottomCenter,
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(sin(t * 0.5) * 0.18),
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Ombre au sol.
                  Positioned(
                    left: w * 0.12,
                    right: w * 0.12,
                    bottom: -h * 0.02,
                    height: h * 0.07,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.all(Radius.elliptical(100, 20)),
                        color: Colors.black.withValues(alpha: 0.16),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Transform.scale(
                      scaleY: 1 + breathe,
                      alignment: Alignment.bottomCenter,
                      child: _svg(_bodySvg),
                    ),
                  ),
                  // Bras qui salue, accroché à l'épaule.
                  Positioned(
                    left: w * 0.01,
                    top: h * 0.52,
                    width: w * 0.3,
                    height: h * 0.36,
                    child: Transform.rotate(
                      angle: armAngle,
                      alignment: const Alignment(0.75, -0.85),
                      child: _svg(_armSvg),
                    ),
                  ),
                  Positioned(
                    left: w * 0.2,
                    width: w * 0.6,
                    top: h * 0.02 - breathe * h,
                    height: h * 0.54,
                    child: Transform.rotate(
                      angle: headTilt,
                      alignment: Alignment.bottomCenter,
                      child: _svg(_headSvg(eyesOpen: !_blink, mouthOpen: _mouthOpen)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static final _cache = <String, Widget>{};

  Widget _svg(String svg) => _cache.putIfAbsent(svg, () => SvgPicture.string(svg, fit: BoxFit.contain));
}

const _skin = '#7A4A2E';
const _skinDark = '#5E3620';

/// Boubou violet brodé d'or, bâton de marche à la main.
const _bodySvg =
    '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 240">
  <rect x="164" y="118" width="7" height="122" rx="3" fill="#6B4410"/>
  <circle cx="167.5" cy="116" r="8" fill="#8A5A1C"/>
  <path d="M100 112 C70 112 52 124 44 142 L22 240 L178 240 L156 142 C148 124 130 112 100 112 Z" fill="#5B2EFF"/>
  <path d="M22 240 L44 142 C47 136 50 131 55 127 L48 240 Z" fill="#4A22D6"/>
  <path d="M178 240 L156 142 C153 136 150 131 145 127 L152 240 Z" fill="#4A22D6"/>
  <path d="M84 114 L100 150 L116 114" fill="none" stroke="#D4A017" stroke-width="5" stroke-linejoin="round"/>
  <path d="M100 150 L100 240" stroke="#D4A017" stroke-width="5"/>
  <g fill="#D4A017">
    <rect x="94" y="168" width="12" height="5"/><rect x="94" y="186" width="12" height="5"/>
    <rect x="94" y="204" width="12" height="5"/><rect x="94" y="222" width="12" height="5"/>
  </g>
  <path d="M140 136 C158 146 166 160 168 176 L154 182 C150 168 144 158 134 150 Z" fill="#4A22D6"/>
  <circle cx="163" cy="176" r="9" fill="$_skin"/>
  <rect x="90" y="100" width="20" height="16" rx="6" fill="$_skinDark"/>
</svg>
''';

/// Bras levé : manche du boubou et main ouverte.
const _armSvg =
    '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 86">
  <path d="M46 6 C34 14 22 32 16 52 L30 58 C34 42 42 28 54 18 Z" fill="#4A22D6"/>
  <path d="M30 58 L16 52" stroke="#D4A017" stroke-width="3"/>
  <g fill="$_skin">
    <ellipse cx="20" cy="66" rx="10" ry="11"/>
    <rect x="11" y="50" width="5" height="12" rx="2.5" transform="rotate(-12 13 56)"/>
    <rect x="16" y="48" width="5" height="13" rx="2.5"/>
    <rect x="21" y="49" width="5" height="12" rx="2.5" transform="rotate(10 23 55)"/>
    <rect x="26" y="54" width="5" height="10" rx="2.5" transform="rotate(30 28 59)"/>
  </g>
</svg>
''';

/// Tête : bonnet aux couleurs du pagne, barbe blanche, yeux et bouche animés.
String _headSvg({required bool eyesOpen, required bool mouthOpen}) {
  final eyes = eyesOpen
      ? '<g><ellipse cx="45" cy="70" rx="6" ry="7" fill="#fff"/><circle cx="46" cy="71" r="3.6" fill="#24140B"/>'
            '<ellipse cx="75" cy="70" rx="6" ry="7" fill="#fff"/><circle cx="76" cy="71" r="3.6" fill="#24140B"/>'
            '<circle cx="47" cy="69.5" r="1.2" fill="#fff"/><circle cx="77" cy="69.5" r="1.2" fill="#fff"/></g>'
      : '<path d="M39 71 Q45 75 51 71 M69 71 Q75 75 81 71" stroke="#24140B" stroke-width="2.6" fill="none" stroke-linecap="round"/>';
  final mouth = mouthOpen
      ? '<ellipse cx="60" cy="99" rx="7" ry="5.5" fill="#3A1F12"/><ellipse cx="60" cy="101.5" rx="4" ry="2.2" fill="#D9707A"/>'
      : '<path d="M53 98 Q60 102 67 98" stroke="#3A1F12" stroke-width="2.6" fill="none" stroke-linecap="round"/>';
  return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 130">
  <circle cx="20" cy="74" r="9" fill="$_skinDark"/><circle cx="100" cy="74" r="9" fill="$_skinDark"/>
  <circle cx="60" cy="72" r="40" fill="$_skin"/>
  <ellipse cx="44" cy="58" rx="16" ry="10" fill="#fff" opacity="0.08"/>
  <path d="M22 56 Q22 16 60 14 Q98 16 98 56 Q60 46 22 56 Z" fill="#D4A017"/>
  <path d="M24 46 Q60 36 96 46 L97 52 Q60 42 23 52 Z" fill="#B5541B"/>
  <g fill="#1C1210"><rect x="34" y="28" width="7" height="7"/><rect x="50" y="24" width="7" height="7"/>
    <rect x="66" y="24" width="7" height="7"/><rect x="82" y="28" width="7" height="7"/></g>
  <path d="M36 61 Q45 55 54 60 M66 60 Q75 55 84 61" stroke="#F2EEE6" stroke-width="4" fill="none" stroke-linecap="round"/>
  $eyes
  <ellipse cx="60" cy="83" rx="7" ry="5" fill="$_skinDark"/>
  <ellipse cx="38" cy="86" rx="6" ry="4" fill="#C0605A" opacity="0.35"/><ellipse cx="82" cy="86" rx="6" ry="4" fill="#C0605A" opacity="0.35"/>
  <path d="M24 82 Q26 124 60 128 Q94 124 96 82 Q84 104 60 104 Q36 104 24 82 Z" fill="#F2EEE6"/>
  <path d="M40 92 Q50 86 60 92 Q70 86 80 92 Q72 96 60 95 Q48 96 40 92 Z" fill="#FFFFFF"/>
  $mouth
</svg>
''';
}
