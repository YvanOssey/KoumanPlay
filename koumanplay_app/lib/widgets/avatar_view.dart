import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/avatar.dart';

/// Avatar du joueur, dessiné en SVG sur une toile 512 × 512 et découpé en rond.
class AvatarView extends StatelessWidget {
  const AvatarView({super.key, required this.config, this.size = 72});

  final AvatarConfig config;
  final double size;

  static final _cache = <String, String>{};

  @override
  Widget build(BuildContext context) {
    final svg = _cache.putIfAbsent(config.key, () => avatarSvg(config));
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: SvgPicture.string(svg, width: size, height: size),
      ),
    );
  }
}

// Pièces dessinées. Ordre des calques : fond, cheveux arrière, tenue, cou,
// tête, visage, cheveux avant, accessoires. Chaque pièce peut être redessinée
// indépendamment (par exemple par un illustrateur), tant qu'elle reste sur la
// même toile 512 × 512.

const _skins = {
  'ebene': ('#4A2C1D', '#3A2116'),
  'cacao': ('#6B3E26', '#57301D'),
  'caramel': ('#8D5524', '#74441B'),
  'miel': ('#A86B3C', '#8E5730'),
  'sable': ('#C68642', '#A86F35'),
};
const _hairColor = '#1C1210';

String avatarSvg(AvatarConfig c) {
  final (back, front) = _hair(c.hair);
  final accessories = [
    if (c.accessories.contains('boucles')) _earrings(),
    if (c.accessories.contains('collier')) _necklace(),
    if (c.accessories.contains('lunettes')) _glasses(),
  ].join();
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">'
      '${_background(c.background)}$back${_outfit(c.outfit)}${_neck(c.skin)}${_head(c.skin)}'
      '${_face(c.skin, lashes: c.lashes)}$front$accessories</svg>';
}

// ---------------------------------------------------------------- Fonds

String _sky(String top, String bottom) =>
    '<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">'
    '<stop offset="0" stop-color="$top"/><stop offset="1" stop-color="$bottom"/></linearGradient></defs>'
    '<rect width="512" height="512" fill="url(#sky)"/>';

String _background(String id) => switch (id) {
  'plateau' =>
    _sky('#5B2EFF', '#B9A6FF') +
        [
              (30, 210, 60, '#7C6BD6'),
              (100, 160, 50, '#9486E3'),
              (360, 180, 55, '#7C6BD6'),
              (425, 230, 60, '#9486E3'),
              (160, 260, 40, '#A99DEB'),
              (318, 250, 40, '#A99DEB'),
            ]
            .map((t) => '<rect x="${t.$1}" y="${t.$2}" width="${t.$3}" height="${512 - t.$2}" rx="4" fill="${t.$4}"/>')
            .join(),
  'lagune' =>
    '${_sky('#9FE3F2', '#E8FAFF')}'
        '<path d="M0 330 Q130 310 256 330 T512 330 V512 H0Z" fill="#2BA9C9"/>'
        '<path d="M60 330 q10 -90 -20 -150" stroke="#6B4A2B" stroke-width="10" fill="none"/>'
        '<path d="M40 180 q40 -30 80 0 M40 180 q-30 -35 -60 -10 M40 180 q10 -45 55 -55" '
        'stroke="#2F8F4E" stroke-width="12" fill="none" stroke-linecap="round"/>',
  _ =>
    '${_sky('#FDE7B0', '#F6C770')}'
        '<circle cx="390" cy="130" r="38" fill="#FFF3D1"/>'
        '<path d="M0 360 Q120 300 250 345 T512 330 V512 H0Z" fill="#9BC57A"/>'
        '<path d="M40 360 l45 -45 l45 45z" fill="#8A5A2B"/><rect x="52" y="360" width="66" height="40" fill="#C98E55"/>'
        '<path d="M400 350 l40 -40 l40 40z" fill="#8A5A2B"/><rect x="410" y="350" width="60" height="36" fill="#C98E55"/>',
};

// ---------------------------------------------------------------- Tenues

const _torso = 'M86 512 C96 420 160 382 214 372 L298 372 C352 382 416 420 426 512Z';

