import '../models/avatar.dart';
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

  /// KoumanPlay+ actif : énergie illimitée et coffres doublés.
  static bool isPremium(PlayerState player, DateTime now) => player.premiumUntil?.isAfter(now) ?? false;

  /// Énergie disponible à [now].
  static int energyAt(PlayerState player, DateTime now) {
    if (player.energySince == null || isPremium(player, now)) return PlayerState.maxEnergy;
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
    if (isPremium(player, now)) return player;
    final current = energyAt(player, now);
    if (current <= 0) return player;
    final since = player.energySince;
    final anchor = since == null || current >= PlayerState.maxEnergy
        ? now
        : since.add(energyRefill * _refills(player, now));
    return player.copyWith(energy: current - 1, energySince: anchor, updatedAt: now);
  }

  /// Rend [amount] énergies (entraînement), sans dépasser le maximum.
  static PlayerState gainEnergy(PlayerState player, DateTime now, int amount) {
    final current = energyAt(player, now);
    if (current >= PlayerState.maxEnergy) return player;
    final since = player.energySince;
    final anchor = since == null ? now : since.add(energyRefill * _refills(player, now));
    return player.copyWith(
      energy: (current + amount).clamp(0, PlayerState.maxEnergy),
      energySince: anchor,
      updatedAt: now,
    );
  }

  // ---------------------------------------------------------------- Cauris

  /// Prix des indices du rappel « complète le proverbe ».
  static const hintLetterCost = 2;
  static const hintWordCost = 5;

  /// Coffre de fin de niveau : 5 cauris par nouvelle étoile, 2 pour un niveau
  /// rejoué et réussi sans nouvelle étoile.
  static const chestPerStar = 5;
  static const chestReplay = 2;

  /// Entraînement terminé : 3 cauris et 1 énergie.
  static const practiceCauris = 3;
  static const practiceEnergy = 1;

  /// Débloque une pièce d'avatar avec des cauris ; null s'il n'y en a pas
  /// assez. Une pièce gratuite ou déjà acquise ne coûte rien.
  static PlayerState? buyItem(PlayerState player, String item, DateTime now) {
    if (player.ownsItem(item)) return player;
    final paid = spendCauris(player, AvatarConfig.priceOf(item), now);
    return paid?.copyWith(ownedItems: {...player.ownedItems, item});
  }

  /// Cauris restant à payer pour enregistrer [avatar].
  static int avatarCost(PlayerState player, AvatarConfig avatar) =>
      avatar.items.where((i) => !player.ownsItem(i)).fold(0, (sum, i) => sum + AvatarConfig.priceOf(i));

  /// Achats en ligne livrés par le serveur : cauris payés et fin de KoumanPlay+.
  static PlayerState applyPurchases(PlayerState player, {required int cauris, DateTime? premiumUntil, required DateTime now}) {
    final until = premiumUntil == null || (player.premiumUntil?.isAfter(premiumUntil) ?? false)
        ? player.premiumUntil
        : premiumUntil;
    if (cauris == 0 && until == player.premiumUntil) return player;
    return player.copyWith(cauris: player.cauris + cauris, premiumUntil: until, updatedAt: now);
  }

  /// Dépense des cauris ; null s'il n'y en a pas assez.
  static PlayerState? spendCauris(PlayerState player, int amount, DateTime now) =>
      player.cauris < amount ? null : player.copyWith(cauris: player.cauris - amount, updatedAt: now);

  // ---------------------------------------------------------------- Étoiles

  /// 3 étoiles : tout juste ; 2 : au moins 80 % ; 1 : niveau validé.
  static int stars(int correct, int total, {required bool passed}) {
    if (!passed || total == 0) return 0;
    if (correct >= total) return 3;
    return correct / total >= 0.8 ? 2 : 1;
  }

  /// Meilleur nombre d'étoiles obtenu sur un niveau.
  static int levelStars(PlayerState player, String levelId) {
    final result = player.levels[levelId];
    return result == null ? 0 : stars(result.bestCorrect, result.total, passed: result.passed);
  }

  // ---------------------------------------------------------------- Quêtes du jour

  static const questPool = [
    QuestDef('niveaux', 'Réussis 2 niveaux', 2, 10),
    QuestDef('sans-faute', 'Fais un sans-faute (3 étoiles)', 1, 15),
    QuestDef('reponses', 'Donne 10 bonnes réponses', 10, 10),
    QuestDef('entrainement', 'Termine un entraînement', 1, 10),
    QuestDef('rappel', 'Complète un proverbe sans indice', 1, 10),
  ];

  /// Les 3 quêtes d'un jour, toujours les mêmes pour ce jour.
  static List<QuestDef> questsOfDay(String day) {
    final seed = day.codeUnits.fold<int>(0, (h, c) => (h * 31 + c) & 0x7fffffff);
    final pool = [...questPool];
    return [for (var i = 0; i < 3; i++) pool.removeAt((seed + i * 7) % pool.length)];
  }

  /// Avance les quêtes du jour ; une quête terminée donne ses cauris tout de
  /// suite. Renvoie le joueur et les quêtes terminées par cette action.
  static (PlayerState, List<QuestDef>) progressQuests(PlayerState player, DateTime now, Map<String, int> increments) {
    final day = dayKey(now);
    final current = player.quests?.day == day ? player.quests! : QuestProgress(day: day);
    final progress = {...current.progress};
    final claimed = {...current.claimed};
    final done = <QuestDef>[];
    var cauris = player.cauris;
    for (final quest in questsOfDay(day)) {
      final add = increments[quest.id] ?? 0;
      if (add <= 0) continue;
      progress[quest.id] = (progress[quest.id] ?? 0) + add;
      if (progress[quest.id]! >= quest.target && claimed.add(quest.id)) {
        done.add(quest);
        cauris += quest.reward;
      }
    }
    return (
      player.copyWith(quests: QuestProgress(day: day, progress: progress, claimed: claimed), cauris: cauris),
      done,
    );
  }

  // ---------------------------------------------------------------- Entraînement

  /// Fin d'un entraînement : les questions réussies sortent de la liste à
  /// réviser, les ratées y restent. Pas d'énergie perdue : on en regagne une.
  static PracticeOutcome completePractice({
    required PlayerState player,
    required Set<String> askedIds,
    required Set<String> correctIds,
    required DateTime now,
  }) {
    var next = player.copyWith(
      toReview: {...player.toReview.difference(correctIds), ...askedIds.difference(correctIds)},
      cauris: player.cauris + practiceCauris,
      updatedAt: now,
    );
    final energyBefore = energyAt(next, now);
    next = touchStreak(gainEnergy(next, now, practiceEnergy), now);
    final (withQuests, quests) = progressQuests(next, now, {'entrainement': 1, 'reponses': correctIds.length});
    return PracticeOutcome(
      player: withQuests,
      correct: correctIds.length,
      total: askedIds.length,
      cauris: practiceCauris,
      energyGained: energyAt(withQuests, now) - energyBefore,
      completedQuests: quests,
    );
  }

  static int xpIntoLevel(int xp) => xp % xpPerPlayerLevel;

  static double levelProgress(int xp) => xpIntoLevel(xp) / xpPerPlayerLevel;

  /// Une étape (langue) est terminée quand tous ses niveaux jouables sont
  /// validés. Une étape sans aucun contenu n'est jamais « terminée ».
  static bool isLanguageCompleted(ContentPack content, PlayerState player, Language language) {
    final playable = content.playableLevelsOf(language.id);
    return playable.isNotEmpty && playable.every((l) => player.isLevelPassed(l.id));
  }

  /// Langue affichée sur la carte : celle choisie par le joueur, sinon la
  /// langue qu'il transmet (aîné), sinon la première qui a du contenu.
  static Language? learningLanguage(ContentPack content, PlayerState player) {
    for (final id in [player.learningLanguageId, player.spokenLanguageId]) {
      final language = id == null ? null : content.language(id);
      if (language != null) return language;
    }
    for (final language in content.languages) {
      if (content.playableLevelsOf(language.id).isNotEmpty) return language;
    }
    return content.languages.firstOrNull;
  }

  /// Un niveau est ouvert si les niveaux jouables qui le précèdent dans sa
  /// langue sont validés. Les niveaux « en préparation » ne bloquent pas.
  /// Toutes les langues sont ouvertes : le joueur choisit la sienne.
  static bool isLevelUnlocked(ContentPack content, PlayerState player, Level level) {
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

  /// Premier niveau ouvert et pas encore validé dans la langue du joueur.
  static Level? nextLevel(ContentPack content, PlayerState player) {
    final language = learningLanguage(content, player);
    if (language == null) return null;
    for (final level in content.levelsOf(language.id)) {
      if (!player.isLevelPassed(level.id) && isLevelUnlocked(content, player, level)) return level;
    }
    return null;
  }

  /// Niveaux validés demandés pour [event] (son propre seuil, sinon le seuil
  /// général). Dans Supabase, ce seuil s'appelle encore « min_diamonds ».
  static int eventLevelsRequired(ContentPack content, CultureEvent? event) =>
      event?.minDiamonds ?? content.settings.eventMinDiamonds;

  /// Le joueur peut participer aux événements culturels : assez de niveaux
  /// validés et un niveau de joueur suffisant. C'est du mérite : les cauris,
  /// qui pourront s'acheter, n'y comptent pas.
  static bool isEventEligible(ContentPack content, PlayerState player, [CultureEvent? event]) =>
      player.levelsPassed >= eventLevelsRequired(content, event) &&
      playerLevel(player.xp) >= content.settings.eventMinLevel;

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
    int correctAnswers = 0,
    int recallsWithoutHint = 0,
  }) {
    final level = content.level(levelId)!;
    final items = content.itemsOf(levelId).where((i) => askedIds.contains(i.id)).toList();
    final total = items.length;
    final correct = items.where((i) => correctIds.contains(i.id)).length;
    final passed = total > 0 && correct / total >= level.passRatio;

    final newlyMastered = items.where((i) => correctIds.contains(i.id) && !player.masteredActivities.contains(i.id));
    final xpGained = newlyMastered.fold<int>(0, (sum, a) => sum + a.xp);

    final previous = player.levels[levelId];
    final previousStars = levelStars(player, levelId);
    final runStars = stars(correct, total, passed: passed);
    final chest =
        (!passed
            ? 0
            : runStars > previousStars
            ? chestPerStar * (runStars - previousStars)
            : chestReplay) *
        (isPremium(player, now) ? 2 : 1);
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
      cauris: player.cauris + chest,
      // Les ratés vont dans l'entraînement ; ce qui est réussi en sort.
      toReview: {
        ...player.toReview.difference(correctIds),
        ...items.where((i) => !correctIds.contains(i.id)).map((i) => i.id),
      },
      updatedAt: now,
    );
    next = touchStreak(next, now);
    final List<QuestDef> quests;
    (next, quests) = progressQuests(next, now, {
      'niveaux': passed ? 1 : 0,
      'sans-faute': runStars == 3 ? 1 : 0,
      'reponses': correctAnswers,
      'rappel': recallsWithoutHint,
    });

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
      stars: runStars,
      previousStars: previousStars,
      chestCauris: chest,
      completedQuests: quests,
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
    this.stars = 0,
    this.previousStars = 0,
    this.chestCauris = 0,
    this.completedQuests = const [],
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

  /// Étoiles de cette partie (0 si le niveau n'est pas validé) et meilleur
  /// score d'avant.
  final int stars;
  final int previousStars;

  /// Cauris du coffre de fin de niveau.
  final int chestCauris;

  /// Quêtes du jour terminées pendant cette partie (leurs cauris sont déjà
  /// ajoutés au joueur).
  final List<QuestDef> completedQuests;
}

class QuestDef {
  const QuestDef(this.id, this.title, this.target, this.reward);

  final String id;
  final String title;
  final int target;

  /// Cauris gagnés en la terminant.
  final int reward;
}

class PracticeOutcome {
  const PracticeOutcome({
    required this.player,
    required this.correct,
    required this.total,
    required this.cauris,
    required this.energyGained,
    required this.completedQuests,
  });

  final PlayerState player;
  final int correct;
  final int total;
  final int cauris;
  final int energyGained;
  final List<QuestDef> completedQuests;
}

class ChallengeOutcome {
  const ChallengeOutcome({required this.player, required this.xpGained, required this.newBadges});

  final PlayerState player;
  final int xpGained;
  final List<BadgeDef> newBadges;
}
