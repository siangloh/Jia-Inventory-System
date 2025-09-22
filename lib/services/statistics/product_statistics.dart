import 'package:assignment/models/product_item.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product_category_model.dart';

class ProductStatistics {
  final int totalItems;
  final int availableItems;
  final int damagedItems;
  final int outOfStockItems;
  final int productCount;
  final Map<String, CategoryProductStats> categoryStats;

  ProductStatistics({
    required this.totalItems,
    required this.availableItems,
    required this.damagedItems,
    required this.outOfStockItems,
    required this.categoryStats,
    required this.productCount,
  });

  @override
  String toString() {
    return 'ProductStatistics(total: $totalItems, available: $availableItems, damaged: $damagedItems, outOfStock: $outOfStockItems, categories: ${categoryStats.length})';
  }
}

class CategoryProductStats {
  final String categoryId;
  final String categoryName;
  final int totalItems;
  final int availableItems;
  final int damagedItems;
  final int outOfStockItems;
  final int? productCount;
  final String iconName;
  final Color color;
  final int lowStockProducts;

  CategoryProductStats({
    required this.categoryId,
    required this.categoryName,
    required this.totalItems,
    required this.availableItems,
    required this.damagedItems,
    required this.outOfStockItems,
    required this.lowStockProducts,
    this.productCount,
    required this.iconName,
    required this.color,
  });

  int get safeProductCount => productCount ?? 0;

  @override
  String toString() {
    return 'CategoryProductStats($categoryName: $productCount products, $totalItems items, available=$availableItems, damaged=$damagedItems, outOfStock=$outOfStockItems)';
  }
}

class ProductStatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ ADDED: Force refresh method for fresh server data
  Future<bool> refreshStatistics() async {
    try {
      print('🔄 Forcing product statistics refresh from Firebase servers...');

      // Force server-only query to bypass cache
      final productItemsSnapshot = await _firestore
          .collection('productItems')
          .get(const GetOptions(source: Source.server));

      print(
          '🔥 Fetched ${productItemsSnapshot.docs.length} product items from server');

      // Calculate fresh statistics
      final freshStats = await _calculateStatistics(productItemsSnapshot.docs);

      print(
          '✅ Product statistics refreshed successfully: ${freshStats.totalItems} total items');
      return true;
    } catch (e) {
      print('❌ Product statistics refresh failed: $e');
      return false;
    }
  }

  /// Get real-time product statistics stream
  Stream<ProductStatistics> getProductStatisticsStream() {
    return _firestore
        .collection('productItems')
        .snapshots()
        .asyncMap((snapshot) => _calculateStatistics(snapshot.docs));
  }

  /// Get statistics for a specific category
  Stream<CategoryProductStats?> getCategoryStatisticsStream(String categoryId) {
    return getProductStatisticsStream()
        .map((stats) => stats.categoryStats[categoryId]);
  }

  /// ✅ FIXED: Calculate comprehensive statistics with correct category mapping
  Future<ProductStatistics> _calculateStatistics(
      List<QueryDocumentSnapshot> productItemsDocs) async {
    print(
        '🔄 Calculating statistics for ${productItemsDocs.length} product items');

    if (productItemsDocs.isEmpty) {
      return ProductStatistics(
        totalItems: 0,
        availableItems: 0,
        damagedItems: 0,
        outOfStockItems: 0,
        productCount: 0,
        categoryStats: {},
      );
    }

    // Step 1: Extract unique product IDs from product items
    final Set<String> productIds = {};
    for (final doc in productItemsDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final productId = data['productId'] as String?;
      if (productId != null && productId.isNotEmpty) {
        productIds.add(productId);
      }
    }

    print('✅ Found ${productIds.length} unique products from items');

    if (productIds.isEmpty) {
      return ProductStatistics(
        totalItems: productItemsDocs.length,
        availableItems: productItemsDocs.length,
        damagedItems: 0,
        productCount: 0,
        outOfStockItems: 0,
        categoryStats: {},
      );
    }

    // Step 2: ✅ FIXED - Get product details with category IDs in batches
    final Map<String, Map<String, dynamic>> productMap = {};
    final List<List<String>> productIdBatches =
        _createBatches(productIds.toList(), 10);

    for (final batch in productIdBatches) {
      try {
        print('🔄 Fetching products batch: ${batch.length} IDs');
        final QuerySnapshot productSnapshot = await _firestore
            .collection('products')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in productSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          productMap[doc.id] = {
            'id': doc.id,
            'categoryId': data['category'] as String?,
            // ✅ This is the category ID
            ...data,
          };
          print('✅ Mapped product ${doc.id} to category ${data['category']}');
        }
      } catch (e) {
        print('❌ Error fetching products batch: $e');
      }
    }

    print('✅ Successfully mapped ${productMap.length} products');

    // Step 3: ✅ FIXED - Get category details using category IDs
    final Map<String, CategoryModel> categoryMap = {};
    final Set<String> categoryIds = {};

    // Extract all unique category IDs from products
    for (final product in productMap.values) {
      final String? categoryId = product['categoryId'] as String?;
      if (categoryId != null && categoryId.isNotEmpty) {
        categoryIds.add(categoryId);
      }
    }

    print('✅ Found ${categoryIds.length} unique category IDs');

    // Fetch category documents using category IDs
    if (categoryIds.isNotEmpty) {
      final List<List<String>> categoryIdBatches =
          _createBatches(categoryIds.toList(), 10);

      for (final batch in categoryIdBatches) {
        try {
          print('🔄 Fetching categories batch: ${batch.length} IDs');
          final QuerySnapshot categorySnapshot = await _firestore
              .collection('categories')
              .where(FieldPath.documentId, whereIn: batch)
              .get();

          for (final doc in categorySnapshot.docs) {
            try {
              final category = CategoryModel.fromFirestore(
                  doc.id, doc.data() as Map<String, dynamic>);
              categoryMap[doc.id] = category;
              print('✅ Loaded category: ${category.name} (ID: ${doc.id})');
            } catch (e) {
              print('❌ Error parsing category ${doc.id}: $e');
            }
          }
        } catch (e) {
          print('❌ Error fetching categories batch: $e');
        }
      }
    }

    print('✅ Successfully loaded ${categoryMap.length} categories');

    // Step 4: ✅ FIXED - Count unique products per category
    final Map<String, int> categoryProductCounts = {};
    for (final categoryId in categoryIds) {
      final int productCount = productMap.values
          .where((product) => product['categoryId'] == categoryId)
          .length;
      categoryProductCounts[categoryId] = productCount;
      print('📊 Category $categoryId: $productCount products');
    }

    // Step 5: Initialize overall counters
    int totalItems = 0;
    int availableItems = 0;
    int damagedItems = 0;
    int outOfStockItems = 0;
    int productCount = productMap.length; // Total unique products

