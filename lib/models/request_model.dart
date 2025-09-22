import 'package:cloud_firestore/cloud_firestore.dart';

class PartRequest {
  final String requestId;
  final String partNumber;
  final String department;
  final String technician;
  final int requestedQuantity;
  final DateTime requestDate;
  final String priority;
  String status;

  PartRequest({
    required this.requestId,
    required this.partNumber,
    required this.department,
    required this.technician,
    required this.requestedQuantity,
    required this.requestDate,
    required this.priority,
    required this.status,
  });

  // Existing Firestore factory
  factory PartRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PartRequest.fromMap(data, doc.id);
  }

  factory PartRequest.fromMap(Map<String, dynamic> data, [String? docId]) {
    return PartRequest(
      requestId: data['request_id'] ?? docId ?? '',
      partNumber: data['part_number'] ?? '',
      department: data['department'] ?? '',
      technician: data['technician'] ?? '',
      requestedQuantity: data['rqted_qty'] is int
          ? data['rqted_qty']
          : int.tryParse((data['rqted_qty'] ?? '0').toString()) ?? 0,
      requestDate: (data['rqted_date'] is Timestamp)
          ? (data['rqted_date'] as Timestamp).toDate()
          : DateTime.now(),
      priority: data['priority'] ?? 'Normal',
      status: data['status'] ?? 'Pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'request_id': requestId,
      'part_number': partNumber,
      'department': department,
      'technician': technician,
      'rqted_qty': requestedQuantity,
      'rqted_date': requestDate,
      'priority': priority,
      'status': status,
    };
  }
}
