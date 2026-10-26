import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/game_rules.dart';
import '../models/content.dart';
import '../models/player.dart';
import 'backend.dart';
import 'contributions.dart';

/// Fournis dans main.dart via ProviderScope.overrides.
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());
final backendProvider = Provider<Backend>((ref) => throw UnimplementedError());
final bundledContentProvider = Provider<ContentPack>((ref) => throw UnimplementedError());

// ---------------------------------------------------------------------------
// Contenu
// ---------------------------------------------------------------------------

// Suffixe de version : un cache d'un ancien format n'est jamais relu.
const _contentCacheKey = 'content_cache_v2';

/// Contenu courant : dernier contenu distant mis en cache, sinon celui
/// embarqué dans l'app.
class ContentController extends Notifier<ContentPack> {
  @override
  ContentPack build() {
    final cached = ref.read(prefsProvider).getString(_contentCacheKey);
    if (cached != null) {
      try {
        return ContentPack.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      } catch (_) {}
    }
    return ref.read(bundledContentProvider);
  }

  Future<void> refresh() async {
    final remote = await ref.read(backendProvider).fetchContent();
    if (remote == null) return;
    await ref.read(prefsProvider).setString(_contentCacheKey, jsonEncode(remote));
    state = ContentPack.fromJson(remote);
  }
}

final contentProvider = NotifierProvider<ContentController, ContentPack>(ContentController.new);

// ---------------------------------------------------------------------------
// Analytics : file d'attente locale, envoyée à Supabase quand c'est possible.
// ---------------------------------------------------------------------------

const _eventsKey = 'pending_events';

class Analytics {
  Analytics(this._prefs, this._backend);

  final SharedPreferences _prefs;
  final Backend _backend;
  bool _flushing = false;

  void track(String name, [Map<String, dynamic> props = const {}]) {
    final pending = _prefs.getStringList(_eventsKey) ?? [];
    pending.add(jsonEncode({'name': name, 'props': props, 'client_time': DateTime.now().toUtc().toIso8601String()}));
    // Plafond pour ne pas remplir le stockage si le joueur reste hors-ligne.
    final trimmed = pending.length > 500 ? pending.sublist(pending.length - 500) : pending;
    _prefs.setStringList(_eventsKey, trimmed);
    flush();
  }

  Future<void> flush() async {
    if (_flushing || !_backend.enabled) return;
    _flushing = true;
    var addedMeanwhile = false;
    try {
      final pending = _prefs.getStringList(_eventsKey) ?? [];
      if (pending.isEmpty || !await _backend.ensureSession()) return;
      final events = pending.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
      if (await _backend.sendEvents(events)) {
        final remaining = (_prefs.getStringList(_eventsKey) ?? []).skip(pending.length).toList();
        await _prefs.setStringList(_eventsKey, remaining);
        addedMeanwhile = remaining.isNotEmpty;
      }
    } finally {
      _flushing = false;
    }
    // Des événements ont été ajoutés pendant l'envoi : on les envoie aussi.
    if (addedMeanwhile) await flush();
  }
}

final analyticsProvider = Provider<Analytics>((ref) => Analytics(ref.read(prefsProvider), ref.read(backendProvider)));

// ---------------------------------------------------------------------------
// Joueur
// ---------------------------------------------------------------------------

const _playerKey = 'player_state';

class PlayerController extends Notifier<PlayerState> {
  @override
  PlayerState build() {
    final raw = ref.read(prefsProvider).getString(_playerKey);
    if (raw == null) return PlayerState.initial();
    try {
      return PlayerState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return PlayerState.initial();
    }
  }

  Backend get _backend => ref.read(backendProvider);

  Analytics get _analytics => ref.read(analyticsProvider);

  ContentPack get _content => ref.read(contentProvider);

  Future<void> _save(PlayerState next, {bool sync = true}) async {
    state = next;
    await ref.read(prefsProvider).setString(_playerKey, jsonEncode(next.toJson()));
    if (sync) _pushRemote();
  }

  Future<void> _pushRemote() async {
    if (!state.onboarded || !await _backend.ensureSession()) return;
    await _backend.pushPlayer(state);
  }

  /// Au démarrage : récupère la progression distante si elle est plus
  /// récente (ex. connexion sur un nouveau téléphone), sinon envoie la locale.
  Future<void> syncOnStart() async {
    if (!await _backend.ensureSession()) return;
    final remote = await _backend.fetchPlayer();
    if (remote != null && (!state.onboarded || remote.updatedAt.isAfter(state.updatedAt))) {
      await _save(remote, sync: false);
    } else {
      await _pushRemote();
    }
  }

