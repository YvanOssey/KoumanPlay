import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/game_rules.dart';
import '../../core/lesson.dart';
import '../../core/theme.dart';
import '../../models/content.dart';
import '../../services/providers.dart';
import '../../widgets/audio_button.dart';
import '../../widgets/cauris.dart';
import '../../widgets/common.dart';
import '../../widgets/energy.dart';

/// Une partie : un niveau, ou un entraînement ([practice]) sur les questions
/// ratées, sans perte d'énergie.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.levelId, this.practice = false});

  final String levelId;
  final bool practice;

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

  @override
  void dispose() {
    _scroll.dispose();
    _typed.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final content = ref.read(contentProvider);
    final player = ref.read(playerProvider);
    if (widget.practice) {
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
    ref.read(analyticsProvider).track(widget.practice ? 'practice_started' : 'level_started', {
      'level': widget.levelId,
    });
  }

  LessonQuestion get _current => _questions[_index];

  bool get _canSubmit => _current.isRecall ? _typed.text.trim().isNotEmpty : _selected != null;

  void _submit() {
    final question = _current;
    final correct = question.isRecall
        ? TypedAnswer.matches(_typed.text, question.expected!)
        : _selected == question.correct;
    // Décidé tout de suite, pour que « Question suivante » ne s'affiche pas
    // sur la dernière énergie.
    final costsEnergy = !widget.practice && !correct;
    final lastEnergy = costsEnergy && GameRules.energyAt(ref.read(playerProvider), DateTime.now()) <= 1;
    setState(() {
      _submitted = true;
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
      'practice': widget.practice,
    });
    if (costsEnergy) ref.read(playerProvider.notifier).loseEnergy();
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
        _typed.clear();
      });
      _scroll.jumpTo(0);
      return;
    }
    setState(() => _finishing = true);
    final notifier = ref.read(playerProvider.notifier);
    final asked = {for (final q in _questions) q.itemId};
    if (widget.practice) {
      final outcome = await notifier.completePractice(askedIds: asked, correctIds: _seenIds.difference(_missedIds));
      if (!mounted) return;
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
    );
    if (mounted) context.pushReplacement('/result', extra: outcome);
  }

  Future<void> _confirmQuit() async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter la partie ?'),
        content: const Text('Ta progression dans ce niveau ne sera pas enregistrée.'),
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
    if (_questions.isEmpty || (!widget.practice && _level == null)) {
      return Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              widget.practice
                  ? 'Valide un premier niveau pour débloquer l\'entraînement.'
                  : 'Ce niveau n\'est pas encore disponible.',
              textAlign: TextAlign.center,
            ),
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
    final eyebrow = widget.practice
        ? 'Entraînement · sans perte d\'énergie'
        : '${_language?.name ?? ''} · Niveau ${_level!.order} · ${_level.kindLabel}';
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
                    const EnergyPill(showWait: false),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  children: [
                    Row(
                      children: [
                        Expanded(child: Eyebrow(eyebrow, color: color)),
                        if (!widget.practice)
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
                    if (question.isRecall)
                      _RecallInput(
                        controller: _typed,
                        expected: question.expected!,
                        revealed: _revealed,
                        submitted: _submitted,
                        correct: _lastCorrect,
                        onSubmit: _canSubmit && !_submitted ? _submit : null,
                        onHintLetter: () => _hint(word: false),
                        onHintWord: () => _hint(word: true),
                      )
                    else
                      for (var i = 0; i < question.answers.length; i++) ...[
                        _AnswerTile(
                          letter: String.fromCharCode(65 + i),
                          text: question.answers[i],
                          state: _answerState(i),
                          onTap: _submitted ? null : () => setState(() => _selected = i),
                        ),
                        const SizedBox(height: 10),
                      ],
                    if (_submitted)
                      _Feedback(
                        correct: _lastCorrect,
                        question: question,
                        outOfEnergy: _outOfEnergy,
                        costsEnergy: !widget.practice,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screen),
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
    return Material(
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
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.correct,
    required this.question,
    required this.outOfEnergy,
    required this.costsEnergy,
  });

  final bool correct;
  final LessonQuestion question;
  final bool outOfEnergy;

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
                    correct ? 'Bonne réponse !' : 'Pas tout à fait',
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
