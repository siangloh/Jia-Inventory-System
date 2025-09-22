// Step 1: Select PO with Expandable Cards and Real-time Search
import 'package:flutter/material.dart';
import 'dart:async';

class SelectPOStep extends StatelessWidget {
  const SelectPOStep({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container();
  }

  static List<Widget> buildSlivers({
    required List<Map<String, dynamic>> purchaseOrders,
    required bool isLoading,
    required String searchQuery,
    required List<String> selectedSuppliers,
    required String selectedTimeFilter,
    required bool isFiltersExpanded,
    required int currentPage,
    required int itemsPerPage,
    required DateTime? startDate,
    required DateTime? endDate,
    required List<String> suppliers,
    required List<String> timeFilters,
    required Function(String) onSearchChanged,
    required Function(List<String>) onSuppliersChanged,
    required Function(String) onTimeFilterChanged,
    required Function() onToggleFilters,
    required Function(int) onPageChanged,
    required Function(DateTimeRange?) onDateRangeChanged,
    required Function(Map<String, dynamic>) onItemSelected,
    required List<Map<String, dynamic>> selectedItems,
    required Function() onClearAllSelection,
    required Function() onSelectAllItems,
    required BuildContext context,
  }) {
    if (isLoading) {
      return [
        SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }


    // Calculate pagination
    final totalPages = (purchaseOrders.length / itemsPerPage).ceil();
    final startIndex = currentPage * itemsPerPage;
    final endIndex = (startIndex + itemsPerPage).clamp(0, purchaseOrders.length);
    final paginatedPOs = purchaseOrders.isEmpty 
        ? <Map<String, dynamic>>[] 
        : purchaseOrders.sublist(startIndex, endIndex);

    List<Widget> slivers = [];

    // Header section
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar with real-time search
              _SearchBarWidget(
                searchQuery: searchQuery,
                onSearchChanged: onSearchChanged,
              ),
              
              const SizedBox(height: 16),

              // Header row
              Row(
                children: [
                  Icon(Icons.inventory_2, color: Colors.red[400], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'All Available Items',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                  if (purchaseOrders.isNotEmpty) ...[
                    TextButton.icon(
                      onPressed: selectedItems.isEmpty 
                          ? onSelectAllItems 
                          : onClearAllSelection,
                      icon: Icon(
                        selectedItems.isEmpty 
                            ? Icons.select_all 
                            : Icons.deselect,
                        size: 18,
                      ),
                      label: Text(
                        selectedItems.isEmpty 
                            ? 'Select All' 
                            : 'Deselect All',
                        style: TextStyle(fontSize: 14),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red[400],
                      ),
                    ),
                  ],
                ],
              ),

              // Filters section
              if (isFiltersExpanded) ...[
                const SizedBox(height: 12),
                _FiltersSection(
                  suppliers: suppliers,
                  selectedSuppliers: selectedSuppliers,
                  selectedTimeFilter: selectedTimeFilter,
                  timeFilters: timeFilters,
                  onSuppliersChanged: onSuppliersChanged,
                  onTimeFilterChanged: onTimeFilterChanged,
                  startDate: startDate,
                  endDate: endDate,
                  onDateRangeChanged: onDateRangeChanged,
                ),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${purchaseOrders.length} POs found',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onToggleFilters,
                    icon: Icon(
                      isFiltersExpanded 
                          ? Icons.keyboard_arrow_up 
                          : Icons.keyboard_arrow_down,
                      size: 18,
                    ),
                    label: Text(
                      isFiltersExpanded ? 'Hide Filters' : 'Show Filters',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red[400],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Pagination at top
    if (totalPages > 1) {
      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: currentPage > 0 
                      ? () => onPageChanged(currentPage - 1) 
                      : null,
                  icon: Icon(Icons.chevron_left),
                  color: currentPage > 0 ? Colors.red[400] : Colors.grey[400],
                ),
                Text(
                  'Page ${currentPage + 1} of $totalPages',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                IconButton(
                  onPressed: currentPage < totalPages - 1
                      ? () => onPageChanged(currentPage + 1)
                      : null,
                  icon: Icon(Icons.chevron_right),
                  color: currentPage < totalPages - 1 
                      ? Colors.red[400] 
                      : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // PO cards with expandable items
    if (paginatedPOs.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No items found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  searchQuery.isNotEmpty
                      ? 'Try adjusting your search'
                      : 'No items available for reporting',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= paginatedPOs.length) return null;
              
              final po = paginatedPOs[index];
              return _ExpandablePOCard(
                po: po,
                onItemSelected: onItemSelected,
                selectedItems: selectedItems,
                searchQuery: searchQuery,
              );
            },
            childCount: paginatedPOs.length,
          ),
        ),
      );
    }

    return slivers;
  }
}

// Real-time search bar widget
class _SearchBarWidget extends StatefulWidget {
  final String searchQuery;
  final Function(String) onSearchChanged;

  const _SearchBarWidget({
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  State<_SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<_SearchBarWidget> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: widget.onSearchChanged,
        decoration: InputDecoration(
                hintText: 'Search by PO number, product name, or supplier...',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.red[400], size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          if (widget.searchQuery.isNotEmpty)
            Container(
              height: 48,
              width: 48,
              child: IconButton(
                icon: Icon(Icons.clear, color: Colors.red[400], size: 20),
                  onPressed: () {
                    _controller.clear();
                    widget.onSearchChanged('');
                    _focusNode.requestFocus();
                  },
              ),
            ),
        ],
      ),
    );
  }
}

// Expandable PO Card
class _ExpandablePOCard extends StatefulWidget {
  final Map<String, dynamic> po;
  final Function(Map<String, dynamic>) onItemSelected;
  final List<Map<String, dynamic>> selectedItems;
  final String searchQuery;

