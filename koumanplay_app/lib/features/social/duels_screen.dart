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
import '../../models/social.dart';
import '../../services/duel_session.dart';
import '../../services/providers.dart';
import '../../widgets/avatar_view.dart';
import '../../widgets/cauris.dart';
import '../../widgets/common.dart';
import '../../widgets/fx.dart';
import '../../widgets/links.dart';

const duelNight = Color(0xFF160D2B);

/// Mode de duel choisi dans l'arène, gardé entre deux parties.
class DuelModeController extends Notifier<DuelMode> {
  @override
  DuelMode build() => DuelMode.corde;

  void select(DuelMode mode) => state = mode;
}

final duelModeProvider = NotifierProvider<DuelModeController, DuelMode>(DuelModeController.new);

String _playerName(WidgetRef ref) {
  final name = ref.read(playerProvider).firstName;
  return name.isEmpty ? 'Joueur' : name;
}

/// Langue des duels : celle de la carte du joueur.
String _languageId(WidgetRef ref) =>
    GameRules.learningLanguage(ref.read(contentProvider), ref.read(playerProvider))?.id ?? 'baoule';

IconData duelIcon(DuelMode mode) => switch (mode) {
  DuelMode.corde => Icons.sports_kabaddi_rounded,
  DuelMode.paires => Icons.extension_rounded,
};

/// Écran Duels ouvert hors de l'onglet Défis.
class DuelsScreen extends StatelessWidget {
  const DuelsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Duels')),
    body: const DuelLobby(),
  );
}

/// L'arène : choix du jeu, puis un joueur inconnu ou un ami.
class DuelLobby extends ConsumerWidget {
  const DuelLobby({super.key});

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final code = await showDialog<String>(context: context, builder: (_) => const _CodeDialog());
    if (code == null || code.trim().isEmpty || !context.mounted) return;
    final player = ref.read(playerProvider);
    final result = await ref
        .read(backendProvider)
        .roomJoin(code.trim(), name: _playerName(ref), avatar: player.avatarOrDefault.toJson());
    if (!context.mounted) return;
    final match = result.match;
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error ?? 'Impossible de rejoindre.')));
      return;
    }
    final mode = DuelMode.values.asNameMap()[match.mode] ?? DuelMode.corde;
    final opponent = LiveOpponent(
      ref.read(backendProvider),
      match.id,
      amA: false,
      name: match.aName,
      avatar: match.aAvatar ?? AvatarConfig.youngDefault,
    );
    context.push(
      '/duel/partie',
      extra: MatchSetup(
        mode: mode,
        languageId: match.languageId,
        seed: match.seed,
        opponent: opponent,
        matchId: match.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(duelModeProvider);
    final history = ref.watch(duelHistoryProvider);
    final online = ref.watch(backendProvider).enabled;
    final wins = history.where((r) => r.verdict == DuelVerdict.win).length;
    final losses = history.where((r) => r.verdict == DuelVerdict.loss).length;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        _ArenaHeader(wins: wins, losses: losses),
        const SizedBox(height: AppSpacing.section),
        Text('Choisis ton jeu', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final m in DuelMode.values) ...[
              if (m != DuelMode.values.first) const SizedBox(width: 10),
              Expanded(
                child: _ModeCard(
                  mode: m,
                  selected: m == mode,
                  onTap: () => ref.read(duelModeProvider.notifier).select(m),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.section),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: duelNight),
            onPressed: () => context.push('/duel/recherche', extra: mode),
            icon: const Icon(Icons.radar_rounded),
            label: const Text('Jouer contre un joueur', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: online ? () => context.push('/duel/ami', extra: mode) : null,
                icon: const Icon(Icons.group_add_rounded, size: 18),
                label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Défier un ami')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: online ? () => _join(context, ref) : null,
                icon: const Icon(Icons.vpn_key_rounded, size: 18),
                label: const FittedBox(fit: BoxFit.scaleDown, child: Text('J\'ai un code')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Victoire ', style: TextStyle(fontSize: 13, color: AppColors.gray700)),
            const CauriIcon(size: 14),
            Text(
              ' ${GameRules.duelWinCauris}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: caurisColor),
            ),
            const Text('  ·  sans énergie', style: TextStyle(fontSize: 13, color: AppColors.gray700)),
          ],
        ),
        const SizedBox(height: AppSpacing.section),
        Text('Derniers duels', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (history.isEmpty)
          const AppCard(child: Text('Ton premier duel t\'attend. Choisis un jeu et lance-toi !'))
        else
          for (final r in history.take(8)) ...[_HistoryRow(record: r), const SizedBox(height: 6)],
      ],
    );
  }
}

