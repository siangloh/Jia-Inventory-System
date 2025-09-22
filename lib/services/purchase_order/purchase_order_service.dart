// service/purchase_order/purchase_order_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:assignment/models/purchase_order.dart';
import 'package:assignment/models/product_model.dart';

class PurchaseOrderService {
  static const String _collectionName = 'purchaseOrder';
  static const String _productCollectionName = 'products'; // Add product collection
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get collection references
  CollectionReference get _collection => _firestore.collection(_collectionName);
  CollectionReference get _productCollection => _firestore.collection(_productCollectionName);

  // ==================== PURCHASE ORDER METHODS ====================

  // Create a new purchase order
  Future<String> createPurchaseOrder(PurchaseOrder purchaseOrder) async {
    try {
      // Generate PO number if not provided
      String poNumber = purchaseOrder.poNumber.isEmpty
          ? await _generatePONumber()
          : purchaseOrder.poNumber;

      // Create updated purchase order with generated PO number
      final updatedPO = purchaseOrder.copyWith(
        poNumber: poNumber,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add to Firestore
      await _collection.doc(updatedPO.id).set(updatedPO.toFirestore());

      return updatedPO.id;
    } catch (e) {
      throw Exception('Failed to create purchase order: $e');
    }
  }

  // Get purchase order by ID
  Future<PurchaseOrder?> getPurchaseOrder(String id) async {
    try {
      final doc = await _collection.doc(id).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return PurchaseOrder.fromFirestore(data);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to get purchase order: $e');
    }
  }

  // Get all purchase orders
  Future<List<PurchaseOrder>> getAllPurchaseOrders() async {
    try {
      final querySnapshot = await _collection
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) {
        // FIX: Add document ID to data before parsing
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return PurchaseOrder.fromFirestore(data);
      })
          .toList();
    } catch (e) {
      throw Exception('Failed to get purchase orders: $e');
    }
  }

  Stream<PurchaseOrder?> getPurchaseOrderStream(String purchaseOrderId) {
    return _collection  // Use the existing collection reference
        .doc(purchaseOrderId)
        .snapshots()
        .map((docSnapshot) {
      if (docSnapshot.exists && docSnapshot.data() != null) {
        try {
          // Extract the data from the snapshot and add the document ID
          final data = docSnapshot.data() as Map<String, dynamic>;
          data['id'] = docSnapshot.id; // Add the document ID to the data
          return PurchaseOrder.fromFirestore(data);
        } catch (e) {
          print('Error parsing purchase order: $e');
          return null;
        }
      }
      return null;
    });
  }

  // Get purchase orders by status
  Future<List<PurchaseOrder>> getPurchaseOrdersByStatus(POStatus status) async {
    try {
      final querySnapshot = await _collection
          .where('status', isEqualTo: status.toString().split('.').last)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PurchaseOrder.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get purchase orders by status: $e');
    }
  }

  // Update purchase order
  Future<void> updatePurchaseOrder(PurchaseOrder purchaseOrder) async {
    try {
      final updatedPO = purchaseOrder.copyWith(
        updatedAt: DateTime.now(),
      );

      await _collection.doc(purchaseOrder.id).update(updatedPO.toFirestore());
    } catch (e) {
      throw Exception('Failed to update purchase order: $e');
    }
  }

  // Update purchase order status
  Future<void> updatePurchaseOrderStatus(
      String id,
      POStatus newStatus,
      {String? updatedByUserId}
      ) async {
    try {
      final updates = {
        'status': newStatus.toString().split('.').last,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (updatedByUserId != null) {
        updates['updatedByUserId'] = updatedByUserId;
      }

      if (newStatus == POStatus.APPROVED && updatedByUserId != null) {
        updates['approvedByUserId'] = updatedByUserId;
        updates['approvedDate'] = Timestamp.fromDate(DateTime.now());
      }

      await _collection.doc(id).update(updates);
    } catch (e) {
      throw Exception('Failed to update purchase order status: $e');
    }
  }

  // Delete purchase order
  Future<void> deletePurchaseOrder(String id) async {
    try {
      await _collection.doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete purchase order: $e');
    }
  }

  // Stream of purchase orders (real-time updates)
  Stream<List<PurchaseOrder>> getPurchaseOrdersStream() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => PurchaseOrder.fromFirestore(doc.data() as Map<String, dynamic>))
        .toList());
  }

  // ==================== PRODUCT METHODS ====================

  // Create a new product
  Future<String> createProduct(Product product) async {
    try {
      // Generate product ID if not provided or if it's the default pattern
      String productId = product.id;
      if (productId.isEmpty || productId.startsWith('product_')) {
        productId = await _generateProductId();
      }

      // Create product with generated ID
      final productWithId = product.copyWith(id: productId);
      final productData = productWithId.toFirestore();
      productData['createdAt'] = Timestamp.fromDate(DateTime.now());
      productData['updatedAt'] = Timestamp.fromDate(DateTime.now());

      await _productCollection.doc(productId).set(productData);

      return productId;
    } catch (e) {
      throw Exception('Failed to create product: $e');
    }
  }

  // Get product by ID
  Future<Product?> getProduct(String id) async {
    try {
      final doc = await _productCollection.doc(id).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Product.fromFirestore(doc);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to get product: $e');
    }
  }

  // Get all products
  Future<List<Product>> getAllProducts() async {
    try {
      final querySnapshot = await _productCollection
          .orderBy('name')
          .get();

      return querySnapshot.docs
          .map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Product.fromFirestore(doc);
      })
          .toList();
    } catch (e) {
      throw Exception('Failed to get products: $e');
    }
  }

  // Get active products (not discontinued)
  Future<List<Product>> getActiveProducts() async {
    try {
      final querySnapshot = await _productCollection
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      return querySnapshot.docs
          .map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Product.fromFirestore(doc);
      })
          .toList();
    } catch (e) {
      throw Exception('Failed to get active products: $e');
    }
  }

  // Stream of products (real-time updates)
  Stream<List<Product>> getProductsStream() {
    return _productCollection
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return Product.fromFirestore(doc);
    })
        .toList());
  }

  // Update product
  Future<void> updateProduct(Product product) async {
    try {
      final productData = product.toFirestore();
      productData['updatedAt'] = Timestamp.fromDate(DateTime.now());

      await _productCollection.doc(product.id).update(productData);
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  // Delete product (soft delete - mark as inactive)
  Future<void> deleteProduct(String id) async {
    try {
      await _productCollection.doc(id).update({
        'isActive': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  // Search products by name or SKU
  Future<List<Product>> searchProducts(String searchTerm) async {
    try {
      final searchTermLower = searchTerm.toLowerCase();

      // Get all active products and filter locally (Firestore doesn't support case-insensitive search)
      final querySnapshot = await _productCollection
          .where('isActive', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Product.fromFirestore(doc);
      })
          .where((product) =>
      product.name.toLowerCase().contains(searchTermLower) ||
          (product.sku?.toLowerCase().contains(searchTermLower) ?? false) ||
          (product.brand?.toLowerCase().contains(searchTermLower) ?? false))
          .toList();
    } catch (e) {
      throw Exception('Failed to search products: $e');
    }
  }

  // Get products by category
  Future<List<Product>> getProductsByCategory(String category) async {
    try {
      final querySnapshot = await _productCollection
          .where('isActive', isEqualTo: true)
          .where('category', isEqualTo: category)
          .orderBy('name')
          .get();

      return querySnapshot.docs
          .map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Product.fromFirestore(doc);
      })
          .toList();
    } catch (e) {
      throw Exception('Failed to get products by category: $e');
    }
  }

  Future<void> createBulkProducts(List<Product> products) async {
    try {
      final batch = _firestore.batch();
      final now = Timestamp.fromDate(DateTime.now());

      for (final product in products) {
        final productData = product.toFirestore();
        productData['createdAt'] = now;
        productData['updatedAt'] = now;

        batch.set(_productCollection.doc(product.id), productData);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to create bulk products: $e');
    }
  }

  // ==================== PRIVATE METHODS ====================

  // Private method to generate PO number
  Future<String> _generatePONumber() async {
    try {
      final now = DateTime.now();
      final year = now.year;

      // Query for POs created in the current year
      final querySnapshot = await _collection
          .where('createdDate', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(year, 1, 1)))
          .where('createdDate', isLessThan: Timestamp.fromDate(DateTime(year + 1, 1, 1)))
          .orderBy('createdDate', descending: true)
          .limit(1)
          .get();

      int nextNumber = 1;

      if (querySnapshot.docs.isNotEmpty) {
        final lastPO = querySnapshot.docs.first.data() as Map<String, dynamic>;
        final lastPONumber = lastPO['poNumber'] as String?;

        if (lastPONumber != null && lastPONumber.startsWith('PO-$year-')) {
          final numberPart = lastPONumber.split('-').last;
          nextNumber = (int.tryParse(numberPart) ?? 0) + 1;
        }
      }

      return 'PO-$year-${nextNumber.toString().padLeft(3, '0')}';
    } catch (e) {
      // Fallback to timestamp-based number if query fails
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return 'PO-${DateTime.now().year}-${timestamp.toString().substring(timestamp.toString().length - 6)}';
    }
  }

  // Private method to generate sequential product ID
  Future<String> _generateProductId() async {
    try {
      final now = DateTime.now();
      final year = now.year;

      // Query for products created in the current year, ordered by creation date
      final querySnapshot = await _productCollection
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(year, 1, 1)))
          .where('createdAt', isLessThan: Timestamp.fromDate(DateTime(year + 1, 1, 1)))
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      int nextNumber = 1;

      if (querySnapshot.docs.isNotEmpty) {
        // Get the last product's ID and extract the number
        final lastProductId = querySnapshot.docs.first.id;

        if (lastProductId.startsWith('PROD-$year-')) {
          final numberPart = lastProductId.split('-').last;
          nextNumber = (int.tryParse(numberPart) ?? 0) + 1;
        }
      }

      return 'PROD-$year-${nextNumber.toString().padLeft(4, '0')}';
    } catch (e) {
      // Fallback to timestamp-based ID if query fails
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return 'PROD-${DateTime.now().year}-${timestamp.toString().substring(timestamp.toString().length - 8)}';
    }
  }

  // ==================== HELPER METHODS ====================

  // Helper method to create PurchaseOrder from form data
  static PurchaseOrder createFromFormData({
    required POPriority priority,
    required String supplierId,
    required String supplierName,
    required DateTime expectedDeliveryDate,
    required List<POLineItem> lineItems,
    required String createdByUserId,
    required String createdByUserName,
    required POCreatorRole creatorRole,
    required POStatus status,
    String? supplierEmail,
    String? supplierPhone,
    String? notes,
    String? deliveryInstructions,
    double discountAmount = 0.0,
    double shippingCost = 0.0,
    double taxRate = 0.0,
    String deliveryAddress = '',
    String? jobId,
    String? jobNumber,
    String? customerName,
  }) {
    final id = _generateUniqueId();
    final now = DateTime.now();

    // Calculate financial totals
    final subtotal = lineItems.fold(0.0, (sum, item) => sum + item.lineTotal);
    final taxAmount = (subtotal - discountAmount) * (taxRate / 100);
    final totalAmount = subtotal - discountAmount + shippingCost + taxAmount;

    // Find supplier contact info
    final supplierContact = supplierEmail ?? supplierPhone ?? '';

    return PurchaseOrder(
      id: id,
      poNumber: '',
      createdDate: now,
      expectedDeliveryDate: expectedDeliveryDate,
      status: status,
      priority: priority,
      createdByUserId: createdByUserId,
      createdByUserName: createdByUserName,
      creatorRole: creatorRole,
      supplierId: supplierId,
      supplierName: supplierName,
      supplierContact: supplierContact,
      supplierEmail: supplierEmail,
      supplierPhone: supplierPhone,
      subtotal: subtotal,
      taxRate: taxRate,
      taxAmount: taxAmount,
      shippingCost: shippingCost,
      discountAmount: discountAmount,
      totalAmount: totalAmount,
      currency: 'USD',
      deliveryAddress: deliveryAddress.isNotEmpty ? deliveryAddress : 'Workshop Address',
      deliveryInstructions: deliveryInstructions,
      lineItems: lineItems,
      approvalHistory: [],
      jobId: jobId,
      jobNumber: jobNumber,
      customerName: customerName,
      notes: notes,
      attachments: [],
      createdAt: now,
      updatedAt: now,
    );
  }

  // Generate unique ID
  static String _generateUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (1000 + (DateTime.now().microsecond % 9000)).toString();
  }
}

