/// Ligues de la semaine et duels : données reçues de Supabase.
library;

import 'avatar.dart';

/// Un joueur du groupe de ligue (prénom et avatar seulement).
class LeagueMember {
  const LeagueMember({required this.name, required this.points, required this.me, this.avatar});

  final String name;
  final int points;
  final bool me;
  final AvatarConfig? avatar;

  factory LeagueMember.fromJson(Map<String, dynamic> json) => LeagueMember(
    name: json['name'] as String? ?? '',
    points: (json['points'] as num?)?.toInt() ?? 0,
    me: json['me'] as bool? ?? false,
    avatar: json['avatar'] is Map ? AvatarConfig.fromJson((json['avatar'] as Map).cast<String, dynamic>()) : null,
  );
}

/// Bilan de la semaine précédente : place, et ligue de cette semaine.
class LeagueResult {
  const LeagueResult({
    required this.week,
    required this.tier,
    required this.rank,
    required this.size,
    required this.points,
    required this.newTier,
  });

  final String week;
  final int tier;
  final int rank;
  final int size;
  final int points;
  final int newTier;

  factory LeagueResult.fromJson(Map<String, dynamic> json) => LeagueResult(
    week: json['week'] as String,
    tier: (json['tier'] as num).toInt(),
    rank: (json['rank'] as num).toInt(),
    size: (json['size'] as num).toInt(),
    points: (json['points'] as num?)?.toInt() ?? 0,
    newTier: (json['new_tier'] as num).toInt(),
  );
}

/// Le groupe de ligue du joueur cette semaine, du premier au dernier.
class LeagueBoard {
  const LeagueBoard({required this.week, required this.tier, required this.members, this.previous});

  final String week;
  final int tier;
  final List<LeagueMember> members;
  final LeagueResult? previous;

  factory LeagueBoard.fromJson(Map<String, dynamic> json) => LeagueBoard(
    week: json['week'] as String,
    tier: (json['tier'] as num).toInt(),
    members: [for (final m in (json['members'] as List? ?? const [])) LeagueMember.fromJson((m as Map).cast<String, dynamic>())],
    previous: json['previous'] is Map ? LeagueResult.fromJson((json['previous'] as Map).cast<String, dynamic>()) : null,
  );
}

/// Partie de duel en direct (Tir à la corde ou Paires express) : les deux
/// joueurs construisent le même contenu avec la même graine.
class LiveMatch {
  const LiveMatch({
    required this.id,
    required this.mode,
    required this.languageId,
    required this.seed,
    required this.amA,
    required this.aName,
    this.aAvatar,
    this.code,
    this.hasB = false,
    this.bName,
    this.bAvatar,
  });

  final String id;

  /// 'corde' ou 'paires'.
  final String mode;
  final String languageId;
  final int seed;

  /// Code à 6 caractères d'un défi entre amis.
  final String? code;

  /// Le joueur de ce téléphone a créé la partie (ou attendait en file).
  final bool amA;
  final String aName;
  final AvatarConfig? aAvatar;
  final bool hasB;
  final String? bName;
  final AvatarConfig? bAvatar;

  String get opponentName => (amA ? bName : aName) ?? '';
  AvatarConfig? get opponentAvatar => amA ? bAvatar : aAvatar;

  factory LiveMatch.fromRow(Map<String, dynamic> r, String? userId) {
    AvatarConfig? avatar(Object? json) =>
        json is Map ? AvatarConfig.fromJson(json.cast<String, dynamic>()) : null;
    return LiveMatch(
      id: r['id'] as String,
      mode: r['mode'] as String,
      languageId: r['language_id'] as String,
      seed: (r['seed'] as num).toInt(),
      code: r['code'] as String?,
      amA: r['player_a'] == userId,
      aName: r['a_name'] as String? ?? '',
      aAvatar: avatar(r['a_avatar']),
      hasB: r['player_b'] != null,
      bName: r['b_name'] as String?,
      bAvatar: avatar(r['b_avatar']),
    );
  }
}
