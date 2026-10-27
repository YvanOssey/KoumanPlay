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
      expect(content.level(a.levelId)?.hasActivities, isTrue, reason: a.id);
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
    expect(
      outcome.newBadges.map((b) => b.id),
      containsAll(['premiers-pas', 'passeur-de-sagesse', 'maitre-des-proverbes']),
    );
    expect(outcome.unlockedChallenges.map((c) => c.id), ['jeune-proverbe-famille']);
    expect(GameRules.isLevelUnlocked(content, outcome.player, content.level('baoule-7')!), isTrue);
  });

  test('la carte suit la langue choisie, chacune avec sa propre progression', () {
    final c = _withTestWords(['bete-1']);
    var p = fresh().copyWith(learningLanguageId: 'bete');
    expect(GameRules.learningLanguage(c, p)?.id, 'bete');
    // Toutes les langues sont ouvertes : le Bété commence par ses proverbes.
    expect(GameRules.nextLevel(c, p)?.id, 'bete-6');
    p = play(c, p, 'bete-6').player;
    expect(GameRules.nextLevel(c, p)?.id, 'bete-1');
    p = play(c, p, 'bete-1').player;
    expect(GameRules.nextLevel(c, p), isNull);
    // Retour au Baoulé : rien n'a été perdu ni validé à sa place.
    p = p.copyWith(learningLanguageId: 'baoule');
    expect(GameRules.nextLevel(c, p)?.id, 'baoule-6');
    expect(p.isLevelPassed('bete-1'), isTrue);
  });

  test("sans langue choisie, l'aîné voit sa langue et le jeune la première qui a du contenu", () {
    expect(GameRules.learningLanguage(content, fresh())?.id, 'baoule');
    final elder = fresh().copyWith(role: 'senior', spokenLanguageId: 'dioula');
    expect(GameRules.learningLanguage(content, elder)?.id, 'dioula');
  });

  test('terminer une langue donne le badge Première étape', () {
    var p = fresh();
    for (final level in content.playableLevelsOf('baoule')) {
      p = play(content, p, level.id).player;
    }
    expect(GameRules.isLanguageCompleted(content, p, content.language('baoule')!), isTrue);
    expect(p.badges, contains('etape-terminee'));
  });

  test('le coffre donne 5 cauris par nouvelle étoile, puis un petit bonus en rejouant', () {
    final start = fresh().cauris;
    final first = play(content, fresh(), 'baoule-6');
    expect(first.stars, 3);
    expect(first.chestCauris, 3 * GameRules.chestPerStar);
    expect(first.player.cauris, greaterThanOrEqualTo(start + 15));
    final again = play(content, first.player, 'baoule-6');
    expect(again.chestCauris, GameRules.chestReplay);
    final failed = play(content, fresh(), 'baoule-6', correct: 1);
    expect(failed.stars, 0);
    expect(failed.chestCauris, 0);
  });

  test('étoiles : 3 pour un sans-faute, 2 dès 80 %, 1 pour un niveau juste validé', () {
    expect(GameRules.stars(5, 5, passed: true), 3);
    expect(GameRules.stars(4, 5, passed: true), 2);
    expect(GameRules.stars(5, 7, passed: true), 1);
    expect(GameRules.stars(4, 5, passed: false), 0);
  });

  test('les questions ratées partent en entraînement, qui rend énergie et cauris', () {
    final failed = play(content, fresh(), 'baoule-6', correct: 2);
    expect(failed.player.toReview, hasLength(3));
    final tired = GameRules.loseEnergy(GameRules.loseEnergy(failed.player, now), now);
    final asked = tired.toReview;
    final practice = GameRules.completePractice(player: tired, askedIds: asked, correctIds: {asked.first}, now: now);
    expect(practice.player.toReview, hasLength(2));
    expect(practice.player.cauris, greaterThanOrEqualTo(tired.cauris + GameRules.practiceCauris));
    expect(GameRules.energyAt(practice.player, now), GameRules.energyAt(tired, now) + 1);
    final questions = LessonBuilder.practice(content, practice.player.toReview, const {}, random: Random(1));
    expect(questions.map((q) => q.itemId).toSet(), practice.player.toReview);
    expect(questions.any((q) => q.isRecall), isFalse);
  });

  test('les quêtes du jour sont 3, fixes pour un jour, et donnent leurs cauris une fois', () {
    final day = GameRules.dayKey(now);
    final quests = GameRules.questsOfDay(day);
    expect(quests, hasLength(3));
    expect(quests.map((q) => q.id).toSet(), hasLength(3));
    expect(GameRules.questsOfDay(day).map((q) => q.id), quests.map((q) => q.id));
    final quest = quests.first;
    final (done, completed) = GameRules.progressQuests(fresh(), now, {quest.id: quest.target});
    expect(completed.map((q) => q.id), [quest.id]);
    expect(done.cauris, fresh().cauris + quest.reward);
    final (again, none) = GameRules.progressQuests(done, now, {quest.id: quest.target});
    expect(none, isEmpty);
    expect(again.cauris, done.cauris);
    // Le lendemain, tout repart à zéro.
    final (tomorrow, _) = GameRules.progressQuests(again, now.add(const Duration(days: 1)), const {});
    expect(tomorrow.quests?.claimed, isEmpty);
  });

  test('un indice se paie en cauris, et pas à crédit', () {
    final p = fresh().copyWith(cauris: 3);
    expect(GameRules.spendCauris(p, GameRules.hintLetterCost, now)?.cauris, 1);
    expect(GameRules.spendCauris(p, GameRules.hintWordCost, now), isNull);
  });

  test("la réponse écrite tolère majuscules, accents et une petite faute", () {
    expect(TypedAnswer.matches("L'œil n'a pas sommeil", "l'œil n'a pas sommeil"), isTrue);
    expect(TypedAnswer.matches('loeil na pas sommeil', "l'œil n'a pas sommeil"), isTrue);
    expect(TypedAnswer.matches("l'œil a sommeil", "l'œil n'a pas sommeil"), isFalse);
    expect(TypedAnswer.matches("l’oeil n'a pas sommeil.", "l'œil n'a pas sommeil"), isTrue);
    expect(TypedAnswer.matches('se brisse', 'se brise'), isTrue);
    expect(TypedAnswer.matches('se casse', 'se brise'), isFalse);
    expect(TypedAnswer.matches('', 'se brise'), isFalse);
  });

  test('les indices révèlent une lettre ou un mot', () {
    const answer = 'le dernier mot';
    expect(TypedAnswer.nextLetter(answer, 0), 1);
    expect(TypedAnswer.nextWord(answer, 0), 2);
    expect(TypedAnswer.nextLetter(answer, 2), 4);
    expect(TypedAnswer.nextWord(answer, 2), 10);
    expect(TypedAnswer.mask(answer, 2), 'le  _______  ___');
  });

  test('un ancien profil avec diamants reçoit 5 cauris par niveau validé', () {
    final old =
        fresh().copyWith(levels: {'baoule-6': const LevelResult(bestCorrect: 5, total: 5, passed: true)}).toJson()
          ..remove('cauris');
    expect(PlayerState.fromJson(old).cauris, PlayerState.welcomeCauris + 5);
  });

  test('participer aux événements demande assez de niveaux validés et de niveau', () {
    final json = _json()
      ..['settings'] = {'eventMinDiamonds': 2, 'eventMinLevel': 2}
      ..['events'] = [
        {'id': 'e1', 'title': 'Test', 'startsAt': '2026-12-01T18:00:00Z'},
        {'id': 'e2', 'title': 'Test exigeant', 'startsAt': '2026-12-02T18:00:00Z', 'minDiamonds': 3},
      ];
    final c = ContentPack.fromJson(json);
    var p = fresh();
    expect(GameRules.isEventEligible(c, p), isFalse);
    p = play(c, p, 'baoule-6').player;
    p = play(c, p, 'baoule-7').player;
    expect(p.levelsPassed, 2);
    expect(GameRules.playerLevel(p.xp), 2);
    expect(GameRules.isEventEligible(c, p, c.event('e1')), isTrue);
    // Un événement peut demander plus que le seuil général.
    expect(GameRules.isEventEligible(c, p, c.event('e2')), isFalse);
    // Assez de niveaux validés mais pas le niveau de joueur : pas encore.
    expect(GameRules.isEventEligible(c, p.copyWith(xp: 0)), isFalse);
    // Les cauris n'achètent pas une place.
    expect(GameRules.isEventEligible(c, fresh().copyWith(cauris: 9999, xp: 1000)), isFalse);
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
    for (final q in questions.where((q) => !q.isRecall)) {
      final activity = content.activities.firstWhere((a) => a.id == q.itemId);
      expect(q.answers[q.correct], activity.answers[activity.correct]);
    }
  });

  test('un niveau de proverbes finit par des rappels « complète le proverbe »', () {
    final questions = LessonBuilder.build(content, 'baoule-6', random: Random(5));
    final recalls = questions.where((q) => q.isRecall).toList();
    expect(recalls, hasLength(LessonBuilder.recallQuestions));
    expect(questions.skip(questions.length - recalls.length).every((q) => q.isRecall), isTrue);
    for (final q in recalls) {
      final proverb = content.activities.firstWhere((a) => a.id == q.itemId).proverb;
      final (start, end) = LessonBuilder.splitProverb(proverb)!;
      expect(q.prompt, '$start …');
      expect(q.expected, end);
      expect(q.answers, isEmpty);
    }
  });

  test('un proverbe se coupe à la ponctuation, ou au milieu', () {
    expect(LessonBuilder.splitProverb("Quand le doigt fait mal, l'œil n'a pas sommeil."), (
      'Quand le doigt fait mal,',
      "l'œil n'a pas sommeil",
    ));
    expect(LessonBuilder.splitProverb('Le pardon est le dernier mot.'), ('Le pardon est', 'le dernier mot'));
    expect(LessonBuilder.splitProverb("L'amour appelle l'amour."), isNull);
    // Jamais coupé juste après un petit mot : « face au … » trahirait la réponse.
    expect(LessonBuilder.splitProverb("L'arbre seul face au vent se brise."), (
      "L'arbre seul face au vent",
      'se brise',
    ));
  });

  test('les mauvaises réponses ne répètent jamais la bonne', () {
    for (final a in content.activities) {
      expect(a.answers.toSet(), hasLength(a.answers.length), reason: a.id);
    }
    expect(content.levels.every((l) => l.passRatio >= 0.7), isTrue);
  });

  test('les trésors sont jouables et ne sont pas présentés comme des proverbes', () {
    final level = content.level('baoule-12')!;
    expect(level.kind, LevelKind.tresors);
    expect(content.isPlayable(level), isTrue);
    final questions = LessonBuilder.build(content, level.id, random: Random(3));
    expect(questions, isNotEmpty);
    for (final q in questions) {
      expect(q.isProverb, isFalse);
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
      content: content,
      player: fresh(),
      challengeId: 'jeune-proverbe-famille',
      note: 'Proverbe',
      shareNote: false,
      now: now,
    );
    expect(first.xpGained, 100);
    expect(first.newBadges.map((b) => b.id), contains('pont-des-generations'));
    final again = GameRules.completeChallenge(
      content: content,
      player: first.player,
      challengeId: 'jeune-proverbe-famille',
      note: 'Proverbe',
      shareNote: false,
      now: now,
    );
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
    final p = fresh().copyWith(
      spokenLanguageId: 'bete',
      village: 'Gagnoa',
      consentAt: now,
      creditName: false,
      transmitted: {'mot': 3},
    );
    final restored = PlayerState.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
    expect(restored.spokenLanguageId, 'bete');
    expect(restored.creditName, isFalse);
    expect(restored.consentAt, isNotNull);
    expect(restored.transmittedTotal, 3);
  });

  test('le parcours commence au niveau 1, par les proverbes', () {
    for (final language in content.languages) {
      final levels = content.levelsOf(language.id);
      expect(levels.map((l) => l.order), List.generate(levels.length, (i) => i + 1), reason: language.id);
    }
    final first = GameRules.nextLevel(content, fresh())!;
    expect(first.order, 1);
    expect(first.kind, LevelKind.proverbes);
  });

  test("une mauvaise réponse coûte une énergie, qui revient toutes les 15 minutes", () {
    var p = fresh();
    expect(GameRules.energyAt(p, now), 5);
    expect(GameRules.nextEnergyIn(p, now), isNull);
    p = GameRules.loseEnergy(p, now);
    expect(GameRules.energyAt(p, now), 4);
    expect(GameRules.nextEnergyIn(p, now), const Duration(minutes: 15));
    // Deux erreurs 5 minutes plus tard : le compte à rebours continue.
    final t5 = now.add(const Duration(minutes: 5));
    p = GameRules.loseEnergy(GameRules.loseEnergy(p, t5), t5);
    expect(GameRules.energyAt(p, t5), 2);
    expect(GameRules.nextEnergyIn(p, t5), const Duration(minutes: 10));
    expect(GameRules.energyAt(p, now.add(const Duration(minutes: 15))), 3);
    expect(GameRules.energyAt(p, now.add(const Duration(minutes: 45))), 5);
    expect(GameRules.nextEnergyIn(p, now.add(const Duration(minutes: 45))), isNull);
  });

  test("à 0 énergie on ne perd plus rien, et tout revient en 75 minutes", () {
    var p = fresh();
    for (var i = 0; i < 7; i++) {
      p = GameRules.loseEnergy(p, now);
    }
    expect(GameRules.energyAt(p, now), 0);
    expect(GameRules.energyAt(p, now.add(const Duration(minutes: 74))), 4);
    expect(GameRules.energyAt(p, now.add(const Duration(minutes: 75))), 5);
    final restored = PlayerState.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
    expect(GameRules.energyAt(restored, now), 0);
  });

  test("les mauvaises réponses ne rapportent pas d'XP", () {
    final level = GameRules.nextLevel(content, fresh())!;
    final none = GameRules.completeLevel(
      content: content,
      player: fresh(),
      levelId: level.id,
      askedIds: idsOf(content, level.id),
      correctIds: const {},
      now: now,
      outOfEnergy: true,
    );
    expect(none.xpGained, 0);
    expect(none.passed, isFalse);
    expect(none.outOfEnergy, isTrue);
  });
}
