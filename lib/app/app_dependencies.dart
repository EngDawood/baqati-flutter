import 'dart:async';
import 'dart:developer' as developer;

import 'package:intl/date_symbol_data_local.dart';

import 'package:baqati/data/app_database.dart';
import 'package:baqati/data/package_event_dao.dart';
import 'package:baqati/data/package_repository.dart';
import 'package:baqati/services/notification_service.dart';
import 'package:baqati/services/settings_service.dart';
import 'package:baqati/services/sms_service.dart';
import 'package:baqati/services/sms_sync_service.dart';
import 'package:baqati/viewmodels/package_view_model.dart';

/// The app's composition root.
///
/// Everything is constructed once here and handed down by constructor, per the
/// project's manual-DI rule — there is no service locator and no global
/// singleton. Tests build this with fakes instead of calling [bootstrap].
class AppDependencies {
  AppDependencies({
    required this.settings,
    required this.repository,
    required this.sms,
    required this.notifications,
    required this.sync,
    required this.packages,
  });

  final SettingsService settings;
  final PackageRepository repository;
  final SmsService sms;
  final NotificationService notifications;
  final SmsSyncService sync;
  final PackageViewModel packages;

  /// Builds the real dependency graph and brings it up.
  ///
  /// Preferences are read before this returns so the router's onboarding
  /// redirect never sees a default that is about to be replaced — the same
  /// reason [SettingsService.load] is a future.
  static Future<AppDependencies> bootstrap() async {
    await initializeDateFormatting('ar');

    final SettingsService settings = await SettingsService.load();
    final PackageRepository repository = PackageRepository(
      PackageEventDao(AppDatabase()),
    );
    final SmsService sms = SmsService();
    final NotificationService notifications = NotificationService();

    final SmsSyncService sync = SmsSyncService(
      repository: repository,
      sms: sms,
      notifications: notifications,
      settings: settings,
    );

    final AppDependencies deps = AppDependencies(
      settings: settings,
      repository: repository,
      sms: sms,
      notifications: notifications,
      sync: sync,
      packages: PackageViewModel(
        repository: repository,
        sms: sms,
        sync: sync,
        notifications: notifications,
        settings: settings,
      ),
    );

    await deps._start();
    return deps;
  }

  /// Loads stored events, then backfills from the inbox in the background.
  ///
  /// PORT-FIX: `HomeScreen.kt:57` ran a full inbox sync from a `LaunchedEffect`
  /// keyed on permission state, so returning to the dashboard re-scanned up to
  /// a hundred messages. Syncing belongs to app startup, not to entering a
  /// screen; the user can still force one from the refresh button.
  Future<void> _start() async {
    await notifications.initialize();
    await packages.initialize();
    sync.start();

    // Deliberately not awaited: the first frame should not wait on a content
    // provider query. The repository notifies when rows land.
    unawaited(_backfill());
  }

  Future<void> _backfill() async {
    if (!packages.hasSmsPermission) return;
    try {
      await sync.syncInbox();
    } on Object catch (error) {
      developer.log('Startup inbox sync failed: $error', name: 'AppDeps');
    }
  }

  Future<void> dispose() async {
    await sync.dispose();
    packages.dispose();
  }
}
