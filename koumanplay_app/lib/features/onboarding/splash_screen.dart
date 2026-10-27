import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';
import '../../widgets/common.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Joueur déjà inscrit : on passe directement à l'accueil.
    if (ref.read(playerProvider).onboarded) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) context.go('/play');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final returning = ref.watch(playerProvider).onboarded;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          // Toute la largeur : sans bouton (joueur qui revient), la colonne
          // prendrait la largeur du slogan et serait décalée à gauche.
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                const Spacer(),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                  child: const BrandLogo(size: 140),
                ),
                const SizedBox(height: 24),
                Text('KoumanPlay', style: theme.textTheme.displaySmall),
                const SizedBox(height: 8),
                Text(
                  'Apprendre. Partager. Se rapprocher.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.gray700),
                ),
                const Spacer(),
                if (!returning)
                  FilledButton(onPressed: () => context.go('/onboarding'), child: const Text('Commencer l\'aventure'))
                else
                  const CircularProgressIndicator(color: AppColors.purple500),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
