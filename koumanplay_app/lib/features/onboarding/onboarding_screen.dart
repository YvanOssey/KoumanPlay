import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

class _Page {
  const _Page(this.image, this.title, this.text);

  final String image;
  final String title;
  final String text;
}

const _pages = [
  _Page('assets/images/onboarding1.webp', 'Joue', 'Découvre des activités ludiques autour de la culture ivoirienne.'),
  _Page('assets/images/onboarding2.webp', 'Apprends', 'Baoulé, Bété, Dioula, Sénoufo : des premiers mots jusqu\'aux proverbes.'),
  _Page('assets/images/onboarding3.webp', 'Partage', 'Relève des défis qui rapprochent les jeunes et les aînés.'),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _pages.length - 1) {
      context.go('/setup');
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => context.go('/setup'), child: const Text('Passer')),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Column(
                    children: [
                      Expanded(child: Image.asset(page.image, fit: BoxFit.cover, alignment: Alignment.topCenter, width: double.infinity)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                        child: Column(
                          children: [
                            Text(page.title, style: theme.textTheme.headlineMedium),
                            const SizedBox(height: 8),
                            Text(
                              page.text,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.gray700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? AppColors.purple500 : AppColors.gray200,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: FilledButton(
                onPressed: _next,
                child: Text(_index == _pages.length - 1 ? 'C\'est parti' : 'Suivant'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
