/// Avatar du joueur : une combinaison de pièces dessinées (voir
/// widgets/avatar_view.dart). Les identifiants restent stables : un
/// illustrateur peut redessiner une pièce sans changer les profils enregistrés.
class AvatarConfig {
  const AvatarConfig({
    this.skin = 'cacao',
    this.hair = 'courts',
    this.outfit = 'kita',
    this.background = 'village',
    this.accessories = const {},
    this.lashes = false,
  });

  final String skin;
  final String hair;
  final String outfit;
  final String background;
  final Set<String> accessories;
  final bool lashes;

  // Catalogue : identifiant -> nom affiché dans l'éditeur.
  static const skins = {'ebene': 'Ébène', 'cacao': 'Cacao', 'caramel': 'Caramel', 'miel': 'Miel', 'sable': 'Sable'};
  static const hairs = {
    'courts': 'Courts',
    'afro': 'Afro',
    'tresses': 'Tresses',
    'bantu': 'Bantu knots',
    'foulard': 'Foulard violet',
    'foulard-rouge': 'Foulard rouge',
  };
  static const outfits = {
    'kita': 'Pagne kita',
    'wax': 'Wax',
    'bogolan': 'Bogolan',
    'uni-vert': 'Uni vert',
    'uni-violet': 'Uni violet',
  };
  static const backgrounds = {'village': 'Village', 'plateau': 'Plateau', 'lagune': 'Lagune'};
  static const accessoryNames = {
    'boucles': 'Boucles d\'oreilles',
    'collier': 'Collier de perles',
    'lunettes': 'Lunettes',
  };

  /// Pièces à débloquer en cauris (« type:id ») ; les autres sont gratuites.
  static const prices = {
    'hair:foulard-rouge': 30,
    'outfit:wax': 40,
    'outfit:bogolan': 60,
    'background:plateau': 30,
    'background:lagune': 30,
    'accessory:boucles': 20,
    'accessory:collier': 25,
  };

  static int priceOf(String item) => prices[item] ?? 0;

  /// Pièces utilisées par cet avatar, au format « type:id ».
  Set<String> get items => {
    'skin:$skin',
    'hair:$hair',
    'outfit:$outfit',
    'background:$background',
    for (final a in accessories) 'accessory:$a',
  };

  /// Avatar de départ, avant que le joueur ne le personnalise.
  static const youngDefault = AvatarConfig();
  static const elderDefault = AvatarConfig(hair: 'foulard-rouge', accessories: {'collier', 'lunettes'});

  /// Clé unique d'une combinaison (cache du dessin).
  String get key => [skin, hair, outfit, background, (accessories.toList()..sort()).join('+'), lashes].join('|');

  AvatarConfig copyWith({
    String? skin,
    String? hair,
    String? outfit,
    String? background,
    Set<String>? accessories,
    bool? lashes,
  }) => AvatarConfig(
    skin: skin ?? this.skin,
    hair: hair ?? this.hair,
    outfit: outfit ?? this.outfit,
    background: background ?? this.background,
    accessories: accessories ?? this.accessories,
    lashes: lashes ?? this.lashes,
  );

  Map<String, dynamic> toJson() => {
    'skin': skin,
    'hair': hair,
    'outfit': outfit,
    'background': background,
    'accessories': accessories.toList(),
    'lashes': lashes,
  };

  /// Une pièce inconnue (retirée du catalogue) revient à la valeur par défaut.
  factory AvatarConfig.fromJson(Map<String, dynamic> json) {
    String pick(String key, Map<String, String> catalog, String fallback) {
      final value = json[key] as String?;
      return catalog.containsKey(value) ? value! : fallback;
    }

    return AvatarConfig(
      skin: pick('skin', skins, 'cacao'),
      hair: pick('hair', hairs, 'courts'),
      outfit: pick('outfit', outfits, 'kita'),
      background: pick('background', backgrounds, 'village'),
      accessories: ((json['accessories'] as List?) ?? const [])
          .cast<String>()
          .where(accessoryNames.containsKey)
          .toSet(),
      lashes: json['lashes'] as bool? ?? false,
    );
  }
}
