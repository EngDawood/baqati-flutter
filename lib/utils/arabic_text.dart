/// Text normalization shared by the SMS parser and the UI.
abstract final class ArabicText {
  static const Map<String, String> _easternDigits = <String, String>{
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
  };

  static const List<String> _easternDigitChars = <String>[
    '٠',
    '١',
    '٢',
    '٣',
    '٤',
    '٥',
    '٦',
    '٧',
    '٨',
    '٩',
  ];

  /// Zero-width and bidirectional formatting characters, written as escapes
  /// because they are invisible in source.
  ///
  /// PORT-FIX: the Kotlin stripped only the tatweel. Carriers and handsets
  /// routinely wrap embedded digit runs in RTL text with these marks, and
  /// because they are Unicode category `Cf` they are *not* matched by `\s` —
  /// so a single invisible character between a keyword and its number makes
  /// the anchor regex fail and the value silently default to zero.
  static final RegExp _invisibleMarks = RegExp(
    '[​-‏؜‪-‮⁦-⁩﻿]',
  );

  /// Arabic tatweel (kashida), a decorative letter-stretching character.
  static const String _tatweel = 'ـ';

  /// Arabic decimal separator (U+066B).
  static const String _arabicDecimal = '٫';

  /// Arabic thousands separator (U+066C).
  ///
  /// Distinct from both the ASCII comma and the Arabic comma (U+060C); the
  /// Kotlin stripped only the former, so "1٬234" parsed as 1.
  static const String _arabicThousands = '٬';

  /// Prepares raw SMS text for regex matching.
  ///
  /// Applied once to the whole body before any parsing rule runs, so every rule
  /// sees identical input.
  ///
  /// Note that the Arabic comma (`،`) is deliberately preserved — the
  /// multi-package balance format splits on it to separate entries.
  static String normalizeForParsing(String input) {
    final String stripped = input
        .replaceAll(_invisibleMarks, '')
        .replaceAll(_tatweel, '');

    final StringBuffer buffer = StringBuffer();
    for (final String char in stripped.split('')) {
      final String? digit = _easternDigits[char];
      if (digit != null) {
        buffer.write(digit);
        continue;
      }
      if (char == _arabicDecimal) {
        buffer.write('.');
        continue;
      }
      if (char == _arabicThousands || char == ',') {
        continue;
      }
      buffer.write(char);
    }
    return buffer.toString();
  }

  /// Renders Western digits in [input] as Arabic-Indic, for display only.
  ///
  /// Never apply this before parsing — [normalizeForParsing] expects the
  /// carrier's original text.
  static String toArabicIndic(String input) {
    final StringBuffer buffer = StringBuffer();
    for (final String char in input.split('')) {
      final int digit = int.tryParse(char) ?? -1;
      buffer.write(digit >= 0 ? _easternDigitChars[digit] : char);
    }
    return buffer.toString();
  }
}
