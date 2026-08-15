import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'package:baqati/data/package_repository.dart';
import 'package:baqati/models/event_type.dart';
import 'package:baqati/models/package_event.dart';
import 'package:baqati/services/notification_service.dart';
import 'package:baqati/services/settings_service.dart';
import 'package:baqati/services/sms_parser.dart';
import 'package:baqati/services/sms_service.dart';
import 'package:baqati/services/sms_sync_service.dart';

/// What a completed sync should tell the user.
@immutable
class SyncResult {
  const SyncResult({
    required this.newEventCount,
    this.permissionDenied = false,
  });

  final int newEventCount;
  final bool permissionDenied;
}

/// Shared state for the dashboard, history and details screens.
///
/// One instance is created at startup and reused across the whole nav graph,
/// mirroring the Kotlin's single `PackageViewModel`. It listens to
/// [PackageRepository] and re-queries whenever the stored events change, so a
/// message arriving while the user is on the history screen updates it without
/// any screen-level plumbing.
class PackageViewModel extends ChangeNotifier {
  PackageViewModel({
    required PackageRepository repository,
    required SmsService sms,
    required SmsSyncService sync,
    required NotificationService notifications,
    required SettingsService settings,
  }) : _repository = repository,
       _sms = sms,
       _sync = sync,
       _notifications = notifications,
       _settings = settings {
    _repository.addListener(_onRepositoryChanged);
  }

  final PackageRepository _repository;
  final SmsService _sms;
  final SmsSyncService _sync;
  final NotificationService _notifications;
  final SettingsService _settings;

  List<PackageEvent> _events = const <PackageEvent>[];
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _hasSmsPermission = false;
  bool _isDisposed = false;

  Future<void> _refresh = Future<void>.value();

  /// Completes once any refresh triggered by a repository change has landed.
  ///
  /// The repository notifies synchronously but re-querying it is asynchronous,
  /// so a caller that writes a row and immediately reads [events] would see the
  /// state from before its own write. Awaiting this closes that window.
  Future<void> get refreshed => _refresh;

  /// Every stored event, newest first.
  List<PackageEvent> get events => _events;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get hasSmsPermission => _hasSmsPermission;

  /// Whether SMS auto-sync exists on this platform at all.
  ///
  /// False on iOS, where no API exposes the inbox — those screens hide the
  /// permission banner and sync button rather than offering a control that can
  /// never succeed.
  bool get supportsSmsSync => defaultTargetPlatform == TargetPlatform.android;

