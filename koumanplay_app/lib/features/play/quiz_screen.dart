import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/lesson.dart';
import '../../core/theme.dart';
import '../../models/content.dart';
import '../../services/providers.dart';
import '../../widgets/audio_button.dart';
import '../../widgets/common.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.levelId});

  final String levelId;

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
  final _correctIds = <String>{};
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final content = ref.read(contentProvider);
    _level = content.level(widget.levelId);
    _language = _level == null ? null : content.language(_level.languageId);
    _questions = LessonBuilder.build(content, widget.levelId);
    ref.read(analyticsProvider).track('level_started', {'level': widget.levelId});
  }

  LessonQuestion get _current => _questions[_index];

  void _submit() {
    final correct = _selected == _current.correct;
    setState(() {
      _submitted = true;
      if (correct) _correctIds.add(_current.itemId);
    });
    ref.read(analyticsProvider).track('answer', {'activity': _current.itemId, 'correct': correct, 'choice': _selected});
    // Fait apparaître l'explication si elle est sous le bas de l'écran.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _next() async {
    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _selected = null;
        _submitted = false;
      });
      _scroll.jumpTo(0);
      return;
    }
    setState(() => _finishing = true);
    final outcome = await ref.read(playerProvider.notifier).completeLevel(
          widget.levelId,
          askedIds: {for (final q in _questions) q.itemId},
          correctIds: _correctIds,
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
    if (_level == null || _questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Ce niveau n\'est pas encore disponible.')),
      );
    }
    final theme = Theme.of(context);
    final question = _current;
    final isCorrect = _selected == question.correct;
    final color = _language == null ? AppColors.purple500 : Color(_language.color);
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
                        Expanded(
                          child: Eyebrow(
                            '${_language?.name ?? ''} · Niveau ${_level.order} · ${_level.kindLabel}',
                            color: color,
                          ),
                        ),
                        Text('+${question.xp} XP', style: const TextStyle(color: AppColors.green500, fontWeight: FontWeight.w600)),
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
                    for (var i = 0; i < question.answers.length; i++) ...[
                      _AnswerTile(
                        letter: String.fromCharCode(65 + i),
                        text: question.answers[i],
                        state: _answerState(i),
                        onTap: _submitted ? null : () => setState(() => _selected = i),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_submitted) _Feedback(correct: isCorrect, question: question),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screen),
                child: FilledButton(
                  onPressed: _finishing
                      ? null
                      : !_submitted
                          ? (_selected == null ? null : _submit)
                          : _next,
                  child: Text(!_submitted
                      ? 'Valider ma réponse'
                      : _index < _questions.length - 1
                          ? 'Question suivante'
                          : 'Voir mon résultat'),
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
                  const Text('“', style: TextStyle(fontSize: 40, height: 0.8, color: AppColors.gold, fontWeight: FontWeight.w700)),
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
                child: Text(letter, style: TextStyle(color: badgeText, fontWeight: FontWeight.w700)),
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
  const _Feedback({required this.correct, required this.question});

  final bool correct;
  final LessonQuestion question;

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
                    Text('La bonne réponse était : ${question.answers[question.correct]}',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(question.explanation, style: const TextStyle(color: AppColors.gray700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
