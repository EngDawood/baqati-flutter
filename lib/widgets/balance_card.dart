import 'package:flutter/material.dart';

import 'package:baqati/theme/app_colors.dart';
import 'package:baqati/widgets/app_card.dart';

/// One of the three remaining-allowance tiles on the dashboard.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    required this.icon,
    required this.value,
    required this.unit,
    super.key,
  });

  final String icon;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: 20,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          unit,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}
