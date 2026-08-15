import 'package:baqati/models/event_type.dart';
import 'package:baqati/models/package_event.dart';
import 'package:baqati/utils/arabic_text.dart';

/// Parses Yemen Mobile carrier messages (sender 111) into [PackageEvent]s.
///
/// Ported from the Kotlin `SmsParser`. Each rule below is an independent check,
/// not a chain of alternatives — one message can legitimately produce several
/// events, and the Kotlin's behavior of accumulating them is preserved.
abstract final class SmsParser {
  /// Title given to the main-credit balance row.
  ///
  /// Exposed because the dashboard has to exclude this row when picking which
  /// package to feature: it is an account-wide credit figure, not a package
  /// with allowances to count down. The Kotlin compared against the same
  /// literal spelled out inline at two call sites (`HomeScreen.kt:68,74`), so a
  /// change here silently broke the filter there.
  static const String mainBalanceTitle = 'الرصيد الأساسي';

  /// Yemen is permanently UTC+03:00 and has never observed daylight saving.
  ///
  /// PORT-FIX: the Kotlin parsed carrier date strings with a `SimpleDateFormat`
  /// carrying no timezone, so they were interpreted in whatever zone the handset
  /// was set to. A traveling user or a misconfigured emulator therefore got
  /// expiry timestamps — and so reminder alarms — shifted by the offset
  /// difference. Because the offset is fixed, applying it arithmetically is
  /// both correct and free of any timezone-database initialization order.
  static const Duration _yemenOffset = Duration(hours: 3);

  /// Filler words the carrier may place between an anchor and its number.
  ///
  /// PORT-FIX (defensive): the Kotlin required the number to follow its anchor
  /// with nothing but whitespace, so a phrase like "دفعت مبلغ 500" silently
  /// yielded zero. We have no captured real messages to confirm the exact
  /// wording, so this widening is kept deliberately narrow — a wrong capture
  /// would be worse than no capture.
  static const String _filler = r'(?:\s*(?:مبلغ|قدره|وقدره|هو))*\s*';

  static final RegExp _paymentAmount = RegExp(
    'دفعت$_filler'
    r'([\d.]+)',
  );
  static final RegExp _paymentDate = RegExp(r'بتاريخ\s*([\d:]+\s+[\d-]+)');

  /// Anchored on "الحكومة" exactly as the Kotlin had it, even though the
  /// description it feeds calls the value "الرصيد بعد الضريبة".
  ///
  /// This may be a genuine fragment of the carrier's wording ("شامل ضريبة
  /// الحكومة") or a mis-keyed anchor that never matches. Without a real payment
  /// message we cannot tell, so the original behavior is preserved rather than
  /// guessed at. If real messages show it never matches, this is the first
  /// thing to revisit.
  static final RegExp _paymentBalance = RegExp(
    'الحكومة$_filler'
    r'([\d.]+)',
  );

  static final RegExp _deductionPackageDotAll = RegExp(
    r'باقة\s+(.*?)\.المبلغ',
    dotAll: true,
  );
  static final RegExp _deductionPackage = RegExp(r'باقة\s+(.*?)\.');
  static final RegExp _deductionAmount = RegExp(
    'المبلغ هو$_filler'
    r'([\d.]+)',
  );

  // PORT-FIX: the Kotlin matched only the singular nouns. Arabic requires the
  // plural for counts of 3-10, and "أيام" does not contain "يوم" as a
  // substring — the second letter differs — so "لمدة 7 أيام" matched nothing,
  // `days` fell back to 0, and the package was recorded as expiring instantly.
  static final RegExp _minutes = RegExp(r'([\d.]+)\s*(?:دقيقة|دقائق)');
  static final RegExp _messages = RegExp(r'([\d.]+)\s*(?:رسالة|رسائل)');
  static final RegExp _days = RegExp(
    r'لمدة\s*([\d.]+)\s*(?:يوماً|يوما|يوم|أيام)',
  );

  /// PORT-FIX: the Kotlin recognized only "ميجا", so any package the carrier
  /// quoted in "جيجا" lost its entire data allowance to 0.0 — not mis-scaled,
  /// silently dropped. The unit is captured so gigabytes can be converted.
  static final RegExp _data = RegExp(r'([\d.]+)\s*(ميجا|جيجا)');

  static const int _megabytesPerGigabyte = 1024;

  static final RegExp _activationExpiry = RegExp(r'تاريخ\s*([\d:]+\s+[\d-]+)');
  static final RegExp _mainBalance = RegExp(
    'رصيدك هو$_filler'
    r'([\d.]+)',
  );
  static final RegExp _mainBalanceExpiry = RegExp(r'قبل\s*([\d:]+\s+[\d-]+)');
  static final RegExp _validityExpiry = RegExp(
    r'تنتهي صلاحيتها قبل\s*([\d:]+\s+[\d-]+)',
  );
  static final RegExp _blockExpiry = RegExp(r'ينتهي قبل\s*([\d:]+\s+[\d-]+)');

