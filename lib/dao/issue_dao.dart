import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/request_model.dart';
import '../models/issue_model.dart';

class IssueDao {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream subscription for issues
  static StreamSubscription<QuerySnapshot>? _issuesSub;

// Subscribe to issues stream FIRESTORE
  static StreamSubscription<QuerySnapshot> subscribeToIssues({
    required Function(List<IssueTransaction>) onData,
    Function(dynamic)? onError,
    int? limit,
  }) {
    _issuesSub?.cancel();

    Query query = _firestore
        .collection('issue')
        .orderBy('createdAt', descending: true); // 🔹 updated to match new model

    if (limit != null) {
      query = query.limit(limit);
    }

    _issuesSub = query.snapshots().listen(
          (snapshot) {
        final transactions = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
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
        }).toList();
        onData(transactions);
      },
      onError: (e) {
        debugPrint('Issues stream error: $e');
        onError?.call(e);
      },
    );

    return _issuesSub!;
  }


// Load issues with optional filtering and pagination
  static Future<List<IssueTransaction>> loadIssues({
    int? limit = 50,
    DateTime? startDate,
    DateTime? endDate,
    String? createdBy,
    String? requestId,
  }) async {
    try {
      Query query = _firestore
          .collection('issue')
          .orderBy('createdAt', descending: true);

      // 🔹 Apply date range filter
      if (startDate != null) {
        query = query.where('createdAt',
            isGreaterThanOrEqualTo: startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.where('createdAt',
            isLessThanOrEqualTo: endDate.toIso8601String());
      }

      // 🔹 Apply createdBy filter
      if (createdBy != null && createdBy.isNotEmpty) {
        query = query.where('createdBy', isEqualTo: createdBy);
      }

      // 🔹 Apply requestId filter
      if (requestId != null && requestId.isNotEmpty) {
        query = query.where('requestId', isEqualTo: requestId);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return IssueTransaction.fromFirestore(data);
      }).toList();
    } catch (e) {
      debugPrint('Failed to load issues: $e');
      rethrow;
    }
  }


  // 🔎 Filter transactions by search query
  static List<IssueTransaction> filterTransactionsBySearch(
      List<IssueTransaction> transactions,
      String searchQuery,
      ) {
    if (searchQuery.isEmpty) return transactions;

    final query = searchQuery.toLowerCase().trim();

    return transactions.where((transaction) {
      return transaction.requestId.toLowerCase().contains(query) ||
          transaction.createdBy.toLowerCase().contains(query) ||
          transaction.issueType.toLowerCase().contains(query) ||
          transaction.notes.toLowerCase().contains(query);
    }).toList();
  }


  // Filter transactions by date range
  static List<IssueTransaction> filterTransactionsByDateRange(
      List<IssueTransaction> transactions,
      DateTime? startDate,
      DateTime? endDate,
      ) {
    if (startDate == null && endDate == null) return transactions;

    return transactions.where((transaction) {
      final issueDate = transaction.createdAt;

      if (startDate != null && issueDate.isBefore(startDate)) {
        return false;
      }

      if (endDate != null && issueDate.isAfter(endDate.add(const Duration(days: 1)))) {
        return false;
      }

      return true;
    }).toList();
  }

  // Filter transactions by issued by
  static List<IssueTransaction> filterTransactionsByIssuedBy(
      List<IssueTransaction> transactions,
      String issuedBy,
      ) {
    if (issuedBy.isEmpty || issuedBy == 'All') return transactions;

    return transactions.where((transaction) {
      return transaction.createdBy.toLowerCase() == issuedBy.toLowerCase();
    }).toList();
  }

  // Filter transactions by quantity range
  static List<IssueTransaction> filterTransactionsByQuantityRange(
      List<IssueTransaction> transactions,
      int? minQuantity,
      int? maxQuantity,
      ) {
    if (minQuantity == null && maxQuantity == null) return transactions;

    return transactions.where((transaction) {
      if (minQuantity != null && transaction.quantity < minQuantity) {
        return false;
      }

      if (maxQuantity != null && transaction.quantity > maxQuantity) {
        return false;
      }

      return true;
    }).toList();
  }

  // Get unique issued by users for filter dropdown
  static List<String> getUniqueIssuedByUsers(List<IssueTransaction> transactions) {
    final users = transactions.map((t) => t.createdBy).toSet().toList();
    users.sort();
    return ['All'] + users;
  }

  // Get unique request IDs for filter dropdown
  static List<String> getUniqueRequestIds(List<IssueTransaction> transactions) {
    final requestIds = transactions.map((t) => t.requestId).toSet().toList();
    requestIds.sort();
    return ['All'] + requestIds;
  }

  // Get transaction statistics
  static Map<String, dynamic> getTransactionStatistics(
      List<IssueTransaction> transactions, {
        DateTime? startDate,
        DateTime? endDate,
      }) {
    // Filter by date if provided
    List<IssueTransaction> filteredTransactions = transactions;
    if (startDate != null || endDate != null) {
      filteredTransactions = filterTransactionsByDateRange(transactions, startDate, endDate);
    }

    if (filteredTransactions.isEmpty) {
      return {
        'totalTransactions': 0,
        'totalQuantityIssued': 0,
        'averageQuantityPerTransaction': 0.0,
        'uniqueUsers': 0,
        'uniqueRequests': 0,
        'transactionsByUser': <String, int>{},
        'dailyTransactions': <String, int>{},
      };
    }

    final totalTransactions = filteredTransactions.length;
    final totalQuantity = filteredTransactions.fold<int>(0, (sum, t) => sum + t.quantity);
    final averageQuantity = totalQuantity / totalTransactions;
    final uniqueUsers = filteredTransactions.map((t) => t.createdBy).toSet().length;
    final uniqueRequests = filteredTransactions.map((t) => t.requestId).toSet().length;

    // Group by user
    final transactionsByUser = <String, int>{};
    for (final transaction in filteredTransactions) {
      transactionsByUser[transaction.createdBy] =
          (transactionsByUser[transaction.createdBy] ?? 0) + 1;
    }

    // Group by day
    final dailyTransactions = <String, int>{};
    for (final transaction in filteredTransactions) {
      final dateKey = '${transaction.createdAt.year}-${transaction.createdAt.month.toString().padLeft(2, '0')}-${transaction.createdAt.day.toString().padLeft(2, '0')}';
      dailyTransactions[dateKey] = (dailyTransactions[dateKey] ?? 0) + 1;
    }

    return {
      'totalTransactions': totalTransactions,
      'totalQuantityIssued': totalQuantity,
      'averageQuantityPerTransaction': averageQuantity,
      'uniqueUsers': uniqueUsers,
      'uniqueRequests': uniqueRequests,
      'transactionsByUser': transactionsByUser,
      'dailyTransactions': dailyTransactions,
    };
  }

