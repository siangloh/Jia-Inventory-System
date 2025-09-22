import 'package:flutter/material.dart';
import 'dart:io';

class ReviewSubmitStep {
  static List<Widget> buildSlivers({
    required List<Map<String, dynamic>> selectedItems,
    required Map<String, Map<String, dynamic>> itemDetails,
    required String returnType,
    required String returnMethod,
    required String carrierName,
    required String trackingNumber,
    required Map<String, dynamic> pickupDetails,
    required Map<String, dynamic> shipmentDetails,
    required List<File> returnDocuments,
    required bool isSubmitting,
    required BuildContext context,
  }) {
    List<Widget> slivers = [];
    
    // Header
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[400]!, Colors.green[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.fact_check, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Review Return',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Verify all details before submission',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    // Return summary card
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Return Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildSummaryRow('Return Type', _formatReturnType(returnType), Colors.blue),
              _buildSummaryRow('Total Items', selectedItems.length.toString(), Colors.orange),
              _buildSummaryRow('Total Quantity', _calculateTotalQuantity(itemDetails, selectedItems).toString(), Colors.purple),
              _buildSummaryRow('Return Method', _formatReturnMethod(returnMethod), Colors.green),
              if (carrierName.isNotEmpty)
                _buildSummaryRow('Carrier', carrierName, Colors.teal),
              if (trackingNumber.isNotEmpty)
                _buildSummaryRow('Tracking', trackingNumber, Colors.indigo),
              _buildSummaryRow('Documents', '${returnDocuments.length} files', Colors.brown),
            ],
          ),
        ),
      ),
    );
    
    // Items review
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Items to Return',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
    
    slivers.add(
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = selectedItems[index];
              final itemId = item['id'] ?? item['productId'] ?? '';
              final details = itemDetails[itemId] ?? {};
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ItemReviewCard(
                  item: item,
                  details: details,
                ),
              );
            },
            childCount: selectedItems.length,
          ),
        ),
      ),
    );
    
    // Logistics review
    if (returnMethod.isNotEmpty)
      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_shipping, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Logistics Information',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._buildLogisticsDetails(
                  returnMethod,
                  pickupDetails,
                  shipmentDetails,
                ),
              ],
            ),
          ),
        ),
      );
    
    // Checklist
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.checklist, color: Colors.green[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Pre-submission Checklist',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ChecklistItem('All items selected', true),
              _ChecklistItem('Quantities verified', itemDetails.isNotEmpty),
              _ChecklistItem('Return reasons specified', _allReasonsSpecified(itemDetails)),
              _ChecklistItem('Logistics configured', returnMethod.isNotEmpty),
              _ChecklistItem('Documents uploaded', returnDocuments.isNotEmpty),
            ],
          ),
        ),
      ),
    );
    
    return slivers;
  }
  
  static Widget _buildSummaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const Spacer(),
          Text(
            value.isNotEmpty ? value : 'N/A',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  static int _calculateTotalQuantity(Map<String, Map<String, dynamic>> details, List<Map<String, dynamic>> items) {
    int total = 0;
    for (var item in items) {
      final itemId = item['id'] ?? item['productId'] ?? '';
      final detailsMap = details[itemId];
      if (detailsMap != null && detailsMap['quantity'] != null) {
        final quantity = detailsMap['quantity'];
        total += quantity is int ? quantity : int.tryParse(quantity.toString()) ?? 0;
      }
    }
    return total;
  }
  
  static String _formatReturnType(String type) {
    switch (type) {
      case 'SUPPLIER_RETURN':
        return 'Supplier Return';
      case 'INTERNAL_RETURN':
        return 'Internal Return';
      case 'MIXED_RETURN':
        return 'Mixed Return';
      default:
        return type.isNotEmpty ? type : 'Not Selected';
    }
  }
  
  static String _formatReturnMethod(String? method) {
    if (method == null || method.isEmpty) return 'Not Selected';
    switch (method) {
      case 'PICKUP':
        return 'Supplier Pickup';
      case 'SHIP':
        return 'Ship to Supplier';
      case 'DROP_OFF':
        return 'Drop Off';
      default:
        return method;
    }
  }
  
  static List<Widget> _buildLogisticsDetails(
    String? method,
    Map<String, dynamic>? pickupDetails,
    Map<String, dynamic>? shipmentDetails,
  ) {
    if (method == null || method.isEmpty) {
      return [
        Text(
          'No logistics information available',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
      ];
    }
    
    switch (method) {
      case 'PICKUP':
        return [
          Text('Date: ${_formatDate(pickupDetails?['date'])}', style: TextStyle(fontSize: 13)),
          Text('Time: ${pickupDetails?['timeSlot'] ?? 'Not set'}', style: TextStyle(fontSize: 13)),
          Text('Address: ${pickupDetails?['address'] ?? 'Not set'}', style: TextStyle(fontSize: 13)),
        ];
      case 'SHIP':
        return [
          Text('Address: ${shipmentDetails?['address'] ?? 'Not set'}', style: TextStyle(fontSize: 13)),
        ];
      case 'DROP_OFF':
        return [
          Text('Location: ${shipmentDetails?['location'] ?? 'Not set'}', style: TextStyle(fontSize: 13)),
        ];
      default:
        return [
          Text('Method: $method', style: TextStyle(fontSize: 13)),
        ];
    }
  }
  
  static String _formatDate(dynamic date) {
    if (date == null) return 'Not set';
    if (date is DateTime) {
      return '${date.day}/${date.month}/${date.year}';
    }
    return date.toString();
  }
  
  static bool _allReasonsSpecified(Map<String, Map<String, dynamic>> details) {
    if (details.isEmpty) return false;
    
    for (var detail in details.values) {
      if (detail == null) return false;
      final reason = detail['reason'];
      if (reason == null || reason.toString().isEmpty) {
        return false;
      }
    }
    return true;
  }
}

class _ItemReviewCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Map<String, dynamic> details;
  
  const _ItemReviewCard({
    required this.item,
    required this.details,
  });
  
  String _getProductName() {
    // Try direct productName
    if (item['productName'] != null && item['productName'].toString().isNotEmpty) {
      return item['productName'];
    }
    
    // Try from nested items
    if (item['items'] != null && item['items'] is List) {
      final items = item['items'] as List;
      if (items.isNotEmpty && items[0]['productName'] != null) {
        return items[0]['productName'];
      }
    }
    
    // Fallback
    return item['partName'] ?? 'Unknown Product';
  }
  
  String _getSku() {
    // Try direct SKU fields
    if (item['sku'] != null && item['sku'].toString().isNotEmpty) {
      return item['sku'];
    }
    if (item['productSKU'] != null && item['productSKU'].toString().isNotEmpty) {
      return item['productSKU'];
    }
    
    // Try from nested items
    if (item['items'] != null && item['items'] is List) {
      final items = item['items'] as List;
      if (items.isNotEmpty) {
        return items[0]['sku'] ?? items[0]['partNumber'] ?? 'N/A';
      }
    }
    
    return item['partNumber'] ?? 'N/A';
  }
  
  @override
  Widget build(BuildContext context) {
    final productName = _getProductName();
    final sku = _getSku();
    final quantity = details['quantity'] ?? 0;
    final reason = details['reason']?.toString() ?? 'Not specified';
    final notes = details['notes']?.toString() ?? '';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$quantity pcs',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'SKU: $sku',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Reason: $reason',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Notes: $notes',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final String label;
  final bool isChecked;
  
  const _ChecklistItem(this.label, this.isChecked);
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: isChecked ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isChecked ? Colors.green[700] : Colors.grey[600],
              decoration: isChecked ? TextDecoration.none : TextDecoration.lineThrough,
            ),
          ),
        ],
      ),
    );
  }
}