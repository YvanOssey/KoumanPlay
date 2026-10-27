import 'dart:math';

import '../models/content.dart';

/// Une question affichée dans l'écran de jeu, quel que soit le type de niveau.
class LessonQuestion {
  const LessonQuestion({
    required this.itemId,
    required this.instruction,
    required this.prompt,
    required this.answers,
    required this.correct,
    required this.explanation,
    required this.xp,
    this.subtitle,
    this.audio,
    this.isProverb = false,
    this.isRecall = false,
    this.expected,
  });

  final String itemId;

  /// Consigne, ex. « Comment dit-on en Baoulé ? ».
  final String instruction;

  /// Texte mis en avant : le mot, la phrase ou le proverbe.
  final String prompt;
  final String? subtitle;
  final String? audio;
  final List<String> answers;
  final int correct;
  final String explanation;
  final int xp;
  final bool isProverb;

  /// Question de rappel (« Complète le proverbe ») sur un proverbe déjà vu
  /// dans le niveau : même [itemId], et le proverbe n'est réussi que si
  /// toutes ses questions le sont.
  final bool isRecall;

  /// Rappel : la fin du proverbe à écrire (pas de choix de réponses).
  final String? expected;
}

/// Vérifie une réponse écrite : sans tenir compte des majuscules, des accents,
/// de la ponctuation, et avec une petite faute de frappe permise.
class TypedAnswer {
  static const _accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'î': 'i', 'ï': 'i',
    'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c', 'œ': 'oe', 'æ': 'ae', 'ɔ': 'o', 'ɛ': 'e',
  };

  static String normalize(String text) {
    final lower = text.toLowerCase().replaceAll('’', "'");
    final plain = lower.split('').map((c) => _accents[c] ?? c).join();
    // Les apostrophes sont facultatives : beaucoup tapent « loeil » au téléphone.
    return plain.replaceAll("'", '').replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool matches(String typed, String expected) {
    final a = normalize(typed), b = normalize(expected);
    if (a.isEmpty) return false;
    if (a == b) return true;
    final allowed = b.length >= 16 ? 2 : (b.length >= 6 ? 1 : 0);
    return allowed > 0 && (a.length - b.length).abs() <= allowed && _distance(a, b) <= allowed;
  }

  static int _distance(String a, String b) {
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = [i, ...List<int>.filled(b.length, 0)];
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        current[j] = [previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost].reduce((x, y) => x < y ? x : y);
      }
      previous = current;
    }
    return previous[b.length];
  }

  /// Indice : le début de la réponse révélé jusqu'à la lettre suivante.
  static int nextLetter(String expected, int revealed) {
    var i = revealed;
    while (i < expected.length && expected[i] == ' ') {
      i++;
    }
    return (i + 1).clamp(0, expected.length);
  }

  /// Indice : le début de la réponse révélé jusqu'à la fin du mot suivant.
  static int nextWord(String expected, int revealed) {
    var i = revealed;
    while (i < expected.length && expected[i] == ' ') {
      i++;
    }
    while (i < expected.length && expected[i] != ' ') {
      i++;
    }
    return i;
  }

  /// Gabarit affiché : lettres révélées, puis un tiret par lettre restante.
  static String mask(String expected, int revealed) => [
    for (var i = 0; i < expected.length; i++)
      i < revealed ? expected[i] : (expected[i] == ' ' ? '  ' : '_'),
  ].join();
}

/// Construit les questions d'un niveau. [random] est injectable pour les tests.
class LessonBuilder {
  static const maxQuestions = 8;

  /// Questions de rappel ajoutées à la fin d'un niveau de proverbes.
  static const recallQuestions = 2;

  static List<LessonQuestion> build(ContentPack content, String levelId, {Random? random}) {
    final rng = random ?? Random();
    final level = content.level(levelId);
    if (level == null || !content.isPlayable(level)) return const [];
    if (level.hasActivities) {
      final isProverb = level.kind == LevelKind.proverbes;
      final activities = content.activitiesOf(levelId);
      return [
        for (final a in activities) _activity(a, rng, isProverb: isProverb),
        if (isProverb) ..._recalls(activities, rng),
      ];
    }
    final language = content.language(level.languageId)?.name ?? 'langue locale';
    final words = content.wordsOf(levelId)..shuffle(rng);
    return [
      for (final (i, w) in words.take(maxQuestions).indexed) _word(w, words, language, toLocal: i.isEven, rng: rng),
    ];
  }

