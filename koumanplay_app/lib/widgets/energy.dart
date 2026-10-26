import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/game_rules.dart';
import '../core/theme.dart';
import '../models/player.dart';
import '../services/providers.dart';
import 'common.dart';

/// « 14 min » ou « 45 s ».
String formatWait(Duration wait) =>
    wait.inSeconds < 60 ? '${wait.inSeconds} s' : '${(wait.inSeconds / 60).ceil()} min';

/// Redessine son contenu chaque seconde tant que l'énergie remonte.
class EnergyBuilder extends ConsumerStatefulWidget {
  const EnergyBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, int energy, Duration? nextIn) builder;

  @override
  ConsumerState<EnergyBuilder> createState() => _EnergyBuilderState();
}

class _EnergyBuilderState extends ConsumerState<EnergyBuilder> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final player = ref.read(playerProvider);
      if (GameRules.nextEnergyIn(player, DateTime.now()) != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final now = DateTime.now();
    return widget.builder(context, GameRules.energyAt(player, now), GameRules.nextEnergyIn(player, now));
  }
}

/// Pastille d'énergie : « 3/5 · 12 min ».
class EnergyPill extends StatelessWidget {
  const EnergyPill({super.key});

  @override
  Widget build(BuildContext context) {
    return EnergyBuilder(
      builder: (context, energy, nextIn) => StatPill(
        icon: Icons.bolt_rounded,
        label: nextIn == null ? '$energy/${PlayerState.maxEnergy}' : '$energy/${PlayerState.maxEnergy} · ${formatWait(nextIn)}',
        color: energy == 0 ? AppColors.error : AppColors.purple500,
      ),
    );
  }
}

/// Ouvre un niveau s'il reste de l'énergie, sinon explique l'attente.
Future<void> startLevel(BuildContext context, WidgetRef ref, String levelId, {bool replace = false}) async {
  final player = ref.read(playerProvider);
  if (GameRules.energyAt(player, DateTime.now()) > 0) {
    replace ? context.pushReplacement('/quiz/$levelId') : context.push('/quiz/$levelId');
    return;
  }
  await showDialog<void>(context: context, builder: (_) => const OutOfEnergyDialog());
}

class OutOfEnergyDialog extends StatelessWidget {
  const OutOfEnergyDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.bolt_rounded, color: AppColors.error, size: 40),
      title: const Text('Plus d\'énergie'),
      content: EnergyBuilder(
        builder: (context, energy, nextIn) => Text(
          energy > 0
              ? 'Ton énergie est revenue : tu peux rejouer !'
              : 'Chaque mauvaise réponse coûte une énergie. La prochaine revient dans '
                  '${formatWait(nextIn ?? GameRules.energyRefill)}.\n\nEn attendant, révise avec un aîné ou relève un défi.',
          textAlign: TextAlign.center,
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('D\'accord'))],
    );
  }
}
