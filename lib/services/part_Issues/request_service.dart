import 'dart:async';
import 'package:assignment/dao/issue_dao.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/request_model.dart';
import '../../models/issue_model.dart';

class RequestService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream subscriptions
  static StreamSubscription<QuerySnapshot>? _requestsSub;
  static StreamSubscription<QuerySnapshot>? _inventorySub;

  // RETRIEVE OPERATIONS

  /// Subscribe to requests stream from Firestore
  static StreamSubscription<QuerySnapshot> subscribeToRequests({
    required Function(List<PartRequest>) onData,
    Function(dynamic)? onError,
  }) {
    _requestsSub?.cancel();
    _requestsSub = _firestore
        .collection('request')
        .orderBy('rqted_date', descending: true)
        .snapshots()
        .listen((snapshot) {
      final requests = snapshot.docs.map((d) => PartRequest.fromFirestore(d)).toList();
      onData(requests);
    }, onError: (e) {
      debugPrint('Request stream error: $e');
      onError?.call(e);
    });
    return _requestsSub!;
  }

  /// Get requests stream from Firestore
  static Stream<List<PartRequest>> getRequestsStream() {
    return _firestore
        .collection('request')
        .orderBy('rqted_date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => PartRequest.fromFirestore(doc)).toList());
  }

  /// Refresh requests (one-time fetch) from Firestore
  static Future<List<PartRequest>> refreshRequests() async {
    try {
      final snap = await _firestore
          .collection('request')
          .orderBy('rqted_date', descending: true)
          .get();
      final requests = snap.docs.map((d) => PartRequest.fromFirestore(d)).toList();
      return requests;
    } catch (e) {
      debugPrint('Failed to refresh requests: $e');
      rethrow;
    }
  }

  /// Get request details by ID from Firestore
  static Future<PartRequest?> getRequestById(String requestId) async {
    try {
      final querySnapshot = await _firestore
          .collection('request')
          .where('request_id', isEqualTo: requestId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return PartRequest.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('Failed to get request by ID: $e');
      return null;
    }
  }

  /// Get transaction details with related request
  static Future<Map<String, dynamic>> getTransactionDetails(
      IssueTransaction transaction, {
        List<PartRequest>? localRequests,
      }) async {
    PartRequest? relatedRequest;

    // Try to find the related request from local cache first
    if (localRequests != null) {
      try {
        relatedRequest = localRequests.firstWhere(
              (req) => req.requestId == transaction.requestId,
        );
      } catch (e) {
        // Not found in cache
      }
    }

    // If not found in cache, try to fetch from Firestore
    if (relatedRequest == null) {
      relatedRequest = await getRequestById(transaction.requestId);
    }

    return {
      'transaction': transaction,
      'relatedRequest': relatedRequest,
    };
  }

  // UPDATE OPERATIONS

  /// Complete an issue by updating request status and quantities
  static Future<void> completeIssue({
    required PartRequest request,
    required int issuedQuantity,
    required String notes,
  }) async {
    if (issuedQuantity < 0) {
      throw ArgumentError('Issued quantity cannot be negative');
    }

    try {
      final reqQuery = await _firestore
          .collection('request')
          .where('request_id', isEqualTo: request.requestId)
          .get();

      if (reqQuery.docs.isNotEmpty) {
        final docId = reqQuery.docs.first.id;

        String newStatus;
        if (issuedQuantity <= 0) {
          newStatus = 'Backorder';
          await updateRequestStatus(
            requestId: request.requestId,
            status: newStatus,
          );
        } else if (issuedQuantity >= request.requestedQuantity) {
          newStatus = 'Completed';
          await updateRequestStatus(
            requestId: request.requestId,
            status: newStatus,
          );
        } else {
          newStatus = 'Partially Issued';
          await updateRequestStatus(
            requestId: request.requestId,
            status: newStatus,
          );
        }
      } else {
        throw Exception('Request not found: ${request.requestId}');
      }
    } catch (e) {
      debugPrint('Issue completion failed: $e');
      rethrow;
    }
  }

  /// Update request status in Firestore
  static Future<void> updateRequestStatus({
    required String requestId,
    required String status,
    Map<String, Object?>? additionalFields,
  }) async {
    try {
      final reqQuery = await _firestore
          .collection('request')
          .where('request_id', isEqualTo: requestId)
          .get();

      if (reqQuery.docs.isNotEmpty) {
        final docId = reqQuery.docs.first.id;
        final updateData = <String, Object?>{
          'status': status,
          'updated_at': Timestamp.fromDate(DateTime.now()),
        };

        if (additionalFields != null) {
          updateData.addAll(additionalFields);
        }

        await _firestore.collection('request').doc(docId).update(updateData);
      } else {
        throw Exception('Request not found: $requestId');
      }
    } catch (e) {
      debugPrint('Failed to update request status: $e');
      rethrow;
    }
  }


  // COMPLEX OPERATIONS

  /// Process request rejection - updates request status and creates issue record
  static Future<void> processRejection(
      PartRequest request,
      String reason,
      String rejectedBy
      ) async {
    try {
      // Insert rejection into issue collection
      await IssueDao.insertIssue(
        requestId: request.requestId,
        issueType: "Rejected",
        quantity: 0,
        notes: reason,
        requestedQuantity: request.requestedQuantity,
        createdAt: DateTime.now(),
        createdBy: rejectedBy,
      );

      // Update request status
      await updateRequestStatus(
        requestId: request.requestId,
        status: 'Rejected',
      );
    } catch (e) {
      debugPrint('Failed to process rejection: $e');
      throw Exception("Failed to reject request: $e");
    }
  }

  /// Cancel all active subscriptions
  static void cancelSubscriptions() {
    _requestsSub?.cancel();
    _inventorySub?.cancel();
    _requestsSub = null;
    _inventorySub = null;
  }

  /// Check if Firestore is available
  static Future<bool> isFirestoreAvailable() async {
    try {
      await _firestore.collection('request').limit(1).get();
      return true;
    } catch (e) {
      debugPrint('Firestore not available: $e');
      return false;
    }
  }

  /// Get collection statistics
  static Future<Map<String, int>> getRequestStatistics() async {
    try {
      final snapshot = await _firestore.collection('request').get();
      final requests = snapshot.docs.map((doc) => PartRequest.fromFirestore(doc)).toList();

      final stats = <String, int>{
        'total': requests.length,
        'pending': requests.where((r) => r.status == 'Pending').length,
        'completed': requests.where((r) => r.status == 'Completed').length,
        'rejected': requests.where((r) => r.status == 'Rejected').length,
        'partially_issued': requests.where((r) => r.status == 'Partially Issued').length,
        'backorder': requests.where((r) => r.status == 'Backorder').length,
      };

      return stats;
    } catch (e) {
      debugPrint('Failed to get request statistics: $e');
      rethrow;
    }
  }
}