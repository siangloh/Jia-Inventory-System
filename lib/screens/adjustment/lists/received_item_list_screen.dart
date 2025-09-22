// received_item_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/adjustment/expandable_card.dart';
import '../../../services/adjustment/inventory_service.dart';
import '../../../services/adjustment/snackbar_manager.dart';
import '../../../services/adjustment/pdf_receipt_service.dart';
import '../../../services/adjustment/pdf_viewer_screen.dart';

class ReceivedItemsListScreen extends StatefulWidget {
  const ReceivedItemsListScreen({Key? key}) : super(key: key);

  @override
  State<ReceivedItemsListScreen> createState() => _ReceivedItemsListScreenState();
}

class _ReceivedItemsListScreenState extends State<ReceivedItemsListScreen> {
  
  final InventoryService _inventoryService = InventoryService();
  
  // REAL-TIME: Stream subscription for automatic updates
  late Stream<List<Map<String, dynamic>>> _ordersStream;
  
  // Additional filters specific to received items
  String selectedStatus = 'All';
  String selectedSupplier = 'All';
  Set<String> suppliers = {'All'};
  
  // Search and pagination
  String searchQuery = '';
  int currentPage = 0;
  final int itemsPerPage = 10;
  
  // Processing state
  bool isLoading = true;
  List<Map<String, dynamic>> allItems = [];
  List<Map<String, dynamic>> filteredItems = [];
  List<Map<String, dynamic>> displayedItems = [];
  
  // Expanded cards
  Set<String> expandedCards = {};
  

  @override
  void initState() {
    super.initState();
    _initializeRealTimeUpdates();
  }

