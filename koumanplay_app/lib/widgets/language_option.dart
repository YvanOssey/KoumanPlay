import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/content.dart';
import 'common.dart';

/// Une langue à choisir : nom, région, et si son contenu est encore en collecte.
class LanguageOption extends StatelessWidget {
  const LanguageOption({super.key, required this.language, required this.ready, required this.selected, required this.onTap});

  final Language language;

  /// Au moins un niveau jouable.
  final bool ready;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(language.color);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: selected ? color : Colors.transparent, width: 2),
      ),
      child: AppCard(
        onTap: onTap,
        color: selected ? color.withValues(alpha: 0.12) : AppColors.white,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text(language.name.characters.first,
                  style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w700, fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(language.name, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    ready ? '${language.group} · ${language.region}' : 'Contenu en collecte avec les aînés',
                    style: const TextStyle(color: AppColors.gray500, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? color : AppColors.gray400,
            ),
          ],
        ),
      ),
    );
  }
}
