import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../models/avatar.dart';
import '../../models/social.dart';
import '../../services/providers.dart';
import '../../widgets/avatar_view.dart';
import '../../widgets/cauris.dart';
import '../../widgets/common.dart';

/// Couleur de chaque ligue, de Bronze à Baobab.
const leagueColors = [Color(0xFFB0703A), Color(0xFF8E9AAF), AppColors.gold, Color(0xFF1F7A3E)];

Color leagueColor(int tier) => leagueColors[tier.clamp(0, leagueColors.length - 1)];

/// Ligue de la semaine : le groupe de 20 joueurs, classé par XP gagné depuis
/// lundi. Les 5 premiers montent, les 5 derniers descendent.
class LeagueScreen extends StatelessWidget {
  const LeagueScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ligue de la semaine')),
    body: const LeagueView(),
  );
}

/// Contenu de la ligue, aussi affiché dans l'onglet Défis.
class LeagueView extends ConsumerStatefulWidget {
  const LeagueView({super.key});

  @override
  ConsumerState<LeagueView> createState() => _LeagueViewState();
}

class _LeagueViewState extends ConsumerState<LeagueView> {
  LeagueBoard? _board;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final board = await ref.read(playerProvider.notifier).syncLeague();
    if (!mounted) return;
    setState(() {
      _board = board;
      _loading = false;
    });
    final previous = board?.previous;
    if (previous == null) return;
    final cauris = await ref.read(playerProvider.notifier).claimLeagueReward(previous);
    if (cauris != null && mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => _WeekEnded(result: previous, cauris: cauris),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          if (_loading && board == null)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (board == null)
            const AppCard(
              child: Text(
                'La ligue n\'est pas disponible pour le moment. Vérifie ta connexion, puis tire vers le bas pour réessayer.',
              ),
            )
          else ...[
            _Header(board: board),
            const SizedBox(height: AppSpacing.section),
            for (final (i, m) in board.members.indexed) ...[
              _MemberRow(rank: i + 1, member: m, zone: _zone(board, i + 1)),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 12),
            const Text(
              'Tout l\'XP gagné compte : niveaux, Boss, défis et transmissions. Le classement se fige le dimanche à minuit.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.gray500, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  /// 1 : monte en ligue ; -1 : descend ; 0 : reste.
  static int _zone(LeagueBoard board, int rank) {
    final size = board.members.length;
    if (rank <= GameRules.leagueMove && board.tier < GameRules.leagues.length - 1) return 1;
    if (size >= 2 * GameRules.leagueMove && rank > size - GameRules.leagueMove && board.tier > 0) return -1;
    return 0;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.board});

  final LeagueBoard board;

  @override
  Widget build(BuildContext context) {
    final color = leagueColor(board.tier);
    final left = GameRules.weekEnd(DateTime.now()).difference(DateTime.now().toUtc());
    final remaining = left.inDays > 0
        ? '${left.inDays} j ${left.inHours % 24} h'
        : '${left.inHours} h ${left.inMinutes % 60} min';
    final top = board.tier < GameRules.leagues.length - 1;
    return AppCard(
      color: color.withValues(alpha: 0.12),
      border: false,
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color,
            child: const Icon(Icons.shield_rounded, color: AppColors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ligue ${GameRules.leagueName(board.tier)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Color.lerp(color, Colors.black, 0.3)),
                ),
                Text('Fin dans $remaining', style: const TextStyle(color: AppColors.gray700, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  top
                      ? 'Les ${GameRules.leagueMove} premiers montent en ligue ${GameRules.leagueName(board.tier + 1)}.'
                      : 'La plus haute ligue : reste dans le haut du classement !',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Podium : ', style: TextStyle(fontSize: 13)),
                    const CauriIcon(size: 14),
                    Text(
                      ' ${GameRules.leagueRewards.join(', ')}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: caurisColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.rank, required this.member, required this.zone});

  final int rank;
  final LeagueMember member;
  final int zone;

  @override
  Widget build(BuildContext context) {
    final rankColor = zone > 0 ? AppColors.green500 : (zone < 0 ? AppColors.error : AppColors.gray500);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: member.me ? AppColors.purple100 : AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: member.me ? AppColors.purple500 : AppColors.gray200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, color: rankColor),
            ),
          ),
          const SizedBox(width: 8),
          AvatarView(config: member.avatar ?? AvatarConfig.youngDefault, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              member.me ? '${member.name} (toi)' : member.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: member.me ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
          if (zone != 0)
            Icon(zone > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 16, color: rankColor),
          const SizedBox(width: 6),
          Text('${member.points} XP', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Bilan de la semaine passée, montré une fois.
class _WeekEnded extends StatelessWidget {
  const _WeekEnded({required this.result, required this.cauris});

  final LeagueResult result;
  final int cauris;

  @override
  Widget build(BuildContext context) {
    final moved = result.newTier.compareTo(result.tier);
    final next = GameRules.leagueName(result.newTier);
    return AlertDialog(
      icon: Icon(Icons.shield_rounded, color: leagueColor(result.newTier), size: 44),
      title: const Text('Semaine terminée'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Tu as fini ${result.rank == 1 ? '1er' : '${result.rank}e'} sur ${result.size} '
            'en ligue ${GameRules.leagueName(result.tier)}.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            moved > 0
                ? 'Bravo, tu montes en ligue $next !'
                : moved < 0
                ? 'Tu descends en ligue $next. Tu peux remonter dès cette semaine.'
                : 'Tu restes en ligue $next.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (cauris > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CauriIcon(size: 20),
                Text(
                  ' +$cauris',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: caurisColor),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('C\'est parti'))],
    );
  }
}
