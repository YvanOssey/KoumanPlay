import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../models/contribution.dart';
import '../../services/contributions.dart';
import '../../services/providers.dart';
import '../../widgets/audio_button.dart';
import '../../widgets/common.dart';
import 'recorder.dart';

const _bigText = TextStyle(fontSize: 18, height: 1.4);

Future<void> _thank(BuildContext context, ChallengeOutcome outcome, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Merci !', textAlign: TextAlign.center, style: TextStyle(fontSize: 26)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center, style: _bigText),
          const SizedBox(height: 12),
          Text(
            '+${outcome.xpGained} XP',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.green500),
          ),
          for (final badge in outcome.newBadges) ...[
            const SizedBox(height: 10),
            Text('${badge.emoji}  Nouveau badge : ${badge.title}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Continuer', style: TextStyle(fontSize: 18))),
      ],
    ),
  );
}

class _TransmitScaffold extends StatelessWidget {
  const _TransmitScaffold({required this.title, required this.children, this.bottom});

  final String title;
  final List<Widget> children;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: ListView(padding: const EdgeInsets.all(AppSpacing.screen), children: children)),
            if (bottom != null) Padding(padding: const EdgeInsets.all(AppSpacing.screen), child: bottom),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Accord
// ---------------------------------------------------------------------------

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key, required this.next});

  /// Écran de transmission à ouvrir une fois l'accord donné.
  final String next;

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _credit = true;

  @override
  Widget build(BuildContext context) {
    return _TransmitScaffold(
      title: 'Avant de commencer',
      bottom: FilledButton(
        onPressed: () async {
          await ref.read(playerProvider.notifier).giveConsent(creditName: _credit);
          if (context.mounted) context.pushReplacement(widget.next);
        },
        child: const Text('J\'accepte', style: TextStyle(fontSize: 18)),
      ),
      children: [
        const Text(
          'Ta voix et tes savoirs vont aider les jeunes à apprendre leur langue et leur culture.',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.4),
        ),
        const SizedBox(height: 16),
        const Text(
          'En acceptant, tu permets à l\'équipe KoumanPlay d\'enregistrer ta voix et d\'utiliser les mots, '
          'proverbes et contes que tu partages dans l\'application. Une personne de l\'équipe les écoute '
          'et les vérifie avant de les publier.',
          style: _bigText,
        ),
        const SizedBox(height: 12),
        const Text(
          'Tu peux demander à tout moment que tes enregistrements soient retirés.',
          style: _bigText,
        ),
        const SizedBox(height: 16),
        AppCard(
          child: RadioGroup<bool>(
            groupValue: _credit,
            onChanged: (v) => setState(() => _credit = v ?? true),
            child: const Column(
              children: [
                RadioListTile<bool>(
                  value: true,
                  activeColor: AppColors.purple500,
                  title: Text('Afficher mon prénom avec ce que je transmets', style: TextStyle(fontSize: 17)),
                ),
                RadioListTile<bool>(
                  value: false,
                  activeColor: AppColors.purple500,
                  title: Text('Rester anonyme', style: TextStyle(fontSize: 17)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mots
// ---------------------------------------------------------------------------

class TransmitWordsScreen extends ConsumerStatefulWidget {
  const TransmitWordsScreen({super.key});

  @override
  ConsumerState<TransmitWordsScreen> createState() => _TransmitWordsScreenState();
}

class _TransmitWordsScreenState extends ConsumerState<TransmitWordsScreen> {
  final _skipped = <String>{};
  String? _audio;
  bool _saving = false;

  // Clé du micro : on la change pour repartir d'un micro vierge à chaque mot.
  int _recorderKey = 0;

  Future<void> _send(CollectPrompt prompt, String languageId) async {
    setState(() => _saving = true);
    final outcome = await ref.read(contributionsProvider.notifier).add(
          kind: ContributionKind.mot,
          languageId: languageId,
          audioPaths: [_audio!],
          prompt: prompt,
        );
    if (!mounted) return;
    if (outcome.newBadges.isNotEmpty) await _thank(context, outcome, 'Ton mot est envoyé à l\'équipe.');
    setState(() {
      _saving = false;
      _audio = null;
      _recorderKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final language = ref.watch(contentProvider).language(player.spokenLanguageId ?? '');
    ref.watch(contributionsProvider);
    if (language == null) return const _TransmitScaffold(title: 'Des mots', children: []);
    final done = ref.read(contributionsProvider.notifier).donePromptIds(language.id);
    final remaining = collectPrompts.where((p) => !done.contains(p.id) && !_skipped.contains(p.id)).toList();
    final color = Color(language.color);

    if (remaining.isEmpty) {
      return _TransmitScaffold(
        title: 'Des mots',
        bottom: FilledButton(onPressed: () => context.pop(), child: const Text('Retour', style: TextStyle(fontSize: 18))),
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.celebration_rounded, size: 80, color: AppColors.green500),
          const SizedBox(height: 16),
          Text(
            done.length == collectPrompts.length
                ? 'Tu as transmis tous les mots de la liste. Merci infiniment !'
                : 'C\'est tout pour aujourd\'hui. Les mots passés reviendront la prochaine fois.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    final prompt = remaining.first;
    return _TransmitScaffold(
      title: 'Des mots en ${language.name}',
      bottom: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                        _skipped.add(prompt.id);
                        _audio = null;
                        _recorderKey++;
                      }),
              child: const Text('Passer', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _audio == null || _saving ? null : () => _send(prompt, language.id),
              child: const Text('Envoyer', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
      children: [
        KpProgressBar(value: done.length / collectPrompts.length, color: color),
        const SizedBox(height: 6),
        Text('${done.length} / ${collectPrompts.length} mots transmis', style: const TextStyle(fontSize: 15, color: AppColors.gray500)),
        const SizedBox(height: 28),
        Text('Comment dit-on en ${language.name} :', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 8),
        Text(
          '« ${prompt.french} »',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 36),
        Recorder(
          key: ValueKey(_recorderKey),
          color: color,
          maxDuration: const Duration(seconds: 30),
          onRecorded: (path) => setState(() => _audio = path),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Proverbe : le proverbe, puis son explication
// ---------------------------------------------------------------------------

class TransmitProverbScreen extends ConsumerStatefulWidget {
  const TransmitProverbScreen({super.key});

  @override
  ConsumerState<TransmitProverbScreen> createState() => _TransmitProverbScreenState();
}

class _TransmitProverbScreenState extends ConsumerState<TransmitProverbScreen> {
  final _translation = TextEditingController();
  String? _proverb;
  String? _meaning;
  int _step = 0;
  bool _saving = false;

  @override
  void dispose() {
    _translation.dispose();
    super.dispose();
  }

  Future<void> _send(String languageId) async {
    setState(() => _saving = true);
    final outcome = await ref.read(contributionsProvider.notifier).add(
          kind: ContributionKind.proverbe,
          languageId: languageId,
          audioPaths: [_proverb!, _meaning!],
          text: _translation.text,
        );
    if (!mounted) return;
    await _thank(context, outcome, 'Ton proverbe est envoyé. L\'équipe va l\'écouter avant de l\'ajouter au jeu.');
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final language = ref.watch(contentProvider).language(player.spokenLanguageId ?? '');
    if (language == null) return const _TransmitScaffold(title: 'Un proverbe', children: []);
    final color = Color(language.color);

    return _TransmitScaffold(
      title: 'Un proverbe',
      bottom: switch (_step) {
        0 => FilledButton(
            onPressed: _proverb == null ? null : () => setState(() => _step = 1),
            child: const Text('Suivant', style: TextStyle(fontSize: 18)),
          ),
        _ => FilledButton(
            onPressed: _meaning == null || _saving ? null : () => _send(language.id),
            child: const Text('Envoyer le proverbe', style: TextStyle(fontSize: 18)),
          ),
      },
      children: [
        Eyebrow('Étape ${_step + 1} sur 2', color: color),
        const SizedBox(height: 8),
        Text(
          _step == 0 ? 'Dis le proverbe en ${language.name}.' : 'Explique ce qu\'il veut dire, et quand on l\'utilise.',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.3),
        ),
        const SizedBox(height: 6),
        Text(
          _step == 0
              ? 'Comme on le disait dans ta famille.'
              : 'Tu peux parler en ${language.name} ou en français.',
          style: const TextStyle(fontSize: 17, color: AppColors.gray500),
        ),
        const SizedBox(height: 32),
        Recorder(
          key: ValueKey('proverbe-$_step'),
          color: color,
          maxDuration: const Duration(minutes: 2),
          onRecorded: (path) => setState(() => _step == 0 ? _proverb = path : _meaning = path),
        ),
        if (_step == 1) ...[
          const SizedBox(height: 32),
          const Text('Facultatif : la traduction en français', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Un jeune peut t\'aider à l\'écrire.', style: TextStyle(fontSize: 15, color: AppColors.gray500)),
          const SizedBox(height: 8),
          TextField(
            controller: _translation,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(fontSize: 17),
            decoration: const InputDecoration(hintText: 'Ex. On ne balaie pas la cour avec une seule main.'),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Conte
// ---------------------------------------------------------------------------

class TransmitTaleScreen extends ConsumerStatefulWidget {
  const TransmitTaleScreen({super.key});

  @override
  ConsumerState<TransmitTaleScreen> createState() => _TransmitTaleScreenState();
}

class _TransmitTaleScreenState extends ConsumerState<TransmitTaleScreen> {
  final _title = TextEditingController();
  String? _audio;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _send(String languageId) async {
    setState(() => _saving = true);
    final outcome = await ref.read(contributionsProvider.notifier).add(
          kind: ContributionKind.conte,
          languageId: languageId,
          audioPaths: [_audio!],
          text: _title.text,
        );
    if (!mounted) return;
    await _thank(context, outcome, 'Ton conte est envoyé. Les jeunes pourront bientôt l\'écouter.');
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final language = ref.watch(contentProvider).language(player.spokenLanguageId ?? '');
    if (language == null) return const _TransmitScaffold(title: 'Un conte', children: []);

    return _TransmitScaffold(
      title: 'Un conte',
      bottom: FilledButton(
        onPressed: _audio == null || _saving ? null : () => _send(language.id),
        child: const Text('Envoyer le conte', style: TextStyle(fontSize: 18)),
      ),
      children: [
        Text(
          'Raconte une histoire en ${language.name}, comme on te la racontait.',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.3),
        ),
        const SizedBox(height: 6),
        const Text(
          'Jusqu\'à 6 minutes. Mets-toi dans un endroit calme.',
          style: TextStyle(fontSize: 17, color: AppColors.gray500),
        ),
        const SizedBox(height: 32),
        Recorder(
          color: AppColors.warning,
          maxDuration: const Duration(minutes: 6),
          onRecorded: (path) => setState(() => _audio = path),
        ),
        const SizedBox(height: 32),
        const Text('Facultatif : le titre du conte', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _title,
          style: const TextStyle(fontSize: 17),
          decoration: const InputDecoration(hintText: 'Ex. L\'araignée et la tortue'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Suivi des transmissions
// ---------------------------------------------------------------------------

class MyContributionsScreen extends ConsumerStatefulWidget {
  const MyContributionsScreen({super.key});

  @override
  ConsumerState<MyContributionsScreen> createState() => _MyContributionsScreenState();
}

class _MyContributionsScreenState extends ConsumerState<MyContributionsScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(contributionsProvider.notifier).sync();
  }

  @override
  Widget build(BuildContext context) {
    final contributions = ref.watch(contributionsProvider);
    final content = ref.watch(contentProvider);
    return _TransmitScaffold(
      title: 'Mes transmissions',
      children: [
        const Text(
          'L\'équipe écoute chaque transmission avant de l\'ajouter au jeu.',
          style: TextStyle(fontSize: 16, color: AppColors.gray500),
        ),
        const SizedBox(height: 16),
        for (final c in contributions) ...[
          AppCard(
            child: Row(
              children: [
                Icon(
                  switch (c.kind) {
                    ContributionKind.mot => Icons.record_voice_over_rounded,
                    ContributionKind.proverbe => Icons.format_quote_rounded,
                    ContributionKind.conte => Icons.auto_stories_rounded,
                  },
                  size: 30,
                  color: AppColors.gray700,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      Text(
                        '${content.language(c.languageId)?.name ?? ''} · ${c.createdAt.day}/${c.createdAt.month}',
                        style: const TextStyle(fontSize: 14, color: AppColors.gray500),
                      ),
                      const SizedBox(height: 6),
                      _StatusChip(status: c.status),
                    ],
                  ),
                ),
                if (c.audioPaths.isNotEmpty) AudioButton(source: c.audioPaths.first),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ContributionStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      ContributionStatus.aEnvoyer => (AppColors.gray500, Icons.cloud_upload_outlined),
      ContributionStatus.enVerification => (AppColors.warning, Icons.hourglass_top_rounded),
      ContributionStatus.publie => (AppColors.green500, Icons.verified_rounded),
      ContributionStatus.refuse => (AppColors.gray400, Icons.block_rounded),
    };
    return StatPill(icon: icon, label: status.label, color: color);
  }
}
