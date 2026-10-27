import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Couleur des cauris, la monnaie du jeu.
const caurisColor = Color(0xFFB7791F);

/// Un cauri dessiné : coquillage ovale avec sa fente dentelée.
class CauriIcon extends StatelessWidget {
  const CauriIcon({super.key, this.size = 18});

  final double size;

  static const _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><g transform="rotate(-35 32 32)">'
      '<ellipse cx="32" cy="32" rx="20" ry="27" fill="#E9D3A6" stroke="#9A6516" stroke-width="3.5"/>'
      '<ellipse cx="25" cy="20" rx="6" ry="9" fill="#FFFFFF" fill-opacity="0.55"/>'
      '<path d="M32 9 C27 20 27 44 32 55 C37 44 37 20 32 9Z" fill="#6B4410"/>'
      '<path d="M28 17 h3 M27.3 23 h3.7 M27 29 h4 M27 35 h4 M27.3 41 h3.7 M28 47 h3 '
      'M33 17 h3 M33 23 h3.7 M33 29 h4 M33 35 h4 M33 41 h3.7 M33 47 h3" '
      'stroke="#E9D3A6" stroke-width="2.6" stroke-linecap="round"/></g></svg>';

  @override
  Widget build(BuildContext context) => SvgPicture.string(_svg, width: size, height: size);
}

/// Pastille « cauri 25 ».
class CauriPill extends StatelessWidget {
  const CauriPill({super.key, required this.cauris});

  final int cauris;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$cauris cauris',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: caurisColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CauriIcon(size: 16),
            const SizedBox(width: 4),
            Text(
              '$cauris',
              style: const TextStyle(color: caurisColor, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Étoiles d'un niveau (0 à 3).
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 14});

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i < stars ? const Color(0xFFF5B301) : const Color(0xFFB8B3C7),
          ),
      ],
    );
  }
}
