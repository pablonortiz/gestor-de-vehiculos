import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../services/sync_service.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/vehicle_history.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class VehicleRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();
  SyncService? _syncService;

  void setSyncService(SyncService syncService) {
    _syncService = syncService;
  }

  Future<bool> get _isOnline async {
    final result = await Connectivity().checkConnectivity();
    final isOnline = result != ConnectivityResult.none && SupabaseConfig.isConfigured;
    debugPrint('🌐 [REPO] isOnline: $isOnline (connectivity: $result, configured: ${SupabaseConfig.isConfigured})');
    return isOnline;
  }

  Future<List<Vehicle>> getAllVehicles() async {
    final db = await _dbHelper.database;
    final maps = await db.query('vehicles', orderBy: 'updated_at DESC');
    return maps.map((map) => Vehicle.fromMap(map)).toList();
  }

  Future<List<Vehicle>> getVehiclesByProvince(int provinceId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'vehicles',
      where: 'province_id = ?',
      whereArgs: [provinceId],
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => Vehicle.fromMap(map)).toList();
  }

  Future<List<Vehicle>> getVehiclesByStatus(int statusIndex) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'vehicles',
      where: 'status = ?',
      whereArgs: [statusIndex],
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => Vehicle.fromMap(map)).toList();
  }

  Future<Vehicle?> getVehicleById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'vehicles',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Vehicle.fromMap(maps.first);
  }

  Future<Vehicle?> getVehicleByPlate(String plate) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'vehicles',
      where: 'plate = ?',
      whereArgs: [plate.toUpperCase()],
    );
    if (maps.isEmpty) return null;
    return Vehicle.fromMap(maps.first);
  }

  Future<String> insertVehicle(Vehicle vehicle) async {
    debugPrint('🚗 [REPO] Insertando vehículo: ${vehicle.plate}');
    
    final db = await _dbHelper.database;
    final id = _uuid.v4();
    final newVehicle = vehicle.copyWith(id: id);
    
    final map = newVehicle.toMap();
    map['plate'] = (map['plate'] as String).toUpperCase();
    map['synced'] = 0;
    
    await db.insert('vehicles', map);
    debugPrint('✅ [REPO] Vehículo guardado localmente con ID: $id');
    
    // Registrar en historial como creación
    final historyId = _uuid.v4();
    await _insertHistory(VehicleHistory(
      id: historyId,
      vehicleId: id,
      field: 'created',
      oldValue: '',
      newValue: 'Vehículo creado',
    ));
    
    // Sincronizar con Supabase
    if (await _isOnline) {
      try {
        debugPrint('📤 [REPO] Intentando subir a Supabase...');
        debugPrint('📤 [REPO] Datos: ${newVehicle.toSupabase()}');
        
        await SupabaseConfig.client.from('vehicles').insert(newVehicle.toSupabase());
        debugPrint('✅ [REPO] Vehículo subido a Supabase exitosamente');
        
        await SupabaseConfig.client.from('vehicle_history').insert({
          'id': historyId,
          'vehicle_id': id,
          'field': 'created',
          'old_value': '',
          'new_value': 'Vehículo creado',
        });
        await db.update('vehicles', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
        debugPrint('✅ [REPO] Marcado como sincronizado');
      } catch (e, stack) {
        debugPrint('❌ [REPO] Error subiendo a Supabase: $e');
        debugPrint('❌ [REPO] Stack: $stack');
        // Agregar a cola de sincronización
        _syncService?.addToSyncQueue(
          tableName: 'vehicles',
          recordId: id,
          operation: 'insert',
          data: newVehicle.toSupabase(),
        );
      }
    } else {
      debugPrint('📴 [REPO] Sin conexión, agregando a cola de sync');
      _syncService?.addToSyncQueue(
        tableName: 'vehicles',
        recordId: id,
        operation: 'insert',
        data: newVehicle.toSupabase(),
      );
    }
    
    return id;
  }

  Future<int> updateVehicle(Vehicle vehicle) async {
    if (vehicle.id == null) throw Exception('Vehicle ID is required');
    
    final db = await _dbHelper.database;
    
    // Obtener vehículo anterior para comparar cambios
    final oldVehicle = await getVehicleById(vehicle.id!);
    
    final updatedVehicle = vehicle.copyWith(updatedAt: DateTime.now());
    final map = updatedVehicle.toMap();
    map['plate'] = (map['plate'] as String).toUpperCase();
    map['synced'] = 0;
    
    final result = await db.update(
      'vehicles',
      map,
      where: 'id = ?',
      whereArgs: [vehicle.id],
    );
    
    // Registrar cambios en historial
    if (oldVehicle != null) {
      await _recordChanges(oldVehicle, updatedVehicle);
    }
    
    // Sincronizar con Supabase
    if (await _isOnline) {
      try {
        await SupabaseConfig.client
            .from('vehicles')
            .update(updatedVehicle.toSupabase())
            .eq('id', vehicle.id!);
        await db.update('vehicles', {'synced': 1}, where: 'id = ?', whereArgs: [vehicle.id]);
      } catch (e) {
        _syncService?.addToSyncQueue(
          tableName: 'vehicles',
          recordId: vehicle.id!,
          operation: 'update',
          data: updatedVehicle.toSupabase(),
        );
      }
    } else {
      _syncService?.addToSyncQueue(
        tableName: 'vehicles',
        recordId: vehicle.id!,
        operation: 'update',
        data: updatedVehicle.toSupabase(),
      );
    }
    
    return result;
  }

  Future<int> deleteVehicle(String id) async {
    final db = await _dbHelper.database;
    
    // Eliminar localmente
    await db.delete('vehicle_history', where: 'vehicle_id = ?', whereArgs: [id]);
    await db.delete('maintenances', where: 'vehicle_id = ?', whereArgs: [id]);
    await db.delete('vehicle_notes', where: 'vehicle_id = ?', whereArgs: [id]);
    await db.delete('vehicle_photos', where: 'vehicle_id = ?', whereArgs: [id]);
    
    final result = await db.delete('vehicles', where: 'id = ?', whereArgs: [id]);
    
    // Sincronizar con Supabase
    if (await _isOnline) {
      try {
        await SupabaseConfig.client.from('vehicles').delete().eq('id', id);
      } catch (e) {
        _syncService?.addToSyncQueue(
          tableName: 'vehicles',
          recordId: id,
          operation: 'delete',
          data: {},
        );
      }
    } else {
      _syncService?.addToSyncQueue(
        tableName: 'vehicles',
        recordId: id,
        operation: 'delete',
        data: {},
      );
    }
    
    return result;
  }

  Future<List<Vehicle>> searchVehicles(String query) async {
    final db = await _dbHelper.database;
    final searchQuery = '%${query.toLowerCase()}%';
    
    final maps = await db.rawQuery('''
      SELECT * FROM vehicles 
      WHERE LOWER(plate) LIKE ? 
         OR LOWER(brand) LIKE ? 
         OR LOWER(model) LIKE ? 
         OR LOWER(responsible_name) LIKE ?
         OR LOWER(city) LIKE ?
      ORDER BY updated_at DESC
    ''', [searchQuery, searchQuery, searchQuery, searchQuery, searchQuery]);
    
    return maps.map((map) => Vehicle.fromMap(map)).toList();
  }

  Future<Map<int, int>> getVehicleCountByProvince() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT province_id, COUNT(*) as count 
      FROM vehicles 
      GROUP BY province_id
    ''');
    
    return {
      for (var row in result)
        row['province_id'] as int: row['count'] as int
    };
  }

  Future<int> getTotalVehicleCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM vehicles');
    return result.first['count'] as int;
  }

  Future<List<Vehicle>> getVehiclesWithExpiringDocuments() async {
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final thirtyDaysLater = DateTime.now()
        .add(const Duration(days: 30))
        .millisecondsSinceEpoch;
    
    final maps = await db.rawQuery('''
      SELECT * FROM vehicles 
      WHERE (vtv_expiry IS NOT NULL AND vtv_expiry BETWEEN ? AND ?)
         OR (insurance_expiry IS NOT NULL AND insurance_expiry BETWEEN ? AND ?)
         OR (vtv_expiry IS NOT NULL AND vtv_expiry < ?)
         OR (insurance_expiry IS NOT NULL AND insurance_expiry < ?)
      ORDER BY vtv_expiry ASC, insurance_expiry ASC
    ''', [now, thirtyDaysLater, now, thirtyDaysLater, now, now]);
    
    return maps.map((map) => Vehicle.fromMap(map)).toList();
  }

  // Historial
  Future<void> _insertHistory(VehicleHistory history) async {
    final db = await _dbHelper.database;
    final map = history.toMap();
    map['synced'] = 0;
    await db.insert('vehicle_history', map);
    
    // Sincronizar con Supabase
    if (await _isOnline) {
      try {
        await SupabaseConfig.client.from('vehicle_history').insert(history.toSupabase());
        await db.update('vehicle_history', {'synced': 1}, where: 'id = ?', whereArgs: [history.id]);
      } catch (e) {
        // Se sincronizará después
      }
    }
  }

  Future<void> _recordChanges(Vehicle oldVehicle, Vehicle newVehicle) async {
    final changes = <VehicleHistory>[];
    
    if (oldVehicle.plate != newVehicle.plate) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'plate',
        oldValue: oldVehicle.plate,
        newValue: newVehicle.plate,
      ));
    }
    
    if (oldVehicle.type != newVehicle.type) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'type',
        oldValue: oldVehicle.type.label,
        newValue: newVehicle.type.label,
      ));
    }
    
    if (oldVehicle.brand != newVehicle.brand) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'brand',
        oldValue: oldVehicle.brand,
        newValue: newVehicle.brand,
      ));
    }
    
    if (oldVehicle.model != newVehicle.model) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'model',
        oldValue: oldVehicle.model,
        newValue: newVehicle.model,
      ));
    }
    
    if (oldVehicle.year != newVehicle.year) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'year',
        oldValue: oldVehicle.year.toString(),
        newValue: newVehicle.year.toString(),
      ));
    }
    
    if (oldVehicle.color.toARGB32() != newVehicle.color.toARGB32()) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'color',
        oldValue: oldVehicle.color.toARGB32().toString(),
        newValue: newVehicle.color.toARGB32().toString(),
      ));
    }
    
    if (oldVehicle.km != newVehicle.km) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'km',
        oldValue: oldVehicle.km.toString(),
        newValue: newVehicle.km.toString(),
      ));
    }
    
    if (oldVehicle.status != newVehicle.status) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'status',
        oldValue: oldVehicle.status.label,
        newValue: newVehicle.status.label,
      ));
    }
    
    if (oldVehicle.provinceId != newVehicle.provinceId) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'provinceId',
        oldValue: oldVehicle.provinceId.toString(),
        newValue: newVehicle.provinceId.toString(),
      ));
    }
    
    if (oldVehicle.city != newVehicle.city) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'city',
        oldValue: oldVehicle.city,
        newValue: newVehicle.city,
      ));
    }
    
    if (oldVehicle.responsibleName != newVehicle.responsibleName) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'responsibleName',
        oldValue: oldVehicle.responsibleName,
        newValue: newVehicle.responsibleName,
      ));
    }
    
    if (oldVehicle.responsiblePhone != newVehicle.responsiblePhone) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'responsiblePhone',
        oldValue: oldVehicle.responsiblePhone,
        newValue: newVehicle.responsiblePhone,
      ));
    }
    
    if (oldVehicle.vtvExpiry?.toIso8601String() != newVehicle.vtvExpiry?.toIso8601String()) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'vtvExpiry',
        oldValue: oldVehicle.vtvExpiry?.toIso8601String() ?? 'Sin fecha',
        newValue: newVehicle.vtvExpiry?.toIso8601String() ?? 'Sin fecha',
      ));
    }
    
    if (oldVehicle.insuranceCompany != newVehicle.insuranceCompany) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'insuranceCompany',
        oldValue: oldVehicle.insuranceCompany ?? 'Sin compañía',
        newValue: newVehicle.insuranceCompany ?? 'Sin compañía',
      ));
    }
    
    if (oldVehicle.insuranceExpiry?.toIso8601String() != newVehicle.insuranceExpiry?.toIso8601String()) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'insuranceExpiry',
        oldValue: oldVehicle.insuranceExpiry?.toIso8601String() ?? 'Sin fecha',
        newValue: newVehicle.insuranceExpiry?.toIso8601String() ?? 'Sin fecha',
      ));
    }
    
    if (oldVehicle.fuelType != newVehicle.fuelType) {
      changes.add(VehicleHistory(
        id: _uuid.v4(),
        vehicleId: newVehicle.id!,
        field: 'fuelType',
        oldValue: oldVehicle.fuelType.label,
        newValue: newVehicle.fuelType.label,
      ));
    }
    
    for (final change in changes) {
      await _insertHistory(change);
    }
  }

  Future<List<VehicleHistory>> getVehicleHistory(String vehicleId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'vehicle_history',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'changed_at DESC',
    );
    return maps.map((map) => VehicleHistory.fromMap(map)).toList();
  }

  Future<List<VehicleHistory>> getAllHistory() async {
    final db = await _dbHelper.database;
    final maps = await db.query('vehicle_history', orderBy: 'changed_at DESC');
    return maps.map((map) => VehicleHistory.fromMap(map)).toList();
  }
}
