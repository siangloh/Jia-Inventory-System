// lib/services/statistics/product_brand_statistics_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product_brand_model.dart';
import '../../models/product_item.dart';

class ProductBrandStatistics {
  final int totalBrands;
  final int activeBrands;
  final int inactiveBrands;
  final int unusedBrands;
  final Map<String, ProductBrandUsageStats> usageStats;
  final Map<BrandType, BrandTypeStats> brandTypeStats;

  ProductBrandStatistics({
    required this.totalBrands,
    required this.activeBrands,
    required this.inactiveBrands,
    required this.unusedBrands,
    required this.usageStats,
    required this.brandTypeStats,
  });

  @override
  String toString() {
    return 'ProductBrandStatistics(total: $totalBrands, active: $activeBrands, inactive: $inactiveBrands, unused: $unusedBrands)';
  }
}

class ProductBrandUsageStats {
  final String brandId;
  final String brandName;
  final BrandType brandType;
  final String countryOfOrigin;
  final String description;
  final bool isActive;
  final int usageCount; // Number of products using this brand
  final int itemCount; // Number of product items for this brand
  final DateTime lastUsed;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductBrandUsageStats({
    required this.brandId,
    required this.brandName,
    required this.brandType,
    required this.countryOfOrigin,
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
    return 'ProductBrandUsageStats($brandName: usage=$usageCount, items=$itemCount)';
  }
}

class BrandTypeStats {
  final BrandType brandType;
  final int totalBrands;
  final int activeBrands;
  final int inactiveBrands;
  final int totalUsageCount;
  final int totalItemCount;

  BrandTypeStats({
    required this.brandType,
    required this.totalBrands,
    required this.activeBrands,
    required this.inactiveBrands,
    required this.totalUsageCount,
    required this.totalItemCount,
  });

  @override
  String toString() {
    return 'BrandTypeStats(${brandType.name}: brands=$totalBrands, usage=$totalUsageCount)';
  }
}

class ProductBrandStatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get real-time product brand statistics stream
  Stream<ProductBrandStatistics> getProductBrandStatisticsStream() {
    return _firestore
        .collection('productBrands')
        .snapshots()
        .asyncMap((productBrandsSnapshot) async {
      try {
        return await _calculateProductBrandStatistics(
            productBrandsSnapshot.docs);
      } catch (e) {
        print('Error calculating product brand statistics: $e');
        return ProductBrandStatistics(
          totalBrands: 0,
          activeBrands: 0,
          inactiveBrands: 0,
          unusedBrands: 0,
          usageStats: {},
          brandTypeStats: {},
        );
      }
    });
  }

  Future<bool> refreshStatistics() async {
    try {
      print('🔄 Forcing statistics refresh from Firebase servers...');

      // Force server-only query to bypass cache
      final productNamesSnapshot = await _firestore
          .collection('productBrands')
          .get(const GetOptions(source: Source.server));

      print(
          '🔥 Fetched ${productNamesSnapshot.docs.length} product names from server');

      // Calculate fresh statistics
      final freshStats =
      await _calculateProductBrandStatistics(productNamesSnapshot.docs);

      // Emit the fresh statistics to any listeners
      // Note: This assumes you have a StreamController in your implementation
      // If not, you can return the stats directly or use a callback pattern

      print(
          '✅ Statistics refreshed successfully: ${freshStats.totalBrands} total names');
      return true;
    } catch (e) {
      print('❌ Statistics refresh failed: $e');
      return false;
    }
  }


