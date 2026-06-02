import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../services/db_change_service.dart';
import '../services/sync_service.dart';
import '../../core/config/supabase_config.dart';
import '../../domain/models/vehicle_photo.dart';
import 'syncable_repository.dart';

class PhotoRepository with SyncableRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();
  SyncService? _syncService;

  void setSyncService(SyncService syncService) {
    _syncService = syncService;
  }

  @override
  SyncService? get syncService => _syncService;

  // Obtener fotos de un vehículo
  Future<List<VehiclePhoto>> getPhotosByVehicle(String vehicleId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'vehicle_photos',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'is_primary DESC, created_at DESC',
    );
    return maps.map((map) => VehiclePhoto.fromMap(map)).toList();
  }

  // Obtener foto principal
  Future<VehiclePhoto?> getPrimaryPhoto(String vehicleId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'vehicle_photos',
      where: 'vehicle_id = ? AND is_primary = 1',
      whereArgs: [vehicleId],
    );
    if (maps.isEmpty) return null;
    return VehiclePhoto.fromMap(maps.first);
  }

  // Insertar foto
  Future<String> insertPhoto(VehiclePhoto photo) async {
    final db = await _dbHelper.database;
    final id = _uuid.v4();

    final existingPhotos = await getPhotosByVehicle(photo.vehicleId);
    final shouldBePrimary = existingPhotos.isEmpty || photo.isPrimary;
    // Insertamos como primaria SOLO si es la primera foto (no hay otra que
    // desmarcar). Si hay otras y debe ser primaria, lo resuelve setPrimaryPhoto
    // más abajo, que marca synced=0 y encola el unset de la primaria anterior
    // (offline-safe). Así evitamos dejar dos primarias tras un fullSync.
    final insertAsPrimary = existingPhotos.isEmpty;

    final newPhoto = VehiclePhoto(
      id: id,
      vehicleId: photo.vehicleId,
      cloudinaryUrl: photo.cloudinaryUrl,
      cloudinaryPublicId: photo.cloudinaryPublicId,
      isPrimary: insertAsPrimary,
      isPdf: photo.isPdf,
      fileName: photo.fileName,
    );

    final map = newPhoto.toMap();
    map['synced'] = 0;

    await db.insert('vehicle_photos', map);

    // Sincronizar el INSERT de la foto nueva.
    await pushWrite(
      table: 'vehicle_photos',
      recordId: id,
      operation: 'insert',
      data: newPhoto.toSupabase(),
      remoteOp: () async {
        await SupabaseConfig.client.from('vehicle_photos').insert(newPhoto.toSupabase());
      },
      markSynced: () async {
        await db.update('vehicle_photos', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
      },
    );

    // Promover a primaria correctamente si corresponde y había otras fotos.
    if (shouldBePrimary && existingPhotos.isNotEmpty) {
      await setPrimaryPhoto(id, photo.vehicleId);
    }

    DbChangeService.instance.notifyChange('vehicle_photos');
    return id;
  }

  // Establecer foto como principal
  Future<void> setPrimaryPhoto(String photoId, String vehicleId) async {
    final db = await _dbHelper.database;

    // Primaria(s) anterior(es): tocamos SOLO las fotos afectadas (la vieja
    // primaria y la nueva), no todas las del vehículo, para no pisar el flag
    // synced de fotos con cambios locales pendientes.
    final prev = await db.query(
      'vehicle_photos',
      columns: ['id'],
      where: 'vehicle_id = ? AND is_primary = 1',
      whereArgs: [vehicleId],
    );
    final prevPrimaryIds = prev.map((m) => m['id'] as String).toList();

    for (final pid in prevPrimaryIds) {
      await db.update('vehicle_photos', {'is_primary': 0, 'synced': 0},
          where: 'id = ?', whereArgs: [pid]);
    }
    await db.update('vehicle_photos', {'is_primary': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [photoId]);

    // IDs afectados (la nueva primaria + las que dejaron de serlo).
    final affectedIds = <String>{...prevPrimaryIds, photoId};

    Future<void> enqueuePrimaryUpdates() async {
      for (final pid in prevPrimaryIds) {
        await _syncService?.addToSyncQueue(
          tableName: 'vehicle_photos',
          recordId: pid,
          operation: 'update',
          data: {'is_primary': false},
        );
      }
      await _syncService?.addToSyncQueue(
        tableName: 'vehicle_photos',
        recordId: photoId,
        operation: 'update',
        data: {'is_primary': true},
      );
    }

    if (await isOnline) {
      try {
        for (final pid in prevPrimaryIds) {
          await SupabaseConfig.client
              .from('vehicle_photos')
              .update({'is_primary': false})
              .eq('id', pid);
        }
        await SupabaseConfig.client
            .from('vehicle_photos')
            .update({'is_primary': true})
            .eq('id', photoId);

        // Marcar synced=1 SOLO las fotos afectadas.
        for (final pid in affectedIds) {
          await db.update('vehicle_photos', {'synced': 1},
              where: 'id = ?', whereArgs: [pid]);
        }
      } catch (e) {
        // No tragar el error: encolar para reintento posterior.
        await enqueuePrimaryUpdates();
      }
    } else {
      await enqueuePrimaryUpdates();
    }

    DbChangeService.instance.notifyChange('vehicle_photos');
  }

  // Eliminar foto
  Future<int> deletePhoto(String id) async {
    final db = await _dbHelper.database;
    
    // Obtener la foto antes de eliminar
    final maps = await db.query('vehicle_photos', where: 'id = ?', whereArgs: [id]);
    final wasPrimary = maps.isNotEmpty && (maps.first['is_primary'] as int) == 1;
    final vehicleId = maps.isNotEmpty ? maps.first['vehicle_id'] as String : null;
    
    final result = await db.delete('vehicle_photos', where: 'id = ?', whereArgs: [id]);
    
    // Si era la foto principal, establecer otra como principal
    if (wasPrimary && vehicleId != null) {
      final remainingPhotos = await getPhotosByVehicle(vehicleId);
      if (remainingPhotos.isNotEmpty) {
        await setPrimaryPhoto(remainingPhotos.first.id!, vehicleId);
      }
    }
    
    // Sincronizar con Supabase
    await pushWrite(
      table: 'vehicle_photos',
      recordId: id,
      operation: 'delete',
      data: {},
      remoteOp: () async {
        await SupabaseConfig.client.from('vehicle_photos').delete().eq('id', id);
      },
    );

    DbChangeService.instance.notifyChange('vehicle_photos');
    return result;
  }
}
