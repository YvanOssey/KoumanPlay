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
}

/// Construit les questions d'un niveau. [random] est injectable pour les tests.
class LessonBuilder {
  static const maxQuestions = 8;

  static List<LessonQuestion> build(ContentPack content, String levelId, {Random? random}) {
    final rng = random ?? Random();
    final level = content.level(levelId);
    if (level == null || !content.isPlayable(level)) return const [];
    if (level.kind == LevelKind.proverbes) {
      return [for (final a in content.activitiesOf(levelId)) _proverb(a, rng)];
    }
    final language = content.language(level.languageId)?.name ?? 'langue locale';
    final words = content.wordsOf(levelId)..shuffle(rng);
    return [
      for (final (i, w) in words.take(maxQuestions).indexed) _word(w, words, language, toLocal: i.isEven, rng: rng),
    ];
  }

  static LessonQuestion _proverb(Activity a, Random rng) {
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
      isProverb: true,
    );
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
