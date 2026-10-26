import '../models/content.dart';
import '../models/player.dart';

/// Règles du jeu, sans dépendance Flutter : XP, niveaux, déblocages, badges,
/// série. Testées dans test/game_rules_test.dart.
class GameRules {
  static const xpPerPlayerLevel = 200;

  static int playerLevel(int xp) => 1 + xp ~/ xpPerPlayerLevel;

  /// XP gagné par un aîné pour chaque transmission.
  static const transmissionXp = {'mot': 10, 'proverbe': 30, 'conte': 50};

  /// Enregistre une transmission d'aîné : XP, compteur, série, badges.
  static ChallengeOutcome recordTransmission(ContentPack content, PlayerState player, String kind, DateTime now) {
    final xpGained = transmissionXp[kind] ?? 10;
    var next = player.copyWith(
      xp: player.xp + xpGained,
      transmitted: {...player.transmitted, kind: (player.transmitted[kind] ?? 0) + 1},
      updatedAt: now,
    );
    next = touchStreak(next, now);
    final newBadges = evaluateBadges(content, next);
    next = next.copyWith(badges: {...next.badges, ...newBadges.map((b) => b.id)});
    return ChallengeOutcome(player: next, xpGained: xpGained, newBadges: newBadges);
  }

  /// Une énergie revient toutes les 15 minutes : 75 minutes de 0 à 5.
  static const energyRefill = Duration(minutes: 15);

  static int _refills(PlayerState player, DateTime now) {
    final elapsed = now.difference(player.energySince!);
    return elapsed.isNegative ? 0 : elapsed.inSeconds ~/ energyRefill.inSeconds;
  }

  /// Énergie disponible à [now].
  static int energyAt(PlayerState player, DateTime now) {
    if (player.energySince == null) return PlayerState.maxEnergy;
    return (player.energy + _refills(player, now)).clamp(0, PlayerState.maxEnergy);
  }

  /// Temps avant la prochaine énergie, ou null si elle est pleine.
  static Duration? nextEnergyIn(PlayerState player, DateTime now) {
    final since = player.energySince;
    if (since == null || energyAt(player, now) >= PlayerState.maxEnergy) return null;
    final elapsed = now.difference(since);
    if (elapsed.isNegative) return energyRefill;
    return Duration(seconds: energyRefill.inSeconds - elapsed.inSeconds % energyRefill.inSeconds);
  }

  /// Retire une énergie (mauvaise réponse). Le temps déjà écoulé vers la
  /// prochaine énergie est conservé.
  static PlayerState loseEnergy(PlayerState player, DateTime now) {
    final current = energyAt(player, now);
    if (current <= 0) return player;
    final since = player.energySince;
    final anchor = since == null || current >= PlayerState.maxEnergy
        ? now
        : since.add(energyRefill * _refills(player, now));
    return player.copyWith(energy: current - 1, energySince: anchor, updatedAt: now);
  }

  static int xpIntoLevel(int xp) => xp % xpPerPlayerLevel;

  static double levelProgress(int xp) => xpIntoLevel(xp) / xpPerPlayerLevel;

  /// Une étape (langue) est terminée quand tous ses niveaux jouables sont
  /// validés. Une étape sans aucun contenu n'est jamais « terminée ».
  static bool isLanguageCompleted(ContentPack content, PlayerState player, Language language) {
    final playable = content.playableLevelsOf(language.id);
    return playable.isNotEmpty && playable.every((l) => player.isLevelPassed(l.id));
  }

  /// La première étape est ouverte ; les suivantes s'ouvrent quand toutes
  /// les étapes précédentes qui ont du contenu sont terminées.
  static bool isLanguageUnlocked(ContentPack content, PlayerState player, Language language) {
    for (final previous in content.languages.takeWhile((l) => l.id != language.id)) {
      if (content.playableLevelsOf(previous.id).isEmpty) continue;
      if (!isLanguageCompleted(content, player, previous)) return false;
    }
    return true;
  }

  /// Un niveau est ouvert si son étape l'est et si les niveaux jouables qui
  /// le précèdent sont validés. Les niveaux « en préparation » ne bloquent pas.
  static bool isLevelUnlocked(ContentPack content, PlayerState player, Level level) {
    final language = content.language(level.languageId);
    if (language == null || !isLanguageUnlocked(content, player, language)) return false;
    if (!content.isPlayable(level)) return false;
    return content
        .playableLevelsOf(level.languageId)
        .takeWhile((l) => l.id != level.id)
        .every((l) => player.isLevelPassed(l.id));
  }

  static bool isChallengeUnlocked(PlayerState player, Challenge challenge) {
    final after = challenge.unlockAfterLevel;
    return after == null || player.isLevelPassed(after);
  }