// Step 6: Process each product item - ONLY for category mapping and available count
    final Map<String, Map<String, int>> categoryCounters = {};
    final Map<String, int> productAvailableCount = {};

// Process each product item
    for (final doc in productItemsDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final String? productId = data['productId'] as String?;
      final String rawStatus = (data['status'] as String? ?? '').toLowerCase();

      if (productId == null || productId.isEmpty || !productMap.containsKey(productId)) {
        totalItems++; // Count orphan items
        continue;
      }

      totalItems++;

      // Convert Firestore string to enum safely
      ProductItemsStatus? status;
      try {
        status = ProductItemsStatus.values.firstWhere(
              (e) => e.name.toLowerCase() == rawStatus,
          orElse: () => ProductItemsStatus.pending,
        );
      } catch (_) {
        status = ProductItemsStatus.pending;
      }

      // Only count available items for low stock calculation
      if (status == ProductItemsStatus.stored || status == ProductItemsStatus.received) {
        productAvailableCount.putIfAbsent(productId, () => 0);
        productAvailableCount[productId] = productAvailableCount[productId]! + 1;
      }

      // Get category ID from product mapping
      final product = productMap[productId]!;
      final String? categoryId = product['categoryId'] as String?;

      if (categoryId != null && categoryId.isNotEmpty && categoryMap.containsKey(categoryId)) {
        // Initialize counters for this category
        categoryCounters.putIfAbsent(
          categoryId,
              () => {'total': 0, 'available': 0, 'damaged': 0, 'outOfStock': 0},
        );

        categoryCounters[categoryId]!['total'] = categoryCounters[categoryId]!['total']! + 1;

        // Count by status for this category
        switch (status) {
          case ProductItemsStatus.stored:
          case ProductItemsStatus.received:
            categoryCounters[categoryId]!['available'] =
                categoryCounters[categoryId]!['available']! + 1;
            break;
          case ProductItemsStatus.damaged:
            categoryCounters[categoryId]!['damaged'] =
                categoryCounters[categoryId]!['damaged']! + 1;
            break;
          case ProductItemsStatus.pending:
          // Pending doesn't count as out of stock
            break;
          default:
            categoryCounters[categoryId]!['outOfStock'] =
                categoryCounters[categoryId]!['outOfStock']! + 1;
            break;
        }
      }
    }

