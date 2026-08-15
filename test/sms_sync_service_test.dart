import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:baqati/data/package_repository.dart';
import 'package:baqati/models/package_event.dart';
import 'package:baqati/services/notification_service.dart';
import 'package:baqati/services/settings_service.dart';
import 'package:baqati/services/sms_service.dart';
import 'package:baqati/services/sms_sync_service.dart';

import 'support/fakes.dart';

/// An activation message with an explicit expiry well in the future.
RawSmsMessage _activation({
  required DateTime sentAt,
  String package = 'مزايا فورجي',
}) => RawSmsMessage(
  body:
      'باقة $package: حصلت على 300 دقيقة و 350 رسالة و 4096 ميجا '
      'لمدة 30 يوم تاريخ 00:00:00 21-12-2030',
  dateMillis: sentAt.millisecondsSinceEpoch,
);

void main() {
  late PackageRepository repository;
  late Database db;
  late FakeSmsService sms;
  late FakeNotificationService notifications;
  late SettingsService settings;

  Future<SmsSyncService> buildSync() async => SmsSyncService(
    repository: repository,
    sms: sms,
    notifications: notifications,
    settings: settings,
  );

  setUp(() async {
    (repository, db) = await openTestRepository();
    notifications = FakeNotificationService();
    settings = await testSettings();
  });

  tearDown(() async {
    await sms.close();
    await db.close();
  });

  group('syncInbox', () {
    test('parses and stores every event in the inbox', () async {
      sms = FakeSmsService(
        inbox: <RawSmsMessage>[_activation(sentAt: DateTime(2026, 6, 16))],
      );
      final SmsSyncService sync = await buildSync();

      expect(await sync.syncInbox(), 1);
      expect(await repository.getAllEvents(), hasLength(1));
    });

    test('a second sync of the same inbox inserts nothing', () async {
      sms = FakeSmsService(
        inbox: <RawSmsMessage>[_activation(sentAt: DateTime(2026, 6, 16))],
      );
      final SmsSyncService sync = await buildSync();

      expect(await sync.syncInbox(), 1);
      expect(await sync.syncInbox(), 0);
      expect(await repository.getAllEvents(), hasLength(1));
    });

    test('dates events from the message, not the sync time', () async {
      final DateTime sentAt = DateTime(2026, 5, 1, 9, 30);
      sms = FakeSmsService(inbox: <RawSmsMessage>[_activation(sentAt: sentAt)]);
      final SmsSyncService sync = await buildSync();

      await sync.syncInbox();

      // A backfill stamped with DateTime.now() would collapse months of
      // history onto today.
      expect(
        (await repository.getAllEvents()).single.timestamp,
        sentAt.millisecondsSinceEpoch,
      );
    });

    test('keeps several events parsed from one message distinct', () async {
      sms = FakeSmsService(
        inbox: <RawSmsMessage>[
          RawSmsMessage(
            body:
                'تم خصم اشتراك باقة مزايا.المبلغ هو 2000 ريال. '
                'حصلت على 300 دقيقة لمدة 30 يوم',
            dateMillis: DateTime(2026, 6, 16).millisecondsSinceEpoch,
          ),
        ],
      );
      final SmsSyncService sync = await buildSync();

      // Both events share a body and a date; only the per-event index in the
      // dedupe hash keeps the unique index from discarding the second.
      expect(await sync.syncInbox(), 2);
    });

    test('two distinct messages both land', () async {
      sms = FakeSmsService(
        inbox: <RawSmsMessage>[
          _activation(sentAt: DateTime(2026, 6, 16), package: 'أولى'),
          _activation(sentAt: DateTime(2026, 6, 17), package: 'ثانية'),
        ],
      );
      final SmsSyncService sync = await buildSync();

      expect(await sync.syncInbox(), 2);
    });

    test('an empty inbox is a no-op', () async {
      sms = FakeSmsService();
      expect(await (await buildSync()).syncInbox(), 0);
    });
  });

  group('reminders', () {
    test('schedules one per newly stored package', () async {
      sms = FakeSmsService(
        inbox: <RawSmsMessage>[_activation(sentAt: DateTime(2026, 6, 16))],
      );
      final SmsSyncService sync = await buildSync();

      await sync.syncInbox();

      expect(notifications.scheduled, hasLength(1));
      expect(notifications.scheduled.single.leadTimeHours, 24);
      expect(notifications.scheduled.single.eventId, isPositive);
    });

    test('keys the reminder on the row id, not the title', () async {
      // Two same-titled packages must not cancel each other's reminder.
      sms = FakeSmsService(
        inbox: <RawSmsMessage>[
          _activation(sentAt: DateTime(2026, 6, 16)),
          _activation(sentAt: DateTime(2026, 6, 17)),
        ],
      );
      final SmsSyncService sync = await buildSync();

      await sync.syncInbox();

      final Set<int> ids = notifications.scheduled
          .map((ScheduledReminder r) => r.eventId)
          .toSet();
      expect(ids, hasLength(2));
    });

    test('re-syncing does not re-schedule an already stored package', () async {
      sms = FakeSmsService(
        inbox: <RawSmsMessage>[_activation(sentAt: DateTime(2026, 6, 16))],
      );
      final SmsSyncService sync = await buildSync();

      await sync.syncInbox();
      await sync.syncInbox();

      expect(notifications.scheduled, hasLength(1));
    });

    test('skips the main-credit row, which is not a package', () async {
      sms = FakeSmsService(
        inbox: <RawSmsMessage>[
          RawSmsMessage(
            body: 'رصيدك هو 1500 ريال ينتهي قبل 00:00:00 21-12-2030',
            dateMillis: DateTime(2026, 6, 16).millisecondsSinceEpoch,
          ),
        ],
      );
      final SmsSyncService sync = await buildSync();

      expect(await sync.syncInbox(), 1);
      expect(notifications.scheduled, isEmpty);
    });

    test(
      'skips an event whose expiry is not after its own timestamp',
      () async {
        // The parser falls back to the message's timestamp when the carrier
        // quotes no date — there is nothing to remind about.
        sms = FakeSmsService(
          inbox: <RawSmsMessage>[
            RawSmsMessage(
              body: 'لديك: 100 دقيقة تنتهي صلاحيتها قبل غير مفهوم',
              dateMillis: DateTime(2026, 6, 16).millisecondsSinceEpoch,
            ),
          ],
        );
        final SmsSyncService sync = await buildSync();

        await sync.syncInbox();
        expect(notifications.scheduled, isEmpty);
      },
    );

    test('schedules nothing when reminders are switched off', () async {
      settings = await testSettings(<String, Object>{
        'reminders_enabled': false,
      });
      sms = FakeSmsService(
        inbox: <RawSmsMessage>[_activation(sentAt: DateTime(2026, 6, 16))],
      );
      final SmsSyncService sync = await buildSync();

      // The event is still stored — only the notification is suppressed.
      expect(await sync.syncInbox(), 1);
      expect(notifications.scheduled, isEmpty);
    });

    test('schedules nothing when the user wants in-app alerts only', () async {
      settings = await testSettings(<String, Object>{'alert_type': 'IN_APP'});
      sms = FakeSmsService(
        inbox: <RawSmsMessage>[_activation(sentAt: DateTime(2026, 6, 16))],
      );

      expect(await (await buildSync()).syncInbox(), 1);
      expect(notifications.scheduled, isEmpty);
    });

    test('uses the configured lead time', () async {
      settings = await testSettings(<String, Object>{
        'reminder_lead_time_hours': 48,
      });
      sms = FakeSmsService(
        inbox: <RawSmsMessage>[_activation(sentAt: DateTime(2026, 6, 16))],
      );

      await (await buildSync()).syncInbox();
      expect(notifications.scheduled.single.leadTimeHours, 48);
    });

    test('stops scheduling once permission is refused', () async {
      notifications = FakeNotificationService(
        outcome: ReminderOutcome.permissionDenied,
      );
      sms = FakeSmsService(
        inbox: <RawSmsMessage>[
          _activation(sentAt: DateTime(2026, 6, 16), package: 'أولى'),
          _activation(sentAt: DateTime(2026, 6, 17), package: 'ثانية'),
        ],
      );
      final SmsSyncService sync = await buildSync();

      expect(await sync.syncInbox(), 2);
      // Every later call would fail identically, so it gives up after one.
      expect(notifications.scheduled, hasLength(1));
    });
  });

  group('live stream', () {
    test('stores a message that arrives while the app runs', () async {
      sms = FakeSmsService();
      final SmsSyncService sync = await buildSync();
      sync.start();

      sms.emit(_activation(sentAt: DateTime(2026, 6, 16)));
      await Future<void>.delayed(Duration.zero);

      expect(await repository.getAllEvents(), hasLength(1));
      await sync.dispose();
    });

    test(
      'a streamed message is not re-inserted by a later inbox sync',
      () async {
        final RawSmsMessage message = _activation(
          sentAt: DateTime(2026, 6, 16),
        );
        sms = FakeSmsService(inbox: <RawSmsMessage>[message]);
        final SmsSyncService sync = await buildSync();
        sync.start();

        sms.emit(message);
        await Future<void>.delayed(Duration.zero);

        // The live path and the backfill path overlap by design; the dedupe hash
        // is what makes that overlap harmless.
        expect(await sync.syncInbox(), 0);
        expect(await repository.getAllEvents(), hasLength(1));
        await sync.dispose();
      },
    );

    test('start is idempotent', () async {
      sms = FakeSmsService();
      final SmsSyncService sync = await buildSync();
      sync.start();
      sync.start();

      sms.emit(_activation(sentAt: DateTime(2026, 6, 16)));
      await Future<void>.delayed(Duration.zero);

      final List<PackageEvent> events = await repository.getAllEvents();
      expect(events, hasLength(1));
      await sync.dispose();
    });
  });
}