  /// `HH:mm:ss dd-MM-yyyy`, the only date shape the carrier uses.
  static final RegExp _dateShape = RegExp(
    r'^(\d{1,2}):(\d{2}):(\d{2})\s+(\d{1,2})-(\d{1,2})-(\d{4})$',
  );

  /// Parses [body] into zero or more events.
  ///
  /// [now] is injectable so callers and tests get deterministic output.
  static List<PackageEvent> parse(String body, {DateTime? now}) {
    final String text = ArabicText.normalizeForParsing(body);
    final int nowMillis = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final List<PackageEvent> events = <PackageEvent>[];

    _parsePayment(text, nowMillis, events);
    _parseDeduction(text, nowMillis, events);
    _parseActivation(text, nowMillis, events);
    _parseMainBalance(text, nowMillis, events);
    _parsePackageBalance(text, nowMillis, events);

    return events;
  }

  static void _parsePayment(
    String text,
    int nowMillis,
    List<PackageEvent> events,
  ) {
    if (!text.contains('دفعت') || !text.contains('رصيدك')) return;

    final double amount = _extractDouble(_paymentAmount, text) ?? 0;
    final double newBalance = _extractDouble(_paymentBalance, text) ?? 0;
    final String? dateStr = _extractString(_paymentDate, text);

    events.add(
      PackageEvent(
        type: EventType.payment,
        timestamp: dateStr == null ? nowMillis : _parseDate(dateStr, nowMillis),
        title: 'دفعة / تعبئة رصيد',
        description:
            'دفع ${_number(amount)} ريال · '
            'الرصيد بعد الضريبة ${_number(newBalance)} ريال',
        cost: amount,
      ),
    );
  }

  static void _parseDeduction(
    String text,
    int nowMillis,
    List<PackageEvent> events,
  ) {
    if (!text.contains('تم خصم') || !text.contains('المبلغ')) return;

    final String packageName =
        _extractString(_deductionPackageDotAll, text)?.trim() ??
        _extractString(_deductionPackage, text)?.trim() ??
        'مجهولة';
    final double amount = _extractDouble(_deductionAmount, text) ?? 0;

    events.add(
      PackageEvent(
        type: EventType.deduction,
        timestamp: nowMillis,
        title: 'خصم اشتراك',
        description: 'باقة $packageName · ${_number(amount)} ريال',
        cost: amount,
      ),
    );
  }

  static void _parseActivation(
    String text,
    int nowMillis,
    List<PackageEvent> events,
  ) {
    if (!text.contains('حصلت على') && !text.contains('تستخدم لمدة')) return;

    final int minutes = _extractDouble(_minutes, text)?.toInt() ?? 0;
    final int messages = _extractDouble(_messages, text)?.toInt() ?? 0;
    final double megabytes = _extractMegabytes(text);
    final int days = _extractDouble(_days, text)?.toInt() ?? 0;
    final String? expiryStr = _extractString(_activationExpiry, text);

    final int expiry = expiryStr != null
        ? _parseDate(expiryStr, nowMillis)
        : nowMillis + Duration(days: days).inMilliseconds;

    events.add(
      PackageEvent(
        type: EventType.activation,
        timestamp: nowMillis,
        minutes: minutes,
        sms: messages,
        megabytes: megabytes,
        expiryTimestamp: expiry,
        title: 'تفعيل باقة جديدة',
        description:
            '$minutes دقيقة · $messages رسالة · '
            '${_number(megabytes)} ميجا · لمدة $days يوم',
      ),
    );
  }

  static void _parseMainBalance(
    String text,
    int nowMillis,
    List<PackageEvent> events,
  ) {
    if (!text.contains('رصيدك هو') || !text.contains('ينتهي قبل')) return;

    final double balance = _extractDouble(_mainBalance, text) ?? 0;
    final String? expiryStr = _extractString(_mainBalanceExpiry, text);

    events.add(
      PackageEvent(
        type: EventType.balanceCheck,
        timestamp: nowMillis,
        title: mainBalanceTitle,
        description: '${_number(balance)} ريال',
        // PORT-FIX: the Kotlin put remaining credit in `cost`, a field meaning
        // "money spent". Any future total-spent aggregate would have silently
        // counted the user's balance as an expense.
        balance: balance,
        expiryTimestamp: expiryStr == null
            ? nowMillis
            : _parseDate(expiryStr, nowMillis),
      ),
    );
  }

  static void _parsePackageBalance(
    String text,
    int nowMillis,
    List<PackageEvent> events,
  ) {
    final bool matches =
        (text.contains('ينتهي قبل') && text.contains('ميجا')) ||
        text.contains('لديك:') ||
        text.contains('تنتهي صلاحيتها');
    if (!matches) return;

    if (text.contains('تنتهي صلاحيتها قبل')) {
      _parseSinglePackageBalance(text, nowMillis, events);
    } else {
      _parseGroupedPackageBalance(text, nowMillis, events);
    }
  }

