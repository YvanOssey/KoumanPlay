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

/// `tresors` : questions sur les œuvres de la Bibliothèque.
enum LevelKind { mots, phrases, proverbes, tresors }

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
        LevelKind.tresors => 'Trésors',
      };

  /// Proverbes et trésors : questions écrites à la main (activities) ;
  /// mots et phrases : questions générées à partir des mots collectés.
  bool get hasActivities => kind == LevelKind.proverbes || kind == LevelKind.tresors;

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

/// Œuvre de la bibliothèque culturelle (masque, statue, pagne, instrument…),
/// fournie par une structure partenaire.
class CulturalWork {
  const CulturalWork({
    required this.id,
    required this.title,
    required this.kind,
    required this.description,
    this.people,
    this.region,
    this.period,
    this.museum,
    this.city,
    this.address,
    this.imageUrl,
    this.link,
  });

  final String id;
  final String title;

  /// Type d'œuvre : « Masque », « Statue », « Textile »…
  final String kind;
  final String description;

  /// Peuple ou groupe culturel d'origine.
  final String? people;
  final String? region;
  final String? period;

  /// Où la voir.
  final String? museum;
  final String? city;
  final String? address;
  final String? imageUrl;
  final String? link;

  /// Texte sur lequel porte la recherche.
  String get searchText => [title, kind, people, region, museum, city].whereType<String>().join(' ').toLowerCase();

  factory CulturalWork.fromJson(Map<String, dynamic> json) => CulturalWork(
        id: json['id'] as String,
        title: json['title'] as String,
        kind: json['kind'] as String? ?? 'Œuvre',
        description: json['description'] as String? ?? '',
        people: json['people'] as String?,
        region: json['region'] as String?,
        period: json['period'] as String?,
        museum: json['museum'] as String?,
        city: json['city'] as String?,
        address: json['address'] as String?,
        imageUrl: json['imageUrl'] as String?,
        link: json['link'] as String?,
      );
}

/// Événement culturel publié par une structure partenaire.
class CultureEvent {
  const CultureEvent({
    required this.id,
    required this.title,
    required this.organizer,
    required this.description,
    required this.startsAt,
    this.endsAt,
    this.place,
    this.city,
    this.imageUrl,
    this.link,
    this.minDiamonds,
  });

  final String id;
  final String title;
  final String organizer;
  final String description;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? place;
  final String? city;
  final String? imageUrl;
  final String? link;

  /// Diamants demandés pour cet événement ; sinon le seuil général.
  final int? minDiamonds;

  /// Terminé depuis plus d'un jour.
  bool isPast(DateTime now) => (endsAt ?? startsAt).isBefore(now.subtract(const Duration(days: 1)));

  factory CultureEvent.fromJson(Map<String, dynamic> json) => CultureEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        organizer: json['organizer'] as String? ?? '',
        description: json['description'] as String? ?? '',
        startsAt: DateTime.parse(json['startsAt'] as String).toLocal(),
        endsAt: DateTime.tryParse(json['endsAt'] as String? ?? '')?.toLocal(),
        place: json['place'] as String?,
        city: json['city'] as String?,
        imageUrl: json['imageUrl'] as String?,
        link: json['link'] as String?,
        minDiamonds: json['minDiamonds'] as int?,
      );
}

/// Réglages modifiables depuis Supabase, sans nouvelle version de l'app.
class AppSettings {
  const AppSettings({this.eventMinDiamonds = 3, this.eventMinLevel = 2});

  /// Seuils pour pouvoir participer à un événement culturel.
  final int eventMinDiamonds;
  final int eventMinLevel;

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        eventMinDiamonds: json['eventMinDiamonds'] as int? ?? 3,
        eventMinLevel: json['eventMinLevel'] as int? ?? 2,
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
    this.works = const [],
    this.events = const [],
    this.settings = const AppSettings(),
  });

  /// Nombre minimum de mots pour générer des questions à 4 choix.
  static const minWordsPerLevel = 4;

  final int version;
  final List<Language> languages;
  final List<Level> levels;
  final List<Word> words;
  final List<Activity> activities;
  final List<Challenge> challenges;
  final List<CulturalWork> works;

  /// Triés par date de début.
  final List<CultureEvent> events;
  final AppSettings settings;

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
      works: list('works', CulturalWork.fromJson),
      events: list('events', CultureEvent.fromJson)..sort((a, b) => a.startsAt.compareTo(b.startsAt)),
      settings: AppSettings.fromJson((json['settings'] as Map?)?.cast<String, dynamic>() ?? const {}),
    );
  }

  List<Level> levelsOf(String languageId) => levels.where((l) => l.languageId == languageId).toList();

  List<Word> wordsOf(String levelId) => words.where((w) => w.levelId == levelId).toList();

  List<Activity> activitiesOf(String levelId) => activities.where((a) => a.levelId == levelId).toList();

  List<LessonItem> itemsOf(String levelId) {
    final level = this.level(levelId);
    if (level == null) return const [];
    return level.hasActivities ? activitiesOf(levelId) : wordsOf(levelId);
  }

  /// Un niveau sans contenu suffisant est affiché « en préparation ».
  bool isPlayable(Level level) => level.hasActivities
      ? activitiesOf(level.id).isNotEmpty
      : wordsOf(level.id).length >= minWordsPerLevel;

  List<Level> playableLevelsOf(String languageId) => levelsOf(languageId).where(isPlayable).toList();

  Level? level(String id) => _firstWhereOrNull(levels, (l) => l.id == id);

  Language? language(String id) => _firstWhereOrNull(languages, (l) => l.id == id);

  Challenge? challenge(String id) => _firstWhereOrNull(challenges, (c) => c.id == id);

  CulturalWork? work(String id) => _firstWhereOrNull(works, (w) => w.id == id);

  CultureEvent? event(String id) => _firstWhereOrNull(events, (e) => e.id == id);
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
