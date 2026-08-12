import 'package:flutter_test/flutter_test.dart';

import 'package:baqati/utils/arabic_text.dart';

/// Bidi marks are built from code points so no invisible characters end up in
/// this file.
String _mark(int codePoint) => String.fromCharCode(codePoint);

void main() {
  final String lrm = _mark(0x200E);
  final String rlm = _mark(0x200F);
  final String arabicLetterMark = _mark(0x061C);
  final String zeroWidthSpace = _mark(0x200B);
  final String isolate = _mark(0x2066);
  final String byteOrderMark = _mark(0xFEFF);

  group('normalizeForParsing', () {
    test('converts Arabic-Indic digits to Western', () {
      expect(ArabicText.normalizeForParsing('١٢٣٤٥٦٧٨٩٠'), '1234567890');
    });

    test('converts the Arabic decimal separator to a dot', () {
      expect(ArabicText.normalizeForParsing('٢٤٧٫٣٥'), '247.35');
    });

    test('strips both ASCII and Arabic thousands separators', () {
      expect(ArabicText.normalizeForParsing('1,234'), '1234');
      // PORT-FIX: the Kotlin stripped only the ASCII comma, so this parsed as 1.
      expect(ArabicText.normalizeForParsing('١٬٢٣٤'), '1234');
    });

    test('strips the tatweel', () {
      expect(ArabicText.normalizeForParsing('رصيــدك'), 'رصيدك');
    });

    test('strips bidi and zero-width marks', () {
      final String noisy =
          'رصيدك$lrm هو$rlm 500$arabicLetterMark$zeroWidthSpace$isolate$byteOrderMark';
      expect(ArabicText.normalizeForParsing(noisy), 'رصيدك هو 500');
    });

    test('leaves an anchor regex able to match across a bidi mark', () {
      // PORT-FIX: a single invisible mark between keyword and number made the
      // Kotlin's anchor regex fail, defaulting the amount to zero.
      final String normalized = ArabicText.normalizeForParsing(
        'رصيدك هو $lrm١٬٢٣٤٫٥ ريال',
      );
      final RegExpMatch? match = RegExp(
        r'رصيدك هو\s*([\d.]+)',
      ).firstMatch(normalized);
      expect(match?.group(1), '1234.5');
    });

    test('preserves the Arabic comma used as a block separator', () {
      expect(ArabicText.normalizeForParsing('أ، ب'), 'أ، ب');
    });
  });

  group('toArabicIndic', () {
    test('converts Western digits and leaves other characters alone', () {
      expect(ArabicText.toArabicIndic('247.35 ميجا'), '٢٤٧.٣٥ ميجا');
    });
  });
}
