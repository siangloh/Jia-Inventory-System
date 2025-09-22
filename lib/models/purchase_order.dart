// models/purchase_order.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum POStatus {
  PENDING_APPROVAL,
  APPROVED,
  REJECTED,
  PARTIALLY_RECEIVED,
  COMPLETED,
  READY,
  CANCELLED
}

enum POPriority {
  LOW,
  NORMAL,
  HIGH,
  URGENT
}

enum POCreatorRole {
  WORKSHOP_MANAGER,
  SENIOR_MECHANIC,
  INVENTORY_STAFF,
  SERVICE_ADVISOR
}

class PurchaseOrder {
  final String id;
  final String poNumber; // Auto-generated: PO-2025-001
  final DateTime createdDate;
  final DateTime? expectedDeliveryDate;
  final DateTime? actualDeliveryDate;

  // Status & Priority
  final POStatus status;
  final POPriority priority;

  // Creator Information
  final String createdByUserId;
  final String createdByUserName;
  final POCreatorRole creatorRole;

  // Supplier Information
  final String supplierId;
  final String supplierName;
  final String supplierContact;
  final String? supplierEmail;
  final String? supplierPhone;

  // Financial Information
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double shippingCost;
  final double discountAmount;
  final double totalAmount;
  final String currency;

  // Delivery Information
  final String deliveryAddress;
  final String? deliveryInstructions;
  final String? trackingNumber;

  // Line Items
  final List<POLineItem> lineItems;

  // Approval Information
  final String? approvedByUserId;
  final String? approvedByUserName;
  final DateTime? approvedDate;
  final List<POApprovalHistory> approvalHistory;

  // Job/Project Reference
  final String? jobId;
  final String? jobNumber;
  final String? customerName;

  // Additional Information
  final String? notes;
  final String? internalNotes;
  final List<String> attachments; // File URLs

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedByUserId;

  PurchaseOrder({
    required this.id,
    required this.poNumber,
    required this.createdDate,
    this.expectedDeliveryDate,
    this.actualDeliveryDate,
    required this.status,
    required this.priority,
    required this.createdByUserId,
    required this.createdByUserName,
    required this.creatorRole,
    required this.supplierId,
    required this.supplierName,
    required this.supplierContact,
    this.supplierEmail,
    this.supplierPhone,
    required this.subtotal,
    required this.taxRate,
    required this.taxAmount,
    required this.shippingCost,
    required this.discountAmount,
    required this.totalAmount,
    required this.currency,
    required this.deliveryAddress,
    this.deliveryInstructions,
    this.trackingNumber,
    required this.lineItems,
    this.approvedByUserId,
    this.approvedByUserName,
    this.approvedDate,
    required this.approvalHistory,
    this.jobId,
    this.jobNumber,
    this.customerName,
    this.notes,
    this.internalNotes,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
    this.updatedByUserId,
  });

