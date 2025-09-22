import 'dart:developer';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'utils/mock_data.dart';
import 'dao/user_dao.dart';

class DatabaseService {
  static final DatabaseService _databaseService = DatabaseService._internal();

  factory DatabaseService() => _databaseService;

  DatabaseService._internal();

  static Database? _database;

  // Get an instance of database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }


  Future<Database> initDatabase() async {
    // Try multiple path strategies for maximum compatibility
    String? path;
    Directory? directory;
    
    // Strategy 1: Try getDatabasesPath() first
    try {
      final databasesPath = await getDatabasesPath();
      path = '$databasesPath/inventory.db';
      directory = Directory(databasesPath);
      print('📁 Strategy 1: Using databases path: $databasesPath');
    } catch (e) {
      print('⚠️ Strategy 1 failed: $e');
    }
    
    // Strategy 2: Try application documents directory
    if (path == null || directory == null || !await directory.exists()) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        path = '${appDir.path}/inventory.db';
        directory = appDir;
        print('📁 Strategy 2: Using app documents: ${appDir.path}');
      } catch (e) {
        print('⚠️ Strategy 2 failed: $e');
      }
    }
    
    // Strategy 3: Try temporary directory as last resort
    if (path == null || directory == null || !await directory.exists()) {
      try {
        final tempDir = await getTemporaryDirectory();
        path = '${tempDir.path}/inventory.db';
        directory = tempDir;
        print('📁 Strategy 3: Using temp directory: ${tempDir.path}');
      } catch (e) {
        print('⚠️ Strategy 3 failed: $e');
      }
    }
    
    if (directory == null || path == null) {
      throw Exception('Could not find a suitable directory for database');
    }
    
    print('📁 Final database path: $path');
    
    // Ensure directory exists
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      print('📁 Created directory: ${directory.path}');
    }
    
    // Check if database file exists and try to delete it
    final databaseFile = File(path);
    if (await databaseFile.exists()) {
      try {
        await databaseFile.delete();
        print('📁 FORCED: Deleted existing database to fix corruption');
      } catch (e) {
        print('⚠️ Could not delete existing database: $e');
        // Try to use existing database if deletion fails
        try {
          final existingDb = await openDatabase(
            path,
            version: 1,
            readOnly: false,
            singleInstance: true,
          );
          print('✅ Using existing database successfully');
          return existingDb;
        } catch (existingDbError) {
          print('❌ Existing database also failed: $existingDbError');
          // Continue with recreation
        }
      }
    }
    
    try {
      print('📁 Creating fresh database...');
      
      // Try to create database with explicit options
      final db = await openDatabase(
        path, 
        onCreate: _onCreate, 
        version: 1,
        readOnly: false,
        singleInstance: true,
      );
      print('✅ Database created successfully');
      
      // Verify tables were created
      final tables = await db.query('sqlite_master', where: 'type = ?', whereArgs: ['table']);
      print('📋 Tables in database: ${tables.map((t) => t['name']).toList()}');

      // Test write operation to ensure database is writable
      try {
        await db.execute('CREATE TABLE IF NOT EXISTS test_write (id INTEGER)');
        await db.execute('DROP TABLE IF EXISTS test_write');
        print('✅ Database write test passed - database is writable');
      } catch (e) {
        print('❌ Database write test failed: $e');
        throw Exception('Database is not writable: $e');
      }

      print('✅ Database ready for use');
      
      return db;
    } catch (e) {
      print('❌ Critical error creating database: $e');
      
      // Try fallback: create database in memory
      print('🔄 Trying fallback: in-memory database...');
      try {
        final inMemoryDb = await openDatabase(
          ':memory:', 
          onCreate: _onCreate, 
          version: 1,
          readOnly: false,
        );
        print('✅ In-memory database created successfully');
        return inMemoryDb;
      } catch (fallbackError) {
        print('❌ Fallback also failed: $fallbackError');
        rethrow; // Re-throw the original error
      }
    }
  }


  // create database tables
  Future<void> _onCreate(Database db, int version) async {
    // users table for authentication
    await db.execute('CREATE TABLE Users ('
        'id TEXT PRIMARY KEY, '
        'firstName TEXT NOT NULL CHECK(length(firstName) > 1), '
        'lastName TEXT NOT NULL CHECK(length(lastName) > 1), '
        'email TEXT UNIQUE NOT NULL, '
        'role TEXT CHECK (role IN ("ADMIN", "MANAGER")) NOT NULL, '
        'phoneNum TEXT UNIQUE CHECK((phoneNum IS NULL) OR (phoneNum GLOB "[0-9]*" AND length(phoneNum) BETWEEN 10 AND 15)),'
        'status TEXT CHECK (status IN ("ACTIVE", "INACTIVE")),'
        'createOn DATETIME DEFAULT CURRENT_TIMESTAMP)');

    // ADD: CREATE STATEMENT FOR SPARE PARTS TABLE (Inventory Adjustment Module - Updated Schema)
    await db.execute('CREATE TABLE spare_parts ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'name TEXT NOT NULL, '
        'part_number TEXT UNIQUE NOT NULL, '
        'manufacturer_part_number TEXT, '
        'category TEXT, '
        'location TEXT, '
        'price REAL, ' // Now nullable since price is handled at batch level
        'created_at DATETIME DEFAULT CURRENT_TIMESTAMP)');

    // ADD: CREATE STATEMENT FOR INVENTORY BATCHES TABLE (New Batch Tracking System)
    await db.execute('CREATE TABLE inventory_batches ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'part_id INTEGER NOT NULL, '
        'quantity_on_hand INTEGER NOT NULL DEFAULT 0, '
        'cost_price REAL NOT NULL, '
        'received_date DATETIME NOT NULL, '
        'supplier_name TEXT, '
        'purchase_order_number TEXT, '
        'created_at DATETIME DEFAULT (datetime(\'now\')), '
        'FOREIGN KEY (part_id) REFERENCES spare_parts(id))');

    // ADD: CREATE STATEMENT FOR INVENTORY ADJUSTMENTS TABLE (Inventory Adjustment Module - Updated with Batch Tracking)
    await db.execute('CREATE TABLE inventory_adjustments ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'part_id INTEGER NOT NULL, '
        'batch_id INTEGER, '
        'user_id INTEGER NOT NULL, '
        'adjustment_type TEXT NOT NULL CHECK (adjustment_type IN ("RECEIVED", "DAMAGED", "LOST", "EXPIRED", "RETURNED")), '
        'quantity INTEGER NOT NULL, '
        'reason_notes TEXT, '
        'photo_url TEXT, '
        'supplier_name TEXT, '
        'purchase_order_number TEXT, '
        'work_order_number TEXT, '
        'created_at DATETIME DEFAULT (datetime(\'now\')), '
        'FOREIGN KEY (part_id) REFERENCES spare_parts(id), '
        'FOREIGN KEY (batch_id) REFERENCES inventory_batches(id), '
        'FOREIGN KEY (user_id) REFERENCES Users(id))');

    // insert default admin user
    await db.insert('Users', {
      'id': 'EMP0001',
      'firstName': 'Datuk',
      'lastName': 'Yeap',
      'email': 'siangloh1123@gmail.com',
      'role': 'ADMIN',
      'phoneNum': '011-59547102',
      'status': 'ACTIVE',
    });

    final userDao = UserDao();
    String? created =
        await userDao.createUserAuth('siangloh1123@gmail.com', 'Admin123');

    if (created == null) {
      print("Create account successfully");
    } else {
      print("Create unsuccessfully.");
    }

    // ADD: INSERT SAMPLE DATA FOR INVENTORY ADJUSTMENT MODULE TESTING
    await _insertMockSpareParts(db);
    await _insertMockBatches(db);
    await _insertMockAdjustments(db);
  }

  // insert sample spare parts for testing
  Future<void> _insertMockSpareParts(Database db) async {
    try {
      for (final part in MockData.spareParts) {
        final id = await db.insert('spare_parts', part);
        print('📦 Inserted part: ${part['name']} with ID: $id');
      }

      print(
          '✅ Successfully inserted ${MockData.spareParts.length} sample spare parts for testing');
    } catch (e) {
      print('❌ Error inserting mock spare parts: $e');
      rethrow;
    }
  }

  // insert sample inventory batches for testing
  Future<void> _insertMockBatches(Database db) async {
    try {
      for (final batch in MockData.inventoryBatches) {
        final id = await db.insert('inventory_batches', batch);
        print('📦 Inserted batch for part ID: ${batch['part_id']} with ID: $id');
      }

      print('✅ Successfully inserted ${MockData.inventoryBatches.length} sample inventory batches for testing');
    } catch (e) {
      print('❌ Error inserting mock inventory batches: $e');
      rethrow;
    }
  }

  // ADD: INSERT SAMPLE INVENTORY ADJUSTMENTS FOR TESTING (Inventory Adjustment Module)
  Future<void> _insertMockAdjustments(Database db) async {
    try {
      for (final adjustment in MockData.inventoryAdjustments) {
        final id = await db.insert('inventory_adjustments', adjustment);
        print(
            '📊 Inserted adjustment: ${adjustment['adjustment_type']} for part ID: ${adjustment['part_id']} with ID: $id');
      }

      print(
          '✅ Successfully inserted ${MockData.inventoryAdjustments.length} sample inventory adjustments for testing');
    } catch (e) {
      print('❌ Error inserting mock adjustments: $e');
      rethrow;
    }
  }

  // handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 Upgrading database from version $oldVersion to $newVersion');
    // For now, just recreate tables if needed
    // In production, you would handle migrations properly
  }
}