  /// Calculate product brand statistics
  Future<ProductBrandStatistics> _calculateProductBrandStatistics(
      List<QueryDocumentSnapshot> productBrandsDocs) async {
    print(
        'Calculating product brand statistics for ${productBrandsDocs.length} brands');

    if (productBrandsDocs.isEmpty) {
      return ProductBrandStatistics(
        totalBrands: 0,
        activeBrands: 0,
        inactiveBrands: 0,
        unusedBrands: 0,
        usageStats: {},
        brandTypeStats: {},
      );
    }

    // Parse product brands
    final List<ProductBrandModel> productBrands = [];
    for (final doc in productBrandsDocs) {
      try {
        final productBrand = ProductBrandModel.fromFirestore(
          doc.id,
          doc.data() as Map<String, dynamic>,
        );
        productBrands.add(productBrand);
      } catch (e) {
        print('Error parsing product brand ${doc.id}: $e');
      }
    }

    // Get usage data
    final Map<String, int> productUsageCounts = await _getProductUsageCounts();
    final Map<String, int> itemCounts = await _getProductItemCounts();
    final Map<String, DateTime> lastUsedDates = await _getLastUsedDates();

    // Calculate statistics
    int totalBrands = productBrands.length;
    int activeBrands = 0;
    int inactiveBrands = 0;
    int unusedBrands = 0;

    final Map<String, ProductBrandUsageStats> usageStats = {};
    final Map<BrandType, Map<String, int>> brandTypeCounters = {};

    for (final productBrand in productBrands) {
      final usageCount = productUsageCounts[productBrand.brandName] ?? 0;
      final itemCount = itemCounts[productBrand.brandName] ?? 0;
      final lastUsed =
          lastUsedDates[productBrand.brandName] ?? productBrand.createdAt;

      // Count by status
      if (productBrand.isActive) {
        activeBrands++;
      } else {
        inactiveBrands++;
      }

      if (usageCount == 0) {
        unusedBrands++;
      }

      // Create usage stats
      usageStats[productBrand.brandName] = ProductBrandUsageStats(
        brandId: productBrand.id ?? '',
        brandName: productBrand.brandName,
        brandType: productBrand.brandType,
        countryOfOrigin: productBrand.countryOfOrigin,
        description: productBrand.description,
        isActive: productBrand.isActive,
        usageCount: usageCount,
        itemCount: itemCount,
        lastUsed: lastUsed,
        createdAt: productBrand.createdAt,
        updatedAt: productBrand.updatedAt,
      );

      // Count by brand type
      final brandType = productBrand.brandType;
      brandTypeCounters.putIfAbsent(
          brandType,
          () => {
                'total': 0,
                'active': 0,
                'inactive': 0,
                'usage': 0,
                'items': 0,
              });

      brandTypeCounters[brandType]!['total'] =
          (brandTypeCounters[brandType]!['total']! + 1);

      if (productBrand.isActive) {
        brandTypeCounters[brandType]!['active'] =
            (brandTypeCounters[brandType]!['active']! + 1);
      } else {
        brandTypeCounters[brandType]!['inactive'] =
            (brandTypeCounters[brandType]!['inactive']! + 1);
      }

      brandTypeCounters[brandType]!['usage'] =
          (brandTypeCounters[brandType]!['usage']! + usageCount);
      brandTypeCounters[brandType]!['items'] =
          (brandTypeCounters[brandType]!['items']! + itemCount);
    }

    // Build brand type statistics
    final Map<BrandType, BrandTypeStats> brandTypeStats = {};
    for (final entry in brandTypeCounters.entries) {
      final brandType = entry.key;
      final counters = entry.value;

      brandTypeStats[brandType] = BrandTypeStats(
        brandType: brandType,
        totalBrands: counters['total']!,
        activeBrands: counters['active']!,
        inactiveBrands: counters['inactive']!,
        totalUsageCount: counters['usage']!,
        totalItemCount: counters['items']!,
      );
    }

    final result = ProductBrandStatistics(
      totalBrands: totalBrands,
      activeBrands: activeBrands,
      inactiveBrands: inactiveBrands,
      unusedBrands: unusedBrands,
      usageStats: usageStats,
      brandTypeStats: brandTypeStats,
    );

    print('Product brand statistics calculated: $result');
    return result;
  }

  /// Get usage counts for each brand from products collection
  Future<Map<String, int>> _getProductUsageCounts() async {
    try {
      print('Starting brand usage count analysis...');

      final QuerySnapshot productsSnapshot =
          await _firestore.collection('products').get();

      print(
          'Found ${productsSnapshot.docs.length} products for brand analysis');

      final QuerySnapshot productBrandsSnapshot =
          await _firestore.collection('productBrands').get();

      print('Found ${productBrandsSnapshot.docs.length} brands in collection');

      final Map<String, String> idToBrandNameMapping = {};
      for (final doc in productBrandsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String? brandName = data['brandName'] as String?;
        if (brandName != null && brandName.isNotEmpty) {
          idToBrandNameMapping[doc.id] = brandName;
          print('Mapped brand ${doc.id} -> $brandName');
        }
      }

      final Map<String, int> usageCounts = {};

      for (final doc in productsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('Analyzing product ${doc.id} for brand usage');

        final String? brandId = data['brand'] as String?;
        print('Product ${doc.id} has brand field: $brandId');

        if (brandId != null && idToBrandNameMapping.containsKey(brandId)) {
          final String actualBrandName = idToBrandNameMapping[brandId]!;
          usageCounts[actualBrandName] =
              (usageCounts[actualBrandName] ?? 0) + 1;
          print('SUCCESS: Product ${doc.id} uses $brandId -> $actualBrandName');
        } else {
          print(
              'FAILED: Product ${doc.id} - no brand mapping found for $brandId');
        }
      }

      print('FINAL BRAND RESULTS: $usageCounts');
      return usageCounts;
    } catch (e) {
      print('❌ ERROR getting brand usage counts: $e');
      return {};
    }
  }

