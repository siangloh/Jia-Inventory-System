// lib/dao/warehouse_deduction_dao.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:assignment/models/warehouse_location.dart';
import 'package:assignment/models/product_item.dart';
import 'dart:async';

class LocationWithDocId {
  final String firestoreDocId;
  final WarehouseLocation location;

  LocationWithDocId({
    required this.firestoreDocId,
    required this.location,
  });
}

class AvailableProduct {
  final String productId;
  final String productName;
  final String category;
  final int totalQuantity;
  final List<LocationWithDocId> locations;
  final String? partNumber;
  final String? brand;
  final double? price;

  AvailableProduct({
    required this.productId,
    required this.productName,
    required this.category,
    required this.totalQuantity,
    required this.locations,
    this.partNumber,
    this.brand,
    this.price,
  });
}

class DeductionResult {
  final bool success;
  final String message;
  final List<Map<String, dynamic>> deductionLog;

  DeductionResult({
    required this.success,
    required this.message,
    this.deductionLog = const [],
  });
}

class WarehouseDeductionDao {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== STREAM LISTENERS ====================

  /// Get real-time stream of products collection
  Stream<QuerySnapshot> getProductsStream() {
    return _firestore.collection('products').snapshots();
  }

  /// Get real-time stream of occupied warehouse locations
  Stream<QuerySnapshot> getOccupiedWarehouseLocationsStream() {
    return _firestore
        .collection('warehouseLocations')
        .where('isOccupied', isEqualTo: true)
        .snapshots();
  }

  // ==================== DATA PROCESSING ====================

