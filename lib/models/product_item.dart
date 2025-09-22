import 'package:cloud_firestore/cloud_firestore.dart';

class ProductItem {
  final String itemId;
  final String productId;
  final String purchaseOrderId;
  final String status;
  final String? location;

  ProductItem({
    required this.itemId,
    required this.productId,
    required this.purchaseOrderId,
    required this.status,
    this.location,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'purchaseOrderId': purchaseOrderId,
      'status': status,
      'location': location,
    };
  }

  factory ProductItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductItem(
      itemId: doc.id,
      productId: data['productId'],
      purchaseOrderId: data['purchaseOrderId'],
      status: data['status'],
      location: data['location'],
    );
  }
}

class ProductItemStatus {
  static const String pending = 'pending';
  static const String issued = 'issued';
  static const String stored = 'stored';
  static const String received = 'received';
  static const String sold = 'sold';
  static const String damaged = 'damaged';
  static const String inTransit = 'in_transit';
  static const String returned = 'returned';
}

enum ProductItemsStatus {
  pending,
  issued,
  stored,
  received,
  sold,
  damaged,
  inTransit,
  returned,
}

class ProductItemService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generate the starting ID for this batch
  Future<int> _getNextStartingNumber() async {
    final year = DateTime.now().year;
    final prefix = 'ITEM-$year-';

    // Get the latest item ID for this year
    final snapshot = await _firestore
        .collection('productItems')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: prefix)
        .where(FieldPath.documentId, isLessThan: '${prefix}ZZZ')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(1)
        .get();

    int nextNumber = 1;
    if (snapshot.docs.isNotEmpty) {
      final lastId = snapshot.docs.first.id;
      final lastNumber = int.tryParse(lastId.split('-').last) ?? 0;
      nextNumber = lastNumber + 1;
    }

    return nextNumber;
  }

  // Generate item ID with sequential number
  String _generateItemId(int sequenceNumber) {
    final year = DateTime.now().year;
    return 'ITEM-$year-${sequenceNumber.toString().padLeft(5, '0')}';
  }

  // Alternative: Generate item ID based on product ID format
  Future<String> _generateProductBasedItemId(String productId, int itemSequence) async {
    return '$productId-ITEM-${itemSequence.toString().padLeft(3, '0')}';
  }

  // Create multiple items for a product from a purchase order
  Future<List<String>> createProductItems(
      String productId,
      String purchaseOrderId,
      int quantity, {
        bool useProductBasedId = false, // Choose ID format
      }) async {
    final batch = _firestore.batch();
    final itemIds = <String>[];

    if (useProductBasedId) {
      // Product-based ID format: PROD-2025-001-ITEM-001, PROD-2025-001-ITEM-002, etc.
      for (int i = 0; i < quantity; i++) {
        final itemId = await _generateProductBasedItemId(productId, i + 1);
        itemIds.add(itemId);

        final item = ProductItem(
          itemId: itemId,
          productId: productId,
          purchaseOrderId: purchaseOrderId,
          status: ProductItemStatus.pending,
        );

        final docRef = _firestore.collection('productItems').doc(itemId);
        batch.set(docRef, item.toFirestore());
      }
    } else {
      // Sequential ID format: Get starting number once, then increment
      int startingNumber = await _getNextStartingNumber();

      for (int i = 0; i < quantity; i++) {
        final itemId = _generateItemId(startingNumber + i);
        itemIds.add(itemId);

        final item = ProductItem(
          itemId: itemId,
          productId: productId,
          purchaseOrderId: purchaseOrderId,
          status: ProductItemStatus.pending,
        );

        final docRef = _firestore.collection('productItems').doc(itemId);
        batch.set(docRef, item.toFirestore());
      }
    }

    await batch.commit();
    return itemIds;
  }

  // Get all items for a product
  Future<List<ProductItem>> getItemsForProduct(String productId) async {
    final snapshot = await _firestore
        .collection('productItems')
        .where('productId', isEqualTo: productId)
        .get();

    return snapshot.docs.map((doc) => ProductItem.fromFirestore(doc)).toList();
  }

  // Get all items from a specific purchase order
  Future<List<ProductItem>> getItemsByPurchaseOrder(String purchaseOrderId) async {
    final snapshot = await _firestore
        .collection('productItems')
        .where('purchaseOrderId', isEqualTo: purchaseOrderId)
        .get();

    return snapshot.docs.map((doc) => ProductItem.fromFirestore(doc)).toList();
  }

  // Update item status
  Future<void> updateItemStatus(String itemId, String status) async {
    await _firestore.collection('productItems').doc(itemId).update({
      'status': status,
    });
  }

  // Get available items count for a product
  Future<int> getAvailableItemsCount(String productId) async {
    final snapshot = await _firestore
        .collection('productItems')
        .where('productId', isEqualTo: productId)
        .where('status', isEqualTo: ProductItemStatus.pending)
        .get();

    return snapshot.docs.length;
  }

  // Get item by ID
  Future<ProductItem?> getItemById(String itemId) async {
    final doc = await _firestore.collection('productItems').doc(itemId).get();

    if (doc.exists) {
      return ProductItem.fromFirestore(doc);
    }
    return null;
  }
}