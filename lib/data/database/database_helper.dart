import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('vehicles_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onConfigure: _onConfigure,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // Activar foreign keys: sqflite las tiene desactivadas por defecto en cada
  // conexión, por lo que los ON DELETE CASCADE del schema no se aplican sin esto.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Agregar tabla de fotos de documentos
      await db.execute('''
        CREATE TABLE IF NOT EXISTS document_photos (
          id TEXT PRIMARY KEY,
          vehicle_id TEXT NOT NULL,
          document_type INTEGER NOT NULL,
          cloudinary_url TEXT NOT NULL,
          cloudinary_public_id TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_document_photos_vehicle ON document_photos (vehicle_id)');
    }

    if (oldVersion < 3) {
      // Agregar tablas de ciudades y lugares (sistema jerárquico de ubicación)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cities (
          id TEXT PRIMARY KEY,
          province_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          name_normalized TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_cities_province_name ON cities (province_id, name_normalized)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_cities_province ON cities (province_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_cities_synced ON cities (synced)');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS lugares (
          id TEXT PRIMARY KEY,
          city_id TEXT NOT NULL,
          name TEXT NOT NULL,
          name_normalized TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (city_id) REFERENCES cities (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_lugares_city_name ON lugares (city_id, name_normalized)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_lugares_city ON lugares (city_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_lugares_synced ON lugares (synced)');

      // Agregar columnas city_id y lugar_id a vehicles
      await db.execute('ALTER TABLE vehicles ADD COLUMN city_id TEXT');
      await db.execute('ALTER TABLE vehicles ADD COLUMN lugar_id TEXT');
      await db.execute('ALTER TABLE vehicles ADD COLUMN lugar TEXT');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_vehicles_city ON vehicles (city_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_vehicles_lugar ON vehicles (lugar_id)');
    }

    if (oldVersion < 4) {
      // Agregar tabla de cargas de combustible
      // Agregar tabla de cargas de combustible
      await db.execute('''
        CREATE TABLE IF NOT EXISTS fuel_charges (
          id TEXT PRIMARY KEY,
          vehicle_id TEXT NOT NULL,
          date INTEGER NOT NULL,
          liters REAL NOT NULL,
          price REAL NOT NULL,
          price_per_liter REAL,
          odometer INTEGER,
          receipt_photo_url TEXT,
          receipt_photo_public_id TEXT,
          display_photo_url TEXT,
          display_photo_public_id TEXT,
          notes TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_fuel_charges_vehicle ON fuel_charges (vehicle_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_fuel_charges_date ON fuel_charges (date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_fuel_charges_vehicle_date ON fuel_charges (vehicle_id, date)');
    }

    if (oldVersion < 5) {
      // Soporte de archivos PDF en fotos de vehículos, documentos, notas y combustible
      await db.execute('ALTER TABLE vehicle_photos ADD COLUMN is_pdf INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE vehicle_photos ADD COLUMN file_name TEXT');
      await db.execute('ALTER TABLE document_photos ADD COLUMN is_pdf INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE document_photos ADD COLUMN file_name TEXT');
      await db.execute('ALTER TABLE note_photos ADD COLUMN is_pdf INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE note_photos ADD COLUMN file_name TEXT');
      await db.execute('ALTER TABLE fuel_charges ADD COLUMN receipt_is_pdf INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE fuel_charges ADD COLUMN receipt_file_name TEXT');
      await db.execute('ALTER TABLE fuel_charges ADD COLUMN display_is_pdf INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE fuel_charges ADD COLUMN display_file_name TEXT');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Tabla de ciudades (sistema jerárquico de ubicación)
    await db.execute('''
      CREATE TABLE cities (
        id TEXT PRIMARY KEY,
        province_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        name_normalized TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Tabla de lugares (dentro de ciudades)
    await db.execute('''
      CREATE TABLE lugares (
        id TEXT PRIMARY KEY,
        city_id TEXT NOT NULL,
        name TEXT NOT NULL,
        name_normalized TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (city_id) REFERENCES cities (id) ON DELETE CASCADE
      )
    ''');

    // Tabla de vehículos (cache de Supabase)
    await db.execute('''
      CREATE TABLE vehicles (
        id TEXT PRIMARY KEY,
        plate TEXT NOT NULL UNIQUE,
        type INTEGER NOT NULL,
        brand TEXT NOT NULL,
        model TEXT NOT NULL,
        year INTEGER NOT NULL,
        color INTEGER NOT NULL,
        km INTEGER NOT NULL,
        vtv_expiry INTEGER,
        insurance_company TEXT,
        insurance_expiry INTEGER,
        fuel_type INTEGER NOT NULL,
        status INTEGER NOT NULL,
        province_id INTEGER NOT NULL,
        city TEXT NOT NULL,
        city_id TEXT,
        lugar_id TEXT,
        lugar TEXT,
        responsible_name TEXT NOT NULL,
        responsible_phone TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Tabla de historial
    await db.execute('''
      CREATE TABLE vehicle_history (
        id TEXT PRIMARY KEY,
        vehicle_id TEXT NOT NULL,
        field TEXT NOT NULL,
        old_value TEXT NOT NULL,
        new_value TEXT NOT NULL,
        changed_at INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
      )
    ''');

    // Tabla de mantenimientos
    await db.execute('''
      CREATE TABLE maintenances (
        id TEXT PRIMARY KEY,
        vehicle_id TEXT NOT NULL,
        date INTEGER NOT NULL,
        detail TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
      )
    ''');

    // Tabla de facturas de mantenimiento
    await db.execute('''
      CREATE TABLE maintenance_invoices (
        id TEXT PRIMARY KEY,
        maintenance_id TEXT NOT NULL,
        cloudinary_url TEXT NOT NULL,
        cloudinary_public_id TEXT NOT NULL,
        file_type INTEGER NOT NULL DEFAULT 0,
        file_name TEXT,
        created_at INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (maintenance_id) REFERENCES maintenances (id) ON DELETE CASCADE
      )
    ''');

    // Tabla de notas del vehículo
    await db.execute('''
      CREATE TABLE vehicle_notes (
        id TEXT PRIMARY KEY,
        vehicle_id TEXT NOT NULL,
        detail TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
      )
    ''');

    // Tabla de fotos de notas
    await db.execute('''
      CREATE TABLE note_photos (
        id TEXT PRIMARY KEY,
        note_id TEXT NOT NULL,
        cloudinary_url TEXT NOT NULL,
        cloudinary_public_id TEXT NOT NULL,
        is_pdf INTEGER NOT NULL DEFAULT 0,
        file_name TEXT,
        created_at INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (note_id) REFERENCES vehicle_notes (id) ON DELETE CASCADE
      )
    ''');

    // Tabla de fotos del vehículo (galería)
    await db.execute('''
      CREATE TABLE vehicle_photos (
        id TEXT PRIMARY KEY,
        vehicle_id TEXT NOT NULL,
        cloudinary_url TEXT NOT NULL,
        cloudinary_public_id TEXT NOT NULL,
        is_primary INTEGER NOT NULL DEFAULT 0,
        is_pdf INTEGER NOT NULL DEFAULT 0,
        file_name TEXT,
        created_at INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
      )
    ''');

    // Tabla de fotos de documentos (cédula verde, cédula azul, título)
    await db.execute('''
      CREATE TABLE document_photos (
        id TEXT PRIMARY KEY,
        vehicle_id TEXT NOT NULL,
        document_type INTEGER NOT NULL,
        cloudinary_url TEXT NOT NULL,
        cloudinary_public_id TEXT NOT NULL,
        is_pdf INTEGER NOT NULL DEFAULT 0,
        file_name TEXT,
        created_at INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
      )
    ''');

    // Tabla de cargas de combustible
    await db.execute('''
      CREATE TABLE fuel_charges (
        id TEXT PRIMARY KEY,
        vehicle_id TEXT NOT NULL,
        date INTEGER NOT NULL,
        liters REAL NOT NULL,
        price REAL NOT NULL,
        price_per_liter REAL,
        odometer INTEGER,
        receipt_photo_url TEXT,
        receipt_photo_public_id TEXT,
        receipt_is_pdf INTEGER NOT NULL DEFAULT 0,
        receipt_file_name TEXT,
        display_photo_url TEXT,
        display_photo_public_id TEXT,
        display_is_pdf INTEGER NOT NULL DEFAULT 0,
        display_file_name TEXT,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
      )
    ''');

    // Cola de sincronización para operaciones offline
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Índices para mejorar rendimiento
    await db.execute('CREATE INDEX idx_vehicles_plate ON vehicles (plate)');
    await db.execute('CREATE INDEX idx_vehicles_province ON vehicles (province_id)');
    await db.execute('CREATE INDEX idx_vehicles_status ON vehicles (status)');
    await db.execute('CREATE INDEX idx_vehicles_synced ON vehicles (synced)');
    await db.execute('CREATE INDEX idx_vehicles_city ON vehicles (city_id)');
    await db.execute('CREATE INDEX idx_vehicles_lugar ON vehicles (lugar_id)');
    await db.execute('CREATE INDEX idx_history_vehicle ON vehicle_history (vehicle_id)');
    await db.execute('CREATE INDEX idx_maintenances_vehicle ON maintenances (vehicle_id)');
    await db.execute('CREATE INDEX idx_notes_vehicle ON vehicle_notes (vehicle_id)');
    await db.execute('CREATE INDEX idx_photos_vehicle ON vehicle_photos (vehicle_id)');
    await db.execute('CREATE INDEX idx_document_photos_vehicle ON document_photos (vehicle_id)');
    await db.execute('CREATE INDEX idx_fuel_charges_vehicle ON fuel_charges (vehicle_id)');
    await db.execute('CREATE INDEX idx_fuel_charges_date ON fuel_charges (date)');
    await db.execute('CREATE INDEX idx_fuel_charges_vehicle_date ON fuel_charges (vehicle_id, date)');

    // Índices para ciudades y lugares
    await db.execute('CREATE UNIQUE INDEX idx_cities_province_name ON cities (province_id, name_normalized)');
    await db.execute('CREATE INDEX idx_cities_province ON cities (province_id)');
    await db.execute('CREATE INDEX idx_cities_synced ON cities (synced)');
    await db.execute('CREATE UNIQUE INDEX idx_lugares_city_name ON lugares (city_id, name_normalized)');
    await db.execute('CREATE INDEX idx_lugares_city ON lugares (city_id)');
    await db.execute('CREATE INDEX idx_lugares_synced ON lugares (synced)');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  // Orden de borrado: hijos antes que padres (respeta las FKs con CASCADE).
  static const _deleteOrder = [
    'fuel_charges',
    'document_photos',
    'note_photos',
    'vehicle_notes',
    'maintenance_invoices',
    'maintenances',
    'vehicle_photos',
    'vehicle_history',
    'vehicles',
    'lugares',
    'cities',
  ];

  // Orden de inserción: padres antes que hijos (respeta las FKs).
  static const _insertOrder = [
    'cities',
    'lugares',
    'vehicles',
    'vehicle_history',
    'maintenances',
    'maintenance_invoices',
    'vehicle_notes',
    'note_photos',
    'vehicle_photos',
    'document_photos',
    'fuel_charges',
  ];

  // Reemplaza atómicamente toda la cache local con los datos descargados de
  // Supabase. Borra y reinserta dentro de una única transacción, de modo que un
  // fallo a mitad de camino no deja la cache vacía/parcial. NO toca sync_queue:
  // esa cola es estado pendiente de subida, no cache de Supabase.
  Future<void> replaceAllData(
    Map<String, List<Map<String, dynamic>>> tableData,
  ) async {
    final db = await database;
    // Desactivamos las foreign keys durante el reemplazo: así el borrado de la
    // cache (filas synced=1) no dispara ON DELETE CASCADE sobre filas locales
    // pendientes de subir (synced=0) en tablas hijas, ni el replace de un padre
    // arrastra a sus hijos. El orden manual mantiene la integridad y al
    // reactivarlas el estado queda consistente. (PRAGMA no se puede cambiar
    // dentro de una transacción, por eso va alrededor.)
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      await db.transaction((txn) async {
        // Borrar SOLO la cache pura de Supabase (synced=1); preservar lo que
        // todavía no se subió (synced=0), que de otro modo se perdería.
        for (final table in _deleteOrder) {
          await txn.delete(table, where: 'synced = 1');
        }
        // Insertar/actualizar lo remoto. replace por si una fila pendiente local
        // ya existe en Supabase (gana la versión remota, ya sincronizada).
        final batch = txn.batch();
        for (final table in _insertOrder) {
          for (final row in tableData[table] ?? const []) {
            batch.insert(table, {...row, 'synced': 1},
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
        await batch.commit(noResult: true);
      });
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  // Método para reiniciar la base de datos
  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'vehicles_v2.db');
    
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    
    await deleteDatabase(path);
    _database = await _initDB('vehicles_v2.db');
  }
}
