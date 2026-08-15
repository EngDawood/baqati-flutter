import 'package:flutter/material.dart';

import 'package:baqati/theme/app_colors.dart';
import 'package:baqati/theme/app_theme.dart';

/// A labelled remaining-of-total progress bar on the details screen.
///
/// Turns orange below [warningThreshold] of the original allowance.
class UsageBar extends StatelessWidget {
  const UsageBar({
    required this.label,
    required this.value,
    required this.progress,
    super.key,
  });

  static const double warningThreshold = 0.2;

  final String label;

  /// Pre-formatted "remaining / total" text.
  final String value;

  /// Fraction remaining, 0..1.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final double clamped = progress.clamp(0.0, 1.0);
    final bool isWarning = clamped < warningThreshold;

    return Semantics(
      label: label,
      value: value,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: semiBold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 8,
              backgroundColor: AppColors.backgroundMain,
              valueColor: AlwaysStoppedAnimation<Color>(
                isWarning ? AppColors.orangeMain : AppColors.blueMain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