  /// Process warehouse snapshot to create available products list
  List<AvailableProduct> processWarehouseSnapshot(
      QuerySnapshot warehouseSnapshot,
      Map<String, Map<String, dynamic>> productsCache,
      ) {
    try {
      print('Processing warehouse snapshot: ${warehouseSnapshot.docs.length} documents');

      // Step 1: Create locations with document IDs that have stock
      final locationsWithDocIds = <LocationWithDocId>[];

      for (var doc in warehouseSnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final location = WarehouseLocation.fromFirestore(data);

          if (location.quantityStored != null && location.quantityStored! > 0) {
            locationsWithDocIds.add(LocationWithDocId(
              firestoreDocId: doc.id,
              location: location,
            ));
          }
        } catch (e) {
          print('Error converting document ${doc.id}: $e');
        }
      }

      print('Successfully converted ${locationsWithDocIds.length} locations with stock');

      if (locationsWithDocIds.isEmpty) {
        return [];
      }

      // Step 2: Group by product ID
      final Map<String, List<LocationWithDocId>> groupedByProduct = {};
      for (final item in locationsWithDocIds) {
        if (item.location.productId != null) {
          groupedByProduct.putIfAbsent(item.location.productId!, () => []).add(item);
        }
      }

      print('Grouped into ${groupedByProduct.length} unique products');

      // Step 3: Create available products list
      final List<AvailableProduct> products = [];

      for (final entry in groupedByProduct.entries) {
        final productId = entry.key;
        final locationsWithIds = entry.value;

        // Calculate total quantity available
        final totalQuantity = locationsWithIds.fold<int>(
            0,
                (sum, item) => sum + (item.location.quantityStored ?? 0)
        );

        // Skip products with zero quantity
        if (totalQuantity <= 0) continue;

        // Get product details from products collection
        final productData = productsCache[productId];

        final product = AvailableProduct(
          productId: productId,
          productName: productData?['productName'] ??
              productData?['name'] ??
              locationsWithIds.first.location.productName ??
              'Unknown Product ($productId)',
          category: productData?['category'] ??
              productData?['type'] ??
              'Unknown',
          partNumber: productData?['partNumber'] ??
              productData?['sku'] ??
              'N/A',
          brand: productData?['brand'] ??
              productData?['manufacturer'],
          price: productData?['price']?.toDouble() ??
              productData?['unitPrice']?.toDouble(),
          totalQuantity: totalQuantity,
          locations: locationsWithIds,
        );

        products.add(product);
      }

      // Sort products by name
      products.sort((a, b) => a.productName.compareTo(b.productName));

      return products;

    } catch (e) {
      print('Error processing warehouse snapshot: $e');
      throw Exception('Failed to process warehouse data: $e');
    }
  }

  /// Update products cache from snapshot
  Map<String, Map<String, dynamic>> updateProductsCache(QuerySnapshot snapshot) {
    final cache = <String, Map<String, dynamic>>{};
    for (var doc in snapshot.docs) {
      cache[doc.id] = doc.data() as Map<String, dynamic>;
    }
    return cache;
  }

  // ==================== DEDUCTION OPERATIONS ====================

  /// Process quantity deduction across multiple warehouse locations
  Future<DeductionResult> processQuantityDeduction({
    required AvailableProduct product,
    required int quantityToDeduct,
    required String reason,
  }) async {
    try {
      print('Processing deduction for ${product.productName}: $quantityToDeduct units');

      // Sort locations by quantity (ascending) to deduct from smallest quantities first
      final sortedLocations = List<LocationWithDocId>.from(product.locations);
      sortedLocations.sort((a, b) =>
          (a.location.quantityStored ?? 0).compareTo(b.location.quantityStored ?? 0)
      );

      int remainingToDeduct = quantityToDeduct;
      List<Map<String, dynamic>> deductionLog = [];

      // Start a batch operation for consistency
      final batch = _firestore.batch();

      // Process deduction across locations
      for (final location in sortedLocations) {
        if (remainingToDeduct <= 0) break;

        final availableInLocation = location.location.quantityStored ?? 0;
        if (availableInLocation <= 0) continue;

        final deductFromLocation = remainingToDeduct > availableInLocation
            ? availableInLocation
            : remainingToDeduct;

        final newQuantity = availableInLocation - deductFromLocation;

        // Update the warehouse location
        final currentTimestamp = DateTime.now();
        batch.update(
            _firestore.collection('warehouseLocations').doc(location.firestoreDocId),
            {
              'quantityStored': newQuantity,
              'isOccupied': newQuantity > 0,
              'lastModified': FieldValue.serverTimestamp(),
              'modificationHistory': FieldValue.arrayUnion([{
                'action': 'quantity_deducted',
                'previousQuantity': availableInLocation,
                'newQuantity': newQuantity,
                'deductedQuantity': deductFromLocation,
                'reason': reason,
                'timestamp': Timestamp.fromDate(currentTimestamp),
              }]),
            }
        );

        // Update ProductItems status if needed
        await _updateProductItemsForDeduction(
          location.location.purchaseOrderId,
          product.productId,
          deductFromLocation,
          batch,
        );

        // Log this deduction
        deductionLog.add({
          'locationId': location.location.locationId,
          'deductedQuantity': deductFromLocation,
          'previousQuantity': availableInLocation,
          'newQuantity': newQuantity,
        });

        remainingToDeduct -= deductFromLocation;
      }

      // Commit the batch
      await batch.commit();

      print('Successfully processed deduction: ${deductionLog.length} locations updated');

      return DeductionResult(
        success: true,
        message: 'Deduction completed successfully! Updated ${deductionLog.length} locations.',
        deductionLog: deductionLog,
      );

    } catch (e) {
      print('Error processing deduction: $e');
      return DeductionResult(
        success: false,
        message: 'Failed to process deduction: $e',
      );
    }
  }

  /// Update ProductItems status when quantities are deduced
  Future<void> _updateProductItemsForDeduction(
      String? purchaseOrderId,
      String productId,
      int quantityDeducted,
      WriteBatch batch,
      ) async {
    if (purchaseOrderId == null) return;

    try {
      // Query ProductItems with status 'stored' for this PO and product
      final snapshot = await _firestore
          .collection('productItems')
          .where('purchaseOrderId', isEqualTo: purchaseOrderId)
          .where('productId', isEqualTo: productId)
          .where('status', isEqualTo: ProductItemStatus.stored)
          .limit(quantityDeducted)
          .get();

      print('Found ${snapshot.docs.length} ProductItems to update for deduction');

      // Update status from 'stored' to 'issued' for the deducted quantity
      int updatedCount = 0;
      for (final doc in snapshot.docs) {
        if (updatedCount >= quantityDeducted) break;

        batch.update(doc.reference, {
          'status': ProductItemStatus.issued,
        });

        updatedCount++;
      }

      print('Updated $updatedCount ProductItems from "stored" to "issued"');

    } catch (e) {
      print('Error updating ProductItems for deduction: $e');
      // Don't throw error here as it's not critical for warehouse location update
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Get product details by ID
  Future<Map<String, dynamic>?> getProductById(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('Error getting product $productId: $e');
      return null;
    }
  }

  /// Check if product has sufficient quantity for deduction
  bool canDeductQuantity(AvailableProduct product, int requestedQuantity) {
    return requestedQuantity > 0 && requestedQuantity <= product.totalQuantity;
  }

  /// Get deduction history for a location
  Future<List<Map<String, dynamic>>> getDeductionHistory(String locationId) async {
    try {
      final doc = await _firestore
          .collection('warehouseLocations')
          .doc(locationId)
          .get();

      if (!doc.exists) return [];

      final data = doc.data() as Map<String, dynamic>;
      final history = data['modificationHistory'] as List<dynamic>? ?? [];

      return history
          .cast<Map<String, dynamic>>()
          .where((entry) => entry['action'] == 'quantity_deducted')
          .toList();

    } catch (e) {
      print('Error getting deduction history: $e');
      return [];
    }
  }

  /// Validate deduction request
  String? validateDeductionRequest({
    required AvailableProduct? product,
    required int quantity,
    required String reason,
  }) {
    if (product == null) {
      return 'Please select a product';
    }

    if (quantity <= 0) {
      return 'Please enter a valid quantity';
    }

    if (quantity > product.totalQuantity) {
      return 'Cannot exceed available quantity (${product.totalQuantity})';
    }

    if (reason.trim().isEmpty) {
      return 'Please provide a reason for deduction';
    }

    return null; // No validation errors
  }

  static Future<Map<String, dynamic>> getProductDetailsForPartNumber({
    required String partNumber,
  }) async {
    try {
      // 🔹 Fetch product document (doc snapshot, not just data)
      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(partNumber)
          .get();

      if (!productDoc.exists) {
        return {
          'success': false,
          'productDoc': null,
          'product': null,
          'productData': null,
          'totalQuantity': 0,
          'locationsCount': 0,
          'error': 'Product not found',
        };
      }

      // 🔹 Fetch warehouse locations for this product
      final warehouseQuery = await FirebaseFirestore.instance
          .collection('warehouseLocations')
          .where('productId', isEqualTo: partNumber)
          .where('isOccupied', isEqualTo: true)
          .get();

      // Process locations
      final locationsWithDocIds = <LocationWithDocId>[];
      int totalQuantity = 0;

      for (var doc in warehouseQuery.docs) {
        try {
          final data = doc.data();
          final location = WarehouseLocation.fromFirestore(data);

          if (location.quantityStored != null && location.quantityStored! > 0) {
            locationsWithDocIds.add(LocationWithDocId(
              firestoreDocId: doc.id,
              location: location,
            ));
            totalQuantity += location.quantityStored!;
          }
        } catch (e) {
          print('Error converting document ${doc.id}: $e');
        }
      }

      // 🔹 Build AvailableProduct model
      final productData = productDoc.data()!;
      final availableProduct = AvailableProduct(
        productId: partNumber,
        productName: productData['name'] ?? 'Unknown Product ($partNumber)',
        category: productData['category'] ?? 'Unknown',
        partNumber: productData['partNumber'] ?? partNumber,
        brand: productData['brand'] ?? 'Unknown',
        price: (productData['price'] is int)
            ? (productData['price'] as int).toDouble()
            : (productData['price']?.toDouble() ?? 0.0),
        totalQuantity: totalQuantity,
        locations: locationsWithDocIds,
      );

      return {
        'success': true,
        'productDoc': productDoc, // 🔹 full doc snapshot
        'product': availableProduct,
        'productData': productData,
        'totalQuantity': totalQuantity,
        'locationsCount': locationsWithDocIds.length,
        'error': null,
      };
    } catch (e) {
      return {
        'success': false,
        'productDoc': null,
        'product': null,
        'productData': null,
        'totalQuantity': 0,
        'locationsCount': 0,
        'error': e.toString(),
      };
    }
  }
}