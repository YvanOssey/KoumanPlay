import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koumanplay/core/game_rules.dart';
import 'package:koumanplay/models/content.dart';
import 'package:koumanplay/models/player.dart';
import 'package:koumanplay/services/reminders.dart';

void main() {
  final content = ContentPack.fromJson(
    jsonDecode(File('assets/content/content_v2.json').readAsStringSync()) as Map<String, dynamic>,
  );
  final now = DateTime(2026, 10, 28, 10);
  String day(int offset) => GameRules.dayKey(now.add(Duration(days: offset)));
  PlayerState player({int streak = 0, String? last, int shields = 0, int cauris = 100}) => PlayerState.initial()
      .copyWith(onboarded: true, streak: streak, lastActiveDay: last, flameShields: shields, cauris: cauris);

  group('Flamme du savoir', () {
    test('elle grandit chaque jour et s\'éteint après un jour manqué', () {
      expect(GameRules.touchStreak(player(streak: 4, last: day(-1)), now).streak, 5);
      expect(GameRules.touchStreak(player(streak: 4, last: day(0)), now).streak, 4);
      expect(GameRules.touchStreak(player(streak: 4, last: day(-2)), now).streak, 1);
    });

    test('un protège-flamme sauve la série après un seul jour manqué', () {
      final saved = GameRules.touchStreak(player(streak: 9, last: day(-2), shields: 1), now);
      expect(saved.streak, 10);
      expect(saved.flameShields, 0);
      expect(GameRules.touchStreak(player(streak: 9, last: day(-3), shields: 1), now).streak, 1);
    });

    test('la flamme affichée tient tant que le joueur a joué hier', () {
      expect(GameRules.flameOf(player(streak: 6, last: day(-1)), now), 6);
      expect(GameRules.flameOf(player(streak: 6, last: day(-2)), now), 0);
      expect(GameRules.flameOf(player(streak: 6, last: day(-2), shields: 1), now), 6);
    });

    test('chaque palier n\'est récompensé qu\'une fois', () {
      final (seven, reached) = GameRules.claimFlameMilestones(player(streak: 7, cauris: 0));
      expect(reached, [3, 7]);
      expect(seven.cauris, GameRules.flameMilestones[7]);
      expect(GameRules.claimFlameMilestones(seven).$2, isEmpty);
      final (_, at30) = GameRules.claimFlameMilestones(seven.copyWith(streak: 30));
      expect(at30, [30]);
    });

    test('7 jours donnent le badge Gardien de la flamme', () {
      expect(GameRules.evaluateBadges(content, player(streak: 7)).map((b) => b.id), contains('flamme-7'));
    });

    test('protège-flamme : 50 cauris, deux au plus', () {
      final one = GameRules.buyFlameShield(player(cauris: 120), now)!;
      expect(one.flameShields, 1);
      expect(one.cauris, 120 - GameRules.flameShieldPrice);
      expect(GameRules.buyFlameShield(player(cauris: 10), now), isNull);
      expect(GameRules.buyFlameShield(player(shields: 2), now), isNull);
    });
  });

  test('bonus éclair : un cauri par réponse rapide, si le niveau est validé', () {
    final level = content.playableLevelsOf('baoule').first;
    final ids = content.itemsOf(level.id).map((i) => i.id).toSet();
    LevelOutcome play(Set<String> correct) => GameRules.completeLevel(
      content: content,
      player: player(cauris: 0),
      levelId: level.id,
      askedIds: ids,
      correctIds: correct,
      now: now,
      quickAnswers: 3,
    );
    final won = play(ids);
    expect(won.quickCauris, 3 * GameRules.quickCauris);
    expect(won.player.cauris, won.chestCauris + won.quickCauris + won.completedQuests.fold<int>(0, (s, q) => s + q.reward));
    expect(play(const {}).quickCauris, 0);
  });

  group('Rappels', () {
    test('au plus une relance par jour, rappel à 18 h le lendemain si on a joué', () {
      final p = player(streak: 3, last: day(0)).copyWith(energy: 2, energySince: now);
      final plan = Reminders.plan(p, now);
      final days = plan.map((r) => GameRules.dayKey(r.at)).toList();
      expect(days.toSet().length, days.length);
      final daily = plan.firstWhere((r) => r.title.contains('Flamme'));
      expect(daily.at, DateTime(2026, 10, 29, 18));
      expect(plan.any((r) => r.title.contains('Énergie')), isTrue);
      expect(plan.any((r) => r.title.contains('oublié') && r.at == DateTime(2026, 10, 30, 12)), isTrue);
    });

    test('pas encore joué aujourd\'hui : rappel ce soir', () {
      final plan = Reminders.plan(player(streak: 2, last: day(-1)), now);
      expect(plan.first.at, DateTime(2026, 10, 28, 18));
    });
  });
}
