import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class ReturnService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  // ENHANCED: Cache for better performance
  final Map<String, String> _productNameCache = {};
  final Map<String, String> _brandNameCache = {};
  final Map<String, Map<String, String>> _categoryCache = {};

  // resolve product name reference from productNames collection
  Future<String> _resolveProductNameReference(String? nameReference) async {
    if (nameReference == null || nameReference.isEmpty || nameReference == 'N/A') {
      return 'N/A';
    }

    // Check cache first
    if (_productNameCache.containsKey(nameReference)) {
      return _productNameCache[nameReference]!;
    }

    try {
      
      final doc = await _firestore.collection('productNames').doc(nameReference).get();
      
      String resolvedName = 'N/A';
      if (doc.exists) {
        final data = doc.data()!;
        resolvedName = data['productName']?.toString() ?? 
                     data['name']?.toString() ?? 
                     nameReference;
        } else {
        resolvedName = nameReference;
      }
      
      // Cache the result
      _productNameCache[nameReference] = resolvedName;
      return resolvedName;
    } catch (e) {
      return nameReference;
    }
  }

  // resolve brand reference from productBrands collection
  Future<String> _resolveBrandReference(String? brandReference) async {
    if (brandReference == null || brandReference.isEmpty || brandReference == 'N/A') {
      return 'N/A';
    }

    // Check cache first
    if (_brandNameCache.containsKey(brandReference)) {
      return _brandNameCache[brandReference]!;
    }

    try {
      
      final doc = await _firestore.collection('productBrands').doc(brandReference).get();
      
      String resolvedBrand = 'N/A';
      if (doc.exists) {
        final data = doc.data()!;
        resolvedBrand = data['brandName']?.toString() ?? 
                      data['name']?.toString() ?? 
                      brandReference;
      } else {
        resolvedBrand = brandReference;
      }
      
      // Cache the result
      _brandNameCache[brandReference] = resolvedBrand;
      return resolvedBrand;
      } catch (e) {
      return brandReference;
    }
  }

  // resolve category reference from categories collection
  Future<Map<String, String>> _resolveCategoryReference(String? categoryReference) async {
    if (categoryReference == null || categoryReference.isEmpty || categoryReference == 'N/A') {
      return {'name': 'N/A', 'icon': 'category'};
    }

    // Check cache first
    if (_categoryCache.containsKey(categoryReference)) {
      return _categoryCache[categoryReference]!;
    }

    try {
      
      final doc = await _firestore.collection('categories').doc(categoryReference).get();
      
      Map<String, String> resolvedCategory;
      if (doc.exists) {
        final data = doc.data()!;
        resolvedCategory = {
          'name': data['name']?.toString() ?? categoryReference,
          'icon': data['iconName']?.toString() ?? 'category',
        };
      } else {
        resolvedCategory = {
          'name': categoryReference,
          'icon': 'category',
        };
      }
      
      // Cache the result
      _categoryCache[categoryReference] = resolvedCategory;
      return resolvedCategory;
    } catch (e) {
      return {'name': categoryReference, 'icon': 'category'};
    }
  }

  // ENHANCED: resolve product data from products collection with two-level references
  Future<Map<String, dynamic>> _resolveProductFromProductsCollection(String? productId) async {
    if (productId == null || productId.isEmpty) {
      return {
        'productName': 'N/A',
        'brandName': 'N/A',
        'categoryName': 'N/A',
        'sku': 'N/A',
        'partNumber': 'N/A',
        'unitPrice': 0.0,
      };
    }

    try {
      
      final productDoc = await _firestore.collection('products').doc(productId).get();
      
      if (!productDoc.exists) {
    return {
          'productName': 'N/A',
          'brandName': 'N/A', 
          'categoryName': 'N/A',
          'sku': 'N/A',
          'partNumber': 'N/A',
          'unitPrice': 0.0,
        };
      }

      final productData = productDoc.data()!;

      // resolve the two-level references concurrently
      final futures = await Future.wait([
        _resolveProductNameReference(productData['name']?.toString()),
        _resolveBrandReference(productData['brand']?.toString()), 
        _resolveCategoryReference(productData['category']?.toString()),
      ]);

      final result = {
        'productName': futures[0] as String,
        'brandName': futures[1] as String,
        'categoryName': (futures[2] as Map<String, String>)['name']!,
        'categoryIcon': (futures[2] as Map<String, String>)['icon']!,
        'sku': productData['sku']?.toString() ?? 'N/A',
        'partNumber': productData['partNumber']?.toString() ?? 'N/A',
        'unitPrice': (productData['price'] ?? 0).toDouble(),
      };

      return result;

    } catch (e) {
    return {
        'productName': 'N/A',
        'brandName': 'N/A',
        'categoryName': 'N/A', 
        'sku': 'N/A',
        'partNumber': 'N/A',
        'unitPrice': 0.0,
      };
    }
  }

  // ENHANCED: get damaged items with proper reference resolution and return status filtering
  Future<List<Map<String, dynamic>>> getDamagedItemsFromDiscrepancies({
    required String timeFilter,
    required List<String> suppliers,
    bool excludeReturned = true,
  }) async {
    try {
      Query query = _firestore.collection('discrepancy_reports')
          .where('status', isEqualTo: 'submitted');
      
      final snapshot = await query.get();

      List<Map<String, dynamic>> allItems = [];
      
      for (final doc in snapshot.docs) {
        final reportData = Map<String, dynamic>.from(doc.data() as Map);
        reportData['id'] = doc.id;
        
        List<dynamic> itemsToProcess = [];
        
        if (reportData['items'] != null && reportData['items'] is List) {
          itemsToProcess = reportData['items'] as List;
        } else {
          itemsToProcess = [reportData];
        }
        
        for (final itemData in itemsToProcess) {
          final item = Map<String, dynamic>.from(itemData);
          
          final itemId = item['itemId'] ?? item['lineItemId'] ?? reportData['lineItemId'];
          final productId = item['productId'] ?? item['partId'] ?? reportData['partId'];
          
          if (itemId == null && productId == null) continue;
          
          final processedItem = {
            'id': doc.id,
            'lineItemId': itemId,
            'productId': productId,
            'partId': productId,
            'productName': item['productName'] ?? reportData['partName'] ?? 'Unknown Product',
            'brandName': item['brand'] ?? reportData['brandName'] ?? 'N/A',
            'brand': item['brand'] ?? reportData['brandName'] ?? 'N/A',
            'supplierName': reportData['supplierName'] ?? 'Unknown Supplier',
            'sku': item['sku'] ?? reportData['sku'] ?? 'N/A',
            'partNumber': item['partNumber'] ?? reportData['partNumber'] ?? 'N/A',
            'poId': item['poId'] ?? reportData['poId'] ?? '',
            'poNumber': item['poNumber'] ?? reportData['poNumber'] ?? 'N/A',
            'quantityAffected': item['quantity'] ?? reportData['quantityAffected'] ?? 1,
            'unitPrice': item['unitPrice'] ?? 0.0,
            'discrepancyType': reportData['discrepancyType'] ?? '',
            'description': reportData['description'] ?? '',
            'reportedAt': reportData['reportedAt'],
            'reportedBy': reportData['reportedBy'] ?? '',
            'reportedByName': reportData['reportedByName'] ?? '',
            'status': reportData['status'] ?? 'submitted',
            'returnStatus': reportData['returnStatus'],
            'photos': reportData['photos'] ?? [],
          };
          
          bool shouldInclude = true;
          
          if (excludeReturned) {
            final returnStatus = processedItem['returnStatus'];
            if (returnStatus == 'RETURNED' || returnStatus == 'COMPLETED' || returnStatus == 'PENDING') {
              shouldInclude = false;
            }
          }
          
          if (shouldInclude && timeFilter != 'All Time') {
            DateTime startDate = _getStartDateFromFilter(timeFilter);
            final reportedAt = processedItem['reportedAt'];
            if (reportedAt != null) {
              final reportDate = reportedAt is Timestamp 
                  ? reportedAt.toDate() 
                  : DateTime.parse(reportedAt.toString());
              if (reportDate.isBefore(startDate)) {
                shouldInclude = false;
              }
            }
          }
          
          if (shouldInclude) {
            await _enhanceItemData(processedItem);
            allItems.add(processedItem);
          }
        }
      }

      allItems.sort((a, b) {
        final aDate = a['reportedAt'] as Timestamp?;
        final bDate = b['reportedAt'] as Timestamp?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      return allItems;

    } catch (e) {
      return [];
    }
  }

  Future<void> _enhanceItemData(Map<String, dynamic> item) async {
    try {
      final productId = item['productId'];
      if (productId != null && productId.toString().isNotEmpty) {
        if (item['productName'] == 'Unknown Product' || item['productName'] == 'N/A') {
          final resolvedProduct = await _resolveProductFromProductsCollection(productId);
          if (resolvedProduct['productName'] != 'N/A') {
            item['productName'] = resolvedProduct['productName'];
            item['brandName'] = resolvedProduct['brandName'];
            item['brand'] = resolvedProduct['brandName'];
            item['sku'] = resolvedProduct['sku'];
            item['partNumber'] = resolvedProduct['partNumber'];
          }
        }
      }
      
      final poId = item['poId'];
      if (poId != null && poId.toString().isNotEmpty) {
        if (item['supplierName'] == 'Unknown Supplier' || item['poNumber'] == 'N/A') {
          await _resolvePOData(item);
        }
      }
    } catch (e) {
      // continue even if enhancement fails
    }
  }


  // resolve po data (supplier info, po number)
  Future<void> _resolvePOData(Map<String, dynamic> report) async {
    try {
      final poId = report['poId']?.toString();
      if (poId == null || poId.isEmpty) return;


      final poDoc = await _firestore.collection('purchaseOrder').doc(poId).get();
      
      if (poDoc.exists) {
        final poData = poDoc.data()!;
        report['poNumber'] = poData['poNumber'] ?? 'N/A';
        report['supplierName'] = poData['supplierName'] ?? 'N/A';
        report['supplierEmail'] = poData['supplierEmail'] ?? 'N/A';
        report['supplierPhone'] = poData['supplierPhone'] ?? 'N/A';
        
      }
    } catch (e) {
    }
  }


  // ENHANCED: create return with properly resolved data and status tracking
  Future<Map<String, dynamic>> createReturn(Map<String, dynamic> returnData) async {
    try {
      
      final batch = _firestore.batch();

      // generate return id
      final returnId = await _generateReturnId();

      // resolve all references in selected items before saving
      final selectedItems = returnData['items'] as List? ?? [];
      final resolvedItems = <Map<String, dynamic>>[];

      for (final item in selectedItems) {
        final resolvedItem = Map<String, dynamic>.from(item);
        
        // resolve references in the main item
        await _resolveItemReferences(resolvedItem);
        
        // resolve references in nested items
        if (resolvedItem['items'] != null && resolvedItem['items'] is List) {
          final nestedItems = resolvedItem['items'] as List;
          for (int i = 0; i < nestedItems.length; i++) {
            final nestedItem = Map<String, dynamic>.from(nestedItems[i]);
            await _resolveNestedItemReferences(nestedItem);
            nestedItems[i] = nestedItem;
          }
        }
        
        resolvedItems.add(resolvedItem);
      }

      // calculate totals
      int totalQuantity = 0;
      double totalValue = 0.0;
      final itemDetails = returnData['itemDetails'] as Map<String, Map<String, dynamic>>? ?? {};

      for (var item in resolvedItems) {
        final itemId = item['id'] ?? item['productId'];
        final details = itemDetails[itemId] ?? {};
        final quantity = (details['quantity'] ?? 0) as int;
        final unitPrice = (item['unitPrice'] ?? 0.0) as num;

        totalQuantity += quantity;
        totalValue += quantity * unitPrice.toDouble();
      }

      // create return document with resolved data
      final returnDoc = {
        'returnId': returnId,
        'returnNumber': returnId,
        'returnType': returnData['returnType'] ?? 'INTERNAL_RETURN',
        'status': 'PENDING',
        'returnMethod': returnData['returnMethod'] ?? '',
        'carrierName': returnData['carrierName'] ?? '',
        'trackingNumber': returnData['trackingNumber'] ?? _generateTrackingNumber(),
        'pickupDetails': returnData['pickupDetails'] ?? {},
        'shipmentDetails': returnData['shipmentDetails'] ?? {},
        'selectedItems': resolvedItems,
        'itemDetails': itemDetails,
        'createdByUserId': 'CURRENT_USER_ID',
        'createdByUserName': 'Current User',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'totalItems': resolvedItems.length,
        'totalQuantity': totalQuantity,
        'totalValue': totalValue,
      };


      batch.set(_firestore.collection('returns').doc(returnId), returnDoc);

      // ENHANCED: update related documents with return status tracking
      for (var item in resolvedItems) {
        await _updateRelatedDocuments(batch, item, itemDetails, returnId);
      }

      await batch.commit();

      return {
        'returnId': returnId,
        'success': true,
      };

          } catch (e) {
      throw Exception('failed to create return: $e');
    }
  }

  // resolve references in main item
  Future<void> _resolveItemReferences(Map<String, dynamic> item) async {
    try {
      // try to get productId from various fields
      final productId = item['productId']?.toString() ?? item['partId']?.toString();
      
      if (productId != null && productId.isNotEmpty) {
        
        final resolved = await _resolveProductFromProductsCollection(productId);
        
        // update item with resolved values
        item['productName'] = resolved['productName'];
        item['brandName'] = resolved['brandName'];
        item['brand'] = resolved['brandName']; // alias
        item['sku'] = resolved['sku'];
        item['partNumber'] = resolved['partNumber'];
        
        if (item['unitPrice'] == null) {
          item['unitPrice'] = resolved['unitPrice'];
        }
        
      }

      // ensure fallbacks
      item['productName'] = item['productName'] ?? 'N/A';
      item['brandName'] = item['brandName'] ?? item['brand'] ?? 'N/A';
      item['supplierName'] = item['supplierName'] ?? 'N/A';
      item['sku'] = item['sku'] ?? 'N/A';
      item['partNumber'] = item['partNumber'] ?? 'N/A';

          } catch (e) {
          }
        }

  // resolve references in nested items array
  Future<void> _resolveNestedItemReferences(Map<String, dynamic> nestedItem) async {
    try {
      // check if productName and brand are references that need resolution
      final productNameRef = nestedItem['productName']?.toString();
      final brandRef = nestedItem['brand']?.toString();
      
      
      // resolve productName reference if it looks like a reference
      if (productNameRef != null && productNameRef.startsWith('proName_')) {
        final resolvedName = await _resolveProductNameReference(productNameRef);
        nestedItem['productName'] = resolvedName;
      }
      
      // resolve brand reference if it looks like a reference  
      if (brandRef != null && brandRef.startsWith('proBrand_')) {
        final resolvedBrand = await _resolveBrandReference(brandRef);
        nestedItem['brand'] = resolvedBrand;
      }

      // apply fallbacks
      nestedItem['productName'] = nestedItem['productName'] ?? 'N/A';
      nestedItem['brand'] = nestedItem['brand'] ?? 'N/A';
      nestedItem['sku'] = nestedItem['sku'] ?? 'N/A';
      nestedItem['partNumber'] = nestedItem['partNumber'] ?? 'N/A';
      nestedItem['category'] = nestedItem['category'] ?? 'N/A';

          } catch (e) {
    }
  }

  // ENHANCED: update related documents after return creation with better status tracking
  Future<void> _updateRelatedDocuments(
    WriteBatch batch,
    Map<String, dynamic> item,
    Map<String, Map<String, dynamic>> itemDetails,
    String returnId,
  ) async {
    try {
      final itemId = item['id'] ?? item['productId'];
      final details = itemDetails[itemId] ?? {};
      final quantity = (details['quantity'] ?? 0) as int;

      // ENHANCED: update discrepancy report status with return tracking
      if (item['id'] != null) {
        try {
          final discrepancyRef = _firestore.collection('discrepancy_reports').doc(item['id']);
          batch.update(discrepancyRef, {
            'returnStatus': 'PENDING',
            'returnDate': FieldValue.serverTimestamp(),
        'returnId': returnId,
            'returnQuantity': quantity,
          });
    } catch (e) {
        }
      }

      // update product items status if needed
      if (item['productId'] != null && quantity > 0) {
        try {
          final itemsSnapshot = await _firestore
              .collection('productItems')
              .where('productId', isEqualTo: item['productId'])
              .where('status', isEqualTo: 'damaged')
              .limit(quantity)
              .get();

          for (var doc in itemsSnapshot.docs) {
            batch.update(doc.reference, {
              'status': 'returned',
              'returnId': returnId,
              'returnDate': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
        }
      }

    } catch (e) {
    }
  }

  // helper methods
  DateTime _getStartDateFromFilter(String filter) {
    final now = DateTime.now();
    switch (filter) {
      case 'Last 7 Days':
        return now.subtract(Duration(days: 7));
      case 'Last 30 Days':
        return now.subtract(Duration(days: 30));
      case 'Last 3 Months':
        return now.subtract(Duration(days: 90));
      case 'Last 6 Months':
        return now.subtract(Duration(days: 180));
      default:
        return DateTime(2000);
    }
  }

  Future<String> _generateReturnId() async {
    final year = DateTime.now().year;
    final prefix = 'RET-$year-';

    final snapshot = await _firestore
        .collection('returns')
        .where('returnId', isGreaterThanOrEqualTo: prefix)
        .where('returnId', isLessThan: '${prefix}ZZZ')
        .orderBy('returnId', descending: true)
        .limit(1)
        .get();

    int nextNumber = 1;
    if (snapshot.docs.isNotEmpty) {
      final lastId = snapshot.docs.first.data()['returnId'] as String;
      final lastNumber = int.tryParse(lastId.split('-').last) ?? 0;
      nextNumber = lastNumber + 1;
    }

    return '$prefix${nextNumber.toString().padLeft(5, '0')}';
  }

  String _generateTrackingNumber() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'TRK${timestamp.toString().substring(3)}';
  }

  // ENHANCED: real-time stream with proper reference resolution
  Stream<List<Map<String, dynamic>>> getReturnsStream() {
    return _firestore.collection('returns')
        .snapshots()
        .asyncMap((snapshot) async {
      try {
        List<Map<String, dynamic>> returns = [];
        
        for (final doc in snapshot.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          
          // the data should already be resolved since we resolve before saving
          // but add a fallback check
          if (data['selectedItems'] != null && data['selectedItems'] is List) {
            final items = data['selectedItems'] as List;
            for (int i = 0; i < items.length; i++) {
              final item = Map<String, dynamic>.from(items[i]);
              
              // only re-resolve if still showing references/unknown values
              if (item['productName'] == 'Unknown Product' || 
                  (item['productName'] != null && item['productName'].toString().startsWith('proName_'))) {
                await _resolveItemReferences(item);
              }
              
              items[i] = item;
            }
          }
          
          returns.add(data);
        }
        
        // sort by createdAt (descending)
        returns.sort((a, b) {
          final aDate = a['createdAt'] as Timestamp?;
          final bDate = b['createdAt'] as Timestamp?;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
        
        return returns;
      } catch (e) {
        return <Map<String, dynamic>>[];
      }
    });
  }

  // ENHANCED: search method with better filtering
  Future<List<Map<String, dynamic>>> searchDamagedItems(String query) async {
    if (query.isEmpty) {
      return getDamagedItemsFromDiscrepancies(
        timeFilter: 'All Time',
        suppliers: [],
        excludeReturned: true, // Only show items that haven't been returned yet
      );
    }

    final lowerQuery = query.toLowerCase();
    final allItems = await getDamagedItemsFromDiscrepancies(
      timeFilter: 'All Time',
      suppliers: [],
      excludeReturned: true, // Only show items that haven't been returned yet
    );

    return allItems.where((item) {
      final productName = (item['productName'] ?? '').toString().toLowerCase();
      final sku = (item['sku'] ?? '').toString().toLowerCase();
      final partNumber = (item['partNumber'] ?? '').toString().toLowerCase();
      final discrepancyId = (item['id'] ?? '').toString().toLowerCase();

      return productName.contains(lowerQuery) ||
          sku.contains(lowerQuery) ||
          partNumber.contains(lowerQuery) ||
          discrepancyId.contains(lowerQuery);
    }).toList();
  }

  // NEW: Complete return with proper status tracking
  Future<void> completeReturn({
    required String returnId,
    required String resolution,
    String? notes,
  }) async {
    try {
      final batch = _firestore.batch();

      // get return data first
      final returnDoc = await _firestore.collection('returns').doc(returnId).get();
      if (!returnDoc.exists) {
        throw Exception('return not found');
      }

      final returnData = returnDoc.data()!;

      // update return document
      batch.update(
          _firestore.collection('returns').doc(returnId),
          {
            'status': 'COMPLETED',
            'resolution': resolution,
            'resolutionNotes': notes,
            'resolvedAt': FieldValue.serverTimestamp(),
            'resolvedByUserId': 'CURRENT_USER_ID',
            'resolvedByUserName': 'Current User',
            'updatedAt': FieldValue.serverTimestamp(),
          }
      );

      // ENHANCED: update related discrepancy reports with completion status
      if (returnData['selectedItems'] != null) {
        final items = returnData['selectedItems'] as List;
        for (var item in items) {
          if (item['id'] != null) {
            // this is the discrepancy report id
            try {
              batch.update(
                  _firestore.collection('discrepancy_reports').doc(item['id']),
                  {
                    'returnStatus': 'COMPLETED',
                    'returnCompletedAt': FieldValue.serverTimestamp(),
                    'returnResolution': resolution,
                  }
              );
            } catch (e) {
            }
          }
        }
      }

      // handle different resolution types
      switch (resolution) {
        case 'CREDIT_ISSUED':
        // update supplier credit if needed
          if (returnData['supplierId'] != null) {
            // you can add logic here to track supplier credits
          }
          break;

        case 'REPLACEMENT_RECEIVED':
        // update inventory for replacements
          if (returnData['selectedItems'] != null) {
            final items = returnData['selectedItems'] as List;
            final details = returnData['itemDetails'] as Map<String, dynamic>? ?? {};

            for (var item in items) {
              if (item['productId'] != null) {
                final itemId = item['id'] ?? item['productId'];
                final quantity = (details[itemId]?['quantity'] ?? 0) as int;

                // increment stock for replacement
                batch.update(
                    _firestore.collection('products').doc(item['productId']),
                    {
                      'stockQuantity': FieldValue.increment(quantity),
                    }
                );
              }
            }
          }
          break;

        case 'DISPOSED':
        // items have been disposed, no further action needed
          break;

        case 'RETURNED_TO_STOCK':
        // items returned to stock (for internal returns)
          if (returnData['selectedItems'] != null) {
            final items = returnData['selectedItems'] as List;
            final details = returnData['itemDetails'] as Map<String, dynamic>? ?? {};

            for (var item in items) {
              if (item['productId'] != null) {
                final itemId = item['id'] ?? item['productId'];
                final quantity = (details[itemId]?['quantity'] ?? 0) as int;

                // return to stock
                batch.update(
                    _firestore.collection('products').doc(item['productId']),
                    {
                      'stockQuantity': FieldValue.increment(quantity),
                    }
                );

                // update product items status back to available
                try {
                  final itemsSnapshot = await _firestore
                      .collection('productItems')
                      .where('productId', isEqualTo: item['productId'])
                      .where('status', isEqualTo: 'returned')
                      .limit(quantity)
                      .get();

                  for (var doc in itemsSnapshot.docs) {
                    batch.update(doc.reference, {'status': 'available'});
                  }
                } catch (e) {
                }
              }
            }
          }
          break;

        default:
      }

      await batch.commit();
    } catch (e) {
      throw e;
    }
  }

  // upload return documents to supabase
  Future<void> uploadReturnDocuments(String returnId, List<File> documents) async {
    List<String> uploadedUrls = [];

    for (int i = 0; i < documents.length; i++) {
      final file = documents[i];
      final fileName = 'returns/$returnId/RET-${DateTime.now().millisecondsSinceEpoch}_photo${i + 1}.jpg';

      await _supabase.storage
          .from('discrepancy-photos')
          .upload(fileName, file);

        final url = _supabase.storage
            .from('discrepancy-photos')
            .getPublicUrl(fileName);
        uploadedUrls.add(url);
    }

    // update return document with photo urls
    await _firestore.collection('returns').doc(returnId).update({
      'photos': uploadedUrls,
    });
  }

  // get total returns count
  Future<int> getTotalReturns() async {
    try {
      final snapshot = await _firestore.collection('returns').get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // get total returns stream
  Stream<int> getTotalReturnsStream() {
    return _firestore.collection('returns').snapshots().map((snapshot) {
      return snapshot.docs.length;
    });
  }

  // get return counts by type
  Future<Map<String, int>> getReturnCountsByType() async {
    try {
      final snapshot = await _firestore.collection('returns').get();

      Map<String, int> counts = {
        'INTERNAL': 0,
        'SUPPLIER': 0,
        'CUSTOMER': 0,
        'TOTAL': 0,
      };

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final returnType = data['returnType'] as String?;

        if (returnType != null && counts.containsKey(returnType)) {
          counts[returnType] = counts[returnType]! + 1;
        }
        counts['TOTAL'] = counts['TOTAL']! + 1;
      }

      return counts;
    } catch (e) {
      return {
        'INTERNAL': 0,
        'SUPPLIER': 0,
        'CUSTOMER': 0,
        'TOTAL': 0,
      };
    }
  }

  // ENHANCED: get return details by id with proper resolution
  Future<Map<String, dynamic>> getReturnDetails(String returnId) async {
    try {
      final doc = await _firestore.collection('returns').doc(returnId).get();

      if (!doc.exists) {
        throw Exception('return not found');
      }

      final data = doc.data()!;

      // process the data to ensure all fields are properly formatted
        final returnData = {
          'id': doc.id,
          ...data,
        };

      // ensure items array exists and is properly formatted
          if (returnData['selectedItems'] != null) {
            final items = returnData['selectedItems'] as List;
        for (var item in items) {
          // fix any missing fields in items
          if (item['productName'] == null || item['productName'].toString().isEmpty) {
            final resolvedData = await _resolveProductFromProductsCollection(item['productId']);
            item['productName'] = resolvedData['productName'];
          }
          if (item['brandName'] == null || item['brandName'].toString().isEmpty) {
            final resolvedData = await _resolveProductFromProductsCollection(item['productId']);
            item['brandName'] = resolvedData['brandName'];
          }
          if (item['unitPrice'] == null) {
            final resolvedData = await _resolveProductFromProductsCollection(item['productId']);
            item['unitPrice'] = resolvedData['unitPrice'];
          }
        }
      }

      // calculate summary statistics if not present
      if (returnData['totalValue'] == null) {
        double totalValue = 0.0;
        if (returnData['selectedItems'] != null && returnData['itemDetails'] != null) {
          final items = returnData['selectedItems'] as List;
          final details = returnData['itemDetails'] as Map<String, dynamic>;

          for (var item in items) {
            final itemId = item['id'] ?? item['productId'];
            final itemDetail = details[itemId] ?? {};
            final quantity = (itemDetail['quantity'] ?? 0) as int;
            final unitPrice = (item['unitPrice'] ?? 0.0) as num;
            totalValue += quantity * unitPrice.toDouble();
          }
        }
        returnData['totalValue'] = totalValue;
      }

      return returnData;
    } catch (e) {
      throw e;
    }
  }

  // NEW: Cancel a return with proper status tracking
  Future<void> cancelReturn(String returnId, String reason) async {
    try {
      final batch = _firestore.batch();

      // get return data
      final returnDoc = await _firestore.collection('returns').doc(returnId).get();
      if (!returnDoc.exists) {
        throw Exception('return not found');
      }

      final returnData = returnDoc.data()!;

      // update return status
      batch.update(
          _firestore.collection('returns').doc(returnId),
          {
            'status': 'CANCELLED',
            'cancelReason': reason,
            'cancelledAt': FieldValue.serverTimestamp(),
            'cancelledByUserId': 'CURRENT_USER_ID',
            'updatedAt': FieldValue.serverTimestamp(),
          }
      );

      // revert related changes
      if (returnData['selectedItems'] != null) {
        final items = returnData['selectedItems'] as List;
        final details = returnData['itemDetails'] as Map<String, dynamic>? ?? {};

        for (var item in items) {
          // update discrepancy report status back
          if (item['id'] != null) {
            batch.update(
                _firestore.collection('discrepancy_reports').doc(item['id']),
                {
                  'returnStatus': null,
                  'returnDate': null,
                  'returnId': null,
                }
            );
          }

          // restore product items status
          if (item['productId'] != null) {
            final itemId = item['id'] ?? item['productId'];
            final quantity = (details[itemId]?['quantity'] ?? 0) as int;

            // restore to damaged status
            try {
              final itemsSnapshot = await _firestore
                  .collection('productItems')
                  .where('productId', isEqualTo: item['productId'])
                  .where('status', isEqualTo: 'returned')
                  .where('returnId', isEqualTo: returnId)
                  .limit(quantity)
                  .get();

              for (var doc in itemsSnapshot.docs) {
                batch.update(doc.reference, {
                  'status': 'damaged',
                  'returnId': null,
                  'returnDate': null,
                });
              }
            } catch (e) {
              print('error restoring product items: $e');
            }
          }
        }
      }

      await batch.commit();
    } catch (e) {
      throw e;
    }
  }

  // get recent returns for dashboard
  Future<List<Map<String, dynamic>>> getRecentReturns({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('returns')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // get return history with filters
  Future<List<Map<String, dynamic>>> getReturnHistory({
    String? productId,
    String? returnType,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('returns');

      // apply filters without using complex composite queries that need indices
      final snapshot = await query.orderBy('createdAt', descending: true).get();

      List<Map<String, dynamic>> returns = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final returnData = <String, dynamic>{
          'id': doc.id,
          ...?data as Map<String, dynamic>?,
        };

        // apply filters in memory to avoid firebase indexing requirements
        bool matchesFilters = true;

        // filter by returnType
        if (returnType != null && returnType.isNotEmpty) {
          if (returnData['returnType'] != returnType) {
            matchesFilters = false;
          }
        }

        // filter by status
        if (status != null && status.isNotEmpty) {
          if (returnData['status'] != status) {
            matchesFilters = false;
          }
        }

        // filter by date range
        if (startDate != null || endDate != null) {
          final createdAt = returnData['createdAt'];
          if (createdAt != null) {
            DateTime docDate;
            if (createdAt is Timestamp) {
              docDate = createdAt.toDate();
            } else {
              docDate = DateTime.parse(createdAt.toString());
            }

            if (startDate != null && docDate.isBefore(startDate)) {
              matchesFilters = false;
            }
            if (endDate != null && docDate.isAfter(endDate)) {
              matchesFilters = false;
            }
          }
        }

        // filter by productId if specified
        if (productId != null && productId.isNotEmpty) {
          bool containsProduct = false;
          if (returnData['selectedItems'] != null) {
            final items = returnData['selectedItems'] as List;
            containsProduct = items.any((item) => item['productId'] == productId);
          }
          if (!containsProduct) {
            matchesFilters = false;
          }
        }

        if (matchesFilters) {
          returns.add(returnData);
        }
      }

      return returns;
    } catch (e) {
      return [];
    }
  }

  // get all returns (no filters)
  Future<List<Map<String, dynamic>>> getAllReturns() async {
    try {
      final snapshot = await _firestore
          .collection('returns')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }
}