class _ArenaHeader extends StatelessWidget {
  const _ArenaHeader({required this.wins, required this.losses});

  final int wins;
  final int losses;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.largeCard),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.purple500, duelNight],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -14,
            child: Icon(Icons.bolt_rounded, size: 130, color: AppColors.white.withValues(alpha: 0.08)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ARÈNE DES DUELS',
                  style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Affronte un joueur en direct',
                  style: TextStyle(color: AppColors.white, fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Pill(icon: Icons.emoji_events_rounded, text: '$wins victoire${wins > 1 ? 's' : ''}'),
                    const SizedBox(width: 8),
                    _Pill(icon: Icons.shield_moon_rounded, text: '$losses défaite${losses > 1 ? 's' : ''}'),
                  ],
                ),
              ],
            ),
          ),
          // Bande kita au bas de la carte.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 6,
            child: Row(
              children: [
                for (var i = 0; i < 24; i++)
                  Expanded(child: ColoredBox(color: i.isEven ? AppColors.gold : const Color(0xFF1F7A3E))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode, required this.selected, required this.onTap});

  final DuelMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = mode == DuelMode.corde ? const Color(0xFFB5541B) : AppColors.green500;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.1) : AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: selected ? color : AppColors.gray200, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: color,
                    child: Icon(duelIcon(mode), color: AppColors.white),
                  ),
                  const Spacer(),
                  if (selected) Icon(Icons.check_circle_rounded, color: color),
                ],
              ),
              const SizedBox(height: 10),
              Text(mode.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              Text(mode.pitch, style: const TextStyle(color: AppColors.gray700, fontSize: 12, height: 1.35)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record});

  final DuelRecord record;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (record.verdict) {
      DuelVerdict.win => ('Gagné', AppColors.green500),
      DuelVerdict.loss => ('Perdu', AppColors.error),
      DuelVerdict.draw => ('Égalité', AppColors.gray700),
    };
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(duelIcon(record.mode), color: AppColors.purple500, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Contre ${record.opponent} · ${record.mode.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(record.score, style: const TextStyle(color: AppColors.gray500, fontSize: 13)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Code du duel'),
      content: TextField(
        controller: _code,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        maxLength: 6,
        decoration: const InputDecoration(hintText: 'Ex. K7PX3M'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(context, _code.text), child: const Text('Rejoindre')),
      ],
    );
  }
}

/// Avatar tiré au sort pour un adversaire simulé.
AvatarConfig randomAvatar(Random rng) {
  T pick<T>(Iterable<T> items) => items.elementAt(rng.nextInt(items.length));
  return AvatarConfig(
    skin: pick(AvatarConfig.skins.keys),
    hair: pick(AvatarConfig.hairs.keys),
    outfit: pick(AvatarConfig.outfits.keys),
    background: pick(AvatarConfig.backgrounds.keys),
    accessories: {if (rng.nextBool()) pick(AvatarConfig.accessoryNames.keys)},
    lashes: rng.nextBool(),
  );
}

/// Recherche d'un adversaire en ligne. Si personne n'est disponible, un
/// adversaire simulé prend le relais.
class MatchmakingScreen extends ConsumerStatefulWidget {
  const MatchmakingScreen({super.key, required this.mode});

  final DuelMode mode;

  @override
  ConsumerState<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends ConsumerState<MatchmakingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _radar = AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..repeat();
  final _rng = Random();
  final _started = DateTime.now();
  Timer? _poll;
  bool _searching = false;
  bool _done = false;
  MatchSetup? _found;

