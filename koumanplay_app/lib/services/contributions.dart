import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/game_rules.dart';
import '../models/contribution.dart';
import 'providers.dart';

const _contributionsKey = 'contributions';

/// Transmissions de l'aîné : gardées sur le téléphone (hors-ligne), envoyées
/// à Supabase dès que possible, puis suivies jusqu'à leur publication.
class ContributionsController extends Notifier<List<Contribution>> {
  bool _syncing = false;

  @override
  List<Contribution> build() {
    final raw = ref.read(prefsProvider).getString(_contributionsKey);
    if (raw == null) return const [];
    try {
      return [for (final c in jsonDecode(raw) as List) Contribution.fromJson(c as Map<String, dynamic>)];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save(List<Contribution> next) async {
    state = next;
    await ref.read(prefsProvider).setString(_contributionsKey, jsonEncode([for (final c in next) c.toJson()]));
  }

  /// Mots de la liste déjà transmis dans [languageId].
  Set<String> donePromptIds(String languageId) => {
        for (final c in state)
          if (c.kind == ContributionKind.mot && c.languageId == languageId && c.promptId != null) c.promptId!,
      };

  Future<ChallengeOutcome> add({
    required ContributionKind kind,
    required String languageId,
    required List<String> audioPaths,
    CollectPrompt? prompt,
    String? text,
  }) async {
    final contribution = Contribution(
      id: const Uuid().v4(),
      kind: kind,
      languageId: languageId,
      promptId: prompt?.id,
      promptFrench: prompt?.french,
      text: text?.trim().isEmpty ?? true ? null : text!.trim(),
      audioPaths: audioPaths,
      createdAt: DateTime.now(),
      status: ContributionStatus.aEnvoyer,
    );
    await _save([contribution, ...state]);
    ref.read(analyticsProvider).track('transmission', {'kind': kind.name, 'language': languageId});
    final outcome = await ref.read(playerProvider.notifier).recordTransmission(kind.name);
    sync();
    return outcome;
  }

  /// Envoie ce qui attend, puis récupère les statuts mis à jour par l'équipe.
  Future<void> sync() async {
    final backend = ref.read(backendProvider);
    if (_syncing || !backend.enabled) return;
    _syncing = true;
    try {
      for (final c in state.where((c) => c.status == ContributionStatus.aEnvoyer).toList()) {
        final audios = <Uint8List>[];
        try {
          for (final path in c.audioPaths) {
            audios.add(await XFile(path).readAsBytes());
          }
        } catch (e) {
          // Enregistrement web perdu après rechargement de la page : rien à envoyer.
          debugPrint('Enregistrement illisible ($e)');
          continue;
        }
        if (!await backend.sendContribution(c, audios, ref.read(playerProvider))) return;
        _replace(c.copyWith(status: ContributionStatus.enVerification));
      }
      final statuses = await backend.fetchContributionStatuses();
      if (statuses == null) return;
      for (final c in state) {
        final remote = statuses[c.id];
        if (remote != null && remote != c.status) _replace(c.copyWith(status: remote));
      }
    } finally {
      _syncing = false;
    }
  }

  void _replace(Contribution updated) {
    _save([for (final c in state) c.id == updated.id ? updated : c]);
  }
}

final contributionsProvider = NotifierProvider<ContributionsController, List<Contribution>>(ContributionsController.new);