  static List<Challenge> challengesFor(ContentPack content, PlayerState player) =>
      content.challenges.where((c) => c.isFor(player.role)).toList();

  /// Premier niveau ouvert et pas encore validé, en suivant la carte.
  static Level? nextLevel(ContentPack content, PlayerState player) {
    for (final language in content.languages) {
      for (final level in content.levelsOf(language.id)) {
        if (!player.isLevelPassed(level.id) && isLevelUnlocked(content, player, level)) return level;
      }
    }
    return null;
  }

  /// Part des éléments (mots, proverbes) maîtrisés dans une langue.
  static double languageMastery(ContentPack content, PlayerState player, Language language) {
    final items = [for (final l in content.levelsOf(language.id)) ...content.itemsOf(l.id)];
    if (items.isEmpty) return 0;
    return items.where((i) => player.masteredActivities.contains(i.id)).length / items.length;
  }

  /// Défi à mettre en avant : celui en cours, sinon le prochain disponible,
  /// sinon le prochain à débloquer.
  static Challenge? featuredChallenge(ContentPack content, PlayerState player) {
    final mine = challengesFor(content, player);
    ChallengeStatus? statusOf(Challenge c) => player.challenges[c.id]?.status;
    for (final c in mine) {
      if (statusOf(c) == ChallengeStatus.inProgress) return c;
    }
    for (final c in mine) {
      if (statusOf(c) == null && isChallengeUnlocked(player, c)) return c;
    }
    for (final c in mine) {
      if (!isChallengeUnlocked(player, c)) return c;
    }
    return null;
  }

  static String dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Met à jour la série de jours consécutifs.
  static PlayerState touchStreak(PlayerState player, DateTime now) {
    final today = dayKey(now);
    if (player.lastActiveDay == today) return player;
    final yesterday = dayKey(now.subtract(const Duration(days: 1)));
    final streak = player.lastActiveDay == yesterday ? player.streak + 1 : 1;
    return player.copyWith(streak: streak, lastActiveDay: today);
  }

  /// Applique la fin d'un niveau. [askedIds] = éléments posés pendant la
  /// partie, [correctIds] = ceux réussis. Seules les bonnes réponses jamais
  /// données rapportent de l'XP, gardé même si le niveau n'est pas validé.
  /// [outOfEnergy] : la partie s'est arrêtée faute d'énergie.
  static LevelOutcome completeLevel({
    required ContentPack content,
    required PlayerState player,
    required String levelId,
    required Set<String> askedIds,
    required Set<String> correctIds,
    required DateTime now,
    bool outOfEnergy = false,
  }) {
    final level = content.level(levelId)!;
    final items = content.itemsOf(levelId).where((i) => askedIds.contains(i.id)).toList();
    final total = items.length;
    final correct = items.where((i) => correctIds.contains(i.id)).length;
    final passed = total > 0 && correct / total >= level.passRatio;

    final newlyMastered = items.where((i) => correctIds.contains(i.id) && !player.masteredActivities.contains(i.id));
    final xpGained = newlyMastered.fold<int>(0, (sum, a) => sum + a.xp);

    final previous = player.levels[levelId];
    final result = LevelResult(
      bestCorrect: previous == null || correct > previous.bestCorrect ? correct : previous.bestCorrect,
      total: total,
      passed: passed || (previous?.passed ?? false),
    );

    final challengesBefore = challengesFor(content, player).where((c) => isChallengeUnlocked(player, c)).map((c) => c.id).toSet();

    var next = player.copyWith(
      xp: player.xp + xpGained,
      levels: {...player.levels, levelId: result},
      masteredActivities: {...player.masteredActivities, ...newlyMastered.map((a) => a.id)},
      updatedAt: now,
    );
    next = touchStreak(next, now);

    final unlocked = challengesFor(content, next)
        .where((c) => isChallengeUnlocked(next, c) && !challengesBefore.contains(c.id))
        .toList();

    final newBadges = evaluateBadges(content, next);
    next = next.copyWith(badges: {...next.badges, ...newBadges.map((b) => b.id)});

    return LevelOutcome(
      player: next,
      levelId: levelId,
      correct: correct,
      total: total,
      passed: passed,
      xpGained: xpGained,
      leveledUp: playerLevel(next.xp) > playerLevel(player.xp),
      newBadges: newBadges,
      unlockedChallenges: unlocked,
      outOfEnergy: outOfEnergy,
    );
  }

