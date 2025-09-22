import 'package:cloud_firestore/cloud_firestore.dart';

// Removed enums - using strings like ReturnService for consistency

class DiscrepancyReport {
  final String id;
  final String poId;
  final String lineItemId;
  final String partId;
  final String partName;
  final String sku;
  final String discrepancyType;
  final int quantityAffected;
  final String description;
  final List<String> photos; 
  final String reportedBy;
  final String reportedByName; 
  final DateTime reportedAt;
  final String status;
  final double costImpact;
  final String? rootCause;
  final String? preventionMeasures;
  final bool supplierNotified;
  final bool insuranceClaimed;
  final String? resolution;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  DiscrepancyReport({
    required this.id,
    required this.poId,
    required this.lineItemId,
    required this.partId,
    required this.partName,
    required this.sku,
    required this.discrepancyType,
    required this.quantityAffected,
    required this.description,
    required this.photos,
    required this.reportedBy,
    required this.reportedByName,
    required this.reportedAt,
    required this.status,
    required this.costImpact,
    this.rootCause,
    this.preventionMeasures,
    required this.supplierNotified,
    required this.insuranceClaimed,
    this.resolution,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DiscrepancyReport.fromFirestore(Map<String, dynamic> data) {
    return DiscrepancyReport(
      id: data['id'] ?? '',
      poId: data['poId'] ?? '',
      lineItemId: data['lineItemId'] ?? '',
      partId: data['partId'] ?? '',
      partName: data['partName'] ?? '',
      sku: data['sku'] ?? '',
      discrepancyType: data['discrepancyType'] ?? 'physicalDamage',
      quantityAffected: data['quantityAffected'] ?? 0,
      description: data['description'] ?? '',
      photos: List<String>.from(data['photos'] ?? []),
      reportedBy: data['reportedBy'] ?? '',
      reportedByName: data['reportedByName'] ?? '',
      reportedAt: (data['reportedAt'] as Timestamp).toDate(),
      status: data['status'] ?? 'submitted',
      costImpact: (data['costImpact'] ?? 0.0).toDouble(),
      rootCause: data['rootCause'],
      preventionMeasures: data['preventionMeasures'],
      supplierNotified: data['supplierNotified'] ?? false,
      insuranceClaimed: data['insuranceClaimed'] ?? false,
      resolution: data['resolution'],
      resolvedAt: data['resolvedAt'] != null 
          ? (data['resolvedAt'] as Timestamp).toDate() 
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'poId': poId,
      'lineItemId': lineItemId,
      'partId': partId,
      'partName': partName,
      'sku': sku,
      'discrepancyType': discrepancyType,
      'quantityAffected': quantityAffected,
      'description': description,
      'photos': photos,
      'reportedBy': reportedBy,
      'reportedByName': reportedByName,
      'reportedAt': Timestamp.fromDate(reportedAt),
      'status': status,
      'costImpact': costImpact,
      'rootCause': rootCause,
      'preventionMeasures': preventionMeasures,
      'supplierNotified': supplierNotified,
      'insuranceClaimed': insuranceClaimed,
      'resolution': resolution,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  DiscrepancyReport copyWith({
    String? id,
    String? poId,
    String? lineItemId,
    String? partId,
    String? partName,
    String? sku,
    String? discrepancyType,
    int? quantityAffected,
    String? description,
    List<String>? photos,
    String? reportedBy,
    String? reportedByName,
    DateTime? reportedAt,
    String? status,
    double? costImpact,
    String? rootCause,
    String? preventionMeasures,
    bool? supplierNotified,
    bool? insuranceClaimed,
    String? resolution,
    DateTime? resolvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiscrepancyReport(
      id: id ?? this.id,
      poId: poId ?? this.poId,
      lineItemId: lineItemId ?? this.lineItemId,
      partId: partId ?? this.partId,
      partName: partName ?? this.partName,
      sku: sku ?? this.sku,
      discrepancyType: discrepancyType ?? this.discrepancyType,
      quantityAffected: quantityAffected ?? this.quantityAffected,
      description: description ?? this.description,
      photos: photos ?? this.photos,
      reportedBy: reportedBy ?? this.reportedBy,
      reportedByName: reportedByName ?? this.reportedByName,
      reportedAt: reportedAt ?? this.reportedAt,
      status: status ?? this.status,
      costImpact: costImpact ?? this.costImpact,
      rootCause: rootCause ?? this.rootCause,
      preventionMeasures: preventionMeasures ?? this.preventionMeasures,
      supplierNotified: supplierNotified ?? this.supplierNotified,
      insuranceClaimed: insuranceClaimed ?? this.insuranceClaimed,
      resolution: resolution ?? this.resolution,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


