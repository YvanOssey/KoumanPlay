import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/duel_games.dart';
import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../models/avatar.dart';
import '../../services/duel_session.dart';
import '../../services/providers.dart';
import '../../widgets/avatar_view.dart';
import '../../widgets/cauris.dart';
import '../../widgets/fx.dart';
import 'duels_screen.dart';

enum _Phase { waiting, countdown, playing, ended }

/// Une partie de duel en direct : compte à rebours, jeu (corde ou paires),
/// puis résultat. Le score de l'adversaire arrive en temps réel.
class DuelGameScreen extends ConsumerStatefulWidget {
  const DuelGameScreen({super.key, required this.setup});

  final MatchSetup setup;

  @override
  ConsumerState<DuelGameScreen> createState() => _DuelGameScreenState();
}

class _DuelGameScreenState extends ConsumerState<DuelGameScreen> {
  _Phase _phase = _Phase.waiting;
  int _count = 3;
  int _myScore = 0;
  int _secondsLeft = 0;
  DuelVerdict? _verdict;
  String? _endNote;
  int _reward = 0;
  Timer? _clock;
  Timer? _noShow;

  Opponent get _opponent => widget.setup.opponent;
  DuelMode get _mode => widget.setup.mode;
  int get _duration => _mode == DuelMode.corde ? RopeRules.seconds : PairsRules.seconds;

  @override
  void initState() {
    super.initState();
    _opponent.startAt.addListener(_onStartKnown);
    _opponent.score.addListener(_check);
    _opponent.left.addListener(_onLeft);
    _opponent.connect();
    // L'adversaire ne s'est jamais connecté.
    _noShow = Timer(const Duration(seconds: 15), () {
      if (_phase == _Phase.waiting) _end(null, note: 'Ton adversaire ne s\'est pas connecté. Relance une recherche !');
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _noShow?.cancel();
    _opponent.startAt.removeListener(_onStartKnown);
    _opponent.score.removeListener(_check);
    _opponent.left.removeListener(_onLeft);
    _opponent.dispose();
    super.dispose();
  }

  void _onStartKnown() {
    final at = _opponent.startAt.value;
    if (at == null || _phase != _Phase.waiting) return;
    _noShow?.cancel();
    setState(() => _phase = _Phase.countdown);
    _clock = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      if (_phase == _Phase.countdown) {
        final left = at.difference(now);
        final count = (left.inMilliseconds / 1000).ceil();
        if (left.isNegative) {
          ref.read(soundProvider).play('go');
          setState(() {
            _phase = _Phase.playing;
            _secondsLeft = _duration;
          });
        } else if (count != _count) {
          ref.read(soundProvider).play('tick');
          setState(() => _count = count);
        }
      } else if (_phase == _Phase.playing) {
        final left = _duration - now.difference(at).inSeconds;
        if (left != _secondsLeft) setState(() => _secondsLeft = max(0, left));
        if (left <= 0) _check(timeUp: true);
      }
    });
  }

  void _onLeft() {
    if (!_opponent.left.value || _phase == _Phase.ended) return;
    if (_phase == _Phase.playing || _phase == _Phase.countdown) {
      _end(DuelVerdict.win, note: '${_opponent.name} a quitté la partie.');
    } else {
      _end(null, note: 'Ton adversaire ne s\'est pas connecté. Relance une recherche !');
    }
  }

  void _scored(int score) {
    if (_phase != _Phase.playing) return;
    setState(() => _myScore = score);
    _opponent.report(score);
    _check();
  }

  void _check({bool timeUp = false}) {
    if (_phase != _Phase.playing) return;
    final theirs = _opponent.score.value;
    final verdict = _mode == DuelMode.corde
        ? RopeRules.verdict(_myScore, theirs, timeUp: timeUp)
        : PairsRules.verdict(_myScore, theirs, timeUp: timeUp);
    if (verdict != null) {
      _end(verdict);
    } else {
      setState(() {});
    }
  }

