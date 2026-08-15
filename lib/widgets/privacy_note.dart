import 'package:flutter/material.dart';

import 'package:baqati/theme/app_colors.dart';

/// The offline-processing reassurance shown on onboarding and in Settings.
class PrivacyNote extends StatelessWidget {
  const PrivacyNote({required this.message, super.key});

  const PrivacyNote.onboarding({super.key})
    : message = 'تتم المعالجة على جهازك فقط — لا تُرسل أي بيانات لأي خادم.';

  const PrivacyNote.settings({super.key})
    : message = 'تعمل جميع العمليات محلياً على جهازك دون أي اتصال بالإنترنت.';

  final String message;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.privacyNoteBg,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      child: Row(
        children: <Widget>[
          const Text('🔒', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.privacyNoteText,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
