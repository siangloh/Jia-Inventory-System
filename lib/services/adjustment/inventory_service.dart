import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'adjustment_photo_service.dart';

class InventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 🚀 PERFORMANCE: Caching for expensive product resolution
  final Map<String, Map<String, dynamic>> _productCache = {};
  final Map<String, String> _productNameCache = {};
  final Map<String, String> _brandNameCache = {};
  final Map<String, Map<String, String>> _categoryCache = {};
  DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // 🚀 PERFORMANCE: Check if cache is still valid
  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheExpiry;
  }

  // 🚀 PERFORMANCE: Clear cache when expired
  void _clearCacheIfExpired() {
    if (!_isCacheValid()) {
      _productCache.clear();
      _productNameCache.clear();
      _brandNameCache.clear();
      _categoryCache.clear();
      _lastCacheUpdate = DateTime.now();
    }
  }

  // 🚀 PERFORMANCE: Background resolution for fast initial load
  Future<void> resolveProductDataInBackground(List<Map<String, dynamic>> lineItems) async {
    // Resolve product data in background without blocking UI
    for (final item in lineItems) {
      if (item['isResolving'] == true) {
        try {
          final resolvedProduct = await getResolvedProductData(item);
          // Update the item with resolved data
          item.addAll({
            ...resolvedProduct,
            'unitPrice': item['unitPrice'] ?? resolvedProduct['price'],
            'partNumber': _getDisplayValue(
                item['partNumber'] ?? resolvedProduct['partNumber']),
            'isResolving': false,
          });
        } catch (e) {
          // If resolution fails, mark as resolved with fallback data
          item.addAll({
            'productName': item['productName'] ?? 'N/A',
            'brandName': item['brandName'] ?? 'N/A',
            'categoryName': item['categoryName'] ?? 'N/A',
            'partNumber': _getDisplayValue(item['partNumber']),
            'sku': item['sku'] ?? 'N/A',
            'description': item['description'] ?? 'N/A',
            'isResolving': false,
          });
        }
      }
    }
  }

  Future<Map<String, dynamic>> getResolvedProductData(
      Map<String, dynamic> lineItem) async {
    try {
      String? productId = lineItem['productId']?.toString();
      if (productId == null || productId.isEmpty) {
        return _createDefaultProductData();
      }

      // 🚀 PERFORMANCE: Check cache first
      _clearCacheIfExpired();
      if (_productCache.containsKey(productId)) {
        final cached = Map<String, dynamic>.from(_productCache[productId]!);
        // Update with line item specific data
        cached['partNumber'] = _getDisplayValue(lineItem['partNumber'] ?? cached['partNumber']);
        cached['unitPrice'] = lineItem['unitPrice'] ?? cached['price'];
        return cached;
      }

      // Get product document
      final productDoc =
          await _firestore.collection('products').doc(productId).get();
      if (!productDoc.exists) {
        return _createDefaultProductData();
      }

      final productData = productDoc.data()!;
      Map<String, dynamic> resolved = {};

      // Resolve all references concurrently for better performance
      final futures = await Future.wait([
        _resolveProductName(productData['name']?.toString()),
        _resolveBrandName(productData['brand']?.toString()),
        _resolveCategoryInfo(productData['category']?.toString()),
      ]);

      resolved['productName'] = futures[0];
      resolved['displayName'] = futures[0];
      resolved['brandName'] = futures[1];
      resolved['brand'] = futures[1];

      final categoryInfo = futures[2] as Map<String, String>;
      resolved['categoryName'] = categoryInfo['name'];
      resolved['categoryIcon'] = categoryInfo['icon'];

      // Add product specifications
      resolved.addAll(_extractProductSpecs(productData));

      // Essential fields with N/A fallback
      resolved['productId'] = productId;
      resolved['sku'] = _getDisplayValue(productData['sku']);
      resolved['partNumber'] =
          _getDisplayValue(lineItem['partNumber'] ?? productData['partNumber']);
      resolved['description'] = _getDisplayValue(productData['description']);
      resolved['price'] =
          (productData['price'] ?? lineItem['unitPrice'] ?? 0).toDouble();

      // 🚀 PERFORMANCE: Cache the resolved data
      _productCache[productId] = Map<String, dynamic>.from(resolved);

      return resolved;
    } catch (e) {
      print('Error resolving product data: $e');
      return _createDefaultProductData();
    }
  }

  Map<String, dynamic> _createDefaultProductData() {
    return {
      'productName': 'N/A',
      'displayName': 'N/A',
      'brandName': 'N/A',
      'brand': 'N/A',
      'categoryName': 'N/A',
      'categoryIcon': 'category',
      'sku': 'N/A',
      'partNumber': 'N/A',
      'description': 'N/A',
      'price': 0.0,
    };
  }

  // ENHANCED: Helper method with N/A fallback
  String _getDisplayValue(dynamic value, {String defaultValue = 'N/A'}) {
    if (value == null) return defaultValue;
    String stringValue = value.toString().trim();
    if (stringValue.isEmpty || stringValue == 'null') return defaultValue;
    return stringValue;
  }


  // Enhanced method for single PO retrieval
    Future<Map<String, dynamic>?> getPurchaseOrderById(String poId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('purchaseOrder').doc(poId).get();
      
      if (doc.exists) {
        Map<String, dynamic> data = Map<String, dynamic>.from(
            doc.data() as Map); // FIXED: Proper casting
        data['id'] = doc.id;
        
        // Resolve product references with proper type casting
        if (data['lineItems'] != null) {
          final lineItems = List<Map<String, dynamic>>.from(
              (data['lineItems'] as List)
                  .map((item) => Map<String, dynamic>.from(item as Map)));
          
          for (int i = 0; i < lineItems.length; i++) {
            final item = lineItems[i];
            final resolvedProduct = await getResolvedProductData(item);
            lineItems[i] = Map<String, dynamic>.from({
              ...item,
              ...resolvedProduct,
              'unitPrice': item['unitPrice'] ?? resolvedProduct['price'],
              'partNumber': _getDisplayValue(
                  item['partNumber'] ?? resolvedProduct['partNumber']),
            });
          }
          
          data['lineItems'] = lineItems;
        }
        
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting PO by ID: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllProducts() async {
    try {
      QuerySnapshot snapshot =
          await _firestore.collection('products').orderBy('name').get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getProductById(String productId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('products').doc(productId).get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> createInventoryAdjustment(
      Map<String, dynamic> adjustmentData) async {
    try {
      await _firestore.collection('inventory_adjustments').add({
        ...adjustmentData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> getInventoryAdjustments() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('inventory_adjustments')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<int> getTotalItemsReceived() async {
    try {
      final snapshot = await _firestore.collection('purchaseOrder').get();
      int totalReceived = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lineItems = List<dynamic>.from(data['lineItems'] ?? []);

        for (final item in lineItems) {
          totalReceived += (item['quantityReceived'] ?? 0) as int;
        }
      }
      return totalReceived;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getTotalDiscrepancyReports() async {
    try {
      final snapshot = await _firestore.collection('discrepancy_reports').get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Stream<int> getTotalItemsReceivedStream() {
    return _firestore.collection('purchaseOrder').snapshots().map((snapshot) {
      int totalReceived = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lineItems = List<dynamic>.from(data['lineItems'] ?? []);
        for (final item in lineItems) {
          totalReceived += (item['quantityReceived'] ?? 0) as int;
        }
      }
      return totalReceived;
    });
  }

  Stream<int> getTotalDiscrepancyReportsStream() {
    return _firestore
        .collection('discrepancy_reports')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.length;
    });
  }

  Stream<List<Map<String, dynamic>>> getApprovedPurchaseOrdersStream() {
    return _firestore
        .collection('purchaseOrder')
        .where('status',
            whereIn: ['APPROVED', 'PARTIALLY_RECEIVED', 'COMPLETED', 'READY'])
        .orderBy('createdDate', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> orders = [];

      for (final doc in snapshot.docs) {
            final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;

            // Resolve line items with product references
            if (data['lineItems'] != null) {
              final lineItems = List<Map<String, dynamic>>.from(
                  (data['lineItems'] as List)
                      .map((item) => Map<String, dynamic>.from(item as Map)));

              // Resolve all line items concurrently
              final resolvedLineItems =
                  await Future.wait(lineItems.map((item) async {
                final resolvedProduct = await getResolvedProductData(item);
                return Map<String, dynamic>.from({
                  ...item,
                  ...resolvedProduct,
                  'unitPrice': item['unitPrice'] ?? resolvedProduct['price'],
                  'partNumber': _getDisplayValue(
                      item['partNumber'] ?? resolvedProduct['partNumber']),
                });
              }));

              data['lineItems'] = resolvedLineItems;
            }

          orders.add(data);
        }

          return orders;
        });
  }

  Stream<List<Map<String, dynamic>>>
      getPurchaseOrdersWithReceivedItemsStream() {
    try {
      // FIXED: Remove orderBy to avoid index requirement, sort in memory instead
      return _firestore
          .collection('purchaseOrder')
          .where('status', whereIn: ['COMPLETED', 'PARTIALLY_RECEIVED'])
          .snapshots()
          .asyncMap((snapshot) async {
            try {
              List<Map<String, dynamic>> orders = [];

              for (final doc in snapshot.docs) {
                final data = Map<String, dynamic>.from(doc.data());
                data['id'] = doc.id;

                final lineItems = List<Map<String, dynamic>>.from(
                    (data['lineItems'] as List? ?? [])
                        .map((item) => Map<String, dynamic>.from(item as Map)));

                bool hasReceivedItems =
                    lineItems.any((item) => (item['quantityReceived'] ?? 0) > 0);

                if (hasReceivedItems) {
                  // Resolve product references for received items
                  final resolvedLineItems =
                      await Future.wait(lineItems.map((item) async {
                    try {
                      final resolvedProduct = await getResolvedProductData(item);
                      return Map<String, dynamic>.from({
                        ...item,
                        ...resolvedProduct,
                        'unitPrice': item['unitPrice'] ?? resolvedProduct['price'],
                        'partNumber': _getDisplayValue(
                            item['partNumber'] ?? resolvedProduct['partNumber']),
                      });
                    } catch (e) {
                      // If resolution fails, return original item with fallback data
                      return Map<String, dynamic>.from({
                        ...item,
                        'productName': item['productName'] ?? 'N/A',
                        'brandName': item['brandName'] ?? 'N/A',
                        'categoryName': item['categoryName'] ?? 'N/A',
                        'partNumber': _getDisplayValue(item['partNumber']),
                        'sku': item['sku'] ?? 'N/A',
                        'description': item['description'] ?? 'N/A',
                      });
                    }
                  }));

                  data['lineItems'] = resolvedLineItems;
                  orders.add(data);
                }
              }

              // Sort in memory by createdDate (descending)
      orders.sort((a, b) {
        final aDate = a['createdDate'] as Timestamp?;
        final bDate = b['createdDate'] as Timestamp?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      return orders;
            } catch (e) {
              print('Error processing received items: $e');
              return <Map<String, dynamic>>[];
            }
          });
    } catch (e) {
      print('Error creating received items stream: $e');
      return Stream.value(<Map<String, dynamic>>[]);
    }
  }

  Future<String> _resolveProductName(String? productNameRef) async {
    if (productNameRef == null || productNameRef.isEmpty) return 'N/A';

    // 🚀 PERFORMANCE: Check cache first
    if (_productNameCache.containsKey(productNameRef)) {
      return _productNameCache[productNameRef]!;
    }

    try {
      final productNameDoc =
          await _firestore.collection('productNames').doc(productNameRef).get();
      if (productNameDoc.exists) {
        final data = productNameDoc.data()!;
        final resolvedName = data['productName']?.toString() ??
            data['name']?.toString() ??
            productNameRef;
        // 🚀 PERFORMANCE: Cache the result
        _productNameCache[productNameRef] = resolvedName;
        return resolvedName;
      }
      // 🚀 PERFORMANCE: Cache the fallback
      _productNameCache[productNameRef] = productNameRef;
      return productNameRef;
    } catch (e) {
      // 🚀 PERFORMANCE: Cache the fallback
      _productNameCache[productNameRef] = productNameRef;
      return productNameRef;
    }
  }

  // Resolve brand name from productBrands collection
  Future<String> _resolveBrandName(String? brandRef) async {
    if (brandRef == null || brandRef.isEmpty) return 'N/A';

    // 🚀 PERFORMANCE: Check cache first
    if (_brandNameCache.containsKey(brandRef)) {
      return _brandNameCache[brandRef]!;
    }

    try {
      final brandDoc =
          await _firestore.collection('productBrands').doc(brandRef).get();
      if (brandDoc.exists) {
        final data = brandDoc.data()!;
        final resolvedBrand = data['brandName']?.toString() ??
            data['name']?.toString() ??
            brandRef;
        // 🚀 PERFORMANCE: Cache the result
        _brandNameCache[brandRef] = resolvedBrand;
        return resolvedBrand;
      }
      // 🚀 PERFORMANCE: Cache the fallback
      _brandNameCache[brandRef] = brandRef;
      return brandRef;
    } catch (e) {
      // 🚀 PERFORMANCE: Cache the fallback
      _brandNameCache[brandRef] = brandRef;
      return brandRef;
    }
  }

  // Resolve category info from categories collection
  Future<Map<String, String>> _resolveCategoryInfo(String? categoryRef) async {
    if (categoryRef == null || categoryRef.isEmpty) {
      return {'name': 'N/A', 'icon': 'category'};
    }

    // 🚀 PERFORMANCE: Check cache first
    if (_categoryCache.containsKey(categoryRef)) {
      return Map<String, String>.from(_categoryCache[categoryRef]!);
    }

    try {
      final categoryDoc =
          await _firestore.collection('categories').doc(categoryRef).get();
      if (categoryDoc.exists) {
        final data = categoryDoc.data()!;
        final categoryInfo = {
          'name': data['name']?.toString() ?? categoryRef,
          'icon': data['iconName']?.toString() ?? 'category',
        };
        // 🚀 PERFORMANCE: Cache the result
        _categoryCache[categoryRef] = Map<String, String>.from(categoryInfo);
        return categoryInfo;
      }
      final fallbackInfo = {'name': categoryRef, 'icon': 'category'};
      // 🚀 PERFORMANCE: Cache the fallback
      _categoryCache[categoryRef] = Map<String, String>.from(fallbackInfo);
      return fallbackInfo;
    } catch (e) {
      final fallbackInfo = {'name': categoryRef, 'icon': 'category'};
      // 🚀 PERFORMANCE: Cache the fallback
      _categoryCache[categoryRef] = Map<String, String>.from(fallbackInfo);
      return fallbackInfo;
    }
  }

  // Extract product specifications
  Map<String, dynamic> _extractProductSpecs(Map<String, dynamic> productData) {
    Map<String, dynamic> specs = {};

    // Physical dimensions
    if (productData['dimensions'] != null) {
      final dimensions = productData['dimensions'] as Map<String, dynamic>;
      List<String> dimParts = [];

      if ((dimensions['length'] ?? 0) > 0)
        dimParts.add('L: ${dimensions['length']}m');
      if ((dimensions['width'] ?? 0) > 0)
        dimParts.add('W: ${dimensions['width']}m');
      if ((dimensions['height'] ?? 0) > 0)
        dimParts.add('H: ${dimensions['height']}m');

      if (dimParts.isNotEmpty) {
        specs['dimensionsDisplay'] = dimParts.join(' × ');
        specs['dimensions'] = dimensions;
      }
    }

    // Weight
    if ((productData['weight'] ?? 0) > 0) {
      specs['weight'] = '${productData['weight']} kg';
    }

    // Storage requirements
    if (productData['storageType']?.toString().isNotEmpty == true) {
      specs['storageType'] = productData['storageType'];
    }

    if (productData['movementFrequency']?.toString().isNotEmpty == true) {
      specs['movementFrequency'] = productData['movementFrequency'];
    }

    // Safety flags
    if (productData['requiresClimateControl'] == true) {
      specs['requiresClimateControl'] = true;
    }

    if (productData['isHazardousMaterial'] == true) {
      specs['isHazardousMaterial'] = true;
    }

    return specs;
  }

  // LEGACY METHODS - Keep for backward compatibility but marked for removal

  // ENHANCED: Consolidated method for all purchase order streams with performance optimization
  Stream<List<Map<String, dynamic>>> getAllPurchaseOrdersStream({
    List<String>? statusFilter,
    bool includeResolved = true,
    bool fastInitialLoad = false, // 🚀 NEW: Fast initial load option
  }) {
    try {
      Query query = _firestore.collection('purchaseOrder');
      
      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.where('status', whereIn: statusFilter);
        // Note: When using whereIn with orderBy, Firestore requires a composite index
        // For now, we'll order in memory to avoid the index requirement
        return query.snapshots().asyncMap((snapshot) async {
          List<Map<String, dynamic>> orders = [];
          
          for (final doc in snapshot.docs) {
            final data = Map<String, dynamic>.from(doc.data() as Map);
            data['id'] = doc.id;
            orders.add(data);
          }
          
          // Sort in memory by createdDate (descending)
      orders.sort((a, b) {
        final aDate = a['createdDate'] as Timestamp?;
        final bDate = b['createdDate'] as Timestamp?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
          
          // PERFORMANCE OPTIMIZATION: Only resolve product data if specifically requested
          // For initial loading, we can skip this heavy operation and show basic data first
          if (includeResolved) {
            // Process line items in parallel for better performance
            final ordersWithResolvedData = await Future.wait(
              orders.map((order) async {
                if (order['lineItems'] != null) {
                  final lineItems = List<Map<String, dynamic>>.from(
                      (order['lineItems'] as List)
                          .map((item) => Map<String, dynamic>.from(item as Map)));

                  // Process line items in parallel
                  final resolvedLineItems = await Future.wait(lineItems.map((item) async {
                    try {
                      final resolvedProduct = await getResolvedProductData(item);
                      return Map<String, dynamic>.from({
                        ...item,
                        ...resolvedProduct,
                        'unitPrice': item['unitPrice'] ?? resolvedProduct['price'],
                        'partNumber': _getDisplayValue(
                            item['partNumber'] ?? resolvedProduct['partNumber']),
                      });
                    } catch (e) {
                      // If resolution fails, return original item with fallback data
                      return Map<String, dynamic>.from({
                        ...item,
                        'productName': item['productName'] ?? 'N/A',
                        'brandName': item['brandName'] ?? 'N/A',
                        'categoryName': item['categoryName'] ?? 'N/A',
                        'partNumber': _getDisplayValue(item['partNumber']),
                        'sku': item['sku'] ?? 'N/A',
                        'description': item['description'] ?? 'N/A',
                      });
                    }
                  }));

                  order['lineItems'] = resolvedLineItems;
                }
                return order;
              })
            );
            return ordersWithResolvedData;
          }

      return orders;
        });
      } else {
        // No status filter, can use orderBy directly
        return query
            .orderBy('createdDate', descending: true)
            .snapshots()
            .asyncMap((snapshot) async {
              try {
                List<Map<String, dynamic>> orders = [];

                for (final doc in snapshot.docs) {
                  final data = Map<String, dynamic>.from(doc.data() as Map);
                  data['id'] = doc.id;

                  if (includeResolved && data['lineItems'] != null) {
                    final lineItems = List<Map<String, dynamic>>.from(
                        (data['lineItems'] as List)
                            .map((item) => Map<String, dynamic>.from(item as Map)));

                    if (fastInitialLoad) {
                      // 🚀 PERFORMANCE: Fast initial load - show basic data immediately
                      final fastLineItems = lineItems.map((item) {
                        return Map<String, dynamic>.from({
                          ...item,
                          'productName': item['productName'] ?? 'Loading...',
                          'brandName': item['brandName'] ?? 'Loading...',
                          'categoryName': item['categoryName'] ?? 'Loading...',
                          'partNumber': _getDisplayValue(item['partNumber']),
                          'sku': item['sku'] ?? 'Loading...',
                          'description': item['description'] ?? 'Loading...',
                          'isResolving': true, // Flag to indicate data is being resolved
                        });
                      }).toList();
                      data['lineItems'] = fastLineItems;
                    } else {
                      // Full resolution with caching
                      final resolvedLineItems = await Future.wait(lineItems.map((item) async {
                        try {
                          final resolvedProduct = await getResolvedProductData(item);
                          return Map<String, dynamic>.from({
                            ...item,
                            ...resolvedProduct,
                            'unitPrice': item['unitPrice'] ?? resolvedProduct['price'],
                            'partNumber': _getDisplayValue(
                                item['partNumber'] ?? resolvedProduct['partNumber']),
                            'isResolving': false, // Data is fully resolved
                          });
                        } catch (e) {
                          // If resolution fails, return original item with fallback data
                          return Map<String, dynamic>.from({
                            ...item,
                            'productName': item['productName'] ?? 'N/A',
                            'brandName': item['brandName'] ?? 'N/A',
                            'categoryName': item['categoryName'] ?? 'N/A',
                            'partNumber': _getDisplayValue(item['partNumber']),
                            'sku': item['sku'] ?? 'N/A',
                            'description': item['description'] ?? 'N/A',
                            'isResolving': false,
                          });
                        }
                      }));

                      data['lineItems'] = resolvedLineItems;
                    }
                  }

                  orders.add(data);
                }

                return orders;
              } catch (e) {
                print('Error processing purchase orders: $e');
                return <Map<String, dynamic>>[];
              }
            });
      }
    } catch (e) {
      print('Error creating purchase orders stream: $e');
      return Stream.value(<Map<String, dynamic>>[]);
    }
  }

  // REST OF THE METHODS REMAIN THE SAME...
  Future<void> updatePurchaseOrderStatus(String poId, String status) async {
    try {
      await _firestore.collection('purchaseOrder').doc(poId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'receivedAt': FieldValue.serverTimestamp(),
        'receivedBy': 'EMP0001', // Replace with actual user ID
      });
    } catch (e) {
      throw e;
    }
  }

  // ENHANCED: Real-time status broadcasting method
  Future<void> updatePurchaseOrderStatusWithBroadcast(String poId, String status) async {
    try {
      // Update the document
      await _firestore.collection('purchaseOrder').doc(poId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'receivedAt': FieldValue.serverTimestamp(),
        'receivedBy': 'EMP0001', // Replace with actual user ID
      });
      
      // The stream listeners will automatically pick up this change
      // No manual refresh needed - real-time updates handle it
      
    } catch (e) {
      print('Error updating purchase order status: $e');
      throw e;
    }
  }

  Future<void> updateLineItemQuantities({
    required String poId,
    required String lineItemId,
    required int quantityReceived,
    required int quantityDamaged,
  }) async {
    try {
      DocumentSnapshot poDoc =
          await _firestore.collection('purchaseOrder').doc(poId).get();

      if (!poDoc.exists) throw Exception('Purchase order not found');

      Map<String, dynamic> poData = poDoc.data() as Map<String, dynamic>;
      List<dynamic> lineItems = List<dynamic>.from(poData['lineItems'] ?? []);

      bool lineItemFound = false;
      String productId = '';

      for (int i = 0; i < lineItems.length; i++) {
        if (lineItems[i]['id'] == lineItemId) {
          int ordered = lineItems[i]['quantityOrdered'] ?? 0;
          int currentReceived = lineItems[i]['quantityReceived'] ?? 0;
          int currentDamaged = lineItems[i]['quantityDamaged'] ?? 0;

          lineItems[i]['quantityReceived'] = currentReceived + quantityReceived;
          lineItems[i]['quantityDamaged'] = currentDamaged + quantityDamaged;

          int totalReceived = lineItems[i]['quantityReceived'] ?? 0;
          int totalDamaged = lineItems[i]['quantityDamaged'] ?? 0;

          if (totalReceived + totalDamaged >= ordered) {
            lineItems[i]['status'] = 'RECEIVED';
          } else if (totalReceived > 0 || totalDamaged > 0) {
            lineItems[i]['status'] = 'PARTIALLY_RECEIVED';
          } else {
            lineItems[i]['status'] = 'PENDING';
          }

          productId = lineItems[i]['productId'] ?? '';
          lineItemFound = true;
          break;
        }
      }

      if (!lineItemFound) throw Exception('Line item not found');

      await _firestore.collection('purchaseOrder').doc(poId).update({
        'lineItems': lineItems,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'EMP0001', // Replace with actual user ID
      });

      if (productId.isNotEmpty && quantityReceived > 0) {
        await updateProductItemsStatus(poId, productId, quantityReceived);
      }
    } catch (e) {
      throw e;
    }
  }

  Future<void> updateProductItemsStatus(
      String poId, String productId, int quantityReceived) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('productItems')
          .where('productId', isEqualTo: productId)
          .where('purchaseOrderId', isEqualTo: poId)
          .where('status', isEqualTo: 'pending')
          .limit(quantityReceived)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.update({
          'status': 'received',
          'receivedAt': FieldValue.serverTimestamp(),
          'receivedBy': 'EMP0001', // Replace with actual user ID
        });
      }
    } catch (e) {
      throw e;
    }
  }

  Future<Map<String, dynamic>> createLocalDiscrepancyReport({
    required String poId,
    required String lineItemId,
    required String productId,
    required String productName,
    required String discrepancyType,
    required int quantityAffected,
    required String description,
    required List<String> photos,
  }) async {
    try {
      final reportId = 'LOCAL-${DateTime.now().millisecondsSinceEpoch}';

      List<Map<String, dynamic>> localPhotos = [];
      for (int i = 0; i < photos.length; i++) {
        localPhotos.add({
          'index': i,
          'fileName': photos[i],
        });
      }

      final report = {
        'id': reportId,
        'poId': poId,
        'lineItemId': lineItemId,
        'partId': productId,
        'partName': productName,
        'productId': productId,
        'discrepancyType': discrepancyType,
        'quantityAffected': quantityAffected,
        'description': description,
        'photos': localPhotos,
        'reportedBy': 'EMP0001',
        'reportedByName': 'Current User',
        'reportedAt': Timestamp.fromDate(DateTime.now()),
        'status': 'local',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      return report;
    } catch (e) {
      throw e;
    }
  }

  Future<void> saveLocalDiscrepancyReportsToFirebase({
    required String poId,
    required List<Map<String, dynamic>> localDiscrepancyReports,
  }) async {
    try {
      for (final report in localDiscrepancyReports) {
        List<String> photoFileNames = [];
        final localPhotoFiles =
            report['localPhotoFiles'] as List<dynamic>? ?? [];

        for (int i = 0; i < localPhotoFiles.length; i++) {
          final photoFile = localPhotoFiles[i];

          if (photoFile is File) {
            final fileName = await AdjustmentPhotoService.uploadPhoto(
              imageFile: photoFile,
              workflowType: 'receive_stock_discrepancy',
              workflowId:
                  '${poId}_${report['lineItemId']}_${DateTime.now().millisecondsSinceEpoch}',
            );

            if (fileName != null) {
              photoFileNames.add(fileName);
            }
          }
        }

        String poNumber = '';
        try {
          final poDoc =
              await _firestore.collection('purchaseOrder').doc(poId).get();
          if (poDoc.exists) {
            final poData = poDoc.data() as Map<String, dynamic>;
            poNumber = poData['poNumber'] ?? '';
          }
        } catch (e) {}

        double costImpact = 0.0;
        try {
          final poDoc =
              await _firestore.collection('purchaseOrder').doc(poId).get();
          if (poDoc.exists) {
            final poData = poDoc.data() as Map<String, dynamic>;
            final lineItems = poData['lineItems'] as List<dynamic>? ?? [];

            for (final lineItem in lineItems) {
              if (lineItem['id'] == report['lineItemId']) {
                final unitPrice = (lineItem['unitPrice'] ?? 0.0).toDouble();
                final quantityAffected =
                    (report['quantityAffected'] ?? 0).toInt();
                costImpact = unitPrice * quantityAffected;
                break;
              }
            }
          }
        } catch (e) {}

        final finalReport = {
          'id': 'DISC-${DateTime.now().millisecondsSinceEpoch}_${report['id']}',
          'items': [
            {
              'poId': poId,
              'poNumber': poNumber,
              'itemId': report['lineItemId'],
              'productId': report['productId'],
              'productName': report['partName'] ?? report['productName'],
              'partNumber': report['partNumber'] ?? '',
              'brand': report['brand'] ?? '',
              'quantity': report['quantityAffected'] ?? 1,
              'unitPrice': report['unitPrice'] ?? 0.0,
            }
          ],
          'discrepancyType': report['discrepancyType'],
          'description': report['description'],
          'photos': photoFileNames,
          'reportedBy': report['reportedBy'],
          'reportedByName': report['reportedByName'],
          'reportedAt':
              report['reportedAt'] ?? Timestamp.fromDate(DateTime.now()),
          'status': 'submitted',
          'costImpact': costImpact,
          'rootCause': '',
          'preventionMeasures': '',
          'supplierNotified': false,
          'insuranceClaimed': false,
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        };

        await _firestore.collection('discrepancy_reports').add(finalReport);
      }
    } catch (e) {
      throw e;
    }
  }

  Future<void> updateLineItemStatus(
      String poId, String lineItemId, int quantityReceived) async {
    try {
      DocumentSnapshot poDoc =
          await _firestore.collection('purchaseOrder').doc(poId).get();

      if (!poDoc.exists) {
        throw Exception('Purchase order not found');
      }

      Map<String, dynamic> poData = poDoc.data() as Map<String, dynamic>;
      List<dynamic> lineItems = List<dynamic>.from(poData['lineItems'] ?? []);

      bool lineItemFound = false;
      for (int i = 0; i < lineItems.length; i++) {
        if (lineItems[i]['id'] == lineItemId) {
          int ordered = lineItems[i]['quantityOrdered'] ?? 0;
          int currentReceived = lineItems[i]['quantityReceived'] ?? 0;
          int newReceived = currentReceived + quantityReceived;

          lineItems[i]['quantityReceived'] = newReceived;

          if (newReceived >= ordered) {
            lineItems[i]['status'] = 'RECEIVED';
          } else if (newReceived > 0) {
            lineItems[i]['status'] = 'PARTIALLY_RECEIVED';
          } else {
            lineItems[i]['status'] = 'PENDING';
          }

          lineItemFound = true;
          break;
        }
      }

      if (!lineItemFound) {
        throw Exception('Line item not found');
      }

      await _firestore.collection('purchaseOrder').doc(poId).update({
        'lineItems': lineItems,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw e;
    }
  }

  Future<void> receiveStock(String poId, String lineItemId,
      int quantityReceived, int quantityDamaged) async {
    try {
      DocumentSnapshot poDoc =
          await _firestore.collection('purchaseOrder').doc(poId).get();

      if (!poDoc.exists) {
        throw Exception('Purchase order not found');
      }

      Map<String, dynamic> poData = poDoc.data() as Map<String, dynamic>;
      List<dynamic> lineItems = List<dynamic>.from(poData['lineItems'] ?? []);

      String? productId;
      bool lineItemFound = false;
      for (int i = 0; i < lineItems.length; i++) {
        if (lineItems[i]['id'] == lineItemId) {
          productId = lineItems[i]['productId'];
          lineItemFound = true;
          break;
        }
      }

      if (!lineItemFound || productId == null) {
        throw Exception('Line item not found');
      }

      await updateLineItemQuantities(
        poId: poId,
        lineItemId: lineItemId,
        quantityReceived: quantityReceived,
        quantityDamaged: quantityDamaged,
      );

      if (quantityReceived > 0) {
        await updateProductItemsStatus(poId, productId, quantityReceived);
      }
    } catch (e) {
      throw e;
    }
  }
}
