import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:baqati/services/notification_service.dart';
import 'package:baqati/services/settings_service.dart';
import 'package:baqati/theme/app_colors.dart';
import 'package:baqati/theme/app_theme.dart';
import 'package:baqati/utils/formatters.dart';
import 'package:baqati/viewmodels/package_view_model.dart';
import 'package:baqati/widgets/app_card.dart';
import 'package:baqati/widgets/primary_button.dart';
import 'package:baqati/widgets/screen_app_bar.dart';
import 'package:baqati/widgets/segmented_button_row.dart';

/// How long a hand-entered package lasts.
enum _Duration {
  weekly(7, 'أسبوعية (٧ أيام)'),
  monthly(30, 'شهرية (٣٠ يوم)'),
  custom(0, 'مخصّص');

  const _Duration(this.days, this.label);

  final int days;
  final String label;
}

/// Records a package the carrier never messaged about.
///
/// This is the whole app on iOS, where no API exposes the SMS inbox.
class ManualAlertScreen extends StatefulWidget {
  const ManualAlertScreen({
    required this.packages,
    required this.settings,
    super.key,
  });

  final PackageViewModel packages;
  final SettingsService settings;

  @override
  State<ManualAlertScreen> createState() => _ManualAlertScreenState();
}

class _ManualAlertScreenState extends State<ManualAlertScreen> {
  static const List<int> _leadTimeChoices = <int>[12, 24, 48];

  final TextEditingController _name = TextEditingController();
  final TextEditingController _customDays = TextEditingController(text: '7');
  final TextEditingController _minutes = TextEditingController();
  final TextEditingController _sms = TextEditingController();
  final TextEditingController _megabytes = TextEditingController();

