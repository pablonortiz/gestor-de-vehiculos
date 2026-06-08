import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Diálogo de confirmación para acciones destructivas (borrados). Devuelve true
/// solo si el usuario confirma. Unifica el patrón de toda la app.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Eliminar',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel, style: const TextStyle(color: AppTheme.error)),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
