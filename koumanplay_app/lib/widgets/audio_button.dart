import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../core/theme.dart';

/// Lit la prononciation enregistrée par un aîné. [source] : URL (Supabase
/// Storage, ou blob: sur le web), chemin d'asset commençant par « assets/ »,
/// ou fichier enregistré sur le téléphone.
class AudioButton extends StatefulWidget {
  const AudioButton({super.key, required this.source, this.size = 40});

  final String source;
  final double size;

  @override
  State<AudioButton> createState() => _AudioButtonState();
}

class _AudioButtonState extends State<AudioButton> {
  final _player = AudioPlayer();
  bool _loading = false;
  bool _failed = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final source = widget.source;
      if (source.startsWith('assets/')) {
        await _player.setAsset(source);
      } else if (source.startsWith('http') || source.startsWith('blob:')) {
        await _player.setUrl(source);
      } else {
        await _player.setFilePath(source);
      }
      setState(() => _loading = false);
      await _player.seek(Duration.zero);
      await _player.play();
    } catch (_) {
      // Pas de réseau ou fichier introuvable : on n'interrompt pas la partie.
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      style: IconButton.styleFrom(backgroundColor: AppColors.purple500, fixedSize: Size.square(widget.size)),
      iconSize: widget.size * 0.55,
      tooltip: _failed ? 'Audio indisponible' : 'Écouter',
      onPressed: _loading ? null : _play,
      icon: _loading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
          : Icon(_failed ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: AppColors.white),
    );
  }
}
