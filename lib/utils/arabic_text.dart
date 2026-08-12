/// Text normalization shared by the SMS parser and the UI.
abstract final class ArabicText {
  /// U+0660..U+0669 -- Arabic-Indic digits zero through nine.
  static const int _easternZero = 0x0660;
  static const int _easternNine = 0x0669;

  /// U+0640 -- tatweel (kashida), a decorative letter-stretching character.
  static const int _tatweel = 0x0640;

  /// U+066B -- Arabic decimal separator.
  static const int _arabicDecimal = 0x066B;

  /// U+066C -- Arabic thousands separator.
  ///
  /// Distinct from both the ASCII comma and the Arabic comma (U+060C). The
  /// Kotlin stripped only the ASCII one, so a number separated by this
  /// character parsed as just its leading digits.
  static const int _arabicThousands = 0x066C;

  static const int _asciiComma = 0x002C;
  static const int _asciiZero = 0x0030;
  static const int _asciiNine = 0x0039;
  static const int _dot = 0x002E;

  /// Zero-width and bidirectional formatting characters.
  ///
  /// PORT-FIX: the Kotlin stripped only the tatweel. Carriers and handsets
  /// routinely wrap embedded digit runs in RTL text with these marks, and
  /// because they are Unicode category Cf they are NOT matched by `\s` -- so a
  /// single invisible character between a keyword and its number makes the
  /// anchor regex fail and the value silently default to zero.
  ///
  /// Identified by code point rather than written literally, since these
  /// characters are invisible in source and corrupt the reading order of the
  /// file itself.
  static bool _isInvisibleMark(int rune) =>
      // U+200B..U+200F zero-width space/joiners, LRM, RLM.
      (rune >= 0x200B && rune <= 0x200F) ||
      // U+061C Arabic letter mark.
      rune == 0x061C ||
      // U+202A..U+202E bidi embeddings and overrides.
      (rune >= 0x202A && rune <= 0x202E) ||
      // U+2066..U+2069 bidi isolates.
      (rune >= 0x2066 && rune <= 0x2069) ||
      // U+FEFF byte-order mark.
      rune == 0xFEFF;

  /// Prepares raw SMS text for regex matching.
  ///
  /// Applied once to the whole body before any parsing rule runs, so every rule
  /// sees identical input.
  ///
  /// The Arabic comma (U+060C) is deliberately preserved -- the multi-package
  /// balance format splits on it to separate entries.
  static String normalizeForParsing(String input) {
    final StringBuffer buffer = StringBuffer();

    for (final int rune in input.runes) {
      if (_isInvisibleMark(rune) ||
          rune == _tatweel ||
          rune == _arabicThousands ||
          rune == _asciiComma) {
        continue;
      }
      if (rune >= _easternZero && rune <= _easternNine) {
        buffer.writeCharCode(_asciiZero + (rune - _easternZero));
        continue;
      }
      if (rune == _arabicDecimal) {
        buffer.writeCharCode(_dot);
        continue;
      }
      buffer.writeCharCode(rune);
    }
    return buffer.toString();
  }

  /// Renders Western digits in [input] as Arabic-Indic, for display only.
  ///
  /// Never apply this before parsing -- [normalizeForParsing] expects the
  /// carrier's original text.
  static String toArabicIndic(String input) {
    final StringBuffer buffer = StringBuffer();
    for (final int rune in input.runes) {
      if (rune >= _asciiZero && rune <= _asciiNine) {
        buffer.writeCharCode(_easternZero + (rune - _asciiZero));
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }
}
