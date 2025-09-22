// Redesigned PO Details Dialog - Mobile-optimized and responsive
// Better layout for narrow screens with improved UX

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PODetailsDialog extends StatelessWidget {
  final Map<String, dynamic> purchaseOrder;
  final bool isSelected;

  const PODetailsDialog({
    Key? key,
    required this.purchaseOrder,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    
    String poNumber = purchaseOrder['poNumber'] ?? '';
    String supplierName = purchaseOrder['supplierName'] ?? '';
    String status = purchaseOrder['status'] ?? '';
    double totalAmount = (purchaseOrder['totalAmount'] ?? 0).toDouble();
    List<dynamic> lineItems = purchaseOrder['lineItems'] ?? [];
    
    DateTime? createdDate;
    DateTime? expectedDate;
    
    try {
      var createdValue = purchaseOrder['createdDate'];
      if (createdValue is Timestamp) {
        createdDate = createdValue.toDate();
      }
      
      var expectedValue = purchaseOrder['expectedDeliveryDate'];
      if (expectedValue is Timestamp) {
        expectedDate = expectedValue.toDate();
      }
    } catch (e) {
      // Handle date parsing error
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isTablet ? 500 : screenSize.width * 0.95,
          maxHeight: screenSize.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Compact Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[600]!, Colors.blue[800]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt_long, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poNumber,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          supplierName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusColor(status)),
                    ),
                    child: Text(
                      _getStatusDisplayName(status),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Stats Row
                    _buildQuickStats(totalAmount, lineItems),
                    
                    const SizedBox(height: 16),
                    
                    // Basic Info Card
                    _buildInfoCard(
                      'Purchase Order Information',
                      Icons.info_outline,
                      Colors.blue,
                      [
                        _buildCompactInfoRow('Created', _formatDate(createdDate)),
                        _buildCompactInfoRow('Expected Delivery', _formatDate(expectedDate)),
                        _buildCompactInfoRow('Total Amount', 'RM ${totalAmount.toStringAsFixed(2)}'),
                        _buildCompactInfoRow('Items', '${lineItems.length} item${lineItems.length != 1 ? 's' : ''}'),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Line Items Section
                    _buildLineItemsSection(lineItems),
                  ],
                ),
              ),
            ),
            
            // Bottom Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected ? Colors.orange[600] : Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(isSelected ? 'Unselect' : 'Select PO'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build quick stats row
  Widget _buildQuickStats(double totalAmount, List<dynamic> lineItems) {
    int totalOrdered = 0;
    int totalReceived = 0;
    int totalDamaged = 0;
    
    for (var item in lineItems) {
      totalOrdered += (item['quantityOrdered'] ?? 0) as int;
      totalReceived += (item['quantityReceived'] ?? 0) as int;
      totalDamaged += (item['quantityDamaged'] ?? 0) as int;
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Expanded(child: _buildStatItem('RM ${totalAmount.toStringAsFixed(2)}', 'Total', Colors.green)),
          Expanded(child: _buildStatItem('$totalOrdered', 'Ordered', Colors.blue)),
          Expanded(child: _buildStatItem('$totalReceived', 'Received', Colors.green)),
          Expanded(child: _buildStatItem('$totalDamaged', 'Damaged', Colors.red)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Build info card
  Widget _buildInfoCard(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          // Card content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  // Build compact info row
  Widget _buildCompactInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build line items section
  Widget _buildLineItemsSection(List<dynamic> lineItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: Colors.orange, size: 18),
            const SizedBox(width: 8),
            Text(
              'Line Items (${lineItems.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...lineItems.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> item = entry.value;
          return _buildCompactLineItemCard(index + 1, item);
        }).toList(),
      ],
    );
  }

  // Build compact line item card
  Widget _buildCompactLineItemCard(int index, Map<String, dynamic> item) {
    String productName = item['productName'] ?? '';
    String brand = item['brand'] ?? '';
    String partNumber = item['partNumber'] ?? '';
    int orderedQty = item['quantityOrdered'] ?? 0;
    int receivedQty = item['quantityReceived'] ?? 0;
    int damagedQty = item['quantityDamaged'] ?? 0;
    double unitPrice = (item['unitPrice'] ?? 0).toDouble();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item header
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (brand.isNotEmpty || partNumber.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (brand.isNotEmpty) 'Brand: $brand',
                          if (partNumber.isNotEmpty) 'Part: $partNumber',
                        ].join(' • '),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                'RM ${unitPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Quantity chips
          Row(
            children: [
              _buildQuantityChip('Ord: $orderedQty', Colors.blue),
              const SizedBox(width: 6),
              _buildQuantityChip('Rec: $receivedQty', Colors.green),
              const SizedBox(width: 6),
              _buildQuantityChip('Dmg: $damagedQty', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return Colors.blue;
      case 'PARTIALLY_RECEIVED':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.green;
      case 'READY':
        return Colors.teal;
      case 'PENDING_APPROVAL':
        return Colors.amber;
      case 'REJECTED':
        return Colors.red;
      case 'CANCELLED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'APPROVED':
        return 'Approved';
      case 'PARTIALLY_RECEIVED':
        return 'Partial';
      case 'COMPLETED':
        return 'Complete';
      case 'READY':
        return 'Ready';
      case 'PENDING_APPROVAL':
        return 'Pending';
      case 'REJECTED':
        return 'Rejected';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    return '${date.day}/${date.month}/${date.year}';
  }
}