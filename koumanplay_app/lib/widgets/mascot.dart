import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Humeur de la mascotte.
enum MascotMood {
  /// Respire tranquillement.
  idle,

  /// Bonne réponse : saute, trompe levée, yeux rieurs.
  happy,

  /// Erreur : oreilles basses, trompe qui pend, petite larme.
  sad,

  /// Réfléchit : trompe enroulée, regard en l'air.
  think,

  /// Grande fête : sauts répétés, oreilles qui battent.
  cheer,

  /// Parle (conseil) : la bouche bouge.
  talk,
}

/// L'éléphanteau de KoumanPlay, avec son foulard kita. Il réagit pendant les
/// quiz et donne des conseils. Dessin provisoire en attendant la version
/// animée d'un illustrateur ivoirien (fichier Rive).
class Mascot extends StatefulWidget {
  const Mascot({super.key, this.mood = MascotMood.idle, this.size = 120, this.reaction = 0});

  final MascotMood mood;
  final double size;

  /// Change à chaque réponse : relance l'animation de l'humeur même si elle
  /// ne change pas (deux bonnes réponses de suite).
  final int reaction;

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();
  late final AnimationController _react = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  /// Pose actuelle, qui glisse vers celle de l'humeur.
  late final AnimationController _blend = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  _Pose _from = _Pose.of(MascotMood.idle);
  _Pose _to = _Pose.of(MascotMood.idle);

