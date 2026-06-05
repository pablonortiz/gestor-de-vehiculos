import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../services/db_change_service.dart';
import '../services/sync_service.dart';
import '../../core/config/supabase_config.dart';
import '../../domain/models/maintenance.dart';
import 'syncable_repository.dart';

class MaintenanceRepository with SyncableRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();
  SyncService? _syncService;

  void setSyncService(SyncService syncService) {
    _syncService = syncService;
  }

  @override
  SyncService? get syncService => _syncService;

  // Todos los mantenimientos (para el dashboard de gastos; sin sus facturas,
  // que no hacen falta para el costo).
  Future<List<Maintenance>> getAllMaintenances() async {
    final db = await _dbHelper.database;
    final maps = await db.query('maintenances', orderBy: 'date DESC');
    return maps.map((map) => Maintenance.fromMap(map)).toList();
  }

  // Obtener mantenimientos de un vehículo
  Future<List<Maintenance>> getMaintenancesByVehicle(String vehicleId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'maintenances',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date DESC',
    );
    if (maps.isEmpty) return [];

    // Traer todas las facturas en una sola query (evita N+1) y agrupar por mantenimiento.
    final ids = maps.map((m) => m['id'] as String).toList();
    final placeholders = List.filled(ids.length, '?').join(', ');
    final invoiceMaps = await db.query(
      'maintenance_invoices',
      where: 'maintenance_id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'created_at DESC',
    );
    final invoicesByMaintenance = <String, List<MaintenanceInvoice>>{};
    for (final m in invoiceMaps) {
      (invoicesByMaintenance[m['maintenance_id'] as String] ??= [])
          .add(MaintenanceInvoice.fromMap(m));
    }

    return maps
        .map((map) => Maintenance.fromMap(map).copyWith(
              invoices: invoicesByMaintenance[map['id'] as String] ?? const [],
            ))
        .toList();
  }

  // Obtener un mantenimiento por ID
  Future<Maintenance?> getMaintenanceById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'maintenances',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    
    final invoices = await getInvoicesByMaintenance(id);
    return Maintenance.fromMap(maps.first).copyWith(invoices: invoices);
  }

  // Insertar mantenimiento
  Future<String> insertMaintenance(Maintenance maintenance) async {
    final db = await _dbHelper.database;
    final id = _uuid.v4();
    final newMaintenance = maintenance.copyWith(id: id);
    
    final map = newMaintenance.toMap();
    map['synced'] = 0;
    
    await db.insert('maintenances', map);
    
    // Sincronizar con Supabase
    await pushWrite(
      table: 'maintenances',
      recordId: id,
      operation: 'insert',
      data: newMaintenance.toSupabase(),
      remoteOp: () async {
        await SupabaseConfig.client.from('maintenances').insert(newMaintenance.toSupabase());
      },
      markSynced: () async {
        await db.update('maintenances', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
      },
    );

    DbChangeService.instance.notifyChange('maintenances');
    return id;
  }

  // Actualizar mantenimiento
  Future<int> updateMaintenance(Maintenance maintenance) async {
    if (maintenance.id == null) throw Exception('Maintenance ID is required');
    
    final db = await _dbHelper.database;
    final updatedMaintenance = maintenance.copyWith(updatedAt: DateTime.now());
    final map = updatedMaintenance.toMap();
    map['synced'] = 0;
    
    final result = await db.update(
      'maintenances',
      map,
      where: 'id = ?',
      whereArgs: [maintenance.id],
    );
    
    // Sincronizar con Supabase
    await pushWrite(
      table: 'maintenances',
      recordId: maintenance.id!,
      operation: 'update',
      data: updatedMaintenance.toSupabase(),
      remoteOp: () async {
        await SupabaseConfig.client
            .from('maintenances')
            .update(updatedMaintenance.toSupabase())
            .eq('id', maintenance.id!);
      },
      markSynced: () async {
        await db.update('maintenances', {'synced': 1}, where: 'id = ?', whereArgs: [maintenance.id]);
      },
    );

    DbChangeService.instance.notifyChange('maintenances');
    return result;
  }

  // Eliminar mantenimiento
  Future<int> deleteMaintenance(String id) async {
    final db = await _dbHelper.database;
    
    // Eliminar facturas primero
    await db.delete('maintenance_invoices', where: 'maintenance_id = ?', whereArgs: [id]);
    
    final result = await db.delete('maintenances', where: 'id = ?', whereArgs: [id]);

    // Sincronizar con Supabase
    await pushWrite(
      table: 'maintenances',
      recordId: id,
      operation: 'delete',
      data: {},
      remoteOp: () async {
        await SupabaseConfig.client.from('maintenances').delete().eq('id', id);
      },
    );

    DbChangeService.instance.notifyChange('maintenances');
    DbChangeService.instance.notifyChange('maintenance_invoices');
    return result;
  }

  // Facturas de mantenimiento
  Future<List<MaintenanceInvoice>> getInvoicesByMaintenance(String maintenanceId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'maintenance_invoices',
      where: 'maintenance_id = ?',
      whereArgs: [maintenanceId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => MaintenanceInvoice.fromMap(map)).toList();
  }

  Future<String> insertInvoice(MaintenanceInvoice invoice) async {
    final db = await _dbHelper.database;
    final id = _uuid.v4();
    final newInvoice = MaintenanceInvoice(
      id: id,
      maintenanceId: invoice.maintenanceId,
      cloudinaryUrl: invoice.cloudinaryUrl,
      cloudinaryPublicId: invoice.cloudinaryPublicId,
      fileType: invoice.fileType,
      fileName: invoice.fileName,
    );
    
    final map = newInvoice.toMap();
    map['synced'] = 0;
    
    await db.insert('maintenance_invoices', map);
    
    // Sincronizar con Supabase
    await pushWrite(
      table: 'maintenance_invoices',
      recordId: id,
      operation: 'insert',
      data: newInvoice.toSupabase(),
      remoteOp: () async {
        await SupabaseConfig.client.from('maintenance_invoices').insert(newInvoice.toSupabase());
      },
      markSynced: () async {
        await db.update('maintenance_invoices', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
      },
    );

    DbChangeService.instance.notifyChange('maintenance_invoices');
    return id;
  }

  Future<int> deleteInvoice(String id) async {
    final db = await _dbHelper.database;
    final result = await db.delete('maintenance_invoices', where: 'id = ?', whereArgs: [id]);

    // Sincronizar con Supabase
    await pushWrite(
      table: 'maintenance_invoices',
      recordId: id,
      operation: 'delete',
      data: {},
      remoteOp: () async {
        await SupabaseConfig.client.from('maintenance_invoices').delete().eq('id', id);
      },
    );

    DbChangeService.instance.notifyChange('maintenance_invoices');
    return result;
  }
}
