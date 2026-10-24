import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'models/content.dart';
import 'services/backend.dart';
import 'services/contributions.dart';
import 'services/providers.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final results = await Future.wait([
    SharedPreferences.getInstance(),
    Backend.init(),
    rootBundle.loadString('assets/content/content_v2.json'),
  ]);
  final bundled = ContentPack.fromJson(jsonDecode(results[2] as String) as Map<String, dynamic>);

  final container = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(results[0] as SharedPreferences),
      backendProvider.overrideWithValue(results[1] as Backend),
      bundledContentProvider.overrideWithValue(bundled),
    ],
  );

  // Synchronisation en arrière-plan : l'app démarre tout de suite, même
  // sans réseau.
  container.read(analyticsProvider).track('app_open');
  container.read(contentProvider.notifier).refresh();
  container.read(playerProvider.notifier).syncOnStart().then((_) => container.read(contributionsProvider.notifier).sync());

  // Retour dans l'app (après être passé sur WhatsApp, par ex.) : on récupère
  // le contenu modifié dans Supabase et on envoie les événements en attente.
  AppLifecycleListener(
    onResume: () {
      container.read(contentProvider.notifier).refresh();
      container.read(analyticsProvider).flush();
      container.read(contributionsProvider.notifier).sync();
    },
  );

  runApp(UncontrolledProviderScope(container: container, child: const KoumanPlayApp()));
}

class KoumanPlayApp extends ConsumerWidget {
  const KoumanPlayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'KoumanPlay',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => MobileFrame(child: child ?? const SizedBox()),
    );
  }
}