/// Motif d'un tissu, en tuiles répétées sur la zone du buste.
String _fabric(String id) {
  final b = StringBuffer();
  switch (id) {
    case 'kita':
      for (var y = 360; y < 512; y += 48) {
        for (var x = 80; x < 432; x += 48) {
          b.write(
            '<rect x="$x" y="$y" width="48" height="48" fill="#E0A800"/>'
            '<rect x="$x" y="$y" width="48" height="10" fill="#1F7A3E"/>'
            '<rect x="$x" y="${y + 22}" width="48" height="6" fill="#B3261E"/>'
            '<rect x="$x" y="${y + 34}" width="24" height="14" fill="#1C1210"/>'
            '<rect x="${x + 24}" y="${y + 10}" width="24" height="12" fill="#1C1210"/>',
          );
        }
      }
    case 'wax':
      b.write('<rect x="80" y="360" width="352" height="152" fill="#E8590C"/>');
      for (var y = 360; y < 512; y += 56) {
        for (var x = 80; x < 432; x += 56) {
          b.write(
            '<circle cx="${x + 14}" cy="${y + 14}" r="11" fill="#FFD43B"/><circle cx="${x + 14}" cy="${y + 14}" r="5" fill="#5B2EFF"/>'
            '<circle cx="${x + 42}" cy="${y + 42}" r="11" fill="#2B8A3E"/><circle cx="${x + 42}" cy="${y + 42}" r="5" fill="#FFD43B"/>',
          );
        }
      }
    case 'bogolan':
      b.write('<rect x="80" y="360" width="352" height="152" fill="#5C3A21"/>');
      for (var y = 360; y < 512; y += 40) {
        b.write('<rect x="80" y="${y + 19}" width="352" height="3" fill="#EAD7B7"/>');
        for (var x = 80; x < 432; x += 40) {
          b.write(
            '<rect x="${x + 19}" y="$y" width="3" height="40" fill="#EAD7B7"/>'
            '<circle cx="${x + 10}" cy="${y + 10}" r="3" fill="#EAD7B7"/><circle cx="${x + 30}" cy="${y + 30}" r="3" fill="#EAD7B7"/>',
          );
        }
      }
    case 'uni-violet':
      b.write('<rect x="80" y="360" width="352" height="152" fill="#5B2EFF"/>');
    default:
      b.write('<rect x="80" y="360" width="352" height="152" fill="#1F7A3E"/>');
  }
  return b.toString();
}

String _outfit(String id) =>
    '<defs><clipPath id="torso"><path d="$_torso"/></clipPath></defs>'
    '<g clip-path="url(#torso)">${_fabric(id)}</g>'
    '<path d="M214 372 Q256 420 298 372" fill="none" stroke="#FFFFFF" stroke-width="10" stroke-linecap="round"/>';

// ---------------------------------------------------------------- Corps et visage

String _neck(String skin) => '<path d="M222 318 L222 380 Q256 404 290 380 L290 318Z" fill="${_skins[skin]!.$2}"/>';

String _head(String skin) {
  final (base, shade) = _skins[skin]!;
  return '<ellipse cx="158" cy="250" rx="18" ry="26" fill="$shade"/><ellipse cx="354" cy="250" rx="18" ry="26" fill="$shade"/>'
      '<path d="M256 128 C330 128 360 182 358 250 C356 318 312 362 256 362 C200 362 156 318 154 250 C152 182 182 128 256 128Z" fill="$base"/>';
}

String _face(String skin, {required bool lashes}) {
  final shade = _skins[skin]!.$2;
  final lash = lashes
      ? '<path d="M204 234 l-8 -6 M212 230 l-4 -8 M300 234 l8 -6 M292 230 l4 -8" stroke="#1C1210" stroke-width="3" stroke-linecap="round"/>'
      : '';
  return '$lash'
      '<path d="M196 212 Q216 200 236 210" fill="none" stroke="#1C1210" stroke-width="7" stroke-linecap="round"/>'
      '<path d="M276 210 Q296 200 316 212" fill="none" stroke="#1C1210" stroke-width="7" stroke-linecap="round"/>'
      '<ellipse cx="216" cy="244" rx="17" ry="13" fill="#FFFFFF"/><ellipse cx="296" cy="244" rx="17" ry="13" fill="#FFFFFF"/>'
      '<circle cx="218" cy="245" r="9" fill="#2A1A12"/><circle cx="298" cy="245" r="9" fill="#2A1A12"/>'
      '<circle cx="221" cy="241" r="3" fill="#FFFFFF"/><circle cx="301" cy="241" r="3" fill="#FFFFFF"/>'
      '<path d="M248 262 Q256 284 246 288 Q256 294 266 288" fill="none" stroke="$shade" stroke-width="6" stroke-linecap="round"/>'
      '<ellipse cx="190" cy="284" rx="16" ry="9" fill="#E8757A" fill-opacity="0.25"/>'
      '<ellipse cx="322" cy="284" rx="16" ry="9" fill="#E8757A" fill-opacity="0.25"/>'
      '<path d="M226 300 Q256 330 286 300 Q256 312 226 300Z" fill="#7A1F1F"/><path d="M234 303 Q256 313 278 303" fill="#FFFFFF"/>';
}

