import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/game_rules.dart';
import '../../core/lesson.dart';
import '../../core/theme.dart';
import '../../models/content.dart';
import '../../services/providers.dart';
import '../../services/reminders.dart';
import '../../widgets/audio_button.dart';
import '../../widgets/cauris.dart';
import '../../widgets/common.dart';
import '../../widgets/energy.dart';
import '../../widgets/fx.dart';
import '../../widgets/mascot.dart';

/// [practice] : sur les questions ratées, sans perte d'énergie.
/// [boss] : défi final d'une langue, chronométré.
enum QuizMode { level, practice, boss }

/// Une partie : un niveau, un entraînement ou un Boss.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.levelId, this.mode = QuizMode.level});

  /// Niveau joué ; pour un Boss, la langue.
  final String levelId;
  final QuizMode mode;

  bool get practice => mode == QuizMode.practice;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  late final List<LessonQuestion> _questions;
  late final Level? _level;
  late final Language? _language;
  int _index = 0;
  int? _selected;
  bool _submitted = false;
  bool _finishing = false;

  /// Plus d'énergie au lancement : on ne joue pas.
  late final bool _blocked;

  /// L'énergie est tombée à 0 pendant la partie : elle s'arrête.
  bool _outOfEnergy = false;

  // Un élément (mot, proverbe) est réussi s'il a été vu et qu'aucune de ses
  // questions n'a été ratée : un rappel manqué fait échouer le proverbe.
  final _seenIds = <String>{};
  final _missedIds = <String>{};

  /// Pour les quêtes du jour.
  int _correctAnswers = 0;
  int _recallsWithoutHint = 0;

  /// Rappel : réponse écrite et nombre de lettres révélées par les indices.
  final _typed = TextEditingController();
  int _revealed = 0;
  bool _hinted = false;
  bool _lastCorrect = false;

  final _scroll = ScrollController();

  /// Temps restant pour la question : imposé au Boss (temps écoulé = erreur),
  /// indicatif dans un niveau (une réponse rapide rapporte un bonus éclair).
  Timer? _clock;
  int _secondsLeft = 0;
  int _timeLimit = 0;
  bool _timedOut = false;
  final _answerTime = Stopwatch();

  /// Animations : confettis (bonne réponse, victoire du Boss), secousse (erreur).
  int _cheers = 0;
  int _shakes = 0;
  int _wins = 0;

  bool get _timed => widget.mode == QuizMode.boss;
  bool get _soft => widget.mode == QuizMode.level;

  /// Mascotte : humeur, réaction (change à chaque réponse) et bulle.
  MascotMood _mood = MascotMood.idle;
  int _reaction = 0;
  String? _bubble;
  int _wrongStreak = 0;
  final _rng = Random();

  /// Bonnes réponses rapides (au moins la moitié du temps restant).
  int _quick = 0;

  static const _cheersText = ['Bravo !', 'Exactement !', 'Tu as l\'œil !', 'Les aînés seraient fiers !', 'Bien joué !'];
  static const _comfort = ['Pas grave, lis bien l\'explication.', 'On apprend de ses erreurs !', 'Presque ! Tu y es.'];
  static const _tips = [
    'Lis tout le proverbe : son sens est souvent dans la deuxième moitié.',
    'Nos proverbes parlent souvent de famille, de travail et de patience. Pense à la vie de tous les jours.',
    'Écarte d\'abord les réponses qui prennent le proverbe au pied de la lettre.',
    'Pas de panique : l\'entraînement te fait réviser sans perdre d\'énergie.',
  ];

  /// Seuls les niveaux et le Boss coûtent de l'énergie.
  bool get _costsEnergy => widget.mode == QuizMode.level || widget.mode == QuizMode.boss;

  @override
  void dispose() {
    _clock?.cancel();
    _scroll.dispose();
    _typed.dispose();
    super.dispose();
  }

  void _startClock() {
    if ((!_timed && !_soft) || _questions.isEmpty) return;
    _clock?.cancel();
    _timeLimit = _current.isRecall
        ? GameRules.bossRecallSeconds
        : (_timed ? GameRules.bossSeconds : GameRules.levelSeconds);
    _secondsLeft = _timeLimit;
    _answerTime.start();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _submitted) return;
      setState(() => _secondsLeft--);
      // Les dernières secondes s'entendent et se sentent.
      if (_secondsLeft > 0 && _secondsLeft <= 5) {
        ref.read(soundProvider).play('tick');
        HapticFeedback.selectionClick();
      }
      if (_secondsLeft <= 0) {
        if (_timed) {
          _submit(timeUp: true);
        } else {
          _clock?.cancel();
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final content = ref.read(contentProvider);
    final player = ref.read(playerProvider);
    if (widget.mode == QuizMode.boss) {
      _level = null;
      _language = content.language(widget.levelId);
      final unlocked = _language != null && GameRules.isBossUnlocked(content, player, _language);
      _questions = unlocked ? LessonBuilder.boss(content, widget.levelId) : const [];
      _blocked = GameRules.energyAt(player, DateTime.now()) == 0;
    } else if (widget.practice) {
      _level = null;
      _language = null;
      final passed = {
        for (final e in player.levels.entries)
          if (e.value.passed) e.key,
      };
      _questions = LessonBuilder.practice(content, player.toReview, passed);
      _blocked = false;
    } else {
      _level = content.level(widget.levelId);
      _language = _level == null ? null : content.language(_level.languageId);
      _questions = LessonBuilder.build(content, widget.levelId);
      _blocked = GameRules.energyAt(player, DateTime.now()) == 0;
    }
    _typed.addListener(() => setState(() {}));
    ref.read(analyticsProvider).track('${widget.mode.name}_started', {'level': widget.levelId});
    if (!_blocked) _startClock();
  }

  LessonQuestion get _current => _questions[_index];

  bool get _canSubmit => _current.isRecall ? _typed.text.trim().isNotEmpty : _selected != null;

  /// [timeUp] : le temps de la question est écoulé, la réponse compte fausse.
  void _submit({bool timeUp = false}) {
    if (_submitted) return;
    _clock?.cancel();
    _answerTime.stop();
    final question = _current;
    final correct =
        !timeUp &&
        (question.isRecall ? TypedAnswer.matches(_typed.text, question.expected!) : _selected == question.correct);
    // Décidé tout de suite, pour que « Question suivante » ne s'affiche pas
    // sur la dernière énergie.
    final costsEnergy = _costsEnergy && !correct;
    final lastEnergy = costsEnergy && GameRules.energyAt(ref.read(playerProvider), DateTime.now()) <= 1;
    ref
        .read(soundProvider)
        .cheer(
          correct ? 'correct' : 'wrong',
          content: ref.read(contentProvider),
          languageId: _language?.id,
          voiceChance: 0.35,
        );
    final quick = correct && _soft && _secondsLeft * 2 >= _timeLimit;
    _wrongStreak = correct ? 0 : _wrongStreak + 1;
    final tip = !correct && _wrongStreak >= 2;
    HapticFeedback.lightImpact();
    setState(() {
      if (correct) {
        _cheers++;
      } else {
        _shakes++;
      }
      if (quick) _quick++;
      _reaction++;
      _mood = correct ? MascotMood.happy : MascotMood.sad;
      _bubble = correct
          ? (quick ? 'Éclair ! Réponse rapide.' : _cheersText[_rng.nextInt(_cheersText.length)])
          : (timeUp ? 'Le temps est passé…' : _comfort[_rng.nextInt(_comfort.length)]);
      _submitted = true;
      _timedOut = timeUp;
      _lastCorrect = correct;
      _seenIds.add(question.itemId);
      if (!correct) _missedIds.add(question.itemId);
      if (correct) _correctAnswers++;
      if (correct && question.isRecall && !_hinted) _recallsWithoutHint++;
      if (lastEnergy) _outOfEnergy = true;
    });
    FocusScope.of(context).unfocus();
    ref.read(analyticsProvider).track('answer', {
      'activity': question.itemId,
      'correct': correct,
      'recall': question.isRecall,
      'hinted': _hinted,
      'mode': widget.mode.name,
      'time_up': timeUp,
    });
    if (costsEnergy) ref.read(playerProvider.notifier).loseEnergy();
    // Deux erreurs de suite : la mascotte donne un conseil.
    if (tip) {
      Timer(const Duration(milliseconds: 1100), () {
        if (!mounted || !_submitted) return;
        setState(() {
          _mood = MascotMood.talk;
          _bubble = _tips[_rng.nextInt(_tips.length)];
        });
      });
    }
    // Fait apparaître l'explication si elle est sous le bas de l'écran.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Indice payé en cauris : révèle une lettre ou un mot de la réponse.
  Future<void> _hint({required bool word}) async {
    final expected = _current.expected!;
    final cost = word ? GameRules.hintWordCost : GameRules.hintLetterCost;
    final paid = await ref.read(playerProvider.notifier).spendCauris(cost, reason: word ? 'hint_word' : 'hint_letter');
    if (!mounted) return;
    if (!paid) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Pas assez de cauris. Gagne-en avec les coffres et les quêtes du jour.')),
        );
      return;
    }
    setState(() {
      _hinted = true;
      _revealed = word ? TypedAnswer.nextWord(expected, _revealed) : TypedAnswer.nextLetter(expected, _revealed);
      _typed.text = expected.substring(0, _revealed);
      _typed.selection = TextSelection.collapsed(offset: _typed.text.length);
    });
  }

  Future<void> _next() async {
    if (!_outOfEnergy && _index < _questions.length - 1) {
      setState(() {
        _index++;
        _selected = null;
        _submitted = false;
        _revealed = 0;
        _hinted = false;
        _timedOut = false;
        _typed.clear();
        _mood = _questions[_index].isRecall ? MascotMood.think : MascotMood.idle;
        _bubble = _questions[_index].isRecall ? 'Souviens-toi de la fin du proverbe…' : null;
      });
      _scroll.jumpTo(0);
      _startClock();
      return;
    }
    setState(() => _finishing = true);
    final notifier = ref.read(playerProvider.notifier);
    final asked = {for (final q in _questions) q.itemId};
    if (widget.mode == QuizMode.boss) {
      final outcome = await notifier.completeBoss(widget.levelId, correct: _correctAnswers, total: _questions.length);
      if (!mounted) return;
      ref
          .read(soundProvider)
          .cheer(outcome.passed ? 'win' : 'lose', content: ref.read(contentProvider), languageId: widget.levelId);
      if (outcome.passed) setState(() => _wins++);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _BossDone(outcome: outcome),
      );
      if (mounted) context.pop();
      return;
    }
    if (widget.practice) {
      final outcome = await notifier.completePractice(askedIds: asked, correctIds: _seenIds.difference(_missedIds));
      if (!mounted) return;
      ref.read(soundProvider).play('win');
      await showDialog<void>(
        context: context,
        builder: (_) => _PracticeDone(outcome: outcome),
      );
      if (mounted) context.pop();
      return;
    }
    final outcome = await notifier.completeLevel(
      widget.levelId,
      askedIds: asked,
      correctIds: _seenIds.difference(_missedIds),
      outOfEnergy: _outOfEnergy,
      correctAnswers: _correctAnswers,
      recallsWithoutHint: _recallsWithoutHint,
      quickAnswers: _quick,
    );
    // Après la première partie : autorisation des rappels de jeu.
    ref.read(remindersProvider).askOnce();
    if (mounted) context.pushReplacement('/result', extra: outcome);
  }

  Future<void> _confirmQuit() async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter la partie ?'),
        content: const Text('Ta progression ne sera pas enregistrée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuer')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Quitter')),
        ],
      ),
    );
    if (quit == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty || (widget.mode == QuizMode.level && _level == null)) {
      return Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(switch (widget.mode) {
              QuizMode.practice => 'Valide un premier niveau pour débloquer l\'entraînement.',
              QuizMode.boss => 'Valide tous les niveaux de cette langue pour affronter le Boss.',
              QuizMode.level => 'Ce niveau n\'est pas encore disponible.',
            }, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    if (_blocked) {
      return Scaffold(
        appBar: AppBar(),
        body: const Padding(
          padding: EdgeInsets.all(AppSpacing.screen),
          child: Center(child: OutOfEnergyDialog()),
        ),
      );
    }
    final theme = Theme.of(context);
    final question = _current;
    final color = _language == null ? AppColors.purple500 : Color(_language.color);
    final eyebrow = switch (widget.mode) {
      QuizMode.practice => 'Entraînement · sans perte d\'énergie',
      QuizMode.boss => '${_language?.name ?? ''} · Boss',
      QuizMode.level => '${_language?.name ?? ''} · Niveau ${_level!.order} · ${_level.kindLabel}',
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuit();
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, AppSpacing.screen, 0),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: _confirmQuit),
                    Expanded(
                      child: KpProgressBar(value: (_index + (_submitted ? 1 : 0)) / _questions.length, color: color),
                    ),
                    const SizedBox(width: 12),
                    Text('${_index + 1}/${_questions.length}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 10),
                    _ScoreChip(score: _correctAnswers),
                    const SizedBox(width: 8),
                    if (widget.mode != QuizMode.practice) const EnergyPill(showWait: false),
                  ],
                ),
              ),
              if (_timed || _soft)
                _TimeBar(secondsLeft: _secondsLeft, limit: _timeLimit, running: !_submitted && !_blocked, hard: _timed),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(AppSpacing.screen),
                        children: [
                          Row(
                            children: [
                              Expanded(child: Eyebrow(eyebrow, color: color)),
                              if (widget.mode == QuizMode.level)
                                Text(
                                  '+${question.xp} XP',
                                  style: const TextStyle(color: AppColors.green500, fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (question.isProverb) ...[
                            _PromptCard(question: question),
                            const SizedBox(height: 20),
                            Text(question.instruction, style: theme.textTheme.titleLarge),
                          ] else ...[
                            Text(question.instruction, style: theme.textTheme.titleLarge),
                            const SizedBox(height: 16),
                            _PromptCard(question: question),
                          ],
                          const SizedBox(height: 16),
                          Shake(
                            trigger: _shakes,
                            child: question.isRecall
                                ? _RecallInput(
                                    controller: _typed,
                                    expected: question.expected!,
                                    revealed: _revealed,
                                    submitted: _submitted,
                                    correct: _lastCorrect,
                                    onSubmit: _canSubmit && !_submitted ? _submit : null,
                                    onHintLetter: () => _hint(word: false),
                                    onHintWord: () => _hint(word: true),
                                  )
                                : Column(
                                    children: [
                                      for (var i = 0; i < question.answers.length; i++) ...[
                                        _AnswerTile(
                                          letter: String.fromCharCode(65 + i),
                                          text: question.answers[i],
                                          state: _answerState(i),
                                          onTap: _submitted ? null : () => setState(() => _selected = i),
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                    ],
                                  ),
                          ),
                          if (_submitted)
                            _Feedback(
                              correct: _lastCorrect,
                              question: question,
                              outOfEnergy: _outOfEnergy,
                              costsEnergy: _costsEnergy,
                              timedOut: _timedOut,
                            ),
                        ],
                      ),
                    ),
                    Positioned.fill(child: ConfettiBurst(trigger: _cheers)),
                    Positioned.fill(child: ConfettiBurst(trigger: _wins, big: true)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 4, AppSpacing.screen, 0),
                child: SizedBox(
                  height: 72,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Mascot(mood: _mood, reaction: _reaction, size: 64),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _bubble == null
                                ? const SizedBox.shrink()
                                : Padding(
                                    key: ValueKey(_bubble),
                                    padding: const EdgeInsets.only(bottom: 22),
                                    child: MascotBubble(text: _bubble!),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 8, AppSpacing.screen, AppSpacing.screen),
                child: FilledButton(
                  onPressed: _finishing
                      ? null
                      : !_submitted
                      ? (_canSubmit ? _submit : null)
                      : _next,
                  child: Text(
                    !_submitted
                        ? 'Valider ma réponse'
                        : !_outOfEnergy && _index < _questions.length - 1
                        ? 'Question suivante'
                        : widget.practice
                        ? 'Terminer l\'entraînement'
                        : 'Voir mon résultat',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _AnswerState _answerState(int i) {
    if (!_submitted) return i == _selected ? _AnswerState.selected : _AnswerState.idle;
    if (i == _current.correct) return _AnswerState.correct;
    if (i == _selected) return _AnswerState.wrong;
    return _AnswerState.idle;
  }
}

/// Rappel : gabarit des lettres, champ de saisie et indices payants.
class _RecallInput extends ConsumerWidget {
  const _RecallInput({
    required this.controller,
    required this.expected,
    required this.revealed,
    required this.submitted,
    required this.correct,
    required this.onSubmit,
    required this.onHintLetter,
    required this.onHintWord,
  });

  final TextEditingController controller;
  final String expected;
  final int revealed;
  final bool submitted;
  final bool correct;
  final VoidCallback? onSubmit;
  final VoidCallback onHintLetter;
  final VoidCallback onHintWord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cauris = ref.watch(playerProvider.select((p) => p.cauris));
    final complete = revealed >= expected.length;
    final border = !submitted ? AppColors.purple500 : (correct ? AppColors.green500 : AppColors.error);
    Widget hintButton(String label, int cost, VoidCallback onTap) => Expanded(
      child: OutlinedButton(
        onPressed: submitted || complete || cauris < cost ? null : onTap,
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(width: 6),
              const CauriIcon(size: 16),
              Text(' $cost', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          TypedAnswer.mask(expected, revealed),
          style: const TextStyle(fontSize: 18, letterSpacing: 2, fontWeight: FontWeight.w600, color: AppColors.gray700),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          enabled: !submitted,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit?.call(),
          decoration: InputDecoration(
            hintText: 'Écris la suite du proverbe',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
              borderSide: BorderSide(color: border, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
              borderSide: BorderSide(color: border, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Bloqué ?', style: TextStyle(color: AppColors.gray500)),
            const Spacer(),
            CauriPill(cauris: cauris),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            hintButton('Une lettre', GameRules.hintLetterCost, onHintLetter),
            const SizedBox(width: 10),
            hintButton('Un mot', GameRules.hintWordCost, onHintWord),
          ],
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

/// Fin d'un entraînement : bilan, cauris et énergie regagnés.
class _PracticeDone extends StatelessWidget {
  const _PracticeDone({required this.outcome});

  final PracticeOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final questCauris = outcome.completedQuests.fold<int>(0, (s, q) => s + q.reward);
    return AlertDialog(
      icon: const Icon(Icons.autorenew_rounded, color: AppColors.purple500, size: 40),
      title: const Text('Entraînement terminé'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${outcome.correct} bonnes réponses sur ${outcome.total}.', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CauriIcon(size: 20),
              Text(
                ' +${outcome.cauris + questCauris}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: caurisColor),
              ),
              if (outcome.energyGained > 0) ...[
                const SizedBox(width: 16),
                const Icon(Icons.bolt_rounded, color: AppColors.purple500),
                Text(
                  '+${outcome.energyGained}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.purple500),
                ),
              ],
            ],
          ),
          for (final q in outcome.completedQuests) ...[
            const SizedBox(height: 8),
            Text(
              'Quête terminée : ${q.title}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.green500),
            ),
          ],
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Super !'))],
    );
  }
}

/// Le proverbe (entre guillemets) ou le mot/la phrase à traduire.
class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.question});

  final LessonQuestion question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(AppRadius.largeCard)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (question.isProverb)
                  const Text(
                    '“',
                    style: TextStyle(fontSize: 40, height: 0.8, color: AppColors.gold, fontWeight: FontWeight.w700),
                  ),
                Text(
                  question.prompt,
                  style: question.isProverb
                      ? theme.textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic)
                      : theme.textTheme.headlineSmall,
                ),
                if (question.subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(question.subtitle!, style: const TextStyle(color: AppColors.gray700, fontSize: 13)),
                ],
              ],
            ),
          ),
          if (question.audio != null) AudioButton(source: question.audio!),
        ],
      ),
    );
  }
}

