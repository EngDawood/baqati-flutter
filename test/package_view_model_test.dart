import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:baqati/data/package_repository.dart';
import 'package:baqati/models/event_type.dart';
import 'package:baqati/models/package_event.dart';
import 'package:baqati/services/notification_service.dart';
import 'package:baqati/services/settings_service.dart';
import 'package:baqati/services/sms_parser.dart';
import 'package:baqati/services/sms_service.dart';
import 'package:baqati/services/sms_sync_service.dart';
import 'package:baqati/viewmodels/package_view_model.dart';

import 'support/fakes.dart';

/// Anchored to the real clock, because the getters under test compare against
/// [DateTime.now] — a hardcoded date would silently drift into the past and
/// make every "active" package expired.
DateTime get _now => DateTime.now();

int _daysFromNow(int days) =>
    _now.add(Duration(days: days)).millisecondsSinceEpoch;

int _daysAgo(int days) =>
    _now.subtract(Duration(days: days)).millisecondsSinceEpoch;

PackageEvent _package({
  required String title,
  required int expiry,
  int timestamp = 1000,
  EventType type = EventType.activation,
  int? minutes,
  double? balance,
  String? sourceHash,
}) => PackageEvent(
  type: type,
  timestamp: timestamp,
  title: title,
  description: 'وصف',
  minutes: minutes,
  balance: balance,
  expiryTimestamp: expiry,
  sourceHash: sourceHash,
);