  static const _minSearch = Duration(milliseconds: 2500);
  static const _maxSearch = Duration(seconds: 12);

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(milliseconds: 1500), (_) => _tick());
    _tick();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _radar.dispose();
    if (_found == null) ref.read(backendProvider).matchLeave();
    super.dispose();
  }

  Future<void> _tick() async {
    if (_searching || _done) return;
    _searching = true;
    final backend = ref.read(backendProvider);
    final player = ref.read(playerProvider);
    final elapsed = DateTime.now().difference(_started);
    LiveMatch? match;
    if (backend.enabled) {
      match = await backend.matchFind(
        mode: widget.mode.name,
        languageId: _languageId(ref),
        name: _playerName(ref),
        avatar: player.avatarOrDefault.toJson(),
      );
    }
    _searching = false;
    if (!mounted || _done) return;
    if (match != null) {
      if (elapsed < _minSearch) await Future<void>.delayed(_minSearch - elapsed);
      _start(
        MatchSetup(
          mode: widget.mode,
          languageId: match.languageId,
          seed: match.seed,
          matchId: match.id,
          opponent: LiveOpponent(
            backend,
            match.id,
            amA: match.amA,
            name: match.opponentName,
            avatar: match.opponentAvatar ?? AvatarConfig.youngDefault,
          ),
        ),
      );
    } else if (elapsed > _maxSearch - Duration(milliseconds: _rng.nextInt(4000))) {
      await backend.matchLeave();
      if (!mounted || _done) return;
      _start(
        MatchSetup(
          mode: widget.mode,
          languageId: _languageId(ref),
          seed: _rng.nextInt(1 << 30),
          opponent: BotOpponent(
            mode: widget.mode,
            name: DuelContent.names[_rng.nextInt(DuelContent.names.length)],
            avatar: randomAvatar(_rng),
          ),
        ),
      );
    }
  }

  /// Montre l'adversaire trouvé, puis lance la partie.
  void _start(MatchSetup setup) {
    _done = true;
    _poll?.cancel();
    setState(() => _found = setup);
    ref.read(soundProvider).play('match');
    Timer(const Duration(milliseconds: 1800), () {
      if (mounted) context.pushReplacement('/duel/partie', extra: setup);
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final found = _found;
    return Scaffold(
      backgroundColor: duelNight,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.white),
                onPressed: () => context.pop(),
              ),
            ),
            Text(
              widget.mode.title.toUpperCase(),
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, letterSpacing: 2),
            ),
            Expanded(
              child: Center(
                child: found == null
                    ? AnimatedBuilder(
                        animation: _radar,
                        builder: (context, _) => SizedBox(
                          width: 260,
                          height: 260,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              for (var i = 0; i < 3; i++)
                                Builder(
                                  builder: (context) {
                                    final t = (_radar.value + i / 3) % 1;
                                    return Container(
                                      width: 90 + 170 * t,
                                      height: 90 + 170 * t,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.purple500.withValues(alpha: (1 - t) * 0.8),
                                          width: 3,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              _Badge(avatar: player.avatarOrDefault, size: 96),
                            ],
                          ),
                        ),
                      )
                    : _VersusIntro(
                        me: player.avatarOrDefault,
                        myName: player.firstName.isEmpty ? 'Toi' : player.firstName,
                        them: found.opponent.avatar,
                        theirName: found.opponent.name,
                      ),
              ),
            ),
            Text(
              found == null ? 'Recherche d\'un adversaire…' : 'Adversaire trouvé !',
              style: const TextStyle(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              found == null ? 'Les joueurs en ligne en ce moment' : 'Prépare-toi…',
              style: TextStyle(color: AppColors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.avatar, required this.size});

  final AvatarConfig avatar;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
      child: ClipOval(
        child: AvatarView(config: avatar, size: size - 8),
      ),
    );
  }
}

class _VersusIntro extends StatelessWidget {
  const _VersusIntro({required this.me, required this.myName, required this.them, required this.theirName});

