import 'package:flutter/material.dart';

import 'package:baqati/theme/app_colors.dart';

/// Shown when a screen genuinely has nothing to display.
///
/// PORT-FIX: the Kotlin had no empty state anywhere. `HistoryScreen.kt:65`
/// filled an empty database with four hardcoded fake events instead, so a new
/// user's first impression was a history of things that never happened, none of
/// which could be deleted because no row backed them.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final String icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(icon, style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          if (action != null) ...<Widget>[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}
