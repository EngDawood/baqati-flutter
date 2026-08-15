import 'dart:async';
import 'dart:developer' as developer;

import 'package:baqati/data/package_repository.dart';
import 'package:baqati/models/package_event.dart';
import 'package:baqati/services/notification_service.dart';
import 'package:baqati/services/settings_service.dart';
import 'package:baqati/services/sms_parser.dart';
import 'package:baqati/services/sms_service.dart';

/// Turns carrier messages into stored events and scheduled reminders.
///
/// This is the only place that knows the whole path from a raw SMS to a row:
/// read → parse → stamp with a dedupe hash → insert → schedule. Screens ask for
/// a sync and get back a count; they never touch [SmsParser] themselves.
class SmsSyncService {
  SmsSyncService({
    required PackageRepository repository,
    required SmsService sms,
    required NotificationService notifications,
    required SettingsService settings,
  }) : _repository = repository,
       _sms = sms,
       _notifications = notifications,
       _settings = settings;

  final PackageRepository _repository;
  final SmsService _sms;
  final NotificationService _notifications;
  final SettingsService _settings;

  StreamSubscription<RawSmsMessage>? _subscription;

  /// Begins consuming messages that arrive while the app is running.
  ///
  /// Messages that arrive while the process is dead are not lost — they are
  /// picked up by [syncInbox] at the next launch, and the dedupe hash makes the
  /// overlap between the two paths harmless.
  void start() {
    _subscription ??= _sms.incoming.listen(
      (RawSmsMessage message) => _ingest(<RawSmsMessage>[message]),
      onError: (Object error) =>
          developer.log('SMS stream error: $error', name: 'SmsSyncService'),
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Re-reads the device inbox, returning how many genuinely new events landed.
  ///
  /// Safe to call as often as the user likes: re-importing the same message
  /// inserts nothing the second time.
  Future<int> syncInbox() async => _ingest(await _sms.readInbox());

  Future<int> _ingest(List<RawSmsMessage> messages) async {
    if (messages.isEmpty) return 0;

    final List<PackageEvent> parsed = <PackageEvent>[];

    for (final RawSmsMessage message in messages) {
      // The message's own date, not the sync time. Backfilling an inbox with
      // `DateTime.now()` would collapse months of history onto today, making
      // every relative timestamp read "قبل قليل" and every "latest event"
      // query a coin toss between rows that now share a timestamp.
      final DateTime sentAt = DateTime.fromMillisecondsSinceEpoch(
        message.dateMillis,
      );
      final List<PackageEvent> events = SmsParser.parse(
        message.body,
        now: sentAt,
      );

      for (int i = 0; i < events.length; i++) {
        parsed.add(
          events[i].copyWith(
            sourceHash: SmsService.sourceHashFor(
              body: message.body,
              dateMillis: message.dateMillis,
              eventIndex: i,
            ),
          ),
        );
      }
    }

    final List<PackageEvent> inserted = await _repository
        .insertAllReturningInserted(parsed);

    await _scheduleReminders(inserted);
    return inserted.length;
  }

  /// Schedules an expiry reminder for each newly stored package.
  ///
  /// PORT-FIX: nothing in the Kotlin ever scheduled an alarm from an SMS at
  /// all — `AlarmScheduler` was reachable only from the manual-entry form — so
  /// a user whose packages all came from carrier messages, which is the app's
  /// entire premise, never received a single reminder.
  Future<void> _scheduleReminders(List<PackageEvent> events) async {
    if (!_settings.shouldNotify) return;

    final int leadTimeHours = _settings.reminderLeadTimeHours;

    for (final PackageEvent event in events) {
      final int? expiry = event.expiryTimestamp;
      final int? id = event.id;
      if (expiry == null || id == null) continue;

      // The main-credit row carries an expiry but is not a package, and the
      // parser falls back to the message's own timestamp when the carrier
      // quotes no date — neither is worth waking the user for.
      if (event.title == SmsParser.mainBalanceTitle) continue;
      if (expiry <= event.timestamp) continue;

      final ReminderOutcome outcome = await _notifications
          .scheduleExpiryReminder(
            eventId: id,
            packageTitle: event.title,
            expiryMillis: expiry,
            leadTimeHours: leadTimeHours,
          );

      if (outcome == ReminderOutcome.permissionDenied) {
        // Every later call in this loop would fail the same way.
        developer.log(
          'Reminder scheduling stopped: notifications not permitted',
          name: 'SmsSyncService',
        );
        return;
      }
    }
  }
}
