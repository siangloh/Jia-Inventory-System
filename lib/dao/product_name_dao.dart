// lib/dao/product_name_dao.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/product_name_model.dart';
import '../services/statistics/product_name_statistic_service.dart';

class ProductNameDao {
  static const String _collectionName = 'productNames';
  static const String _carPartsCollection = 'carParts';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ProductNameStatisticsService _statisticsService =
      ProductNameStatisticsService();

  Future<bool> refreshProductNames() async {
    try {
      // Force a fresh query with offline persistence disabled temporarily
      final snapshot = await _firestore
          .collection(_collectionName)
          .orderBy('createdAt', descending: true)
          .get(const GetOptions(source: Source.server));

      // Clear any local cache if you have one
      final productNames = snapshot.docs
          .map((doc) => ProductNameModel.fromJson(doc.data())..id = doc.id)
          .toList();

      // Update the stream controller or local state
      // If using a stream controller:
      // _productNamesController.add(productNames);

      print('✅ Refreshed ${productNames.length} product names from Firebase');
      return true;
    } catch (e) {
      print('❌ Refresh product names error: $e');
      return false;
    }
  }

  // Stream for real-time updates
  Stream<List<ProductNameModel>> getProductNamesStream() {
    return _firestore
        .collection(_collectionName)
        .orderBy('productName')
        .snapshots()
        .map((snapshot) {
      final List<ProductNameModel> names = [];

      for (var doc in snapshot.docs) {
        try {
          final productName =
              ProductNameModel.fromFirestore(doc.id, doc.data());
          names.add(productName);
        } catch (e) {
          print('Error parsing product name ${doc.id}: $e');
        }
      }

      return names;
    });
  }

  // Get product names with real-time usage counts
  Stream<List<ProductNameModel>> getProductNamesWithUsageStream() {
    return getProductNamesStream().asyncMap((productNames) async {
      try {
        final statistics = await _statisticsService.getCurrentStatistics();

        return productNames.map((productName) {
          final usageStats = statistics.usageStats[productName.productName];
          if (usageStats != null) {
            return productName.copyWith(
              usageCount: usageStats.usageCount,
            );
          }
          return productName.copyWith(usageCount: 0);
        }).toList()
          ..sort((a, b) => a.productName.compareTo(b.productName));
      } catch (e) {
        print('Error getting usage statistics: $e');
        // Return product names without usage counts if statistics fail
        return productNames;
      }
    });
  }

  // Get all product names (one-time fetch)
  Future<List<ProductNameModel>> getAllProductNames() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .orderBy('productName')
          .get();

      final List<ProductNameModel> names = [];

      for (var doc in snapshot.docs) {
        try {
          final productName =
              ProductNameModel.fromFirestore(doc.id, doc.data());
          names.add(productName);
        } catch (e) {
          print('Error parsing product name ${doc.id}: $e');
        }
      }

