/// Ce qu'un aîné transmet depuis l'app : un mot, un proverbe ou un conte,
/// enregistré à la voix. Envoyé à Supabase, vérifié par l'équipe, puis
/// ajouté au jeu.
library;

enum ContributionKind { mot, proverbe, conte }

enum ContributionStatus {
  /// Enregistré sur le téléphone, pas encore envoyé (pas de réseau).
  aEnvoyer('a_envoyer', 'En attente d\'envoi'),
  enVerification('en_verification', 'En vérification'),
  publie('publie', 'Publié dans le jeu'),
  refuse('refuse', 'Non retenu');

  const ContributionStatus(this.code, this.label);

  /// Valeur de la colonne `status` dans Supabase.
  final String code;
  final String label;

  static ContributionStatus fromCode(String? code) =>
      values.firstWhere((s) => s.code == code, orElse: () => ContributionStatus.enVerification);
}

class Contribution {
  const Contribution({
    required this.id,
    required this.kind,
    required this.languageId,
    required this.audioPaths,
    required this.createdAt,
    required this.status,
    this.promptId,
    this.promptFrench,
    this.text,
  });

  final String id;
  final ContributionKind kind;
  final String languageId;

  /// Mot demandé (ex. « 1-04 », « Merci ») pour les transmissions de mots.
  final String? promptId;
  final String? promptFrench;

  /// Texte facultatif : traduction d'un proverbe, titre d'un conte.
  final String? text;

  /// Enregistrements sur le téléphone : un pour un mot ou un conte, deux pour
  /// un proverbe (le proverbe, puis son explication).
  final List<String> audioPaths;
  final DateTime createdAt;
  final ContributionStatus status;

  Contribution copyWith({ContributionStatus? status}) => Contribution(
        id: id,
        kind: kind,
        languageId: languageId,
        audioPaths: audioPaths,
        createdAt: createdAt,
        status: status ?? this.status,
        promptId: promptId,
        promptFrench: promptFrench,
        text: text,
      );

  String get title => switch (kind) {
        ContributionKind.mot => promptFrench ?? 'Mot',
        ContributionKind.proverbe => text?.isNotEmpty ?? false ? text! : 'Proverbe',
        ContributionKind.conte => text?.isNotEmpty ?? false ? text! : 'Conte',
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'languageId': languageId,
        'promptId': promptId,
        'promptFrench': promptFrench,
        'text': text,
        'audioPaths': audioPaths,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'status': status.code,
      };

  factory Contribution.fromJson(Map<String, dynamic> json) => Contribution(
        id: json['id'] as String,
        kind: ContributionKind.values.byName(json['kind'] as String),
        languageId: json['languageId'] as String,
        promptId: json['promptId'] as String?,
        promptFrench: json['promptFrench'] as String?,
        text: json['text'] as String?,
        audioPaths: ((json['audioPaths'] as List?) ?? const []).cast<String>(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        status: ContributionStatus.fromCode(json['status'] as String?),
      );
}

/// Mot ou phrase que l'app demande à l'aîné de dire dans sa langue. Même
/// liste que content/collecte_mots.csv et la fiche de collecte papier.
class CollectPrompt {
  const CollectPrompt(this.id, this.level, this.french);

  /// « niveau-numéro », ex. « 1-04 ». L'id du mot dans le jeu sera
  /// « `langue-id` » (ex. « baoule-1-04 »).
  final String id;
  final int level;
  final String french;
}

const collectPrompts = <CollectPrompt>[
  CollectPrompt('1-01', 1, 'Bonjour (le matin)'),
  CollectPrompt('1-02', 1, 'Bonsoir'),
  CollectPrompt('1-03', 1, 'Bienvenue'),
  CollectPrompt('1-04', 1, 'Merci'),
  CollectPrompt('1-05', 1, 'Au revoir'),
  CollectPrompt('1-06', 1, 'Comment ça va ?'),
  CollectPrompt('1-07', 1, 'Ça va bien'),
  CollectPrompt('1-08', 1, 'Oui'),
  CollectPrompt('1-09', 1, 'Non'),
  CollectPrompt('2-01', 2, 'Père'),
  CollectPrompt('2-02', 2, 'Mère'),
  CollectPrompt('2-03', 2, 'Frère'),
  CollectPrompt('2-04', 2, 'Sœur'),
  CollectPrompt('2-05', 2, 'Grand-père'),
  CollectPrompt('2-06', 2, 'Grand-mère'),
  CollectPrompt('2-07', 2, 'Enfant'),
  CollectPrompt('2-08', 2, 'Ami'),
  CollectPrompt('2-09', 2, 'Mari'),
  CollectPrompt('2-10', 2, 'Femme (épouse)'),
  CollectPrompt('3-01', 3, 'Un'),
  CollectPrompt('3-02', 3, 'Deux'),
  CollectPrompt('3-03', 3, 'Trois'),
  CollectPrompt('3-04', 3, 'Quatre'),
  CollectPrompt('3-05', 3, 'Cinq'),
  CollectPrompt('3-06', 3, 'Six'),
  CollectPrompt('3-07', 3, 'Sept'),
  CollectPrompt('3-08', 3, 'Huit'),
  CollectPrompt('3-09', 3, 'Neuf'),
  CollectPrompt('3-10', 3, 'Dix'),
  CollectPrompt('4-01', 4, 'Je m\'appelle …'),
  CollectPrompt('4-02', 4, 'Comment t\'appelles-tu ?'),
  CollectPrompt('4-03', 4, 'J\'ai … ans'),
  CollectPrompt('4-04', 4, 'Je viens de …'),
  CollectPrompt('4-05', 4, 'Où habites-tu ?'),
  CollectPrompt('4-06', 4, 'Je suis content de te voir'),
  CollectPrompt('5-01', 5, 'J\'ai faim'),
  CollectPrompt('5-02', 5, 'Viens manger'),
  CollectPrompt('5-03', 5, 'Combien ça coûte ?'),
  CollectPrompt('5-04', 5, 'C\'est trop cher'),
  CollectPrompt('5-05', 5, 'Je ne comprends pas'),
  CollectPrompt('5-06', 5, 'Répète, s\'il te plaît'),
  CollectPrompt('5-07', 5, 'Bonne nuit'),
];
