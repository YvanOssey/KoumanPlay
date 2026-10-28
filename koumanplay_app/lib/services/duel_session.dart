import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/duel_games.dart';
import '../core/game_rules.dart';
import '../models/avatar.dart';
import 'backend.dart';
import 'providers.dart';

/// L'adversaire d'un duel en direct, vu par le jeu : son nom, son avatar et
/// son score qui avance pendant la partie.
abstract class Opponent {
  Opponent({required this.name, required this.avatar});

  final String name;
  final AvatarConfig avatar;

  /// Tirs (corde) ou paires trouvées (paires express).
  final score = ValueNotifier<int>(0);

  /// L'adversaire a quitté la partie ou ne répond plus.
  final left = ValueNotifier<bool>(false);

  /// Début de la partie (après le compte à rebours), une fois les deux
  /// joueurs prêts.
  final startAt = ValueNotifier<DateTime?>(null);

  Future<void> connect();

  /// Envoie le score du joueur de ce téléphone.
  void report(int myScore);

  /// La partie est finie : plus rien n'avance.
  void stop();

  @mustCallSuper
  void dispose() {
    stop();
    score.dispose();
    left.dispose();
    startAt.dispose();
  }
}

/// Adversaire réel, relié par un canal Supabase Realtime (« duel:`id` »).
/// Le joueur A fixe le départ dès qu'il reçoit le bonjour de B.
class LiveOpponent extends Opponent {
  LiveOpponent(this._backend, this.matchId, {required this.amA, required super.name, required super.avatar});

  final Backend _backend;
  final String matchId;
  final bool amA;
  RealtimeChannel? _channel;
  Timer? _hello;
  Timer? _heartbeat;
  DateTime _lastSeen = DateTime.now();
  int _myScore = 0;
  bool _stopped = false;

  static const _countdown = Duration(milliseconds: 3500);

  /// Sans nouvelles de l'adversaire pendant ce temps, il a quitté.
  static const _silence = Duration(seconds: 12);

  Map<String, dynamic> _data(Map<String, dynamic> message) =>
      (message['payload'] as Map?)?.cast<String, dynamic>() ?? message;

  void _send(String event, [Map<String, dynamic> payload = const {}]) {
    _channel?.sendBroadcastMessage(event: event, payload: payload);
  }

  void _seen() => _lastSeen = DateTime.now();

  @override
  Future<void> connect() async {
    final channel = _backend.duelChannel(matchId);
    if (channel == null) {
      left.value = true;
      return;
    }
    _channel = channel
      ..onBroadcast(
        event: 'hello',
        callback: (message) {
          _seen();
          if (amA && startAt.value == null) {
            startAt.value = DateTime.now().add(_countdown);
            _send('start', {'in': _countdown.inMilliseconds});
          } else if (amA) {
            // B n'a pas reçu le départ : on le renvoie avec le temps restant.
            final remaining = startAt.value!.difference(DateTime.now()).inMilliseconds;
            _send('start', {'in': max(0, remaining)});
          }
        },
      )
      ..onBroadcast(
        event: 'start',
        callback: (message) {
          _seen();
          final inMs = (_data(message)['in'] as num?)?.toInt() ?? _countdown.inMilliseconds;
          startAt.value ??= DateTime.now().add(Duration(milliseconds: inMs));
        },
      )
      ..onBroadcast(
        event: 'progress',
        callback: (message) {
          _seen();
          final value = (_data(message)['score'] as num?)?.toInt() ?? 0;
          if (value > score.value) score.value = value;
        },
      )
      ..onBroadcast(
        event: 'bye',
        callback: (_) {
          if (!_stopped) left.value = true;
        },
      )
      ..subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) _send('hello');
      });
    // Le bonjour est répété jusqu'au départ, au cas où l'autre n'écoutait pas encore.
    _hello = Timer.periodic(const Duration(seconds: 1), (_) {
      if (startAt.value != null && !amA) {
        _hello?.cancel();
        return;
      }
      if (startAt.value == null) _send('hello');
    });
    // Signe de vie pendant la partie, et détection d'un adversaire parti.
    _heartbeat = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_stopped) return;
      _send('progress', {'score': _myScore});
      if (DateTime.now().difference(_lastSeen) > _silence) left.value = true;
    });
  }

  @override
  void report(int myScore) {
    _myScore = myScore;
    _send('progress', {'score': myScore});
  }

  @override
  void stop() {
    if (_stopped) return;
    _stopped = true;
    _hello?.cancel();
    _heartbeat?.cancel();
    _send('progress', {'score': _myScore});
  }

  /// Quitte le canal ; [quit] : prévient l'adversaire qu'on abandonne.
  Future<void> close({bool quit = false}) async {
    if (quit) _send('bye');
    stop();
    final channel = _channel;
    _channel = null;
    if (channel != null) await channel.unsubscribe();
  }

  @override
  void dispose() {
    close();
    super.dispose();
  }
}

