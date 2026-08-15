import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:baqati/models/package_event.dart';
import 'package:baqati/router.dart';
import 'package:baqati/services/settings_service.dart';
import 'package:baqati/theme/app_colors.dart';
import 'package:baqati/theme/app_theme.dart';
import 'package:baqati/utils/formatters.dart';
import 'package:baqati/viewmodels/package_view_model.dart';
import 'package:baqati/widgets/app_card.dart';
import 'package:baqati/widgets/empty_state.dart';
import 'package:baqati/widgets/pill_badge.dart';
import 'package:baqati/widgets/primary_button.dart';
import 'package:baqati/widgets/usage_bar.dart';

/// Allowances, key dates and reminder status for the current package.
class PackageDetailsScreen extends StatelessWidget {
  const PackageDetailsScreen({
    required this.packages,
    required this.settings,
    super.key,
  });

  final PackageViewModel packages;
  final SettingsService settings;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: packages,
        builder: (BuildContext context, Widget? child) {
          final PackageEvent? activation = packages.latestActivation;
          final PackageEvent? current = packages.mainPackage;

          return Column(
            children: <Widget>[
              _AppBar(onBack: () => context.pop()),
              Expanded(
                child: current == null
                    ? EmptyState(
                        icon: '📦',
                        title: 'لم يتم التعرف على باقة',
                        message:
                            'لم تصل رسالة تفعيل من ١١١ بعد. يمكنك إضافة باقتك '
                            'يدوياً حتى ذلك الحين.',
                        action: SizedBox(
                          width: 220,
                          child: PrimaryButton(
                            label: '＋ إضافة تنبيه يدوي',
                            height: 48,
                            onPressed: () => context.push(Routes.manualAlert),
                          ),
                        ),
                      )
                    : _Details(
                        current: current,
                        activation: activation,
                        leadTimeHours: settings.reminderLeadTimeHours,
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _AppBar extends StatelessWidget {
  const _AppBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
    child: Row(
      children: <Widget>[
        Material(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(13),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.arrow_back,
                size: 20,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'تفاصيل الباقة',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}

class _Details extends StatelessWidget {
  const _Details({
    required this.current,
    required this.activation,
    required this.leadTimeHours,
  });

  /// The package being shown — normally the newest balance reading.
  final PackageEvent current;

  /// The activation the package started from, if one was ever received.
  final PackageEvent? activation;

  final int leadTimeHours;

  bool get _isExpired {
    final int? expiry = current.expiryTimestamp;
    return expiry != null && expiry <= DateTime.now().millisecondsSinceEpoch;
  }

  @override
  Widget build(BuildContext context) {
    final int? expiry = current.expiryTimestamp;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: <Widget>[
        _HeaderCard(
          title: activation?.title ?? current.title,
          isExpired: _isExpired,
          current: current,
          activation: activation,
        ),
        const SizedBox(height: 14),
        _KeyDatesCard(
          activation: activation,
          expiryMillis: expiry,
          cost: activation?.cost ?? current.cost,
        ),
        const SizedBox(height: 14),
        if (!_isExpired && expiry != null) ...<Widget>[
          _ReminderBanner(leadTimeHours: leadTimeHours),
          const SizedBox(height: 14),
        ],
        PrimaryButton(
          label: _isExpired ? 'تجديد الباقة' : 'جدّد قبل الانتهاء',
          height: 52,
          // Neither reference defines what renewal does — the Kotlin's handler
          // was an empty lambda that silently did nothing. Sending the user to
          // manual entry at least records the renewed package.
          onPressed: () => context.push(Routes.manualAlert),
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.isExpired,
    required this.current,
    required this.activation,
  });

  final String title;
  final bool isExpired;
  final PackageEvent current;
  final PackageEvent? activation;

  /// Builds one bar, or null when the pair of numbers cannot be compared.
  ///
  /// PORT-FIX: `PackageDetailsScreen.kt:46-56` read both the remaining and the
  /// total off the *same* event, so every ratio was `x / x` and all three bars
  /// sat at 100% no matter how much the user had spent. The total belongs to
  /// the activation ("حصلت على ٣٠٠ دقيقة") and the remaining to the newest
  /// balance check — two different rows. When only one of them exists there is
  /// no ratio to draw, and a full bar would be a lie, so the bar is omitted.
  Widget? _bar({
    required String label,
    required num? remaining,
    required num? total,
  }) {
    if (remaining == null || total == null || total <= 0) return null;

    return UsageBar(
      label: label,
      value: '${Formatters.number(remaining)} / ${Formatters.number(total)}',
      progress: remaining / total,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSameRow = activation == null || activation!.id == current.id;

    final List<Widget> bars = <Widget?>[
      _bar(
        label: '📞 الدقائق',
        remaining: current.minutes,
        total: isSameRow ? null : activation!.minutes,
      ),
      _bar(
        label: '💬 الرسائل',
        remaining: current.sms,
        total: isSameRow ? null : activation!.sms,
      ),
      _bar(
        label: '📶 الإنترنت (ميجا)',
        remaining: current.megabytes,
        total: isSameRow ? null : activation!.megabytes,
      ),
    ].whereType<Widget>().toList();

    return AppCard(
      radius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      isExpired
                          ? 'يمن موبايل · غير مفعلة'
                          : 'يمن موبايل · فعّالة',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PillBadge(
                label: isExpired ? 'منتهية' : 'نشطة',
                background: isExpired
                    ? AppColors.orangeBadgeBg
                    : AppColors.blueBg,
                foreground: isExpired
                    ? AppColors.orangeMain
                    : AppColors.blueMain,
              ),
            ],
          ),
          if (bars.isEmpty) ...<Widget>[
            const SizedBox(height: 14),
            _RemainingOnly(event: current),
          ] else
            for (final Widget bar in bars) ...<Widget>[
              const SizedBox(height: 14),
              bar,
            ],
        ],
      ),
    );
  }
}

/// Shown when there is no activation to compare against, so no ratio exists.
class _RemainingOnly extends StatelessWidget {
  const _RemainingOnly({required this.event});

  final PackageEvent event;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const Text(
        'المتبقّي',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 6),
      Text(
        <String>[
          '📞 ${Formatters.number(event.minutes, fallback: '—')} دقيقة',
          '💬 ${Formatters.number(event.sms, fallback: '—')} رسالة',
          '📶 ${Formatters.number(event.megabytes, fallback: '—')} ميجا',
        ].join('  ·  '),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: semiBold,
          color: AppColors.textPrimary,
        ),
      ),
    ],
  );
}

class _KeyDatesCard extends StatelessWidget {
  const _KeyDatesCard({
    required this.activation,
    required this.expiryMillis,
    required this.cost,
  });

  final PackageEvent? activation;
  final int? expiryMillis;
  final double? cost;

  String get _validity {
    final PackageEvent? event = activation;
    final int? expiry = event?.expiryTimestamp;
    if (event == null || expiry == null || expiry <= event.timestamp) {
      return 'غير متوفر';
    }
    final int days = Duration(milliseconds: expiry - event.timestamp).inDays;
    return '${Formatters.number(days)} يوماً';
  }

  @override
  Widget build(BuildContext context) => AppCard(
    radius: 22,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Column(
      children: <Widget>[
        _DateRow(
          label: 'تاريخ التفعيل',
          value: activation == null
              ? 'غير متوفر'
              : Formatters.dateTime(
                  DateTime.fromMillisecondsSinceEpoch(activation!.timestamp),
                ),
        ),
        _DateRow(label: 'مدة الصلاحية', value: _validity),
        _DateRow(
          label: 'تاريخ الانتهاء',
          value: expiryMillis == null
              ? 'غير متوفر'
              : Formatters.dateTime(
                  DateTime.fromMillisecondsSinceEpoch(expiryMillis!),
                ),
          isHighlight: true,
        ),
        _DateRow(
          label: 'قيمة الاشتراك',
          value: Formatters.riyal(cost, fallback: 'غير متوفر'),
          hasDivider: false,
        ),
      ],
    ),
  );
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
    this.hasDivider = true,
  });

  final String label;
  final String value;
  final bool isHighlight;
  final bool hasDivider;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isHighlight ? FontWeight.bold : semiBold,
                  color: isHighlight
                      ? AppColors.orangeDark
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
      if (hasDivider)
        const Divider(height: 1, thickness: 1, color: AppColors.dividerLine),
    ],
  );
}

class _ReminderBanner extends StatelessWidget {
  const _ReminderBanner({required this.leadTimeHours});

  final int leadTimeHours;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.blueBg,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.blueMain,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Text('⏰', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'تنبيه مجدوَل',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.blueTextDark,
                  ),
                ),
                Text(
                  // The prototype's wording, which names the actual lead time
                  // instead of the Kotlin's bare "تم ضبط المنبه" — a claim it
                  // made unconditionally while nothing had been scheduled.
                  'سيصلك تنبيه قبل ${Formatters.number(leadTimeHours)} ساعة '
                  'من الانتهاء.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.blueTextLight,
                    height: 1.4,
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