  /// Get item counts for each brand from product items
  Future<Map<String, int>> _getProductItemCounts() async {
    try {
      print('Starting brand item count analysis...');

      final QuerySnapshot itemsSnapshot = await _firestore
          .collection('productItems')
          .where('status', whereIn: [
        ProductItemsStatus.stored.name,
        ProductItemsStatus.received.name
      ]).get();

      print(
          'Found ${itemsSnapshot.docs.length} product items for brand analysis');

      final Set<String> productIds = {};
      for (final doc in itemsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String? productId = data['productId'] as String?;
        if (productId != null && productId.isNotEmpty) {
          productIds.add(productId);
          print('Item ${doc.id} references product: $productId');
        }
      }

      if (productIds.isEmpty) {
        print('No product IDs found in productItems');
        return {};
      }

      print('Found ${productIds.length} unique product IDs in items');

      final QuerySnapshot productBrandsSnapshot =
          await _firestore.collection('productBrands').get();

      final Map<String, String> brandIdToBrandName = {};
      for (final doc in productBrandsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String? brandName = data['brandName'] as String?;
        if (brandName != null && brandName.isNotEmpty) {
          brandIdToBrandName[doc.id] = brandName;
        }
      }

      final Map<String, String> productIdToBrandName = {};
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
            final String? brandId = data['brand'] as String?;

            if (brandId != null && brandIdToBrandName.containsKey(brandId)) {
              final String actualBrandName = brandIdToBrandName[brandId]!;
              productIdToBrandName[doc.id] = actualBrandName;
              print('Product ${doc.id} -> $brandId -> $actualBrandName');
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

        if (productId != null && productIdToBrandName.containsKey(productId)) {
          final brandName = productIdToBrandName[productId]!;
          itemCounts[brandName] = (itemCounts[brandName] ?? 0) + 1;
          print('Item ${doc.id} counted for brand: $brandName');
        }
      }

      print('FINAL BRAND ITEM COUNTS: $itemCounts');
      return itemCounts;
    } catch (e) {
      print('ERROR getting brand item counts: $e');
      return {};
    }
  }

