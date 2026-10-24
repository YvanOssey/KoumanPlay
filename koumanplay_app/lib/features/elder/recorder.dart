import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme.dart';
import '../../widgets/audio_button.dart';

/// Gros bouton micro pensé pour les aînés : on appuie pour parler, on appuie
/// pour arrêter, on réécoute, on recommence si besoin. [onRecorded] reçoit le
/// chemin de l'enregistrement (null quand on recommence).
class Recorder extends StatefulWidget {
  const Recorder({super.key, required this.onRecorded, this.maxDuration = const Duration(minutes: 1), this.color});

  final ValueChanged<String?> onRecorded;
  final Duration maxDuration;
  final Color? color;

  @override
  State<Recorder> createState() => _RecorderState();
}

enum _Phase { idle, recording, done }

class _RecorderState extends State<Recorder> {
  final _recorder = AudioRecorder();
  _Phase _phase = _Phase.idle;
  String? _path;
  String? _error;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  /// Téléphone : AAC dans un fichier. Web : le premier format que le
  /// navigateur sait enregistrer.
  Future<AudioEncoder> _encoder() async {
    if (!kIsWeb) return AudioEncoder.aacLc;
    for (final e in [AudioEncoder.opus, AudioEncoder.aacLc, AudioEncoder.wav]) {
      if (await _recorder.isEncoderSupported(e)) return e;
    }
    return AudioEncoder.opus;
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      // Délai généreux : la première fois, l'aîné doit répondre à la demande d'accès au micro.
      if (!await _recorder.hasPermission().timeout(const Duration(seconds: 30))) {
        setState(() => _error = 'Autorise le micro dans les réglages du téléphone pour enregistrer.');
        return;
      }
      var path = '';
      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        path = '${dir.path}/transmission-${const Uuid().v4()}.m4a';
      }
      await _recorder.start(RecordConfig(encoder: await _encoder(), numChannels: 1, bitRate: 64000), path: path);
    } catch (e) {
      // Micro refusé ou indisponible (ex. navigateur qui le bloque).
      debugPrint('Enregistrement impossible : $e');
      if (mounted) setState(() => _error = 'Le micro n\'est pas disponible. Vérifie qu\'il est autorisé.');
      return;
    }
    _elapsed = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
      if (_elapsed >= widget.maxDuration) _stop();
    });
    setState(() => _phase = _Phase.recording);
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _path = path;
      _phase = path == null ? _Phase.idle : _Phase.done;
    });
    widget.onRecorded(path);
  }

  void _restart() {
    setState(() {
      _path = null;
      _phase = _Phase.idle;
    });
    widget.onRecorded(null);
  }

  String _format(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.purple500;
    return Column(
      children: [
        if (_phase == _Phase.done) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AudioButton(source: _path!, size: 64),
              const SizedBox(width: 16),
              const Text('Réécoute ton enregistrement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Recommencer', style: TextStyle(fontSize: 18)),
          ),
        ] else ...[
          GestureDetector(
            onTap: _phase == _Phase.recording ? _stop : _start,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _phase == _Phase.recording ? AppColors.error : color,
                boxShadow: [
                  BoxShadow(
                    color: (_phase == _Phase.recording ? AppColors.error : color).withValues(alpha: 0.4),
                    blurRadius: _phase == _Phase.recording ? 36 : 18,
                    spreadRadius: _phase == _Phase.recording ? 6 : 0,
                  ),
                ],
              ),
              child: Icon(
                _phase == _Phase.recording ? Icons.stop_rounded : Icons.mic_rounded,
                color: AppColors.white,
                size: 72,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _phase == _Phase.recording
                ? 'J\'écoute…  ${_format(_elapsed)}\nAppuie pour arrêter'
                : 'Appuie sur le micro et parle',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error, fontSize: 16)),
        ],
      ],
    );
  }
}
