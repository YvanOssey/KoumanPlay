/// État du joueur, sauvegardé localement (hors-ligne) et synchronisé avec
/// Supabase quand une connexion est disponible.
library;

import 'avatar.dart';

enum ChallengeStatus { inProgress, done }

class ChallengeProgress {
  const ChallengeProgress({
    required this.status,
    this.stepsDone = const {},
    this.note,
    this.shareNote = false,
    this.completedAt,
  });

  final ChallengeStatus status;
  final Set<int> stepsDone;
  final String? note;

  /// Le joueur accepte que l'équipe réutilise sa note (après validation).
  final bool shareNote;
  final DateTime? completedAt;

  ChallengeProgress copyWith({
    ChallengeStatus? status,
    Set<int>? stepsDone,
    String? note,
    bool? shareNote,
    DateTime? completedAt,
  }) =>
      ChallengeProgress(
        status: status ?? this.status,
        stepsDone: stepsDone ?? this.stepsDone,
        note: note ?? this.note,
        shareNote: shareNote ?? this.shareNote,
        completedAt: completedAt ?? this.completedAt,
      );

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'stepsDone': stepsDone.toList(),
        'note': note,
        'shareNote': shareNote,
        'completedAt': completedAt?.toIso8601String(),
      };

  factory ChallengeProgress.fromJson(Map<String, dynamic> json) => ChallengeProgress(
        status: ChallengeStatus.values.byName(json['status'] as String? ?? 'inProgress'),
        stepsDone: ((json['stepsDone'] as List?) ?? const []).cast<int>().toSet(),
        note: json['note'] as String?,
        shareNote: json['shareNote'] as bool? ?? false,
        completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      );
}

class LevelResult {
  const LevelResult({required this.bestCorrect, required this.total, required this.passed});

  final int bestCorrect;
  final int total;
  final bool passed;

  bool get perfect => bestCorrect == total;

  Map<String, dynamic> toJson() => {'bestCorrect': bestCorrect, 'total': total, 'passed': passed};

  factory LevelResult.fromJson(Map<String, dynamic> json) => LevelResult(
        bestCorrect: json['bestCorrect'] as int? ?? 0,
        total: json['total'] as int? ?? 0,
        passed: json['passed'] as bool? ?? false,
      );
}

/// Quêtes du jour : avancement de chaque quête et celles déjà récompensées.
class QuestProgress {
  const QuestProgress({required this.day, this.progress = const {}, this.claimed = const {}});

  /// Jour (AAAA-MM-JJ) des quêtes : elles changent chaque jour.
  final String day;
  final Map<String, int> progress;
  final Set<String> claimed;

  Map<String, dynamic> toJson() => {'day': day, 'progress': progress, 'claimed': claimed.toList()};

  factory QuestProgress.fromJson(Map<String, dynamic> json) => QuestProgress(
    day: json['day'] as String? ?? '',
    progress: ((json['progress'] as Map?) ?? const {}).cast<String, int>(),
    claimed: ((json['claimed'] as List?) ?? const []).cast<String>().toSet(),
  );
}

class PlayerState {
  const PlayerState({
    required this.firstName,
    required this.role,
    required this.groupId,
    required this.onboarded,
    required this.xp,
    required this.levels,
    required this.masteredActivities,
    required this.challenges,
    required this.badges,
    required this.streak,
    required this.updatedAt,
    this.lastActiveDay,
    this.spokenLanguageId,
    this.learningLanguageId,
    this.village,
    this.consentAt,
    this.creditName = true,
    this.transmitted = const {},
    this.energy = maxEnergy,
    this.energySince,
    this.avatar,
    this.cauris = welcomeCauris,
    this.quests,
    this.toReview = const {},
    this.ownedItems = const {},
    this.premiumUntil,
    this.weekKey,
    this.weekXp = 0,
    this.bossesBeaten = const {},
    this.leagueRewardWeek,
    this.duelsRewarded = const {},
    this.flameShields = 0,
    this.flameClaimed = const {},
  });

  /// Énergie maximale ; une mauvaise réponse en coûte une.
  static const maxEnergy = 5;

  /// Cauris offerts au départ, pour pouvoir essayer les indices.
  static const welcomeCauris = 10;

  factory PlayerState.initial() => PlayerState(
        firstName: '',
        role: 'jeune',
        groupId: 'akan',
        onboarded: false,
        xp: 0,
        levels: const {},
        masteredActivities: const {},
        challenges: const {},
        badges: const {},
        streak: 0,
        updatedAt: DateTime.now(),
      );

  final String firstName;

  /// 'jeune' ou 'senior'.
  final String role;
  final String groupId;
  final bool onboarded;
  final int xp;
  final Map<String, LevelResult> levels;

  /// Activités déjà réussies une fois : elles ne rapportent plus d'XP.
  final Set<String> masteredActivities;
  final Map<String, ChallengeProgress> challenges;
  final Set<String> badges;
  final int streak;

  /// Jour (AAAA-MM-JJ) de la dernière activité, pour la série.
  final String? lastActiveDay;
  final DateTime updatedAt;

