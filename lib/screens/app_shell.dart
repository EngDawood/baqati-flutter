import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:baqati/theme/app_colors.dart';
import 'package:baqati/theme/app_theme.dart';

/// Hosts the three bottom-tab destinations and the bar itself.
///
/// PORT-FIX: the Kotlin bar called `navigate(route) { popUpTo(0) }` on every
/// tap, with no `launchSingleTop`, so re-tapping the active tab tore down and
/// rebuilt that screen — losing scroll position and any in-progress form — and
/// wiped the whole back stack. [StatefulShellRoute] keeps each branch's state
/// alive independently instead.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: navigationShell,
    bottomNavigationBar: _BottomNavBar(
      currentIndex: navigationShell.currentIndex,
      onTap: (int index) => navigationShell.goBranch(
        index,
        // Re-tapping the active tab returns to that branch's root rather than
        // rebuilding it.
        initialLocation: index == navigationShell.currentIndex,
      ),
    ),
  );
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<({String emoji, String label})> _items =
      <({String emoji, String label})>[
        (emoji: '🏠', label: 'الرئيسية'),
        (emoji: '🗂️', label: 'السجل'),
        (emoji: '⚙️', label: 'الإعدادات'),
      ];

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.cardBackground,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            for (int i = 0; i < _items.length; i++)
              _NavItem(
                emoji: _items[i].emoji,
                label: _items[i].label,
                selected: i == currentIndex,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected
        ? AppColors.blueMain
        : AppColors.textQuaternary;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          // PORT-FIX: padding raises the touch target to the 48dp minimum
          // without changing how the item looks.
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: selected ? semiBold : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