// ---------------------------------------------------------------- Coiffures : (arrière, avant)

(String, String) _hair(String id) => switch (id) {
  'afro' => (
    [
      (256, 150, 120),
      (160, 190, 70),
      (352, 190, 70),
      (190, 110, 70),
      (322, 110, 70),
      (256, 80, 70),
      (150, 250, 50),
      (362, 250, 50),
    ].map((p) => '<circle cx="${p.$1}" cy="${p.$2}" r="${p.$3}" fill="$_hairColor"/>').join(),
    '<path d="M160 214 C170 150 220 132 256 132 C292 132 342 150 352 214 C330 176 290 166 256 168 C222 166 182 176 160 214Z" fill="$_hairColor"/>',
  ),
  'tresses' => (
    [168, 186, 326, 344]
        .map(
          (x) =>
              '<path d="M$x 200 Q${x < 256 ? x - 6 : x + 6} 320 $x 420" stroke="$_hairColor" stroke-width="16" fill="none" stroke-linecap="round"/>'
              '<circle cx="$x" cy="424" r="8" fill="#D4A017"/>',
        )
        .join(),
    '<path d="M154 236 C150 150 210 120 256 120 C302 120 362 150 358 236 C340 180 300 160 256 160 C212 160 172 180 154 236Z" fill="$_hairColor"/>'
        '${[for (var x = 196; x < 330; x += 22) '<path d="M$x 128 Q${x + 4} 150 $x 168" stroke="#3A2A24" stroke-width="3" fill="none"/>'].join()}',
  ),
  'bantu' => (
    '',
    '<path d="M156 226 C156 168 206 140 256 140 C306 140 356 168 356 226 C338 190 300 176 256 176 C212 176 174 190 156 226Z" fill="$_hairColor"/>'
        '${[(196, 150), (256, 122), (316, 150), (174, 200), (338, 200)].map((p) => '<circle cx="${p.$1}" cy="${p.$2}" r="22" fill="$_hairColor"/>'
            '<path d="M${p.$1 - 10} ${p.$2} q10 -12 20 0" stroke="#3A2A24" stroke-width="3" fill="none"/>').join()}',
  ),
  'foulard' => _headscarf('#5B2EFF', '#D4A017'),
  'foulard-rouge' => _headscarf('#B3261E', '#FFD43B'),
  _ => (
    '',
    '<path d="M156 222 C152 160 204 130 256 130 C308 130 360 160 356 222 C346 188 306 168 256 168 C206 168 166 188 156 222Z" fill="$_hairColor"/>',
  ),
};

(String, String) _headscarf(String color, String motif) => (
  '<ellipse cx="256" cy="150" rx="132" ry="96" fill="$color"/>',
  '<path d="M150 230 C140 120 210 70 256 70 C302 70 372 120 362 230 C340 170 300 150 256 150 C212 150 172 170 150 230Z" fill="$color"/>'
      '<path d="M170 150 Q256 110 342 150" stroke="$motif" stroke-width="8" fill="none"/>'
      '<path d="M186 118 Q256 84 326 118" stroke="$motif" stroke-width="4" fill="none"/>'
      '<path d="M300 82 q46 -36 70 6 q-34 4 -50 26z" fill="$color"/><path d="M300 82 q-10 -46 -54 -38 q18 26 22 48z" fill="$color"/>',
);

// ---------------------------------------------------------------- Accessoires

String _earrings() =>
    '<circle cx="158" cy="282" r="9" fill="none" stroke="#D4A017" stroke-width="5"/>'
    '<circle cx="354" cy="282" r="9" fill="none" stroke="#D4A017" stroke-width="5"/>';

String _necklace() {
  const colors = ['#D4A017', '#B3261E', '#D4A017', '#1F7A3E'];
  final b = StringBuffer();
  for (var t = -14, i = 0; t <= 14; t += 2, i++) {
    final x = 256 + 70 * sin(t / 10), y = 388 + 26 * cos(t / 10);
    b.write('<circle cx="${x.toStringAsFixed(1)}" cy="${y.toStringAsFixed(1)}" r="7" fill="${colors[i % 4]}"/>');
  }
  return b.toString();
}

String _glasses() =>
    '<rect x="186" y="224" width="60" height="42" rx="14" fill="#FFFFFF" fill-opacity="0.15" stroke="#1C1210" stroke-width="6"/>'
    '<rect x="266" y="224" width="60" height="42" rx="14" fill="#FFFFFF" fill-opacity="0.15" stroke="#1C1210" stroke-width="6"/>'
    '<path d="M246 240 h20" stroke="#1C1210" stroke-width="6"/>';