  // Convert to Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'poNumber': poNumber,
      'createdDate': Timestamp.fromDate(createdDate),
      'expectedDeliveryDate': expectedDeliveryDate != null
          ? Timestamp.fromDate(expectedDeliveryDate!)
          : null,
      'actualDeliveryDate': actualDeliveryDate != null
          ? Timestamp.fromDate(actualDeliveryDate!)
          : null,
      'status': status.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'createdByUserId': createdByUserId,
      'createdByUserName': createdByUserName,
      'creatorRole': creatorRole.toString().split('.').last,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'supplierContact': supplierContact,
      'supplierEmail': supplierEmail,
      'supplierPhone': supplierPhone,
      'subtotal': subtotal,
      'taxRate': taxRate,
      'taxAmount': taxAmount,
      'shippingCost': shippingCost,
      'discountAmount': discountAmount,
      'totalAmount': totalAmount,
      'currency': currency,
      'deliveryAddress': deliveryAddress,
      'deliveryInstructions': deliveryInstructions,
      'trackingNumber': trackingNumber,
      'lineItems': lineItems.map((item) => item.toFirestore()).toList(),
      'approvedByUserId': approvedByUserId,
      'approvedByUserName': approvedByUserName,
      'approvedDate': approvedDate != null
          ? Timestamp.fromDate(approvedDate!)
          : null,
      'approvalHistory': approvalHistory.map((h) => h.toFirestore()).toList(),
      'jobId': jobId,
      'jobNumber': jobNumber,
      'customerName': customerName,
      'notes': notes,
      'internalNotes': internalNotes,
      'attachments': attachments,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedByUserId': updatedByUserId,
    };
  }

  // Create from Firestore Map
  factory PurchaseOrder.fromFirestore(Map<String, dynamic> map) {
    return PurchaseOrder(
      id: map['id'] ?? '',
      poNumber: map['poNumber'] ?? '',
      createdDate: (map['createdDate'] as Timestamp).toDate(),
      expectedDeliveryDate: map['expectedDeliveryDate'] != null
          ? (map['expectedDeliveryDate'] as Timestamp).toDate()
          : null,
      actualDeliveryDate: map['actualDeliveryDate'] != null
          ? (map['actualDeliveryDate'] as Timestamp).toDate()
          : null,
      status: POStatus.values.firstWhere(
            (e) => e.toString().split('.').last == map['status'],
        orElse: () => POStatus.PENDING_APPROVAL,
      ),
      priority: POPriority.values.firstWhere(
            (e) => e.toString().split('.').last == map['priority'],
        orElse: () => POPriority.NORMAL,
      ),
      createdByUserId: map['createdByUserId'] ?? '',
      createdByUserName: map['createdByUserName'] ?? '',
      creatorRole: POCreatorRole.values.firstWhere(
            (e) => e.toString().split('.').last == map['creatorRole'],
        orElse: () => POCreatorRole.WORKSHOP_MANAGER,
      ),
      supplierId: map['supplierId'] ?? '',
      supplierName: map['supplierName'] ?? '',
      supplierContact: map['supplierContact'] ?? '',
      supplierEmail: map['supplierEmail'],
      supplierPhone: map['supplierPhone'],
      subtotal: (map['subtotal'] ?? 0.0).toDouble(),
      taxRate: (map['taxRate'] ?? 0.0).toDouble(),
      taxAmount: (map['taxAmount'] ?? 0.0).toDouble(),
      shippingCost: (map['shippingCost'] ?? 0.0).toDouble(),
      discountAmount: (map['discountAmount'] ?? 0.0).toDouble(),
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      currency: map['currency'] ?? 'USD',
      deliveryAddress: map['deliveryAddress'] ?? '',
      deliveryInstructions: map['deliveryInstructions'],
      trackingNumber: map['trackingNumber'],
      lineItems: (map['lineItems'] as List<dynamic>?)
          ?.map((item) => POLineItem.fromFirestore(item as Map<String, dynamic>))
          .toList() ?? [],
      approvedByUserId: map['approvedByUserId'],
      approvedByUserName: map['approvedByUserName'],
      approvedDate: map['approvedDate'] != null
          ? (map['approvedDate'] as Timestamp).toDate()
          : null,
      approvalHistory: (map['approvalHistory'] as List<dynamic>?)
          ?.map((h) => POApprovalHistory.fromFirestore(h as Map<String, dynamic>))
          .toList() ?? [],
      jobId: map['jobId'],
      jobNumber: map['jobNumber'],
      customerName: map['customerName'],
      notes: map['notes'],
      internalNotes: map['internalNotes'],
      attachments: List<String>.from(map['attachments'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      updatedByUserId: map['updatedByUserId'],
    );
  }

  // Copy with method for updates
  PurchaseOrder copyWith({
    String? id,
    String? poNumber,
    DateTime? createdDate,
    DateTime? expectedDeliveryDate,
    DateTime? actualDeliveryDate,
    POStatus? status,
    POPriority? priority,
    String? createdByUserId,
    String? createdByUserName,
    POCreatorRole? creatorRole,
    String? supplierId,
    String? supplierName,
    String? supplierContact,
    String? supplierEmail,
    String? supplierPhone,
    double? subtotal,
    double? taxRate,
    double? taxAmount,
    double? shippingCost,
    double? discountAmount,
    double? totalAmount,
    String? currency,
    String? deliveryAddress,
    String? deliveryInstructions,
    String? trackingNumber,
    List<POLineItem>? lineItems,
    String? approvedByUserId,
    String? approvedByUserName,
    DateTime? approvedDate,
    List<POApprovalHistory>? approvalHistory,
    String? jobId,
    String? jobNumber,
    String? customerName,
    String? notes,
    String? internalNotes,
    List<String>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedByUserId,
  }) {
    return PurchaseOrder(
      id: id ?? this.id,
      poNumber: poNumber ?? this.poNumber,
      createdDate: createdDate ?? this.createdDate,
      expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
      actualDeliveryDate: actualDeliveryDate ?? this.actualDeliveryDate,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByUserName: createdByUserName ?? this.createdByUserName,
      creatorRole: creatorRole ?? this.creatorRole,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      supplierContact: supplierContact ?? this.supplierContact,
      supplierEmail: supplierEmail ?? this.supplierEmail,
      supplierPhone: supplierPhone ?? this.supplierPhone,
      subtotal: subtotal ?? this.subtotal,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      shippingCost: shippingCost ?? this.shippingCost,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      lineItems: lineItems ?? this.lineItems,
      approvedByUserId: approvedByUserId ?? this.approvedByUserId,
      approvedByUserName: approvedByUserName ?? this.approvedByUserName,
      approvedDate: approvedDate ?? this.approvedDate,
      approvalHistory: approvalHistory ?? this.approvalHistory,
      jobId: jobId ?? this.jobId,
      jobNumber: jobNumber ?? this.jobNumber,
      customerName: customerName ?? this.customerName,
      notes: notes ?? this.notes,
      internalNotes: internalNotes ?? this.internalNotes,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByUserId: updatedByUserId ?? this.updatedByUserId,
    );
  }
}

class POLineItem {
  final String id;
  final String productId; // Reference to existing product or newly created
  final String productName;
  final String? productSKU;
  final String? productDescription;
  final String? partNumber;
  final String? brand;

  final int quantityOrdered;
  final int? quantityReceived;
  final int? quantityPlaced;

  final int quantityDamaged;
  final double unitPrice;
  final double lineTotal;

  final String? notes;
  final bool isNewProduct; // Track if product was created during PO creation

  // Status for individual line items
  final String status; // PENDING, RECEIVED, PARTIAL, CANCELLED

  POLineItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.productSKU,
    this.productDescription,
    this.partNumber,
    this.brand,
    required this.quantityOrdered,
    this.quantityReceived,
    this.quantityPlaced,
    this.quantityDamaged = 0,
    required this.unitPrice,
    required this.lineTotal,
    this.notes,
    required this.isNewProduct,
    required this.status,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'productSKU': productSKU,
      'productDescription': productDescription,
      'partNumber': partNumber,
      'brand': brand,
      'quantityOrdered': quantityOrdered,
      'quantityReceived': quantityReceived,
      'quantityPlaced': quantityPlaced,
      'quantityDamaged': quantityDamaged,
      'unitPrice': unitPrice,
      'lineTotal': lineTotal,
      'notes': notes,
      'isNewProduct': isNewProduct,
      'status': status,
    };
  }

  factory POLineItem.fromFirestore(Map<String, dynamic> map) {
    return POLineItem(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productSKU: map['productSKU'],
      productDescription: map['productDescription'],
      partNumber: map['partNumber'],
      brand: map['brand'],
      quantityOrdered: map['quantityOrdered'] ?? 0,
      quantityReceived: map['quantityReceived'],
      quantityPlaced: map['quantityPlaced'],
      quantityDamaged: map['quantityDamaged'] ?? 0,
      unitPrice: (map['unitPrice'] ?? 0.0).toDouble(),
      lineTotal: (map['lineTotal'] ?? 0.0).toDouble(),
      notes: map['notes'],
      isNewProduct: map['isNewProduct'] ?? false,
      status: map['status'] ?? 'PENDING',
    );
  }

  POLineItem copyWith({
    String? id,
    String? productId,
    String? productName,
    String? productSKU,
    String? productDescription,
    String? partNumber,
    String? brand,
    int? quantityOrdered,
    int? quantityReceived,
    int? quantityPlaced,
    int? quantityDamaged,
    double? unitPrice,
    double? lineTotal,
    String? notes,
    bool? isNewProduct,
    String? status,
  }) {
    return POLineItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productSKU: productSKU ?? this.productSKU,
      productDescription: productDescription ?? this.productDescription,
      partNumber: partNumber ?? this.partNumber,
      brand: brand ?? this.brand,
      quantityOrdered: quantityOrdered ?? this.quantityOrdered,
      quantityReceived: quantityReceived ?? this.quantityReceived,
      quantityPlaced: quantityPlaced ?? this.quantityPlaced,
      quantityDamaged: quantityDamaged ?? this.quantityDamaged,
      unitPrice: unitPrice ?? this.unitPrice,
      lineTotal: lineTotal ?? this.lineTotal,
      notes: notes ?? this.notes,
      isNewProduct: isNewProduct ?? this.isNewProduct,
      status: status ?? this.status,
    );
  }
}

