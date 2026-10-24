/// État du joueur, sauvegardé localement (hors-ligne) et synchronisé avec
/// Supabase quand une connexion est disponible.
library;

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
    this.village,
    this.consentAt,
    this.creditName = true,
    this.transmitted = const {},
  });

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

  /// Aîné : date de l'accord pour l'utilisation de sa voix (null = pas encore).
  final DateTime? consentAt;

  /// Aîné : accepte que son nom soit affiché avec ce qu'il transmet.
  final bool creditName;

  /// Nombre de transmissions par type ('mot', 'proverbe', 'conte').
  final Map<String, int> transmitted;

  int get transmittedTotal => transmitted.values.fold(0, (a, b) => a + b);

  bool get isSenior => role == 'senior';

  bool isLevelPassed(String levelId) => levels[levelId]?.passed ?? false;

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
    String? village,
    DateTime? consentAt,
    bool? creditName,
    Map<String, int>? transmitted,
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
        village: village ?? this.village,
        consentAt: consentAt ?? this.consentAt,
        creditName: creditName ?? this.creditName,
        transmitted: transmitted ?? this.transmitted,
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
        'village': village,
        'consentAt': consentAt?.toUtc().toIso8601String(),
        'creditName': creditName,
        'transmitted': transmitted,
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
        village: json['village'] as String?,
        consentAt: DateTime.tryParse(json['consentAt'] as String? ?? ''),
        creditName: json['creditName'] as bool? ?? true,
        transmitted: ((json['transmitted'] as Map?) ?? const {}).cast<String, int>(),
      );
}
