import 'dart:math';

import '../models/content.dart';
import 'game_rules.dart';
import 'lesson.dart';

/// Les deux jeux de duel, joués en direct. Les deux joueurs construisent le
/// même contenu à partir de la même graine.
enum DuelMode {
  /// Vrai ou faux le plus vite possible : chaque bonne réponse tire la corde.
  corde,

  /// Relier les deux moitiés de proverbes (ou un mot et sa traduction).
  paires;

  String get title => switch (this) {
    DuelMode.corde => 'Tir à la corde',
    DuelMode.paires => 'Paires express',
  };

  String get pitch => switch (this) {
    DuelMode.corde => 'Vrai ou faux ? Réponds vite : chaque bonne réponse tire la corde de ton côté.',
    DuelMode.paires => 'Relie chaque début de proverbe à sa fin, plus vite que ton adversaire.',
  };
}

/// Une carte du tir à la corde : ce proverbe veut-il dire ça ?
class RopeCard {
  const RopeCard({required this.proverb, required this.meaning, required this.isTrue, required this.answer});

  final String proverb;

  /// Sens proposé, juste ou non.
  final String meaning;
  final bool isTrue;

  /// Le vrai sens, montré après une erreur.
  final String answer;
}

/// Une paire à relier : deux moitiés de proverbe, ou un mot et sa traduction.
class PairCard {
  const PairCard({required this.id, required this.left, required this.right});

  final String id;
  final String left;
  final String right;
}

class RopeRules {
  /// Écart de tirs pour gagner avant la fin du temps.
  static const winGap = 8;
  static const seconds = 60;

  /// Réponse rapide (moins de 2,5 s) : tire deux fois plus fort.
  static int strength(Duration answerTime) => answerTime < const Duration(milliseconds: 2500) ? 2 : 1;

  /// Après une erreur, le joueur ne peut plus répondre pendant ce temps.
  static const penalty = Duration(milliseconds: 1200);

  /// Résultat quand la corde atteint un camp, ou à la fin du temps ; null si la
  /// partie continue.
  static DuelVerdict? verdict(int mine, int theirs, {required bool timeUp}) {
    final gap = mine - theirs;
    if (gap >= winGap) return DuelVerdict.win;
    if (gap <= -winGap) return DuelVerdict.loss;
    if (!timeUp) return null;
    return gap > 0 ? DuelVerdict.win : (gap < 0 ? DuelVerdict.loss : DuelVerdict.draw);
  }
}

class PairsRules {
  static const rounds = 3;
  static const perRound = 4;
  static const total = rounds * perRound;
  static const seconds = 90;

  /// Mauvaise association : cartes bloquées pendant ce temps.
  static const penalty = Duration(milliseconds: 1500);

  /// Le premier à tout relier gagne ; à la fin du temps, celui qui a le plus
  /// de paires.
  static DuelVerdict? verdict(int mine, int theirs, {required bool timeUp}) {
    if (mine >= total && theirs < total) return DuelVerdict.win;
    if (theirs >= total && mine < total) return DuelVerdict.loss;
    if (!timeUp) return null;
    return mine > theirs ? DuelVerdict.win : (mine < theirs ? DuelVerdict.loss : DuelVerdict.draw);
  }
}

class DuelContent {
  /// Proverbes de la langue ; s'il y en a trop peu, ceux de toutes les langues.
  static List<Activity> _proverbs(ContentPack content, String languageId) {
    bool isProverb(Activity a) => content.level(a.levelId)?.kind == LevelKind.proverbes;
    final mine = content.activities
        .where((a) => isProverb(a) && content.level(a.levelId)?.languageId == languageId)
        .toList();
    return mine.length >= 8 ? mine : content.activities.where(isProverb).toList();
  }

  /// Cartes du tir à la corde, une fois sur deux avec le vrai sens.
  static List<RopeCard> rope(ContentPack content, String languageId, int seed, {int count = 40}) {
    final rng = Random(seed);
    final pool = _proverbs(content, languageId);
    if (pool.isEmpty) return const [];
    final cards = <RopeCard>[];
    var deck = <Activity>[];
    while (cards.length < count) {
      if (deck.isEmpty) deck = [...pool]..shuffle(rng);
      final a = deck.removeLast();
      final truth = a.answers[a.correct];
      final wrong = [
        for (var i = 0; i < a.answers.length; i++)
          if (i != a.correct) a.answers[i],
      ];
      final isTrue = wrong.isEmpty || rng.nextBool();
      cards.add(
        RopeCard(
          proverb: a.proverb,
          meaning: isTrue ? truth : wrong[rng.nextInt(wrong.length)],
          isTrue: isTrue,
          answer: truth,
        ),
      );
    }
    return cards;
  }

  /// Manches de paires express : des mots collectés quand il y en a assez,
  /// sinon les deux moitiés des proverbes.
  static List<List<PairCard>> pairs(ContentPack content, String languageId, int seed) {
    final rng = Random(seed);
    final words = [
      for (final l in content.playableLevelsOf(languageId))
        if (!l.hasActivities) ...content.wordsOf(l.id),
    ];
    final pool = <PairCard>[
      for (final w in words) PairCard(id: w.id, left: w.local, right: w.french),
      if (words.length < PairsRules.total)
        for (final a in _proverbs(content, languageId))
          if (LessonBuilder.splitProverb(a.proverb) case (final start, final end))
            PairCard(id: a.id, left: start, right: end),
    ]..shuffle(rng);
    final picked = pool.take(PairsRules.total).toList();
    return [
      for (var r = 0; r * PairsRules.perRound < picked.length; r++)
        picked.skip(r * PairsRules.perRound).take(PairsRules.perRound).toList(),
    ];
  }

  /// Prénoms des joueurs proposés quand personne n'est disponible.
  static const names = [
    'Koffi',
    'Aya',
    'Yao',
    'Adjoua',
    'Konan',
    'Amenan',
    'Kouassi',
    'Affoué',
    'Mamadou',
    'Fatou',
    'Seydou',
    'Awa',
    'Brou',
    'Akissi',
    'Drissa',
    'Mariam',
    'Tano',
    'Ahou',
    'Ibrahim',
    'Grâce',
  ];
}

/// Rythme d'un adversaire simulé : temps de réponse et justesse, tirés au
/// sort pour chaque partie autour du niveau d'un joueur moyen.
class BotSkill {
  BotSkill(Random rng)
    : accuracy = 0.62 + rng.nextDouble() * 0.23,
      minMs = 1500 + rng.nextInt(700),
      maxMs = 3200 + rng.nextInt(1800);

  final double accuracy;
  final int minMs;
  final int maxMs;

  Duration nextDelay(Random rng) => Duration(milliseconds: minMs + rng.nextInt(maxMs - minMs));
}
