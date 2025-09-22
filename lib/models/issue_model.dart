import 'package:cloud_firestore/cloud_firestore.dart';

class IssueTransaction {
  final String issueId;
  final String requestId;
  final int requestedQuantity;
  final int quantity; // issued quantity
  final String issueType;
  final String notes;
  final String createdBy;
  final DateTime createdAt;

  IssueTransaction({
    required this.issueId,
    required this.requestId,
    required this.requestedQuantity,
    required this.quantity,
    required this.issueType,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  // 🔹 Convert to Firestore Map
  Map<String, dynamic> toFirestore() => {
    'issueId' : issueId,
    'requestId': requestId,
    'requestedQuantity': requestedQuantity,
    'quantity': quantity,
    'issueType': issueType,
    'notes': notes,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(), // store as string like your sample
  };

  // 🔹 Construct from Firestore document
  factory IssueTransaction.fromFirestore(Map<String, dynamic> data) {
    return IssueTransaction(
      issueId: data['issueId'] ?? '',
      requestId: data['requestId'] ?? '',
      requestedQuantity: data['requestedQuantity'] ?? 0,
      quantity: data['quantity'] ?? 0,
      issueType: data['issueType'] ?? '',
      notes: data['notes'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
