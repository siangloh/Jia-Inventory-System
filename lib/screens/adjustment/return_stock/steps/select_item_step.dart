import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SelectDamagedItemsStep {
  static List<Widget> buildSlivers({
    required List<Map<String, dynamic>> damagedItems,
    required List<Map<String, dynamic>> selectedItems,
    required bool isLoading,
    required String searchQuery,
    required List<String> selectedSuppliers,
    required String timeFilter,
    required int currentPage,
    required int itemsPerPage,
    required String returnType,
    required Function(String) onSearchChanged,
    required Function(Map<String, dynamic>) onItemToggled,
    required Function(List<String>) onSuppliersChanged,
    required Function(String) onTimeFilterChanged,
    required Function(int) onPageChanged,
    required Function() onSelectAll,
    required Function() onClearAll,
    required BuildContext context,
  }) {

    List<Widget> slivers = [];

    // Header with search
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and auto-detected type
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Items for Return',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (returnType.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: returnType == 'SUPPLIER_RETURN' 
                                ? Colors.red[100] 
                                : Colors.blue[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              returnType == 'SUPPLIER_RETURN' 
                                ? 'Supplier Return' 
                                : 'Internal Return',
                              style: TextStyle(
                                fontSize: 12,
                                color: returnType == 'SUPPLIER_RETURN' 
                                  ? Colors.red[700] 
                                  : Colors.blue[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Quick actions
                  if (damagedItems.isNotEmpty) ...[
                    TextButton.icon(
                      onPressed: onSelectAll,
                      icon: Icon(Icons.select_all, size: 18),
                      label: Text('Select All'),
                    ),
                    if (selectedItems.isNotEmpty)
                      TextButton.icon(
                        onPressed: onClearAll,
                        icon: Icon(Icons.clear, size: 18),
                        label: Text('Clear'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                  ],
                ],
              ),
              
              SizedBox(height: 16),
              
              // Search bar
              TextField(
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search by product name, SKU, or discrepancy ID...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              
              SizedBox(height: 12),
              
              // Filters row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Time filter
                    FilterChip(
                      label: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16),
                          SizedBox(width: 4),
                          Text(timeFilter),
                        ],
                      ),
                      selected: timeFilter != 'All Time',
                      onSelected: (_) => _showTimeFilterDialog(context, timeFilter, onTimeFilterChanged),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Loading state
    if (isLoading) {
      slivers.add(
        SliverFillRemaining(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
      return slivers;
    }

    // Empty state
    if (damagedItems.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'No Items Found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'No damaged items found for return processing',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
      return slivers;
    }

    // Paginated items
    final startIndex = currentPage * itemsPerPage;
    final endIndex = (startIndex + itemsPerPage).clamp(0, damagedItems.length);
    final paginatedItems = damagedItems.sublist(startIndex, endIndex);

    // Items list
    slivers.add(
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = paginatedItems[index];
              final isSelected = selectedItems.any((selected) =>
                (selected['id'] ?? selected['productId']) == 
                (item['id'] ?? item['productId'])
              );

              return Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: _DamagedItemCard(
                  item: item,
                  isSelected: isSelected,
                  onToggle: () => onItemToggled(item),
                ),
              );
            },
            childCount: paginatedItems.length,
          ),
        ),
      ),
    );

    // Pagination
    if (damagedItems.length > itemsPerPage) {
      final totalPages = (damagedItems.length / itemsPerPage).ceil();
      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Page ${currentPage + 1} of $totalPages'),
                Row(
                  children: [
                    IconButton(
                      onPressed: currentPage > 0 
                        ? () => onPageChanged(currentPage - 1)
                        : null,
                      icon: Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      onPressed: currentPage < totalPages - 1
                        ? () => onPageChanged(currentPage + 1)
                        : null,
                      icon: Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  static void _showTimeFilterDialog(
    BuildContext context, 
    String current, 
    Function(String) onChanged
  ) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select Time Period'),
        children: [
          'All Time',
          'Last 7 Days', 
          'This Month',
          'Custom Date Range'
        ].map((filter) => SimpleDialogOption(
          child: Row(
            children: [
              Radio<String>(
                value: filter,
                groupValue: current,
                onChanged: (value) {
                  Navigator.pop(context);
                  if (value != null) onChanged(value);
                },
              ),
              Text(filter),
            ],
          ),
          onPressed: () {
            Navigator.pop(context);
            onChanged(filter);
          },
        )).toList(),
      ),
    );
  }

}

class _DamagedItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isSelected;
  final VoidCallback onToggle;

  const _DamagedItemCard({
    required this.item,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final returnStatus = item['returnStatus']?.toString();
    
    // ENHANCED: Determine the actual status to display
    String displayStatus;
    Color statusColor;
    IconData statusIcon;
    
    if (returnStatus == 'PENDING') {
      displayStatus = 'In Return Process';
      statusColor = Colors.orange;
      statusIcon = Icons.assignment_return;
    } else if (returnStatus == 'COMPLETED') {
      displayStatus = 'Returned';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (returnStatus == 'CANCELLED') {
      displayStatus = 'Return Cancelled';
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    } else {
      displayStatus = 'Damaged';
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
    }
    
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? statusColor.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? statusColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Checkbox indicator
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? statusColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? statusColor : Colors.grey[400]!,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: isSelected
                    ? Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
                ),
                
                SizedBox(width: 12),
                
                // Product info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getProductName(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Brand: ${item['brandName'] ?? item['brand'] ?? 'Unknown Brand'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Quantity badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${item['quantityAffected'] ?? 0} pcs',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Enhanced details section
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status row
                  Row(
                    children: [
                      _buildInfoChip(
                        statusIcon,
                        displayStatus,
                        statusColor,
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 8),
                  
                  // PO and supplier info
                  Row(
                    children: [
                      _buildInfoChip(
                        Icons.business,
                        item['supplierName'] ?? 'Unknown',
                        Colors.blue,
                      ),
                      SizedBox(width: 8),
                      _buildInfoChip(
                        Icons.receipt,
                        'PO: ${item['poNumber'] ?? 'N/A'}',
                        Colors.grey,
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 8),
                  
                  // Date info
                  Row(
                    children: [
                      _buildInfoChip(
                        Icons.calendar_today,
                        _formatDate(item['reportedAt']),
                        Colors.grey,
                      ),
                      if (returnStatus == 'PENDING' && item['returnDate'] != null) ...[
                        SizedBox(width: 8),
                        _buildInfoChip(
                          Icons.assignment_return,
                          'Return: ${_formatDate(item['returnDate'])}',
                          Colors.orange,
                        ),
                      ],
                    ],
                  ),
                  
                  if (item['description'] != null) ...[
                    SizedBox(height: 8),
                    Text(
                      item['description'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }



  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      if (date is Timestamp) {
        final dateTime = date.toDate();
        final now = DateTime.now();
        final difference = now.difference(dateTime);
        
        if (difference.inDays == 0) {
          return 'Today';
        } else if (difference.inDays == 1) {
          return 'Yesterday';
        } else if (difference.inDays < 7) {
          return '${difference.inDays} days ago';
        } else {
          return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
        }
      }
      return 'Recent';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getProductName() {
    if (item['productName'] != null && 
        item['productName'].toString().isNotEmpty && 
        item['productName'] != 'Unknown Product') {
      return item['productName'];
    }
    
    if (item['items'] != null && item['items'] is List) {
      final items = item['items'] as List;
      if (items.isNotEmpty && items[0]['productName'] != null) {
        return items[0]['productName'];
      }
    }
    
    return item['partName'] ?? 'Unknown Product';
  }
}