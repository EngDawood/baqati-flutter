import 'package:flutter/material.dart';

import 'package:baqati/theme/app_colors.dart';
import 'package:baqati/theme/app_theme.dart';

/// One choice in a [SegmentedButtonRow].
@immutable
class SegmentOption<T> {
  const SegmentOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// The filled/outlined chip row used for package duration, lead time and alert
/// type.
///
/// PORT-FIX: the Kotlin's equivalent (`TypeButton`) was reimplemented inline on
/// each screen with its own selected-state colors, and the Settings screen's
/// copies were not wired to anything at all.
class SegmentedButtonRow<T> extends StatelessWidget {
  const SegmentedButtonRow({
    required this.options,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      for (int i = 0; i < options.length; i++) ...<Widget>[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: _Segment<T>(
            option: options[i],
            isSelected: options[i].value == selected,
            onTap: () => onChanged(options[i].value),
          ),
        ),
      ],
    ],
  );
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final SegmentOption<T> option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: isSelected,
    child: Material(
      color: isSelected ? AppColors.blueMain : AppColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          // Raises the touch target to the 48dp minimum without changing how
          // the chip looks.
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? null
                : Border.all(color: AppColors.borderColor),
          ),
          child: Text(
            option.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? semiBold : FontWeight.w400,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    ),
  );
}
