import 'package:flutter/material.dart';

/// Shows a simple Yes / No confirmation dialog. Returns true only if the user
/// taps the confirm button. Used to confirm printing (bills and reports).
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Yes',
  String cancelLabel = 'No',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