  const _ExpandablePOCard({
    required this.po,
    required this.onItemSelected,
    required this.selectedItems,
    required this.searchQuery,
  });

  @override
  State<_ExpandablePOCard> createState() => _ExpandablePOCardState();
}

class _ExpandablePOCardState extends State<_ExpandablePOCard> {
  bool isExpanded = false;

  @override
  void initState() {
    super.initState();
    // Auto-expand if search query matches items
    if (widget.searchQuery.isNotEmpty) {
      List<dynamic> lineItems = widget.po['lineItems'] ?? [];
      bool hasMatchingItems = lineItems.any((item) {
        String searchLower = widget.searchQuery.toLowerCase();
        return (item['productName'] ?? '').toLowerCase().contains(searchLower) ||
            (item['partNumber'] ?? '').toLowerCase().contains(searchLower) ||
            (item['brand'] ?? '').toLowerCase().contains(searchLower);
      });
      if (hasMatchingItems) {
        isExpanded = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String poNumber = widget.po['poNumber'] ?? '';
    String supplierName = widget.po['supplierName'] ?? '';
    String status = widget.po['status'] ?? '';
    List<dynamic> lineItems = widget.po['lineItems'] ?? [];

    // Get available items
    List<Map<String, dynamic>> availableItems = [];
    for (var item in lineItems) {
      if ((item['availableQuantity'] ?? 0) > 0) {
        availableItems.add({
          'poId': widget.po['id'],
          'poNumber': widget.po['poNumber'],
          'itemId': item['id'] ?? item['productId'],
          'productName': item['productName'] ?? '',
          'partNumber': item['partNumber'] ?? '',
          'brand': item['brand'] ?? '',
          'quantityAvailable': item['availableQuantity'] ?? 0,
          'unitPrice': item['unitPrice'] ?? 0.0,
          'supplierName': widget.po['supplierName'] ?? '',
        });
      }
    }

    Color statusColor = Colors.grey;
    if (status == 'COMPLETED') statusColor = Colors.green;
    else if (status == 'PARTIALLY_RECEIVED') statusColor = Colors.orange;
    else if (status == 'APPROVED') statusColor = Colors.blue;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // PO Header
          InkWell(
            onTap: () {
              setState(() {
                isExpanded = !isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long,
                    color: Colors.red[400],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              poNumber,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: statusColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          supplierName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${availableItems.length} items available',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),

          // Expandable items section
          if (isExpanded) ...[
            Container(
              width: double.infinity,
              height: 1,
              color: Colors.grey[200],
            ),
            Container(
              constraints: BoxConstraints(
                maxHeight: 300,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: availableItems.map((item) {
                    final isItemSelected = widget.selectedItems.any(
                        (selectedItem) =>
                            selectedItem['poId'] == item['poId'] &&
                            selectedItem['itemId'] == item['itemId']);

                    bool isHighlighted = widget.searchQuery.isNotEmpty &&
                        (item['productName'].toLowerCase().contains(widget.searchQuery.toLowerCase()) ||
                         item['partNumber'].toLowerCase().contains(widget.searchQuery.toLowerCase()) ||
                         item['brand'].toLowerCase().contains(widget.searchQuery.toLowerCase()));

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: isItemSelected
                            ? Colors.red[50]
                            : isHighlighted
                                ? Colors.amber[50]
                                : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isItemSelected
                              ? Colors.red[300]!
                              : isHighlighted
                                  ? Colors.amber[300]!
                                  : Colors.grey[200]!,
                          width: isItemSelected || isHighlighted ? 2 : 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => widget.onItemSelected(item),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: isItemSelected
                                      ? Colors.red[400]
                                      : Colors.grey[300],
                                  shape: BoxShape.circle,
                                  border: isItemSelected
                                      ? null
                                      : Border.all(
                                          color: Colors.grey[400]!, width: 1),
                                ),
                                child: isItemSelected
                                    ? Icon(Icons.check,
                                        color: Colors.white, size: 14)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['productName'] ?? 'N/A',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        if (item['partNumber'] != null && item['partNumber'] != 'N/A') ...[
      Text(
                                            'Part: ${item['partNumber']}',
        style: TextStyle(
                                              fontSize: 11,
          color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        if (item['brand'] != null && item['brand'] != 'N/A')
                                          Text(
                                            'Brand: ${item['brand']}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.blue[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (item['sku'] != null && item['sku'] != 'N/A')
                                      Text(
                                        'SKU: ${item['sku']}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[500],
        ),
      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${item['quantityAvailable']} units',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'RM ${(item['unitPrice'] as num).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// Filters Section Widget
class _FiltersSection extends StatefulWidget {
  final List<String> suppliers;
  final List<String> selectedSuppliers;
  final String selectedTimeFilter;
  final List<String> timeFilters;
  final Function(List<String>) onSuppliersChanged;
  final Function(String) onTimeFilterChanged;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTimeRange?) onDateRangeChanged;

  const _FiltersSection({
    required this.suppliers,
    required this.selectedSuppliers,
    required this.selectedTimeFilter,
    required this.timeFilters,
    required this.onSuppliersChanged,
    required this.onTimeFilterChanged,
    required this.startDate,
    required this.endDate,
    required this.onDateRangeChanged,
  });

  @override
  State<_FiltersSection> createState() => _FiltersSectionState();
}

class _FiltersSectionState extends State<_FiltersSection> {
  bool showAllSuppliers = false;

  @override
  Widget build(BuildContext context) {
    // Show only first 5 suppliers unless expanded
    final displayedSuppliers = showAllSuppliers
        ? widget.suppliers
        : widget.suppliers.take(5).toList();
    final hasMoreSuppliers = widget.suppliers.length > 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Supplier filter
        Text(
          'Filter by Supplier',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...displayedSuppliers.map((supplier) {
              bool isSelected = widget.selectedSuppliers.contains(supplier);
              return FilterChip(
                label: Text(
                  supplier,
                  style: TextStyle(fontSize: 12),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  List<String> newSelection = List.from(widget.selectedSuppliers);
                  if (selected) {
                    newSelection.add(supplier);
                  } else {
                    newSelection.remove(supplier);
                  }
                  widget.onSuppliersChanged(newSelection);
                },
                selectedColor: Colors.red[100],
                checkmarkColor: Colors.red[600],
                side: BorderSide(
                  color: isSelected ? Colors.red[400]! : Colors.grey[300]!,
                ),
              );
            }).toList(),
            if (hasMoreSuppliers) 
              ActionChip(
                label: Text(
                  showAllSuppliers 
                      ? 'Show Less' 
                      : 'Show ${widget.suppliers.length - 5} More',
                  style: TextStyle(fontSize: 12),
                ),
                onPressed: () {
                  setState(() {
                    showAllSuppliers = !showAllSuppliers;
                  });
                },
                backgroundColor: Colors.grey[100],
              ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Time filter
        Text(
          'Filter by Date',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.timeFilters.map((filter) {
            bool isSelected = widget.selectedTimeFilter == filter;
            return FilterChip(
              label: Text(
                filter,
                style: TextStyle(fontSize: 12),
              ),
              selected: isSelected,
              onSelected: (selected) {
                widget.onTimeFilterChanged(filter);
                if (filter == 'Custom Date Range') {
                  _showDateRangePicker(context);
                }
              },
              selectedColor: Colors.red[100],
              checkmarkColor: Colors.red[600],
              side: BorderSide(
                color: isSelected ? Colors.red[400]! : Colors.grey[300]!,
              ),
            );
          }).toList(),
        ),
        
        if (widget.selectedTimeFilter == 'Custom Date Range' && 
            widget.startDate != null && 
            widget.endDate != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.date_range, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  '${_formatDate(widget.startDate!)} - ${_formatDate(widget.endDate!)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showDateRangePicker(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: widget.startDate != null && widget.endDate != null
          ? DateTimeRange(start: widget.startDate!, end: widget.endDate!)
          : null,
    );

    if (picked != null) {
      widget.onDateRangeChanged(picked);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}