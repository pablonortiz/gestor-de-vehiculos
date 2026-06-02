import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/sync_service.dart';
import '../../core/config/supabase_config.dart';

/// Mixin que centraliza el patrón online/offline + cola de sincronización
/// compartido por todos los repositorios.
///
/// Cada repo debe exponer su [SyncService] vía [syncService] y, tras escribir
/// localmente en sqflite, delegar la propagación remota en [pushWrite].
mixin SyncableRepository {
  /// El [SyncService] del repo (típicamente su `_syncService`). Puede ser null
  /// si todavía no fue inyectado.
  SyncService? get syncService;

  /// `true` si hay conectividad y Supabase está configurado.
  Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    final online = result != ConnectivityResult.none && SupabaseConfig.isConfigured;
    debugPrint('🌐 [REPO] isOnline: $online (connectivity: $result, configured: ${SupabaseConfig.isConfigured})');
    return online;
  }

  /// Propaga una escritura local hacia Supabase.
  ///
  /// Si [isOnline]: ejecuta [remoteOp] y, si tiene éxito, [markSynced]. Si falla,
  /// cae a la cola de sincronización. Si está offline, encola directamente.
  ///
  /// El insert/update local en sqflite debe ocurrir ANTES de llamar a este helper.
  Future<void> pushWrite({
    required String table,
    required String recordId,
    required String operation,
    required Map<String, dynamic> data,
    required Future<void> Function() remoteOp,
    Future<void> Function()? markSynced,
  }) async {
    if (await isOnline) {
      try {
        await remoteOp();
        await markSynced?.call();
        return;
      } catch (e) {
        debugPrint('❌ [REPO] Error sincronizando $table/$recordId ($operation): $e');
      }
    }

    await syncService?.addToSyncQueue(
      tableName: table,
      recordId: recordId,
      operation: operation,
      data: data,
    );
  }
}