  @override
  void dispose() {
    _isDisposed = true;
    _repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  /// Loads stored events and refreshes the cached permission state.
  Future<void> initialize() async {
    _hasSmsPermission = await _sms.hasSmsPermission();
    await _reload();
  }

  void _onRepositoryChanged() => _refresh = _reload();

  Future<void> _reload() async {
    final List<PackageEvent> events = await _repository.getAllEvents();
    // A refresh already in flight when the app shuts down would otherwise
    // notify a disposed notifier, which throws.
    if (_isDisposed) return;

    _events = events;
    _isLoading = false;
    notifyListeners();
  }

  /// Packages that have not expired, soonest expiry first.
  ///
  /// Grouped by expiry so that repeated balance checks of one package collapse
  /// to the newest reading rather than appearing as several live packages. The
  /// main-credit row is excluded: it is an account balance, not a package with
  /// allowances to count down.
  List<PackageEvent> get activePackages {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final Map<int, PackageEvent> newestByExpiry = <int, PackageEvent>{};

    for (final PackageEvent event in _events) {
      final int? expiry = event.expiryTimestamp;
      if (expiry == null || expiry <= now) continue;
      if (event.title == SmsParser.mainBalanceTitle) continue;

      final PackageEvent? existing = newestByExpiry[expiry];
      if (existing == null || event.timestamp > existing.timestamp) {
        newestByExpiry[expiry] = event;
      }
    }

    return newestByExpiry.values.toList()..sort(
      (PackageEvent a, PackageEvent b) =>
          a.expiryTimestamp!.compareTo(b.expiryTimestamp!),
    );
  }

  /// The package the dashboard features: the one expiring soonest.
  ///
  /// Falls back to the most recent package-shaped event so a user whose
  /// packages have all expired still sees what they had, rather than an empty
  /// dashboard that looks broken.
  PackageEvent? get mainPackage {
    final List<PackageEvent> active = activePackages;
    if (active.isNotEmpty) return active.first;

    for (final PackageEvent event in _events) {
      if (event.expiryTimestamp != null &&
          event.title != SmsParser.mainBalanceTitle) {
        return event;
      }
    }
    return _events.isEmpty ? null : _events.first;
  }

  /// Active packages other than [mainPackage].
  List<PackageEvent> get secondaryPackages =>
      activePackages.skip(1).toList(growable: false);

  PackageEvent? get latestActivation => _latestOfType(EventType.activation);

  PackageEvent? get latestBalanceCheck => _latestOfType(EventType.balanceCheck);

  /// The most recent main-credit reading, in riyal.
  double? get mainBalance {
    for (final PackageEvent event in _events) {
      if (event.title == SmsParser.mainBalanceTitle) return event.balance;
    }
    return null;
  }

  /// True when [mainPackage] has run out.
  bool get isExpired {
    final int? expiry = mainPackage?.expiryTimestamp;
    return expiry != null && expiry <= DateTime.now().millisecondsSinceEpoch;
  }

  /// How long [mainPackage] has left, or null when there is no live package.
  Duration? get timeRemaining {
    final int? expiry = mainPackage?.expiryTimestamp;
    if (expiry == null) return null;

    final Duration remaining = DateTime.fromMillisecondsSinceEpoch(
      expiry,
    ).difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Events of one [type], or all of them when [type] is null.
  List<PackageEvent> eventsOfType(EventType? type) => type == null
      ? _events
      : _events
            .where((PackageEvent event) => event.type == type)
            .toList(growable: false);

  /// Re-reads the inbox, prompting for permission first if it is missing.
  Future<SyncResult> sync() async {
    if (_isSyncing) return const SyncResult(newEventCount: 0);

    _isSyncing = true;
    notifyListeners();

    try {
      if (!_hasSmsPermission) {
        _hasSmsPermission = await _sms.requestSmsPermission();
        if (!_hasSmsPermission) {
          return const SyncResult(newEventCount: 0, permissionDenied: true);
        }
      }
      final int count = await _sync.syncInbox();
      await refreshed;
      return SyncResult(newEventCount: count);
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Re-checks SMS permission, which the user may have changed in Settings.
  Future<void> refreshPermissionState() async {
    final bool granted = await _sms.hasSmsPermission();
    if (granted == _hasSmsPermission) return;
    _hasSmsPermission = granted;
    notifyListeners();
  }

  /// Stores a hand-entered package and schedules its reminder.
  ///
  /// PORT-FIX: the Kotlin wrote these as `EventType.ACTIVATION`, so every
  /// manual entry became the newest "activation" and permanently masked the
  /// real carrier activation that the details screen reads its totals from.
  /// [EventType.manual] exists to keep the two apart.
  ///
  /// PORT-FIX: the Kotlin also wrote the form's lead time and alert type into
  /// global settings as a side effect of saving one package, silently
  /// reconfiguring every future reminder. The lead time applies to this event
  /// only; the Settings screen owns the global default.
  Future<ReminderOutcome> addManualAlert({
    required String title,
    required DateTime expiry,
    required int leadTimeHours,
    required bool isMonthly,
    int? minutes,
    int? sms,
    double? megabytes,
  }) async {
    final PackageEvent event = PackageEvent(
      type: EventType.manual,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      title: title,
      description: isMonthly ? 'باقة شهرية' : 'باقة مخصصة',
      minutes: minutes,
      sms: sms,
      megabytes: megabytes,
      expiryTimestamp: expiry.millisecondsSinceEpoch,
    );

    final int id = await _repository.insert(event);
    await refreshed;
    if (id == 0) {
      developer.log('Manual alert not stored', name: 'PackageViewModel');
      return ReminderOutcome.expiryAlreadyPassed;
    }

    // The event is stored either way; only the notification is suppressed, so
    // the package still appears on the dashboard and in history.
    if (!_settings.shouldNotify) return ReminderOutcome.remindersDisabled;

    return _notifications.scheduleExpiryReminder(
      eventId: id,
      packageTitle: title,
      expiryMillis: event.expiryTimestamp!,
      leadTimeHours: leadTimeHours,
    );
  }

  /// Deletes an event and cancels any reminder it had pending.
  Future<void> deleteEvent(int id) async {
    await _notifications.cancelReminder(id);
    await _repository.deleteById(id);
    await refreshed;
  }

  /// The lead time reminders are scheduled with, for display.
  int get reminderLeadTimeHours => _settings.reminderLeadTimeHours;

  PackageEvent? _latestOfType(EventType type) {
    for (final PackageEvent event in _events) {
      if (event.type == type) return event;
    }
    return null;
  }
}
