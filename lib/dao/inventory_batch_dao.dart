import 'package:sqflite/sqflite.dart';

import '../models/inventory_batch_model.dart';
// Removed unused import
import '../database_service.dart';

class InventoryBatchDao {
  final dbService = DatabaseService();

  // Create a new batch (when receiving stock)
  Future<InventoryBatchModel?> createBatch(InventoryBatchModel batch) async {
    try {
      final db = await dbService.database;
      print('📦 Creating new inventory batch for part ID: ${batch.partId}');
      
      final batchMap = batch.toMap();
      print('📋 Batch data: $batchMap');
      
      final id = await db.insert('inventory_batches', batchMap);
      print('✅ Successfully created batch with ID: $id');
      
      if (id > 0) {
        // Return the created batch with its ID
        final createdBatch = InventoryBatchModel(
          id: id,
          partId: batch.partId,
          quantityOnHand: batch.quantityOnHand,
          costPrice: batch.costPrice,
          receivedDate: batch.receivedDate,
          supplierName: batch.supplierName,
          purchaseOrderNumber: batch.purchaseOrderNumber,
          createdAt: DateTime.now(),
        );
        
        print('✅ Returning created batch with ID: ${createdBatch.id}');
        return createdBatch;
      }
      
      return null;
    } catch (e) {
      print('❌ Error creating batch: $e');
      return null;
    }
  }

  // Get all batches for a specific part
  Future<List<InventoryBatchModel>> getBatchesByPartId(int partId) async {
    try {
      final db = await dbService.database;
      print('🔍 Getting batches for part ID: $partId');
      
      final result = await db.query(
        'inventory_batches',
        where: 'part_id = ?',
        whereArgs: [partId],
        orderBy: 'received_date DESC', // Most recent first
      );
      
      final batches = result.map((row) => InventoryBatchModel.fromJson(row)).toList();
      print('✅ Found ${batches.length} batches for part ID: $partId');
      
      return batches;
    } catch (e) {
      print('❌ Error getting batches by part ID: $e');
      return [];
    }
  }

  // Get a specific batch by ID
  Future<InventoryBatchModel?> getBatchById(int batchId) async {
    try {
      final db = await dbService.database;
      final result = await db.query(
        'inventory_batches',
        where: 'id = ?',
        whereArgs: [batchId],
      );
      
      if (result.isNotEmpty) {
        return InventoryBatchModel.fromJson(result.first);
      }
      return null;
    } catch (e) {
      print('❌ Error getting batch by ID: $e');
      return null;
    }
  }

  // Update batch stock level (for adjustments)
  Future<bool> updateBatchStock(int batchId, int newQuantity) async {
    try {
      final db = await dbService.database;
      print('📦 Updating batch $batchId stock to: $newQuantity');
      
      final result = await db.update(
        'inventory_batches',
        {'quantity_on_hand': newQuantity},
        where: 'id = ?',
        whereArgs: [batchId],
      );
      
      final success = result > 0;
      if (success) {
        print('✅ Successfully updated batch stock');
      } else {
        print('❌ Failed to update batch stock');
      }
      
      return success;
    } catch (e) {
      print('❌ Error updating batch stock: $e');
      return false;
    }
  }

  // Get total stock for a part (sum of all batches)
  Future<int> getTotalStockForPart(int partId) async {
    try {
      final db = await dbService.database;
      final result = await db.rawQuery(
        'SELECT SUM(quantity_on_hand) as total_stock FROM inventory_batches WHERE part_id = ?',
        [partId],
      );
      
      final totalStock = Sqflite.firstIntValue(result) ?? 0;
      print('📊 Total stock for part $partId: $totalStock');
      
      return totalStock;
    } catch (e) {
      print('❌ Error getting total stock for part: $e');
      return 0;
    }
  }

  // Get batches with stock (for part selection)
  Future<List<InventoryBatchModel>> getBatchesWithStock(int partId) async {
    try {
      final db = await dbService.database;
      final result = await db.query(
        'inventory_batches',
        where: 'part_id = ? AND quantity_on_hand > 0',
        whereArgs: [partId],
        orderBy: 'received_date DESC',
      );
      
      final batches = result.map((row) => InventoryBatchModel.fromJson(row)).toList();
      print('✅ Found ${batches.length} batches with stock for part ID: $partId');
      
      return batches;
    } catch (e) {
      print('❌ Error getting batches with stock: $e');
      return [];
    }
  }

  // Get low stock batches (less than 10 items)
  Future<List<InventoryBatchModel>> getLowStockBatches() async {
    try {
      final db = await dbService.database;
      final result = await db.query(
        'inventory_batches',
        where: 'quantity_on_hand < 10 AND quantity_on_hand > 0',
        orderBy: 'quantity_on_hand ASC',
      );
      
      final batches = result.map((row) => InventoryBatchModel.fromJson(row)).toList();
      print('⚠️ Found ${batches.length} batches with low stock');
      
      return batches;
    } catch (e) {
      print('❌ Error getting low stock batches: $e');
      return [];
    }
  }

  // Get out of stock batches
  Future<List<InventoryBatchModel>> getOutOfStockBatches() async {
    try {
      final db = await dbService.database;
      final result = await db.query(
        'inventory_batches',
        where: 'quantity_on_hand <= 0',
        orderBy: 'received_date DESC',
      );
      
      final batches = result.map((row) => InventoryBatchModel.fromJson(row)).toList();
      print('❌ Found ${batches.length} out of stock batches');
      
      return batches;
    } catch (e) {
      print('❌ Error getting out of stock batches: $e');
      return [];
    }
  }

  // Delete a batch (for cleanup)
  Future<bool> deleteBatch(int batchId) async {
    try {
      final db = await dbService.database;
      print('🗑️ Deleting batch ID: $batchId');
      
      final result = await db.delete(
        'inventory_batches',
        where: 'id = ?',
        whereArgs: [batchId],
      );
      
      final success = result > 0;
      if (success) {
        print('✅ Successfully deleted batch');
      } else {
        print('❌ Failed to delete batch');
      }
      
      return success;
    } catch (e) {
      print('❌ Error deleting batch: $e');
      return false;
    }
  }

  // Get batch statistics
  Future<Map<String, dynamic>> getBatchStats() async {
    try {
      final db = await dbService.database;
      
      // Total batches
      final totalBatches = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM inventory_batches')
      ) ?? 0;
      
      // Total value
      final totalValueResult = await db.rawQuery('SELECT SUM(quantity_on_hand * cost_price) as total_value FROM inventory_batches');
      final totalValue = totalValueResult.isNotEmpty && totalValueResult.first['total_value'] != null 
          ? (totalValueResult.first['total_value'] as num).toDouble() 
          : 0.0;
      
      // Low stock batches
      final lowStockCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM inventory_batches WHERE quantity_on_hand < 10 AND quantity_on_hand > 0')
      ) ?? 0;
      
      // Out of stock batches
      final outOfStockCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM inventory_batches WHERE quantity_on_hand <= 0')
      ) ?? 0;
      
      final stats = {
        'totalBatches': totalBatches,
        'totalValue': totalValue,
        'lowStockCount': lowStockCount,
        'outOfStockCount': outOfStockCount,
      };
      
      print('📊 Batch statistics: $stats');
      return stats;
    } catch (e) {
      print('❌ Error getting batch statistics: $e');
      return {};
    }
  }
}