  // REAL-TIME: Initialize stream for automatic updates
  void _initializeRealTimeUpdates() {
    _ordersStream = _inventoryService.getPurchaseOrdersWithReceivedItemsStream();
    
    // Listen to stream and update UI automatically
    _ordersStream.listen(
      (orders) {
        if (mounted) {
          setState(() {
            allItems = orders;
            isLoading = false;
            
            // Extract unique suppliers for filtering
            final supplierSet = <String>{'All'};
            for (final order in orders) {
              final supplierName = order['supplierName'] ?? '';
              if (supplierName.isNotEmpty) supplierSet.add(supplierName);
            }
            suppliers = supplierSet;
          });
          
          _applyFiltersAndSort();
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => isLoading = false);
          SnackbarManager().showErrorMessage(
            context,
            message: 'Error loading orders: $error',
          );
        }
      },
    );
  }

  // CONSOLIDATED: Single filter and sort method
  void _applyFiltersAndSort() {
    List<Map<String, dynamic>> filtered = List.from(allItems);
    
    // Apply search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        final searchLower = searchQuery.toLowerCase();
        final searchText = [
          item['poNumber'] ?? '',
          item['supplierName'] ?? '',
          item['createdByUserName'] ?? '',
        ].join(' ').toLowerCase();
        return searchText.contains(searchLower);
      }).toList();
    }
    
    // Apply status filter
    if (selectedStatus != 'All') {
      filtered = filtered.where((item) => item['status'] == selectedStatus).toList();
    }
    
    // Apply supplier filter
    if (selectedSupplier != 'All') {
      filtered = filtered.where((item) => item['supplierName'] == selectedSupplier).toList();
    }
    
    // Sort by creation date (newest first)
    filtered.sort((a, b) {
      final aDate = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1900);
      final bDate = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1900);
      return bDate.compareTo(aDate);
    });
    
    if (mounted) {
      setState(() {
        filteredItems = filtered;
        currentPage = 0;
        _updateDisplayedItems();
      });
    }
  }

  // CONSOLIDATED: Update displayed items with pagination
  void _updateDisplayedItems() {
    final startIndex = currentPage * itemsPerPage;
    final endIndex = (startIndex + itemsPerPage).clamp(0, filteredItems.length);
    
    if (startIndex >= filteredItems.length) {
      displayedItems = [];
    } else {
      displayedItems = filteredItems.sublist(startIndex, endIndex);
    }
  }

  // CONSOLIDATED: Calculate statistics
  Map<String, dynamic> _calculateStats() {
    int totalOrders = filteredItems.length;
    int totalItemsReceived = 0;
    int totalItemsOrdered = 0;
    double totalValue = 0.0;
    
    for (final order in filteredItems) {
      final lineItems = List<dynamic>.from(order['lineItems'] ?? []);
      for (final item in lineItems) {
        final received = (item['quantityReceived'] ?? 0) as int;
        final ordered = (item['quantityOrdered'] ?? 0) as int;
        final unitPrice = ((item['unitPrice'] ?? 0.0) as num).toDouble();
        
        totalItemsReceived += received;
        totalItemsOrdered += ordered;
        totalValue += (received * unitPrice);
      }
    }
    
    int remainingItems = (totalItemsOrdered - totalItemsReceived).clamp(0, totalItemsOrdered);
    
    return {
      'Orders': totalOrders,
      'Received': totalItemsReceived,
      'Remaining': remainingItems,
      'Value': 'RM ${totalValue.toStringAsFixed(0)}',
    };
  }

  // NEW: Generate and open PDF for individual purchase order
  Future<void> _generateAndOpenPDF(Map<String, dynamic> purchaseOrder) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Generating Receipt PDF...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait while we prepare your document',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );

      // Generate PDF bytes for this single purchase order
      final pdfBytes = await PDFReceiptService.generateReceivingReceiptBytes(
        purchaseOrders: [purchaseOrder], // Pass as single-item list
        generatedBy: 'Current User',
        workshopName: 'JiaCar Workshop',
        workshopAddress: 'Default Workshop Address',
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (pdfBytes != null) {
        // Navigate to PDF viewer
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PDFViewerScreen(
                pdfBytes: pdfBytes,
                title: 'Receipt - ${purchaseOrder['poNumber'] ?? 'Unknown PO'}',
              ),
            ),
          );
        }
      } else {
        SnackbarManager().showErrorMessage(
          context,
          message: 'Failed to generate PDF receipt',
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.pop(context);

      SnackbarManager().showErrorMessage(
        context,
        message: 'Error generating PDF: ${e.toString()}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    
    final stats = _calculateStats();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(),
          _buildStatsBar(stats),
          _buildFilterSection(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Received Items',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'View all received inventory items',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // REAL-TIME: Show live indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Search bar
            TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
                _applyFiltersAndSort();
              },
              decoration: InputDecoration(
                hintText: 'Search orders...',
                prefixIcon: Icon(Icons.search, size: 20),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 20),
                        onPressed: () {
                          setState(() {
                            searchQuery = '';
                          });
                          _applyFiltersAndSort();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(
          bottom: BorderSide(color: Colors.blue[200]!),
        ),
      ),
      child: Row(
        children: stats.entries.map((entry) {
          return Expanded(
            child: Column(
              children: [
                Text(
                  entry.value.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterSection() {
    final totalPages = (filteredItems.length / itemsPerPage).ceil();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        children: [
          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Status filter
                Container(
                  margin: EdgeInsets.only(right: 8),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedStatus,
                      items: ['All', 'READY', 'APPROVED', 'PARTIALLY_RECEIVED', 'COMPLETED']
                          .map((status) => DropdownMenuItem(
                                value: status,
                                child: Text(
                                  status == 'All' ? 'All Status' : _getStatusDisplayName(status),
                                  style: TextStyle(fontSize: 13),
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => selectedStatus = value!);
                        _applyFiltersAndSort();
                      },
                      isDense: true,
                    ),
                  ),
                ),
                
                // Supplier filter
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedSupplier,
                      items: suppliers
                          .map((supplier) => DropdownMenuItem(
                                value: supplier,
                                child: Text(
                                  supplier == 'All' ? 'All Suppliers' : supplier,
                                  style: TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => selectedSupplier = value!);
                        _applyFiltersAndSort();
                      },
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Pagination
          if (totalPages > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Page ${currentPage + 1} of $totalPages',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: currentPage > 0 ? () {
                        setState(() => currentPage--);
                        _updateDisplayedItems();
                      } : null,
                      icon: Icon(Icons.chevron_left),
                      iconSize: 20,
                    ),
                    IconButton(
                      onPressed: currentPage < totalPages - 1 ? () {
                        setState(() => currentPage++);
                        _updateDisplayedItems();
                      } : null,
                      icon: Icon(Icons.chevron_right),
                      iconSize: 20,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (displayedItems.isEmpty) {
      return _buildEmptyState();
    }
    
    // REAL-TIME: StreamBuilder is not needed since we handle stream in initState
    return RefreshIndicator(
      onRefresh: () async {
        // Manual refresh triggers a new stream listen
        _initializeRealTimeUpdates();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: displayedItems.length,
        itemBuilder: (context, index) {
          final item = displayedItems[index];
          final itemId = item['id'] ?? '';
          final isExpanded = expandedCards.contains(itemId);
          
          return _buildCard(item, itemId, isExpanded);
        },
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item, String itemId, bool isExpanded) {
    final status = item['status'] ?? '';
    final statusColor = _getStatusColor(status);
    final statusDisplayName = _getStatusDisplayName(status);
    
    return ExpandableCard(
      id: itemId,
      isExpanded: isExpanded,
      onToggleExpand: () {
        setState(() {
          if (expandedCards.contains(itemId)) {
            expandedCards.remove(itemId);
          } else {
            expandedCards.add(itemId);
          }
        });
      },
      statusColor: statusColor,
      statusText: statusDisplayName,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['poNumber'] ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['supplierName'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // NEW: PDF Icon Button
              Container(
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: IconButton(
                  onPressed: () => _generateAndOpenPDF(item),
                  icon: Icon(
                    Icons.picture_as_pdf,
                    color: Colors.red[600],
                    size: 20,
                  ),
                  tooltip: 'View Receipt PDF',
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      content: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey[50]!, Colors.grey[100]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildEnhancedInfoChip(
                    Icons.inventory_2,
                    'Items',
                    '${_getTotalItems(item)}',
                    Colors.blue,
                    Colors.blue[50]!,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildEnhancedInfoChip(
                    Icons.attach_money,
                    'Amount',
                    'RM ${((item['totalAmount'] ?? 0.0) as num).toStringAsFixed(0)}',
                    Colors.green,
                    Colors.green[50]!,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildEnhancedInfoChip(
                    Icons.calendar_today,
                    'Date',
                    _formatDate(item['createdAt']),
                    Colors.orange,
                    Colors.orange[50]!,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Progress indicator
          _buildProgressIndicator(item),
        ],
      ),
      expandedContent: _buildExpandedDetails(item),
    );
  }

  Widget _buildExpandedDetails(Map<String, dynamic> item) {
    final lineItems = List<dynamic>.from(item['lineItems'] ?? []);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Line Items',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        ...lineItems.map((lineItem) => _buildLineItemDetail(lineItem)),
      ],
    );
  }

  Widget _buildLineItemDetail(Map<String, dynamic> lineItem) {
    final received = lineItem['quantityReceived'] ?? 0;
    final ordered = lineItem['quantityOrdered'] ?? 0;
    final progress = ordered > 0 ? received / ordered : 0.0;
    
    String productName = lineItem['displayName'] ?? lineItem['productName'] ?? 'Unknown Product';
    String brandName = lineItem['brandName'] ?? lineItem['brand'] ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (brandName.isNotEmpty && brandName != 'N/A')
                      Text(
                        'Brand: $brandName',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '$received / $ordered',
                style: TextStyle(
                  color: received >= ordered ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                received >= ordered ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No received items found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            searchQuery.isNotEmpty 
                ? 'Try adjusting your search or filters'
                : 'No received items available',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // CONSOLIDATED: Helper methods
  int _getTotalItems(Map<String, dynamic> order) {
    final lineItems = List<dynamic>.from(order['lineItems'] ?? []);
    return lineItems.fold(0, (sum, item) => 
      sum + ((item['quantityReceived'] ?? 0) as int));
  }

  Widget _buildEnhancedInfoChip(IconData icon, String label, String value, Color color, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(Map<String, dynamic> order) {
    final lineItems = List<dynamic>.from(order['lineItems'] ?? []);
    int totalOrdered = 0;
    int totalReceived = 0;
    final status = order['status'] ?? '';
    
    for (final item in lineItems) {
      totalOrdered += (item['quantityOrdered'] ?? 0) as int;
      totalReceived += (item['quantityReceived'] ?? 0) as int;
    }
    
    double progress;
    if (status == 'READY' || status == 'COMPLETED') {
      progress = 1.0;
      totalReceived = totalOrdered;
    } else {
      progress = totalOrdered > 0 ? totalReceived / totalOrdered : 0.0;
    }
    
    final statusColor = _getStatusColor(status);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                '${totalReceived}/${totalOrdered} items',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toInt()}% complete',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else {
      return '';
    }
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }
    
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'READY':
        return Colors.pink;
      case 'APPROVED':
        return Colors.blue;
      case 'PARTIALLY_RECEIVED':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'READY':
        return 'Ready for Inventory';
      case 'APPROVED':
        return 'Approved';
      case 'PARTIALLY_RECEIVED':
        return 'Partially Received';
      case 'COMPLETED':
        return 'Completed';
      default:
        return status;
    }
  }
}