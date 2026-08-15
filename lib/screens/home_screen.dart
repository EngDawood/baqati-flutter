import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:baqati/models/package_event.dart';
import 'package:baqati/router.dart';
import 'package:baqati/theme/app_colors.dart';
import 'package:baqati/theme/app_theme.dart';
import 'package:baqati/utils/formatters.dart';
import 'package:baqati/viewmodels/package_view_model.dart';
import 'package:baqati/widgets/app_card.dart';
import 'package:baqati/widgets/balance_card.dart';
import 'package:baqati/widgets/pill_badge.dart';
import 'package:baqati/widgets/primary_button.dart';

/// The dashboard: how long the current package lasts and what is left of it.
class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.packages, super.key});

  final PackageViewModel packages;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Under this much time left, the dashboard warns.
  static const Duration _warningWindow = Duration(hours: 24);

  Future<void> _sync() async {
    final SyncResult result = await widget.packages.sync();
    if (!mounted) return;

    final String message = result.permissionDenied
        ? 'لم يتم منح إذن قراءة الرسائل'
        : 'تم تحديث البيانات (${Formatters.number(result.newEventCount)} حدث)';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: widget.packages,
        builder: (BuildContext context, Widget? child) {
          final PackageViewModel vm = widget.packages;
          if (vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final PackageEvent? main = vm.mainPackage;
          final Duration? remaining = vm.timeRemaining;
          final bool isExpired = vm.isExpired;
          final bool isEndingSoon =
              remaining != null &&
              remaining > Duration.zero &&
              remaining <= _warningWindow;

          return RefreshIndicator(
            onRefresh: _sync,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              children: <Widget>[
                _Header(
                  packageTitle: main?.title,
                  isSyncing: vm.isSyncing,
                  showSync: vm.supportsSmsSync,
                  needsAttention: isExpired || isEndingSoon,
                  onSync: _sync,
                ),
                const SizedBox(height: 14),
                if (vm.supportsSmsSync && !vm.hasSmsPermission) ...<Widget>[
                  _PermissionBanner(onGrant: _sync),
                  const SizedBox(height: 14),
                ],
                if (isExpired) ...<Widget>[
                  const _WarningBanner(
                    message: 'انتهت صلاحية باقتك الحالية أو استُنفذت.',
                  ),
                  const SizedBox(height: 14),
                ] else if (isEndingSoon) ...<Widget>[
                  const _WarningBanner(
                    message:
                        'باقتك على وشك الانتهاء — جدّد الآن قبل أن تفقد رصيدك.',
                  ),
                  const SizedBox(height: 14),
                ],
                _CountdownHero(
                  remaining: remaining,
                  isExpired: isExpired,
                  expiry: main?.expiryTimestamp,
                ),
                const SizedBox(height: 24),
                const _SectionHeader(),
                const SizedBox(height: 11),
                _BalanceRow(package: main),
                const SizedBox(height: 24),
                if (vm.secondaryPackages.isNotEmpty) ...<Widget>[
                  const Text(
                    'باقات أخرى نشطة',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 11),
                  for (final PackageEvent event in vm.secondaryPackages)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SecondaryPackageCard(event: event),
                    ),
                  const SizedBox(height: 2),
                ],
                PrimaryButton(
                  label: main == null ? 'تفعيل باقة جديدة' : 'تفاصيل الباقة',
                  onPressed: () => context.push(
                    main == null ? Routes.manualAlert : Routes.packageDetails,
                  ),
                ),
                const SizedBox(height: 8),
                if (main != null)
                  Center(
                    child: Text(
                      '${main.title} · ${Formatters.riyal(main.cost)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                SecondaryButton(
                  label: '＋ إضافة تنبيه يدوي',
                  onPressed: () => context.push(Routes.manualAlert),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.packageTitle,
    required this.isSyncing,
    required this.showSync,
    required this.needsAttention,
    required this.onSync,
  });

  final String? packageTitle;
  final bool isSyncing;
  final bool showSync;
  final bool needsAttention;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'مرحباً 👋',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            Text(
              packageTitle ?? 'لا توجد بيانات',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      if (showSync)
        _IconTile(
          semanticLabel: 'تحديث من رسائل ١١١',
          onTap: isSyncing ? null : onSync,
          child: isSyncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('🔄', style: TextStyle(fontSize: 18)),
        ),
      const SizedBox(width: 8),
      _IconTile(
        semanticLabel: 'التنبيهات',
        onTap: null,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            const Text('🔔', style: TextStyle(fontSize: 19)),
            if (needsAttention)
              Positioned(
                top: -2,
                left: -4,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppColors.orangeMain,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.child,
    required this.onTap,
    required this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: semanticLabel,
    child: Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(width: 44, height: 44, child: Center(child: child)),
      ),
    ),
  );
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onGrant});

  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.smsBannerBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.smsBannerBorder),
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
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('✉️', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'سماح بقراءة رسائل باقتي (١١١)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'اسمَح بقراءة الرسائل لاستعادة تفاصيل باقتك والرصيد المتبقي '
                  'تلقائياً.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onGrant,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.blueMain,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text(
              'السماح',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.orangeBg,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.orangeMain,
              shape: BoxShape.circle,
            ),
            child: const Text(
              '!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: semiBold,
                color: AppColors.orangeTextDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CountdownHero extends StatelessWidget {
  const _CountdownHero({
    required this.remaining,
    required this.isExpired,
    required this.expiry,
  });

  final Duration? remaining;
  final bool isExpired;
  final int? expiry;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.blueBg,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          remaining == null
              ? 'لا توجد باقة نشطة'
              : isExpired
              ? 'انتهت الباقة'
              : 'تنتهي صلاحية باقتك خلال',
          style: const TextStyle(fontSize: 13, color: AppColors.blueTextLight),
        ),
        const SizedBox(height: 14),
        if (remaining == null || isExpired)
          Text(
            remaining == null ? 'غير متصل' : 'منتهية',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: AppColors.blueTextDark,
            ),
          )
        else
          _CountdownParts(remaining: remaining!),
        // The prototype spells the expiry date out under the countdown; the
        // Kotlin dropped it, leaving the user to work backwards from "٥ يوم".
        if (expiry != null && !isExpired) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            '📅 تنتهي: '
            '${Formatters.longDateTime(DateTime.fromMillisecondsSinceEpoch(expiry!))}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.blueTextLight,
            ),
          ),
        ],
      ],
    ),
  );
}