// Get issue details with related data FIRESTORE
  static Future<Map<String, dynamic>> getIssueDetails(
      String docId, { // now we use the Firestore document ID instead of old transactionId
        List<PartRequest>? localRequests,
      }) async {
    try {
      // Fetch the issue document by its Firestore docId
      final issueDoc = await _firestore.collection('issue').doc(docId).get();

      if (!issueDoc.exists) {
        throw Exception('Issue not found');
      }

      final issueData = issueDoc.data() as Map<String, dynamic>;

      // Create IssueTransaction from Firestore
      final transaction = IssueTransaction.fromFirestore(issueData);

      PartRequest? relatedRequest;

      // Try local cache first
      if (localRequests != null) {
        try {
          relatedRequest = localRequests.firstWhere(
                (req) => req.requestId == transaction.requestId,
            orElse: () => throw Exception('Not found'),
          );
        } catch (_) {
          // If not found locally, fallback to Firestore
        }
      }

      // Fetch from Firestore if not found in local cache
      if (relatedRequest == null && transaction.requestId.isNotEmpty) {
        final requestQuery = await _firestore
            .collection('request')
            .where('request_id', isEqualTo: transaction.requestId)
            .limit(1)
            .get();

        if (requestQuery.docs.isNotEmpty) {
          relatedRequest = PartRequest.fromFirestore(requestQuery.docs.first);
        }
      }

      return {
        'transaction': transaction,
        'relatedRequest': relatedRequest,
      };
    } catch (e) {
      debugPrint('Failed to get issue details: $e');
      rethrow;
    }
  }


  // Cancel subscriptions
  static void cancelSubscriptions() {
    _issuesSub?.cancel();
  }

  /// Auto adjust issue quantity based on type, available stock, and requested qty
  static String autoAdjustQuantity({
    required String issueType,
    required int availableStock,
    required int requestedQuantity,
    required bool hasEnoughStock,
  }) {
    switch (issueType) {
      case 'Full Issue':
      // Only available if we have enough stock
        return requestedQuantity.toString();

      case 'Partial Issue':
      // Default to maximum available stock or half of requested, whichever is smaller
        int partialAmount = availableStock;
        if (hasEnoughStock) {
          // If we have enough stock but user chose partial, default to half
          partialAmount = (requestedQuantity / 2).ceil();
        }
        return partialAmount.toString();

      case 'Backorder':
        return '0';

      default:
        return '0';
    }
  }

  /// Validates and adjusts issue type based on manual qty input
  static String handleQuantityChanged({
    required String currentIssueType,
    required String inputText,
    required int requestedQuantity,   // 👈 add this
    required bool hasEnoughStock,
  }) {
    final qty = int.tryParse(inputText) ?? 0;

    if (qty == 0 && currentIssueType != 'Backorder') {
      return 'Backorder';
    } else if (qty > 0) {
      if (qty >= requestedQuantity) {
        return 'Full Issue'; // 👈 new status if fully satisfied
      } else {
        return 'Partial Issue';
      }
    }

    return currentIssueType; // unchanged
  }


  static Map<String, dynamic> handleIssue({
    required String issueType,
    required String notes,
    required String inputText,
    required int availableStock,
    required int requestedQuantity,
    required bool hasEnoughStock,
  }) {
    int issueQty = int.tryParse(inputText) ?? 0;

    if (issueType == 'Backorder') {
      if (notes.trim().isEmpty) {
        return {"success": false, "error": "Please provide notes for backorder"};
      }
      issueQty = 0; // backorder = no stock issued
    } else {
      if (issueQty <= 0) {
        return {"success": false, "error": "Please enter a valid quantity"};
      }

      if (issueQty > availableStock) {
        return {
          "success": false,
          "error": "Cannot issue more than available stock ($availableStock)"
        };
      }

      // Special rule for partial when insufficient stock
      if (!hasEnoughStock && issueType == 'Partial Issue') {
        if (issueQty > availableStock) {
          return {
            "success": false,
            "error": "Partial issue cannot exceed available stock"
          };
        }
      }
    }

    return {
      "success": true,
      "quantity": issueQty,
      "notes": notes,
    };
  }

  /// Insert new issue into Firestore
  static Future<void> insertIssue({
    String? issueId,
    required String requestId,
    required String issueType,
    required int quantity,
    required String notes,
    required int requestedQuantity,
    required DateTime createdAt,
    required String createdBy,
  }) async {
    try {
      // Auto-generate if not provided
      final newIssueId = (issueId == null || issueId.isEmpty)
          ? await getNextIssueId()
          : issueId;

      final data = {
        'issueId' : newIssueId,
        'requestId': requestId,
        'issueType': issueType,
        'quantity': quantity,
        'notes': notes,
        'requestedQuantity': requestedQuantity,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
      };

      if (newIssueId != null && newIssueId.isNotEmpty) {
        // Use custom document ID
        await _firestore.collection('issue').doc(newIssueId).set(data);
      } else {
        // Let Firestore auto-generate ID
        await _firestore.collection('issue').add(data);
      }
    } catch (e) {
      throw Exception("Failed to insert issue: $e");
    }
  }

  /// Generate the next issueId by checking the latest one in Firestore
  static Future<String> getNextIssueId() async {
    try {
      final snapshot = await _firestore
          .collection('issue')
          .orderBy('createdAt', descending: true) // get latest
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return "ISSUE-0001";
      }

      final lastData = snapshot.docs.first.data() as Map<String, dynamic>;
      final lastId = lastData['issueId'] ?? "ISSUE-0000";

      // Extract the number part (e.g. ISSUE-0005 → 5)
      final numberPart = int.tryParse(lastId.split('-').last) ?? 0;
      final nextNumber = numberPart + 1;

      // Format with leading zeros (4 digits)
      return "ISSUE-${nextNumber.toString().padLeft(4, '0')}";
    } catch (e) {
      throw Exception("Failed to generate next issueId: $e");
    }
  }

  static Map<String, dynamic> getIssueTypeInfo(String issueType) {
    switch (issueType.toLowerCase()) {
      case 'full issue':
      case 'full_issue':
        return {
          'label': 'FULL ISSUE',
          'icon': Icons.check_circle_outline,
          'headerColor': const Color(0xFFF8FFF8),
          'statusColor': const Color(0xFF2E7D32),
        };
      case 'partial issue':
      case 'partial_issue':
        return {
          'label': 'PARTIAL ISSUE',
          'icon': Icons.pie_chart_outline,
          'headerColor': const Color(0xFFFFFBF0),
          'statusColor': const Color(0xFFE65100),
        };
      case 'backorder':
        return {
          'label': 'BACKORDER',
          'icon': Icons.schedule_outlined,
          'headerColor': const Color(0xFFFFF5F5),
          'statusColor': const Color(0xFFC62828),
        };
      case 'rejected':
        return {
          'label': 'REJECTED',
          'icon': Icons.cancel_outlined,
          'headerColor': const Color(0xFFFFF3F3),
          'statusColor': const Color(0xFFD32F2F),
        };
      default:
        return {
          'label': 'PENDING',
          'icon': Icons.info_outline,
          'headerColor': const Color(0xFFF8F9FA),
          'statusColor': const Color(0xFF616161),
        };
    }
  }

