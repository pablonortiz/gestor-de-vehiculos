// Stub para web - no usa sqflite
// En web, todos los datos vienen directamente de Supabase

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  DatabaseHelper._init();

  // En web no hay base de datos local
  Future<dynamic> get database async => throw UnsupportedError('SQLite no disponible en web');

  Future<void> close() async {}

  Future<void> clearAllTables() async {}

  Future<void> resetDatabase() async {}
}
