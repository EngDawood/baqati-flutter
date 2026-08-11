import 'package:flutter/material.dart';

/// The app's color palette, ported from the Kotlin reference's `ui/theme/Color.kt`.
///
/// Two tokens deliberately differ from the original — see [textTertiary] and
/// [textQuaternary]. Everything else matches the Compose values exactly.
abstract final class AppColors {
  // Blues — primary brand color.
  static const Color blueMain = Color(0xFF0061A4);
  static const Color blueLight = Color(0xFF4A94DD);
  static const Color blueDark = Color(0xFF001D36);
  static const Color blueBg = Color(0xFFD3E4FF);
  static const Color blueTextDark = Color(0xFF001D36);
  static const Color blueTextLight = Color(0xFF0061A4);

  // Oranges — warnings and expiry states.
  static const Color orangeMain = Color(0xFFF5841F);
  static const Color orangeLight = Color(0xFFFB9A33);
  static const Color orangeDark = Color(0xFFC2611B);
  static const Color orangeBg = Color(0xFFFFE9D4);
  static const Color orangeTextDark = Color(0xFF8A4E12);
  static const Color orangeBadgeBg = Color(0xFFFFEDDC);

  // Greens — payment and deduction tags.
  static const Color greenMain = Color(0xFF2E7D52);
  static const Color greenBg = Color(0xFFE3F0E8);

  /// PORT-FIX: the Kotlin used [greenBg] for real events but this near-identical
  /// tint for the mock ones (`HistoryScreen.kt:68`). Kept as an alias so the two
  /// code paths can't drift apart again.
  static const Color greenIconBg = greenBg;

  // Text.
  static const Color textPrimary = Color(0xFF191C1E);
  static const Color textSecondary = Color(0xFF64748B);

  /// PORT-FIX: was `#94A3B8` (~2.5:1 on white, below WCAG AA's 4.5:1).
  /// Darkened for legibility on small section labels.
  static const Color textTertiary = Color(0xFF5C6B7F);

  /// PORT-FIX: was `#CBD5E1` (~1.4:1 on white — effectively invisible outdoors).
  /// Used for 11sp timestamps, so contrast matters more here than anywhere.
  static const Color textQuaternary = Color(0xFF8A97A8);

  // Surfaces.
  static const Color backgroundMain = Color(0xFFF7F9FF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color surfaceTint = Color(0xFFF3F4F9);
  static const Color dividerColor = Color(0xFFE2E8F0);
  static const Color borderColor = Color(0xFFF1F5F9);

  // Colors that the Kotlin screens hardcoded inline rather than tokenizing.
  // Named here so the ported screens don't scatter raw hex literals.
  static const Color smsBannerBg = Color(0xFFEBF3FE);
  static const Color smsBannerBorder = Color(0xFFC7DCFA);
  static const Color onboardingBg = Color(0xFFF7F8FB);
  static const Color privacyNoteBg = Color(0xFFFFF4E9);
  static const Color privacyNoteText = Color(0xFF9A5A18);
  static const Color permissionItemBorder = Color(0xFFE3EAFB);
  static const Color dividerLine = Color(0xFFF0F2F7);
}
