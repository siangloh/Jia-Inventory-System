import 'package:sqflite/sqflite.dart';

import '../models/inventory_adjustment_model.dart';
import '../database_service.dart';

class InventoryAdjustmentDao {
  final dbService = DatabaseService();

  Future<List<InventoryAdjustmentModel>> getAllAdjustments() async {
    final db = await dbService.database;
    final result = await db.query('inventory_adjustments', orderBy: 'created_at DESC');
    return result.map((row) => InventoryAdjustmentModel.fromJson(row)).toList();
  }

  Future<InventoryAdjustmentModel?> getAdjustmentById(int id) async {
    final db = await dbService.database;
    final result = await db.query(
      'inventory_adjustments',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return InventoryAdjustmentModel.fromJson(result.first);
    }
    return null;
  }

  Future<bool> createAdjustment(InventoryAdjustmentModel adjustment) async {
    try {
      final db = await dbService.database;
      print('📊 Creating inventory adjustment for part ID: ${adjustment.partId}');
      
      final adjustmentMap = adjustment.toMap();
      print('📋 Adjustment data: $adjustmentMap');
      
      final result = await db.insert('inventory_adjustments', adjustmentMap);
      print('✅ Inventory adjustment created with ID: $result');
      
      return result > 0;
    } catch (e) {
      print('❌ Error creating inventory adjustment: $e');
      print('📋 Adjustment data that failed: ${adjustment.toMap()}');
      return false;
    }
  }

  Future<List<InventoryAdjustmentModel>> getAdjustmentsByPartId(int partId) async {
    final db = await dbService.database;
    final result = await db.query(
      'inventory_adjustments',
      where: 'part_id = ?',
      whereArgs: [partId],
      orderBy: 'created_at DESC',
    );
    return result.map((row) => InventoryAdjustmentModel.fromJson(row)).toList();
  }

  Future<List<InventoryAdjustmentModel>> getAdjustmentsByUserId(int userId) async {
    final db = await dbService.database;
    final result = await db.query(
      'inventory_adjustments',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return result.map((row) => InventoryAdjustmentModel.fromJson(row)).toList();
  }

  Future<List<InventoryAdjustmentModel>> getAdjustmentsByType(String adjustmentType) async {
    final db = await dbService.database;
    final result = await db.query(
      'inventory_adjustments',
      where: 'adjustment_type = ?',
      whereArgs: [adjustmentType],
      orderBy: 'created_at DESC',
    );
    return result.map((row) => InventoryAdjustmentModel.fromJson(row)).toList();
  }

  Future<List<InventoryAdjustmentModel>> getAdjustmentsByDateRange(DateTime startDate, DateTime endDate) async {
    final db = await dbService.database;
    final result = await db.query(
      'inventory_adjustments',
      where: 'created_at BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'created_at DESC',
    );
    return result.map((row) => InventoryAdjustmentModel.fromJson(row)).toList();
  }

  Future<List<InventoryAdjustmentModel>> getTodayAdjustments() async {
    final db = await dbService.database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final result = await db.query(
      'inventory_adjustments',
      where: 'created_at >= ? AND created_at < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'created_at DESC',
    );
    return result.map((row) => InventoryAdjustmentModel.fromJson(row)).toList();
  }

  Future<List<InventoryAdjustmentModel>> getThisWeekAdjustments() async {
    final db = await dbService.database;
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    
    final result = await db.query(
      'inventory_adjustments',
      where: 'created_at >= ?',
      whereArgs: [startOfWeekDay.toIso8601String()],
      orderBy: 'created_at DESC',
    );
    return result.map((row) => InventoryAdjustmentModel.fromJson(row)).toList();
  }

  Future<List<InventoryAdjustmentModel>> searchAdjustments(String query) async {
    final db = await dbService.database;
    final result = await db.query(
      'inventory_adjustments',
      where: 'reason_notes LIKE ? OR supplier_name LIKE ? OR purchase_order_number LIKE ? OR work_order_number LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%', '%$query%'],
      orderBy: 'created_at DESC',
    );
    return result.map((row) => InventoryAdjustmentModel.fromJson(row)).toList();
  }

  // Get adjustment statistics
  Future<Map<String, int>> getAdjustmentStats() async {
    final db = await dbService.database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final result = await db.rawQuery('''
      SELECT adjustment_type, COUNT(*) as count
      FROM inventory_adjustments
      WHERE created_at >= ? AND created_at < ?
      GROUP BY adjustment_type
    ''', [startOfDay.toIso8601String(), endOfDay.toIso8601String()]);
    
    final stats = <String, int>{};
    for (final row in result) {
      stats[row['adjustment_type'] as String] = row['count'] as int;
    }
    
    return stats;
  }

  // Get top damaged/returned parts
  Future<List<Map<String, dynamic>>> getTopAdjustedParts(String adjustmentType, {int limit = 5}) async {
    final db = await dbService.database;
    final result = await db.rawQuery('''
      SELECT 
        sp.name,
        sp.part_number,
        COUNT(*) as adjustment_count,
        SUM(ia.quantity) as total_quantity
      FROM inventory_adjustments ia
      JOIN spare_parts sp ON ia.part_id = sp.id
      WHERE ia.adjustment_type = ?
      GROUP BY ia.part_id
      ORDER BY adjustment_count DESC
      LIMIT ?
    ''', [adjustmentType, limit]);
    
    return result;
  }

  // Get adjustment reasons breakdown
  Future<List<Map<String, dynamic>>> getAdjustmentReasonsBreakdown() async {
    final db = await dbService.database;
    final result = await db.rawQuery('''
      SELECT 
        adjustment_type,
        COUNT(*) as count
      FROM inventory_adjustments
      GROUP BY adjustment_type
      ORDER BY count DESC
    ''');
    
    return result;
  }
}