class POApprovalHistory {
  final String id;
  final String userId;
  final String userName;
  final String userRole;
  final POStatus fromStatus;
  final POStatus toStatus;
  final DateTime timestamp;
  final String? comments;
  final String action; // APPROVED, REJECTED, REQUESTED_CHANGES

  POApprovalHistory({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.fromStatus,
    required this.toStatus,
    required this.timestamp,
    this.comments,
    required this.action,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userRole': userRole,
      'fromStatus': fromStatus.toString().split('.').last,
      'toStatus': toStatus.toString().split('.').last,
      'timestamp': Timestamp.fromDate(timestamp),
      'comments': comments,
      'action': action,
    };
  }

  factory POApprovalHistory.fromFirestore(Map<String, dynamic> map) {
    return POApprovalHistory(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userRole: map['userRole'] ?? '',
      fromStatus: POStatus.values.firstWhere(
            (e) => e.toString().split('.').last == map['fromStatus'],
        orElse: () => POStatus.PENDING_APPROVAL,
      ),
      toStatus: POStatus.values.firstWhere(
            (e) => e.toString().split('.').last == map['toStatus'],
        orElse: () => POStatus.PENDING_APPROVAL,
      ),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      comments: map['comments'],
      action: map['action'] ?? '',
    );
  }
}