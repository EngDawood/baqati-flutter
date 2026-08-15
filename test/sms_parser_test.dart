import 'package:flutter_test/flutter_test.dart';

import 'package:baqati/models/event_type.dart';
import 'package:baqati/models/package_event.dart';
import 'package:baqati/services/sms_parser.dart';

/// A fixed clock so every expectation is deterministic.
final DateTime _now = DateTime.utc(2026, 6, 16, 3, 0);

/// Yemen is UTC+3, so a carrier wall-clock time maps to this instant.
int _yemenTime(int year, int month, int day, [int hour = 0, int minute = 0]) =>
    DateTime.utc(
      year,
      month,
      day,
      hour,
      minute,
    ).subtract(const Duration(hours: 3)).millisecondsSinceEpoch;

PackageEvent _only(List<PackageEvent> events, EventType type) =>
    events.singleWhere((PackageEvent e) => e.type == type);

void main() {
  group('payment', () {
    test('captures the amount and the post-tax balance', () {
      final List<PackageEvent> events = SmsParser.parse(
        'عزيزي المشترك، دفعت 2500 ريال بتاريخ 03:01:00 16-06-2026 '
        'وأصبح رصيدك بعد ضريبة الحكومة 2148.9 ريال.',
        now: _now,
      );

      final PackageEvent payment = _only(events, EventType.payment);
      expect(payment.cost, 2500);
      expect(payment.title, 'دفعة / تعبئة رصيد');
      expect(payment.description, contains('2500'));
      expect(payment.description, contains('2148.9'));
    });

    test('dates the event from the message, not the parse time', () {
      final List<PackageEvent> events = SmsParser.parse(
        'دفعت 500 ريال بتاريخ 12:30:00 01-05-2026 رصيدك الحكومة 100',
        now: _now,
      );

      expect(
        _only(events, EventType.payment).timestamp,
        _yemenTime(2026, 5, 1, 12, 30),
      );
    });

    test('needs both anchors, not just one', () {
      expect(SmsParser.parse('دفعت 500 ريال', now: _now), isEmpty);
    });
  });

  group('deduction', () {
    test('captures the package name and the amount', () {
      final List<PackageEvent> events = SmsParser.parse(
        'تم خصم اشتراك باقة مزايا فورجي الشهرية.المبلغ هو 2066.25 ريال',
        now: _now,
      );

      final PackageEvent deduction = _only(events, EventType.deduction);
      expect(deduction.cost, 2066.25);
      expect(deduction.description, contains('مزايا فورجي الشهرية'));
    });

    test('falls back to مجهولة when no package name is present', () {
      final List<PackageEvent> events = SmsParser.parse(
        'تم خصم اشتراك. المبلغ هو 100 ريال',
        now: _now,
      );

      expect(
        _only(events, EventType.deduction).description,
        contains('مجهولة'),
      );
    });
  });

  group('activation', () {
    test('captures allowances and the explicit expiry date', () {
      final List<PackageEvent> events = SmsParser.parse(
        'حصلت على 300 دقيقة و 350 رسالة و 4096 ميجا لمدة 30 يوم '
        'تاريخ 00:00:00 21-06-2026',
        now: _now,
      );

      final PackageEvent activation = _only(events, EventType.activation);
      expect(activation.minutes, 300);
      expect(activation.sms, 350);
      expect(activation.megabytes, 4096);
      expect(activation.expiryTimestamp, _yemenTime(2026, 6, 21));
    });

    test('derives the expiry from the duration when no date is quoted', () {
      final List<PackageEvent> events = SmsParser.parse(
        'حصلت على 100 دقيقة لمدة 7 أيام',
        now: _now,
      );

      expect(
        _only(events, EventType.activation).expiryTimestamp,
        _now.add(const Duration(days: 7)).millisecondsSinceEpoch,
      );
    });

    test('reads the plural أيام, which the Kotlin regex missed entirely', () {
      // "أيام" does not contain "يوم" as a substring, so the singular-only
      // pattern yielded 0 days and an already-expired package.
      final List<PackageEvent> events = SmsParser.parse(
        'حصلت على 50 دقيقة لمدة 5 أيام',
        now: _now,
      );

      expect(
        _only(events, EventType.activation).expiryTimestamp,
        greaterThan(_now.millisecondsSinceEpoch),
      );
    });

    test('converts جيجا to megabytes instead of dropping it', () {
      final List<PackageEvent> events = SmsParser.parse(
        'حصلت على 5 جيجا لمدة 30 يوم',
        now: _now,
      );

      expect(_only(events, EventType.activation).megabytes, 5 * 1024);
    });
  });

  group('main balance', () {
    test('stores credit in balance, never in cost', () {
      final List<PackageEvent> events = SmsParser.parse(
        'رصيدك هو 1500.5 ريال ينتهي قبل 00:00:00 30-12-2026',
        now: _now,
      );

      final PackageEvent event = events.singleWhere(
        (PackageEvent e) => e.title == SmsParser.mainBalanceTitle,
      );
      expect(event.balance, 1500.5);
      expect(event.cost, isNull);
      expect(event.expiryTimestamp, _yemenTime(2026, 12, 30));
    });
  });

  group('package balance', () {
    test('parses the single-package form', () {
      final List<PackageEvent> events = SmsParser.parse(
        'لديك: 301 دقيقة و 136 رسالة و 247.35 ميجا '
        'تنتهي صلاحيتها قبل 00:00:00 21-06-2026',
        now: _now,
      );

      final PackageEvent event = events.single;
      expect(event.type, EventType.balanceCheck);
      expect(event.minutes, 301);
      expect(event.sms, 136);
      expect(event.megabytes, 247.35);
      expect(event.expiryTimestamp, _yemenTime(2026, 6, 21));
    });

    test('sums entries sharing an expiry and splits differing ones', () {
      final List<PackageEvent> events = SmsParser.parse(
        'لديك:\n'
        '100 دقيقة ينتهي قبل 00:00:00 21-06-2026\n'
        '50 دقيقة ينتهي قبل 00:00:00 21-06-2026\n'
        '20 دقيقة ينتهي قبل 00:00:00 30-06-2026',
        now: _now,
      );

      expect(events, hasLength(2));

      final PackageEvent june21 = events.singleWhere(
        (PackageEvent e) => e.expiryTimestamp == _yemenTime(2026, 6, 21),
      );
      expect(june21.minutes, 150);

      final PackageEvent june30 = events.singleWhere(
        (PackageEvent e) => e.expiryTimestamp == _yemenTime(2026, 6, 30),
      );
      expect(june30.minutes, 20);
    });

    test('does not cut a decimal allowance at its point', () {
      // The Kotlin split blocks on '.' too, so "1.5 ميجا" became "5 ميجا".
      final List<PackageEvent> events = SmsParser.parse(
        'لديك: 1.5 ميجا ينتهي قبل 00:00:00 21-06-2026',
        now: _now,
      );

      expect(events.single.megabytes, 1.5);
    });
  });

  group('normalization', () {
    test('reads Arabic-Indic digits', () {
      final List<PackageEvent> events = SmsParser.parse(
        'حصلت على ٣٠٠ دقيقة لمدة ٣٠ يوم',
        now: _now,
      );

      expect(_only(events, EventType.activation).minutes, 300);
    });

    test('survives invisible bidi marks between anchor and number', () {
      // U+200F RIGHT-TO-LEFT MARK is category Cf, so \s never matched it and
      // the anchored regex failed silently.
      final List<PackageEvent> events = SmsParser.parse(
        'حصلت على ‏300‏ دقيقة لمدة 30 يوم',
        now: _now,
      );

      expect(_only(events, EventType.activation).minutes, 300);
    });

    test('handles the Arabic thousands separator', () {
      final List<PackageEvent> events = SmsParser.parse(
        'حصلت على 4٬096 ميجا لمدة 30 يوم',
        now: _now,
      );

      expect(_only(events, EventType.activation).megabytes, 4096);
    });
  });

  test('one message can produce several independent events', () {
    final List<PackageEvent> events = SmsParser.parse(
      'تم خصم اشتراك باقة مزايا.المبلغ هو 2000 ريال. '
      'حصلت على 300 دقيقة و 350 رسالة و 4096 ميجا لمدة 30 يوم',
      now: _now,
    );

    expect(
      events.map((PackageEvent e) => e.type),
      containsAll(<EventType>[EventType.deduction, EventType.activation]),
    );
  });

  test('an unrelated message produces nothing', () {
    expect(SmsParser.parse('مرحباً بك في يمن موبايل', now: _now), isEmpty);
  });

  test('a malformed date falls back rather than throwing', () {
    final List<PackageEvent> events = SmsParser.parse(
      'رصيدك هو 100 ريال ينتهي قبل 99:99:99 45-45-2026',
      now: _now,
    );

    expect(events.single.expiryTimestamp, _now.millisecondsSinceEpoch);
  });
}