  /// Valide un défi : l'XP n'est donné qu'une seule fois.
  static ChallengeOutcome completeChallenge({
    required ContentPack content,
    required PlayerState player,
    required String challengeId,
    required String? note,
    required bool shareNote,
    required DateTime now,
  }) {
    final challenge = content.challenge(challengeId)!;
    final previous = player.challenges[challengeId];
    final alreadyDone = previous?.status == ChallengeStatus.done;
    final progress = ChallengeProgress(
      status: ChallengeStatus.done,
      stepsDone: {for (var i = 0; i < challenge.steps.length; i++) i},
      note: note,
      shareNote: shareNote,
      completedAt: previous?.completedAt ?? now,
    );
    final xpGained = alreadyDone ? 0 : challenge.rewardXp;
    var next = player.copyWith(
      xp: player.xp + xpGained,
      challenges: {...player.challenges, challengeId: progress},
      updatedAt: now,
    );
    next = touchStreak(next, now);
    final newBadges = evaluateBadges(content, next);
    next = next.copyWith(badges: {...next.badges, ...newBadges.map((b) => b.id)});
    return ChallengeOutcome(player: next, xpGained: xpGained, newBadges: newBadges);
  }

  /// Badges gagnés par [player] qu'il n'avait pas encore.
  static List<BadgeDef> evaluateBadges(ContentPack content, PlayerState player) {
    final doneChallenges = player.challenges.values.where((c) => c.status == ChallengeStatus.done).length;
    final passedLevels = player.levels.values.where((l) => l.passed).length;
    final passedProverbs = content.levels
        .where((l) => l.kind == LevelKind.proverbes && player.isLevelPassed(l.id))
        .length;
    final earned = <String>{
      if (player.levels.isNotEmpty) 'premiers-pas',
      if (passedLevels >= 1) 'passeur-de-sagesse',
      if (player.levels.values.any((l) => l.perfect && l.total > 0)) 'maitre-des-proverbes',
      if (passedProverbs >= 3) 'gardien-des-proverbes',
      if (content.languages.any((l) => isLanguageCompleted(content, player, l))) 'etape-terminee',
      if (doneChallenges >= 1) 'pont-des-generations',
      if (player.streak >= 3) 'regulier',
      if (player.transmittedTotal >= 1) 'premiere-transmission',
      if (player.transmittedTotal >= 10) 'gardien-de-la-parole',
      if ((player.transmitted['conte'] ?? 0) >= 1) 'conteur',
    };
    return badges.where((b) => earned.contains(b.id) && !player.badges.contains(b.id)).toList();
  }

  static const badges = <BadgeDef>[
    BadgeDef('premiers-pas', 'Premiers pas', 'Termine ta première partie.', '🌱'),
    BadgeDef('passeur-de-sagesse', 'Passeur de sagesse', 'Valide ton premier niveau.', '🌿'),
    BadgeDef('maitre-des-proverbes', 'Sans-faute', 'Fais un sans-faute sur un niveau.', '🏆'),
    BadgeDef('gardien-des-proverbes', 'Gardien des proverbes', 'Valide 3 niveaux de proverbes.', '🌳'),
    BadgeDef('etape-terminee', 'Première étape', 'Termine tous les niveaux d\'une langue.', '🎯'),
    BadgeDef('pont-des-generations', 'Pont des générations', 'Réalise ton premier défi intergénérationnel.', '🤝'),
    BadgeDef('regulier', 'Régulier', 'Joue 3 jours d\'affilée.', '🔥'),
    BadgeDef('premiere-transmission', 'Passeur de savoir', 'Transmets ton premier mot, proverbe ou conte.', '🎤'),
    BadgeDef('gardien-de-la-parole', 'Gardien de la parole', 'Transmets 10 savoirs.', '🏅'),
    BadgeDef('conteur', 'Conteur', 'Raconte ton premier conte.', '📖'),
  ];
}

class BadgeDef {
  const BadgeDef(this.id, this.title, this.description, this.emoji);

  final String id;
  final String title;
  final String description;
  final String emoji;
}

class LevelOutcome {
  const LevelOutcome({
    required this.player,
    required this.levelId,
    required this.correct,
    required this.total,
    required this.passed,
    required this.xpGained,
    required this.leveledUp,
    required this.newBadges,
    required this.unlockedChallenges,
    this.outOfEnergy = false,
  });

  final PlayerState player;
  final String levelId;
  final int correct;
  final int total;
  final bool passed;
  final int xpGained;
  final bool leveledUp;
  final List<BadgeDef> newBadges;
  final List<Challenge> unlockedChallenges;
  final bool outOfEnergy;
}

class ChallengeOutcome {
  const ChallengeOutcome({required this.player, required this.xpGained, required this.newBadges});

  final PlayerState player;
  final int xpGained;
  final List<BadgeDef> newBadges;
}
