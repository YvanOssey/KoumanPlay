import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/player.dart';
import '../../services/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/links.dart';

const _months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
const _days = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

String _hour(DateTime d) => d.hour == 0 && d.minute == 0 ? '' : ' · ${d.hour}h${d.minute.toString().padLeft(2, '0')}';

/// « sam. 14 nov. 2026 · 18h00 », ou « du 14 au 16 nov. 2026 ».
String eventDateLabel(CultureEvent e) {
  final s = e.startsAt, end = e.endsAt;
  if (end != null && (end.day != s.day || end.month != s.month || end.year != s.year)) {
    final sameMonth = end.month == s.month && end.year == s.year;
    return 'du ${s.day}${sameMonth ? '' : ' ${_months[s.month - 1]}'} au ${end.day} ${_months[end.month - 1]} ${end.year}';
  }
  return '${_days[s.weekday - 1]} ${s.day} ${_months[s.month - 1]} ${s.year}${_hour(s)}';
}

/// Événements culturels publiés par les structures partenaires.
class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final content = ref.watch(contentProvider);
    final player = ref.watch(playerProvider);
    final now = DateTime.now();
    final upcoming = content.events.where((e) => !e.isPast(now)).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          Text('Événements', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('Festivals, expositions, contes : les rendez-vous de nos partenaires culturels.',
              style: TextStyle(color: AppColors.gray500)),
          const SizedBox(height: 16),
          EligibilityCard(content: content, player: player),
          const SizedBox(height: AppSpacing.section),
          Text('À venir', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          if (upcoming.isEmpty)
            const AppCard(
              color: AppColors.cream,
              border: false,
              child: Text(
                'Aucun événement annoncé pour le moment. Les prochains rendez-vous de nos partenaires apparaîtront ici.',
                style: TextStyle(color: AppColors.gray700),
              ),
            ),
          for (final e in upcoming) ...[
            _EventTile(event: e, content: content, player: player),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// Où en est le joueur par rapport aux seuils pour participer.
class EligibilityCard extends StatelessWidget {
  const EligibilityCard({super.key, required this.content, required this.player, this.event});

  final ContentPack content;
  final PlayerState player;
  final CultureEvent? event;

  @override
  Widget build(BuildContext context) {
    final needLevels = GameRules.eventLevelsRequired(content, event);
    final needLevel = content.settings.eventMinLevel;
    final level = GameRules.playerLevel(player.xp);
    final eligible = GameRules.isEventEligible(content, player, event);
    return AppCard(
      color: eligible ? AppColors.green100 : AppColors.purple100,
      border: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(eligible ? Icons.verified_rounded : Icons.lock_clock_rounded,
                  color: eligible ? AppColors.green500 : AppColors.purple500),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  eligible ? 'Tu peux participer aux événements' : 'Gagne ta place aux événements',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            eligible
                ? 'Présente ton profil KoumanPlay à la structure qui organise l\'événement.'
                : 'Valide $needLevels niveaux et atteins le niveau $needLevel pour participer. Ta place se gagne en jouant.',
            style: const TextStyle(color: AppColors.gray700),
          ),
          const SizedBox(height: 12),
          _Gauge(
            icon: Icons.flag_rounded,
            color: AppColors.purple500,
            label: 'Niveaux validés',
            value: player.levelsPassed,
            target: needLevels,
          ),
          const SizedBox(height: 8),
          _Gauge(icon: Icons.star_rounded, color: AppColors.gold, label: 'Niveau', value: level, target: needLevel),
        ],
      ),
    );
  }
}

class _Gauge extends StatelessWidget {
  const _Gauge({required this.icon, required this.color, required this.label, required this.value, required this.target});

  final IconData icon;
  final Color color;
  final String label;
  final int value;
  final int target;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        SizedBox(width: 72, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(child: KpProgressBar(value: target == 0 ? 1 : (value / target).clamp(0, 1).toDouble(), color: color)),
        const SizedBox(width: 10),
        Text('${value.clamp(0, 9999)} / $target',
            style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.content, required this.player});

  final CultureEvent event;
  final ContentPack content;
  final PlayerState player;

  @override
  Widget build(BuildContext context) {
    final where = [event.place, event.city].whereType<String>().join(' · ');
    final custom = event.minDiamonds;
    return AppCard(
      onTap: () => context.push('/events/${event.id}'),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 72,
            decoration: BoxDecoration(color: AppColors.purple100, borderRadius: BorderRadius.circular(AppRadius.input)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${event.startsAt.day}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.purple600)),
                Text(_months[event.startsAt.month - 1],
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.purple500)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.organizer.isNotEmpty) Eyebrow(event.organizer),
                Text(event.title, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (where.isNotEmpty)
                  Text(where, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.gray500, fontSize: 13)),
                if (custom != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.flag_rounded, size: 14, color: AppColors.purple500),
                      const SizedBox(width: 4),
                      Text(
                        '$custom niveaux validés requis',
                        style: const TextStyle(color: AppColors.purple500, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.gray400),
        ],
      ),
    );
  }
}

/// Fiche d'un événement.
class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).track('event_opened', {'event': widget.eventId});
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentProvider);
    final player = ref.watch(playerProvider);
    final event = content.event(widget.eventId);
    if (event == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Cet événement n\'est plus disponible.')));
    }
    final theme = Theme.of(context);
    final where = [event.place, event.city].whereType<String>().join(', ');
    return Scaffold(
      appBar: AppBar(title: Text(event.title, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          if (event.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.largeCard),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: RemoteImage(url: event.imageUrl, icon: Icons.event_rounded, color: AppColors.purple500, iconSize: 56),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (event.organizer.isNotEmpty) Eyebrow(event.organizer),
          const SizedBox(height: 4),
          Text(event.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.calendar_month_rounded, text: eventDateLabel(event)),
          if (where.isNotEmpty) _InfoRow(icon: Icons.place_rounded, text: where),
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(event.description, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
          ],
          const SizedBox(height: AppSpacing.section),
          EligibilityCard(content: content, player: player, event: event),
          if (event.link != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => openLink(context, event.link!),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Voir l\'événement'),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.purple500),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
