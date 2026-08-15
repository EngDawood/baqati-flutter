import 'package:flutter/material.dart';

import 'package:baqati/theme/app_colors.dart';

/// The plain title row the design uses instead of a Material [AppBar].
///
/// Back navigation is a rounded white tile rather than a bare icon, and it is
/// automatically mirrored for RTL by [Icons.arrow_back] pointing at the start
/// edge.
class ScreenAppBar extends StatelessWidget {
  const ScreenAppBar({
    required this.title,
    this.onBack,
    this.trailing,
    super.key,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
    child: Row(
      children: <Widget>[
        if (onBack != null) ...<Widget>[
          Material(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(13),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}
