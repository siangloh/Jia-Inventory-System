// models/return_stock.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ReturnStock {
  final String returnId;
  final String returnNumber; 
  final String returnType; 
  final String status; 
  final String reason;
  final int quantity; 
  final String? discrepancyReportId; 
  final String? supplierId; 
  final String? purchaseOrderId; 
  final String returnMethod; 
  final String? returnAddress;
  final String? trackingNumber;
  final List<String> photos;
  final String? notes;
  final String createdByUserId;
  final String createdByUserName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? resolvedByUserId;
  final DateTime? resolvedAt;
  final String? resolution; 
  final int totalItems; 
  final int totalQuantity; 
  final List<ReturnLineItem> items; 

  ReturnStock({
    required this.returnId,
    required this.returnNumber,
    required this.returnType,
    required this.status,
    required this.reason,
    required this.quantity,
    this.discrepancyReportId,
    this.supplierId,
    this.purchaseOrderId,
    required this.returnMethod,
    this.returnAddress,
    this.trackingNumber,
    required this.photos,
    this.notes,
    required this.createdByUserId,
    required this.createdByUserName,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedByUserId,
    this.resolvedAt,
    this.resolution,
    required this.totalItems,
    required this.totalQuantity,
    required this.items,
  });

  // Convert to Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      'returnId': returnId,
      'returnNumber': returnNumber,
      'returnType': returnType,
      'status': status,
      'reason': reason,
      'quantity': quantity,
      'discrepancyReportId': discrepancyReportId,
      'supplierId': supplierId,
      'purchaseOrderId': purchaseOrderId,
      'returnMethod': returnMethod,
      'returnAddress': returnAddress,
      'trackingNumber': trackingNumber,
      'photos': photos,
      'notes': notes,
      'createdByUserId': createdByUserId,
      'createdByUserName': createdByUserName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'resolvedByUserId': resolvedByUserId,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'resolution': resolution,
      'totalItems': totalItems,
      'totalQuantity': totalQuantity,
      'items': items.map((item) => item.toFirestore()).toList(),
    };
  }

  // Create from Firestore Map
  factory ReturnStock.fromFirestore(Map<String, dynamic> data) {
    return ReturnStock(
      returnId: data['returnId'] ?? '',
      returnNumber: data['returnNumber'] ?? '',
      returnType: data['returnType'] ?? 'SUPPLIER_RETURN',
      status: data['status'] ?? 'PENDING',
      reason: data['reason'] ?? '',
      quantity: data['quantity'] ?? 0,
      discrepancyReportId: data['discrepancyReportId'],
      supplierId: data['supplierId'],
      purchaseOrderId: data['purchaseOrderId'],
      returnMethod: data['returnMethod'] ?? 'SHIP',
      returnAddress: data['returnAddress'],
      trackingNumber: data['trackingNumber'],
      photos: List<String>.from(data['photos'] ?? []),
      notes: data['notes'],
      createdByUserId: data['createdByUserId'] ?? '',
      createdByUserName: data['createdByUserName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      resolvedByUserId: data['resolvedByUserId'],
      resolvedAt: data['resolvedAt'] != null
          ? (data['resolvedAt'] as Timestamp).toDate()
          : null,
      resolution: data['resolution'],
      totalItems: data['totalItems'] ?? 0,
      totalQuantity: data['totalQuantity'] ?? 0,
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => ReturnLineItem.fromFirestore(item))
              .toList() ??
          [],
    );
  }

  // Copy with method for updates
  ReturnStock copyWith({
    String? returnId,
    String? returnNumber,
    String? returnType,
    String? status,
    String? reason,
    int? quantity,
    String? discrepancyReportId,
    String? supplierId,
    String? purchaseOrderId,
    String? returnMethod,
    String? returnAddress,
    String? trackingNumber,
    List<String>? photos,
    String? notes,
    String? createdByUserId,
    String? createdByUserName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? resolvedByUserId,
    DateTime? resolvedAt,
    String? resolution,
    int? totalItems,
    int? totalQuantity,
    List<ReturnLineItem>? items,
  }) {
    return ReturnStock(
      returnId: returnId ?? this.returnId,
      returnNumber: returnNumber ?? this.returnNumber,
      returnType: returnType ?? this.returnType,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      quantity: quantity ?? this.quantity,
      discrepancyReportId: discrepancyReportId ?? this.discrepancyReportId,
      supplierId: supplierId ?? this.supplierId,
      purchaseOrderId: purchaseOrderId ?? this.purchaseOrderId,
      returnMethod: returnMethod ?? this.returnMethod,
      returnAddress: returnAddress ?? this.returnAddress,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      photos: photos ?? this.photos,
      notes: notes ?? this.notes,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByUserName: createdByUserName ?? this.createdByUserName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedByUserId: resolvedByUserId ?? this.resolvedByUserId,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolution: resolution ?? this.resolution,
      totalItems: totalItems ?? this.totalItems,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      items: items ?? this.items,
    );
  }
}

// Return Line Item Model
class ReturnLineItem {
  final String productId;
  final String productName;
  final String? partNumber;
  final String? sku;
  final int returnQuantity;
  final String reason;
  final String condition;
  final String? notes;

  ReturnLineItem({
    required this.productId,
    required this.productName,
    this.partNumber,
    this.sku,
    required this.returnQuantity,
    required this.reason,
    required this.condition,
    this.notes,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'productName': productName,
      'partNumber': partNumber,
      'sku': sku,
      'returnQuantity': returnQuantity,
      'reason': reason,
      'condition': condition,
      'notes': notes,
    };
  }

  factory ReturnLineItem.fromFirestore(Map<String, dynamic> data) {
    return ReturnLineItem(
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      partNumber: data['partNumber'],
      sku: data['sku'],
      returnQuantity: data['returnQuantity'] ?? 0,
      reason: data['reason'] ?? '',
      condition: data['condition'] ?? ReturnCondition.DAMAGED_UNUSABLE,
      notes: data['notes'],
    );
  }
}

// Return Type Constants
class ReturnType {
  static const String SUPPLIER_RETURN = 'SUPPLIER_RETURN';
  static const String INTERNAL_RETURN = 'INTERNAL_RETURN';
}

// Return Status Constants
class ReturnStatus {
  static const String PENDING = 'PENDING';
  static const String COMPLETED = 'COMPLETED';
}

// Return Method Constants
class ReturnMethod {
  static const String PICKUP = 'PICKUP';
  static const String SHIP = 'SHIP';
  static const String DROP_OFF = 'DROP_OFF';
  static const String DIRECT_RESTOCK = 'DIRECT_RESTOCK';
}

// Return Condition Constants
class ReturnCondition {
  static const String DAMAGED_UNUSABLE = 'Damaged - Unusable';
  static const String DAMAGED_PARTIALLY_USABLE = 'Damaged - Partially Usable';
  static const String DEFECTIVE = 'Defective';
  static const String EXPIRED = 'Expired';
  static const String WRONG_ITEM = 'Wrong Item';
  static const String MISSING_PARTS = 'Missing Parts';
  
  static const List<String> ALL_CONDITIONS = [
    DAMAGED_UNUSABLE,
    DAMAGED_PARTIALLY_USABLE,
    DEFECTIVE,
    EXPIRED,
    WRONG_ITEM,
    MISSING_PARTS,
  ];
}