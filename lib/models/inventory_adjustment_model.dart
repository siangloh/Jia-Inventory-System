class InventoryAdjustmentModel {
  final int? id;
  final int partId;
  final int? batchId;              // Foreign key to inventory_batches (nullable for legacy data)
  final int userId;
  final String adjustmentType;
  final int quantity;
  final String? reasonNotes;
  final String? photoUrl;
  final String? supplierName;
  final String? purchaseOrderNumber;
  final String? workOrderNumber;
  final DateTime? createdAt;

  InventoryAdjustmentModel({
    this.id,
    required this.partId,
    this.batchId,
    required this.userId,
    required this.adjustmentType,
    required this.quantity,
    this.reasonNotes,
    this.photoUrl,
    this.supplierName,
    this.purchaseOrderNumber,
    this.workOrderNumber,
    this.createdAt,
  });

  factory InventoryAdjustmentModel.fromJson(Map<String, dynamic> data) => InventoryAdjustmentModel(
        id: data['id'],
        partId: data['part_id'],
        batchId: data['batch_id'],
        userId: data['user_id'],
        adjustmentType: data['adjustment_type'],
        quantity: data['quantity'],
        reasonNotes: data['reason_notes'],
        photoUrl: data['photo_url'],
        supplierName: data['supplier_name'],
        purchaseOrderNumber: data['purchase_order_number'],
        workOrderNumber: data['work_order_number'],
        createdAt: DateTime.tryParse(data['created_at'].toString()),
      );

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'part_id': partId,
      'user_id': userId,
      'adjustment_type': adjustmentType,
      'quantity': quantity,
    };
    
    // Only add non-null values
    if (batchId != null) map['batch_id'] = batchId;
    if (reasonNotes != null) map['reason_notes'] = reasonNotes;
    if (photoUrl != null) map['photo_url'] = photoUrl;
    if (supplierName != null) map['supplier_name'] = supplierName;
    if (purchaseOrderNumber != null) map['purchase_order_number'] = purchaseOrderNumber;
    if (workOrderNumber != null) map['work_order_number'] = workOrderNumber;
    
    // Don't include id or created_at - let SQLite handle these
    // id will be auto-generated, created_at will use DEFAULT CURRENT_TIMESTAMP
    
    return map;
  }

  // Helper method to check if this is a positive adjustment (received, returned)
  bool get isPositiveAdjustment => 
      adjustmentType == 'RECEIVED' || adjustmentType == 'RETURNED';
  
  // Helper method to check if this is a negative adjustment (damaged, lost, expired)
  bool get isNegativeAdjustment => 
      adjustmentType == 'DAMAGED' || adjustmentType == 'LOST' || adjustmentType == 'EXPIRED';
  
  // Helper method to get display quantity with sign
  String get displayQuantity => isPositiveAdjustment ? '+$quantity' : '-$quantity';
  
  // Helper method to get adjustment type display name
  String get adjustmentTypeDisplay {
    switch (adjustmentType) {
      case 'RECEIVED':
        return 'Received';
      case 'DAMAGED':
        return 'Damaged';
      case 'LOST':
        return 'Lost';
      case 'EXPIRED':
        return 'Expired';
      case 'RETURNED':
        return 'Returned';
      default:
        return adjustmentType;
    }
  }
  
  // Helper method to check if photo is required for this adjustment type
  bool get requiresPhoto => adjustmentType == 'DAMAGED' || adjustmentType == 'LOST' || adjustmentType == 'EXPIRED';
}