class _CountdownParts extends StatelessWidget {
  const _CountdownParts({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final ({int days, int hours, int minutes}) parts = Formatters.countdown(
      remaining,
    );
    final bool hasDays = parts.days > 0;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (hasDays) ...<Widget>[
            _Part(value: parts.days, unit: 'يوم', large: true),
            const SizedBox(width: 16),
            _Part(value: parts.hours, unit: 'ساعة', large: false),
          ] else ...<Widget>[
            _Part(value: parts.hours, unit: 'ساعة', large: true),
            const SizedBox(width: 16),
            _Part(value: parts.minutes, unit: 'دقيقة', large: false),
          ],
        ],
      ),
    );
  }
}

class _Part extends StatelessWidget {
  const _Part({required this.value, required this.unit, required this.large});

  final int value;
  final String unit;
  final bool large;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: <Widget>[
      Text(
        Formatters.number(value),
        style: TextStyle(
          fontSize: large ? 58 : 34,
          height: 1.1,
          fontWeight: FontWeight.bold,
          color: AppColors.blueTextDark,
        ),
      ),
      const SizedBox(width: 6),
      Text(
        unit,
        style: TextStyle(
          fontSize: large ? 20 : 16,
          fontWeight: FontWeight.w500,
          color: AppColors.blueTextLight,
        ),
      ),
    ],
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: <Widget>[
      Text(
        'الرصيد المتبقّي',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      PillBadge(
        label: 'يُفقد عند الانتهاء',
        background: AppColors.orangeBadgeBg,
        foreground: AppColors.orangeDark,
      ),
    ],
  );
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.package});

  final PackageEvent? package;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: BalanceCard(
            icon: '📞',
            value: Formatters.number(package?.minutes),
            unit: 'دقيقة',
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: BalanceCard(
            icon: '💬',
            value: Formatters.number(package?.sms),
            unit: 'رسالة',
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: BalanceCard(
            icon: '📶',
            value: Formatters.number(package?.megabytes),
            unit: 'ميجابايت',
          ),
        ),
      ],
    ),
  );
}

class _SecondaryPackageCard extends StatelessWidget {
  const _SecondaryPackageCard({required this.event});

  final PackageEvent event;

  @override
  Widget build(BuildContext context) {
    final Duration remaining = DateTime.fromMillisecondsSinceEpoch(
      event.expiryTimestamp!,
    ).difference(DateTime.now());

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Formatters.remainingLabel(remaining),
                style: const TextStyle(fontSize: 12, color: AppColors.blueMain),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: <Widget>[
              Text(
                '📞 ${Formatters.number(event.minutes, fallback: '٠')} دقيقة',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '💬 ${Formatters.number(event.sms, fallback: '٠')} رسالة',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '📶 ${Formatters.number(event.megabytes, fallback: '٠')} ميجا',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