enum _AnswerState { idle, selected, correct, wrong }

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({required this.letter, required this.text, required this.state, this.onTap});

  final String letter;
  final String text;
  final _AnswerState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (border, background, badge) = switch (state) {
      _AnswerState.idle => (AppColors.gray200, AppColors.white, AppColors.gray100),
      _AnswerState.selected => (AppColors.purple500, AppColors.purple100, AppColors.purple500),
      _AnswerState.correct => (AppColors.green500, AppColors.green100, AppColors.green500),
      _AnswerState.wrong => (AppColors.error, AppColors.errorLight, AppColors.error),
    };
    final badgeText = state == _AnswerState.idle ? AppColors.gray700 : AppColors.white;
    return TweenAnimationBuilder<double>(
      key: ValueKey(state),
      tween: Tween(begin: state == _AnswerState.correct ? 1.06 : 1, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.button),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.button),
              border: Border.all(color: border, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: badge, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    letter,
                    style: TextStyle(color: badgeText, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.correct,
    required this.question,
    required this.outOfEnergy,
    required this.costsEnergy,
    this.timedOut = false,
  });

  final bool correct;
  final LessonQuestion question;
  final bool outOfEnergy;
  final bool timedOut;

  /// Entraînement : une erreur ne coûte pas d'énergie.
  final bool costsEnergy;

  @override
  Widget build(BuildContext context) {
    final color = correct ? AppColors.green500 : AppColors.error;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: correct ? AppColors.green100 : AppColors.errorLight,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(correct ? Icons.check_circle_rounded : Icons.info_rounded, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    correct ? 'Bonne réponse !' : (timedOut ? 'Temps écoulé' : 'Pas tout à fait'),
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  if (!correct)
                    Text(
                      'La bonne réponse était : ${question.expected ?? question.answers[question.correct]}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  const SizedBox(height: 4),
                  Text(question.explanation, style: const TextStyle(color: AppColors.gray700)),
                  if (!correct && costsEnergy) ...[
                    const SizedBox(height: 6),
                    Text(
                      outOfEnergy ? '−1 énergie : tu n\'en as plus, la partie s\'arrête ici.' : '−1 énergie',
                      style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fin d'un Boss : victoire ou non, récompenses et badge.
class _BossDone extends StatelessWidget {
  const _BossDone({required this.outcome});

  final BossOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final questCauris = outcome.completedQuests.fold<int>(0, (s, q) => s + q.reward);
    final cauris = outcome.cauris + questCauris;
    final needed = (outcome.total * GameRules.bossPassRatio).ceil();
    return AlertDialog(
      icon: Icon(
        outcome.passed ? Icons.emoji_events_rounded : Icons.shield_rounded,
        color: outcome.passed ? AppColors.gold : AppColors.gray500,
        size: 48,
      ),
      title: Text(outcome.passed ? 'Boss vaincu !' : 'Le Boss résiste'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            outcome.passed
                ? '${outcome.correct} bonnes réponses sur ${outcome.total}.'
                : '${outcome.correct} bonnes réponses sur ${outcome.total} : il en fallait $needed. Révise et reviens !',
            textAlign: TextAlign.center,
          ),
          if (cauris > 0 || outcome.xpGained > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (cauris > 0) ...[
                  const CauriIcon(size: 20),
                  Text(
                    ' +$cauris',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: caurisColor),
                  ),
                ],
                if (outcome.xpGained > 0) ...[
                  const SizedBox(width: 16),
                  Text(
                    '+${outcome.xpGained} XP',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.green500),
                  ),
                ],
              ],
            ),
          ],
          for (final b in outcome.newBadges) ...[
            const SizedBox(height: 8),
            Text('Nouveau badge : ${b.emoji} ${b.title}', textAlign: TextAlign.center),
          ],
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Retour à la carte'))],
    );
  }
}

