import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product_name_model.dart';

class ProductNameStatistics {
  final int totalProductNames;
  final int activeProductNames;
  final int inactiveProductNames;
  final int unusedProductNames;
  final Map<String, ProductNameUsageStats> usageStats;
  final Map<String, CategoryNameStats> categoryStats;

  ProductNameStatistics({
    required this.totalProductNames,
    required this.activeProductNames,
    required this.inactiveProductNames,
    required this.unusedProductNames,
    required this.usageStats,
    required this.categoryStats,
  });

  @override
  String toString() {
    return 'ProductNameStatistics(total: $totalProductNames, active: $activeProductNames, inactive: $inactiveProductNames, unused: $unusedProductNames)';
  }
}

class ProductNameUsageStats {
  final String productNameId;
  final String productName;
  final String category;
  final String description;
  final bool isActive;
  final int usageCount; // Number of products using this name
  final int itemCount; // Number of product items for this name
  final DateTime lastUsed;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductNameUsageStats({
    required this.productNameId,
    required this.productName,
    required this.category,
    required this.description,
    required this.isActive,
    required this.usageCount,
    required this.itemCount,
    required this.lastUsed,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  String toString() {
    return 'ProductNameUsageStats($productName: usage=$usageCount, items=$itemCount)';
  }
}

class CategoryNameStats {
  final String categoryName;
  final int totalProductNames;
  final int activeProductNames;
  final int inactiveProductNames;
  final int totalUsageCount;
  final int totalItemCount;

  CategoryNameStats({
    required this.categoryName,
    required this.totalProductNames,
    required this.activeProductNames,
    required this.inactiveProductNames,
    required this.totalUsageCount,
    required this.totalItemCount,
  });

  @override
  String toString() {
    return 'CategoryNameStats($categoryName: names=$totalProductNames, usage=$totalUsageCount)';
  }
}

class ProductNameStatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> refreshStatistics() async {
    try {
      print('🔄 Forcing statistics refresh from Firebase servers...');

      // Force server-only query to bypass cache
      final productNamesSnapshot = await _firestore
          .collection('productNames')
          .get(const GetOptions(source: Source.server));

      print(
          '🔥 Fetched ${productNamesSnapshot.docs.length} product names from server');

      // Calculate fresh statistics
      final freshStats =
          await _calculateProductNameStatistics(productNamesSnapshot.docs);

      // Emit the fresh statistics to any listeners
      // Note: This assumes you have a StreamController in your implementation
      // If not, you can return the stats directly or use a callback pattern

      print(
          '✅ Statistics refreshed successfully: ${freshStats.totalProductNames} total names');
      return true;
    } catch (e) {
      print('❌ Statistics refresh failed: $e');
      return false;
    }
  }

  /// Get real-time product name statistics stream
  Stream<ProductNameStatistics> getProductNameStatisticsStream() {
    // Listen to changes in product names only - no circular dependency
    return _firestore
        .collection('productNames')
        .snapshots()
        .asyncMap((productNamesSnapshot) async {
      try {
        return await _calculateProductNameStatistics(productNamesSnapshot.docs);
      } catch (e) {
        print('Error calculating product name statistics: $e');
        return ProductNameStatistics(
          totalProductNames: 0,
          activeProductNames: 0,
          inactiveProductNames: 0,
          unusedProductNames: 0,
          usageStats: {},
          categoryStats: {},
        );
      }
    });
  }

  Future<ProductNameStatistics> getFreshStatistics() async {
    try {
      print('🔄 Getting fresh statistics from server (no cache)...');

      // Force server query to bypass local cache
      final productNamesSnapshot = await _firestore
          .collection('productNames')
          .get(const GetOptions(source: Source.server));

      print(
          '🔥 Fresh server data: ${productNamesSnapshot.docs.length} product names');

      return await _calculateProductNameStatistics(productNamesSnapshot.docs);
    } catch (e) {
      print('❌ Fresh statistics fetch failed: $e');
      // Fallback to cached data if server fetch fails
      final fallbackSnapshot =
          await _firestore.collection('productNames').get();
      return await _calculateProductNameStatistics(fallbackSnapshot.docs);
    }
  }

  /// Calculate product name statistics
  Future<ProductNameStatistics> _calculateProductNameStatistics(
      List<QueryDocumentSnapshot> productNamesDocs) async {
    print(
        'Calculating product name statistics for ${productNamesDocs.length} product names');

    if (productNamesDocs.isEmpty) {
      return ProductNameStatistics(
        totalProductNames: 0,
        activeProductNames: 0,
        inactiveProductNames: 0,
        unusedProductNames: 0,
        usageStats: {},
        categoryStats: {},
      );
    }

    // Parse product names
    final List<ProductNameModel> productNames = [];
    for (final doc in productNamesDocs) {
      try {
        final productName = ProductNameModel.fromFirestore(
          doc.id,
          doc.data() as Map<String, dynamic>,
        );
        productNames.add(productName);
      } catch (e) {
        print('Error parsing product name ${doc.id}: $e');
      }
    }

    // Get all products to count usage - NO DAO dependency
    final Map<String, int> productUsageCounts = await _getProductUsageCounts();
    final Map<String, int> itemCounts = await _getProductItemCounts();
    final Map<String, DateTime> lastUsedDates = await _getLastUsedDates();

    // Calculate statistics
    int totalProductNames = productNames.length;
    int activeProductNames = 0;
    int inactiveProductNames = 0;
    int unusedProductNames = 0;

    final Map<String, ProductNameUsageStats> usageStats = {};
    final Map<String, Map<String, int>> categoryCounters = {};

    for (final productName in productNames) {
      final itemCount = productName.usageCount;
      final usageCount = productUsageCounts[productName.productName] ?? 0;
      final lastUsed =
          lastUsedDates[productName.productName] ?? productName.createdAt;

      // Count by status
      if (productName.isActive) {
        activeProductNames++;
        if (itemCount == 0) {
          print('Products: ${productName.productName}');
          unusedProductNames++;
        }
      } else {
        inactiveProductNames++;
      }



      // Create usage stats
      usageStats[productName.productName] = ProductNameUsageStats(
        productNameId: productName.id ?? '',
        productName: productName.productName,
        category: productName.category,
        description: productName.description,
        isActive: productName.isActive,
        usageCount: usageCount,
        itemCount: itemCount,
        lastUsed: lastUsed,
        createdAt: productName.createdAt,
        updatedAt: productName.updatedAt,
      );

      // Count by category
      final category = productName.category;
      categoryCounters.putIfAbsent(
          category,
          () => {
                'total': 0,
                'active': 0,
                'inactive': 0,
                'usage': 0,
                'items': 0,
              });

      categoryCounters[category]!['total'] =
          (categoryCounters[category]!['total']! + 1);

      if (productName.isActive) {
        categoryCounters[category]!['active'] =
            (categoryCounters[category]!['active']! + 1);
      } else {
        categoryCounters[category]!['inactive'] =
            (categoryCounters[category]!['inactive']! + 1);
      }

      categoryCounters[category]!['usage'] =
          (categoryCounters[category]!['usage']! + usageCount);
      categoryCounters[category]!['items'] =
          (categoryCounters[category]!['items']! + itemCount);
    }

    // Build category statistics
    final Map<String, CategoryNameStats> categoryStats = {};
    for (final entry in categoryCounters.entries) {
      final categoryName = entry.key;
      final counters = entry.value;

      categoryStats[categoryName] = CategoryNameStats(
        categoryName: categoryName,
        totalProductNames: counters['total']!,
        activeProductNames: counters['active']!,
        inactiveProductNames: counters['inactive']!,
        totalUsageCount: counters['usage']!,
        totalItemCount: counters['items']!,
      );
    }

    final result = ProductNameStatistics(
      totalProductNames: totalProductNames,
      activeProductNames: activeProductNames,
      inactiveProductNames: inactiveProductNames,
      unusedProductNames: unusedProductNames,
      usageStats: usageStats,
      categoryStats: categoryStats,
    );

    print('Product name statistics calculated: $result');
    return result;
  }

  /// Get usage counts for each product name from products collection - DIRECT FIRESTORE ACCESS
  Future<Map<String, int>> _getProductUsageCounts() async {
    try {
      print('Starting product usage count analysis...');

      final QuerySnapshot productsSnapshot =
          await _firestore.collection('products').get();

      print('Found ${productsSnapshot.docs.length} products in collection');

      final QuerySnapshot productNamesSnapshot =
          await _firestore.collection('productNames').get();

      print(
          'Found ${productNamesSnapshot.docs.length} product names in collection');

      final Map<String, String> idToNameMapping = {};
      for (final doc in productNamesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String? productName = data['productName'] as String?;
        if (productName != null && productName.isNotEmpty) {
          idToNameMapping[doc.id] = productName;
          print('Mapped ${doc.id} -> $productName');
        }
      }

      final Map<String, int> usageCounts = {};

      for (final doc in productsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('Analyzing product ${doc.id}');

        final String? productNameId = data['name'] as String?;
        print('Product ${doc.id} has name field: $productNameId');

        if (productNameId != null &&
            idToNameMapping.containsKey(productNameId)) {
          final String actualProductName = idToNameMapping[productNameId]!;
          usageCounts[actualProductName] =
              (usageCounts[actualProductName] ?? 0) + 1;
          print(
              'SUCCESS: Product ${doc.id} uses $productNameId -> $actualProductName');
        } else {
          print(
              'FAILED: Product ${doc.id} - no mapping found for $productNameId');
        }
      }

      print('FINAL RESULTS: $usageCounts');
      return usageCounts;
    } catch (e) {
      print('❌ ERROR: $e');
      return {};
    }
  }

  /// Get item counts for each product name from product items - DIRECT FIRESTORE ACCESS
  Future<Map<String, int>> _getProductItemCounts() async {
    try {
      final QuerySnapshot itemsSnapshot =
      await _firestore.collection('productItems').get();

      final Set<String> productIds = {};
      for (final doc in itemsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String? productId = data['productId'] as String?;
        if (productId != null && productId.isNotEmpty) {
          productIds.add(productId);
        }
      }

      if (productIds.isEmpty) {
        print('No product IDs found in productItems');
        return {};
      }

      final QuerySnapshot productNamesSnapshot =
      await _firestore.collection('productNames').get();

      final Map<String, String> productNameIdToName = {};
      for (final doc in productNamesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String? productName = data['productName'] as String?;
        if (productName != null && productName.isNotEmpty) {
          productNameIdToName[doc.id] = productName;
        }
      }

      final Map<String, String> productIdToProductName = {};
      final List<List<String>> productIdBatches =
      _createBatches(productIds.toList(), 10);

      for (final batch in productIdBatches) {
        try {
          final QuerySnapshot productsSnapshot = await _firestore
              .collection('products')
              .where(FieldPath.documentId, whereIn: batch)
              .get();

          for (final doc in productsSnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final String? productNameId = data['name'] as String?;

            if (productNameId != null &&
                productNameIdToName.containsKey(productNameId)) {
              final String actualProductName =
              productNameIdToName[productNameId]!;
              productIdToProductName[doc.id] = actualProductName;
            }
          }
        } catch (e) {
          print('Error fetching products batch: $e');
        }
      }

      final Map<String, int> itemCounts = {};
      for (final doc in itemsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String? productId = data['productId'] as String?;

        if (productId != null &&
            productIdToProductName.containsKey(productId)) {
          final productName = productIdToProductName[productId]!;
          itemCounts[productName] = (itemCounts[productName] ?? 0) + 1;
          print('Item ${doc.id} counted for product name: $productName');
        }
      }

      print('FINAL ITEM COUNTS: $itemCounts');

      for (final entry in itemCounts.entries) {
        final String productId = entry.key;
        final int usageCount = entry.value;

        print('Name: $productId');

        final querySnapshot = await _firestore
            .collection('productNames')
            .where('productName', isEqualTo: productId)
            .get();

        for (final doc in querySnapshot.docs) {
          await doc.reference.update({'usageCount': usageCount});
        }

        print(
            'Updated product $productId (${productIdToProductName[productId]}) with usageCount: $usageCount');
      }

      return itemCounts;
    } catch (e) {
      print('ERROR getting product item counts: $e');
      return {};
    }
  }

  /// Get last used dates for product names - DIRECT FIRESTORE ACCESS
  Future<Map<String, DateTime>> _getLastUsedDates() async {
    try {
      final QuerySnapshot productsSnapshot = await _firestore
          .collection('products')
          .orderBy('updatedAt', descending: true)
          .get();

      final Map<String, DateTime> lastUsedDates = {};

      for (final doc in productsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String? productName = data['productName'] as String?;
        final Timestamp? updatedAt = data['updatedAt'] as Timestamp?;

        if (productName != null &&
            productName.isNotEmpty &&
            updatedAt != null) {
          // Only keep the latest date for each product name
          if (!lastUsedDates.containsKey(productName) ||
              updatedAt.toDate().isAfter(lastUsedDates[productName]!)) {
            lastUsedDates[productName] = updatedAt.toDate();
          }
        }
      }

      return lastUsedDates;
    } catch (e) {
      print('Error getting last used dates: $e');
      return {};
    }
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

  /// Get usage count for a specific product name - DIRECT FIRESTORE ACCESS
  Future<int> getProductNameUsageCount(String productName) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('products')
          .where('productName', isEqualTo: productName)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting usage count for $productName: $e');
      return 0;
    }
  }

