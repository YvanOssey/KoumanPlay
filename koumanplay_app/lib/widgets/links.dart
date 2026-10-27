import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ouvre un lien externe (site d'un musée, page d'un événement).
Future<void> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final opened = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d\'ouvrir le lien : $url')));
  }
}

/// Image distante, ou un aplat avec une icône si elle manque ou ne charge pas.
class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.url,
    required this.icon,
    required this.color,
    this.iconSize = 32,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final IconData icon;
  final Color color;
  final double iconSize;

  /// `contain` pour montrer une œuvre en entier (fiche), `cover` pour remplir une vignette.
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: color.withValues(alpha: 0.12),
      child: Center(child: Icon(icon, color: color, size: iconSize)),
    );
    final src = url;
    if (src == null || src.isEmpty) return placeholder;
    return Image.network(
      src,
      fit: fit,
      // Version web : les musées n'autorisent pas toujours le chargement direct
      // (CORS) ; on affiche donc les images avec une balise <img>.
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      errorBuilder: (_, _, _) => placeholder,
      loadingBuilder: (context, child, progress) => progress == null ? child : placeholder,
    );
  }
}
