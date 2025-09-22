import 'dart:async';
import 'package:assignment/dao/warehouse_deduction_dao.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/request_model.dart';
import '../models/issue_model.dart';
import '../services/part_Issues/request_service.dart';

class RequestDao {

  // Get predefined rejection reasons
  static List<String> _getRejectionReasons() {
    return [
      'Insufficient stock',
      'Item discontinued',
      'Invalid request',
      'Budget constraints',
      'Not authorized',
      'Duplicate request',
      'Wrong specifications',
      'Priority conflict',
      'Supplier unavailable',
      'Quality concerns',
      'Other',
    ];
  }

  // BUSINESS LOGIC METHODS - DATA PROCESSING

  /// Filter pending requests based on various criteria
  static List<PartRequest> getFilteredPendingRequests(
      List<PartRequest> allRequests, {
        required String searchQuery,
        required String departmentFilter,
        required String priorityFilter,
        required String partNumberFilter,
        DateTime? startDate,
        DateTime? endDate,
      }) {
    return allRequests.where((request) {
      // Search filter
      bool matchesSearch = searchQuery.isEmpty ||
          request.requestId.toLowerCase().contains(searchQuery.toLowerCase()) ||
          request.partNumber.toLowerCase().contains(searchQuery.toLowerCase()) ||
          request.technician.toLowerCase().contains(searchQuery.toLowerCase());

      // Department filter
      bool matchesDepartment = departmentFilter == 'All' ||
          request.department == departmentFilter;

      // Priority filter
      bool matchesPriority = priorityFilter == 'All' ||
          request.priority == priorityFilter;

      // Part number filter
      bool matchesPartNumber = partNumberFilter == 'All' ||
          request.partNumber == partNumberFilter;

      // Date filtering
      bool matchesDateRange = true;
      if (startDate != null) {
        matchesDateRange = matchesDateRange &&
            request.requestDate.isAfter(startDate.subtract(const Duration(days: 1)));
      }
      if (endDate != null) {
        matchesDateRange = matchesDateRange &&
            request.requestDate.isBefore(endDate.add(const Duration(days: 1)));
      }

      return matchesSearch && matchesDepartment && matchesPriority &&
          matchesPartNumber && matchesDateRange;
    }).toList();
  }

