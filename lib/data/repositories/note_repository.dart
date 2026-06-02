import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../services/db_change_service.dart';
import '../services/sync_service.dart';
import '../../core/config/supabase_config.dart';
import '../../domain/models/vehicle_note.dart';
import 'syncable_repository.dart';

class NoteRepository with SyncableRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();
  SyncService? _syncService;

  void setSyncService(SyncService syncService) {
    _syncService = syncService;
  }

  @override
  SyncService? get syncService => _syncService;

  // Obtener notas de un vehículo
  Future<List<VehicleNote>> getNotesByVehicle(String vehicleId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'vehicle_notes',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'created_at DESC',
    );
    if (maps.isEmpty) return [];

    // Traer todas las fotos en una sola query (evita N+1) y agrupar por nota.
    final ids = maps.map((m) => m['id'] as String).toList();
    final placeholders = List.filled(ids.length, '?').join(', ');
    final photoMaps = await db.query(
      'note_photos',
      where: 'note_id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'created_at DESC',
    );
    final photosByNote = <String, List<NotePhoto>>{};
    for (final m in photoMaps) {
      (photosByNote[m['note_id'] as String] ??= []).add(NotePhoto.fromMap(m));
    }

    return maps
        .map((map) => VehicleNote.fromMap(map).copyWith(
              photos: photosByNote[map['id'] as String] ?? const [],
            ))
        .toList();
  }

  // Obtener una nota por ID
  Future<VehicleNote?> getNoteById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'vehicle_notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    
    final photos = await getPhotosByNote(id);
    return VehicleNote.fromMap(maps.first).copyWith(photos: photos);
  }

  // Insertar nota
  Future<String> insertNote(VehicleNote note) async {
    final db = await _dbHelper.database;
    final id = _uuid.v4();
    final newNote = note.copyWith(id: id);
    
    final map = newNote.toMap();
    map['synced'] = 0;
    
    await db.insert('vehicle_notes', map);
    
    // Sincronizar con Supabase
    await pushWrite(
      table: 'vehicle_notes',
      recordId: id,
      operation: 'insert',
      data: newNote.toSupabase(),
      remoteOp: () async {
        await SupabaseConfig.client.from('vehicle_notes').insert(newNote.toSupabase());
      },
      markSynced: () async {
        await db.update('vehicle_notes', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
      },
    );

    DbChangeService.instance.notifyChange('vehicle_notes');
    return id;
  }

  // Actualizar nota
  Future<int> updateNote(VehicleNote note) async {
    if (note.id == null) throw Exception('Note ID is required');
    
    final db = await _dbHelper.database;
    final updatedNote = note.copyWith(updatedAt: DateTime.now());
    final map = updatedNote.toMap();
    map['synced'] = 0;
    
    final result = await db.update(
      'vehicle_notes',
      map,
      where: 'id = ?',
      whereArgs: [note.id],
    );
    
    // Sincronizar con Supabase
    await pushWrite(
      table: 'vehicle_notes',
      recordId: note.id!,
      operation: 'update',
      data: updatedNote.toSupabase(),
      remoteOp: () async {
        await SupabaseConfig.client
            .from('vehicle_notes')
            .update(updatedNote.toSupabase())
            .eq('id', note.id!);
      },
      markSynced: () async {
        await db.update('vehicle_notes', {'synced': 1}, where: 'id = ?', whereArgs: [note.id]);
      },
    );

    DbChangeService.instance.notifyChange('vehicle_notes');
    return result;
  }

  // Eliminar nota
  Future<int> deleteNote(String id) async {
    final db = await _dbHelper.database;
    
    // Eliminar fotos primero
    await db.delete('note_photos', where: 'note_id = ?', whereArgs: [id]);
    
    final result = await db.delete('vehicle_notes', where: 'id = ?', whereArgs: [id]);

    // Sincronizar con Supabase
    await pushWrite(
      table: 'vehicle_notes',
      recordId: id,
      operation: 'delete',
      data: {},
      remoteOp: () async {
        await SupabaseConfig.client.from('vehicle_notes').delete().eq('id', id);
      },
    );

    DbChangeService.instance.notifyChange('vehicle_notes');
    DbChangeService.instance.notifyChange('note_photos');
    return result;
  }

  // Fotos de notas
  Future<List<NotePhoto>> getPhotosByNote(String noteId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'note_photos',
      where: 'note_id = ?',
      whereArgs: [noteId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => NotePhoto.fromMap(map)).toList();
  }

  Future<String> insertPhoto(NotePhoto photo) async {
    final db = await _dbHelper.database;
    final id = _uuid.v4();
    final newPhoto = NotePhoto(
      id: id,
      noteId: photo.noteId,
      cloudinaryUrl: photo.cloudinaryUrl,
      cloudinaryPublicId: photo.cloudinaryPublicId,
      isPdf: photo.isPdf,
      fileName: photo.fileName,
    );
    
    final map = newPhoto.toMap();
    map['synced'] = 0;
    
    await db.insert('note_photos', map);
    
    // Sincronizar con Supabase
    await pushWrite(
      table: 'note_photos',
      recordId: id,
      operation: 'insert',
      data: newPhoto.toSupabase(),
      remoteOp: () async {
        await SupabaseConfig.client.from('note_photos').insert(newPhoto.toSupabase());
      },
      markSynced: () async {
        await db.update('note_photos', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
      },
    );

    DbChangeService.instance.notifyChange('note_photos');
    return id;
  }

  Future<int> deletePhoto(String id) async {
    final db = await _dbHelper.database;
    final result = await db.delete('note_photos', where: 'id = ?', whereArgs: [id]);

    // Sincronizar con Supabase
    await pushWrite(
      table: 'note_photos',
      recordId: id,
      operation: 'delete',
      data: {},
      remoteOp: () async {
        await SupabaseConfig.client.from('note_photos').delete().eq('id', id);
      },
    );

    DbChangeService.instance.notifyChange('note_photos');
    return result;
  }
}