  final AvatarConfig me;
  final String myName;
  final AvatarConfig them;
  final String theirName;

  @override
  Widget build(BuildContext context) {
    Widget side(AvatarConfig avatar, String name, double from) => TweenAnimationBuilder<double>(
      tween: Tween(begin: from, end: 0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, dx, child) => Transform.translate(offset: Offset(dx, 0), child: child),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Badge(avatar: avatar, size: 100),
          const SizedBox(height: 8),
          SizedBox(
            width: 110,
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        side(me, myName, -160),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'VS',
            style: TextStyle(color: AppColors.gold, fontSize: 34, fontWeight: FontWeight.w900),
          ),
        ),
        side(them, theirName, 160),
      ],
    );
  }
}

/// Défi entre amis : crée la partie, montre le code à partager et attend
/// que l'ami la rejoigne.
class FriendRoomScreen extends ConsumerStatefulWidget {
  const FriendRoomScreen({super.key, required this.mode});

  final DuelMode mode;

  @override
  ConsumerState<FriendRoomScreen> createState() => _FriendRoomScreenState();
}

class _FriendRoomScreenState extends ConsumerState<FriendRoomScreen> {
  LiveMatch? _match;
  bool _failed = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _create();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _create() async {
    final player = ref.read(playerProvider);
    final match = await ref
        .read(backendProvider)
        .roomCreate(
          mode: widget.mode.name,
          languageId: _languageId(ref),
          name: _playerName(ref),
          avatar: player.avatarOrDefault.toJson(),
        );
    if (!mounted) return;
    setState(() {
      _match = match;
      _failed = match == null;
    });
    if (match == null) return;
    _poll = Timer.periodic(const Duration(seconds: 2), (_) async {
      final latest = await ref.read(backendProvider).fetchMatch(match.id);
      if (!mounted || latest == null || !latest.hasB) return;
      _poll?.cancel();
      ref.read(soundProvider).play('match');
      context.pushReplacement(
        '/duel/partie',
        extra: MatchSetup(
          mode: widget.mode,
          languageId: latest.languageId,
          seed: latest.seed,
          matchId: latest.id,
          opponent: LiveOpponent(
            ref.read(backendProvider),
            latest.id,
            amA: true,
            name: latest.bName ?? 'Ton ami',
            avatar: latest.bAvatar ?? AvatarConfig.youngDefault,
          ),
        ),
      );
    });
  }

  String _shareText(String code) =>
      'Je te défie en duel (${widget.mode.title}) sur KoumanPlay ! Ouvre l\'app, va dans Défis puis Duels, '
      'touche « J\'ai un code » et entre : $code';

  @override
  Widget build(BuildContext context) {
    final match = _match;
    return Scaffold(
      appBar: AppBar(title: Text('Défier un ami · ${widget.mode.title}')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: _failed
            ? const AppCard(child: Text('Impossible de créer le duel. Vérifie ta connexion.'))
            : match == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    child: Column(
                      children: [
                        const Text('Envoie ce code à ton ami :', style: TextStyle(color: AppColors.gray700)),
                        const SizedBox(height: 8),
                        SelectableText(
                          match.code ?? '',
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 8,
                            color: AppColors.purple500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Il doit l\'entrer dans les 30 minutes.',
                          style: TextStyle(color: AppColors.gray500, fontSize: 12),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                                onPressed: () => openLink(
                                  context,
                                  'https://wa.me/?text=${Uri.encodeComponent(_shareText(match.code ?? ''))}',
                                ),
                                icon: const Icon(Icons.send_rounded, size: 18),
                                label: const FittedBox(fit: BoxFit.scaleDown, child: Text('WhatsApp')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(text: _shareText(match.code ?? '')));
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(const SnackBar(content: Text('Message copié')));
                                  }
                                },
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Copier')),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 16),
                  const Text(
                    'En attente de ton ami…\nLa partie commence dès qu\'il entre le code.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.gray700),
                  ),
                ],
              ),
      ),
    );
  }
}
