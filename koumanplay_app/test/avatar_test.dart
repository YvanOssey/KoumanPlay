import 'package:flutter_test/flutter_test.dart';
import 'package:koumanplay/models/avatar.dart';
import 'package:koumanplay/models/player.dart';
import 'package:koumanplay/widgets/avatar_view.dart';

void main() {
  test("sans avatar choisi, le jeune et l'aîné ont chacun un avatar de départ", () {
    final young = PlayerState.initial();
    expect(young.avatar, isNull);
    expect(young.avatarOrDefault.key, AvatarConfig.youngDefault.key);
    expect(young.copyWith(role: 'senior').avatarOrDefault.key, AvatarConfig.elderDefault.key);
  });

  test("l'avatar survit à la sauvegarde du joueur", () {
    const avatar = AvatarConfig(
      skin: 'ebene',
      hair: 'tresses',
      outfit: 'bogolan',
      background: 'lagune',
      accessories: {'boucles'},
      lashes: true,
    );
    final restored = PlayerState.fromJson(PlayerState.initial().copyWith(avatar: avatar).toJson());
    expect(restored.avatar?.key, avatar.key);
  });

  test('une pièce retirée du catalogue revient à la valeur par défaut', () {
    final avatar = AvatarConfig.fromJson({
      'skin': 'inconnu',
      'hair': 'afro',
      'accessories': ['lunettes', 'chapeau'],
    });
    expect(avatar.skin, 'cacao');
    expect(avatar.hair, 'afro');
    expect(avatar.accessories, {'lunettes'});
  });

  test('chaque combinaison du catalogue donne un dessin SVG complet', () {
    for (final skin in AvatarConfig.skins.keys) {
      for (final hair in AvatarConfig.hairs.keys) {
        for (final outfit in AvatarConfig.outfits.keys) {
          for (final background in AvatarConfig.backgrounds.keys) {
            final svg = avatarSvg(
              AvatarConfig(
                skin: skin,
                hair: hair,
                outfit: outfit,
                background: background,
                accessories: AvatarConfig.accessoryNames.keys.toSet(),
              ),
            );
            expect(svg, startsWith('<svg'));
            expect(svg, endsWith('</svg>'));
            expect(svg, isNot(contains('null')));
          }
        }
      }
    }
  });
}