  /// Get unused product names
  Future<List<ProductNameUsageStats>> getUnusedProductNames() async {
    try {
      final statistics = await getProductNameStatisticsStream().first;
      return statistics.usageStats.values
          .where((stats) => stats.usageCount == 0 && stats.isActive == true) // Add isActive condition
          .toList()
        ..sort((a, b) => a.productName.compareTo(b.productName));
    } catch (e) {
      print('Error getting unused product names: $e');
      return [];
    }
  }

  /// Get all product name usage counts as a simple map
  Future<Map<String, int>> getAllProductNameUsageCounts() async {
    try {
      final statistics = await getProductNameStatisticsStream().first;
      final Map<String, int> usageCounts = {};

      for (final entry in statistics.usageStats.entries) {
        usageCounts[entry.key] = entry.value.usageCount;
      }

      return usageCounts;
    } catch (e) {
      print('Error getting all product name usage counts: $e');
      return {};
    }
  }

  /// Get most used product names
  Future<List<ProductNameUsageStats>> getTopUsedProductNames(
      {int limit = 10}) async {
    try {
      final statistics = await getProductNameStatisticsStream().first;
      final List<ProductNameUsageStats> sortedStats =
          statistics.usageStats.values.toList()
            ..sort((a, b) => b.usageCount.compareTo(a.usageCount));

      return sortedStats.take(limit).toList();
    } catch (e) {
      print('Error getting top used product names: $e');
      return [];
    }
  }

