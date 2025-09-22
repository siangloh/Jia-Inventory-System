class InventoryBatchModel {
  final int? id;
  final int partId;                    // Foreign key to spare_parts
  final int quantityOnHand;            // Current stock for this specific batch
  final double costPrice;              // Cost price per unit for this batch
  final DateTime receivedDate;         // When this batch was received
  final String? supplierName;          // Supplier for this batch
  final String? purchaseOrderNumber;   // PO number for this batch
  final DateTime? createdAt;           // When this batch record was created

  InventoryBatchModel({
    this.id,
    required this.partId,
    required this.quantityOnHand,
    required this.costPrice,
    required this.receivedDate,
    this.supplierName,
    this.purchaseOrderNumber,
    this.createdAt,
  });

  factory InventoryBatchModel.fromJson(Map<String, dynamic> data) => InventoryBatchModel(
        id: data['id'],
        partId: data['part_id'],
        quantityOnHand: data['quantity_on_hand'],
        costPrice: data['cost_price']?.toDouble() ?? 0.0,
        receivedDate: DateTime.parse(data['received_date']),
        supplierName: data['supplier_name'],
        purchaseOrderNumber: data['purchase_order_number'],
        createdAt: data['created_at'] != null 
            ? DateTime.parse(data['created_at']) 
            : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'part_id': partId,
        'quantity_on_hand': quantityOnHand,
        'cost_price': costPrice,
        'received_date': receivedDate.toIso8601String(),
        'supplier_name': supplierName,
        'purchase_order_number': purchaseOrderNumber,
        'created_at': createdAt?.toIso8601String(),
      };

  // Helper method to get display name for batch selection
  String get displayName {
    final batchId = id?.toString().padLeft(3, '0') ?? '???';
    final date = receivedDate.toString().substring(0, 10);
    final supplier = supplierName ?? 'Unknown Supplier';
    return 'B-$batchId ($date) - $supplier';
  }

  // Helper method to get short display name
  String get shortDisplayName {
    final batchId = id?.toString().padLeft(3, '0') ?? '???';
    final date = receivedDate.toString().substring(0, 10);
    return 'B-$batchId ($date)';
  }

  // Helper method to check if batch has stock
  bool get hasStock => quantityOnHand > 0;

  // Helper method to get stock status
  String get stockStatus {
    if (quantityOnHand <= 0) return 'Out of Stock';
    if (quantityOnHand < 10) return 'Low Stock';
    return 'In Stock';
  }

  // Helper method to get total value of batch
  double get totalValue => quantityOnHand * costPrice;
}