  /// Aîné : la langue qu'il parle et transmet, et son village.
  final String? spokenLanguageId;
  final String? village;

  /// Langue que le joueur a choisi d'apprendre : sa carte n'affiche qu'elle.
  final String? learningLanguageId;

  /// Aîné : date de l'accord pour l'utilisation de sa voix (null = pas encore).
  final DateTime? consentAt;

  /// Aîné : accepte que son nom soit affiché avec ce qu'il transmet.
  final bool creditName;

  /// Nombre de transmissions par type ('mot', 'proverbe', 'conte').
  final Map<String, int> transmitted;

  /// Énergie au moment [energySince] ; elle remonte ensuite avec le temps
  /// (voir GameRules.energyAt). [energySince] null = énergie pleine.
  final int energy;
  final DateTime? energySince;

  /// Avatar personnalisé ; null = avatar de départ selon le profil.
  final AvatarConfig? avatar;

  /// Cauris : gagnés en jouant (coffres, quêtes), dépensés en indices.
  final int cauris;

  /// Quêtes du jour ; null = pas encore commencées.
  final QuestProgress? quests;

  /// Questions ratées, à revoir en mode Entraînement.
  final Set<String> toReview;

  /// Pièces d'avatar débloquées avec des cauris (« type:id »).
  final Set<String> ownedItems;

  /// Fin de l'abonnement KoumanPlay+ (payé en ligne, donné par le serveur).
  final DateTime? premiumUntil;

  /// Semaine ISO (« 2026-W44 ») de [weekXp] : l'XP gagné cette semaine fait
  /// le classement de la ligue.
  final String? weekKey;
  final int weekXp;

  /// Langues dont le Boss a été battu.
  final Set<String> bossesBeaten;

  /// Dernière semaine de ligue dont la récompense a été reçue.
  final String? leagueRewardWeek;

  /// Duels terminés dont la récompense a été reçue.
  final Set<String> duelsRewarded;

  /// Flamme du savoir : protège-flammes en réserve (sauvent la série après
  /// un jour manqué) et paliers déjà récompensés (3, 7, 30, 100 jours).
  final int flameShields;
  final Set<int> flameClaimed;

  bool ownsItem(String item) => AvatarConfig.priceOf(item) == 0 || ownedItems.contains(item);

  AvatarConfig get avatarOrDefault => avatar ?? (isSenior ? AvatarConfig.elderDefault : AvatarConfig.youngDefault);

  int get transmittedTotal => transmitted.values.fold(0, (a, b) => a + b);

  bool get isSenior => role == 'senior';

  bool isLevelPassed(String levelId) => levels[levelId]?.passed ?? false;

  /// Niveaux validés : ils ouvrent l'accès aux événements culturels.
  int get levelsPassed => levels.values.where((l) => l.passed).length;

