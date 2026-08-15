import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the user should be told a package is about to expire.
enum AlertType {
  both('BOTH'),
  notification('NOTIFICATION'),
  inApp('IN_APP');

  const AlertType(this.wireName);

  final String wireName;

  static AlertType fromWireName(String value) => AlertType.values.firstWhere(
    (AlertType type) => type.wireName == value,
    orElse: () => AlertType.both,
  );
}

/// User preferences, replacing the Kotlin's Preferences DataStore.
///
/// Values are read once into memory by [load] before the app renders, so
/// callers never observe a default that is about to be replaced by a real
/// stored value.
///
/// PORT-FIX: the Kotlin exposed these as cold Flows collected with
/// `initial = false`, and computed the navigation start destination from them.
/// A returning user could therefore be routed to onboarding on the first frame,
/// before DataStore had finished reading — and Compose Navigation ignores a
/// start destination that changes after the graph is built.
class SettingsService extends ChangeNotifier {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static const String _keyPermissionsGranted = 'permissions_granted';
  static const String _keyHasSeenOnboarding = 'has_seen_onboarding';
  static const String _keyReminderLeadTimeHours = 'reminder_lead_time_hours';
  static const String _keyAlertType = 'alert_type';
  static const String _keyRemindersEnabled = 'reminders_enabled';

  /// Reads preferences from disk, then constructs the service.
  static Future<SettingsService> load() async =>
      SettingsService(await SharedPreferences.getInstance());

  bool get permissionsGranted =>
      _prefs.getBool(_keyPermissionsGranted) ?? false;

  bool get hasSeenOnboarding => _prefs.getBool(_keyHasSeenOnboarding) ?? false;

  int get reminderLeadTimeHours =>
      _prefs.getInt(_keyReminderLeadTimeHours) ?? 24;

  AlertType get alertType =>
      AlertType.fromWireName(_prefs.getString(_keyAlertType) ?? 'BOTH');

  /// Master switch for expiry reminders, defaulting to on.
  ///
  /// The design prototype's Settings screen has a "تفعيل التنبيهات" toggle, but
  /// the Kotlin drew it as a decorative `Box` (`PlaceholderScreens.kt:201`)
  /// backed by nothing, so there was no state for it to read or write. This is
  /// that state. It gates scheduling app-side, which is distinct from the OS
  /// notification permission — a user can keep the permission granted and still
  /// silence the app.
  bool get remindersEnabled => _prefs.getBool(_keyRemindersEnabled) ?? true;

  /// Whether a scheduled reminder should raise a system notification.
  ///
  /// [AlertType.inApp] means the user wants the in-app warning banners only.
  bool get shouldNotify => remindersEnabled && alertType != AlertType.inApp;

  /// True once the user has been through onboarding, whatever they answered.
  ///
  /// PORT-FIX: this used to also require [permissionsGranted], mirroring
  /// `NavGraph.kt:27`. That gate is unsatisfiable in two ordinary cases — a
  /// user who declines the SMS prompt, and every iOS user, since no iOS API
  /// exposes the inbox — and because onboarding is the redirect target for all
  /// other routes, failing it traps the app on the onboarding screen with no
  /// way forward. The Kotlin only escaped this by writing a hardcoded `true`
  /// into the flag (`NavGraph.kt:54`) regardless of what the user actually
  /// granted, which then made the flag useless for anything else.
  ///
  /// [permissionsGranted] stays honest and drives the dashboard's "grant
  /// access" banner instead. The app is usable without SMS: manual entry
  /// covers it.
  bool get isOnboarded => hasSeenOnboarding;

  Future<void> setPermissionsGranted(bool value) async {
    await _prefs.setBool(_keyPermissionsGranted, value);
    notifyListeners();
  }

  Future<void> setHasSeenOnboarding(bool value) async {
    await _prefs.setBool(_keyHasSeenOnboarding, value);
    notifyListeners();
  }

  Future<void> setReminderLeadTimeHours(int value) async {
    await _prefs.setInt(_keyReminderLeadTimeHours, value);
    notifyListeners();
  }

  Future<void> setAlertType(AlertType value) async {
    await _prefs.setString(_keyAlertType, value.wireName);
    notifyListeners();
  }

  Future<void> setRemindersEnabled(bool value) async {
    await _prefs.setBool(_keyRemindersEnabled, value);
    notifyListeners();
  }
}