  /// Après connexion à un compte existant : la progression du compte remplace
  /// la progression locale.
  Future<void> pullAfterSignIn() async {
    final remote = await _backend.fetchPlayer();
    if (remote != null) {
      await _save(remote, sync: false);
    } else {
      await _pushRemote();
    }
  }

  Future<void> completeOnboarding({
    required String firstName,
    required String role,
    String? spokenLanguageId,
    String? village,
  }) async {
    await _save(state.copyWith(
      firstName: firstName.trim(),
      role: role,
      spokenLanguageId: spokenLanguageId,
      village: village?.trim().isEmpty ?? true ? null : village!.trim(),
      onboarded: true,
      updatedAt: DateTime.now(),
    ));
    _analytics.track('onboarding_completed', {'role': role, 'language': ?spokenLanguageId});
  }

  Future<void> setSpokenLanguage(String languageId) async {
    await _save(state.copyWith(spokenLanguageId: languageId, updatedAt: DateTime.now()));
  }

  /// Accord de l'aîné pour l'utilisation de sa voix, donné une seule fois.
  Future<void> giveConsent({required bool creditName}) async {
    await _save(state.copyWith(consentAt: DateTime.now(), creditName: creditName, updatedAt: DateTime.now()));
    _analytics.track('consent_given', {'credit_name': creditName});
  }

  Future<ChallengeOutcome> recordTransmission(String kind) async {
    final outcome = GameRules.recordTransmission(_content, state, kind, DateTime.now());
    await _save(outcome.player);
    for (final badge in outcome.newBadges) {
      _analytics.track('badge_earned', {'badge': badge.id});
    }
    return outcome;
  }

  /// Mauvaise réponse : retire une énergie et renvoie celle qui reste.
  Future<int> loseEnergy() async {
    final now = DateTime.now();
    await _save(GameRules.loseEnergy(state, now));
    final left = GameRules.energyAt(state, now);
    if (left == 0) _analytics.track('energy_empty');
    return left;
  }

  Future<LevelOutcome> completeLevel(
    String levelId, {
    required Set<String> askedIds,
    required Set<String> correctIds,
    bool outOfEnergy = false,
  }) async {
    final outcome = GameRules.completeLevel(
      content: _content,
      player: state,
      levelId: levelId,
      askedIds: askedIds,
      correctIds: correctIds,
      now: DateTime.now(),
      outOfEnergy: outOfEnergy,
    );
    await _save(outcome.player);
    _analytics.track('level_completed', {
      'level': levelId,
      'correct': outcome.correct,
      'total': outcome.total,
      'passed': outcome.passed,
      'xp_gained': outcome.xpGained,
      'out_of_energy': outOfEnergy,
    });
    for (final badge in outcome.newBadges) {
      _analytics.track('badge_earned', {'badge': badge.id});
    }
    return outcome;
  }

  Future<void> startChallenge(String challengeId) async {
    if (state.challenges.containsKey(challengeId)) return;
    await _save(state.copyWith(
      challenges: {...state.challenges, challengeId: const ChallengeProgress(status: ChallengeStatus.inProgress)},
      updatedAt: DateTime.now(),
    ));
    _analytics.track('challenge_started', {'challenge': challengeId});
  }

  Future<void> toggleChallengeStep(String challengeId, int step) async {
    final progress = state.challenges[challengeId];
    if (progress == null || progress.status == ChallengeStatus.done) return;
    final steps = {...progress.stepsDone};
    steps.contains(step) ? steps.remove(step) : steps.add(step);
    await _save(state.copyWith(
      challenges: {...state.challenges, challengeId: progress.copyWith(stepsDone: steps)},
      updatedAt: DateTime.now(),
    ));
  }

  Future<ChallengeOutcome> completeChallenge(String challengeId, {String? note, bool shareNote = false}) async {
    final outcome = GameRules.completeChallenge(
      content: _content,
      player: state,
      challengeId: challengeId,
      note: note,
      shareNote: shareNote,
      now: DateTime.now(),
    );
    await _save(outcome.player);
    _analytics.track('challenge_completed', {
      'challenge': challengeId,
      // La note n'est transmise que si le joueur a donné son accord.
      if (shareNote && note != null && note.isNotEmpty) 'note': note,
    });
    return outcome;
  }

  /// Efface la progression locale et ferme la session : la prochaine partie
  /// repart d'un nouveau joueur anonyme.
  Future<void> reset() async {
    await _backend.signOut();
    await ref.read(prefsProvider).remove(_playerKey);
    await ref.read(prefsProvider).remove('contributions');
    ref.invalidate(contributionsProvider);
    state = PlayerState.initial();
  }
}

final playerProvider = NotifierProvider<PlayerController, PlayerState>(PlayerController.new);
