import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:baqati/utils/formatters.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('ar'));

  group('number', () {
    test('renders Arabic-Indic digits', () {
      expect(Formatters.number(301), '٣٠١');
      expect(Formatters.number(0), '٠');
    });

    test('drops a redundant .0 on whole doubles', () {
      // Allowances are stored as doubles but read as counts.
      expect(Formatters.number(4096.0), '٤٠٩٦');
    });

    test('uses the Arabic decimal separator', () {
      expect(Formatters.number(247.35), '٢٤٧٫٣٥');
    });

    test('falls back for a null value', () {
      expect(Formatters.number(null), '—');
      expect(Formatters.number(null, fallback: '٠'), '٠');
    });
  });

  group('riyal', () {
    test('appends the unit', () => expect(Formatters.riyal(2500), '٢٥٠٠ ريال'));

    test('falls back without inventing a zero', () {
      expect(Formatters.riyal(null, fallback: 'غير متوفر'), 'غير متوفر');
    });
  });

  group('dates', () {
    final DateTime moment = DateTime(2026, 6, 21, 15, 5);

    test('formats a short date', () {
      expect(Formatters.date(moment), '٢١/٠٦/٢٠٢٦');
    });

    test('formats a date and time together', () {
      expect(Formatters.dateTime(moment), startsWith('٢١/٠٦/٢٠٢٦ — '));
    });

    test('spells out a long date without Western digits', () {
      final String formatted = Formatters.longDateTime(moment);
      expect(formatted, contains('٢٠٢٦'));
      expect(RegExp(r'\d').hasMatch(formatted), isFalse);
    });
  });

  group('relativeTime', () {
    final DateTime now = DateTime(2026, 6, 21, 12);

    test('reports minutes, hours and days as they accumulate', () {
      expect(
        Formatters.relativeTime(
          now.subtract(const Duration(minutes: 5)),
          now: now,
        ),
        'قبل ٥ دقيقة',
      );
      expect(
        Formatters.relativeTime(
          now.subtract(const Duration(hours: 3)),
          now: now,
        ),
        'قبل ٣ ساعة',
      );
      expect(
        Formatters.relativeTime(
          now.subtract(const Duration(days: 4)),
          now: now,
        ),
        'قبل ٤ يوم',
      );
    });

    test('switches to an absolute date past a month', () {
      expect(
        Formatters.relativeTime(
          now.subtract(const Duration(days: 45)),
          now: now,
        ),
        contains('/'),
      );
    });

    test('handles a future timestamp without a negative count', () {
      expect(
        Formatters.relativeTime(now.add(const Duration(hours: 1)), now: now),
        'الآن',
      );
    });
  });

  group('countdown', () {
    test('splits into whole days, hours and minutes', () {
      final ({int days, int hours, int minutes}) parts = Formatters.countdown(
        const Duration(days: 5, hours: 3, minutes: 20),
      );

      expect(parts.days, 5);
      expect(parts.hours, 3);
      expect(parts.minutes, 20);
    });

    test('clamps an elapsed duration to zero rather than going negative', () {
      final ({int days, int hours, int minutes}) parts = Formatters.countdown(
        const Duration(hours: -5),
      );

      expect(parts, (days: 0, hours: 0, minutes: 0));
    });
  });

  group('remainingLabel', () {
    test('includes days when there are any', () {
      expect(
        Formatters.remainingLabel(const Duration(days: 2, hours: 4)),
        'تنتهي خلال ٢ يوم و ٤ ساعة',
      );
    });

    test('drops to hours under a day', () {
      expect(
        Formatters.remainingLabel(const Duration(hours: 6)),
        'تنتهي خلال ٦ ساعة',
      );
    });

    test('drops to minutes under an hour', () {
      expect(
        Formatters.remainingLabel(const Duration(minutes: 30)),
        'تنتهي خلال ٣٠ دقيقة',
      );
    });

    test('reports an elapsed package as expired', () {
      expect(Formatters.remainingLabel(Duration.zero), 'منتهية');
    });
  });
}