/// Bonnes réponses de la partie : le chiffre rebondit à chaque point.
class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(score),
      tween: Tween(begin: score == 0 ? 1 : 1.35, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: AppColors.green100, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_rounded, size: 16, color: AppColors.green500),
            const SizedBox(width: 2),
            Text(
              '$score',
              style: const TextStyle(color: AppColors.green500, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barre de temps qui se vide ; les 5 dernières secondes, elle rougit et bat.
class _TimeBar extends StatelessWidget {
  const _TimeBar({required this.secondsLeft, required this.limit, required this.running, required this.hard});

  final int secondsLeft;
  final int limit;
  final bool running;

  /// Boss : temps imposé (affiché en secondes).
  final bool hard;

  @override
  Widget build(BuildContext context) {
    final fraction = limit == 0 ? 0.0 : (secondsLeft / limit).clamp(0.0, 1.0);
    final urgent = running && secondsLeft <= 5;
    final color = urgent ? AppColors.error : (fraction > 0.5 ? AppColors.green500 : AppColors.gold);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 8, AppSpacing.screen, 0),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            key: ValueKey(urgent ? secondsLeft : -1),
            tween: Tween(begin: urgent ? 1.4 : 1, end: 1),
            duration: const Duration(milliseconds: 400),
            builder: (context, s, child) => Transform.scale(scale: s, child: child),
            child: Icon(running ? Icons.timer_rounded : Icons.timer_off_rounded, size: 18, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: running ? fraction : fraction),
                duration: const Duration(milliseconds: 950),
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: urgent ? 10 : 7,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              hard || urgent ? '$secondsLeft s' : (secondsLeft * 2 >= limit ? '⚡' : ''),
              textAlign: TextAlign.end,
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: urgent ? 15 : 13),
            ),
          ),
        ],
      ),
    );
  }
}
