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
    var next = gainXp(player, xpGained, now).copyWith(
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

  /// Niveau : temps indicatif par question. Une bonne réponse donnée avant la
  /// moitié du temps est un « éclair » : 1 cauri de plus si le niveau est validé.
  static const levelSeconds = 20;
  static const quickCauris = 1;

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

  /// Livraison d'un achat simulé (boutique de démonstration) : les jours de
  /// KoumanPlay+ s'ajoutent à l'abonnement en cours.
  static PlayerState applyDemoPurchase(PlayerState player, {required int cauris, required int premiumDays, required DateTime now}) {
    final current = isPremium(player, now) ? player.premiumUntil! : now;
    return applyPurchases(
      player,
      cauris: cauris,
      premiumUntil: premiumDays > 0 ? current.add(Duration(days: premiumDays)) : null,
      now: now,
    );
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

  // ---------------------------------------------------------------- Boss

  /// Défi final d'une langue, ouvert quand tous ses niveaux sont validés :
  /// des questions de tous les niveaux, chronométrées.
  static const bossQuestions = 12;
  static const bossPassRatio = 0.8;
  static const bossSeconds = 20;

  /// Rappel écrit : plus de temps pour taper.
  static const bossRecallSeconds = 45;
  static const bossFirstCauris = 50;
  static const bossReplayCauris = 5;
  static const bossXp = 100;

  static bool isBossUnlocked(ContentPack content, PlayerState player, Language language) =>
      isLanguageCompleted(content, player, language);

  /// Fin d'un Boss : la première victoire rapporte XP, cauris et badge ; les
  /// suivantes quelques cauris. [correct] / [total] : questions réussies / posées.
  static BossOutcome completeBoss({
    required ContentPack content,
    required PlayerState player,
    required String languageId,
    required int correct,
    required int total,
    required DateTime now,
  }) {
    final passed = total > 0 && correct / total >= bossPassRatio;
    final firstWin = passed && !player.bossesBeaten.contains(languageId);
    final cauris = (firstWin ? bossFirstCauris : (passed ? bossReplayCauris : 0)) * (isPremium(player, now) ? 2 : 1);
    final xpGained = firstWin ? bossXp : 0;
    var next = gainXp(player, xpGained, now).copyWith(
      cauris: player.cauris + cauris,
      bossesBeaten: passed ? {...player.bossesBeaten, languageId} : player.bossesBeaten,
      updatedAt: now,
    );
    next = touchStreak(next, now);
    final List<QuestDef> quests;
    (next, quests) = progressQuests(next, now, {'niveaux': passed ? 1 : 0, 'reponses': correct});
    final newBadges = evaluateBadges(content, next);
    next = next.copyWith(badges: {...next.badges, ...newBadges.map((b) => b.id)});
    return BossOutcome(
      player: next,
      passed: passed,
      firstWin: firstWin,
      correct: correct,
      total: total,
      cauris: cauris,
      xpGained: xpGained,
      completedQuests: quests,
      newBadges: newBadges,
    );
  }

  // ---------------------------------------------------------------- Ligues

  /// Ligues, de la première à la plus haute. Chaque semaine, les joueurs sont
  /// classés par groupes de 20 selon l'XP gagné.
  static const leagues = ['Bronze', 'Argent', 'Or', 'Baobab'];
  static const leagueMove = 5;
  static const leagueRewards = [30, 20, 10];

  static String leagueName(int tier) => leagues[tier.clamp(0, leagues.length - 1)];

  /// Semaine ISO en temps universel (« 2026-W44 »), comme le serveur.
  static String weekKey(DateTime date) {
    final utc = date.toUtc();
    final day = DateTime.utc(utc.year, utc.month, utc.day);
    final thursday = day.add(Duration(days: DateTime.thursday - day.weekday));
    final week = 1 + thursday.difference(DateTime.utc(thursday.year)).inDays ~/ 7;
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }

  /// Fin de la semaine de ligue : lundi suivant à 0 h (temps universel).
  static DateTime weekEnd(DateTime date) {
    final utc = date.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day).add(Duration(days: 8 - utc.weekday));
  }

  /// XP gagné : compte aussi pour la ligue de la semaine.
  static PlayerState gainXp(PlayerState player, int amount, DateTime now) {
    final week = weekKey(now);
    return player.copyWith(
      xp: player.xp + amount,
      weekKey: week,
      weekXp: (player.weekKey == week ? player.weekXp : 0) + amount,
    );
  }

  static int weeklyXp(PlayerState player, DateTime now) => player.weekKey == weekKey(now) ? player.weekXp : 0;

  /// Récompense du podium de la semaine [week] (30, 20, 10 cauris), donnée
  /// une seule fois ; null si elle a déjà été reçue.
  static PlayerState? claimLeagueReward(PlayerState player, {required String week, required int rank, required int points, required DateTime now}) {
    if (player.leagueRewardWeek == week) return null;
    final reward = points > 0 && rank >= 1 && rank <= leagueRewards.length ? leagueRewards[rank - 1] : 0;
    return player.copyWith(cauris: player.cauris + reward, leagueRewardWeek: week, updatedAt: now);
  }

  // ---------------------------------------------------------------- Duels

  /// Duels en direct (Tir à la corde, Paires express) : cauris selon le
  /// résultat, sans énergie ni XP.
  static const duelWinCauris = 10;
  static const duelDrawCauris = 5;
  static const duelPlayCauris = 2;

  /// Récompense d'un duel terminé, une seule fois ; null si déjà reçue.
  static PlayerState? claimDuelReward(PlayerState player, String duelId, DuelVerdict verdict, DateTime now) {
    if (player.duelsRewarded.contains(duelId)) return null;
    return player.copyWith(
      cauris: player.cauris + duelReward(verdict),
      duelsRewarded: {...player.duelsRewarded, duelId},
      updatedAt: now,
    );
  }

  static int duelReward(DuelVerdict verdict) => switch (verdict) {
    DuelVerdict.win => duelWinCauris,
    DuelVerdict.draw => duelDrawCauris,
    DuelVerdict.loss => duelPlayCauris,
  };

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
  /// Un jour manqué : un protège-flamme, s'il y en a un, sauve la série.
  static PlayerState touchStreak(PlayerState player, DateTime now) {
    final today = dayKey(now);
    if (player.lastActiveDay == today) return player;
    final yesterday = dayKey(now.subtract(const Duration(days: 1)));
    final dayBefore = dayKey(now.subtract(const Duration(days: 2)));
    if (player.lastActiveDay == yesterday) {
      return player.copyWith(streak: player.streak + 1, lastActiveDay: today);
    }
    if (player.lastActiveDay == dayBefore && player.flameShields > 0) {
      return player.copyWith(streak: player.streak + 1, lastActiveDay: today, flameShields: player.flameShields - 1);
    }
    return player.copyWith(streak: 1, lastActiveDay: today);
  }

  // ---------------------------------------------------------------- Flamme du savoir

  /// Paliers de la flamme (jours d'affilée) et leurs cauris.
  static const flameMilestones = {3: 0, 7: 20, 30: 100, 100: 300};
  static const flameShieldPrice = 50;
  static const flameShieldMax = 2;

  /// Série affichée : elle tient tant que le joueur a joué hier ou aujourd'hui
  /// (ou avant-hier avec un protège-flamme).
  static int flameOf(PlayerState player, DateTime now) {
    final last = player.lastActiveDay;
    if (last == dayKey(now) || last == dayKey(now.subtract(const Duration(days: 1)))) return player.streak;
    if (last == dayKey(now.subtract(const Duration(days: 2))) && player.flameShields > 0) return player.streak;
    return 0;
  }

  /// La flamme est déjà nourrie aujourd'hui.
  static bool isFlameFed(PlayerState player, DateTime now) => player.lastActiveDay == dayKey(now);

  /// 0 : flamme simple, 1 : 7 jours, 2 : dorée (30), 3 : éternelle (100).
  static int flameTier(int streak) => streak >= 100 ? 3 : (streak >= 30 ? 2 : (streak >= 7 ? 1 : 0));

  /// Paliers atteints et pas encore fêtés : leurs cauris sont ajoutés.
  static (PlayerState, List<int>) claimFlameMilestones(PlayerState player) {
    final reached = [
      for (final m in flameMilestones.keys)
        if (player.streak >= m && !player.flameClaimed.contains(m)) m,
    ];
    if (reached.isEmpty) return (player, const []);
    final cauris = reached.fold<int>(0, (sum, m) => sum + flameMilestones[m]!);
    return (
      player.copyWith(cauris: player.cauris + cauris, flameClaimed: {...player.flameClaimed, ...reached}),
      reached,
    );
  }

  /// Achète un protège-flamme ; null s'il manque des cauris ou si la réserve est pleine.
  static PlayerState? buyFlameShield(PlayerState player, DateTime now) {
    if (player.flameShields >= flameShieldMax) return null;
    return spendCauris(player, flameShieldPrice, now)?.copyWith(flameShields: player.flameShields + 1);
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
    int quickAnswers = 0,
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
    final quick = passed ? quickAnswers * quickCauris : 0;
    final result = LevelResult(
      bestCorrect: previous == null || correct > previous.bestCorrect ? correct : previous.bestCorrect,
      total: total,
      passed: passed || (previous?.passed ?? false),
    );

    final challengesBefore = challengesFor(content, player).where((c) => isChallengeUnlocked(player, c)).map((c) => c.id).toSet();

    var next = gainXp(player, xpGained, now).copyWith(
      levels: {...player.levels, levelId: result},
      masteredActivities: {...player.masteredActivities, ...newlyMastered.map((a) => a.id)},
      cauris: player.cauris + chest + quick,
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
      quickCauris: quick,
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
    var next = gainXp(player, xpGained, now).copyWith(
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
      if (player.bossesBeaten.isNotEmpty) 'vainqueur-boss',
      if (player.streak >= 7) 'flamme-7',
      if (player.streak >= 30) 'flamme-30',
      if (player.streak >= 100) 'flamme-100',
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
    BadgeDef('vainqueur-boss', 'Vainqueur du Boss', 'Bats le Boss d\'une langue.', '👑'),
    BadgeDef('flamme-7', 'Gardien de la flamme', 'Garde ta flamme du savoir allumée 7 jours.', '🔥'),
    BadgeDef('flamme-30', 'Flamme dorée', 'Garde ta flamme allumée 30 jours.', '✨'),
    BadgeDef('flamme-100', 'Flamme éternelle', 'Garde ta flamme allumée 100 jours.', '🌟'),
  ];
}

enum DuelVerdict { win, loss, draw }

class BossOutcome {
  const BossOutcome({
    required this.player,
    required this.passed,
    required this.firstWin,
    required this.correct,
    required this.total,
    required this.cauris,
    required this.xpGained,
    required this.completedQuests,
    required this.newBadges,
  });

  final PlayerState player;
  final bool passed;

  /// Première victoire contre ce Boss.
  final bool firstWin;
  final int correct;
  final int total;
  final int cauris;
  final int xpGained;
  final List<QuestDef> completedQuests;
  final List<BadgeDef> newBadges;
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
    this.quickCauris = 0,
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

  /// Bonus éclair : cauris des bonnes réponses rapides.
  final int quickCauris;

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
