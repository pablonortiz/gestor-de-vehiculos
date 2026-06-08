import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../providers/connectivity_provider.dart';

/// Envuelve la app entera y muestra una barra de "sin conexión" superpuesta
/// arriba cuando se pierde conectividad. Al estar en MaterialApp.builder cubre
/// todas las pantallas (shell, formularios y sheets), no solo el home.
class OfflineBanner extends ConsumerWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Por defecto asumimos online (mientras resuelve) para no parpadear el banner.
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;

    return Stack(
      children: [
        child,
        if (!online)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Material(
                color: AppTheme.warning,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 16, color: Colors.white),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Sin conexión — los cambios se guardan y se sincronizan después',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
