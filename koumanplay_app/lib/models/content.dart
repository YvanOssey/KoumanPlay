/// Contenu culturel : langues (étapes de la carte), niveaux, mots/phrases,
/// proverbes et défis. Chargé depuis assets/content (hors-ligne) ou Supabase.
library;

/// Une étape de la carte = une langue.
class Language {
  const Language({
    required this.id,
    required this.name,
    required this.group,
    required this.region,
    required this.color,
  });

  final String id;
  final String name;

  /// Grand groupe culturel (Akan, Krou, Mandé, Gour).
  final String group;
  final String region;
  final int color;

  factory Language.fromJson(Map<String, dynamic> json) => Language(
        id: json['id'] as String,
        name: json['name'] as String,
        group: json['group'] as String? ?? '',
        region: json['region'] as String? ?? '',
        color: _parseColor(json['color'] as String? ?? '#5B2EFF'),
      );
}

enum LevelKind { mots, phrases, proverbes }

class Level {
  const Level({
    required this.id,
    required this.languageId,
    required this.order,
    required this.title,
    required this.kind,
    required this.passRatio,
  });

  final String id;
  final String languageId;
  final int order;
  final String title;
  final LevelKind kind;
  final double passRatio;

  String get kindLabel => switch (kind) {
        LevelKind.mots => 'Mots',
        LevelKind.phrases => 'Phrases',
        LevelKind.proverbes => 'Proverbes',
      };

  factory Level.fromJson(Map<String, dynamic> json) => Level(
        id: json['id'] as String,
        languageId: json['languageId'] as String,
        order: json['order'] as int,
        title: json['title'] as String,
        kind: LevelKind.values.asNameMap()[json['kind']] ?? LevelKind.mots,
        passRatio: (json['passRatio'] as num?)?.toDouble() ?? 0.6,
      );
}

/// Ce qui rapporte de l'XP dans un niveau : un mot/une phrase ou un proverbe.
abstract class LessonItem {
  String get id;
  String get levelId;
  int get xp;
}

/// Mot ou phrase à apprendre. Les questions sont générées automatiquement
/// (traduire dans un sens ou dans l'autre, 4 choix).
class Word implements LessonItem {
  const Word({
    required this.id,
    required this.levelId,
    required this.french,
    required this.local,
    this.pronunciation,
    this.audio,
    this.xp = 10,
    this.validated = false,
  });

  @override
  final String id;
  @override
  final String levelId;
  final String french;
  final String local;
  final String? pronunciation;

  /// URL (Supabase Storage) ou chemin d'asset d'un enregistrement.
  final String? audio;
  @override
  final int xp;
  final bool validated;

  factory Word.fromJson(Map<String, dynamic> json) => Word(
        id: json['id'] as String,
        levelId: json['levelId'] as String,
        french: json['french'] as String,
        local: json['local'] as String,
        pronunciation: json['pronunciation'] as String?,
        audio: json['audio'] as String?,
        xp: json['xp'] as int? ?? 10,
        validated: json['validated'] as bool? ?? false,
      );
}

/// Proverbe : question à choix multiple écrite à la main.
class Activity implements LessonItem {
  const Activity({
    required this.id,
    required this.levelId,
    required this.proverb,
    required this.question,
    required this.answers,
    required this.correct,
    required this.explanation,
    required this.xp,
    this.original,
    this.language,
    this.audio,
    this.validated = false,
  });

  @override
  final String id;
  @override
  final String levelId;
  final String proverb;
  final String? original;
  final String? language;
  final String question;
  final List<String> answers;
  final int correct;
  final String explanation;
  final String? audio;
  @override
  final int xp;
  final bool validated;

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        id: json['id'] as String,
        levelId: json['levelId'] as String,
        proverb: json['proverb'] as String,
        original: json['original'] as String?,
        language: json['language'] as String?,
        question: json['question'] as String,
        answers: (json['answers'] as List).cast<String>(),
        correct: json['correct'] as int,
        explanation: json['explanation'] as String? ?? '',
        audio: json['audio'] as String?,
        xp: json['xp'] as int? ?? 20,
        validated: json['validated'] as bool? ?? false,
      );
}

class Challenge {
  const Challenge({
    required this.id,
    required this.role,
    required this.title,
    required this.description,
    required this.rewardXp,
    required this.durationMin,
    required this.difficulty,
    required this.steps,
    required this.notePrompt,
    this.unlockAfterLevel,
  });

  final String id;

  /// 'jeune', 'senior' ou 'all'.
  final String role;
  final String? unlockAfterLevel;
  final String title;
  final String description;
  final int rewardXp;
  final int durationMin;
  final String difficulty;
  final List<String> steps;
  final String notePrompt;

  bool isFor(String playerRole) => role == 'all' || role == playerRole;

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
        id: json['id'] as String,
        role: json['role'] as String? ?? 'all',
        unlockAfterLevel: json['unlockAfterLevel'] as String?,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        rewardXp: json['rewardXp'] as int? ?? 100,
        durationMin: json['durationMin'] as int? ?? 15,
        difficulty: json['difficulty'] as String? ?? 'Facile',
        steps: (json['steps'] as List).cast<String>(),
        notePrompt: json['notePrompt'] as String? ?? 'Ce que tu as appris',
      );
}

class ContentPack {
  ContentPack({
    required this.version,
    required this.languages,
    required this.levels,
    required this.words,
    required this.activities,
    required this.challenges,
  });

  /// Nombre minimum de mots pour générer des questions à 4 choix.
  static const minWordsPerLevel = 4;

  final int version;
  final List<Language> languages;
  final List<Level> levels;
  final List<Word> words;
  final List<Activity> activities;
  final List<Challenge> challenges;

  factory ContentPack.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) =>
        (json[key] as List? ?? const []).map((e) => parse(e as Map<String, dynamic>)).toList();
    return ContentPack(
      version: json['version'] as int? ?? 1,
      languages: list('languages', Language.fromJson),
      levels: list('levels', Level.fromJson)..sort((a, b) => a.order.compareTo(b.order)),
      words: list('words', Word.fromJson),
      activities: list('activities', Activity.fromJson),
      challenges: list('challenges', Challenge.fromJson),
    );
  }

  List<Level> levelsOf(String languageId) => levels.where((l) => l.languageId == languageId).toList();

  List<Word> wordsOf(String levelId) => words.where((w) => w.levelId == levelId).toList();

  List<Activity> activitiesOf(String levelId) => activities.where((a) => a.levelId == levelId).toList();

  List<LessonItem> itemsOf(String levelId) {
    final level = this.level(levelId);
    if (level == null) return const [];
    return level.kind == LevelKind.proverbes ? activitiesOf(levelId) : wordsOf(levelId);
  }

  /// Un niveau sans contenu suffisant est affiché « en préparation ».
  bool isPlayable(Level level) => level.kind == LevelKind.proverbes
      ? activitiesOf(level.id).isNotEmpty
      : wordsOf(level.id).length >= minWordsPerLevel;

  List<Level> playableLevelsOf(String languageId) => levelsOf(languageId).where(isPlayable).toList();

  Level? level(String id) => _firstWhereOrNull(levels, (l) => l.id == id);

  Language? language(String id) => _firstWhereOrNull(languages, (l) => l.id == id);

  Challenge? challenge(String id) => _firstWhereOrNull(challenges, (c) => c.id == id);
}

T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

int _parseColor(String hex) {
  final value = hex.replaceFirst('#', '');
  return int.parse(value.length == 6 ? 'FF$value' : value, radix: 16);
}