  @override
  void initState() {
    super.initState();
    _to = _Pose.of(widget.mood);
    _from = _to;
    _react.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant Mascot old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood || old.reaction != widget.reaction) {
      _from = _Pose.lerp(_from, _to, _blend.value);
      _to = _Pose.of(widget.mood);
      _blend.forward(from: 0);
      _react.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _react.dispose();
    _blend.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _react, _blend]),
        builder: (context, _) {
          final t = _idle.value * 2 * pi;
          final r = _react.value;
          final pose = _Pose.lerp(_from, _to, Curves.easeOut.transform(_blend.value));
          var hop = 0.0;
          var flap = 0.0;
          var tilt = sin(t) * 0.02;
          switch (widget.mood) {
            case MascotMood.happy:
              hop = sin(r * pi) * 0.16;
              flap = sin(r * pi * 4) * 0.25 * (1 - r);
            case MascotMood.cheer:
              hop = sin(t * 2).abs() * 0.14;
              flap = sin(t * 4) * 0.3;
              tilt = sin(t * 2) * 0.08;
            case MascotMood.sad:
              tilt = sin(r * pi * 3) * 0.05 * (1 - r);
            case MascotMood.talk:
              tilt = sin(t * 3) * 0.03;
            case MascotMood.idle || MascotMood.think:
              break;
          }
          final talking = widget.mood == MascotMood.talk && sin(t * 9) > 0;
          return SizedBox(
            width: widget.size,
            height: widget.size * 1.1,
            child: Transform.translate(
              offset: Offset(0, -hop * widget.size + sin(t) * widget.size * 0.012),
              child: Transform.rotate(
                angle: tilt,
                alignment: Alignment.bottomCenter,
                child: CustomPaint(
                  painter: _ElephantPainter(pose: pose, flap: flap, mouthOpen: talking || pose.mouthOpen),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Une expression : position des oreilles, de la trompe, des yeux, de la bouche.
class _Pose {
  const _Pose({
    required this.ear,
    required this.trunk,
    required this.eyes,
    required this.smile,
    required this.brow,
    this.lookUp = 0,
    this.tear = 0,
    this.mouthOpen = false,
  });

  /// Oreilles : 0 au repos, négatif = baissées, positif = dressées.
  final double ear;

  /// Trompe : -1 pend, 0 au repos, 1 levée, 2 enroulée (réflexion).
  final double trunk;

  /// Yeux : 0 ouverts, 1 rieurs (fermés en arc).
  final double eyes;

  /// Bouche : 1 sourire, -1 moue.
  final double smile;

  /// Sourcils : positif = tristes (relevés au milieu).
  final double brow;
  final double lookUp;
  final double tear;
  final bool mouthOpen;

  static _Pose of(MascotMood mood) => switch (mood) {
    MascotMood.idle => const _Pose(ear: 0, trunk: 0, eyes: 0, smile: 0.6, brow: 0),
    MascotMood.happy => const _Pose(ear: 0.35, trunk: 1, eyes: 1, smile: 1, brow: 0, mouthOpen: true),
    MascotMood.cheer => const _Pose(ear: 0.45, trunk: 1, eyes: 1, smile: 1, brow: 0, mouthOpen: true),
    MascotMood.sad => const _Pose(ear: -0.55, trunk: -1, eyes: 0, smile: -1, brow: 1, tear: 1),
    MascotMood.think => const _Pose(ear: 0.1, trunk: 2, eyes: 0, smile: 0.2, brow: -0.4, lookUp: 1),
    MascotMood.talk => const _Pose(ear: 0.15, trunk: 0.3, eyes: 0, smile: 0.8, brow: 0),
  };

  static _Pose lerp(_Pose a, _Pose b, double t) => _Pose(
    ear: lerpDouble(a.ear, b.ear, t)!,
    trunk: lerpDouble(a.trunk, b.trunk, t)!,
    eyes: lerpDouble(a.eyes, b.eyes, t)!,
    smile: lerpDouble(a.smile, b.smile, t)!,
    brow: lerpDouble(a.brow, b.brow, t)!,
    lookUp: lerpDouble(a.lookUp, b.lookUp, t)!,
    tear: lerpDouble(a.tear, b.tear, t)!,
    mouthOpen: t < 0.5 ? a.mouthOpen : b.mouthOpen,
  );
}

class _ElephantPainter extends CustomPainter {
  _ElephantPainter({required this.pose, required this.flap, required this.mouthOpen});

  final _Pose pose;
  final double flap;
  final bool mouthOpen;

  static const _skin = Color(0xFF9AA6BA);
  static const _skinDark = Color(0xFF7D8AA0);
  static const _inner = Color(0xFFE9A9B6);
  static const _ink = Color(0xFF241A2E);

  @override
  void paint(Canvas canvas, Size size) {
    // Dessin dans un repère 200 x 220, mis à l'échelle.
    canvas.scale(size.width / 200, size.height / 220);
    final skin = Paint()..color = _skin;
    final dark = Paint()..color = _skinDark;

    // Ombre au sol.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 214), width: 110, height: 12),
      Paint()..color = Colors.black.withValues(alpha: 0.14),
    );

    // Corps et pattes.
    canvas.drawOval(Rect.fromCenter(center: const Offset(100, 176), width: 104, height: 70), skin);
    for (final x in [74.0, 126.0]) {
      final leg = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, 198), width: 30, height: 26),
        const Radius.circular(12),
      );
      canvas.drawRRect(leg, skin);
      for (final dx in [-7.0, 0.0, 7.0]) {
        canvas.drawCircle(Offset(x + dx, 208), 3, Paint()..color = const Color(0xFFE8E2D6));
      }
    }

    // Oreilles, accrochées sur les côtés de la tête.
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      final anchor = Offset(100 + side * 34, 82);
      canvas.translate(anchor.dx, anchor.dy);
      canvas.rotate(side * (-pose.ear * 0.6 - flap));
      final outer = Rect.fromCenter(center: Offset(side * 26, 14), width: 66, height: 78);
      canvas.drawOval(outer, dark);
      canvas.drawOval(outer.deflate(5), skin);
      canvas.drawOval(Rect.fromCenter(center: Offset(side * 28, 16), width: 40, height: 52), Paint()..color = _inner);
      canvas.restore();
    }

    // Tête.
    canvas.drawCircle(const Offset(100, 92), 54, skin);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(84, 68), width: 40, height: 22),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );

    // Foulard kita autour du cou, noué sur le côté.
    final scarf = Path()
      ..moveTo(52, 140)
      ..quadraticBezierTo(100, 158, 148, 140)
      ..lineTo(150, 152)
      ..quadraticBezierTo(100, 172, 50, 152)
      ..close();
    canvas.save();
    canvas.clipPath(scarf);
    const stripes = [Color(0xFFE0A800), Color(0xFF1F7A3E), Color(0xFFE0A800), Color(0xFFB3261E)];
    for (var i = 0; i < 14; i++) {
      canvas.drawRect(Rect.fromLTWH(50 + i * 7.3, 130, 7.3, 50), Paint()..color = stripes[i % stripes.length]);
    }
    canvas.restore();
    final knot = Path()
      ..moveTo(136, 150)
      ..lineTo(158, 172)
      ..lineTo(146, 176)
      ..lineTo(132, 154)
      ..close();
    canvas.drawPath(knot, Paint()..color = const Color(0xFFE0A800));
    canvas.drawCircle(const Offset(136, 151), 6, Paint()..color = const Color(0xFFB3261E));

    // Joues.
    for (final x in [66.0, 134.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 108), width: 18, height: 10),
        Paint()..color = _inner.withValues(alpha: 0.7),
      );
    }

    // Bouche, sous la trompe.
    final mouth = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    if (mouthOpen) {
      canvas.drawOval(Rect.fromCenter(center: const Offset(100, 126), width: 18, height: 12), Paint()..color = _ink);
      canvas.drawOval(Rect.fromCenter(center: const Offset(100, 129), width: 10, height: 5), Paint()..color = _inner);
    } else {
      final curve = pose.smile * 6;
      canvas.drawPath(
        Path()
          ..moveTo(90, 124)
          ..quadraticBezierTo(100, 124 + curve, 110, 124),
        mouth,
      );
    }

    // Trompe : un tube épais dont l'extrémité suit l'expression.
    final start = const Offset(100, 100);
    final (Offset c1, Offset c2, Offset end) = switch (pose.trunk) {
      final v when v >= 1 => _trunkCurl(v - 1),
      final v => (
        Offset(100, 118 - v * 10),
        Offset(lerpDouble(98, 118, max(0, v))!, lerpDouble(150, 112, (v + 1) / 2)!),
        Offset(lerpDouble(94, 132, max(0, v))!, lerpDouble(160, 92, (v + 1) / 2)!),
      ),
    };
    final trunk = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
    canvas.drawPath(
      trunk,
      Paint()
        ..color = _skin
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round,
    );
    for (final metric in trunk.computeMetrics()) {
      for (var d = 18.0; d < metric.length - 8; d += 9) {
        final tangent = metric.getTangentForOffset(d)!;
        final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
        canvas.drawLine(
          tangent.position - normal * 6,
          tangent.position + normal * 6,
          Paint()
            ..color = _skinDark
            ..strokeWidth = 1.6,
        );
      }
    }
    canvas.drawCircle(end, 9, Paint()..color = _skinDark);

    // Yeux et sourcils.
    for (final side in [-1.0, 1.0]) {
      final center = Offset(100 + side * 20, 84);
      if (pose.eyes > 0.5) {
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - 8, center.dy + 2)
            ..quadraticBezierTo(center.dx, center.dy - 9, center.dx + 8, center.dy + 2),
          Paint()
            ..color = _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.4
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawOval(Rect.fromCenter(center: center, width: 18, height: 22), Paint()..color = Colors.white);
        final pupil = center + Offset(0, 2 - pose.lookUp * 6 + max(0, pose.brow) * 3);
        canvas.drawCircle(pupil, 6.5, Paint()..color = _ink);
        canvas.drawCircle(pupil + const Offset(-2, -2.5), 2, Paint()..color = Colors.white);
      }
      final browY = center.dy - 17;
      final inner = browY - pose.brow * 5;
      canvas.drawLine(
        Offset(center.dx - side * 9, inner),
        Offset(center.dx + side * 9, browY + pose.brow * 2),
        Paint()
          ..color = _skinDark
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round,
      );
    }

    // Petite larme quand il est déçu.
    if (pose.tear > 0.05) {
      final drop = Path()
        ..moveTo(78, 96)
        ..quadraticBezierTo(73, 106, 78, 109)
        ..quadraticBezierTo(83, 106, 78, 96);
      canvas.drawPath(drop, Paint()..color = const Color(0xFF5DADE2).withValues(alpha: pose.tear));
    }
  }

  /// Trompe levée (0) ou enroulée vers la tempe (1).
  static (Offset, Offset, Offset) _trunkCurl(double curl) => (
    Offset(lerpDouble(102, 112, curl)!, lerpDouble(108, 118, curl)!),
    Offset(lerpDouble(122, 150, curl)!, lerpDouble(112, 104, curl)!),
    Offset(lerpDouble(132, 140, curl)!, lerpDouble(92, 76, curl)!),
  );

  @override
  bool shouldRepaint(covariant _ElephantPainter old) => true;
}

/// Bulle de conseil de la mascotte, qui apparaît en glissant.
class MascotBubble extends StatelessWidget {
  const MascotBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(scale: t, alignment: Alignment.bottomLeft, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomRight: Radius.circular(14),
            bottomLeft: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.3)),
      ),
    );
  }
}
