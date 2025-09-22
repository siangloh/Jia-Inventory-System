import 'package:sqflite/sqflite.dart';

import '../models/spare_part_model.dart';
import '../database_service.dart';

class SparePartDao {
  final dbService = DatabaseService();

  Future<List<SparePartModel>> getAllSpareParts() async {
    try {
      final db = await dbService.database;
      print('🔍 Querying spare_parts table...');
      
      final result = await db.query('spare_parts');
      print('📦 Found ${result.length} parts in database');
      
      final parts = result.map((row) => SparePartModel.fromJson(row)).toList();
      print('✅ Successfully converted ${parts.length} parts to models');
      
      return parts;
    } catch (e) {
      print('❌ Error in getAllSpareParts: $e');
      rethrow;
    }
  }

  Future<SparePartModel?> getSparePartById(int id) async {
    final db = await dbService.database;
    final result = await db.query(
      'spare_parts',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return SparePartModel.fromJson(result.first);
    }
    return null;
  }

  Future<List<SparePartModel>> searchSpareParts(String query) async {
    try {
      final db = await dbService.database;
      print('🔍 Searching spare_parts table for: $query');
      
      final result = await db.query(
        'spare_parts',
        where: 'name LIKE ? OR part_number LIKE ? OR manufacturer_part_number LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
      );
      print('📦 Found ${result.length} matching parts');
      
      final parts = result.map((row) => SparePartModel.fromJson(row)).toList();
      print('✅ Successfully converted ${parts.length} parts to models');
      
      return parts;
    } catch (e) {
      print('❌ Error in searchSpareParts: $e');
      rethrow;
    }
  }

  Future<List<SparePartModel>> getSparePartsByCategory(String category) async {
    final db = await dbService.database;
    final result = await db.query(
      'spare_parts',
      where: 'category = ?',
      whereArgs: [category],
    );
    return result.map((row) => SparePartModel.fromJson(row)).toList();
  }

  // Note: These methods are deprecated. Stock levels are now tracked at batch level.
  // Use InventoryBatchDao.getLowStockBatches() and getOutOfStockBatches() instead.
  Future<List<SparePartModel>> getLowStockParts() async {
    print('⚠️ Warning: getLowStockParts is deprecated. Use InventoryBatchDao.getLowStockBatches() instead.');
    return [];
  }

  Future<List<SparePartModel>> getOutOfStockParts() async {
    print('⚠️ Warning: getOutOfStockParts is deprecated. Use InventoryBatchDao.getOutOfStockBatches() instead.');
    return [];
  }

  // Note: Stock levels are now managed at batch level, not part level
  // This method is kept for backward compatibility but will be deprecated
  Future<bool> updateStockLevel(int partId, int newStockLevel) async {
    print('⚠️ Warning: updateStockLevel is deprecated. Use batch-based stock management instead.');
    return false;
  }

  // Note: This method is deprecated. Use batch-based stock management instead.
  // For now, it returns false to prevent usage
  Future<bool> adjustStockLevel(int partId, int adjustmentQuantity) async {
    print('⚠️ Warning: adjustStockLevel is deprecated. Use batch-based stock management instead.');
    print('📦 Part ID: $partId, Adjustment: $adjustmentQuantity');
    print('💡 Use InventoryBatchDao.updateBatchStock() for batch-level adjustments');
    return false;
  }

  Future<bool> isPartExists(String partNumber) async {
    try {
      final db = await dbService.database;
      final result = await db.query(
        'spare_parts',
        columns: ['part_number'],
        where: 'part_number = ?',
        whereArgs: [partNumber],
      );
      return result.isNotEmpty;
    } catch (e) {
      print('❌ Error checking if part exists: $e');
      return false;
    }
  }