  static void _parseSinglePackageBalance(
    String text,
    int nowMillis,
    List<PackageEvent> events,
  ) {
    final int minutes = _extractDouble(_minutes, text)?.toInt() ?? 0;
    final int messages = _extractDouble(_messages, text)?.toInt() ?? 0;
    final double megabytes = _extractMegabytes(text);
    if (minutes <= 0 && messages <= 0 && megabytes <= 0) return;

    final String? expiryStr = _extractString(_validityExpiry, text);

    events.add(
      PackageEvent(
        type: EventType.balanceCheck,
        timestamp: nowMillis,
        minutes: minutes,
        sms: messages,
        megabytes: megabytes,
        expiryTimestamp: expiryStr == null
            ? nowMillis
            : _parseDate(expiryStr, nowMillis),
        title: 'فحص الرصيد',
        description:
            '$minutes دقيقة · $messages رسالة · ${_number(megabytes)} ميجا',
      ),
    );
  }

  /// Sums allowances across entries that share an expiry, one event per date.
  static void _parseGroupedPackageBalance(
    String text,
    int nowMillis,
    List<PackageEvent> events,
  ) {
    // PORT-FIX: the Kotlin split on '.' as well as newline and the Arabic
    // comma. Numbers are matched with `[\d.]+`, so "1.5 ميجا" was cut at the
    // decimal point and the block regex then captured "5" — a 1.5 MB allowance
    // recorded as 5 MB.
    final List<String> blocks = text
        .split(RegExp(r'[\n،]'))
        .map((String block) => block.trim())
        .where((String block) => block.isNotEmpty)
        .toList();

    final Map<String, ({int minutes, int sms, double megabytes})> byDate =
        <String, ({int minutes, int sms, double megabytes})>{};

    for (final String block in blocks) {
      final String? dateStr = _extractString(_blockExpiry, block);
      if (dateStr == null) continue;

      final ({int minutes, int sms, double megabytes})? existing =
          byDate[dateStr];
      byDate[dateStr] = (
        minutes:
            (existing?.minutes ?? 0) +
            (_extractDouble(_minutes, block)?.toInt() ?? 0),
        sms:
            (existing?.sms ?? 0) +
            (_extractDouble(_messages, block)?.toInt() ?? 0),
        megabytes: (existing?.megabytes ?? 0) + _extractMegabytes(block),
      );
    }

    byDate.forEach((
      String dateStr,
      ({int minutes, int sms, double megabytes}) totals,
    ) {
      events.add(
        PackageEvent(
          type: EventType.balanceCheck,
          timestamp: nowMillis,
          minutes: totals.minutes,
          sms: totals.sms,
          megabytes: totals.megabytes,
          expiryTimestamp: _parseDate(dateStr, nowMillis),
          title: 'فحص الرصيد',
          description:
              '${totals.minutes} دقيقة · ${totals.sms} رسالة · '
              '${_number(totals.megabytes)} ميجا',
        ),
      );
    });
  }

  /// Reads a data allowance, converting gigabytes to megabytes.
  static double _extractMegabytes(String text) {
    final RegExpMatch? match = _data.firstMatch(text);
    if (match == null) return 0;

    final double? value = double.tryParse(match.group(1) ?? '');
    if (value == null) return 0;

    return match.group(2) == 'جيجا' ? value * _megabytesPerGigabyte : value;
  }

  static double? _extractDouble(RegExp pattern, String text) =>
      double.tryParse(pattern.firstMatch(text)?.group(1) ?? '');

  static String? _extractString(RegExp pattern, String text) =>
      pattern.firstMatch(text)?.group(1);

  /// Converts a carrier date string to epoch milliseconds.
  ///
  /// Falls back to [fallbackMillis] on any malformed input, matching the
  /// Kotlin's behavior of never throwing out of a parse.
  static int _parseDate(String dateStr, int fallbackMillis) {
    final RegExpMatch? match = _dateShape.firstMatch(dateStr.trim());
    if (match == null) return fallbackMillis;

    final int? hour = int.tryParse(match.group(1)!);
    final int? minute = int.tryParse(match.group(2)!);
    final int? second = int.tryParse(match.group(3)!);
    final int? day = int.tryParse(match.group(4)!);
    final int? month = int.tryParse(match.group(5)!);
    final int? year = int.tryParse(match.group(6)!);

    if (hour == null ||
        minute == null ||
        second == null ||
        day == null ||
        month == null ||
        year == null) {
      return fallbackMillis;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31 || hour > 23) {
      return fallbackMillis;
    }

    // Read the wall-clock time as Yemen local, then shift to UTC.
    return DateTime.utc(
      year,
      month,
      day,
      hour,
      minute,
      second,
    ).subtract(_yemenOffset).millisecondsSinceEpoch;
  }

  /// Formats a number for display text stored in the database.
  ///
  /// PORT-FIX (cosmetic): Kotlin string interpolation of a `Double` always
  /// renders a decimal point, so descriptions read "دفع 2500.0 ريال". Whole
  /// numbers are shown without the trailing ".0" here.
  static String _number(double value) =>
      value == value.roundToDouble() && value.abs() < 1e15
      ? value.toInt().toString()
      : value.toString();
}