void main() {
  late PackageRepository repository;
  late Database db;
  late FakeSmsService sms;
  late FakeNotificationService notifications;
  late SettingsService settings;
  late PackageViewModel vm;

  Future<void> build() async {
    vm = PackageViewModel(
      repository: repository,
      sms: sms,
      sync: SmsSyncService(
        repository: repository,
        sms: sms,
        notifications: notifications,
        settings: settings,
      ),
      notifications: notifications,
      settings: settings,
    );
    await vm.initialize();
  }

  setUp(() async {
    (repository, db) = await openTestRepository();
    sms = FakeSmsService();
    notifications = FakeNotificationService();
    settings = await testSettings();
  });

  tearDown(() async {
    vm.dispose();
    await sms.close();
    await db.close();
  });

  group('active packages', () {
    test('excludes expired ones and sorts by soonest expiry', () async {
      await repository.insertAll(<PackageEvent>[
        _package(title: 'منتهية', expiry: _daysAgo(1), sourceHash: 'a#0'),
        _package(title: 'لاحقة', expiry: _daysFromNow(20), sourceHash: 'b#0'),
        _package(title: 'أقرب', expiry: _daysFromNow(3), sourceHash: 'c#0'),
      ]);
      await build();

      expect(vm.activePackages.map((PackageEvent e) => e.title), <String>[
        'أقرب',
        'لاحقة',
      ]);
      expect(vm.mainPackage?.title, 'أقرب');
      expect(vm.secondaryPackages.map((PackageEvent e) => e.title), <String>[
        'لاحقة',
      ]);
    });

    test('collapses repeated readings of one package to the newest', () async {
      // Balance checks of the same package share an expiry; showing each as a
      // separate live package would triple-count it.
      await repository.insertAll(<PackageEvent>[
        _package(
          title: 'قديم',
          expiry: _daysFromNow(5),
          timestamp: 1000,
          minutes: 300,
          sourceHash: 'a#0',
        ),
        _package(
          title: 'جديد',
          expiry: _daysFromNow(5),
          timestamp: 5000,
          minutes: 120,
          sourceHash: 'b#0',
        ),
      ]);
      await build();

      expect(vm.activePackages, hasLength(1));
      expect(vm.activePackages.single.minutes, 120);
    });

    test('excludes the main-credit row', () async {
      await repository.insertAll(<PackageEvent>[
        _package(
          title: SmsParser.mainBalanceTitle,
          expiry: _daysFromNow(30),
          type: EventType.balanceCheck,
          balance: 1500,
          sourceHash: 'a#0',
        ),
        _package(title: 'باقة', expiry: _daysFromNow(5), sourceHash: 'b#0'),
      ]);
      await build();

      expect(vm.activePackages, hasLength(1));
      expect(vm.activePackages.single.title, 'باقة');
      expect(vm.mainBalance, 1500);
    });

    test(
      'falls back to the newest expired package when none are live',
      () async {
        await repository.insert(
          _package(title: 'منتهية', expiry: _daysAgo(2), sourceHash: 'a#0'),
        );
        await build();

        expect(vm.activePackages, isEmpty);
        // An empty dashboard would look broken; showing the lapsed package and
        // marking it expired is more useful.
        expect(vm.mainPackage?.title, 'منتهية');
        expect(vm.isExpired, isTrue);
        expect(vm.timeRemaining, Duration.zero);
      },
    );

    test('reports nothing at all on an empty database', () async {
      await build();

      expect(vm.events, isEmpty);
      expect(vm.mainPackage, isNull);
      expect(vm.timeRemaining, isNull);
      expect(vm.isExpired, isFalse);
      expect(vm.isLoading, isFalse);
    });
  });

  group('latest by type', () {
    test('separates activations from balance checks', () async {
      await repository.insertAll(<PackageEvent>[
        _package(
          title: 'تفعيل',
          expiry: _daysFromNow(30),
          timestamp: 1000,
          sourceHash: 'a#0',
        ),
        _package(
          title: 'فحص',
          expiry: _daysFromNow(30),
          timestamp: 2000,
          type: EventType.balanceCheck,
          sourceHash: 'b#0',
        ),
      ]);
      await build();

      expect(vm.latestActivation?.title, 'تفعيل');
      expect(vm.latestBalanceCheck?.title, 'فحص');
    });

    test('a manual entry does not mask the real latest activation', () async {
      await repository.insertAll(<PackageEvent>[
        _package(
          title: 'تفعيل حقيقي',
          expiry: _daysFromNow(30),
          timestamp: 1000,
          sourceHash: 'a#0',
        ),
      ]);
      await build();

      await vm.addManualAlert(
        title: 'يدوي',
        expiry: _now.add(const Duration(days: 10)),
        leadTimeHours: 24,
        isMonthly: true,
      );

      // The Kotlin stored manual entries as ACTIVATION, so this assertion
      // would have returned 'يدوي' and the details screen would have read its
      // totals off a hand-typed row.
      expect(vm.latestActivation?.title, 'تفعيل حقيقي');
    });
  });

  group('filtering', () {
    test('returns everything for a null type', () async {
      await repository.insertAll(<PackageEvent>[
        _package(title: 'أ', expiry: _daysFromNow(5), sourceHash: 'a#0'),
        _package(
          title: 'ب',
          expiry: _daysFromNow(5),
          type: EventType.payment,
          sourceHash: 'b#0',
        ),
      ]);
      await build();

      expect(vm.eventsOfType(null), hasLength(2));
      expect(vm.eventsOfType(EventType.payment), hasLength(1));
      expect(vm.eventsOfType(EventType.deduction), isEmpty);
    });
  });

  group('addManualAlert', () {
    test('stores as EventType.manual and schedules a reminder', () async {
      await build();

      final ReminderOutcome outcome = await vm.addManualAlert(
        title: 'باقتي اليدوية',
        expiry: _now.add(const Duration(days: 10)),
        leadTimeHours: 12,
        isMonthly: false,
        minutes: 100,
      );

      expect(outcome, ReminderOutcome.scheduled);
      expect(vm.events.single.type, EventType.manual);
      expect(vm.events.single.description, 'باقة مخصصة');
      expect(notifications.scheduled.single.leadTimeHours, 12);
    });

    test('stores the event but skips the reminder when they are off', () async {
      settings = await testSettings(<String, Object>{
        'reminders_enabled': false,
      });
      await build();

      final ReminderOutcome outcome = await vm.addManualAlert(
        title: 'باقة',
        expiry: _now.add(const Duration(days: 10)),
        leadTimeHours: 24,
        isMonthly: true,
      );

      expect(outcome, ReminderOutcome.remindersDisabled);
      expect(vm.events, hasLength(1));
      expect(notifications.scheduled, isEmpty);
    });

    test('does not write the form lead time into global settings', () async {
      await build();

      await vm.addManualAlert(
        title: 'باقة',
        expiry: _now.add(const Duration(days: 10)),
        leadTimeHours: 6,
        isMonthly: true,
      );

      // The Kotlin reconfigured every future reminder as a side effect of
      // saving one package.
      expect(settings.reminderLeadTimeHours, 24);
    });
  });

  group('deleteEvent', () {
    test('cancels the reminder alongside the row', () async {
      await build();
      await vm.addManualAlert(
        title: 'باقة',
        expiry: _now.add(const Duration(days: 10)),
        leadTimeHours: 24,
        isMonthly: true,
      );

      final int id = vm.events.single.id!;
      await vm.deleteEvent(id);

      expect(vm.events, isEmpty);
      expect(notifications.cancelled, <int>[id]);
    });
  });

  group('sync', () {
    test('requests permission first when it is missing', () async {
      sms = FakeSmsService(permissionGranted: false);
      await build();

      final SyncResult result = await vm.sync();

      expect(result.permissionDenied, isTrue);
      expect(result.newEventCount, 0);
      expect(sms.permissionRequestCount, 1);
      expect(sms.readInboxCount, 0);
    });

    test('reads the inbox and reports the new event count', () async {
      sms = FakeSmsService(
        inbox: <RawSmsMessage>[
          RawSmsMessage(
            body: 'حصلت على 300 دقيقة لمدة 30 يوم تاريخ 00:00:00 21-12-2030',
            dateMillis: _now.millisecondsSinceEpoch,
          ),
        ],
      );
      await build();

      expect((await vm.sync()).newEventCount, 1);
      expect(vm.events, hasLength(1));
    });

    test('notifies listeners while syncing and again when done', () async {
      sms = FakeSmsService();
      await build();

      int notifications = 0;
      vm.addListener(() => notifications++);

      await vm.sync();

      expect(notifications, greaterThanOrEqualTo(2));
      expect(vm.isSyncing, isFalse);
    });
  });

  test('re-queries when the repository changes underneath it', () async {
    await build();
    expect(vm.events, isEmpty);

    // A write that bypasses the view model — an SMS landing while the user is
    // on another screen takes exactly this path.
    await repository.insert(
      _package(title: 'جديد', expiry: _daysFromNow(5), sourceHash: 'a#0'),
    );
    await vm.refreshed;

    expect(vm.events, hasLength(1));
  });
}