// Calculate global counters AFTER processing all items
    for (final doc in productItemsDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final String? productId = data['productId'] as String?;
      final String rawStatus = (data['status'] as String? ?? '').toLowerCase();

      if (productId == null || productId.isEmpty || !productMap.containsKey(productId)) {
        continue; // Already counted as totalItems
      }

      final status = ProductItemsStatus.values.firstWhere(
            (e) => e.name.toLowerCase() == rawStatus,
        orElse: () => ProductItemsStatus.pending,
      );

      switch (status) {
        case ProductItemsStatus.stored:
        case ProductItemsStatus.received:
          availableItems++;
          break;
        case ProductItemsStatus.damaged:
          damagedItems++;
          break;
        default:
        // Don't count pending as out of stock here
          break;
      }
    }

// ✅ NEW: Count out-of-stock based on low stock products (< 5 available)
    const int lowStockThreshold = 5;
    int totalLowStockItems = 0;
    final Set<String> lowStockProducts = {};
    for (final entry in productAvailableCount.entries) {
      final productId = entry.key;
      final available = entry.value;

      if (available <= lowStockThreshold && available > 0) {
        totalLowStockItems += available;
        lowStockProducts.add(productId);
        print("⚠️ Product $productId is LOW STOCK ($available items available)");
      }
    }