/// Adversaire joué par l'app quand personne n'est disponible : il répond
/// avec un temps et une justesse tirés au sort, comme un joueur moyen.
class BotOpponent extends Opponent {
  BotOpponent({required this.mode, required super.name, required super.avatar, Random? random})
    : _rng = random ?? Random(),
      skill = BotSkill(random ?? Random());

  final DuelMode mode;
  final BotSkill skill;
  final Random _rng;
  Timer? _next;
  bool _stopped = false;

  @override
  Future<void> connect() async {
    await Future<void>.delayed(Duration(milliseconds: 400 + _rng.nextInt(900)));
    startAt.value = DateTime.now().add(LiveOpponent._countdown);
    _next = Timer(LiveOpponent._countdown + skill.nextDelay(_rng), _act);
  }

  void _act() {
    if (_stopped) return;
    final delay = skill.nextDelay(_rng);
    final success = _rng.nextDouble() < skill.accuracy;
    if (success) {
      score.value += switch (mode) {
        DuelMode.corde => RopeRules.strength(delay),
        DuelMode.paires => 1,
      };
    }
    final pause = success ? delay : delay + (mode == DuelMode.corde ? RopeRules.penalty : PairsRules.penalty);
    if (mode == DuelMode.paires && score.value >= PairsRules.total) return;
    _next = Timer(pause, _act);
  }

  @override
  void report(int myScore) {}

  @override
  void stop() {
    _stopped = true;
    _next?.cancel();
  }
}

/// Tout ce qu'il faut pour lancer une partie.
class MatchSetup {
  const MatchSetup({
    required this.mode,
    required this.languageId,
    required this.seed,
    required this.opponent,
    this.matchId,
  });

  final DuelMode mode;
  final String languageId;
  final int seed;
  final Opponent opponent;

  /// Partie enregistrée sur le serveur (adversaire réel) ; null sinon.
  final String? matchId;

  /// Identifiant pour la récompense, donnée une seule fois par partie.
  String get rewardId => matchId ?? 'local-$seed';
}

/// Un duel terminé, gardé sur le téléphone pour l'historique.
class DuelRecord {
  const DuelRecord({
    required this.mode,
    required this.opponent,
    required this.verdict,
    required this.at,
    required this.score,
  });

  final DuelMode mode;
  final String opponent;
  final DuelVerdict verdict;
  final DateTime at;

  /// Score du joueur et de l'adversaire, ex. « 9 – 4 ».
  final String score;

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'opponent': opponent,
    'verdict': verdict.name,
    'at': at.toIso8601String(),
    'score': score,
  };

  factory DuelRecord.fromJson(Map<String, dynamic> json) => DuelRecord(
    mode: DuelMode.values.asNameMap()[json['mode']] ?? DuelMode.corde,
    opponent: json['opponent'] as String? ?? '',
    verdict: DuelVerdict.values.asNameMap()[json['verdict']] ?? DuelVerdict.draw,
    at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
    score: json['score'] as String? ?? '',
  );
}

const _historyKey = 'duel_history';

class DuelHistory extends Notifier<List<DuelRecord>> {
  @override
  List<DuelRecord> build() {
    final raw = ref.read(prefsProvider).getStringList(_historyKey) ?? const [];
    return [for (final r in raw) ?_parse(r)];
  }

  static DuelRecord? _parse(String raw) {
    try {
      return DuelRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> add(DuelRecord record) async {
    state = [record, ...state].take(20).toList();
    await ref.read(prefsProvider).setStringList(_historyKey, [for (final r in state) jsonEncode(r.toJson())]);
  }
}

final duelHistoryProvider = NotifierProvider<DuelHistory, List<DuelRecord>>(DuelHistory.new);