  // ADD: CHECK IF MANUFACTURER PART NUMBER EXISTS (Inventory Adjustment Module)
  Future<bool> isManufacturerPartExists(String manufacturerPartNumber) async {
    try {
      final db = await dbService.database;
      
      // Clean the input to remove whitespace and normalize
      final cleanInput = manufacturerPartNumber.trim();
      
      // Check for exact match first
      var result = await db.query(
        'spare_parts',
        columns: ['manufacturer_part_number'],
        where: 'manufacturer_part_number = ?',
        whereArgs: [cleanInput],
      );
      
      // If no exact match, check for case-insensitive match
      if (result.isEmpty) {
        result = await db.rawQuery(
          'SELECT manufacturer_part_number FROM spare_parts WHERE LOWER(manufacturer_part_number) = LOWER(?)',
          [cleanInput],
        );
      }
      
      final exists = result.isNotEmpty;
      print('🔍 Manufacturer part number "$cleanInput" exists: $exists');
      return exists;
    } catch (e) {
      print('❌ Error checking if manufacturer part exists: $e');
      return false;
    }
  }

  // ADD: GET PART BY MANUFACTURER PART NUMBER (CreatePartScreen)
  Future<SparePartModel?> getPartByManufacturerPartNumber(String manufacturerPartNumber) async {
    try {
      final db = await dbService.database;
      
      // Clean the input to remove whitespace and normalize
      final cleanInput = manufacturerPartNumber.trim();
      
      // Check for exact match first
      var result = await db.query(
        'spare_parts',
        where: 'manufacturer_part_number = ?',
        whereArgs: [cleanInput],
      );
      
      // If no exact match, check for case-insensitive match
      if (result.isEmpty) {
        result = await db.rawQuery(
          'SELECT * FROM spare_parts WHERE LOWER(manufacturer_part_number) = LOWER(?)',
          [cleanInput],
        );
      }
      
      if (result.isNotEmpty) {
        print('🔍 Found duplicate part: ${result.first['name']} with manufacturer part number: ${result.first['manufacturer_part_number']}');
        return SparePartModel.fromJson(result.first);
      }
      
      print('✅ No duplicate found for manufacturer part number: $cleanInput');
      return null;
    } catch (e) {
      print('❌ Error getting part by manufacturer part number: $e');
      return null;
    }
  }

  // ADD: GET NEXT INTERNAL PART NUMBER (CreatePartScreen)
  Future<String> getNextInternalPartNumber() async {
    try {
      final db = await dbService.database;
      
      // Get the highest existing internal part number
      final result = await db.rawQuery('''
        SELECT part_number FROM spare_parts 
        WHERE part_number LIKE 'P-%' 
        ORDER BY CAST(SUBSTR(part_number, 3) AS INTEGER) DESC 
        LIMIT 1
      ''');
      
      if (result.isNotEmpty) {
        final lastPartNumber = result.first['part_number'] as String;
        // Extract the number part and increment
        final numberPart = lastPartNumber.substring(2); // Remove 'P-'
        final nextNumber = int.parse(numberPart) + 1;
        return 'P-${nextNumber.toString().padLeft(4, '0')}';
      } else {
        // No existing parts, start with P-0001
        return 'P-0001';
      }
    } catch (e) {
      print('❌ Error generating next part number: $e');
      // Fallback to a simple increment
      try {
        final db = await dbService.database;
        final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM spare_parts')
        ) ?? 0;
        return 'P-${(count + 1).toString().padLeft(4, '0')}';
      } catch (fallbackError) {
        print('❌ Fallback error: $fallbackError');
        return 'P-0001';
      }
    }
  }

  // ADD: CREATE NEW PART (CreatePartScreen)
  Future<SparePartModel?> createPart(SparePartModel part) async {
    try {
      final db = await dbService.database;
      
      // Check if manufacturer part number already exists (only if provided)
      if (part.manufacturerPartNumber != null && 
          await isManufacturerPartExists(part.manufacturerPartNumber!)) {
        print('❌ Manufacturer part number already exists: ${part.manufacturerPartNumber}');
        return null;
      }
      
      // Insert the new part
      final id = await db.insert('spare_parts', part.toMap());
      print('✅ Successfully created part with ID: $id');
      
      if (id > 0) {
        // Return the created part with its ID
        final createdPart = SparePartModel(
          id: id,
          name: part.name,
          partNumber: part.partNumber,
          manufacturerPartNumber: part.manufacturerPartNumber,
          category: part.category,
          location: part.location,
          price: part.price,
          createdAt: DateTime.now(),
        );
        
        print('✅ Returning created part with ID: ${createdPart.id}');
        return createdPart;
      }
      
      return null;
    } catch (e) {
      print('❌ Error creating part: $e');
      return null;
    }
  }
}