// Set out of stock items = number of low stock products
//     outOfStockItems = lowStockProducts.length;
    outOfStockItems = totalLowStockItems;
    print("📊 Out of stock items set to: $outOfStockItems (low stock products)");
    // Step 7: ✅ FIXED - Build final category statistics
    final Map<String, CategoryProductStats> categoryStats = {};

    for (final entry in categoryCounters.entries) {
      final categoryId = entry.key;
      final counters = entry.value;
      final category = categoryMap[categoryId];
      final int productCountForCategory =
          categoryProductCounts[categoryId] ?? 0;
      final int categoryLowStockItems = lowStockProducts
          .where((pId) => productMap[pId]?['categoryId'] == categoryId)
          .map((pId) => productAvailableCount[pId] ?? 0)
          .fold(0, (sum, count) => sum + count);

      if (category != null) {
        categoryStats[categoryId] = CategoryProductStats(
          categoryId: categoryId,
          categoryName: category.name,
          totalItems: counters['total'] ?? 0,
          availableItems: counters['available'] ?? 0,
          damagedItems: counters['damaged'] ?? 0,
          // outOfStockItems: counters['outOfStock'] ?? 0,
          productCount: productCountForCategory,
          iconName: category.iconName,
          color: category.color,
          lowStockProducts: lowStockProducts.where(
                  (pId) => productMap[pId]?['categoryId'] == categoryId
          ).length,
          outOfStockItems: categoryLowStockItems,
        );

        print(
            '✅ Category stats for ${category.name}: ${counters['total']} items, $productCountForCategory products');
      }
    }

    // Add categories with products but no items
    for (final categoryId in categoryProductCounts.keys) {
      if (!categoryCounters.containsKey(categoryId) &&
          categoryMap.containsKey(categoryId)) {
        final category = categoryMap[categoryId]!;
        final productCount = categoryProductCounts[categoryId]!;

        if (productCount > 0) {
          categoryStats[categoryId] = CategoryProductStats(
            categoryId: categoryId,
            categoryName: category.name,
            totalItems: 0,
            availableItems: 0,
            damagedItems: 0,
            outOfStockItems: 0,
            productCount: productCount,
            iconName: category.iconName,
            color: category.color,
            lowStockProducts: lowStockProducts
                .where((pId) => productMap[pId]?['categoryId'] == categoryId)
                .length,
          );

          print(
              'ℹ️  Added empty category ${category.name} with $productCount products');
        }
      }
    }

    final result = ProductStatistics(
      totalItems: totalItems,
      availableItems: availableItems,
      damagedItems: damagedItems,
      outOfStockItems: outOfStockItems,
      categoryStats: categoryStats,
      productCount: productCount,
    );

    print('🎉 Statistics calculated successfully: $result');
    return result;
  }

  /// Helper method to create batches for Firestore 'in' queries
  List<List<T>> _createBatches<T>(List<T> items, int batchSize) {
    if (items.isEmpty) return [];

    final List<List<T>> batches = [];
    for (int i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      batches.add(items.sublist(i, end));
    }
    return batches;
  }

  /// ✅ ADDED: Get fresh statistics (server-only)
  Future<ProductStatistics> getFreshStatistics() async {
    try {
      print('🔄 Getting fresh product statistics from server...');

      final productItemsSnapshot = await _firestore
          .collection('productItems')
          .get(const GetOptions(source: Source.server));

      return await _calculateStatistics(productItemsSnapshot.docs);
    } catch (e) {
      print('❌ Fresh statistics fetch failed: $e');
      // Fallback to cached data
      final fallbackSnapshot =
          await _firestore.collection('productItems').get();
      return await _calculateStatistics(fallbackSnapshot.docs);
    }
  }

  /// Get statistics for multiple categories
  Future<Map<String, CategoryProductStats>> getCategoriesStatistics(
      List<String> categoryIds) async {
    try {
      final stats = await getProductStatisticsStream().first;

      final Map<String, CategoryProductStats> result = {};
      for (final categoryId in categoryIds) {
        if (stats.categoryStats.containsKey(categoryId)) {
          result[categoryId] = stats.categoryStats[categoryId]!;
        }
      }

      return result;
    } catch (e) {
      print('Error getting categories statistics: $e');
      return {};
    }
  }

  /// Get top categories by total items
  Future<List<CategoryProductStats>> getTopCategoriesByItems(
      {int limit = 5}) async {
    try {
      final stats = await getProductStatisticsStream().first;

      final List<CategoryProductStats> categoryList =
          stats.categoryStats.values.toList();
      categoryList.sort((a, b) => b.totalItems.compareTo(a.totalItems));

      return categoryList.take(limit).toList();
    } catch (e) {
      print('Error getting top categories: $e');
      return [];
    }
  }

  /// Get categories with damaged items
  Future<List<CategoryProductStats>> getCategoriesWithDamagedItems() async {
    try {
      final stats = await getProductStatisticsStream().first;

      return stats.categoryStats.values
          .where((categoryStats) => categoryStats.damagedItems > 0)
          .toList()
        ..sort((a, b) => b.damagedItems.compareTo(a.damagedItems));
    } catch (e) {
      print('Error getting categories with damaged items: $e');
      return [];
    }
  }

  /// Get categories with out of stock items
  Future<List<CategoryProductStats>> getCategoriesWithOutOfStockItems() async {
    try {
      final stats = await getProductStatisticsStream().first;

      return stats.categoryStats.values
          .where((categoryStats) => categoryStats.outOfStockItems > 0)
          .toList()
        ..sort((a, b) => b.outOfStockItems.compareTo(a.outOfStockItems));
    } catch (e) {
      print('Error getting categories with out of stock items: $e');
      return [];
    }
  }

  /// Get current statistics (one-time fetch)
  Future<ProductStatistics> getCurrentStatistics() async {
    try {
      return await getProductStatisticsStream().first;
    } catch (e) {
      print('Error getting current statistics: $e');
      return ProductStatistics(
        totalItems: 0,
        availableItems: 0,
        damagedItems: 0,
        outOfStockItems: 0,
        categoryStats: {},
        productCount: 0,
      );
    }
  }

  /// Check if a category has any product items
  Future<bool> categoryHasItems(String categoryId) async {
    try {
      final stats = await getCurrentStatistics();
      return stats.categoryStats.containsKey(categoryId) &&
          stats.categoryStats[categoryId]!.totalItems > 0;
    } catch (e) {
      print('Error checking if category has items: $e');
      return false;
    }
  }

  /// Get health score for inventory (percentage of available items)
  Future<double> getInventoryHealthScore() async {
    try {
      final stats = await getCurrentStatistics();
      if (stats.totalItems == 0) return 100.0;
      return (stats.availableItems / stats.totalItems) * 100;
    } catch (e) {
      print('Error calculating inventory health score: $e');
      return 0.0;
    }
  }
}