  /// Get product names that need attention (inactive or unused)
  Future<List<ProductNameUsageStats>> getProductNamesNeedingAttention() async {
    try {
      final statistics = await getProductNameStatisticsStream().first;
      return statistics.usageStats.values
          .where((stats) => !stats.isActive || stats.usageCount == 0)
          .toList()
        ..sort((a, b) {
          // Sort by priority: unused first, then inactive
          if (a.usageCount == 0 && b.usageCount > 0) return -1;
          if (a.usageCount > 0 && b.usageCount == 0) return 1;
          if (!a.isActive && b.isActive) return -1;
          if (a.isActive && !b.isActive) return 1;
          return a.productName.compareTo(b.productName);
        });
    } catch (e) {
      print('Error getting product names needing attention: $e');
      return [];
    }
  }

  /// Get statistics for a specific category
  Future<CategoryNameStats?> getCategoryNameStatistics(
      String categoryName) async {
    try {
      final statistics = await getProductNameStatisticsStream().first;
      return statistics.categoryStats[categoryName];
    } catch (e) {
      print('Error getting category statistics for $categoryName: $e');
      return null;
    }
  }

  /// Get usage efficiency (percentage of product names that are used)
  Future<double> getUsageEfficiency() async {
    try {
      final statistics = await getProductNameStatisticsStream().first;
      if (statistics.totalProductNames == 0) return 100.0;

      final usedNames =
          statistics.totalProductNames - statistics.unusedProductNames;
      return (usedNames / statistics.totalProductNames) * 100;
    } catch (e) {
      print('Error calculating usage efficiency: $e');
      return 0.0;
    }
  }

  /// Get current statistics (one-time fetch)
  Future<ProductNameStatistics> getCurrentStatistics() async {
    try {
      return await getProductNameStatisticsStream().first;
    } catch (e) {
      print('Error getting current statistics: $e');
      return ProductNameStatistics(
        totalProductNames: 0,
        activeProductNames: 0,
        inactiveProductNames: 0,
        unusedProductNames: 0,
        usageStats: {},
        categoryStats: {},
      );
    }
  }
}