  /// Filter transactions based on search criteria
  static List<IssueTransaction> getFilteredTransactions(
      List<IssueTransaction> allTransactions, {
        String searchQuery = '',
      }) {
    if (searchQuery.isEmpty) return allTransactions;

    final lowerQuery = searchQuery.toLowerCase();

    return allTransactions.where((transaction) {
      return transaction.requestId.toLowerCase().contains(lowerQuery) ||
          transaction.createdBy.toLowerCase().contains(lowerQuery) ||
          transaction.issueType.toLowerCase().contains(lowerQuery) ||
          transaction.notes.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Get unique departments from requests
  static List<String> getDepartments(List<PartRequest> requests) {
    return ['All'] + requests.map((r) => r.department).toSet().toList();
  }

  /// Get unique priorities from requests
  static List<String> getPriorities(List<PartRequest> requests) {
    return ['All'] + requests.map((r) => r.priority).toSet().toList();
  }

  /// Get unique part numbers from requests
  static List<String> getPartNumbers(List<PartRequest> requests) {
    return ['All'] + requests.map((r) => r.partNumber).toSet().toList();
  }

  // WRAPPER METHODS FOR SERVICE CALLS - MAINTAINING API COMPATIBILITY

  /// Subscribe to requests stream (delegates to service)
  static StreamSubscription subscribeToRequests({
    required Function(List<PartRequest>) onData,
    Function(dynamic)? onError,
  }) {
    return RequestService.subscribeToRequests(
      onData: onData,
      onError: onError,
    );
  }

  /// Get requests stream (delegates to service)
  static Stream<List<PartRequest>> getRequestsStream() {
    return RequestService.getRequestsStream();
  }

  /// Refresh requests (delegates to service)
  static Future<List<PartRequest>> refreshRequests() async {
    return await RequestService.refreshRequests();
  }

  /// Get request details by ID (delegates to service)
  static Future<PartRequest?> getRequestById(String requestId) async {
    return await RequestService.getRequestById(requestId);
  }

  /// Get transaction details with related request (delegates to service)
  static Future<Map<String, dynamic>> getTransactionDetails(
      IssueTransaction transaction, {
        List<PartRequest>? localRequests,
      }) async {
    return await RequestService.getTransactionDetails(
      transaction,
      localRequests: localRequests,
    );
  }

  /// Complete issue (delegates to service)
  static Future<void> completeIssue({
    required PartRequest request,
    required int issuedQuantity,
    required String notes,
  }) async {
    return await RequestService.completeIssue(
      request: request,
      issuedQuantity: issuedQuantity,
      notes: notes,
    );
  }

  /// Cancel subscriptions (delegates to service)
  static void cancelSubscriptions() {
    RequestService.cancelSubscriptions();
  }

  // UI UTILITY METHODS

  /// Show error snackbar from anywhere
  static void showErrorSnackBar(BuildContext context, String message) {
    if (message.isEmpty) {
      return; // Guard against empty messages
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F), // Material Design error color
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show success snackbar from anywhere
  static void showSuccessSnackBar(BuildContext context, String message) {
    if (message.isEmpty) {
      return; // Guard against empty messages
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF00DC1E), // Material Design error color
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Returns a map containing status, label, color, and backgroundColor
  static Map<String, dynamic> getStockStatus(int available, int requested) {
    if (available <= 0) {
      return {
        'status': 'out_of_stock',
        'label': 'OUT OF STOCK',
        'color': const Color(0xFFC62828),
        'backgroundColor': const Color(0xFFFFF5F5),
        'canFulfill': false,
        'fulfillableQuantity': 0,
      };
    } else if (available < requested) {
      return {
        'status': 'insufficient',
        'label': 'INSUFFICIENT STOCK',
        'color': const Color(0xFFE65100),
        'backgroundColor': const Color(0xFFFFFBF0),
        'canFulfill': true,
        'fulfillableQuantity': available,
      };
    } else {
      return {
        'status': 'available',
        'label': 'IN STOCK',
        'color': const Color(0xFF2E7D32),
        'backgroundColor': const Color(0xFFF8FFF8),
        'canFulfill': true,
        'fulfillableQuantity': requested,
      };
    }
  }

  /// Gets the appropriate icon for stock status
  static IconData getStockStatusIcon(String status) {
    switch (status) {
      case 'available':
        return Icons.check_circle_outline;
      case 'insufficient':
        return Icons.warning_amber_outlined;
      case 'out_of_stock':
        return Icons.block_outlined;
      default:
        return Icons.info_outline;
    }
  }

  static Map<String, dynamic> getPriorityInfo(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'urgent':
        return {
          'label': 'HIGH PRIORITY',
          'icon': Icons.priority_high,
          'headerColor': const Color(0xFFFFF5F5),
          'statusColor': const Color(0xFFC62828),
          'stockColor': const Color(0xFFD32F2F),
          'priority': 'high',
          'sortOrder': 1,
        };
      case 'medium':
        return {
          'label': 'MEDIUM',
          'icon': Icons.remove,
          'headerColor': const Color(0xFFFFFBF0),
          'statusColor': const Color(0xFFE65100),
          'stockColor': const Color(0xFFFF9800),
          'priority': 'medium',
          'sortOrder': 2,
        };
      case 'low':
        return {
          'label': 'LOW',
          'icon': Icons.keyboard_arrow_down,
          'headerColor': const Color(0xFFF8FFF8),
          'statusColor': const Color(0xFF2E7D32),
          'stockColor': const Color(0xFF4CAF50),
          'priority': 'low',
          'sortOrder': 3,
        };
      default:
        return {
          'label': 'NORMAL',
          'icon': Icons.info_outline,
          'headerColor': const Color(0xFFF8F9FA),
          'statusColor': const Color(0xFF616161),
          'stockColor': const Color(0xFF757575),
          'priority': 'normal',
          'sortOrder': 4,
        };
    }
  }

  static String formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  static Future<void> showRequestDetails(
      BuildContext context,
      PartRequest request,
      ) async {
    // Call your static function to get product details
    final result = await WarehouseDeductionDao.getProductDetailsForPartNumber(
      partNumber: request.partNumber,
    );

    if (!context.mounted) return; // Prevent showing dialog if context is not mounted

    showDialog(
      context: context,
      builder: (context) {
        if (result['success']) {
          final availableProduct = result['product'];
          final totalQuantity = result['totalQuantity'];
          final locationsCount = result['locationsCount'];

          return AlertDialog(
            title: const Text('Request Details'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildDetailRow('Part Number:', request.partNumber),
                  buildDetailRow('Department:', request.department),
                  buildDetailRow('Technician:', request.technician),
                  buildDetailRow('Quantity:', '${request.requestedQuantity}'),
                  buildDetailRow('Priority:', request.priority),
                  buildDetailRow(
                    'Request Date:',
                    RequestDao.formatDateTime(request.requestDate),
                  ),

                  const SizedBox(height: 15),
                  buildDetailRow('Product Name:', availableProduct.productName),
                  buildDetailRow('Price:', 'RM ${availableProduct.price.toStringAsFixed(2)}'),
                  buildDetailRow('Total Quantity:', '$totalQuantity'),
                  buildDetailRow('Stored in Locations:', '$locationsCount'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        } else {
          return AlertDialog(
            title: const Text('Error'),
            content: Text("Failed to load details: ${result['error']}"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        }
      },
    );
  }

  // Helper method for building detail rows
  static Widget buildDetailRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.black, // default black if not provided
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void showRejectDialog(dynamic request, BuildContext context, String currentUser) {
    final TextEditingController reasonController = TextEditingController();
    String? selectedReason;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.cancel_outlined,
                    color: const Color(0xFFC62828),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Reject Request',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Request info summary
                    Container(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildDetailRow('Request ID:', request.requestId),
                          buildDetailRow('Quantity:', '${request.requestedQuantity}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Rejection reason dropdown
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      hint: const Text('Select rejection reason'),
                      items: _getRejectionReasons().map((reason) {
                        return DropdownMenuItem(
                          value: reason,
                          child: Text(reason),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedReason = value;
                          if (value != null && value != 'Other') {
                            reasonController.text = value;
                          } else if (value == 'Other') {
                            reasonController.clear();
                          }
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Reason for Rejection *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.error_outline),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (selectedReason == 'Other') ...[
                      const SizedBox(height: 4),
                      Text(
                        'Please provide a specific reason for rejection',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: reasonController,
                        decoration: InputDecoration(
                          hintText: 'Enter custom reason...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        maxLines: 2, // allow multiple lines if needed
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    // Validation
                    if (selectedReason == null) {
                      showErrorSnackBar(context, 'Please select a rejection reason');
                      return;
                    }

                    if (selectedReason == 'Other' && reasonController.text.trim().isEmpty) {
                      showErrorSnackBar(context, 'Please provide a custom reason');
                      return;
                    }

                    if (reasonController.text.trim().isEmpty && selectedReason != 'Other') {
                      showErrorSnackBar(context, 'Please provide rejection details');
                      return;
                    }

                    setState(() => isLoading = true);

                    try {
                      await RequestService.processRejection(
                        request,
                        selectedReason == 'Other'
                            ? reasonController.text.trim()
                            : '${selectedReason}${reasonController.text.trim().isNotEmpty ? ' - ${reasonController.text.trim()}' : ''}',
                        currentUser ?? "Jacky", // Use provided user or default
                      );

                      Navigator.pop(context);
                      showSuccessSnackBar(context, 'Request rejected successfully');
                    } catch (e) {
                      showErrorSnackBar(context, 'Failed to reject request: $e');
                    } finally {
                      setState(() => isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    foregroundColor: Colors.white,
                  ),
                  child: isLoading
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Reject Request'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}