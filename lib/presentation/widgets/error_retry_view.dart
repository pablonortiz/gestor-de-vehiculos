import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Estado de error amigable con botón de reintento. Reemplaza los `Text('Error: $e')`
/// crudos en pantallas que cargan datos async: en vez de mostrar la excepción
/// técnica, da un mensaje claro y una acción para volver a intentar.
class ErrorRetryView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorRetryView({
    super.key,
    this.message = 'No se pudieron cargar los datos',
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
