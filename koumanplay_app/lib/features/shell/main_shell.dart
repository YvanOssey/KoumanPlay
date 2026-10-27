import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/providers.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pour un aîné, le premier onglet est son espace de transmission.
    final senior = ref.watch(playerProvider.select((p) => p.isSenior));
    return Scaffold(
      body: _TabTransition(index: shell.currentIndex, child: shell),
      bottomNavigationBar: _TabBar(
        selectedIndex: shell.currentIndex,
        onSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        tabs: [
          senior
              ? const _Tab(Icons.mic_none_rounded, Icons.mic_rounded, 'Transmettre')
              : const _Tab(Icons.map_outlined, Icons.map_rounded, 'Carte'),
          const _Tab(Icons.handshake_outlined, Icons.handshake_rounded, 'Défis'),
          const _Tab(Icons.collections_bookmark_outlined, Icons.collections_bookmark_rounded, 'Bibliothèque'),
          const _Tab(Icons.event_outlined, Icons.event_rounded, 'Événements'),
          const _Tab(Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
        ],
      ),
    );
  }
}

class _Tab {
  const _Tab(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Barre d'onglets façon Material 3, mais dont les libellés restent sur une
/// seule ligne : ils rétrécissent au besoin sur les petits écrans ou quand le
/// texte du téléphone est agrandi (« Bibliothèque » passait sur deux lignes).
class _TabBar extends StatelessWidget {
  const _TabBar({required this.selectedIndex, required this.onSelected, required this.tabs});

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<_Tab> tabs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).navigationBarTheme;
    return Material(
      color: theme.backgroundColor,
      elevation: 3,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _TabItem(tab: tabs[i], selected: i == selectedIndex, onTap: () => onSelected(i)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab, required this.selected, required this.onTap});

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).navigationBarTheme;
    final states = {if (selected) WidgetState.selected};
    final iconTheme = theme.iconTheme?.resolve(states);
    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        highlightShape: BoxShape.rectangle,
        containedInkWell: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 30,
                decoration: BoxDecoration(
                  color: selected ? theme.indicatorColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(selected ? tab.selectedIcon : tab.icon, size: 24, color: iconTheme?.color),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tab.label,
                  maxLines: 1,
                  softWrap: false,
                  // Le libellé suit la barre (68 px) : on n'applique pas l'agrandissement du texte du téléphone.
                  textScaler: TextScaler.noScaling,
                  style: theme.labelTextStyle?.resolve(states),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fondu + léger glissement quand on change d'onglet, du côté de l'onglet
/// choisi. Le contenu n'est pas recréé : chaque onglet garde son état
/// (position sur la carte, onglet de défis…).
class _TabTransition extends StatefulWidget {
  const _TabTransition({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_TabTransition> createState() => _TabTransitionState();
}

class _TabTransitionState extends State<_TabTransition> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  double _direction = 1;

  @override
  void didUpdateWidget(covariant _TabTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _direction = widget.index > oldWidget.index ? 1 : -1;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return Opacity(
          opacity: 0.4 + 0.6 * t,
          child: FractionalTranslation(translation: Offset(0.06 * _direction * (1 - t), 0), child: child),
        );
      },
    );
  }
}
