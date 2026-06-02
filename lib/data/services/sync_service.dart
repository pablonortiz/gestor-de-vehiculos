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
  SyncService() : super(SyncState());

  final _db = DatabaseHelper.instance;
  
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

      // Normalizar shape Supabase → local vía los modelos.
      final data = <String, List<Map<String, dynamic>>>{
        'cities': [for (final d in raw['cities']!) City.fromSupabase(d).toMap()],
        'lugares': [for (final d in raw['lugares']!) Lugar.fromSupabase(d).toMap()],
        'vehicles': [for (final d in raw['vehicles']!) Vehicle.fromSupabase(d).toMap()],
        'vehicle_history': [for (final d in raw['vehicle_history']!) VehicleHistory.fromSupabase(d).toMap()],
        'maintenances': [for (final d in raw['maintenances']!) Maintenance.fromSupabase(d).toMap()],
        'maintenance_invoices': [for (final d in raw['maintenance_invoices']!) MaintenanceInvoice.fromSupabase(d).toMap()],
        'vehicle_notes': [for (final d in raw['vehicle_notes']!) VehicleNote.fromSupabase(d).toMap()],
        'note_photos': [for (final d in raw['note_photos']!) NotePhoto.fromSupabase(d).toMap()],
        'vehicle_photos': [for (final d in raw['vehicle_photos']!) VehiclePhoto.fromSupabase(d).toMap()],
        'document_photos': [for (final d in raw['document_photos']!) DocumentPhoto.fromSupabase(d).toMap()],
        'fuel_charges': [for (final d in raw['fuel_charges']!) FuelCharge.fromSupabase(d).toMap()],
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
          final existing = await client
              .from('cities')
              .select('id')
              .eq('id', city.id!)
              .maybeSingle();

          if (existing == null) {
            await client.from('cities').insert(city.toSupabase());
            debugPrint('✅ [SYNC] Ciudad ${city.name} insertada en Supabase');
          } else {
            await client.from('cities').update(city.toSupabase()).eq('id', city.id!);
            debugPrint('✅ [SYNC] Ciudad ${city.name} actualizada en Supabase');
          }

          await db.update('cities', {'synced': 1}, where: 'id = ?', whereArgs: [city.id]);
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
          final existing = await client
              .from('lugares')
              .select('id')
              .eq('id', lugar.id!)
              .maybeSingle();

          if (existing == null) {
            await client.from('lugares').insert(lugar.toSupabase());
            debugPrint('✅ [SYNC] Lugar ${lugar.name} insertado en Supabase');
          } else {
            await client.from('lugares').update(lugar.toSupabase()).eq('id', lugar.id!);
            debugPrint('✅ [SYNC] Lugar ${lugar.name} actualizado en Supabase');
          }

          await db.update('lugares', {'synced': 1}, where: 'id = ?', whereArgs: [lugar.id]);
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
        
        // Verificar si ya existe en Supabase
        final existing = await client
            .from('vehicles')
            .select('id')
            .eq('id', vehicle.id!)
            .maybeSingle();
        
        if (existing == null) {
          // Insertar nuevo
          await client.from('vehicles').insert(vehicle.toSupabase());
          debugPrint('✅ [SYNC] Vehículo ${vehicle.plate} insertado en Supabase');
        } else {
          // Actualizar existente
          await client.from('vehicles').update(vehicle.toSupabase()).eq('id', vehicle.id!);
          debugPrint('✅ [SYNC] Vehículo ${vehicle.plate} actualizado en Supabase');
        }
        
        // Marcar como sincronizado localmente
        await db.update('vehicles', {'synced': 1}, where: 'id = ?', whereArgs: [vehicle.id]);
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
          final existing = await client
              .from('fuel_charges')
              .select('id')
              .eq('id', fuelCharge.id!)
              .maybeSingle();

          if (existing == null) {
            await client.from('fuel_charges').insert(fuelCharge.toSupabase());
            debugPrint('✅ [SYNC] Carga de combustible insertada en Supabase');
          } else {
            await client.from('fuel_charges').update(fuelCharge.toSupabase()).eq('id', fuelCharge.id!);
            debugPrint('✅ [SYNC] Carga de combustible actualizada en Supabase');
          }

          await db.update('fuel_charges', {'synced': 1}, where: 'id = ?', whereArgs: [fuelCharge.id]);
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
    final queue = await db.query('sync_queue', orderBy: 'created_at ASC');

    for (final item in queue) {
      try {
        final tableName = item['table_name'] as String;
        final operation = item['operation'] as String;
        final data = jsonDecode(item['data'] as String) as Map<String, dynamic>;

        final client = SupabaseConfig.client;

        switch (operation) {
          case 'insert':
            await client.from(tableName).insert(data);
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
        // Incrementar retry count
        final retryCount = (item['retry_count'] as int) + 1;
        if (retryCount >= 5) {
          // Eliminar después de 5 intentos, dejando rastro de la operación
          // descartada (pérdida de dato silenciosa de lo contrario).
          debugPrint(
            '⚠️ [SYNC] Operación descartada tras 5 reintentos: '
            '${item['operation']} ${item['table_name']} #${item['record_id']} — error: $e',
          );
          await db.delete('sync_queue', where: 'id = ?', whereArgs: [item['id']]);
        } else {
          await db.update(
            'sync_queue',
            {'retry_count': retryCount},
            where: 'id = ?',
            whereArgs: [item['id']],
          );
        }
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
}

// Provider para el servicio de sincronización
final syncServiceProvider = StateNotifierProvider<SyncService, SyncState>((ref) {
  return SyncService();
});
