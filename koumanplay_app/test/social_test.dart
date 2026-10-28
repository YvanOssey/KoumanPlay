import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:koumanplay/core/duel_games.dart';
import 'package:koumanplay/core/game_rules.dart';
import 'package:koumanplay/core/lesson.dart';
import 'package:koumanplay/models/content.dart';
import 'package:koumanplay/models/player.dart';
import 'package:koumanplay/models/social.dart';

void main() {
  final content = ContentPack.fromJson(
    jsonDecode(File('assets/content/content_v2.json').readAsStringSync()) as Map<String, dynamic>,
  );
  final now = DateTime.utc(2026, 10, 27, 12);
  PlayerState fresh() => PlayerState.initial().copyWith(firstName: 'Aya', onboarded: true, cauris: 10);
  final baoule = content.language('baoule')!;

  PlayerState allPassed(PlayerState p) => p.copyWith(
    levels: {
      for (final l in content.playableLevelsOf('baoule')) l.id: const LevelResult(bestCorrect: 5, total: 5, passed: true),
    },
  );

  group('Boss', () {
    test('ouvert seulement quand tous les niveaux de la langue sont validés', () {
      expect(GameRules.isBossUnlocked(content, fresh(), baoule), isFalse);
      expect(GameRules.isBossUnlocked(content, allPassed(fresh()), baoule), isTrue);
    });

    test('les questions viennent de la langue, sans dépasser le maximum', () {
      final questions = LessonBuilder.boss(content, 'baoule', random: Random(1));
      final ids = {for (final l in content.playableLevelsOf('baoule')) ...content.itemsOf(l.id).map((i) => i.id)};
      expect(questions, isNotEmpty);
      expect(questions.length, lessThanOrEqualTo(GameRules.bossQuestions));
      expect(questions.every((q) => ids.contains(q.itemId)), isTrue);
    });

    test('première victoire : XP, 50 cauris et badge ; ensuite 5 cauris ; défaite : rien', () {
      final p = allPassed(fresh());
      final win = GameRules.completeBoss(content: content, player: p, languageId: 'baoule', correct: 10, total: 12, now: now);
      expect(win.passed, isTrue);
      expect(win.firstWin, isTrue);
      expect(win.cauris, GameRules.bossFirstCauris);
      expect(win.player.xp, p.xp + GameRules.bossXp);
      expect(win.player.bossesBeaten, contains('baoule'));
      expect(win.player.badges, contains('vainqueur-boss'));

      final again = GameRules.completeBoss(content: content, player: win.player, languageId: 'baoule', correct: 12, total: 12, now: now);
      expect(again.firstWin, isFalse);
      expect(again.cauris, GameRules.bossReplayCauris);
      expect(again.xpGained, 0);

      final lost = GameRules.completeBoss(content: content, player: p, languageId: 'baoule', correct: 9, total: 12, now: now);
      expect(lost.passed, isFalse);
      expect(lost.cauris, 0);
      expect(lost.player.bossesBeaten, isEmpty);
    });
  });

  group('Ligues', () {
    test('semaine ISO comme le serveur', () {
      expect(GameRules.weekKey(DateTime.utc(2026, 1, 1)), '2026-W01');
      expect(GameRules.weekKey(DateTime.utc(2024, 12, 30)), '2025-W01');
      expect(GameRules.weekKey(DateTime.utc(2027, 1, 1)), '2026-W53');
      expect(GameRules.weekKey(now), '2026-W44');
      expect(GameRules.weekEnd(now), DateTime.utc(2026, 11, 2));
    });

    test("l'XP gagné compte pour la semaine, et repart de zéro le lundi", () {
      var p = GameRules.gainXp(fresh(), 30, now);
      p = GameRules.gainXp(p, 20, now);
      expect(GameRules.weeklyXp(p, now), 50);
      final nextWeek = now.add(const Duration(days: 7));
      expect(GameRules.weeklyXp(p, nextWeek), 0);
      expect(GameRules.weeklyXp(GameRules.gainXp(p, 10, nextWeek), nextWeek), 10);
      expect(GameRules.gainXp(p, 10, nextWeek).xp, 60);
    });

    test('un niveau réussi fait monter l\'XP de la semaine', () {
      final level = content.playableLevelsOf('baoule').first;
      final ids = content.itemsOf(level.id).map((i) => i.id).toSet();
      final outcome = GameRules.completeLevel(
        content: content,
        player: fresh(),
        levelId: level.id,
        askedIds: ids,
        correctIds: ids,
        now: now,
      );
      expect(GameRules.weeklyXp(outcome.player, now), outcome.xpGained);
    });

    test('podium : 30, 20, 10 cauris, une seule fois par semaine', () {
      final first = GameRules.claimLeagueReward(fresh(), week: '2026-W43', rank: 1, points: 120, now: now)!;
      expect(first.cauris, 10 + 30);
      expect(GameRules.claimLeagueReward(first, week: '2026-W43', rank: 1, points: 120, now: now), isNull);
      expect(GameRules.claimLeagueReward(fresh(), week: '2026-W43', rank: 4, points: 120, now: now)!.cauris, 10);
      expect(GameRules.claimLeagueReward(fresh(), week: '2026-W43', rank: 1, points: 0, now: now)!.cauris, 10);
    });

    test('le groupe reçu du serveur se lit', () {
      final board = LeagueBoard.fromJson({
        'week': '2026-W44',
        'tier': 1,
        'members': [
          {'name': 'Koffi', 'points': 120, 'me': false, 'avatar': null},
          {'name': 'Aya', 'points': 80, 'me': true, 'avatar': fresh().avatarOrDefault.toJson()},
        ],
        'previous': {'week': '2026-W43', 'tier': 0, 'rank': 2, 'size': 20, 'points': 300, 'new_tier': 1},
      });
      expect(board.members.last.me, isTrue);
      expect(board.members.last.avatar, isNotNull);
      expect(board.previous!.newTier, 1);
    });
  });

  group('Duels en direct', () {
    test('les deux joueurs reçoivent les mêmes cartes et paires', () {
      expect([for (final c in DuelContent.rope(content, 'baoule', 9)) c.meaning],
          [for (final c in DuelContent.rope(content, 'baoule', 9)) c.meaning]);
      final rounds = DuelContent.pairs(content, 'baoule', 9);
      expect(rounds.length, PairsRules.rounds);
      expect(rounds.every((r) => r.length == PairsRules.perRound), isTrue);
    });

    test("corde : 8 tirs d'avance gagnent, sinon le temps tranche", () {
      expect(RopeRules.verdict(10, 2, timeUp: false), DuelVerdict.win);
      expect(RopeRules.verdict(3, 2, timeUp: false), isNull);
      expect(RopeRules.verdict(3, 2, timeUp: true), DuelVerdict.win);
      expect(RopeRules.verdict(4, 4, timeUp: true), DuelVerdict.draw);
    });

    test('récompense donnée une seule fois par partie', () {
      final won = GameRules.claimDuelReward(fresh(), 'm1', DuelVerdict.win, now)!;
      expect(won.cauris, 10 + GameRules.duelWinCauris);
      expect(GameRules.claimDuelReward(won, 'm1', DuelVerdict.win, now), isNull);
    });
  });

  test('les nouveaux champs du joueur survivent à la sauvegarde', () {
    final p = GameRules.gainXp(fresh(), 40, now).copyWith(
      bossesBeaten: {'baoule'},
      leagueRewardWeek: '2026-W43',
      duelsRewarded: {'d1'},
    );
    final back = PlayerState.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
    expect(back.weekKey, '2026-W44');
    expect(back.weekXp, 40);
    expect(back.bossesBeaten, {'baoule'});
    expect(back.leagueRewardWeek, '2026-W43');
    expect(back.duelsRewarded, {'d1'});
  });
}
