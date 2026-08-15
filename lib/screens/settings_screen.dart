import 'package:flutter/material.dart';

import 'package:baqati/services/notification_service.dart';
import 'package:baqati/services/settings_service.dart';
import 'package:baqati/theme/app_colors.dart';
import 'package:baqati/theme/app_theme.dart';
import 'package:baqati/utils/formatters.dart';
import 'package:baqati/viewmodels/package_view_model.dart';
import 'package:baqati/widgets/app_card.dart';
import 'package:baqati/widgets/pill_badge.dart';
import 'package:baqati/widgets/privacy_note.dart';
import 'package:baqati/widgets/screen_app_bar.dart';
import 'package:baqati/widgets/segmented_button_row.dart';

/// Permissions, carriers and reminder preferences.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.packages,
    required this.settings,
    required this.notifications,
    super.key,
  });

  final PackageViewModel packages;
  final SettingsService settings;
  final NotificationService notifications;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// The lead times the prototype offers, plus a custom escape hatch.
  static const List<int> _leadTimeChoices = <int>[12, 24, 48];

  Future<void> _sync() async {
    final SyncResult result = await widget.packages.sync();
    if (!mounted) return;

    _toast(
      result.permissionDenied
          ? 'لم يتم منح إذن قراءة الرسائل'
          : 'تم الانتهاء (${Formatters.number(result.newEventCount)} حدث جديد)',
    );
  }

  Future<void> _setRemindersEnabled(bool enabled) async {
    await widget.settings.setRemindersEnabled(enabled);
    if (!enabled) {
      // Leaving alarms armed after the user silences the app would fire
      // notifications they explicitly turned off.
      await widget.notifications.cancelAll();
      return;
    }
    if (!await widget.notifications.requestPermissions() && mounted) {
      _toast('لم يتم منح إذن الإشعارات');
    }
  }

  Future<void> _pickCustomLeadTime() async {
    final TextEditingController controller = TextEditingController(
      text: widget.settings.reminderLeadTimeHours.toString(),
    );

    final int? hours = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('التنبيه قبل الانتهاء بـ'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            suffixText: 'ساعة',
            hintText: 'مثال: ٧٢',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(int.tryParse(controller.text.trim())),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (hours != null && hours > 0) {
      await widget.settings.setReminderLeadTimeHours(hours);
    }
  }

  void _toast(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: ListenableBuilder(
        // Rebuilds for both preference writes and permission/sync changes.
        listenable: Listenable.merge(<Listenable>[
          widget.settings,
          widget.packages,
        ]),
        builder: (BuildContext context, Widget? child) {
          final SettingsService settings = widget.settings;
          final bool hasSms = widget.packages.hasSmsPermission;
          final bool supportsSms = widget.packages.supportsSmsSync;
          final int leadTime = settings.reminderLeadTimeHours;
          final bool isCustomLeadTime = !_leadTimeChoices.contains(leadTime);

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            children: <Widget>[
              const ScreenAppBar(title: 'الإعدادات'),
              if (supportsSms) ...<Widget>[
                AppCard(
                  onTap: widget.packages.isSyncing ? null : _sync,
                  child: Center(
                    child: Text(
                      hasSms
                          ? '🔄 فحص واستعادة الرسائل الحديثة من ١١١'
                          : '✉️ منح إذن قراءة رسائل ١١١ وفحصها',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: semiBold,
                        color: AppColors.blueMain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'الأذونات والخدمات',
                  children: <Widget>[
                    _SettingRow(
                      icon: '✉️',
                      iconBackground: AppColors.blueBg,
                      title: 'إذن قراءة رسائل ١١١',
                      subtitle: hasSms
                          ? 'ممنوح ومفعّل تلقائياً'
                          : 'انقر لمنح الإذن',
                      onTap: hasSms ? null : _sync,
                      trailing: PillBadge(
                        label: hasSms ? 'نشط' : 'غير مفعّل',
                        background: hasSms
                            ? AppColors.blueBg
                            : AppColors.orangeBadgeBg,
                        foreground: hasSms
                            ? AppColors.blueMain
                            : AppColors.orangeMain,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              _Section(
                title: 'المشغّلون',
                children: <Widget>[
                  _SettingRow(
                    icon: '📡',
                    iconBackground: AppColors.blueBg,
                    title: 'يمن موبايل',
                    subtitle: 'الرقم ١١١',
                    trailing: const PillBadge(
                      label: 'نشط',
                      background: AppColors.blueBg,
                      foreground: AppColors.blueMain,
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.dividerLine,
                  ),
                  // PORT-FIX: the Kotlin drew this unsupported carrier with the
                  // same live-looking blue toggle as Yemen Mobile
                  // (`PlaceholderScreens.kt:247`), so it read as switchable
                  // when nothing behind it existed.
                  _SettingRow(
                    icon: '📡',
                    iconBackground: AppColors.backgroundMain,
                    title: 'Y / سبأفون',
                    subtitle: 'قريباً',
                    isFaded: true,
                    trailing: const PillBadge(
                      label: 'لاحقاً',
                      background: AppColors.backgroundMain,
                      foreground: AppColors.textQuaternary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'التنبيهات',
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: settings.remindersEnabled,
                      onChanged: _setRemindersEnabled,
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppColors.blueMain,
                      title: const Text(
                        'تفعيل التنبيهات',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: semiBold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        settings.remindersEnabled
                            ? 'ننبّهك قبل انتهاء كل باقة'
                            : 'لن تصلك أي تنبيهات',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textQuaternary,
                        ),
                      ),
                    ),
                  ),
                  if (settings.remindersEnabled) ...<Widget>[
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.dividerLine,
                    ),
                    _ChoiceBlock(
                      label: 'التنبيه قبل الانتهاء بـ',
                      child: SegmentedButtonRow<int>(
                        // A custom value is represented by -1 so the row can
                        // show it selected without inventing a fourth choice.
                        selected: isCustomLeadTime ? -1 : leadTime,
                        options: <SegmentOption<int>>[
                          for (final int hours in _leadTimeChoices)
                            SegmentOption<int>(
                              value: hours,
                              label: '${Formatters.number(hours)} ساعة',
                            ),
                          SegmentOption<int>(
                            value: -1,
                            label: isCustomLeadTime
                                ? '${Formatters.number(leadTime)} ساعة'
                                : 'مخصّص',
                          ),
                        ],
                        onChanged: (int value) => value == -1
                            ? _pickCustomLeadTime()
                            : settings.setReminderLeadTimeHours(value),
                      ),
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.dividerLine,
                    ),
                    _ChoiceBlock(
                      label: 'نوع التنبيه',
                      child: SegmentedButtonRow<AlertType>(
                        selected: settings.alertType,
                        options: const <SegmentOption<AlertType>>[
                          SegmentOption<AlertType>(
                            value: AlertType.inApp,
                            label: 'داخل التطبيق',
                          ),
                          SegmentOption<AlertType>(
                            value: AlertType.notification,
                            label: 'إشعار',
                          ),
                          SegmentOption<AlertType>(
                            value: AlertType.both,
                            label: 'كلاهما',
                          ),
                        ],
                        onChanged: settings.setAlertType,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              const PrivacyNote.settings(),
            ],
          );
        },
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 8, right: 6),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: semiBold,
            color: AppColors.textTertiary,
          ),
        ),
      ),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: children),
      ),
    ],
  );
}

class _ChoiceBlock extends StatelessWidget {
  const _ChoiceBlock({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    this.isFaded = false,
  });

  final String icon;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool isFaded;

  @override
  Widget build(BuildContext context) {
    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: semiBold,
                    color: isFaded
                        ? AppColors.textQuaternary
                        : AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textQuaternary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );

    if (onTap == null) return row;

    return InkWell(onTap: onTap, child: row);
  }
}
