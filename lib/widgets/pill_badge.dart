import 'package:flutter/material.dart';

import 'package:baqati/theme/app_theme.dart';

/// A small rounded status chip — "نشطة", "يُفقد عند الانتهاء", history tags.
class PillBadge extends StatelessWidget {
  const PillBadge({
    required this.label,
    required this.background,
    required this.foreground,
    this.fontSize = 11,
    super.key,
  });

  final String label;
  final Color background;
  final Color foreground;
  final double fontSize;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: semiBold,
          color: foreground,
        ),
      ),
    ),
  );
}
