import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A box with a spinner and a short message, shown while the AI is working (it can take up to a minute).
class AiWorkingBox extends StatelessWidget {
  const AiWorkingBox({super.key, this.title = 'AI is working...', this.message = 'This can take up to a minute.'});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.primaryGreen),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

/// A pop-up the person cannot dismiss. Close it with `Navigator.of(context, rootNavigator: true).pop()`.
void showAiWorkingDialog(BuildContext context, String title, String message) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AiWorkingBox(title: title, message: message),
        ),
      ),
    ),
  );
}
