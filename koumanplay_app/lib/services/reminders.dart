import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/game_rules.dart';
import '../models/player.dart';
import 'providers.dart';

/// Notifications de relance, programmées sur le téléphone (sans serveur) :
/// énergie pleine, rappel du jour à 18 h, et un message boudeur après un jour
/// manqué. Au plus une par jour ; reprogrammées chaque fois que le joueur
/// quitte l'app.
class Reminders {
  Reminders(this._prefs);

  final SharedPreferences _prefs;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _enabledKey = 'reminders_on';
  static const _askedKey = 'reminders_asked';
  static const _energyId = 1, _dailyId = 2, _missedId = 3;
  static const dailyHour = 18;

  bool get enabled => _prefs.getBool(_enabledKey) ?? true;

  Future<void> setEnabled(bool on) async {
    await _prefs.setBool(_enabledKey, on);
    if (on) {
      await askPermission();
    } else {
      await _init();
      if (_ready) await _plugin.cancelAll();
    }
  }

  Future<void> _init() async {
    if (_ready || kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_kouman')),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications indisponibles : $e');
    }
  }

  Future<void> askPermission() async {
    await _init();
    if (!_ready) return;
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Demande l'autorisation une seule fois, après la première partie.
  Future<void> askOnce() async {
    if (_prefs.getBool(_askedKey) ?? false) return;
    await _prefs.setBool(_askedKey, true);
    if (enabled) await askPermission();
  }

  /// Les relances à programmer pour [player], du plus tôt au plus tard.
  @visibleForTesting
  static List<({int id, DateTime at, String title, String body})> plan(PlayerState player, DateTime now) {
    final out = <({int id, DateTime at, String title, String body})>[];
    final today = DateTime(now.year, now.month, now.day);
    final fed = GameRules.isFlameFed(player, now);
    final flame = GameRules.flameOf(player, now);

    // Rappel du jour à 18 h : demain si le joueur a déjà joué aujourd'hui.
    var daily = today.add(Duration(hours: dailyHour));
    if (fed || !daily.isAfter(now)) daily = daily.add(const Duration(days: 1));
    out.add((
      id: _dailyId,
      at: daily,
      title: flame > 0 ? '🔥 La Flamme du savoir' : '🐘 C\'est l\'heure d\'apprendre',
      body: flame > 0
          ? '$flame jour${flame > 1 ? 's' : ''} d\'affilée ! Une petite partie pour garder ta flamme allumée ?'
          : 'Cinq minutes suffisent pour découvrir un nouveau proverbe avec l\'éléphanteau.',
    ));

    // Énergie pleine, sauf si le rappel du jour tombe le même jour.
    final missing = PlayerState.maxEnergy - GameRules.energyAt(player, now);
    final nextIn = GameRules.nextEnergyIn(player, now);
    if (missing > 0 && nextIn != null) {
      final full = now.add(nextIn + GameRules.energyRefill * (missing - 1));
      if (!_sameDay(full, daily)) {
        out.add((
          id: _energyId,
          at: full,
          title: '⚡ Énergie pleine !',
          body: 'L\'éléphanteau t\'attend : ton énergie est à fond pour un nouveau niveau.',
        ));
      }
    }

    // Jour manqué : le surlendemain du dernier jeu, à midi.
    final last = DateTime.tryParse(player.lastActiveDay ?? '');
    if (last != null) {
      final missed = DateTime(last.year, last.month, last.day + 2, 12);
      if (missed.isAfter(now) && !_sameDay(missed, daily)) {
        out.add((
          id: _missedId,
          at: missed,
          title: '😤 Hé, tu m\'as oublié hier…',
          body: player.flameShields > 0
              ? 'Ton protège-flamme sauve ta série aujourd\'hui. Viens vite jouer !'
              : player.streak > 1
              ? 'Ta flamme de ${player.streak} jours vacille. Reviens vite la rallumer !'
              : 'L\'éléphanteau boude un peu. Reviens jouer, il t\'attend !',
        ));
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// Remplace les relances programmées par celles de l'état actuel du joueur.
  Future<void> reschedule(PlayerState player) async {
    if (!player.onboarded) return;
    await _init();
    if (!_ready) return;
    await _plugin.cancelAll();
    if (!enabled) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'relance',
        'Rappels de jeu',
        channelDescription: 'Énergie pleine, Flamme du savoir, rappel du jour',
        icon: 'ic_stat_kouman',
        color: Color(0xFF5B2EFF),
      ),
    );
    for (final r in plan(player, DateTime.now())) {
      try {
        await _plugin.zonedSchedule(
          id: r.id,
          scheduledDate: tz.TZDateTime.from(r.at.toUtc(), tz.UTC),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: r.title,
          body: r.body,
        );
      } catch (e) {
        debugPrint('Relance non programmée : $e');
      }
    }
  }
}

final remindersProvider = Provider<Reminders>((ref) => Reminders(ref.read(prefsProvider)));
