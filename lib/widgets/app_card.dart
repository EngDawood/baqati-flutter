import 'package:flutter/material.dart';

import 'package:baqati/theme/app_colors.dart';

/// The white, hairline-bordered surface every screen builds its sections from.
///
/// The design has no elevation anywhere — depth comes from the border alone —
/// so this deliberately does not use [Card].
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.color = AppColors.cardBackground,
    this.bordered = true,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final bool bordered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(radius);

    final Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: bordered ? Border.all(color: AppColors.borderColor) : null,
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: borderRadius, child: content),
    );
  }
}