  PlayerState copyWith({
    String? firstName,
    String? role,
    String? groupId,
    bool? onboarded,
    int? xp,
    Map<String, LevelResult>? levels,
    Set<String>? masteredActivities,
    Map<String, ChallengeProgress>? challenges,
    Set<String>? badges,
    int? streak,
    String? lastActiveDay,
    DateTime? updatedAt,
    String? spokenLanguageId,
    String? learningLanguageId,
    String? village,
    DateTime? consentAt,
    bool? creditName,
    Map<String, int>? transmitted,
    int? energy,
    DateTime? energySince,
    AvatarConfig? avatar,
    int? cauris,
    QuestProgress? quests,
    Set<String>? toReview,
    Set<String>? ownedItems,
    DateTime? premiumUntil,
    String? weekKey,
    int? weekXp,
    Set<String>? bossesBeaten,
    String? leagueRewardWeek,
    Set<String>? duelsRewarded,
    int? flameShields,
    Set<int>? flameClaimed,
  }) =>
      PlayerState(
        firstName: firstName ?? this.firstName,
        role: role ?? this.role,
        groupId: groupId ?? this.groupId,
        onboarded: onboarded ?? this.onboarded,
        xp: xp ?? this.xp,
        levels: levels ?? this.levels,
        masteredActivities: masteredActivities ?? this.masteredActivities,
        challenges: challenges ?? this.challenges,
        badges: badges ?? this.badges,
        streak: streak ?? this.streak,
        lastActiveDay: lastActiveDay ?? this.lastActiveDay,
        updatedAt: updatedAt ?? this.updatedAt,
        spokenLanguageId: spokenLanguageId ?? this.spokenLanguageId,
        learningLanguageId: learningLanguageId ?? this.learningLanguageId,
        village: village ?? this.village,
        consentAt: consentAt ?? this.consentAt,
        creditName: creditName ?? this.creditName,
        transmitted: transmitted ?? this.transmitted,
        energy: energy ?? this.energy,
        energySince: energySince ?? this.energySince,
        avatar: avatar ?? this.avatar,
        cauris: cauris ?? this.cauris,
        quests: quests ?? this.quests,
        toReview: toReview ?? this.toReview,
        ownedItems: ownedItems ?? this.ownedItems,
        premiumUntil: premiumUntil ?? this.premiumUntil,
        weekKey: weekKey ?? this.weekKey,
        weekXp: weekXp ?? this.weekXp,
        bossesBeaten: bossesBeaten ?? this.bossesBeaten,
        leagueRewardWeek: leagueRewardWeek ?? this.leagueRewardWeek,
        duelsRewarded: duelsRewarded ?? this.duelsRewarded,
        flameShields: flameShields ?? this.flameShields,
        flameClaimed: flameClaimed ?? this.flameClaimed,
      );

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'role': role,
        'groupId': groupId,
        'onboarded': onboarded,
        'xp': xp,
        'levels': levels.map((k, v) => MapEntry(k, v.toJson())),
        'masteredActivities': masteredActivities.toList(),
        'challenges': challenges.map((k, v) => MapEntry(k, v.toJson())),
        'badges': badges.toList(),
        'streak': streak,
        'lastActiveDay': lastActiveDay,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'spokenLanguageId': spokenLanguageId,
        'learningLanguageId': learningLanguageId,
        'village': village,
        'consentAt': consentAt?.toUtc().toIso8601String(),
        'creditName': creditName,
        'transmitted': transmitted,
        'energy': energy,
        'energySince': energySince?.toUtc().toIso8601String(),
        'avatar': avatar?.toJson(),
        'cauris': cauris,
        'quests': quests?.toJson(),
        'toReview': toReview.toList(),
        'ownedItems': ownedItems.toList(),
        'premiumUntil': premiumUntil?.toUtc().toIso8601String(),
        'weekKey': weekKey,
        'weekXp': weekXp,
        'bossesBeaten': bossesBeaten.toList(),
        'leagueRewardWeek': leagueRewardWeek,
        'duelsRewarded': duelsRewarded.toList(),
        'flameShields': flameShields,
        'flameClaimed': flameClaimed.toList(),
      };

  factory PlayerState.fromJson(Map<String, dynamic> json) => PlayerState(
        firstName: json['firstName'] as String? ?? '',
        role: json['role'] as String? ?? 'jeune',
        groupId: json['groupId'] as String? ?? 'akan',
        onboarded: json['onboarded'] as bool? ?? false,
        xp: json['xp'] as int? ?? 0,
        levels: ((json['levels'] as Map?) ?? const {}).map(
          (k, v) => MapEntry(k as String, LevelResult.fromJson((v as Map).cast<String, dynamic>())),
        ),
        masteredActivities: ((json['masteredActivities'] as List?) ?? const []).cast<String>().toSet(),
        challenges: ((json['challenges'] as Map?) ?? const {}).map(
          (k, v) => MapEntry(k as String, ChallengeProgress.fromJson((v as Map).cast<String, dynamic>())),
        ),
        badges: ((json['badges'] as List?) ?? const []).cast<String>().toSet(),
        streak: json['streak'] as int? ?? 0,
        lastActiveDay: json['lastActiveDay'] as String?,
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
        spokenLanguageId: json['spokenLanguageId'] as String?,
        learningLanguageId: json['learningLanguageId'] as String?,
        village: json['village'] as String?,
        consentAt: DateTime.tryParse(json['consentAt'] as String? ?? ''),
        creditName: json['creditName'] as bool? ?? true,
        transmitted: ((json['transmitted'] as Map?) ?? const {}).cast<String, int>(),
        energy: json['energy'] as int? ?? maxEnergy,
        energySince: DateTime.tryParse(json['energySince'] as String? ?? ''),
        avatar: json['avatar'] is Map ? AvatarConfig.fromJson((json['avatar'] as Map).cast<String, dynamic>()) : null,
        // Anciens profils (avec diamants) : 5 cauris par niveau déjà validé.
        cauris: json['cauris'] as int? ??
            welcomeCauris + 5 * ((json['levels'] as Map?) ?? const {}).values.where((v) => (v as Map)['passed'] == true).length,
        quests: json['quests'] is Map ? QuestProgress.fromJson((json['quests'] as Map).cast<String, dynamic>()) : null,
        toReview: ((json['toReview'] as List?) ?? const []).cast<String>().toSet(),
        // Profils d'avant la boutique : les pièces déjà portées restent acquises.
        ownedItems: json['ownedItems'] is List
            ? (json['ownedItems'] as List).cast<String>().toSet()
            : json['avatar'] is Map
            ? AvatarConfig.fromJson((json['avatar'] as Map).cast<String, dynamic>()).items
            : const {},
        premiumUntil: DateTime.tryParse(json['premiumUntil'] as String? ?? ''),
        weekKey: json['weekKey'] as String?,
        weekXp: json['weekXp'] as int? ?? 0,
        bossesBeaten: ((json['bossesBeaten'] as List?) ?? const []).cast<String>().toSet(),
        leagueRewardWeek: json['leagueRewardWeek'] as String?,
        duelsRewarded: ((json['duelsRewarded'] as List?) ?? const []).cast<String>().toSet(),
        flameShields: json['flameShields'] as int? ?? 0,
        flameClaimed: ((json['flameClaimed'] as List?) ?? const []).cast<int>().toSet(),
      );
}