  _Duration _duration = _Duration.monthly;
  late int _leadTimeHours = widget.settings.reminderLeadTimeHours;
  TimeOfDay _expiryTime = const TimeOfDay(hour: 0, minute: 0);
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _customDays.addListener(_onCustomDaysChanged);
  }

  @override
  void dispose() {
    _customDays.removeListener(_onCustomDaysChanged);
    _name.dispose();
    _customDays.dispose();
    _minutes.dispose();
    _sms.dispose();
    _megabytes.dispose();
    super.dispose();
  }

  void _onCustomDaysChanged() {
    if (_duration == _Duration.custom) setState(() {});
  }

  int get _days => _duration == _Duration.custom
      ? int.tryParse(_customDays.text.trim()) ?? 0
      : _duration.days;

  /// The expiry the reminder is scheduled against.
  ///
  /// PORT-FIX: the Kotlin computed this inside `remember(daysDuration)`, so it
  /// was captured once per duration change and the time-of-day box beside it
  /// was pure decoration — the prototype says "يمكنك تعديل الوقت", and here it
  /// actually is editable.
  DateTime get _expiry {
    final DateTime day = DateTime.now().add(Duration(days: _days));
    return DateTime(
      day.year,
      day.month,
      day.day,
      _expiryTime.hour,
      _expiryTime.minute,
    );
  }

  bool get _isValid => _days > 0 && _expiry.isAfter(DateTime.now());

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _expiryTime,
    );
    if (picked != null) setState(() => _expiryTime = picked);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final ReminderOutcome outcome;
    try {
      outcome = await widget.packages.addManualAlert(
        title: _name.text.trim().isEmpty
            ? 'باقة مسجلة يدوياً'
            : _name.text.trim(),
        expiry: _expiry,
        leadTimeHours: _leadTimeHours,
        isMonthly: _duration == _Duration.monthly,
        minutes: int.tryParse(_minutes.text.trim()),
        sms: int.tryParse(_sms.text.trim()),
        megabytes: double.tryParse(_megabytes.text.trim()),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_messageFor(outcome))));
    context.pop();
  }

  /// PORT-FIX: the Kotlin popped the screen with no feedback at all, and its
  /// scheduling silently did nothing when the lead time had already elapsed or
  /// a permission was missing. [ReminderOutcome] exists so the user is told
  /// what actually happened.
  String _messageFor(ReminderOutcome outcome) => switch (outcome) {
    ReminderOutcome.scheduled => 'تم حفظ الباقة وضبط التنبيه.',
    ReminderOutcome.scheduledInexact =>
      'تم حفظ الباقة. قد يصل التنبيه متأخراً قليلاً — لم يُسمح بالمنبّه الدقيق.',
    ReminderOutcome.firedImmediately =>
      'تم حفظ الباقة. موعد التنبيه قد مضى، لذا نبّهناك الآن.',
    ReminderOutcome.expiryAlreadyPassed =>
      'تم حفظ الباقة، لكن تاريخ الانتهاء قد مضى فلم يُضبط تنبيه.',
    ReminderOutcome.permissionDenied =>
      'تم حفظ الباقة، لكن الإشعارات غير مسموح بها فلن يصلك تنبيه.',
    ReminderOutcome.remindersDisabled =>
      'تم حفظ الباقة. التنبيهات معطّلة من الإعدادات.',
    ReminderOutcome.unsupported => 'تم حفظ الباقة.',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: <Widget>[
          ScreenAppBar(title: 'إضافة تنبيه يدوي', onBack: () => context.pop()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(bottom: 16, right: 4),
                  child: Text(
                    'أدخل تفاصيل الباقة يدوياً إذا لم تصل رسالة من المشغّل أو '
                    'لمشغّل غير مدعوم بعد.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                const _Label('اسم الباقة'),
                _Field(controller: _name, hint: 'مثال: باقة مزايا فورجي'),
                const SizedBox(height: 14),
                const _Label('نوع / مدة الباقة'),
                SegmentedButtonRow<_Duration>(
                  selected: _duration,
                  options: <SegmentOption<_Duration>>[
                    for (final _Duration value in _Duration.values)
                      SegmentOption<_Duration>(
                        value: value,
                        label: value.label,
                      ),
                  ],
                  onChanged: (_Duration value) =>
                      setState(() => _duration = value),
                ),
                if (_duration == _Duration.custom) ...<Widget>[
                  const SizedBox(height: 10),
                  _Field(
                    controller: _customDays,
                    hint: 'عدد الأيام',
                    isNumeric: true,
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const _Label('تاريخ الانتهاء تلقائي'),
                          _ReadOnlyBox(
                            value: _days > 0 ? Formatters.date(_expiry) : '—',
                            background: AppColors.surfaceTint,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 11),
                    SizedBox(
                      width: 128,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const _Label('الوقت'),
                          _ReadOnlyBox(
                            value: Formatters.time(_expiry),
                            background: AppColors.cardBackground,
                            onTap: _pickTime,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const _Label('الرصيد المتبقّي (اختياري)'),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _Field(
                        controller: _minutes,
                        hint: '📞 دقائق',
                        isNumeric: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Field(
                        controller: _sms,
                        hint: '💬 رسائل',
                        isNumeric: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Field(
                        controller: _megabytes,
                        hint: '📶 ميجا',
                        isNumeric: true,
                        allowsDecimal: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const _Label('نبّهني قبل الانتهاء بـ'),
                SegmentedButtonRow<int>(
                  selected: _leadTimeChoices.contains(_leadTimeHours)
                      ? _leadTimeHours
                      : -1,
                  options: <SegmentOption<int>>[
                    for (final int hours in _leadTimeChoices)
                      SegmentOption<int>(
                        value: hours,
                        label: '${Formatters.number(hours)} ساعة',
                      ),
                    SegmentOption<int>(
                      value: -1,
                      label: _leadTimeChoices.contains(_leadTimeHours)
                          ? 'مخصّص'
                          : '${Formatters.number(_leadTimeHours)} ساعة',
                    ),
                  ],
                  onChanged: (int value) => value == -1
                      ? _pickCustomLeadTime()
                      : setState(() => _leadTimeHours = value),
                ),
              ],
            ),
          ),
          Container(
            color: AppColors.cardBackground,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            child: PrimaryButton(
              label: _isSaving ? 'جارٍ الحفظ…' : '⏰ حفظ التنبيه',
              onPressed: _isValid && !_isSaving ? _save : null,
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _pickCustomLeadTime() async {
    final TextEditingController controller = TextEditingController(
      text: _leadTimeHours.toString(),
    );

    final int? hours = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('نبّهني قبل الانتهاء بـ'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'ساعة'),
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

    if (hours != null && hours > 0) setState(() => _leadTimeHours = hours);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7, right: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: semiBold,
        color: AppColors.textTertiary,
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.isNumeric = false,
    this.allowsDecimal = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool isNumeric;
  final bool allowsDecimal;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: isNumeric
        ? TextInputType.numberWithOptions(decimal: allowsDecimal)
        : TextInputType.text,
    inputFormatters: isNumeric
        ? <TextInputFormatter>[
            FilteringTextInputFormatter.allow(
              allowsDecimal ? RegExp(r'[\d.]') : RegExp(r'\d'),
            ),
          ]
        : null,
    style: const TextStyle(fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textQuaternary),
      filled: true,
      fillColor: AppColors.cardBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.blueMain),
      ),
    ),
  );
}

class _ReadOnlyBox extends StatelessWidget {
  const _ReadOnlyBox({
    required this.value,
    required this.background,
    this.onTap,
  });

  final String value;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: 15,
    color: background,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    onTap: onTap,
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: semiBold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (onTap != null)
          const Icon(Icons.schedule, size: 16, color: AppColors.textQuaternary),
      ],
    ),
  );
}