  /// Get last used dates for brands
  Future<Map<String, DateTime>> _getLastUsedDates() async {
    try {
      final QuerySnapshot productsSnapshot = await _firestore
          .collection('products')
          .orderBy('updatedAt', descending: true)
          .get();

      final QuerySnapshot productBrandsSnapshot =
          await _firestore.collection('productBrands').get();

      final Map<String, String> brandIdToBrandName = {};
      for (final doc in productBrandsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String? brandName = data['brandName'] as String?;
        if (brandName != null && brandName.isNotEmpty) {
          brandIdToBrandName[doc.id] = brandName;
        }
      }

      final Map<String, DateTime> lastUsedDates = {};

      for (final doc in productsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final Timestamp? updatedAt = data['updatedAt'] as Timestamp?;

        if (updatedAt != null) {
          final String? brandId = data['brand'] as String?;

          if (brandId != null && brandIdToBrandName.containsKey(brandId)) {
            final String actualBrandName = brandIdToBrandName[brandId]!;

            if (!lastUsedDates.containsKey(actualBrandName) ||
                updatedAt.toDate().isAfter(lastUsedDates[actualBrandName]!)) {
              lastUsedDates[actualBrandName] = updatedAt.toDate();
            }
          }
        }
      }

      return lastUsedDates;
    } catch (e) {
      print('Error getting last used dates for brands: $e');
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

  /// Get usage count for a specific brand
  Future<int> getBrandUsageCount(String brandName) async {
    try {
      // First, get the brandId for this brand name
      final QuerySnapshot brandSnapshot = await _firestore
          .collection('productBrands')
          .where('brandName', isEqualTo: brandName)
          .limit(1)
          .get();

      if (brandSnapshot.docs.isEmpty) {
        return 0; // Brand doesn't exist
      }

      final brandId = brandSnapshot.docs.first.id;

      // Count products using this brandId in the "brand" field
      final QuerySnapshot productsSnapshot = await _firestore
          .collection('products')
          .where('brand', isEqualTo: brandId)
          .get();

      return productsSnapshot.docs.length;
    } catch (e) {
      print('Error getting usage count for $brandName: $e');
      return 0;
    }
  }

  /// Get unused brands
  Future<List<ProductBrandUsageStats>> getUnusedBrands() async {
    try {
      final statistics = await getProductBrandStatisticsStream().first;
      return statistics.usageStats.values
          .where((stats) => stats.usageCount == 0)
          .toList()
        ..sort((a, b) => a.brandName.compareTo(b.brandName));
    } catch (e) {
      print('Error getting unused brands: $e');
      return [];
    }
  }

  /// Get all brand usage counts as a simple map
  Future<Map<String, int>> getAllBrandUsageCounts() async {
    try {
      final statistics = await getProductBrandStatisticsStream().first;
      final Map<String, int> usageCounts = {};

      for (final entry in statistics.usageStats.entries) {
        usageCounts[entry.key] = entry.value.usageCount;
      }

      return usageCounts;
    } catch (e) {
      print('Error getting all brand usage counts: $e');
      return {};
    }
  }

  /// Get most used brands
  Future<List<ProductBrandUsageStats>> getTopUsedBrands(
      {int limit = 10}) async {
    try {
      final statistics = await getProductBrandStatisticsStream().first;
      final List<ProductBrandUsageStats> sortedStats =
          statistics.usageStats.values.toList()
            ..sort((a, b) => b.usageCount.compareTo(a.usageCount));

      return sortedStats.take(limit).toList();
    } catch (e) {
      print('Error getting top used brands: $e');
      return [];
    }
  }

  /// Get brands that need attention (inactive or unused)
  Future<List<ProductBrandUsageStats>> getBrandsNeedingAttention() async {
    try {
      final statistics = await getProductBrandStatisticsStream().first;
      return statistics.usageStats.values
          .where((stats) => !stats.isActive || stats.usageCount == 0)
          .toList()
        ..sort((a, b) {
          // Sort by priority: unused first, then inactive
          if (a.usageCount == 0 && b.usageCount > 0) return -1;
          if (a.usageCount > 0 && b.usageCount == 0) return 1;
          if (!a.isActive && b.isActive) return -1;
          if (a.isActive && !b.isActive) return 1;
          return a.brandName.compareTo(b.brandName);
        });
    } catch (e) {
      print('Error getting brands needing attention: $e');
      return [];
    }
  }

  /// Get statistics for a specific brand type
  Future<BrandTypeStats?> getBrandTypeStatistics(BrandType brandType) async {
    try {
      final statistics = await getProductBrandStatisticsStream().first;
      return statistics.brandTypeStats[brandType];
    } catch (e) {
      print('Error getting brand type statistics for $brandType: $e');
      return null;
    }
  }

  /// Get usage efficiency (percentage of brands that are used)
  Future<double> getUsageEfficiency() async {
    try {
      final statistics = await getProductBrandStatisticsStream().first;
      if (statistics.totalBrands == 0) return 100.0;

      final usedBrands = statistics.totalBrands - statistics.unusedBrands;
      return (usedBrands / statistics.totalBrands) * 100;
    } catch (e) {
      print('Error calculating brand usage efficiency: $e');
      return 0.0;
    }
  }

  /// Get current statistics (one-time fetch)
  Future<ProductBrandStatistics> getCurrentStatistics() async {
    try {
      return await getProductBrandStatisticsStream().first;
    } catch (e) {
      print('Error getting current brand statistics: $e');
      return ProductBrandStatistics(
        totalBrands: 0,
        activeBrands: 0,
        inactiveBrands: 0,
        unusedBrands: 0,
        usageStats: {},
        brandTypeStats: {},
      );
    }
  }
}
