import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:koumanplay/core/game_rules.dart';
import 'package:koumanplay/core/lesson.dart';
import 'package:koumanplay/models/content.dart';
import 'package:koumanplay/models/contribution.dart';
import 'package:koumanplay/models/player.dart';

Map<String, dynamic> _json() =>
    jsonDecode(File('assets/content/content_v2.json').readAsStringSync()) as Map<String, dynamic>;

/// Contenu embarqué + des mots fictifs (marqués TEST) pour vérifier les
/// règles des niveaux de mots sans dépendre du contenu en collecte.
ContentPack _withTestWords(List<String> levelIds) {
  final json = _json();
  json['words'] = [
    for (final levelId in levelIds)
      for (var i = 1; i <= 5; i++)
        {'id': '$levelId-t$i', 'levelId': levelId, 'french': 'fr-$levelId-$i', 'local': 'TEST-$levelId-$i'},
  ];
  return ContentPack.fromJson(json);
}

void main() {
  final content = ContentPack.fromJson(_json());
  final now = DateTime(2026, 10, 22, 10);
  PlayerState fresh() => PlayerState.initial().copyWith(firstName: 'Aya', onboarded: true);
  Set<String> idsOf(ContentPack c, String levelId, [int? count]) =>
      c.itemsOf(levelId).take(count ?? 99).map((i) => i.id).toSet();
  LevelOutcome play(ContentPack c, PlayerState p, String levelId, {int? correct}) => GameRules.completeLevel(
        content: c,
        player: p,
        levelId: levelId,
        askedIds: idsOf(c, levelId),
        correctIds: idsOf(c, levelId, correct),
        now: now,
      );

  test('le contenu embarqué est cohérent', () {
    expect(content.languages.map((l) => l.id), ['baoule', 'bete', 'dioula', 'senoufo']);
    for (final language in content.languages) {
      expect(content.levelsOf(language.id), isNotEmpty, reason: language.id);
    }
    for (final a in content.activities) {
      expect(content.level(a.levelId)?.kind, LevelKind.proverbes, reason: a.id);
      expect(a.correct, inInclusiveRange(0, a.answers.length - 1), reason: a.id);
    }
    for (final c in content.challenges) {
      if (c.unlockAfterLevel != null) expect(content.level(c.unlockAfterLevel!), isNotNull, reason: c.id);
    }
    // Aucun mot n'est inventé : ils viennent de la collecte.
    expect(content.words, isEmpty);
  });

  test('sans mots collectés, seuls les proverbes du Baoulé sont jouables', () {
    final p = fresh();
    expect(content.isPlayable(content.level('baoule-1')!), isFalse);
    expect(GameRules.isLevelUnlocked(content, p, content.level('baoule-6')!), isTrue);
    expect(GameRules.isLevelUnlocked(content, p, content.level('baoule-7')!), isFalse);
    expect(GameRules.nextLevel(content, p)?.id, 'baoule-6');
  });

  test('valider un niveau donne XP, badges, défi et ouvre le suivant', () {
    final outcome = play(content, fresh(), 'baoule-6');
    expect(outcome.passed, isTrue);
    expect(outcome.xpGained, 100);
    expect(outcome.newBadges.map((b) => b.id), containsAll(['premiers-pas', 'passeur-de-sagesse', 'maitre-des-proverbes']));
    expect(outcome.unlockedChallenges.map((c) => c.id), ['jeune-proverbe-famille']);
    expect(GameRules.isLevelUnlocked(content, outcome.player, content.level('baoule-7')!), isTrue);
  });

  test('l\'étape suivante s\'ouvre quand l\'étape précédente est terminée', () {
    final c = _withTestWords(['baoule-1', 'bete-1']);
    final bete1 = c.level('bete-1')!;
    var p = fresh();
    expect(GameRules.isLevelUnlocked(c, p, bete1), isFalse);
    for (final id in ['baoule-1', 'baoule-6', 'baoule-7', 'baoule-8']) {
      p = play(c, p, id).player;
    }
    expect(GameRules.isLanguageCompleted(c, p, c.language('baoule')!), isTrue);
    expect(GameRules.isLevelUnlocked(c, p, bete1), isTrue);
    expect(p.badges, contains('etape-terminee'));
  });

  test('une étape sans contenu ne bloque pas les suivantes', () {
    final c = _withTestWords(['dioula-1']);
    var p = fresh();
    for (final id in ['baoule-6', 'baoule-7', 'baoule-8']) {
      p = play(c, p, id).player;
    }
    // Bété n'a aucun contenu : le Dioula s'ouvre directement après le Baoulé.
    expect(GameRules.isLevelUnlocked(c, p, c.level('dioula-1')!), isTrue);
  });

  test('un échec garde l\'XP mais ne valide pas', () {
    final outcome = play(content, fresh(), 'baoule-6', correct: 2);
    expect(outcome.passed, isFalse);
    expect(outcome.xpGained, 40);
    expect(outcome.player.isLevelPassed('baoule-6'), isFalse);
  });

  test('rejouer ne redonne pas d\'XP pour ce qui est déjà maîtrisé', () {
    final first = play(content, fresh(), 'baoule-6', correct: 3);
    final second = play(content, first.player, 'baoule-6');
    expect(second.xpGained, 40);
    expect(second.player.xp, 100);
  });

  test('les questions de mots ont 4 choix distincts et la bonne réponse', () {
    final c = _withTestWords(['baoule-1']);
    final questions = LessonBuilder.build(c, 'baoule-1', random: Random(1));
    expect(questions, hasLength(5));
    for (final q in questions) {
      final word = c.words.firstWhere((w) => w.id == q.itemId);
      expect(q.answers.toSet(), hasLength(4));
      final expected = q.prompt == word.french ? word.local : word.french;
      expect(q.answers[q.correct], expected);
    }
    // Les deux sens de traduction sont utilisés.
    expect(questions.map((q) => q.instruction).toSet(), hasLength(2));
  });

  test('les réponses des proverbes sont mélangées sans perdre la bonne', () {
    final questions = LessonBuilder.build(content, 'baoule-6', random: Random(3));
    for (final q in questions) {
      final activity = content.activities.firstWhere((a) => a.id == q.itemId);
      expect(q.answers[q.correct], activity.answers[activity.correct]);
    }
  });

  test('la série augmente les jours consécutifs et repart à 1 après une pause', () {
    var p = GameRules.touchStreak(fresh(), now);
    p = GameRules.touchStreak(p, now.add(const Duration(days: 1)));
    p = GameRules.touchStreak(p, now.add(const Duration(days: 2)));
    expect(p.streak, 3);
    expect(GameRules.evaluateBadges(content, p).map((b) => b.id), contains('regulier'));
    p = GameRules.touchStreak(p, now.add(const Duration(days: 5)));
    expect(p.streak, 1);
  });

  test('un défi ne rapporte son XP qu\'une fois', () {
    final first = GameRules.completeChallenge(
        content: content, player: fresh(), challengeId: 'jeune-proverbe-famille', note: 'Proverbe', shareNote: false, now: now);
    expect(first.xpGained, 100);
    expect(first.newBadges.map((b) => b.id), contains('pont-des-generations'));
    final again = GameRules.completeChallenge(
        content: content, player: first.player, challengeId: 'jeune-proverbe-famille', note: 'Proverbe', shareNote: false, now: now);
    expect(again.xpGained, 0);
  });

  test('les défis proposés dépendent du profil', () {
    final senior = fresh().copyWith(role: 'senior');
    expect(GameRules.challengesFor(content, senior).every((c) => c.isFor('senior')), isTrue);
  });

  test('l\'état joueur survit à la sérialisation', () {
    final outcome = play(content, fresh(), 'baoule-6', correct: 4);
    final restored = PlayerState.fromJson(jsonDecode(jsonEncode(outcome.player.toJson())) as Map<String, dynamic>);
    expect(restored.xp, outcome.player.xp);
    expect(restored.levels['baoule-6']!.bestCorrect, 4);
    expect(restored.badges, outcome.player.badges);
  });

  test("une transmission d'aîné donne XP et badges", () {
    var p = fresh().copyWith(role: 'senior', spokenLanguageId: 'baoule');
    final first = GameRules.recordTransmission(content, p, 'mot', now);
    expect(first.xpGained, 10);
    expect(first.newBadges.map((b) => b.id), contains('premiere-transmission'));
    p = first.player;
    final conte = GameRules.recordTransmission(content, p, 'conte', now);
    expect(conte.xpGained, 50);
    expect(conte.newBadges.map((b) => b.id), contains('conteur'));
    p = conte.player;
    for (var i = 0; i < 8; i++) {
      p = GameRules.recordTransmission(content, p, 'mot', now).player;
    }
    expect(p.transmittedTotal, 10);
    expect(p.badges, contains('gardien-de-la-parole'));
  });

  test("la liste de collecte suit le fichier CSV de l'équipe", () {
    final csv = File('content/collecte_mots.csv').readAsLinesSync().skip(1).where((l) => l.startsWith('baoule-'));
    final csvPrompts = [for (final l in csv) l.split(';')[2]];
    expect(collectPrompts.map((p) => p.french).toList(), csvPrompts);
    expect(collectPrompts.map((p) => p.id).toSet(), hasLength(collectPrompts.length));
  });

  test('une transmission et le profil aîné survivent à la sérialisation', () {
    final c = Contribution(
      id: 'x',
      kind: ContributionKind.proverbe,
      languageId: 'bete',
      audioPaths: const ['a.m4a', 'b.m4a'],
      createdAt: now,
      status: ContributionStatus.aEnvoyer,
      text: 'Traduction',
    );
    final back = Contribution.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.kind, ContributionKind.proverbe);
    expect(back.audioPaths, hasLength(2));
    expect(back.status, ContributionStatus.aEnvoyer);
    final p = fresh().copyWith(spokenLanguageId: 'bete', village: 'Gagnoa', consentAt: now, creditName: false, transmitted: {'mot': 3});
    final restored = PlayerState.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
    expect(restored.spokenLanguageId, 'bete');
    expect(restored.creditName, isFalse);
    expect(restored.consentAt, isNotNull);
    expect(restored.transmittedTotal, 3);
  });
}
