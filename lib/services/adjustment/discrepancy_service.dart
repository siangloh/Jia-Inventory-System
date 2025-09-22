import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'adjustment_photo_service.dart';
import 'package:flutter/material.dart';

class DiscrepancyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, String> _productNameCache = {};
  final Map<String, String> _brandNameCache = {};
  final Map<String, Map<String, String>> _categoryCache = {};
  
  Map<String, Set<String>> _discrepancyReportsCache = {};
  bool _cacheInitialized = false;

  Future<void> _initializeDiscrepancyCache() async {
    if (_cacheInitialized) return;
    
    try {
      final snapshot = await _firestore.collection('discrepancy_reports').get();
      _discrepancyReportsCache.clear();
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        
        if (data['items'] != null) {
          final items = List<dynamic>.from(data['items']);
          for (final item in items) {
            final poId = item['poId']?.toString() ?? '';
            final itemId = item['itemId']?.toString() ?? '';
            final productId = item['productId']?.toString() ?? '';
            
            if (poId.isNotEmpty && itemId.isNotEmpty) {
              final key = '${poId}_${itemId}';
              _discrepancyReportsCache.putIfAbsent(poId, () => <String>{}).add(key);
            }
            
            if (poId.isNotEmpty && productId.isNotEmpty && itemId.isEmpty) {
              final key = '${poId}_${productId}';
              _discrepancyReportsCache.putIfAbsent(poId, () => <String>{}).add(key);
            }
          }
        } else {
          final poId = data['poId']?.toString() ?? '';
          final lineItemId = data['lineItemId']?.toString() ?? '';
          final productId = data['productId']?.toString() ?? '';
          
          if (poId.isNotEmpty && lineItemId.isNotEmpty) {
            final key = '${poId}_${lineItemId}';
            _discrepancyReportsCache.putIfAbsent(poId, () => <String>{}).add(key);
          }
          
          if (poId.isNotEmpty && productId.isNotEmpty && lineItemId.isEmpty) {
            final key = '${poId}_${productId}';
            _discrepancyReportsCache.putIfAbsent(poId, () => <String>{}).add(key);
          }
        }
      }
      
      _cacheInitialized = true;
    } catch (e) {
      print('Error initializing discrepancy cache: $e');
      _discrepancyReportsCache.clear();
    }
  }

  bool _isItemAlreadyReported(String poId, String itemId, String productId) {
    if (!_cacheInitialized) return false;
    
    final poReports = _discrepancyReportsCache[poId];
    if (poReports == null || poReports.isEmpty) return false;
    
    if (itemId.isNotEmpty) {
      final itemKey = '${poId}_${itemId}';
      if (poReports.contains(itemKey)) {
        return true;
      }
    }
    
    if (productId.isNotEmpty) {
      final productKey = '${poId}_${productId}';
      if (poReports.contains(productKey)) {
        return true;
      }
    }
    
    return false;
  }

  Future<Map<String, dynamic>> _resolveAllReferences(Map<String, dynamic> lineItem, Map<String, dynamic> productData) async {
    try {
      final futures = await Future.wait([
        _resolveProductNameReference(productData['name']?.toString()),
        _resolveBrandReference(productData['brand']?.toString()),
        _resolveCategoryReference(productData['category']?.toString()),
      ]);

      return {
        'productId': lineItem['productId'] ?? '',
        'itemId': lineItem['id'] ?? lineItem['itemId'] ?? '',
        'poId': '',
        'poNumber': '',
        'productName': futures[0] as String,
        'displayName': futures[0] as String,
        'brandName': futures[1] as String,
        'brand': futures[1] as String,
        'categoryName': (futures[2] as Map<String, String>)['name']!,
        'categoryIcon': (futures[2] as Map<String, String>)['icon']!,
        'sku': _getDisplayValue(productData['sku']),
        'partNumber': _getDisplayValue(lineItem['partNumber'] ?? productData['partNumber']),
        'description': _getDisplayValue(productData['description']),
        'price': (productData['price'] ?? lineItem['unitPrice'] ?? 0).toDouble(),
        'unitPrice': (lineItem['unitPrice'] ?? productData['price'] ?? 0).toDouble(),
        'weight': _getDisplayValue(productData['weight']?.toString()),
        'dimensions': _formatDimensions(productData['dimensions']),
        'storageType': _getDisplayValue(productData['storageType']),
        'movementFrequency': _getDisplayValue(productData['movementFrequency']),
        'requiresClimateControl': productData['requiresClimateControl'] ?? false,
        'isHazardousMaterial': productData['isHazardousMaterial'] ?? false,
        'quantityOrdered': lineItem['quantityOrdered'] ?? 0,
        'quantityReceived': lineItem['quantityReceived'] ?? 0,
        'quantityDamaged': lineItem['quantityDamaged'] ?? 0,
        'quantityPlaced': lineItem['quantityPlaced'] ?? 0,
        'lineTotal': (lineItem['lineTotal'] ?? 0).toDouble(),
        'status': lineItem['status'] ?? 'PENDING',
        'notes': _getDisplayValue(lineItem['notes']),
        'isNewProduct': lineItem['isNewProduct'] ?? false,
      };
    } catch (e) {
      return _createFallbackData(lineItem);
    }
  }

  String _getDisplayValue(dynamic value, {String defaultValue = 'N/A'}) {
    if (value == null) return defaultValue;
    String stringValue = value.toString().trim();
    if (stringValue.isEmpty || stringValue == 'null') return defaultValue;
    return stringValue;
  }

  String _formatDimensions(dynamic dimensions) {
    if (dimensions == null) return 'N/A';
    
    try {
      final dims = dimensions as Map<String, dynamic>;
      List<String> parts = [];
      
      final length = dims['length'];
      final width = dims['width'];
      final height = dims['height'];
      
      if (length != null && length > 0) parts.add('L:${length}m');
      if (width != null && width > 0) parts.add('W:${width}m');
      if (height != null && height > 0) parts.add('H:${height}m');
      
      return parts.isEmpty ? 'N/A' : parts.join(' × ');
    } catch (e) {
      return 'N/A';
    }
  }

  Future<String> _resolveProductNameReference(String? productNameRef) async {
    if (productNameRef == null || productNameRef.isEmpty) return 'N/A';

    if (_productNameCache.containsKey(productNameRef)) {
      return _productNameCache[productNameRef]!;
    }

    try {
      final productNameDoc = await _firestore
          .collection('productNames')
          .doc(productNameRef)
          .get();
      
      String resolvedName = 'N/A';
      if (productNameDoc.exists) {
        final data = productNameDoc.data()!;
        resolvedName = data['productName']?.toString() ?? 
                     data['name']?.toString() ?? 
                     productNameRef;
      } else {
        resolvedName = productNameRef;
      }
      
      _productNameCache[productNameRef] = resolvedName;
      return resolvedName;
    } catch (e) {
      return productNameRef;
    }
  }

  Future<String> _resolveBrandReference(String? brandRef) async {
    if (brandRef == null || brandRef.isEmpty) return 'N/A';

    if (_brandNameCache.containsKey(brandRef)) {
      return _brandNameCache[brandRef]!;
    }

    try {
      final brandDoc = await _firestore
          .collection('productBrands')
          .doc(brandRef)
          .get();
      
      String resolvedBrand = 'N/A';
      if (brandDoc.exists) {
        final data = brandDoc.data()!;
        resolvedBrand = data['brandName']?.toString() ?? 
                      data['name']?.toString() ?? 
                      brandRef;
      } else {
        resolvedBrand = brandRef;
      }
      
      _brandNameCache[brandRef] = resolvedBrand;
      return resolvedBrand;
    } catch (e) {
      return brandRef;
    }
  }

  Future<Map<String, String>> _resolveCategoryReference(String? categoryRef) async {
    if (categoryRef == null || categoryRef.isEmpty) {
      return {'name': 'N/A', 'icon': 'category'};
    }

    if (_categoryCache.containsKey(categoryRef)) {
      return _categoryCache[categoryRef]!;
    }

    try {
      final categoryDoc = await _firestore
          .collection('categories')
          .doc(categoryRef)
          .get();
      
      Map<String, String> resolvedCategory;
      if (categoryDoc.exists) {
        final data = categoryDoc.data()!;
        resolvedCategory = {
          'name': data['name']?.toString() ?? categoryRef,
          'icon': data['iconName']?.toString() ?? 'category',
        };
      } else {
        resolvedCategory = {
          'name': categoryRef,
          'icon': 'category',
        };
      }
      
      _categoryCache[categoryRef] = resolvedCategory;
      return resolvedCategory;
    } catch (e) {
      return {'name': categoryRef, 'icon': 'category'};
    }
  }

  Map<String, dynamic> _createFallbackData(Map<String, dynamic> lineItem) {
    return {
      'productId': lineItem['productId'] ?? '',
      'itemId': lineItem['id'] ?? lineItem['itemId'] ?? '',
      'poId': '',
      'poNumber': '',
      'productName': lineItem['productName'] ?? 'Unknown Product',
      'displayName': lineItem['productName'] ?? 'Unknown Product',
      'brandName': lineItem['brand'] ?? 'N/A',
      'brand': lineItem['brand'] ?? 'N/A',
      'categoryName': 'N/A',
      'categoryIcon': 'category',
      'sku': _getDisplayValue(lineItem['productSKU']),
      'partNumber': _getDisplayValue(lineItem['partNumber']),
      'description': _getDisplayValue(lineItem['productDescription']),
      'price': (lineItem['unitPrice'] ?? 0).toDouble(),
      'unitPrice': (lineItem['unitPrice'] ?? 0).toDouble(),
      'weight': 'N/A',
      'dimensions': 'N/A',
      'storageType': 'N/A',
      'movementFrequency': 'N/A',
      'requiresClimateControl': false,
      'isHazardousMaterial': false,
      'quantityOrdered': lineItem['quantityOrdered'] ?? 0,
      'quantityReceived': lineItem['quantityReceived'] ?? 0,
      'quantityDamaged': lineItem['quantityDamaged'] ?? 0,
      'quantityPlaced': lineItem['quantityPlaced'] ?? 0,
      'lineTotal': (lineItem['lineTotal'] ?? 0).toDouble(),
      'status': lineItem['status'] ?? 'PENDING',
      'notes': _getDisplayValue(lineItem['notes']),
      'isNewProduct': lineItem['isNewProduct'] ?? false,
    };
  }

  Future<List<Map<String, dynamic>>> getPurchaseOrdersWithReceivedItems() async {
    try {
      await _initializeDiscrepancyCache();
      
      final orders = await _firestore.collection('purchaseOrder').get();
      List<Map<String, dynamic>> eligibleOrders = [];

      for (final orderDoc in orders.docs) {
        final orderData = orderDoc.data();
        orderData['id'] = orderDoc.id;
        
        String status = orderData['status'] ?? '';
        bool shouldProcessPO = ['COMPLETED', 'PARTIALLY_RECEIVED', 'READY'].contains(status);
        
        if (!shouldProcessPO) {
          continue;
        }

        final lineItems = List<dynamic>.from(orderData['lineItems'] ?? []);
        List<dynamic> eligibleLineItems = [];

        for (int i = 0; i < lineItems.length; i++) {
          final lineItem = lineItems[i];
          
          bool shouldIncludeItem = false;
          int availableQuantity = 0;
          
          if (status == 'READY') {
            availableQuantity = lineItem['quantityOrdered'] ?? 0;
            shouldIncludeItem = availableQuantity > 0;
          } else {
            int quantityReceived = lineItem['quantityReceived'] ?? 0;
            int quantityDamaged = lineItem['quantityDamaged'] ?? 0;
            availableQuantity = quantityReceived - quantityDamaged;
            shouldIncludeItem = availableQuantity > 0;
          }
          
          if (shouldIncludeItem) {
            final itemId = lineItem['id'] ?? lineItem['itemId'] ?? '';
            final productId = lineItem['productId'] ?? '';
            final poId = orderDoc.id;
            
            if (_isItemAlreadyReported(poId, itemId, productId)) {
              continue;
            }
            
            try {
              final productDoc = await _firestore
                  .collection('products')
                  .doc(lineItem['productId'])
                  .get();
              
              Map<String, dynamic> enhancedItem;
              if (productDoc.exists) {
                final productData = productDoc.data()!;
                enhancedItem = await _resolveAllReferences(lineItem, productData);
              } else {
                enhancedItem = _createFallbackData(lineItem);
              }
              
              enhancedItem['poId'] = orderDoc.id;
              enhancedItem['poNumber'] = orderData['poNumber'] ?? 'Unknown';
              enhancedItem['supplierName'] = orderData['supplierName'] ?? 'Unknown Supplier';
              enhancedItem['availableQuantity'] = availableQuantity;
              
              eligibleLineItems.add(enhancedItem);
            } catch (e) {
              final fallbackItem = _createFallbackData(lineItem);
              fallbackItem['poId'] = orderDoc.id;
              fallbackItem['poNumber'] = orderData['poNumber'] ?? 'Unknown';
              fallbackItem['supplierName'] = orderData['supplierName'] ?? 'Unknown Supplier';
              fallbackItem['availableQuantity'] = availableQuantity;
              eligibleLineItems.add(fallbackItem);
            }
          }
        }

        if (eligibleLineItems.isNotEmpty) {
          orderData['lineItems'] = eligibleLineItems;
          orderData['itemCount'] = eligibleLineItems.length;
          orderData['totalAvailableItems'] = eligibleLineItems
              .fold<int>(0, (sum, item) => sum + ((item['availableQuantity'] ?? 0) as int));
          eligibleOrders.add(orderData);
        }
      }

      eligibleOrders.sort((a, b) {
        final aDate = a['createdDate'] as Timestamp?;
        final bDate = b['createdDate'] as Timestamp?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      return eligibleOrders;
    } catch (e) {
      return [];
    }
  }
  
  Future<List<Map<String, dynamic>>> searchItemsRealtime(String searchQuery) async {
    try {
      if (searchQuery.trim().isEmpty) {
        return await getPurchaseOrdersWithReceivedItems();
      }

      String query = searchQuery.toLowerCase().trim();
      final allPOs = await getPurchaseOrdersWithReceivedItems();
      List<Map<String, dynamic>> matchingResults = [];
      
      for (final po in allPOs) {
        final lineItems = List<dynamic>.from(po['lineItems'] ?? []);
        List<dynamic> matchingLineItems = [];
        
        bool poMatches = (po['poNumber'] ?? '').toLowerCase().contains(query) ||
                         (po['supplierName'] ?? '').toLowerCase().contains(query);
        
        for (final item in lineItems) {
          if ((item['availableQuantity'] ?? 0) > 0) {
            String productName = (item['productName'] ?? '').toLowerCase();
            String partNumber = (item['partNumber'] ?? '').toLowerCase();
            String brand = (item['brandName'] ?? '').toLowerCase();
            String category = (item['categoryName'] ?? '').toLowerCase();
            
            if (productName.contains(query) || 
                partNumber.contains(query) || 
                brand.contains(query) || 
                category.contains(query) ||
                poMatches) {
              matchingLineItems.add(item);
            }
          }
        }
        
        if (matchingLineItems.isNotEmpty || poMatches) {
          po['lineItems'] = matchingLineItems.isNotEmpty ? matchingLineItems : lineItems;
          matchingResults.add(po);
        }
      }
      
      return matchingResults;
    } catch (e) {
      return [];
    }
  }
  
  Future<String> createMultiItemDiscrepancyReport({
    required List<Map<String, dynamic>> items,
    required String discrepancyType,
    required String description,
    required List<File> localPhotoFiles,
    required String staffId,
    required String staffName,
  }) async {
    try {
      List<String> photoFileNames = [];
      
      for (int i = 0; i < localPhotoFiles.length; i++) {
        final photoFile = localPhotoFiles[i];
        
        final fileName = await AdjustmentPhotoService.uploadPhoto(
          imageFile: photoFile,
          workflowType: 'discrepancy',
          workflowId: 'DISC_${DateTime.now().millisecondsSinceEpoch}',
        );
        
        if (fileName != null) {
          photoFileNames.add(fileName);
        }
      }
      
      double totalCostImpact = 0.0;
      for (final item in items) {
        double unitPrice = (item['unitPrice'] ?? 0.0).toDouble();
        int quantity = (item['quantity'] ?? 0);
        totalCostImpact += unitPrice * quantity;
      }

      final batch = _firestore.batch();

      final reportData = {
        'items': items.map((item) => {
          'poId': item['poId'] ?? '',
          'poNumber': item['poNumber'] ?? '',
          'itemId': item['itemId'] ?? '',
          'productId': item['productId'] ?? '',
          'productName': item['productName'] ?? '',
          'partNumber': item['partNumber'] ?? '',
          'brand': item['brandName'] ?? '',
          'quantity': item['quantity'] ?? 1,
          'unitPrice': item['unitPrice'] ?? 0.0,
        }).toList(),
        'discrepancyType': discrepancyType,
        'description': description,
        'photos': photoFileNames,
        'reportedBy': staffId,
        'reportedByName': staffName,
        'reportedAt': Timestamp.fromDate(DateTime.now()),
        'status': 'submitted',
        'costImpact': totalCostImpact,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      final reportRef = _firestore.collection('discrepancy_reports').doc();
      batch.set(reportRef, reportData);

      for (final item in items) {
        final poId = item['poId']?.toString();
        final itemId = item['itemId']?.toString();
        final quantity = (item['quantity'] ?? 1) as int;
        
        if (poId != null && poId.isNotEmpty && itemId != null && itemId.isNotEmpty) {
          try {
            final poDoc = await _firestore.collection('purchaseOrder').doc(poId).get();
            
            if (poDoc.exists) {
              final poData = poDoc.data()!;
              final lineItems = List<dynamic>.from(poData['lineItems'] ?? []);

        for (int i = 0; i < lineItems.length; i++) {
          final lineItem = lineItems[i];
                if (lineItem['id'] == itemId) {
                  int currentDamaged = (lineItem['quantityDamaged'] ?? 0) as int;
                  lineItems[i] = {
                    ...lineItem,
                    'quantityDamaged': currentDamaged + quantity,
                  };
                  break;
                }
              }
              
              batch.update(
                _firestore.collection('purchaseOrder').doc(poId),
                {'lineItems': lineItems, 'updatedAt': FieldValue.serverTimestamp()}
              );
              }
            } catch (e) {
            // continue with other items even if one fails
          }
        }
      }

      await batch.commit();
      
      _cacheInitialized = false;
      _discrepancyReportsCache.clear();
      
      return reportRef.id;
    } catch (e) {
      throw Exception('Failed to create discrepancy report: $e');
    }
  }
  
  static List<Map<String, dynamic>> getDiscrepancyTypes() {
    return [
      {
        'type': 'manufacturingDefect',
        'label': 'Manufacturing Defect',
        'icon': Icons.build,
        'color': Colors.orange,
        'description': 'Product is faulty due to manufacturing process issues',
      },
      {
        'type': 'physicalDamage',
        'label': 'Physical Damage',
        'icon': Icons.broken_image,
        'color': Colors.red,
        'description': 'Items damaged during handling, shipping, or storage',
      },
      {
        'type': 'qualityIssue',
        'label': 'Quality Issue',
        'icon': Icons.warning,
        'color': Colors.amber,
        'description': 'Items that function but don\'t meet expected quality standards',
      },
    ];
  }

  static String getDiscrepancyTypeLabel(String type) {
    switch (type) {
      case 'manufacturingDefect':
        return 'Manufacturing Defect';
      case 'physicalDamage':
        return 'Physical Damage';
      case 'qualityIssue':
        return 'Quality Issue';
      default:
        return type;
    }
  }
  
  Future<List<Map<String, dynamic>>> getDiscrepancyReports({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('discrepancy_reports');

      if (startDate != null) {
        query = query.where('reportedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('reportedAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.orderBy('reportedAt', descending: true).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> getDiscrepancyReportsStream() {
    return _firestore
        .collection('discrepancy_reports')
        .orderBy('reportedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    });
  }
}