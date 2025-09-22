// lib/dao/category_dao.dart
import 'package:barcode_scanner/scanbot_barcode_sdk.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_category_model.dart';
import 'dart:async';

class CategoryDao {
  static final CategoryDao _instance = CategoryDao._internal();

  factory CategoryDao() => _instance;

  CategoryDao._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'categories';

  // Stream for real-time category updates
  Stream<List<CategoryModel>> getCategoriesStream() {
    return _firestore
        .collection(_collection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            try {
              return CategoryModel.fromFirestore(doc.id, doc.data());
            } catch (e) {
              print('Error parsing category ${doc.id}: $e');
              return null;
            }
          })
          .where((category) => category != null)
          .cast<CategoryModel>()
          .toList();
    });
  }

  Future<bool> refreshCategories() async {
    try {
      print('🔄 Refreshing categories from Firebase...');

      // Force server query to bypass cache
      final snapshot = await _firestore
          .collection(_collection)
          .get(const GetOptions(source: Source.server));

      print('✅ Refreshed ${snapshot.docs.length} categories from server');
      return true;
    } catch (e) {
      print('❌ Refresh categories error: $e');
      return false;
    }
  }
  
  // Get all categories (one-time fetch)
  Future<List<CategoryModel>> getAllCategories() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('name')
          .get();
      return snapshot.docs
          .map((doc) {
            try {
              final data = Map<String, dynamic>.from(doc.data() as Map);
              return CategoryModel.fromFirestore(doc.id, data);
            } catch (e) {
              print('Error parsing category ${doc.id}: $e');
              return null;
            }
          })
          .where((category) => category != null)
          .cast<CategoryModel>()
          .toList();
    } catch (e) {
      print('Error fetching categories: $e');
      throw Exception('Failed to fetch categories: $e');
    }
  }

  // Get active categories only
  Future<List<CategoryModel>> getActiveCategories() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      List<CategoryModel> categories = snapshot.docs
          .map((doc) {
            try {
              return CategoryModel.fromFirestore(doc.id, doc.data());
            } catch (e) {
              print('Error parsing category ${doc.id}: $e');
              return null;
            }
          })
          .where((category) => category != null)
          .cast<CategoryModel>()
          .toList();

      // Sort by name in Dart code
      categories.sort((a, b) => a.name.compareTo(b.name));

      return categories;
    } catch (e) {
      print('Error fetching active categories: $e');
      throw Exception('Failed to fetch active categories: $e');
    }
  }

  // Get category by ID
  Future<CategoryModel?> getCategoryById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists && doc.data() != null) {
        return CategoryModel.fromFirestore(
            doc.id, Map<String, dynamic>.from(doc.data() as Map));
      }
      return null;
    } catch (e) {
      print('Error fetching category $id: $e');
      throw Exception('Failed to fetch category: $e');
    }
  }

  Future<CategoryModel?> getCategoryByName(String catName) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('name', isEqualTo: catName)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return CategoryModel.fromFirestore(
            doc.id, Map<String, dynamic>.from(doc.data() as Map));
      }
      return null;
    } catch (e) {
      print('Error fetching category $catName: $e');
      throw Exception('Failed to fetch category: $e');
    }
  }

  // Generate a unique category ID with sequential numbering
  Future<String> generateCategoryId() async {
    final prefix = "CAT_${DateTime.now().year}"; // e.g. CAT_2025
    final collection = _firestore.collection(_collection);

    try {
      // Get last document ID starting with "CAT_<year>_"
      final query = await collection
          .orderBy(FieldPath.documentId, descending: true)
          .startAt(['${prefix}_\uf8ff']) // highest under this prefix
          .endAt([prefix]) // lowest under this prefix
          .limit(1)
          .get();

      int nextNumber = 1;

      if (query.docs.isNotEmpty) {
        final lastId = query.docs.first.id; // e.g. CAT_2025_0007
        final lastNumberStr = lastId.split('_').last; // "0007"
        final lastNumber = int.tryParse(lastNumberStr) ?? 0;
        nextNumber = lastNumber + 1;
      }

      // Format new custom ID
      return "${prefix}_${nextNumber.toString().padLeft(4, '0')}"; // e.g. CAT_2025_0001
    } catch (e) {
      print('Error generating category ID: $e');
      // Fallback to timestamp-based ID
      return "Null";
    }
  }

  // Create category with duplicate check and return bool
  Future<bool> createCategory(CategoryModel category) async {
    print("Here Created");
    try {
      // Check if category name already exists
      final nameExists = await doesCategoryNameExist(category.name);
      if (nameExists) {
        return false; // Duplicate name found
      }

      // Generate custom ID
      final customId = await generateCategoryId();

      if (customId == "Null") {
        print("<Masuk>");

        return false;
      }

      // Check if ID already exists (collision)
      final idExists = await doesCategoryIdExist(customId);
      if (idExists) {
        return false; // ID collision
      }

      // Create category with custom ID
      final categoryWithId = category.copyWith(id: customId);
      print("Start Insert");

      // Use set() with custom document ID
      await _firestore
          .collection(_collection)
          .doc(customId)
          .set(categoryWithId.toFirestore());

      return true; // Success
    } catch (e) {
      print('Error creating category: $e');
      return false;
    }
  }

  // Update existing category
  Future<void> updateCategory(CategoryModel category) async {
    if (category.id == null) {
      throw ArgumentError('Category ID cannot be null for update');
    }

    try {
      await _firestore
          .collection(_collection)
          .doc(category.id!)
          .update(category.copyWith(updatedAt: DateTime.now()).toFirestore());
    } catch (e) {
      print('Error updating category ${category.id}: $e');
      throw Exception('Failed to update category: $e');
    }
  }

  // Delete category
  Future<void> deleteCategory(String categoryId) async {
    try {
      await _firestore.collection(_collection).doc(categoryId).delete();
    } catch (e) {
      print('Error deleting category $categoryId: $e');
      throw Exception('Failed to delete category: $e');
    }
  }

  // Toggle category active status
  Future<void> toggleCategoryStatus(
      String categoryId, bool currentStatus) async {
    try {
      await _firestore.collection(_collection).doc(categoryId).update({
        'isActive': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error toggling category status $categoryId: $e');
      throw Exception('Failed to toggle category status: $e');
    }
  }

  // Batch update category sort orders
  // Future<void> updateCategorySortOrders(List<CategoryModel> categories) async {
  //   try {
  //     final batch = _firestore.batch();
  //
  //     for (int i = 0; i < categories.length; i++) {
  //       final category = categories[i];
  //       if (category.id != null) {
  //         batch.update(
  //           _firestore.collection(_collection).doc(category.id),
  //           {
  //             'sortOrder': i,
  //             'updatedAt': FieldValue.serverTimestamp(),
  //           },
  //         );
  //       }
  //     }
  //
  //     await batch.commit();
  //   } catch (e) {
  //     print('Error updating category sort orders: $e');
  //     throw Exception('Failed to update category sort orders: $e');
  //   }
  // }

  // Get product counts for each category
  Future<Map<String, int>> getProductCountsByCategory() async {
    try {
      final productsSnapshot =
          await FirebaseFirestore.instance.collection('products').get();

      final Map<String, int> counts = {};
      for (var doc in productsSnapshot.docs) {
        final data = doc.data();
        final category = data['category'] as String?;
        if (category != null) {
          counts[category] = (counts[category] ?? 0) + 1;
        }
      }

      return counts;
    } catch (e) {
      print('Error loading product counts: $e');
      throw Exception('Failed to load product counts: $e');
    }
  }

  // Check if category name already exists (for validation)
  Future<bool> doesCategoryNameExist(String name, {String? excludeId}) async {
    try {
      Query query =
          _firestore.collection(_collection).where('name', isEqualTo: name);

      final snapshot = await query.get();

      if (excludeId != null) {
        // Exclude current category when updating
        return snapshot.docs.any((doc) => doc.id != excludeId);
      }

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking category name existence: $e');
      return false;
    }
  }

  // Utility method: Check if custom ID already exists
  Future<bool> doesCategoryIdExist(String categoryId) async {
    try {
      final doc =
          await _firestore.collection(_collection).doc(categoryId).get();
      return doc.exists;
    } catch (e) {
      print('Error checking category ID existence: $e');
      return false;
    }
  }

  // Validate category before saving
  Future<String?> validateCategory(CategoryModel category,
      {bool isUpdate = false}) async {
    // Check name is not empty
    print("ZMK");
    if (category.name.trim().isEmpty) {
      print("ZMK!!1");

      return 'Category name is required';
    }

    // Check if name already exists
    final nameExists = await doesCategoryNameExist(
      category.name.trim(),
      excludeId: isUpdate ? category.id : null,
    );

    if (nameExists) {
      return 'Category name already exists';
    }

    return null; // Valid
  }

  // Create category with validation
  Future<bool> createCategoryWithValidation(CategoryModel category) async {
    print("Come d");
    final validationError = await validateCategory(category);
    print("Here lah");
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    return await createCategory(category);
  }

  // Update category with validation
  Future<void> updateCategoryWithValidation(CategoryModel category) async {
    final validationError = await validateCategory(category, isUpdate: true);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    await updateCategory(category);
  }

  // Delete category with safety checks
  Future<void> deleteCategoryWithSafetyChecks(
      CategoryModel ctg) async {
    // Check if category is being used by products
    final productCounts = await getProductCountsByCategory();
    final productCount = productCounts[ctg.name] ?? 0;

    if (productCount > 0) {
      throw StateError(
          'Cannot delete category with $productCount products. Move or delete products first.');
    }

    await toggleCategoryStatus(ctg.id!, ctg.isActive);
  }

  // Get categories with product counts
  Future<List<CategoryModel>> getCategoriesWithProductCounts() async {
    try {
      final categories = await getAllCategories();
      final productCounts = await getProductCountsByCategory();

      return categories.map((category) {
        final count = productCounts[category.name] ?? 0;
        return category.copyWith(productCount: count);
      }).toList();
    } catch (e) {
      print('Error fetching categories with product counts: $e');
      throw Exception('Failed to fetch categories with product counts: $e');
    }
  }

  // Stream categories with product counts
  Stream<List<CategoryModel>> getCategoriesWithProductCountsStream() async* {
    await for (final categories in getCategoriesStream()) {
      try {
        final productCounts = await getProductCountsByCategory();

        final categoriesWithCounts = categories.map((category) {
          final count = productCounts[category.name] ?? 0;
          return category.copyWith(productCount: count);
        }).toList();

        yield categoriesWithCounts;
      } catch (e) {
        print('Error in categories with counts stream: $e');
        yield categories; // Return categories without counts on error
      }
    }
  }

  // Get category names for dropdown lists
  Future<List<String>> getCategoryNames({bool activeOnly = false}) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where("isActive", isEqualTo: true)
          .get();

      final Set<String> brands = {'All'};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final brand = data['name'] as String?;
        if (brand != null && brand.isNotEmpty) {
          brands.add(brand);
        }
      }

      final result = brands.toList()..sort();
      return result;
    } catch (e) {
      print('Error fetching category names: $e');
      throw Exception('Failed to fetch category names: $e');
    }
  }

  // Get category

  // Bulk operations for better performance
  Future<void> bulkCreateCategories(List<CategoryModel> categories) async {
    try {
      final batch = _firestore.batch();

      for (final category in categories) {
        // Check for duplicates first
        final nameExists = await doesCategoryNameExist(category.name);
        if (nameExists) {
          print('Skipping duplicate category: ${category.name}');
          continue;
        }

        final customId = await generateCategoryId();
        final categoryWithId = category.copyWith(id: customId);

        batch.set(
          _firestore.collection(_collection).doc(customId),
          categoryWithId.toFirestore(),
        );
      }

      await batch.commit();
    } catch (e) {
      print('Error bulk creating categories: $e');
      throw Exception('Failed to bulk create categories: $e');
    }
  }

  // Enhanced method to get categories by multiple IDs
  Future<List<CategoryModel>> getCategoriesByIds(
      List<String> categoryIds) async {
    if (categoryIds.isEmpty) return [];

    try {
      // Firestore 'in' queries are limited to 10 items, so we need to batch them
      final List<CategoryModel> allCategories = [];

      // Process in chunks of 10
      for (int i = 0; i < categoryIds.length; i += 10) {
        final chunk = categoryIds.skip(i).take(10).toList();

        final snapshot = await _firestore
            .collection(_collection)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        final categories = snapshot.docs
            .map((doc) => CategoryModel.fromFirestore(doc.id, doc.data()))
            .toList();

        allCategories.addAll(categories);
      }

      return allCategories;
    } catch (e) {
      print('Error fetching categories by IDs: $e');
      throw Exception('Failed to fetch categories by IDs: $e');
    }
  }
}