  static LessonQuestion _activity(Activity a, Random rng, {required bool isProverb}) {
    final order = List.generate(a.answers.length, (i) => i)..shuffle(rng);
    return LessonQuestion(
      itemId: a.id,
      instruction: a.question,
      prompt: a.proverb,
      subtitle: a.original == null ? null : '${a.original}${a.language != null ? '  ·  ${a.language}' : ''}',
      audio: a.audio,
      answers: [for (final i in order) a.answers[i]],
      correct: order.indexOf(a.correct),
      explanation: a.explanation,
      xp: a.xp,
      isProverb: isProverb,
    );
  }

  static const _linkWords = {
    'au',
    'aux',
    'le',
    'la',
    'les',
    'de',
    'du',
    'des',
    'un',
    'une',
    'à',
    'en',
    'et',
    'ne',
    'se',
    'sa',
    'son',
    'ses',
    'qui',
    'que',
    'pas',
    'sur',
    'dans',
    'par',
    'pour',
    'avec',
    'tu',
    'il',
    'on',
    'te',
    'ton',
    'ta',
    'tes',
  };

  /// Coupe un proverbe en début et fin, à une ponctuation ou au milieu.
  /// Null pour un proverbe trop court pour en faire une question.
  static (String, String)? splitProverb(String proverb) {
    final text = proverb.trim().replaceFirst(RegExp(r'[.!]$'), '');
    for (final sep in [' : ', ' ; ', ', ']) {
      final i = text.indexOf(sep);
      if (i > 8 && i < text.length - 6) {
        return (text.substring(0, i + sep.length).trimRight(), text.substring(i + sep.length));
      }
    }
    final words = text.split(' ');
    if (words.length < 5) return null;
    // Ne pas couper juste après un petit mot (« face au … ») : la grammaire
    // trahirait la bonne fin.
    var cut = (words.length / 2).ceil();
    while (cut < words.length - 1 && _linkWords.contains(words[cut - 1].toLowerCase())) {
      cut++;
    }
    return (words.take(cut).join(' '), words.skip(cut).join(' '));
  }

  /// « Complète le proverbe » : le joueur écrit la fin d'un proverbe qu'il
  /// vient de voir. Des indices (payés en cauris) l'aident s'il bloque.
  static List<LessonQuestion> _recalls(List<Activity> activities, Random rng) {
    final candidates = activities.where((a) => splitProverb(a.proverb) != null).toList()..shuffle(rng);
    return [
      for (final a in candidates.take(recallQuestions))
        if (splitProverb(a.proverb) case (final start, final end)) _recall(a, start, end),
    ];
  }

  static LessonQuestion _recall(Activity a, String start, String end) => LessonQuestion(
    itemId: a.id,
    instruction: 'Rappel : écris la fin du proverbe',
    prompt: '$start …',
    answers: const [],
    correct: -1,
    expected: end,
    explanation: '« ${a.proverb} » ${a.answers[a.correct]}',
    xp: a.xp,
    isProverb: true,
    isRecall: true,
  );

  /// Entraînement : jusqu'à [maxQuestions] questions parmi celles ratées,
  /// complétées par des questions des niveaux déjà validés. Pas de rappel.
  static List<LessonQuestion> practice(ContentPack content, Set<String> toReview, Set<String> passedLevels, {Random? random}) {
    final rng = random ?? Random();
    final review = content.activities.where((a) => toReview.contains(a.id)).toList()..shuffle(rng);
    final extra = content.activities
        .where((a) => passedLevels.contains(a.levelId) && !toReview.contains(a.id))
        .toList()
      ..shuffle(rng);
    return [
      for (final a in [...review, ...extra].take(maxQuestions))
        _activity(a, rng, isProverb: content.level(a.levelId)?.kind == LevelKind.proverbes),
    ];
  }

  /// [toLocal] : le joueur voit le français et choisit la traduction locale,
  /// sinon l'inverse. Les mauvaises réponses viennent du même niveau.
  static LessonQuestion _word(Word w, List<Word> pool, String language, {required bool toLocal, required Random rng}) {
    String side(Word x) => toLocal ? x.local : x.french;
    final distractors = (pool.where((x) => x.id != w.id && side(x) != side(w)).map(side).toSet().toList()..shuffle(rng))
        .take(3)
        .toList();
    final answers = [side(w), ...distractors]..shuffle(rng);
    return LessonQuestion(
      itemId: w.id,
      instruction: toLocal ? 'Comment dit-on en $language ?' : 'Que veut dire ce mot en français ?',
      prompt: toLocal ? w.french : w.local,
      subtitle: toLocal ? null : w.pronunciation,
      audio: toLocal ? null : w.audio,
      answers: answers,
      correct: answers.indexOf(side(w)),
      explanation: '${w.local} = ${w.french}${w.pronunciation != null ? '  (se prononce « ${w.pronunciation} »)' : ''}',
      xp: w.xp,
    );
  }
}
