import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/challenges/challenge_detail_screen.dart';
import '../features/challenges/challenges_screen.dart';
import '../features/elder/transmit_screens.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/profile_setup_screen.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/play/map_screen.dart';
import '../features/play/quiz_screen.dart';
import '../features/play/result_screen.dart';
import '../features/profile/account_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/shell/main_shell.dart';
import '../services/providers.dart';
import 'game_rules.dart';

const _publicRoutes = {'/', '/onboarding', '/setup'};

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final onboarded = ref.read(playerProvider).onboarded;
      final location = state.matchedLocation;
      if (!onboarded && !_publicRoutes.contains(location)) return '/';
      // Progression récupérée depuis Supabase pendant l'onboarding.
      if (onboarded && (location == '/onboarding' || location == '/setup')) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/setup', builder: (context, state) => const ProfileSetupScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (context, state) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/play', builder: (context, state) => const MapScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/challenges', builder: (context, state) => const ChallengesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen())]),
        ],
      ),
      GoRoute(
        path: '/quiz/:levelId',
        builder: (context, state) => QuizScreen(levelId: state.pathParameters['levelId']!),
      ),
      GoRoute(
        path: '/result',
        builder: (context, state) {
          final outcome = state.extra;
          if (outcome is! LevelOutcome) return const _Redirect('/play');
          return ResultScreen(outcome: outcome);
        },
      ),
      GoRoute(
        path: '/challenge/:id',
        builder: (context, state) => ChallengeDetailScreen(challengeId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/account', builder: (context, state) => const AccountScreen()),
      GoRoute(
        path: '/transmettre/accord',
        builder: (context, state) => ConsentScreen(next: state.uri.queryParameters['next'] ?? '/home'),
      ),
      GoRoute(path: '/transmettre/mots', builder: (context, state) => const TransmitWordsScreen()),
      GoRoute(path: '/transmettre/proverbe', builder: (context, state) => const TransmitProverbScreen()),
      GoRoute(path: '/transmettre/conte', builder: (context, state) => const TransmitTaleScreen()),
      GoRoute(path: '/transmettre/envois', builder: (context, state) => const MyContributionsScreen()),
    ],
  );
  ref.listen(playerProvider.select((p) => p.onboarded), (_, _) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});

/// Écran de résultat ouvert sans données (ex. rechargement web) : on renvoie
/// vers une page valide.
class _Redirect extends StatelessWidget {
  const _Redirect(this.location);

  final String location;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => context.go(location));
    return const Scaffold();
  }
}
