import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// What actually happened when a reminder was requested.
///
/// PORT-FIX: the Kotlin's scheduling was `void` and failed silently in three
/// separate ways — a past trigger time scheduled nothing, a denied
/// notification permission dropped the notification, and a denied exact-alarm
/// permission quietly downgraded to an inexact alarm. Meanwhile the details
/// screen unconditionally told the user "تم ضبط المنبه". Returning the outcome
/// lets the UI say something true.
enum ReminderOutcome {
  /// Scheduled as an exact alarm.
  scheduled,

  /// Scheduled, but only inexactly — the OS withheld exact-alarm permission,
  /// so it may fire late.
  scheduledInexact,

  /// The lead time had already elapsed but the package has not expired yet, so
  /// the reminder was shown immediately instead.
  firedImmediately,

  /// The package expiry is already in the past; nothing was scheduled.
  expiryAlreadyPassed,

  /// The user has not granted notification permission.
  permissionDenied,

  /// Not running on Android.
  unsupported,
}

/// Schedules expiry reminders, replacing the Kotlin's `AlarmScheduler` +
/// `ReminderReceiver` pair.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const String channelId = 'package_reminders';
  static const String channelName = 'Package Reminders';
  static const String channelDescription = 'Reminders for package expiration';

  /// Carrier timestamps are Yemen local time and the device may not be.
  static const String _timeZoneName = 'Asia/Aden';

  static const String defaultTitle = 'باقتك على وشك الانتهاء';
  static const String defaultBody = 'جدّد الآن قبل أن تفقد رصيدك.';

  late final tz.Location _location;
  bool _initialized = false;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Prepares timezones, the plugin, and the notification channel.
  ///
  /// Reminders survive a reboot without any work here: the plugin registers its
  /// own `ScheduledNotificationBootReceiver`, which the manifest merger folds
  /// in, and `RECEIVE_BOOT_COMPLETED` is declared in our manifest. The Kotlin
  /// had no boot receiver at all, so every pending reminder was destroyed by a
  /// restart and never re-registered.
  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    _location = tz.getLocation(_timeZoneName);
    tz.setLocalLocation(_location);

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  /// Requests notification permission, and exact-alarm permission where the OS
  /// requires it.
  Future<bool> requestPermissions() async {
    if (!_isAndroid) return false;

    final bool granted =
        await _android?.requestNotificationsPermission() ?? false;
    // Requesting this is allowed to fail; inexact scheduling still works.
    await _android?.requestExactAlarmsPermission();
    return granted;
  }

  Future<bool> areNotificationsEnabled() async =>
      _isAndroid && (await _android?.areNotificationsEnabled() ?? false);

  Future<bool> canScheduleExactAlarms() async =>
      _isAndroid && (await _android?.canScheduleExactNotifications() ?? false);

  /// Schedules a reminder [leadTimeHours] before [expiryMillis].
  ///
  /// Returns what actually happened — callers are expected to surface it rather
  /// than assume success.
  Future<ReminderOutcome> scheduleExpiryReminder({
    required int eventId,
    required String packageTitle,
    required int expiryMillis,
    required int leadTimeHours,
  }) async {
    if (!_isAndroid) return ReminderOutcome.unsupported;
    await initialize();

    if (!await areNotificationsEnabled()) {
      return ReminderOutcome.permissionDenied;
    }

    final tz.TZDateTime now = tz.TZDateTime.now(_location);
    final tz.TZDateTime expiry = tz.TZDateTime.fromMillisecondsSinceEpoch(
      _location,
      expiryMillis,
    );

    if (!expiry.isAfter(now)) {
      return ReminderOutcome.expiryAlreadyPassed;
    }

    final tz.TZDateTime triggerAt = expiry.subtract(
      Duration(hours: leadTimeHours),
    );

    // PORT-FIX: when the lead time had already elapsed the Kotlin silently
    // scheduled nothing and told the user nothing, so a package expiring in
    // under 24h produced no reminder at all. The user's intent here is
    // unambiguous, so tell them now.
    if (!triggerAt.isAfter(now)) {
      final ReminderOutcome outcome = await showNow(
        id: eventId,
        title: defaultTitle,
        body: _bodyFor(packageTitle),
      );
      return outcome == ReminderOutcome.permissionDenied
          ? outcome
          : ReminderOutcome.firedImmediately;
    }

    final bool exact = await canScheduleExactAlarms();

    await _plugin.zonedSchedule(
      // PORT-FIX: the Kotlin keyed its PendingIntent on `pkgName.hashCode()` —
      // the hash of the package *title* — so two reminders for same-titled
      // packages collided and the second silently cancelled the first. The
      // database row id is unique by construction.
      id: eventId,
      scheduledDate: triggerAt,
      title: defaultTitle,
      body: _bodyFor(packageTitle),
      notificationDetails: _details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );

    return exact
        ? ReminderOutcome.scheduled
        : ReminderOutcome.scheduledInexact;
  }

  /// Shows a notification immediately.
  ///
  /// PORT-FIX: the Kotlin checked the permission and then silently did nothing
  /// forever when it was missing. The caller is told instead.
  Future<ReminderOutcome> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_isAndroid) return ReminderOutcome.unsupported;
    await initialize();

    if (!await areNotificationsEnabled()) {
      developer.log(
        'Notification $id suppressed: permission not granted',
        name: 'NotificationService',
      );
      return ReminderOutcome.permissionDenied;
    }

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details,
    );
    return ReminderOutcome.firedImmediately;
  }

  Future<void> cancelReminder(int eventId) async {
    if (!_isAndroid) return;
    await _plugin.cancel(id: eventId);
  }

  Future<void> cancelAll() async {
    if (!_isAndroid) return;
    await _plugin.cancelAll();
  }

  static String _bodyFor(String packageTitle) =>
      packageTitle.isEmpty ? defaultBody : '$packageTitle · $defaultBody';

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      autoCancel: true,
    ),
  );
}
