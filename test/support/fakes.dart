import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:baqati/data/app_database.dart';
import 'package:baqati/data/package_event_dao.dart';
import 'package:baqati/data/package_repository.dart';
import 'package:baqati/services/notification_service.dart';
import 'package:baqati/services/settings_service.dart';
import 'package:baqati/services/sms_service.dart';

/// One scheduling request the code under test made.
class ScheduledReminder {
  const ScheduledReminder({
    required this.eventId,
    required this.packageTitle,
    required this.expiryMillis,
    required this.leadTimeHours,
  });

  final int eventId;
  final String packageTitle;
  final int expiryMillis;
  final int leadTimeHours;
}

/// Records scheduling calls instead of reaching the platform.
///
/// Extends rather than implements so the real constructor still runs — it only
/// allocates a plugin object, making no platform call — and every method that
/// would touch the platform is overridden below.
class FakeNotificationService extends NotificationService {
  FakeNotificationService({this.outcome = ReminderOutcome.scheduled});

  final List<ScheduledReminder> scheduled = <ScheduledReminder>[];
  final List<int> cancelled = <int>[];
  int cancelAllCount = 0;
  ReminderOutcome outcome;

  @override
  Future<ReminderOutcome> scheduleExpiryReminder({
    required int eventId,
    required String packageTitle,
    required int expiryMillis,
    required int leadTimeHours,
  }) async {
    scheduled.add(
      ScheduledReminder(
        eventId: eventId,
        packageTitle: packageTitle,
        expiryMillis: expiryMillis,
        leadTimeHours: leadTimeHours,
      ),
    );
    return outcome;
  }

  @override
  Future<ReminderOutcome> showNow({
    required int id,
    required String title,
    required String body,
  }) async => ReminderOutcome.firedImmediately;

  @override
  Future<void> cancelReminder(int eventId) async => cancelled.add(eventId);

  @override
  Future<void> cancelAll() async => cancelAllCount++;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<bool> areNotificationsEnabled() async => true;

  @override
  Future<bool> canScheduleExactAlarms() async => true;
}

/// Serves a scripted inbox and a controllable live stream.
class FakeSmsService extends SmsService {
  FakeSmsService({
    List<RawSmsMessage> inbox = const <RawSmsMessage>[],
    this.permissionGranted = true,
  }) : inbox = List<RawSmsMessage>.of(inbox);

  final List<RawSmsMessage> inbox;
  bool permissionGranted;
  int readInboxCount = 0;
  int permissionRequestCount = 0;

  final StreamController<RawSmsMessage> _controller =
      StreamController<RawSmsMessage>.broadcast();

  void emit(RawSmsMessage message) => _controller.add(message);

  Future<void> close() => _controller.close();

  @override
  Stream<RawSmsMessage> get incoming => _controller.stream;

  @override
  Future<List<RawSmsMessage>> readInbox() async {
    readInboxCount++;
    return inbox;
  }

  @override
  Future<bool> hasSmsPermission() async => permissionGranted;

  @override
  Future<bool> requestSmsPermission() async {
    permissionRequestCount++;
    return permissionGranted;
  }
}

/// Opens an in-memory repository backed by the real schema.
Future<(PackageRepository, Database)> openTestRepository() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final Database db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 1, onCreate: AppDatabase.onCreate),
  );

  return (PackageRepository(PackageEventDao(AppDatabase(database: db))), db);
}

/// A [SettingsService] over in-memory preferences.
Future<SettingsService> testSettings([
  Map<String, Object> values = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SettingsService.load();
}
