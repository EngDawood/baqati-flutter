import 'package:flutter/material.dart';

import 'package:baqati/models/event_type.dart';
import 'package:baqati/models/package_event.dart';
import 'package:baqati/theme/app_colors.dart';
import 'package:baqati/theme/app_theme.dart';
import 'package:baqati/utils/formatters.dart';
import 'package:baqati/viewmodels/package_view_model.dart';
import 'package:baqati/widgets/app_card.dart';
import 'package:baqati/widgets/empty_state.dart';
import 'package:baqati/widgets/pill_badge.dart';
import 'package:baqati/widgets/screen_app_bar.dart';

/// How one [EventType] is presented in the list.
@immutable
class _TypeStyle {
  const _TypeStyle({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String icon;
  final String label;
  final Color background;
  final Color foreground;

  /// PORT-FIX: `HistoryScreen.kt:73` mapped only four types and would not
  /// compile against this port's five — [EventType.manual] exists here so that
  /// hand-entered reminders stop masking real carrier activations.
  static const Map<EventType, _TypeStyle> byType = <EventType, _TypeStyle>{
    EventType.balanceCheck: _TypeStyle(
      icon: '📊',
      label: 'رصيد',
      background: AppColors.orangeBadgeBg,
      foreground: AppColors.orangeDark,
    ),
    EventType.activation: _TypeStyle(
      icon: '🎁',
      label: 'تفعيل',
      background: AppColors.blueBg,
      foreground: AppColors.blueMain,
    ),
    EventType.deduction: _TypeStyle(
      icon: '🧾',
      label: 'خصم',
      background: AppColors.greenBg,
      foreground: AppColors.greenMain,
    ),
    EventType.payment: _TypeStyle(
      icon: '💰',
      label: 'دفع',
      background: AppColors.greenBg,
      foreground: AppColors.greenMain,
    ),
    EventType.manual: _TypeStyle(
      icon: '⏰',
      label: 'يدوي',
      background: AppColors.blueBg,
      foreground: AppColors.blueTextLight,
    ),
  };
}

/// Every stored event, newest first, filterable by type.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({required this.packages, super.key});

  final PackageViewModel packages;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  /// null means "الكل".
  EventType? _filter;

  static const List<(EventType?, String)> _filters = <(EventType?, String)>[
    (null, 'الكل'),
    (EventType.activation, 'تفعيل'),
    (EventType.balanceCheck, 'رصيد'),
    (EventType.payment, 'دفع'),
    (EventType.deduction, 'خصم'),
    (EventType.manual, 'يدوي'),
  ];

  Future<void> _confirmDelete(PackageEvent event) async {
    final int? id = event.id;
    if (id == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('حذف الحدث'),
        content: Text('سيُحذف "${event.title}" مع أي تنبيه مرتبط به.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) await widget.packages.deleteEvent(id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: widget.packages,
        builder: (BuildContext context, Widget? child) {
          final List<PackageEvent> events = widget.packages.eventsOfType(
            _filter,
          );
          final bool hasAnyEvents = widget.packages.events.isNotEmpty;

          return Column(
            children: <Widget>[
              const ScreenAppBar(title: 'السجل'),
              _FilterBar(
                selected: _filter,
                filters: _filters,
                onChanged: (EventType? type) => setState(() => _filter = type),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: events.isEmpty
                    // PORT-FIX: `HistoryScreen.kt:65` rendered four hardcoded
                    // mock cards whenever the database was empty, so a new user
                    // saw a history of events that never happened and could not
                    // be deleted — no row backed them.
                    ? EmptyState(
                        icon: hasAnyEvents ? '🔍' : '🗂️',
                        title: hasAnyEvents
                            ? 'لا نتائج لهذا التصنيف'
                            : 'لا يوجد سجل بعد',
                        message: hasAnyEvents
                            ? 'جرّب تصنيفاً آخر لعرض بقية الأحداث.'
                            : 'ستظهر هنا رسائل ١١١ بعد تحليلها، وأي تنبيه '
                                  'تضيفه يدوياً.',
                      )
                    // PORT-FIX: the Kotlin laid the cards out in a plain
                    // non-scrolling Column, so everything past the first
                    // screenful overflowed and was unreachable.
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                        itemCount: events.length,
                        separatorBuilder: (BuildContext _, int _) =>
                            const SizedBox(height: 11),
                        itemBuilder: (BuildContext context, int index) =>
                            _HistoryCard(
                              event: events[index],
                              onLongPress: () => _confirmDelete(events[index]),
                            ),
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.filters,
    required this.onChanged,
  });

  final EventType? selected;
  final List<(EventType?, String)> filters;
  final ValueChanged<EventType?> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      itemCount: filters.length,
      separatorBuilder: (BuildContext _, int _) => const SizedBox(width: 8),
      itemBuilder: (BuildContext context, int index) {
        final (EventType? type, String label) = filters[index];
        final bool isSelected = type == selected;

        // PORT-FIX: the Kotlin's chips took their selected state from a
        // literal (`FilterChip("تفعيل", false)`) and had no tap handler at
        // all — the row looked interactive but filtered nothing.
        return Center(
          child: Semantics(
            button: true,
            selected: isSelected,
            child: Material(
              color: isSelected ? AppColors.blueMain : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => onChanged(type),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? semiBold : FontWeight.w400,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.event, required this.onLongPress});

  final PackageEvent event;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final _TypeStyle style = _TypeStyle.byType[event.type]!;

    return GestureDetector(
      onLongPress: onLongPress,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: style.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(style.icon, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
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
                        // PORT-FIX: the Kotlin passed the literal "قبل قليل"
                        // for every row, so a month-old backfilled event and a
                        // just-received one looked identical.
                        Formatters.relativeTime(
                          DateTime.fromMillisecondsSinceEpoch(event.timestamp),
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textQuaternary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    event.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 7),
                  PillBadge(
                    label: style.label,
                    background: style.background,
                    foreground: style.foreground,
                    fontSize: 10,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
