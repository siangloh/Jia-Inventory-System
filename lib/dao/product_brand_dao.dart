// lib/dao/product_brand_dao.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/product_brand_model.dart';
import '../services/statistics/product_brand_service.dart';

class ProductBrandDAO {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionName = 'productBrands';
  final ProductBrandStatisticsService _statisticsService =
      ProductBrandStatisticsService();

  StreamSubscription<QuerySnapshot>? _subscription;

  // Real-time listener
  Stream<List<ProductBrandModel>> get brandsStream => _firestore
      .collection(collectionName)
      .orderBy('brandName')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ProductBrandModel.fromFirestore(doc.id, doc.data()))
          .where((brand) => brand.brandName.isNotEmpty)
          .toList());

  // Get brands with real-time usage counts
  Stream<List<ProductBrandModel>> getBrandsWithUsageStream() {
    return brandsStream.asyncMap((brands) async {
      try {
        final statistics = await _statisticsService.getCurrentStatistics();

        return brands.map((brand) {
          final usageStats = statistics.usageStats[brand.brandName];
          if (usageStats != null) {
            return brand.copyWith(usageCount: usageStats.usageCount);
          }
          return brand.copyWith(usageCount: 0);
        }).toList()
          ..sort((a, b) => a.brandName.compareTo(b.brandName));
      } catch (e) {
        print('Error getting brand usage statistics: $e');
        return brands;
      }
    });
  }

  // Usage counts using the new statistics service
  Future<Map<String, int>> getUsageCounts() async {
    try {
      return await _statisticsService.getAllBrandUsageCounts();
    } catch (e) {
      print('Error loading usage counts: $e');
      return {};
    }
  }

  // Get usage count for a specific brand
  Future<int> getUsageCount(String brandName) async {
    try {
      return await _statisticsService.getBrandUsageCount(brandName);
    } catch (e) {
      print('Error getting usage count for $brandName: $e');
      return 0;
    }
  }

  // CRUD Operations
  Future<bool> createBrand(ProductBrandModel brand) async {
    final year = DateTime.now().year.toString();
    final prefix = "proBrand_$year";
    final collection = _firestore.collection(collectionName);

    return _firestore.runTransaction((transaction) async {
      // Check if brand name already exists
      final existingQuery = await collection
          .where('brandName', isEqualTo: brand.brandName)
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        return false;
      }

      // Get last document ID starting with "proBrand_<year>_"
      final query = await collection
          .orderBy(FieldPath.documentId, descending: true)
          .startAt(['${prefix}_\uf8ff'])
          .endAt([prefix])
          .limit(1)
          .get();

      int nextNumber = 1;

      if (query.docs.isNotEmpty) {
        final lastId = query.docs.first.id;
        final lastNumberStr = lastId.split('_').last;
        final lastNumber = int.tryParse(lastNumberStr) ?? 0;
        nextNumber = lastNumber + 1;
      }

      // Format new custom ID
      final customId = "${prefix}_${nextNumber.toString().padLeft(5, '0')}";

      // Create the document with custom ID
      final docRef = collection.doc(customId);
      transaction.set(docRef, brand.toFirestore());

      return true;
    });
  }

  Future<bool> updateBrand(ProductBrandModel brand) async {
    try {
      if (brand.id == null) return false;

      // Check for duplicates (excluding current document)
      final existingQuery = await _firestore
          .collection(collectionName)
          .where('brandName', isEqualTo: brand.brandName)
          .get();

      final duplicates =
          existingQuery.docs.where((doc) => doc.id != brand.id).toList();

      if (duplicates.isNotEmpty) {
        throw Exception('Brand name "${brand.brandName}" already exists');
      }

      await _firestore
          .collection(collectionName)
          .doc(brand.id!)
          .update(brand.copyWith(updatedAt: DateTime.now()).toFirestore());
      return true;
    } catch (e) {
      print('Error updating brand: $e');
      return false;
    }
  }

  // Future<bool> deleteBrand(ProductBrandModel brand) async {
  //   try {
  //     // Check usage count using statistics service
  //     final usageCount = await _statisticsService.getBrandUsageCount(brand.brandName);
  //
  //     if (usageCount > 0) {
  //       return false; // Cannot delete if in use
  //     }
  //
  //     await _firestore.collection(collectionName).doc(brand.brandId).delete();
  //     return true;
  //   } catch (e) {
  //     print('Error deleting brand: $e');
  //     return false;
  //   }
  // }

  Future<bool> toggleBrandStatus(String brandId, bool currentStatus) async {
    try {
      await _firestore.collection(collectionName).doc(brandId).update({
        'isActive': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error toggling brand status: $e');
      return false;
    }
  }

  // Get unused brands
  Future<List<ProductBrandModel>> getUnusedBrands() async {
    try {
      final unusedStats = await _statisticsService.getUnusedBrands();
      final List<ProductBrandModel> unusedModels = [];

      // Get the full ProductBrandModel for each unused brand
      for (final stats in unusedStats) {
        final brand = await getBrandById(stats.brandId);
        if (brand != null) {
          unusedModels.add(brand.copyWith(usageCount: 0));
        }
      }

      return unusedModels;
    } catch (e) {
      throw Exception('Failed to fetch unused brands: $e');
    }
  }

  // Get top used brands
  Future<List<ProductBrandUsageStats>> getTopUsedBrands({int limit = 5}) async {
    try {
      return await _statisticsService.getTopUsedBrands(limit: limit);
    } catch (e) {
      throw Exception('Failed to get top used brands: $e');
    }
  }

  // Get brands that need attention
  Future<List<ProductBrandUsageStats>> getBrandsNeedingAttention() async {
    try {
      return await _statisticsService.getBrandsNeedingAttention();
    } catch (e) {
      throw Exception('Failed to get brands needing attention: $e');
    }
  }

  // Check if a brand can be safely deleted
  Future<bool> canDeleteBrand(String brandName) async {
    try {
      final usageCount = await getUsageCount(brandName);
      return usageCount == 0;
    } catch (e) {
      print('Error checking if brand can be deleted: $e');
      return false;
    }
  }

  // Analytics using the new statistics service
  Future<Map<BrandType, int>> getBrandTypeStats() async {
    try {
      final statistics = await _statisticsService.getCurrentStatistics();
      final Map<BrandType, int> stats = {};

      for (final entry in statistics.brandTypeStats.entries) {
        stats[entry.key] = entry.value.totalBrands;
      }

      return stats;
    } catch (e) {
      print('Error getting brand type stats: $e');
      return {};
    }
  }

  Future<Map<String, int>> getCountryStats() async {
    try {
      final brands = await getAllBrands();
      final stats = <String, int>{};

      for (final brand in brands) {
        if (brand.countryOfOrigin.isNotEmpty) {
          stats[brand.countryOfOrigin] =
              (stats[brand.countryOfOrigin] ?? 0) + 1;
        }
      }

      return stats;
    } catch (e) {
      print('Error getting country stats: $e');
      return {};
    }
  }

  // Bulk Operations
  Future<int> importFromExistingParts(
      List<ProductBrandModel> existingBrands) async {
    try {
      // This method would need to be updated based on your actual data structure
      // For now, returning 0 as it references the old 'carParts' collection
      print('Import from existing parts not implemented for new structure');
      return 0;
    } catch (e) {
      print('Error importing brands: $e');
      return 0;
    }
  }

  // Get all brands with usage counts
  Future<List<ProductBrandModel>> getAllBrandsWithUsage() async {
    try {
      final brands = await getAllBrands();
      final usageCounts = await getUsageCounts();

      return brands.map((brand) {
        final usageCount = usageCounts[brand.brandName] ?? 0;
        return brand.copyWith(usageCount: usageCount);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch brands with usage: $e');
    }
  }

  // Get brand by ID
  Future<ProductBrandModel?> getBrandById(String brandId) async {
    try {
      final doc =
          await _firestore.collection(collectionName).doc(brandId).get();

      if (doc.exists) {
        final brand = ProductBrandModel.fromFirestore(
            doc.id, Map<String, dynamic>.from(doc.data() as Map));

        // Add usage count
        final usageCount = await getUsageCount(brand.brandName);
        return brand.copyWith(usageCount: usageCount);
      }
      return null;
    } catch (e) {
      print('Error getting brand by ID: $e');
      return null;
    }
  }

  // Get distinct brands
  Future<List<String>> getDistinctBrands() async {
    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .where("isActive", isEqualTo: true)
          .get();

      final Set<String> brands = {'All'};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final brand = data['brandName'] as String?;
        if (brand != null && brand.isNotEmpty) {
          brands.add(brand);
        }
      }

      final result = brands.toList()..sort();
      return result;
    } catch (e) {
      throw Exception('Failed to fetch distinct brands: $e');
    }
  }

  // Get brand by name
  Future<ProductBrandModel?> getBrandByName(String brandName) async {
    try {
      final query = await _firestore
          .collection(collectionName)
          .where('brandName', isEqualTo: brandName)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final brand = ProductBrandModel.fromFirestore(
            doc.id, Map<String, dynamic>.from(doc.data() as Map));

        // Add usage count
        final usageCount = await getUsageCount(brandName);
        return brand.copyWith(usageCount: usageCount);
      }
      return null;
    } catch (e) {
      print('Error getting brand by name: $e');
      return null;
    }
  }

  // Get all brands
  Future<List<ProductBrandModel>> getAllBrands(
      {bool includeInactive = false}) async {
    try {
      Query query = _firestore.collection(collectionName);

      if (!includeInactive) {
        query = query.where('isActive', isEqualTo: true);
      }

      final snapshot = await query.orderBy('brandName').get();

      return snapshot.docs
          .map((doc) => ProductBrandModel.fromFirestore(
              doc.id, Map<String, dynamic>.from(doc.data() as Map)))
          .where((brand) => brand.brandName.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error getting all brands: $e');
      return [];
    }
  }

  // Search brands
  Future<List<ProductBrandModel>> searchBrands(String query) async {
    try {
      final allBrands = await getAllBrandsWithUsage();

      if (query.isEmpty) {
        return allBrands;
      }

      final filteredBrands = allBrands.where((brand) {
        return brand.matchesSearch(query);
      }).toList();

      return filteredBrands;
    } catch (e) {
      throw Exception('Failed to search brands: $e');
    }
  }

  // Get brands by type
  Future<List<ProductBrandModel>> getBrandsByType(BrandType brandType) async {
    try {
      final query = await _firestore
          .collection(collectionName)
          .where('brandType', isEqualTo: brandType.name)
          .orderBy('brandName')
          .get();

      final List<ProductBrandModel> brands = [];
      final usageCounts = await getUsageCounts();

      for (var doc in query.docs) {
        try {
          final brand = ProductBrandModel.fromFirestore(doc.id, doc.data());
          final usageCount = usageCounts[brand.brandName] ?? 0;
          brands.add(brand.copyWith(usageCount: usageCount));
        } catch (e) {
          print('Error parsing brand ${doc.id}: $e');
        }
      }

      return brands;
    } catch (e) {
      throw Exception('Failed to fetch brands by type: $e');
    }
  }

  // Get active brands only
  Future<List<ProductBrandModel>> getActiveBrands() async {
    try {
      final query = await _firestore
          .collection(collectionName)
          .where('isActive', isEqualTo: true)
          .orderBy('brandName')
          .get();

      final List<ProductBrandModel> brands = [];
      final usageCounts = await getUsageCounts();

      for (var doc in query.docs) {
        try {
          final brand = ProductBrandModel.fromFirestore(doc.id, doc.data());
          final usageCount = usageCounts[brand.brandName] ?? 0;
          brands.add(brand.copyWith(usageCount: usageCount));
        } catch (e) {
          print('Error parsing brand ${doc.id}: $e');
        }
      }

      return brands;
    } catch (e) {
      throw Exception('Failed to fetch active brands: $e');
    }
  }

  // Bulk update usage counts (useful for data migration or correction)
  Future<void> updateUsageCounts() async {
    try {
      final usageCounts = await getUsageCounts();
      final WriteBatch batch = _firestore.batch();
      int updateCount = 0;

      for (final entry in usageCounts.entries) {
        final brandName = entry.key;
        final usageCount = entry.value;

        // Find the brand document
        final QuerySnapshot snapshot = await _firestore
            .collection(collectionName)
            .where('brandName', isEqualTo: brandName)
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
        print('Updated usage counts for $updateCount brands');
      }
    } catch (e) {
      throw Exception('Failed to update usage counts: $e');
    }
  }

  // Get statistics service instance
  ProductBrandStatisticsService get statisticsService => _statisticsService;

  // Get usage efficiency (percentage of active brands that are used)
  Future<double> getUsageEfficiency() async {
    try {
      return await _statisticsService.getUsageEfficiency();
    } catch (e) {
      print('Error calculating usage efficiency: $e');
      return 0.0;
    }
  }

  // Get current statistics
  Future<ProductBrandStatistics> getCurrentStatistics() async {
    try {
      return await _statisticsService.getCurrentStatistics();
    } catch (e) {
      throw Exception('Failed to get current statistics: $e');
    }
  }

  // Get brand type statistics
  Future<BrandTypeStats?> getBrandTypeStatistics(BrandType brandType) async {
    try {
      return await _statisticsService.getBrandTypeStatistics(brandType);
    } catch (e) {
      print('Error getting brand type statistics for $brandType: $e');
      return null;
    }
  }

  // Cleanup method - remove brands with 0 usage and inactive status
  Future<int> cleanupInactiveUnusedBrands() async {
    try {
      final allBrands = await getAllBrandsWithUsage();
      final toDelete = allBrands
          .where((brand) => !brand.isActive && brand.usageCount == 0)
          .toList();

      if (toDelete.isEmpty) {
        return 0;
      }

      final batch = _firestore.batch();
      for (var brand in toDelete) {
        if (brand.id != null) {
          final docRef = _firestore.collection(collectionName).doc(brand.id!);
          batch.delete(docRef);
        }
      }

      await batch.commit();
      return toDelete.length;
    } catch (e) {
      throw Exception('Failed to cleanup inactive unused brands: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}