// In IssueDao class
  static List<String> getUniquePartNumbers(
      List<IssueTransaction> transactions,
      List<PartRequest> allRequests
      ) {
    Set<String> partNumbers = {'All'};

    // Get part numbers by matching request IDs
    for (var transaction in transactions) {
      try {
        var matchingRequest = allRequests.firstWhere(
                (request) => request.requestId == transaction.requestId
        );
        partNumbers.add(matchingRequest.partNumber);
      } catch (e) {
        // Request not found, skip
      }
    }

    return partNumbers.toList();
  }

  // Get unique departments from transactions
  static List<String> getUniqueDepartments(
      List<IssueTransaction> transactions,
      List<PartRequest> allRequests
      ) {
    Set<String> departments = {'All'};

    // Get departments by matching request IDs
    for (var transaction in transactions) {
      try {
        var matchingRequest = allRequests.firstWhere(
                (request) => request.requestId == transaction.requestId
        );
        departments.add(matchingRequest.department);
      } catch (e) {
        // Request not found, skip
      }
    }

    return departments.toList()..sort();
  }

// Update the filterTransactions method
  static List<IssueTransaction> filterTransactions(
      List<IssueTransaction> transactions, {
        required String searchQuery,
        DateTime? startDate,
        DateTime? endDate,
        required String issuedBy,
        required String partNumberFilter,
        required String departmentFilter, // Add this parameter
        required List<PartRequest> allRequests,
        int? minQuantity,
        int? maxQuantity,
      }) {
    return transactions.where((transaction) {
      // Search filter
      bool matchesSearch = searchQuery.isEmpty ||
          transaction.requestId.toLowerCase().contains(searchQuery.toLowerCase()) ||
          transaction.createdBy.toLowerCase().contains(searchQuery.toLowerCase());

      // Date filters
      bool matchesDateRange = true;
      if (startDate != null) {
        matchesDateRange = matchesDateRange &&
            transaction.createdAt.isAfter(startDate.subtract(const Duration(days: 1)));
      }
      if (endDate != null) {
        matchesDateRange = matchesDateRange &&
            transaction.createdAt.isBefore(endDate.add(const Duration(days: 1)));
      }

      // Issued by filter
      bool matchesIssuedBy = issuedBy == 'All' || transaction.createdBy == issuedBy;

      // Part number filter
      bool matchesPartNumber = true;
      if (partNumberFilter != 'All') {
        try {
          var matchingRequest = allRequests.firstWhere(
                  (request) => request.requestId == transaction.requestId
          );
          matchesPartNumber = matchingRequest.partNumber == partNumberFilter;
        } catch (e) {
          matchesPartNumber = false;
        }
      }

      // Department filter
      bool matchesDepartment = true;
      if (departmentFilter != 'All') {
        try {
          var matchingRequest = allRequests.firstWhere(
                  (request) => request.requestId == transaction.requestId
          );
          matchesDepartment = matchingRequest.department == departmentFilter;
        } catch (e) {
          matchesDepartment = false;
        }
      }

      // Quantity filters
      bool matchesQuantity = true;
      if (minQuantity != null) {
        matchesQuantity = matchesQuantity && transaction.quantity >= minQuantity;
      }
      if (maxQuantity != null) {
        matchesQuantity = matchesQuantity && transaction.quantity <= maxQuantity;
      }

      return matchesSearch && matchesDateRange && matchesIssuedBy &&
          matchesPartNumber && matchesDepartment && matchesQuantity;
    }).toList();
  }

  static List<IssueTransaction> applySorting(
      List<IssueTransaction> transactions,
      String sortType,
      List<PartRequest> allRequests,
      ) {
    var sortedList = List<IssueTransaction>.from(transactions);

    switch (sortType) {
      case 'date_desc':
        sortedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'date_asc':
        sortedList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'quantity_desc':
        sortedList.sort((a, b) {
          int qtyComparison = b.quantity.compareTo(a.quantity);
          if (qtyComparison != 0) return qtyComparison;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case 'quantity_asc':
        sortedList.sort((a, b) {
          int qtyComparison = a.quantity.compareTo(b.quantity);
          if (qtyComparison != 0) return qtyComparison;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case 'issued_by':
        sortedList.sort((a, b) {
          int userComparison = a.createdBy.compareTo(b.createdBy);
          if (userComparison != 0) return userComparison;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case 'issue_type':
        sortedList.sort((a, b) {
          final typeOrder = {
            'full issue': 1,
            'partial issue': 2,
            'backorder': 3,
            'rejected': 4
          };
          final aType = typeOrder[a.issueType.toLowerCase()] ?? 5;
          final bType = typeOrder[b.issueType.toLowerCase()] ?? 5;

          if (aType != bType) return aType.compareTo(bType);
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case 'request_id':
        sortedList.sort((a, b) {
          int requestComparison = a.requestId.compareTo(b.requestId);
          if (requestComparison != 0) return requestComparison;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case 'priority':
        sortedList.sort((a, b) {
          String aPriority = 'normal';
          String bPriority = 'normal';

          try {
            final aRequest = allRequests.firstWhere((req) => req.requestId == a.requestId);
            aPriority = aRequest.priority;
          } catch (e) {
            // Request not found
          }

          try {
            final bRequest = allRequests.firstWhere((req) => req.requestId == b.requestId);
            bPriority = bRequest.priority;
          } catch (e) {
            // Request not found
          }

          final priorityOrder = {'high': 1, 'urgent': 1, 'medium': 2, 'low': 3, 'normal': 4};
          final aPriorityVal = priorityOrder[aPriority.toLowerCase()] ?? 5;
          final bPriorityVal = priorityOrder[bPriority.toLowerCase()] ?? 5;

          if (aPriorityVal != bPriorityVal) return aPriorityVal.compareTo(bPriorityVal);
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
    }

    return sortedList;
  }

  static List<String> getBackorderSuggestions() {
    return [
      "Currently out of stock. New shipment expected by [date]",
      "Insufficient inventory. Awaiting supplier delivery in 2-3 weeks",
      "Stock depleted. Reorder placed with vendor",
      "Supplier backlog due to high demand",
      "Vendor manufacturing delay. Updated ETA to be provided"
    ];
  }

  static List<DropdownMenuItem<String>> getAvailableIssueTypes(bool hasEnoughStock) {
    List<DropdownMenuItem<String>> items = [];

    if (hasEnoughStock) {
      // If enough stock, show all options
      items.addAll([
        const DropdownMenuItem(value: 'Full Issue', child: Text('Full Issue')),
        const DropdownMenuItem(value: 'Partial Issue', child: Text('Partial Issue')),
        const DropdownMenuItem(value: 'Backorder', child: Text('Backorder')),
      ]);
    } else {
      // If insufficient stock, only show partial and backorder
      items.addAll([
        const DropdownMenuItem(value: 'Partial Issue', child: Text('Partial Issue')),
        const DropdownMenuItem(value: 'Backorder', child: Text('Backorder')),
      ]);
    }

    return items;
  }

  static Widget buildStatRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}