  Future<void> _end(DuelVerdict? verdict, {String? note}) async {
    if (_phase == _Phase.ended) return;
    _clock?.cancel();
    _opponent.stop();
    setState(() {
      _phase = _Phase.ended;
      _verdict = verdict;
      _endNote = note;
    });
    if (verdict == null) return;
    final theirs = _opponent.score.value;
    final setup = widget.setup;
    final matchId = setup.matchId;
    if (matchId != null) {
      ref.read(backendProvider).matchFinish(matchId, score: _myScore, won: verdict == DuelVerdict.win);
    }
    await ref
        .read(duelHistoryProvider.notifier)
        .add(
          DuelRecord(
            mode: _mode,
            opponent: _opponent.name,
            verdict: verdict,
            at: DateTime.now(),
            score: '$_myScore – $theirs',
          ),
        );
    final cauris = await ref.read(playerProvider.notifier).claimDuelReward(setup.rewardId, verdict);
    if (mounted) setState(() => _reward = cauris ?? 0);
  }

  Future<void> _quit() async {
    if (_phase == _Phase.ended || _phase == _Phase.waiting) {
      _leave();
      return;
    }
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandonner le duel ?'),
        content: const Text('La partie comptera comme perdue.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuer')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Abandonner')),
        ],
      ),
    );
    if (quit != true || !mounted) return;
    await _end(DuelVerdict.loss, note: 'Tu as abandonné.');
    _leave(quit: true);
  }

  void _leave({bool quit = false}) {
    final opponent = _opponent;
    if (opponent is LiveOpponent) opponent.close(quit: quit);
    if (mounted) context.pop();
  }

  void _replay() {
    final opponent = _opponent;
    if (opponent is LiveOpponent) opponent.close();
    context.pushReplacement('/duel/recherche', extra: _mode);
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final myName = player.firstName.isEmpty ? 'Toi' : player.firstName;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quit();
      },
      child: Scaffold(
        backgroundColor: _mode == DuelMode.corde ? const Color(0xFFFFF4DC) : const Color(0xFFEFF7F0),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _Header(
                    mode: _mode,
                    me: player.avatarOrDefault,
                    myName: myName,
                    myScore: _myScore,
                    opponent: _opponent,
                    secondsLeft: _phase == _Phase.playing ? _secondsLeft : _duration,
                    onClose: _quit,
                  ),
                  Expanded(
                    child: switch (_mode) {
                      DuelMode.corde => _RopeGame(
                        setup: widget.setup,
                        enabled: _phase == _Phase.playing,
                        myScore: _myScore,
                        me: player.avatarOrDefault,
                        onScore: _scored,
                      ),
                      DuelMode.paires => _PairsGame(
                        setup: widget.setup,
                        enabled: _phase == _Phase.playing,
                        onScore: _scored,
                      ),
                    },
                  ),
                ],
              ),
              if (_phase == _Phase.waiting || _phase == _Phase.countdown)
                Positioned.fill(
                  child: _Countdown(waiting: _phase == _Phase.waiting, count: _count, mode: _mode),
                ),
              if (_phase == _Phase.ended)
                Positioned.fill(
                  child: _EndPanel(
                    verdict: _verdict,
                    note: _endNote,
                    myScore: _myScore,
                    theirScore: _opponent.score.value,
                    mode: _mode,
                    opponentName: _opponent.name,
                    reward: _reward,
                    languageId: widget.setup.languageId,
                    onReplay: _replay,
                    onLeave: _leave,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.mode,
    required this.me,
    required this.myName,
    required this.myScore,
    required this.opponent,
    required this.secondsLeft,
    required this.onClose,
  });

  final DuelMode mode;
  final AvatarConfig me;
  final String myName;
  final int myScore;
  final Opponent opponent;
  final int secondsLeft;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final urgent = secondsLeft <= 10;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.close_rounded), onPressed: onClose),
          Expanded(
            child: _PlayerChip(
              avatar: me,
              name: myName,
              score: mode == DuelMode.paires ? '$myScore/${PairsRules.total}' : null,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (urgent ? AppColors.error : duelNight).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$secondsLeft s',
              style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: opponent.score,
              builder: (context, theirs, _) => _PlayerChip(
                avatar: opponent.avatar,
                name: opponent.name,
                score: mode == DuelMode.paires ? '$theirs/${PairsRules.total}' : null,
                alignEnd: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({required this.avatar, required this.name, this.score, this.alignEnd = false});

  final AvatarConfig avatar;
  final String name;
  final String? score;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final children = [
      Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
        child: ClipOval(child: AvatarView(config: avatar, size: 38)),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Column(
          crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (score != null) Text(score!, style: const TextStyle(color: AppColors.gray700, fontSize: 12)),
          ],
        ),
      ),
    ];
    return Row(
      mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignEnd ? children.reversed.toList() : children,
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.waiting, required this.count, required this.mode});

  final bool waiting;
  final int count;
  final DuelMode mode;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: duelNight.withValues(alpha: 0.88),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mode.title.toUpperCase(),
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, letterSpacing: 2),
            ),
            const SizedBox(height: 16),
            if (waiting)
              const CircularProgressIndicator(color: AppColors.white)
            else
              TweenAnimationBuilder<double>(
                key: ValueKey(count),
                tween: Tween(begin: 1.8, end: 1),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                builder: (context, s, child) => Transform.scale(scale: s, child: child),
                child: Text(
                  '$count',
                  style: const TextStyle(color: AppColors.white, fontSize: 96, fontWeight: FontWeight.w900),
                ),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                waiting ? 'Connexion avec ton adversaire…' : mode.pitch,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.white.withValues(alpha: 0.85)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Tir à la corde

class _RopeGame extends ConsumerStatefulWidget {
  const _RopeGame({
    required this.setup,
    required this.enabled,
    required this.myScore,
    required this.me,
    required this.onScore,
  });

  final MatchSetup setup;
  final bool enabled;
  final int myScore;
  final AvatarConfig me;
  final ValueChanged<int> onScore;

  @override
  ConsumerState<_RopeGame> createState() => _RopeGameState();
}

class _RopeGameState extends ConsumerState<_RopeGame> {
  late final List<RopeCard> _cards = DuelContent.rope(
    ref.read(contentProvider),
    widget.setup.languageId,
    widget.setup.seed,
  );
  int _index = 0;
  final _shown = Stopwatch()..start();
  bool _locked = false;
  bool? _lastRight;
  int _shakes = 0;
  int _pulls = 0;

  void _answer(bool saysTrue) {
    if (!widget.enabled || _locked || _cards.isEmpty) return;
    final card = _cards[_index % _cards.length];
    final right = saysTrue == card.isTrue;
    final sound = ref.read(soundProvider);
    if (right) {
      final strength = RopeRules.strength(_shown.elapsed);
      sound.play('pull');
      HapticFeedback.lightImpact();
      setState(() {
        _lastRight = true;
        _pulls++;
        _index++;
      });
      _shown.reset();
      widget.onScore(widget.myScore + strength);
    } else {
      sound.play('wrong');
      HapticFeedback.mediumImpact();
      setState(() {
        _lastRight = false;
        _locked = true;
        _shakes++;
      });
      Timer(RopeRules.penalty, () {
        if (!mounted) return;
        setState(() {
          _locked = false;
          _index++;
        });
        _shown.reset();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) return const Center(child: Text('Pas encore de proverbes pour ce duel.'));
    final card = _cards[_index % _cards.length];
    final opponent = widget.setup.opponent;
    return Column(
      children: [
        ValueListenableBuilder<int>(
          valueListenable: opponent.score,
          builder: (context, theirs, _) =>
              _RopeField(gap: widget.myScore - theirs, me: widget.me, them: opponent.avatar, pulls: _pulls),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 4, AppSpacing.screen, 0),
            child: Shake(
              trigger: _shakes,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween(begin: const Offset(0.25, 0), end: Offset.zero).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Container(
                  key: ValueKey(_index),
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadius.largeCard),
                    border: Border.all(color: _locked ? AppColors.error : AppColors.gray200, width: _locked ? 2 : 1),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '« ${card.proverb} »',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 10),
                        const Text('veut dire :', style: TextStyle(color: AppColors.gray500)),
                        const SizedBox(height: 4),
                        Text(card.meaning, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        if (_locked && _lastRight == false) ...[
                          const SizedBox(height: 10),
                          Text(
                            card.isTrue ? 'C\'était vrai !' : 'Faux : ${card.answer}',
                            style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Row(
            children: [
              Expanded(
                child: _BigButton(
                  label: 'Faux',
                  icon: Icons.close_rounded,
                  color: AppColors.error,
                  onTap: widget.enabled && !_locked ? () => _answer(false) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BigButton(
                  label: 'Vrai',
                  icon: Icons.check_rounded,
                  color: AppColors.green500,
                  onTap: widget.enabled && !_locked ? () => _answer(true) : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.icon, required this.color, required this.onTap});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.largeCard)),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 28),
        label: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// Le terrain : la corde, le foulard qui glisse vers le camp qui mène, et les
/// deux joueurs qui tirent.
class _RopeField extends StatelessWidget {
  const _RopeField({required this.gap, required this.me, required this.them, required this.pulls});

  /// Tirs d'avance du joueur (négatif : l'adversaire mène).
  final int gap;
  final AvatarConfig me;
  final AvatarConfig them;

  /// Change à chaque tir : relance l'élan du joueur.
  final int pulls;

  @override
  Widget build(BuildContext context) {
    final position = (gap / RopeRules.winGap).clamp(-1.0, 1.0);
    return SizedBox(
      height: 170,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return TweenAnimationBuilder<double>(
            tween: Tween(end: position),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            builder: (context, p, _) {
              final scarfX = width / 2 - p * width * 0.32;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _RopePainter(scarfX: scarfX)),
                  ),
                  // Le joueur à gauche, l'adversaire à droite ; ils se penchent
                  // en arrière quand ils mènent.
                  Positioned(
                    left: 6,
                    top: 34,
                    child: _Puller(avatar: me, lean: -0.12 - max(0, p) * 0.2, pulse: pulls),
                  ),
                  Positioned(
                    right: 6,
                    top: 34,
                    child: _Puller(avatar: them, lean: 0.12 + max(0, -p) * 0.2, pulse: 0),
                  ),
                  Positioned(
                    left: scarfX - 16,
                    top: 66,
                    child: Transform.rotate(
                      angle: sin(p * 6) * 0.15,
                      child: const Icon(Icons.flag_rounded, size: 34, color: Color(0xFFB3261E)),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Puller extends StatelessWidget {
  const _Puller({required this.avatar, required this.lean, required this.pulse});

  final AvatarConfig avatar;
  final double lean;
  final int pulse;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(pulse),
      tween: Tween(begin: 1.12, end: 1),
      duration: const Duration(milliseconds: 300),
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: Transform.rotate(
        angle: lean,
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 4)),
            ],
          ),
          child: ClipOval(child: AvatarView(config: avatar, size: 74)),
        ),
      ),
    );
  }
}

class _RopePainter extends CustomPainter {
  _RopePainter({required this.scarfX});

  final double scarfX;

  @override
  void paint(Canvas canvas, Size size) {
    final y = 92.0;
    // Les deux camps : vert à gauche (le joueur), rouge à droite.
    final zone = Paint()..strokeWidth = 4;
    canvas.drawLine(
      Offset(size.width * 0.18, y - 30),
      Offset(size.width * 0.18, y + 30),
      zone..color = AppColors.green500.withValues(alpha: 0.6),
    );
    canvas.drawLine(
      Offset(size.width * 0.82, y - 30),
      Offset(size.width * 0.82, y + 30),
      zone..color = AppColors.error.withValues(alpha: 0.6),
    );
    canvas.drawLine(
      Offset(size.width / 2, y - 22),
      Offset(size.width / 2, y + 22),
      Paint()
        ..color = AppColors.gray400
        ..strokeWidth = 2,
    );
    // La corde, torsadée.
    final rope = Paint()
      ..color = const Color(0xFF9A6B2F)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(60, y), Offset(size.width - 60, y), rope);
    final twist = Paint()
      ..color = const Color(0xFF6B4410)
      ..strokeWidth = 2;
    for (var x = 64.0; x < size.width - 64; x += 10) {
      canvas.drawLine(Offset(x, y - 4), Offset(x + 6, y + 4), twist);
    }
    // Le foulard noué au milieu de la corde.
    canvas.drawCircle(Offset(scarfX, y), 8, Paint()..color = const Color(0xFFB3261E));
  }

  @override
  bool shouldRepaint(covariant _RopePainter old) => old.scarfX != scarfX;
}

// ---------------------------------------------------------------- Paires express

class _PairsGame extends ConsumerStatefulWidget {
  const _PairsGame({required this.setup, required this.enabled, required this.onScore});

  final MatchSetup setup;
  final bool enabled;
  final ValueChanged<int> onScore;

  @override
  ConsumerState<_PairsGame> createState() => _PairsGameState();
}

class _PairsGameState extends ConsumerState<_PairsGame> {
  late final List<List<PairCard>> _rounds = DuelContent.pairs(
    ref.read(contentProvider),
    widget.setup.languageId,
    widget.setup.seed,
  );
  int _round = 0;
  late List<PairCard> _left;
  late List<PairCard> _right;
  final _matched = <String>{};
  String? _selected;
  String? _wrongLeft;
  String? _wrongRight;
  bool _locked = false;
  int _score = 0;
  int _shakes = 0;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  /// Les deux colonnes de la manche, mélangées de la même façon chez les deux joueurs.
  void _deal() {
    if (_rounds.isEmpty) return;
    final cards = _rounds[_round];
    _left = [...cards]..shuffle(Random(widget.setup.seed + _round * 2));
    _right = [...cards]..shuffle(Random(widget.setup.seed + _round * 2 + 1));
    _matched.clear();
    _selected = null;
  }

  void _tapLeft(PairCard card) {
    if (!widget.enabled || _locked || _matched.contains(card.id)) return;
    ref.read(soundProvider).play('flip');
    setState(() => _selected = card.id);
  }

  void _tapRight(PairCard card) {
    if (!widget.enabled || _locked || _matched.contains(card.id) || _selected == null) return;
    final sound = ref.read(soundProvider);
    if (card.id == _selected) {
      sound.play('match');
      HapticFeedback.lightImpact();
      setState(() {
        _matched.add(card.id);
        _selected = null;
        _score++;
      });
      widget.onScore(_score);
      if (_matched.length == _left.length && _round < _rounds.length - 1) {
        Timer(const Duration(milliseconds: 450), () {
          if (!mounted) return;
          setState(() {
            _round++;
            _deal();
          });
        });
      }
    } else {
      sound.play('wrong');
      HapticFeedback.mediumImpact();
      setState(() {
        _wrongLeft = _selected;
        _wrongRight = card.id;
        _locked = true;
        _shakes++;
      });
      Timer(PairsRules.penalty, () {
        if (!mounted) return;
        setState(() {
          _wrongLeft = null;
          _wrongRight = null;
          _selected = null;
          _locked = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_rounds.isEmpty) return const Center(child: Text('Pas encore de contenu pour ce duel.'));
    final opponent = widget.setup.opponent;
    Widget column(List<PairCard> cards, {required bool left}) => Column(
      children: [
        for (final card in cards)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _PairTile(
                text: left ? card.left : card.right,
                state: _matched.contains(card.id)
                    ? _TileState.matched
                    : (left ? _wrongLeft : _wrongRight) == card.id
                    ? _TileState.wrong
                    : left && _selected == card.id
                    ? _TileState.selected
                    : _TileState.idle,
                onTap: () => left ? _tapLeft(card) : _tapRight(card),
              ),
            ),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.screen),
      child: Column(
        children: [
          ValueListenableBuilder<int>(
            valueListenable: opponent.score,
            builder: (context, theirs, _) => Column(
              children: [
                _ProgressLine(label: 'Toi', value: _score, color: AppColors.green500),
                const SizedBox(height: 4),
                _ProgressLine(label: opponent.name, value: theirs, color: AppColors.purple500),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Manche ${_round + 1}/${_rounds.length} · relie chaque début à sa fin',
            style: const TextStyle(color: AppColors.gray700, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Shake(
              trigger: _shakes,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Row(
                  key: ValueKey(_round),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: column(_left, left: true)),
                    const SizedBox(width: 10),
                    Expanded(child: column(_right, left: false)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: value / PairsRules.total),
              duration: const Duration(milliseconds: 300),
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('$value/${PairsRules.total}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

enum _TileState { idle, selected, matched, wrong }

class _PairTile extends StatelessWidget {
  const _PairTile({required this.text, required this.state, required this.onTap});

  final String text;
  final _TileState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (background, border) = switch (state) {
      _TileState.idle => (AppColors.white, AppColors.gray200),
      _TileState.selected => (AppColors.purple100, AppColors.purple500),
      _TileState.matched => (AppColors.green100, AppColors.green500),
      _TileState.wrong => (AppColors.errorLight, AppColors.error),
    };
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: state == _TileState.matched ? 0.45 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: border, width: state == _TileState.idle ? 1 : 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.25),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Fin de partie

class _EndPanel extends StatelessWidget {
  const _EndPanel({
    required this.verdict,
    required this.note,
    required this.myScore,
    required this.theirScore,
    required this.mode,
    required this.opponentName,
    required this.reward,
    required this.languageId,
    required this.onReplay,
    required this.onLeave,
  });

  final DuelVerdict? verdict;
  final String? note;
  final int myScore;
  final int theirScore;
  final DuelMode mode;
  final String opponentName;
  final int reward;
  final String languageId;
  final VoidCallback onReplay;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final (title, icon, color) = switch (verdict) {
      DuelVerdict.win => ('Victoire !', Icons.emoji_events_rounded, AppColors.gold),
      DuelVerdict.loss => ('Défaite', Icons.shield_moon_rounded, AppColors.gray400),
      DuelVerdict.draw => ('Égalité', Icons.handshake_rounded, AppColors.purple500),
      null => ('Partie annulée', Icons.wifi_off_rounded, AppColors.gray400),
    };
    return Celebration(
      won: verdict == DuelVerdict.win,
      languageId: languageId,
      child: ColoredBox(
        color: duelNight.withValues(alpha: 0.92),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.3, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (context, s, child) => Transform.scale(scale: s, child: child),
                  child: Icon(icon, size: 96, color: color),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(color: AppColors.white, fontSize: 32, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  note ??
                      (mode == DuelMode.corde
                          ? (verdict == DuelVerdict.win
                                ? 'Tu as tiré la corde dans ton camp !'
                                : verdict == DuelVerdict.loss
                                ? '$opponentName a tiré plus fort cette fois.'
                                : 'Personne n\'a cédé.')
                          : 'Paires : toi $myScore, $opponentName $theirScore.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.white.withValues(alpha: 0.85)),
                ),
                if (reward > 0) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CauriIcon(size: 24),
                      Text(
                        ' +$reward',
                        style: const TextStyle(color: AppColors.gold, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: onReplay, child: const Text('Rejouer')),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: const BorderSide(color: AppColors.white),
                    ),
                    onPressed: onLeave,
                    child: const Text('Retour à l\'arène'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
