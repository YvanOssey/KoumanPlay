import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/content.dart';
import '../../services/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/links.dart';

/// Bibliothèque des œuvres culturelles : recherche, filtre par type, fiche.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _search = TextEditingController();
  String? _kind;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final works = ref.watch(contentProvider).works;
    final kinds = {for (final w in works) w.kind}.toList()..sort();
    final query = _search.text.trim().toLowerCase();
    final results = works
        .where((w) => (_kind == null || w.kind == _kind) && (query.isEmpty || w.searchText.contains(query)))
        .toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          Text('Bibliothèque', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('Les œuvres de notre patrimoine, et où les voir.', style: TextStyle(color: AppColors.gray500)),
          const SizedBox(height: 16),
          if (works.isEmpty)
            const _EmptyLibrary()
          else ...[
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Rechercher une œuvre, un peuple, un musée…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
            if (kinds.length > 1) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final k in [null, ...kinds]) ...[
                      ChoiceChip(
                        label: Text(k ?? 'Toutes'),
                        selected: _kind == k,
                        onSelected: (_) => setState(() => _kind = k),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Aucune œuvre ne correspond à « ${_search.text.trim()} ».',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.gray500),
                ),
              ),
            for (final w in results) ...[
              _WorkTile(work: w),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.cream,
      border: false,
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.museum_rounded, size: 48, color: AppColors.gold),
          const SizedBox(height: 12),
          Text('La bibliothèque se prépare', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text(
            'Nos partenaires culturels y ajoutent leurs œuvres : masques, statues, pagnes, instruments… '
            'avec leur histoire et le musée où les voir.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.gray700),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _WorkTile extends StatelessWidget {
  const _WorkTile({required this.work});

  final CulturalWork work;

  @override
  Widget build(BuildContext context) {
    final where = [work.museum, work.city].whereType<String>().join(' · ');
    return AppCard(
      onTap: () => context.push('/library/${work.id}'),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.input),
            child: SizedBox(
              width: 72,
              height: 72,
              child: RemoteImage(url: work.imageUrl, icon: Icons.museum_rounded, color: AppColors.gold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow([work.kind, ?work.people].join(' · '), color: AppColors.gold),
                const SizedBox(height: 2),
                Text(work.title, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (where.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.place_rounded, size: 14, color: AppColors.gray500),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(where,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.gray500, fontSize: 13)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.gray400),
        ],
      ),
    );
  }
}

/// Fiche complète d'une œuvre.
class WorkDetailScreen extends ConsumerStatefulWidget {
  const WorkDetailScreen({super.key, required this.workId});

  final String workId;

  @override
  ConsumerState<WorkDetailScreen> createState() => _WorkDetailScreenState();
}

class _WorkDetailScreenState extends ConsumerState<WorkDetailScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).track('work_opened', {'work': widget.workId});
  }

  @override
  Widget build(BuildContext context) {
    final work = ref.watch(contentProvider).work(widget.workId);
    if (work == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Cette œuvre n\'est plus disponible.')));
    }
    final theme = Theme.of(context);
    final facts = [
      ('Type', work.kind),
      if (work.people != null) ('Peuple', work.people!),
      if (work.region != null) ('Région', work.region!),
      if (work.period != null) ('Époque', work.period!),
    ];
    final hasPlace = work.museum != null || work.address != null || work.city != null;
    return Scaffold(
      appBar: AppBar(title: Text(work.title, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.largeCard),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              // L'œuvre en entier, sur un fond neutre proche de celui des photos de musée.
              child: ColoredBox(
                color: const Color(0xFFE9E9E9),
                child: RemoteImage(
                  url: work.imageUrl,
                  icon: Icons.museum_rounded,
                  color: AppColors.gold,
                  iconSize: 64,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(work.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, value) in facts)
                Chip(
                  label: Text('$label : $value'),
                  backgroundColor: AppColors.cream,
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (work.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(work.description, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
          ],
          if (hasPlace) ...[
            const SizedBox(height: AppSpacing.section),
            Text('Où la voir', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.museum_rounded, color: AppColors.purple500),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (work.museum != null) Text(work.museum!, style: theme.textTheme.titleSmall),
                        if (work.address != null) Text(work.address!, style: const TextStyle(color: AppColors.gray700)),
                        if (work.city != null) Text(work.city!, style: const TextStyle(color: AppColors.gray500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (work.link != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => openLink(context, work.link!),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('En savoir plus'),
            ),
          ],
        ],
      ),
    );
  }
}
