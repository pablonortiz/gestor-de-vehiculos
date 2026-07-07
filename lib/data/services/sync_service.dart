import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/supabase_config.dart';
import '../database/database.dart';
import 'db_change_service.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/vehicle_history.dart';
import '../../domain/models/maintenance.dart';
import '../../domain/models/vehicle_note.dart';
import '../../domain/models/vehicle_photo.dart';
import '../../domain/models/document_photo.dart';
import '../../domain/models/city.dart';
import '../../domain/models/lugar.dart';
import '../../domain/models/fuel_charge.dart';

/// Reintentos por ítem de la cola antes de pasarlo a "fallido" (dead-letter).
const kMaxSyncRetries = 5;

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
  offline,
}

class SyncState {
  final SyncStatus status;
  final String? message;
  final DateTime? lastSync;

  SyncState({
    this.status = SyncStatus.idle,
    this.message,
    this.lastSync,
  });

  SyncState copyWith({
    SyncStatus? status,
    String? message,
    DateTime? lastSync,
  }) {
    return SyncState(
      status: status ?? this.status,
      message: message ?? this.message,
      lastSync: lastSync ?? this.lastSync,
    );
  }
}

class SyncService extends StateNotifier<SyncState> {
  SyncService() : super(SyncState()) {
    // Al recuperar conectividad, sincronizar: de lo contrario la cola de
    // pendientes solo se drena al reabrir la app o con pull-to-refresh manual.
    // fullSync tiene su propio guard de re-entrada y chequeo de online.
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) fullSync();
    });
  }

  final _db = DatabaseHelper.instance;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  // Ventana corta para ignorar el "eco" de realtime de nuestras propias
  // escrituras: Supabase emite eventos PostgresChange también por los writes de
  // esta misma app, lo que dispararía un fullSync completo redundante por cada
  // cambio local. No afecta la correctitud: un cambio de OTRO dispositivo que
  // caiga en esta ventana se sincroniza en el siguiente evento o al reabrir.
  DateTime? _suppressEchoUntil;
  bool get shouldSuppressRealtimeEcho =>
      _suppressEchoUntil != null && DateTime.now().isBefore(_suppressEchoUntil!);
  void markSelfWrite() {
    _suppressEchoUntil = DateTime.now().add(const Duration(seconds: 2));
  }


  // Verificar conectividad
  Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  // Sincronización completa desde Supabase
  Future<void> fullSync() async {
    // Guard de re-entrada: fullSync se dispara en initState y en cada cambio
    // realtime de Supabase, por lo que es fácil que se solapen dos corridas.
    // Como borra y reescribe la cache, dos en paralelo la dejarían inconsistente.
    if (state.status == SyncStatus.syncing) {
      debugPrint('⏭️ [SYNC] fullSync ya en curso, se omite esta invocación');
      return;
    }
    debugPrint('🔄 [SYNC] Iniciando fullSync...');

    if (!await isOnline) {
      debugPrint('❌ [SYNC] Sin conexión a internet');
      state = state.copyWith(status: SyncStatus.offline, message: 'Sin conexión');
      return;
    }

    if (!SupabaseConfig.isConfigured) {
      debugPrint('❌ [SYNC] Supabase no configurado');
      state = state.copyWith(status: SyncStatus.error, message: 'Supabase no configurado');
      return;
    }

    state = state.copyWith(status: SyncStatus.syncing, message: 'Sincronizando...');

    try {
      final client = SupabaseConfig.client;

      // PRIMERO: Subir datos locales no sincronizados a Supabase
      debugPrint('📤 [SYNC] Subiendo datos locales no sincronizados...');
      await _uploadUnsyncedData();

      // Procesar cola de sincronización pendiente
      debugPrint('📤 [SYNC] Procesando cola de sincronización...');
      await _processSyncQueue();

      // AHORA: Descargar TODO de Supabase a memoria ANTES de tocar la DB local.
      // Si una query "core" falla, se lanza la excepción y se aborta sin haber
      // modificado la cache (el reemplazo es atómico más abajo).
      debugPrint('📥 [SYNC] Descargando datos de Supabase...');

      Future<List<Map<String, dynamic>>> fetch(String table) async {
        final data = await client.from(table).select();
        return (data as List).cast<Map<String, dynamic>>();
      }
      // Tablas que pueden no existir todavía en algunos entornos: se toleran vacías.
      Future<List<Map<String, dynamic>>> fetchOptional(String table) async {
        try {
          return await fetch(table);
        } catch (e) {
          debugPrint('⚠️ [SYNC] Tabla $table no disponible: $e');
          return const [];
        }
      }

      final raw = <String, List<Map<String, dynamic>>>{
        'cities': await fetchOptional('cities'),
        'lugares': await fetchOptional('lugares'),
        'vehicles': await fetch('vehicles'),
        'vehicle_history': await fetch('vehicle_history'),
        'maintenances': await fetch('maintenances'),
        'maintenance_invoices': await fetch('maintenance_invoices'),
        'vehicle_notes': await fetch('vehicle_notes'),
        'note_photos': await fetch('note_photos'),
        'vehicle_photos': await fetch('vehicle_photos'),
        'document_photos': await fetchOptional('document_photos'),
        'fuel_charges': await fetchOptional('fuel_charges'),
      };
      debugPrint('📥 [SYNC] Recibidos ${raw['vehicles']!.length} vehículos de Supabase');

      // Normalizar shape Supabase → local vía los modelos. Cada fila se parsea
      // de forma aislada: una fila corrupta se descarta (con log) sin abortar la
      // sincronización entera del resto de las tablas.
      final data = <String, List<Map<String, dynamic>>>{
        'cities': _normalizeRows(raw['cities']!, (d) => City.fromSupabase(d).toMap(), 'cities'),
        'lugares': _normalizeRows(raw['lugares']!, (d) => Lugar.fromSupabase(d).toMap(), 'lugares'),
        'vehicles': _normalizeRows(raw['vehicles']!, (d) => Vehicle.fromSupabase(d).toMap(), 'vehicles'),
        'vehicle_history': _normalizeRows(raw['vehicle_history']!, (d) => VehicleHistory.fromSupabase(d).toMap(), 'vehicle_history'),
        'maintenances': _normalizeRows(raw['maintenances']!, (d) => Maintenance.fromSupabase(d).toMap(), 'maintenances'),
        'maintenance_invoices': _normalizeRows(raw['maintenance_invoices']!, (d) => MaintenanceInvoice.fromSupabase(d).toMap(), 'maintenance_invoices'),
        'vehicle_notes': _normalizeRows(raw['vehicle_notes']!, (d) => VehicleNote.fromSupabase(d).toMap(), 'vehicle_notes'),
        'note_photos': _normalizeRows(raw['note_photos']!, (d) => NotePhoto.fromSupabase(d).toMap(), 'note_photos'),
        'vehicle_photos': _normalizeRows(raw['vehicle_photos']!, (d) => VehiclePhoto.fromSupabase(d).toMap(), 'vehicle_photos'),
        'document_photos': _normalizeRows(raw['document_photos']!, (d) => DocumentPhoto.fromSupabase(d).toMap(), 'document_photos'),
        'fuel_charges': _normalizeRows(raw['fuel_charges']!, (d) => FuelCharge.fromSupabase(d).toMap(), 'fuel_charges'),
      };

      // Reemplazo atómico (borra + reinserta en una transacción, sin tocar sync_queue).
      await _db.replaceAllData(data);
      debugPrint('✅ [SYNC] Cache local reemplazada atómicamente');

      // Notify all tables that data may have changed
      DbChangeService.instance.notifyChange('vehicles');
      DbChangeService.instance.notifyChange('vehicle_photos');
      DbChangeService.instance.notifyChange('document_photos');
      DbChangeService.instance.notifyChange('maintenances');
      DbChangeService.instance.notifyChange('maintenance_invoices');
      DbChangeService.instance.notifyChange('vehicle_notes');
      DbChangeService.instance.notifyChange('note_photos');
      DbChangeService.instance.notifyChange('fuel_charges');
      DbChangeService.instance.notifyChange('cities');
      DbChangeService.instance.notifyChange('lugares');

      // Las escrituras que este sync acaba de subir generarán ecos de realtime;
      // los suprimimos para no re-disparar otro fullSync.
      markSelfWrite();

      state = state.copyWith(
        status: SyncStatus.success,
        message: 'Sincronización completa',
        lastSync: DateTime.now(),
      );
    } catch (e, stack) {
      debugPrint('❌ [SYNC] Error en fullSync: $e');
      debugPrint('❌ [SYNC] Stack: $stack');
      state = state.copyWith(
        status: SyncStatus.error,
        message: 'Error: ${e.toString()}',
      );
    }
  }
  
  /// Normaliza filas remotas a shape local tolerando filas corruptas: una fila
  /// que falle al parsear se descarta (con log) en vez de abortar todo el batch.
  List<Map<String, dynamic>> _normalizeRows(
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> Function(Map<String, dynamic>) parse,
    String table,
  ) {
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      try {
        result.add(parse(row));
      } catch (e) {
        debugPrint('⚠️ [SYNC] Fila inválida en $table descartada: $e');
      }
    }
    return result;
  }

  /// Sube un registro pendiente resolviendo el conflicto por updated_at: solo
  /// pisa el remoto si la versión local es estrictamente más nueva. En cualquier
  /// caso marca la fila local como sincronizada (si el remoto era más nuevo, se
  /// baja en la fase de descarga del fullSync).
  Future<void> _pushUnsynced({
    required String table,
    required String id,
    required DateTime localUpdatedAt,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _db.database;
    final client = SupabaseConfig.client;
    final existing =
        await client.from(table).select('id, updated_at').eq('id', id).maybeSingle();
    if (existing == null) {
      await client.from(table).insert(payload);
    } else {
      final remoteUpdatedAt =
          DateTime.tryParse(existing['updated_at']?.toString() ?? '');
      if (remoteUpdatedAt == null || localUpdatedAt.isAfter(remoteUpdatedAt)) {
        await client.from(table).update(payload).eq('id', id);
      }
      // Si el remoto es más nuevo o igual, no lo pisamos: se baja en el fetch.
    }
    await db.update(table, {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  // Subir datos locales no sincronizados
  Future<void> _uploadUnsyncedData() async {
    final db = await _db.database;
    final client = SupabaseConfig.client;

    // Subir ciudades no sincronizadas primero (antes de vehículos por la FK)
    try {
      final unsyncedCities = await db.query('cities', where: 'synced = 0');
      debugPrint('📤 [SYNC] ${unsyncedCities.length} ciudades pendientes de sincronizar');

      for (final map in unsyncedCities) {
        try {
          final city = City.fromMap(map);
          await _pushUnsynced(
            table: 'cities',
            id: city.id!,
            localUpdatedAt: city.updatedAt,
            payload: city.toSupabase(),
          );
          debugPrint('✅ [SYNC] Ciudad ${city.name} sincronizada');
        } catch (e) {
          debugPrint('❌ [SYNC] Error subiendo ciudad: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [SYNC] Tabla cities no existe localmente: $e');
    }

    // Subir lugares no sincronizados
    try {
      final unsyncedLugares = await db.query('lugares', where: 'synced = 0');
      debugPrint('📤 [SYNC] ${unsyncedLugares.length} lugares pendientes de sincronizar');

      for (final map in unsyncedLugares) {
        try {
          final lugar = Lugar.fromMap(map);
          await _pushUnsynced(
            table: 'lugares',
            id: lugar.id!,
            localUpdatedAt: lugar.updatedAt,
            payload: lugar.toSupabase(),
          );
          debugPrint('✅ [SYNC] Lugar ${lugar.name} sincronizado');
        } catch (e) {
          debugPrint('❌ [SYNC] Error subiendo lugar: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [SYNC] Tabla lugares no existe localmente: $e');
    }

    // Subir vehículos no sincronizados
    final unsyncedVehicles = await db.query('vehicles', where: 'synced = 0');
    debugPrint('📤 [SYNC] ${unsyncedVehicles.length} vehículos pendientes de sincronizar');
    
    for (final map in unsyncedVehicles) {
      try {
        final vehicle = Vehicle.fromMap(map);
        debugPrint('📤 [SYNC] Subiendo vehículo: ${vehicle.plate}');
        await _pushUnsynced(
          table: 'vehicles',
          id: vehicle.id!,
          localUpdatedAt: vehicle.updatedAt,
          payload: vehicle.toSupabase(),
        );
        debugPrint('✅ [SYNC] Vehículo ${vehicle.plate} sincronizado');
      } catch (e) {
        debugPrint('❌ [SYNC] Error subiendo vehículo: $e');
      }
    }
    
    // Subir historial no sincronizado
    final unsyncedHistory = await db.query('vehicle_history', where: 'synced = 0');
    for (final map in unsyncedHistory) {
      try {
        final history = VehicleHistory.fromMap(map);
        final existing = await client
            .from('vehicle_history')
            .select('id')
            .eq('id', history.id!)
            .maybeSingle();

        if (existing == null) {
          await client.from('vehicle_history').insert(history.toSupabase());
        }
        await db.update('vehicle_history', {'synced': 1}, where: 'id = ?', whereArgs: [history.id]);
      } catch (e) {
        debugPrint('❌ [SYNC] Error subiendo historial: $e');
      }
    }

    // Subir cargas de combustible no sincronizadas
    try {
      final unsyncedFuelCharges = await db.query('fuel_charges', where: 'synced = 0');
      debugPrint('📤 [SYNC] ${unsyncedFuelCharges.length} cargas de combustible pendientes de sincronizar');

      for (final map in unsyncedFuelCharges) {
        try {
          final fuelCharge = FuelCharge.fromMap(map);
          await _pushUnsynced(
            table: 'fuel_charges',
            id: fuelCharge.id!,
            localUpdatedAt: fuelCharge.updatedAt,
            payload: fuelCharge.toSupabase(),
          );
          debugPrint('✅ [SYNC] Carga de combustible sincronizada');
        } catch (e) {
          debugPrint('❌ [SYNC] Error subiendo carga de combustible: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [SYNC] Tabla fuel_charges no existe localmente: $e');
    }
  }

  // Lock para serializar el procesamiento de la cola: addToSyncQueue puede
  // dispararlo desde varios repos casi a la vez, y dos pasadas concurrentes
  // sobre la misma cola intentarían procesar/borrar los mismos items.
  bool _isProcessingQueue = false;

  // Procesar cola de sincronización pendiente
  Future<void> _processSyncQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;
    try {
      await _drainSyncQueue();
    } finally {
      _isProcessingQueue = false;
    }
  }

  Future<void> _drainSyncQueue() async {
    final db = await _db.database;
    // Los que agotaron reintentos quedan como dead-letter (visibles en
    // Ajustes, reintentables a mano) en vez de descartarse.
    final queue = await db.query(
      'sync_queue',
      where: 'retry_count < ?',
      whereArgs: [kMaxSyncRetries],
      orderBy: 'created_at ASC',
    );

    for (final item in queue) {
      try {
        final tableName = item['table_name'] as String;
        final operation = item['operation'] as String;
        final data = jsonDecode(item['data'] as String) as Map<String, dynamic>;

        final client = SupabaseConfig.client;

        switch (operation) {
          case 'insert':
            // upsert (no insert) para que el reintento sea idempotente: si el
            // registro ya existe en Supabase (ej. el insert original tuvo éxito
            // parcial antes de encolarse), no viola la PK.
            await client.from(tableName).upsert(data);
            break;
          case 'update':
            final id = item['record_id'] as String;
            await client.from(tableName).update(data).eq('id', id);
            break;
          case 'delete':
            final id = item['record_id'] as String;
            await client.from(tableName).delete().eq('id', id);
            break;
        }

        // Eliminar de la cola si fue exitoso
        await db.delete('sync_queue', where: 'id = ?', whereArgs: [item['id']]);
      } catch (e) {
        final retryCount = (item['retry_count'] as int) + 1;
        if (retryCount >= kMaxSyncRetries) {
          debugPrint(
            '⚠️ [SYNC] Operación pasa a fallida tras $kMaxSyncRetries reintentos: '
            '${item['operation']} ${item['table_name']} #${item['record_id']} — error: $e',
          );
        }
        await db.update(
          'sync_queue',
          {'retry_count': retryCount},
          where: 'id = ?',
          whereArgs: [item['id']],
        );
      }
    }
  }

  // Agregar operación a la cola de sincronización
  Future<void> addToSyncQueue({
    required String tableName,
    required String recordId,
    required String operation,
    required Map<String, dynamic> data,
  }) async {
    final db = await _db.database;
    await db.insert('sync_queue', {
      'table_name': tableName,
      'record_id': recordId,
      'operation': operation,
      'data': jsonEncode(data),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    // Intentar sincronizar si está online
    if (await isOnline && SupabaseConfig.isConfigured) {
      await _processSyncQueue();
    }
  }

  /// Reencola los ítems fallidos (dead-letter) y dispara un sync.
  Future<void> retryFailedItems() async {
    final db = await _db.database;
    await db.update(
      'sync_queue',
      {'retry_count': 0},
      where: 'retry_count >= ?',
      whereArgs: [kMaxSyncRetries],
    );
    await fullSync();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}

/// Conteos de la cola de sincronización para mostrar en Ajustes.
class SyncQueueCounts {
  final int pending;
  final int failed;

  const SyncQueueCounts({required this.pending, required this.failed});

  bool get isEmpty => pending == 0 && failed == 0;
}

final syncQueueCountsProvider =
    FutureProvider.autoDispose<SyncQueueCounts>((ref) async {
  // Refrescar cada vez que cambia el estado de sync.
  ref.watch(syncServiceProvider);
  final db = await DatabaseHelper.instance.database;
  final rows = await db.rawQuery(
    'SELECT '
    'SUM(CASE WHEN retry_count < $kMaxSyncRetries THEN 1 ELSE 0 END) AS pending, '
    'SUM(CASE WHEN retry_count >= $kMaxSyncRetries THEN 1 ELSE 0 END) AS failed '
    'FROM sync_queue',
  );
  final row = rows.first;
  return SyncQueueCounts(
    pending: (row['pending'] as int?) ?? 0,
    failed: (row['failed'] as int?) ?? 0,
  );
});

// Provider para el servicio de sincronización
final syncServiceProvider = StateNotifierProvider<SyncService, SyncState>((ref) {
  return SyncService();
});
