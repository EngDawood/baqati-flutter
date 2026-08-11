import 'package:flutter/material.dart';

import 'package:baqati/theme/app_colors.dart';

/// The single font family the app renders in.
///
/// The Kotlin reference declares a full Material type scale plus two Serif
/// families, but no screen ever reads `MaterialTheme.typography` — every `Text`
/// passes literal sizes and weights. The ported screens do the same, so this
/// theme deliberately sets only the family and leaves sizing to call sites.
const String kFontFamily = 'ThmanyahSans';

/// Maps [FontWeight.w600] onto the Bold file.
///
/// The Kotlin screens use `FontWeight.SemiBold` extensively, but no semibold
/// `.ttf` exists in the family. Compose silently synthesized it; Flutter's
/// matching is less forgiving, so the choice is made explicitly here rather
/// than left to the engine.
const FontWeight semiBold = FontWeight.w700;

abstract final class AppTheme {
  static ThemeData get light {
    final ColorScheme scheme = const ColorScheme.light().copyWith(
      primary: AppColors.blueMain,
      onPrimary: Colors.white,
      secondary: AppColors.orangeMain,
      surface: AppColors.cardBackground,
      onSurface: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: kFontFamily,
      scaffoldBackgroundColor: AppColors.backgroundMain,
      dividerColor: AppColors.dividerColor,
      // The design has no elevation-tinted surfaces; cards are flat white with
      // a hairline border.
      cardTheme: const CardThemeData(
        color: AppColors.cardBackground,
        elevation: 0,
      ),
      textTheme: const TextTheme().apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
        fontFamily: kFontFamily,
      ),
    );
  }
}
