import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/game_rules.dart';
import '../models/avatar.dart';
import '../models/content.dart';
import '../models/player.dart';
import '../models/social.dart';
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
    final weekXpChanged = next.weekXp != state.weekXp || next.weekKey != state.weekKey;
    // Flamme du savoir : un palier atteint est récompensé et fêté.
    if (sync && next.streak > state.streak) {
      final (claimed, reached) = GameRules.claimFlameMilestones(next);
      if (reached.isNotEmpty) {
        next = claimed;
        ref.read(flameEventProvider.notifier).show(reached.last);
        _analytics.track('flame_milestone', {'days': reached.last});
      }
    }
    state = next;
    await ref.read(prefsProvider).setString(_playerKey, jsonEncode(next.toJson()));
    if (sync) _pushRemote();
    if (sync && weekXpChanged) syncLeague();
  }

  /// Envoie l'XP de la semaine à la ligue et renvoie le groupe du joueur.
  Future<LeagueBoard?> syncLeague() async {
    final now = DateTime.now();
    return _backend.syncLeague(
      week: GameRules.weekKey(now),
      points: GameRules.weeklyXp(state, now),
      name: state.firstName.isEmpty ? 'Joueur' : state.firstName,
      avatar: state.avatarOrDefault.toJson(),
    );
  }

  /// Podium de la semaine passée : renvoie les cauris reçus, ou null si la
  /// récompense avait déjà été donnée.
  Future<int?> claimLeagueReward(LeagueResult result) async {
    final next = GameRules.claimLeagueReward(state, week: result.week, rank: result.rank, points: result.points, now: DateTime.now());
    if (next == null) return null;
    final cauris = next.cauris - state.cauris;
    await _save(next);
    _analytics.track('league_week_ended', {'tier': result.tier, 'rank': result.rank, 'new_tier': result.newTier});
    return cauris;
  }

  /// Duel terminé : renvoie les cauris reçus, ou null si déjà donnés.
  Future<int?> claimDuelReward(String duelId, DuelVerdict verdict) async {
    final next = GameRules.claimDuelReward(state, duelId, verdict, DateTime.now());
    if (next == null) return null;
    await _save(next);
    _analytics.track('duel_finished', {'verdict': verdict.name});
    return GameRules.duelReward(verdict);
  }

  Future<BossOutcome> completeBoss(String languageId, {required int correct, required int total}) async {
    final outcome = GameRules.completeBoss(
      content: _content,
      player: state,
      languageId: languageId,
      correct: correct,
      total: total,
      now: DateTime.now(),
    );
    await _save(outcome.player);
    _analytics.track('boss_completed', {'language': languageId, 'correct': correct, 'total': total, 'passed': outcome.passed});
    for (final badge in outcome.newBadges) {
      _analytics.track('badge_earned', {'badge': badge.id});
    }
    return outcome;
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
    // Achats faits ailleurs (version web) ou terminés pendant que l'app était fermée.
    await refreshPurchases();
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
    String? learningLanguageId,
    String? village,
  }) async {
    await _save(state.copyWith(
      firstName: firstName.trim(),
      role: role,
      spokenLanguageId: spokenLanguageId,
      learningLanguageId: learningLanguageId,
      village: village?.trim().isEmpty ?? true ? null : village!.trim(),
      onboarded: true,
      updatedAt: DateTime.now(),
    ));
    _analytics.track('onboarding_completed', {
      'role': role,
      'language': ?spokenLanguageId,
      'learning': ?learningLanguageId,
    });
  }

  Future<void> setSpokenLanguage(String languageId) async {
    await _save(state.copyWith(spokenLanguageId: languageId, updatedAt: DateTime.now()));
  }

  /// Change la langue de la carte ; la progression de chaque langue est gardée.
  Future<void> setLearningLanguage(String languageId) async {
    if (languageId == state.learningLanguageId) return;
    await _save(state.copyWith(learningLanguageId: languageId, updatedAt: DateTime.now()));
    _analytics.track('language_changed', {'language': languageId});
  }

  /// Paie un indice en cauris ; false s'il n'y en a pas assez.
  Future<bool> spendCauris(int amount, {required String reason}) async {
    final next = GameRules.spendCauris(state, amount, DateTime.now());
    if (next == null) return false;
    await _save(next);
    _analytics.track('cauris_spent', {'amount': amount, 'reason': reason});
    return true;
  }

  Future<PracticeOutcome> completePractice({required Set<String> askedIds, required Set<String> correctIds}) async {
    final outcome = GameRules.completePractice(player: state, askedIds: askedIds, correctIds: correctIds, now: DateTime.now());
    await _save(outcome.player);
    _analytics.track('practice_completed', {'correct': outcome.correct, 'total': outcome.total});
    return outcome;
  }

  /// Débloque les pièces payantes de [avatar] avec des cauris, puis
  /// l'enregistre. False s'il n'y a pas assez de cauris.
  Future<bool> buyAndSetAvatar(AvatarConfig avatar) async {
    final now = DateTime.now();
    final cost = GameRules.avatarCost(state, avatar);
    if (cost > state.cauris) return false;
    var next = state;
    for (final item in avatar.items) {
      next = GameRules.buyItem(next, item, now)!;
    }
    await _save(next.copyWith(avatar: avatar, updatedAt: now));
    if (cost > 0) _analytics.track('avatar_items_bought', {'cauris': cost});
    _analytics.track('avatar_updated', {'hair': avatar.hair, 'outfit': avatar.outfit});
    return true;
  }

  /// Ajoute les achats en ligne livrés par le serveur. Renvoie les cauris reçus.
  Future<int> refreshPurchases() async {
    final purchases = await _backend.claimPurchases();
    if (purchases == null) return 0;
    final next = GameRules.applyPurchases(
      state,
      cauris: purchases.cauris,
      premiumUntil: purchases.premiumUntil,
      now: DateTime.now(),
    );
    if (!identical(next, state)) await _save(next);
    if (purchases.cauris > 0) _analytics.track('purchase_delivered', {'cauris': purchases.cauris});
    return purchases.cauris;
  }

  /// Protège-flamme payé en cauris ; false s'il en manque ou si la réserve est pleine.
  Future<bool> buyFlameShield() async {
    final next = GameRules.buyFlameShield(state, DateTime.now());
    if (next == null) return false;
    await _save(next);
    _analytics.track('flame_shield_bought');
    return true;
  }

  /// Boutique de démonstration : livre l'achat sur le téléphone, sans paiement.
  Future<void> applyDemoPurchase({required int cauris, required int premiumDays}) async {
    await _save(GameRules.applyDemoPurchase(state, cauris: cauris, premiumDays: premiumDays, now: DateTime.now()));
    _analytics.track('demo_purchase', {'cauris': cauris, 'premium_days': premiumDays});
  }

  Future<void> setAvatar(AvatarConfig avatar) async {
    await _save(state.copyWith(avatar: avatar, updatedAt: DateTime.now()));
    _analytics.track('avatar_updated', {'hair': avatar.hair, 'outfit': avatar.outfit});
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
    int correctAnswers = 0,
    int recallsWithoutHint = 0,
    int quickAnswers = 0,
  }) async {
    final outcome = GameRules.completeLevel(
      content: _content,
      player: state,
      levelId: levelId,
      askedIds: askedIds,
      correctIds: correctIds,
      now: DateTime.now(),
      outOfEnergy: outOfEnergy,
      correctAnswers: correctAnswers,
      recallsWithoutHint: recallsWithoutHint,
      quickAnswers: quickAnswers,
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

/// Palier de la Flamme du savoir à fêter (3, 7, 30 ou 100 jours), ou null.
class FlameEvent extends Notifier<int?> {
  @override
  int? build() => null;

  void show(int days) => state = days;

  void clear() => state = null;
}

final flameEventProvider = NotifierProvider<FlameEvent, int?>(FlameEvent.new);