      return names;
    } catch (e) {
      throw Exception('Failed to fetch product names: $e');
    }
  }

  // Get all product names with usage counts
  Future<List<ProductNameModel>> getAllProductNamesWithUsage() async {
    try {
      final productNames = await getAllProductNames();
      final usageCounts = await getUsageCounts();

      return productNames.map((productName) {
        final usageCount = usageCounts[productName.productName] ?? 0;
        return productName.copyWith(usageCount: usageCount);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch product names with usage: $e');
    }
  }

  // Create new product name
  Future<bool> createProductName(ProductNameModel productName) async {
    final prefix = "proName"; // fixed prefix
    final collection = _firestore.collection(_collectionName);

    return _firestore.runTransaction((transaction) async {
      // Step 1: Check if name already exists
      final existingQuery = await collection
          .where('productName', isEqualTo: productName.productName)
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        return false;
      }

      // Step 2: Get last document ID starting with "proName_"
      final query = await collection
          .orderBy(FieldPath.documentId, descending: true)
          .startAt(['${prefix}_\uf8ff']) // upper bound
          .endAt([prefix]) // lower bound
          .limit(1)
          .get();

      int nextNumber = 1;

      if (query.docs.isNotEmpty) {
        final lastId = query.docs.first.id; // e.g. proName_0007
        final lastNumberStr = lastId.split('_').last; // "0007"
        final lastNumber = int.tryParse(lastNumberStr) ?? 0;
        nextNumber = lastNumber + 1;
      }

      // Step 3: Format new custom ID
      final customId = "${prefix}_${nextNumber.toString().padLeft(4, '0')}";

      // Step 4: Create the document with custom ID
      final docRef = collection.doc(customId);
      transaction.set(docRef, productName.toFirestore());

      return true;
    });
  }

  // Update existing product name
  Future<void> updateProductName(ProductNameModel productName) async {
    try {
      if (productName.id == null) {
        throw Exception('Product name ID cannot be null for update');
      }

      final oldDoc = await _firestore.collection(_collectionName).doc(productName.id!).get();
      if (!oldDoc.exists) {
        throw Exception('Product name with ID ${productName.id} not found');
      }
      final String oldCategoryId = oldDoc.id;

      // Check for duplicates (excluding current document)
      final existingQuery = await _firestore
          .collection(_collectionName)
          .where('productName', isEqualTo: productName.productName)
          .get();
      final duplicates =
          existingQuery.docs.where((doc) => doc.id != productName.id).toList();

      if (duplicates.isNotEmpty) {
        throw Exception(
            'Product name "${productName.productName}" already exists');
      }

      if (oldCategoryId != null && oldCategoryId != productName.category) {
        final productsQuery = await _firestore
            .collection('products')
            .where('name', isEqualTo: productName.id) // product refers to productNameId
            .get();

        for (final productDoc in productsQuery.docs) {
          await productDoc.reference.update({
            'category': productName.category,
          });
          print('Updated product ${productDoc.id} with new categoryId: ${productName.category}');
        }
      }

      await _firestore.collection(_collectionName).doc(productName.id!).update(
          productName.copyWith(updatedAt: DateTime.now()).toFirestore());
    } catch (e) {
      throw Exception('Failed to update product name: $e');
    }
  }

  // Delete product name (with usage check)
  Future<void> deleteProductName(String productNameId) async {
    try {
      // First get the product name to check its usage
      final productNameDoc =
          await _firestore.collection(_collectionName).doc(productNameId).get();

      if (!productNameDoc.exists) {
        throw Exception('Product name not found');
      }

      final productNameData = ProductNameModel.fromFirestore(
        productNameDoc.id,
        productNameDoc.data() as Map<String, dynamic>,
      );

      // Check usage count
      final usageCount = await _statisticsService
          .getProductNameUsageCount(productNameData.productName);

      if (usageCount > 0) {
        throw Exception(
            'Cannot delete product name "${productNameData.productName}". It is used by $usageCount car parts.');
      }

      await _firestore.collection(_collectionName).doc(productNameId).delete();
    } catch (e) {
      throw Exception('Failed to delete product name: $e');
    }
  }

  // Toggle product name status (active/inactive)
  Future<void> toggleProductNameStatus(
      String productNameId, bool currentStatus) async {
    try {
      await _firestore.collection(_collectionName).doc(productNameId).update({
        'isActive': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to toggle product name status: $e');
    }
  }

  // Get usage counts for product names
  Future<Map<String, int>> getUsageCounts() async {
    try {
      return await _statisticsService.getAllProductNameUsageCounts();
    } catch (e) {
      throw Exception('Failed to load usage counts: $e');
    }
  }

  // Get usage count for a specific product name
  Future<int> getUsageCount(String productName) async {
    try {
      return await _statisticsService.getProductNameUsageCount(productName);
    } catch (e) {
      print('Error getting usage count for $productName: $e');
      return 0;
    }
  }

  // Check if product name exists
  Future<bool> productNameExists(String productName) async {
    try {
      final query = await _firestore
          .collection(_collectionName)
          .where('productName', isEqualTo: productName)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check product name existence: $e');
    }
  }

  // Get unused product names (usage count = 0)
  Future<List<ProductNameModel>> getUnusedProductNames() async {
    try {
      final unusedStats = await _statisticsService.getUnusedProductNames();
      final List<ProductNameModel> unusedModels = [];

      // Get the full ProductNameModel for each unused name
      for (final stats in unusedStats) {
        final productName = await getProductNameById(stats.productNameId);
        if (productName != null) {
          unusedModels.add(productName.copyWith(usageCount: 0));
        }
      }

      return unusedModels;
    } catch (e) {
      throw Exception('Failed to fetch unused product names: $e');
    }
  }

  // Get top used product names
  Future<List<ProductNameUsageStats>> getTopUsedProductNames(
      {int limit = 10}) async {
    try {
      return await _statisticsService.getTopUsedProductNames(limit: limit);
    } catch (e) {
      throw Exception('Failed to get top used product names: $e');
    }
  }

  // Get product names that need attention (inactive or unused)
  Future<List<ProductNameUsageStats>> getProductNamesNeedingAttention() async {
    try {
      return await _statisticsService.getProductNamesNeedingAttention();
    } catch (e) {
      throw Exception('Failed to get product names needing attention: $e');
    }
  }

  // Check if a product name can be safely deleted
  Future<bool> canDeleteProductName(String productName) async {
    try {
      final usageCount = await getUsageCount(productName);
      return usageCount == 0;
    } catch (e) {
      print('Error checking if product name can be deleted: $e');
      return false;
    }
  }

  // Import product names from existing car parts
  Future<int> importProductNamesFromCarParts() async {
    try {
      final existingProductNames = await getAllProductNames();
      final existingNames =
          existingProductNames.map((p) => p.productName).toSet();

      final partsSnapshot =
          await _firestore.collection(_carPartsCollection).get();

      int importCount = 0;
      final batch = _firestore.batch();

      for (var doc in partsSnapshot.docs) {
        final data = doc.data();
        final productName = data['name'] as String?;
        final category = data['category'] as String?;

        if (productName != null &&
            productName.isNotEmpty &&
            !existingNames.contains(productName)) {
          // Generate custom ID like in createProductName
          final prefix = "proName";
          final collection = _firestore.collection(_collectionName);

          final query = await collection
              .orderBy(FieldPath.documentId, descending: true)
              .startAt(['${prefix}_\uf8ff'])
              .endAt([prefix])
              .limit(1)
              .get();

          int nextNumber = importCount + 1;
          if (query.docs.isNotEmpty) {
            final lastId = query.docs.first.id;
            final lastNumberStr = lastId.split('_').last;
            final lastNumber = int.tryParse(lastNumberStr) ?? 0;
            nextNumber = lastNumber + importCount + 1;
          }

          final customId = "${prefix}_${nextNumber.toString().padLeft(4, '0')}";

          final now = DateTime.now();
          final newProductName = ProductNameModel(
            productName: productName,
            description: 'Imported from existing parts',
            category: category ?? 'Unknown',
            createdAt: now,
            updatedAt: now,
            createdBy: 'system_import',
          );

          final docRef = _firestore.collection(_collectionName).doc(customId);
          batch.set(docRef, newProductName.toFirestore());

          existingNames.add(productName);
          importCount++;
        }
      }

      if (importCount > 0) {
        await batch.commit();
      }

      return importCount;
    } catch (e) {
      throw Exception('Failed to import product names: $e');
    }
  }

  // Get distinct product names (active only)
  Future<List<String>> getDistinctProductName() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where("isActive", isEqualTo: true)
          .get();

      final Set<String> productNames = {'All'};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final productName = data['productName'] as String?;
        if (productName != null && productName.isNotEmpty) {
          productNames.add(productName);
        }
      }

      final result = productNames.toList()..sort();
      return result;
    } catch (e) {
      throw Exception('Failed to fetch distinct product names: $e');
    }
  }

  // Batch delete unused product names
  Future<int> deleteUnusedProductNames() async {
    try {
      final unusedNames = await getUnusedProductNames();

      if (unusedNames.isEmpty) {
        return 0;
      }

      final batch = _firestore.batch();

      for (var productName in unusedNames) {
        if (productName.id != null) {
          final docRef =
              _firestore.collection(_collectionName).doc(productName.id!);
          batch.delete(docRef);
        }
      }

      await batch.commit();
      return unusedNames.length;
    } catch (e) {
      throw Exception('Failed to delete unused product names: $e');
    }
  }

  // Get product name by ID
  Future<ProductNameModel?> getProductNameById(String id) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(id).get();

      if (doc.exists && doc.data() != null) {
        final productName = ProductNameModel.fromFirestore(
            doc.id, Map<String, dynamic>.from(doc.data() as Map));

        // Add usage count
        final usageCount = await getUsageCount(productName.productName);
        return productName.copyWith(usageCount: usageCount);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch product name: $e');
    }
  }

  // Get product name by name
  Future<ProductNameModel?> getProductNameByName(String productName) async {
    try {
      final query = await _firestore
          .collection(_collectionName)
          .where('productName', isEqualTo: productName)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final productNameModel = ProductNameModel.fromFirestore(
            doc.id, Map<String, dynamic>.from(doc.data() as Map));

        // Add usage count
        final usageCount = await getUsageCount(productName);
        return productNameModel.copyWith(usageCount: usageCount);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch product name: $e');
    }
  }

  // Search product names
  Future<List<ProductNameModel>> searchProductNames(String query) async {
    try {
      final allNames = await getAllProductNamesWithUsage();

      if (query.isEmpty) {
        return allNames;
      }

      final filteredNames = allNames.where((productName) {
        return productName.matchesSearch(query);
      }).toList();

      return filteredNames;
    } catch (e) {
      throw Exception('Failed to search product names: $e');
    }
  }

  // Get product names by category
  Future<List<ProductNameModel>> getProductNamesByCategory(
      String category) async {
    try {
      final query = await _firestore
          .collection(_collectionName)
          .where('category', isEqualTo: category)
          .orderBy('productName')
          .get();

      final List<ProductNameModel> names = [];
      final usageCounts = await getUsageCounts();

      for (var doc in query.docs) {
        try {
          final productName =
              ProductNameModel.fromFirestore(doc.id, doc.data());
          final usageCount = usageCounts[productName.productName] ?? 0;
          names.add(productName.copyWith(usageCount: usageCount));
        } catch (e) {
          print('Error parsing product name ${doc.id}: $e');
        }
      }

      return names;
    } catch (e) {
      throw Exception('Failed to fetch product names by category: $e');
    }
  }

  // Get active product names only
  Future<List<ProductNameModel>> getActiveProductNames() async {
    try {
      final query = await _firestore
          .collection(_collectionName)
          .where('isActive', isEqualTo: true)
          .orderBy('productName')
          .get();

      final List<ProductNameModel> names = [];
      final usageCounts = await getUsageCounts();

      for (var doc in query.docs) {
        try {
          final productName =
              ProductNameModel.fromFirestore(doc.id, doc.data());
          final usageCount = usageCounts[productName.productName] ?? 0;
          names.add(productName.copyWith(usageCount: usageCount));
        } catch (e) {
          print('Error parsing product name ${doc.id}: $e');
        }
      }

      return names;
    } catch (e) {
      throw Exception('Failed to fetch active product names: $e');
    }
  }

  // Bulk update usage counts (useful for data migration or correction)
  Future<void> updateUsageCounts() async {
    try {
      final usageCounts = await getUsageCounts();
      final WriteBatch batch = _firestore.batch();
      int updateCount = 0;

      for (final entry in usageCounts.entries) {
        final productName = entry.key;
        final usageCount = entry.value;

        // Find the product name document
        final QuerySnapshot snapshot = await _firestore
            .collection(_collectionName)
            .where('productName', isEqualTo: productName)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final docRef = snapshot.docs.first.reference;
          batch.update(docRef, {
            'usageCount': usageCount,
            'updatedAt': DateTime.now(),
          });
          updateCount++;
        }
      }

      if (updateCount > 0) {
        await batch.commit();
        print('Updated usage counts for $updateCount product names');
      }
    } catch (e) {
      throw Exception('Failed to update usage counts: $e');
    }
  }

  // Get statistics service instance
  ProductNameStatisticsService get statisticsService => _statisticsService;

  // Get usage efficiency (percentage of active product names that are used)
  Future<double> getUsageEfficiency() async {
    try {
      return await _statisticsService.getUsageEfficiency();
    } catch (e) {
      print('Error calculating usage efficiency: $e');
      return 0.0;
    }
  }

  // Get current statistics
  Future<ProductNameStatistics> getCurrentStatistics() async {
    try {
      return await _statisticsService.getCurrentStatistics();
    } catch (e) {
      throw Exception('Failed to get current statistics: $e');
    }
  }

  // Get category statistics
  Future<CategoryNameStats?> getCategoryStatistics(String categoryName) async {
    try {
      return await _statisticsService.getCategoryNameStatistics(categoryName);
    } catch (e) {
      print('Error getting category statistics for $categoryName: $e');
      return null;
    }
  }

  // Cleanup method - remove product names with 0 usage and inactive status
  Future<int> cleanupInactiveUnusedProductNames() async {
    try {
      final allNames = await getAllProductNamesWithUsage();
      final toDelete = allNames
          .where((name) => !name.isActive && name.usageCount == 0)
          .toList();

      if (toDelete.isEmpty) {
        return 0;
      }

      final batch = _firestore.batch();
      for (var productName in toDelete) {
        if (productName.id != null) {
          final docRef =
              _firestore.collection(_collectionName).doc(productName.id!);
          batch.delete(docRef);
        }
      }

      await batch.commit();
      return toDelete.length;
    } catch (e) {
      throw Exception('Failed to cleanup inactive unused product names: $e');
    }
  }

  Future<int> migrateProductsToIdReferences() async {
    try {
      final WriteBatch batch = _firestore.batch();
      int migratedCount = 0;

      // Get all products
      final QuerySnapshot productsSnapshot =
          await _firestore.collection('products').get();

      // Get reference data
      final Map<String, String> productNameToId =
          await _getProductNameMapping();
      final Map<String, String> brandNameToId = await _getBrandMapping();
      final Map<String, String> categoryNameToId = await _getCategoryMapping();

      for (final doc in productsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final Map<String, dynamic> updates = {};

        // Migrate productName to productNameId
        final String? productName = data['productName'] as String?;
        if (productName != null && productNameToId.containsKey(productName)) {
          updates['productNameId'] = productNameToId[productName];
          // Optionally remove old field: updates.remove('productName');
        }

        // Migrate brand to brandId
        final String? brand = data['brand'] as String?;
        if (brand != null && brandNameToId.containsKey(brand)) {
          updates['brandId'] = brandNameToId[brand];
        }

        // Migrate category to categoryId
        final String? category = data['category'] as String?;
        if (category != null && categoryNameToId.containsKey(category)) {
          updates['categoryId'] = categoryNameToId[category];
        }

        if (updates.isNotEmpty) {
          updates['migratedAt'] = FieldValue.serverTimestamp();
          batch.update(doc.reference, updates);
          migratedCount++;
        }
      }

      if (migratedCount > 0) {
        await batch.commit();
      }

      return migratedCount;
    } catch (e) {
      throw Exception('Failed to migrate products: $e');
    }
  }

  Future<Map<String, String>> _getProductNameMapping() async {
    final QuerySnapshot snapshot =
        await _firestore.collection('productNames').get();

    final Map<String, String> mapping = {};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final String? productName = data['productName'] as String?;
      if (productName != null) {
        mapping[productName] = doc.id;
      }
    }
    return mapping;
  }

  Future<Map<String, String>> _getBrandMapping() async {
    final QuerySnapshot snapshot = await _firestore.collection('brands').get();

    final Map<String, String> mapping = {};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final String? brandName = data['brandName'] as String?;
      if (brandName != null) {
        mapping[brandName] = doc.id;
      }
    }
    return mapping;
  }

  Future<Map<String, String>> _getCategoryMapping() async {
    final QuerySnapshot snapshot =
        await _firestore.collection('categories').get();

    final Map<String, String> mapping = {};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final String? categoryName = data['name'] as String?;
      if (categoryName != null) {
        mapping[categoryName] = doc.id;
      }
    }
    return mapping;
  }


}
