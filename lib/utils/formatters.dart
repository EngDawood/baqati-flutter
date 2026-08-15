import 'package:intl/intl.dart';

import 'package:baqati/utils/arabic_text.dart';

/// Display formatting for every user-facing number and date.
///
/// The app renders Arabic-Indic digits throughout, matching the design
/// prototype. Screens must not call [DateFormat] or [num.toString] directly —
/// route through here so a single place decides how digits look.
///
/// Note the asymmetry with [ArabicText.normalizeForParsing]: that converts the
/// carrier's Arabic-Indic digits *to* Western ones so the regexes can match.
/// This converts back, for display only.
abstract final class Formatters {
  static const String _locale = 'ar';

  /// U+066B, the Arabic decimal separator.
  static const String _arabicDecimal = '٫';

  /// Renders [value] with Arabic-Indic digits, dropping a redundant `.0`.
  ///
  /// Package allowances arrive as doubles but read as counts — "٣٠٠ دقيقة",
  /// not "٣٠٠٫٠ دقيقة".
  static String number(num? value, {String fallback = '—'}) {
    if (value == null) return fallback;

    final String western = value is int || value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();

    return ArabicText.toArabicIndic(western).replaceAll('.', _arabicDecimal);
  }

  /// A money amount with its unit, e.g. `٢٠٦٦٫٢٥ ريال`.
  static String riyal(num? value, {String fallback = '—'}) =>
      value == null ? fallback : '${number(value)} ريال';

  /// `٢١/٠٦/٢٠٢٦`
  static String date(DateTime value) => _format('dd/MM/yyyy', value);

  /// `٢١/٠٦` — the compact form history cards use inside a longer sentence.
  static String shortDate(DateTime value) => _format('dd/MM', value);

  /// `١٦/٠٦/٢٠٢٦ — ٣:٠١ ص`
  static String dateTime(DateTime value) => '${date(value)} — ${time(value)}';

  /// `٣:٠١ ص`
  static String time(DateTime value) => _format('h:mm a', value);

  /// `السبت ٢١ يونيو ٢٠٢٦ — ١٢:٠٠ ص`
  static String longDateTime(DateTime value) =>
      '${_format('EEEE d MMMM yyyy', value)} — ${time(value)}';

  /// How long ago [value] was, in the coarsest unit that still reads naturally.
  ///
  /// PORT-FIX: `HistoryScreen.kt:82` passed the literal string "قبل قليل" for
  /// every row, so a month-old event and a five-minute-old one were
  /// indistinguishable — and a backfilled inbox is mostly old events.
  static String relativeTime(DateTime value, {DateTime? now}) {
    final Duration elapsed = (now ?? DateTime.now()).difference(value);

    if (elapsed.isNegative) return 'الآن';
    if (elapsed.inMinutes < 1) return 'قبل قليل';
    if (elapsed.inMinutes < 60) return 'قبل ${number(elapsed.inMinutes)} دقيقة';
    if (elapsed.inHours < 24) return 'قبل ${number(elapsed.inHours)} ساعة';
    if (elapsed.inDays < 30) return 'قبل ${number(elapsed.inDays)} يوم';

    // Past a month, an absolute date is more useful than "قبل ٤٧ يوم".
    return dateTime(value);
  }

  /// Splits [remaining] into whole days, hours and minutes for the countdown.
  ///
  /// Returns zeros for an elapsed duration rather than negative components, so
  /// callers can render the expired state without re-checking the sign.
  static ({int days, int hours, int minutes}) countdown(Duration remaining) {
    if (remaining <= Duration.zero) {
      return (days: 0, hours: 0, minutes: 0);
    }
    return (
      days: remaining.inDays,
      hours: remaining.inHours.remainder(24),
      minutes: remaining.inMinutes.remainder(60),
    );
  }

  /// `تنتهي خلال ٥ يوم و ٣ ساعة`, shortening to hours once under a day.
  static String remainingLabel(Duration remaining) {
    if (remaining <= Duration.zero) return 'منتهية';

    final ({int days, int hours, int minutes}) parts = countdown(remaining);
    if (parts.days > 0) {
      return 'تنتهي خلال ${number(parts.days)} يوم و ${number(parts.hours)} ساعة';
    }
    if (parts.hours > 0) return 'تنتهي خلال ${number(parts.hours)} ساعة';
    return 'تنتهي خلال ${number(parts.minutes)} دقيقة';
  }

  static String _format(String pattern, DateTime value) =>
      ArabicText.toArabicIndic(DateFormat(pattern, _locale).format(value));
}
