import 'package:flutter/material.dart';

import 'package:baqati/services/notification_service.dart';
import 'package:baqati/services/settings_service.dart';
import 'package:baqati/services/sms_service.dart';
import 'package:baqati/theme/app_colors.dart';
import 'package:baqati/theme/app_theme.dart';
import 'package:baqati/viewmodels/package_view_model.dart';
import 'package:baqati/widgets/primary_button.dart';
import 'package:baqati/widgets/privacy_note.dart';

/// First-run introduction and permission request.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.settings,
    required this.sms,
    required this.notifications,
    required this.packages,
    super.key,
  });

  final SettingsService settings;
  final SmsService sms;
  final NotificationService notifications;
  final PackageViewModel packages;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isRequesting = false;

  /// Asks for both permissions, records what was actually granted, then lets
  /// the user through either way.
  ///
  /// PORT-FIX: `NavGraph.kt:54` wrote `setPermissionsGranted(true)`
  /// unconditionally, so a user who denied everything was recorded as fully
  /// permissioned and landed on a dashboard that could never populate — with
  /// no banner offering to fix it, because the banner keyed off that same flag.
  Future<void> _requestAndContinue() async {
    setState(() => _isRequesting = true);

    bool smsGranted = false;
    try {
      smsGranted = await widget.sms.requestSmsPermission();
      // Notification permission is requested regardless: reminders are useful
      // even for hand-entered packages, which is the whole iOS experience.
      await widget.notifications.requestPermissions();
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }

    await widget.settings.setPermissionsGranted(smsGranted);
    if (smsGranted) {
      await widget.packages.refreshPermissionState();
      await widget.packages.sync();
    }

    // Written last: it is what the router's redirect watches, so flipping it
    // before the permission state is stored would route to a dashboard that
    // has not yet heard about the grant.
    await widget.settings.setHasSeenOnboarding(true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.onboardingBg,
    body: SafeArea(
      child: Column(
        children: <Widget>[
          const Expanded(child: _Hero()),
          _PermissionSheet(
            isRequesting: _isRequesting,
            onContinue: _isRequesting ? null : _requestAndContinue,
            showSmsRow: widget.packages.supportsSmsSync,
          ),
        ],
      ),
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 34),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const _AppMark(),
        const SizedBox(height: 22),
        const Text(
          'باقتي',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'نراقب رسائل باقتك وننبّهك قبل أن تفقد رصيدك المتبقّي من الدقائق '
          'والرسائل والإنترنت.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
      ],
    ),
  );
}

/// The rounded blue tile with a ring and an orange dot, from the prototype.
class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 96,
    height: 96,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.blueMain,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 5),
            ),
          ),
          Positioned(
            top: 22,
            right: 24,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.orangeMain,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PermissionSheet extends StatelessWidget {
  const _PermissionSheet({
    required this.isRequesting,
    required this.onContinue,
    required this.showSmsRow,
  });

  final bool isRequesting;
  final VoidCallback? onContinue;
  final bool showSmsRow;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text(
          'نحتاج هذه الأذونات',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        if (showSmsRow) ...<Widget>[
          const _PermissionItem(
            icon: '✉️',
            title: 'قراءة واستقبال الرسائل',
            subtitle: 'من رقم المشغّل ١١١ فقط لتحليل تفاصيل الباقة.',
          ),
          const SizedBox(height: 14),
        ],
        const _PermissionItem(
          icon: '🔔',
          title: 'الإشعارات',
          subtitle: 'لتنبيهك قبل انتهاء الباقة بوقت كافٍ.',
        ),
        const SizedBox(height: 14),
        const PrivacyNote.onboarding(),
        const SizedBox(height: 24),
        PrimaryButton(
          label: isRequesting ? 'جارٍ الطلب…' : 'السماح والمتابعة',
          height: 52,
          onPressed: onContinue,
        ),
      ],
    ),
  );
}

class _PermissionItem extends StatelessWidget {
  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surfaceTint,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.permissionItemBorder),
    ),
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.blueBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: semiBold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
