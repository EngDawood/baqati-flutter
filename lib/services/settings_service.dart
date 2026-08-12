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

  /// True once the user has finished onboarding and granted permissions.
  bool get isOnboarded => hasSeenOnboarding && permissionsGranted;

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
}
