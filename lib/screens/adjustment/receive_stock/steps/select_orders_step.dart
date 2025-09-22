import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SelectOrdersStep extends StatelessWidget {
  final List<Map<String, dynamic>> purchaseOrders;
  final List<Map<String, dynamic>> selectedPurchaseOrders;
  final bool isLoading;
  final String searchQuery;
  final List<String> selectedSuppliers;
  final String selectedTimeFilter;
  final bool isFiltersExpanded;
  final int currentPage;
  final int itemsPerPage;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> suppliers;
  final List<String> timeFilters;

  final Function(String) onSearchChanged;
  final Function(List<String>) onSuppliersChanged;
  final Function(String) onTimeFilterChanged;
  final Function() onToggleFilters;
  final Function(int) onPageChanged;
  final Function(DateTimeRange?) onDateRangeChanged;
  final Function(Map<String, dynamic>) onToggleSelection;
  final Function(Map<String, dynamic>) onShowDetails;
  final Function() onClearAllSelection;
  final Function() onSelectAllPurchaseOrders;
  final Function() onProceedToNextStep;

  const SelectOrdersStep({
    Key? key,
    required this.purchaseOrders,
    required this.selectedPurchaseOrders,
    required this.isLoading,
    required this.searchQuery,
    required this.selectedSuppliers,
    required this.selectedTimeFilter,
    required this.isFiltersExpanded,
    required this.currentPage,
    required this.itemsPerPage,
    required this.startDate,
    required this.endDate,
    required this.suppliers,
    required this.timeFilters,
    required this.onSearchChanged,
    required this.onSuppliersChanged,
    required this.onTimeFilterChanged,
    required this.onToggleFilters,
    required this.onPageChanged,
    required this.onDateRangeChanged,
    required this.onToggleSelection,
    required this.onShowDetails,
    required this.onClearAllSelection,
    required this.onSelectAllPurchaseOrders,
    required this.onProceedToNextStep,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container();
  }

  static List<Widget> buildSlivers({
    required List<Map<String, dynamic>> purchaseOrders,
    required List<Map<String, dynamic>> selectedPurchaseOrders,
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
    required Function(Map<String, dynamic>) onToggleSelection,
    required Function(Map<String, dynamic>) onShowDetails,
    required Function() onClearAllSelection,
    required Function() onSelectAllPurchaseOrders,
    required Function() onProceedToNextStep,
    required BuildContext context,
  }) {
    if (isLoading) {
      return [
        SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    // Helper functions
    List<Map<String, dynamic>> getFilteredPurchaseOrders() {
      return purchaseOrders.where((po) {
        bool matchesSearch = searchQuery.isEmpty ||
            (po['poNumber']?.toString() ?? '')
                .toLowerCase()
                .contains(searchQuery.toLowerCase()) ||
            (po['supplierName']?.toString() ?? '')
                .toLowerCase()
                .contains(searchQuery.toLowerCase());

        bool matchesSupplier = selectedSuppliers.isEmpty ||
            selectedSuppliers.contains(po['supplierName']?.toString() ?? '');

        bool matchesStatus = ['APPROVED', 'PARTIALLY_RECEIVED']
            .contains(po['status']?.toString() ?? '');

        bool matchesDate = true;

        // Handle different time filters
        if (selectedTimeFilter == 'Custom Date Range' &&
            startDate != null &&
            endDate != null) {
          try {
            var dateValue = po['expectedDeliveryDate'];
            if (dateValue is Timestamp) {
              DateTime poDate = dateValue.toDate();
              matchesDate =
                  poDate.isAfter(startDate.subtract(Duration(days: 1))) &&
                      poDate.isBefore(endDate.add(Duration(days: 1)));
            }
          } catch (e) {
            matchesDate = true;
          }
        } else if (selectedTimeFilter == 'Last 7 Days') {
          try {
            var dateValue = po['expectedDeliveryDate'];
            if (dateValue is Timestamp) {
              DateTime poDate = dateValue.toDate();
              DateTime weekAgo = DateTime.now().subtract(Duration(days: 7));
              matchesDate = poDate.isAfter(weekAgo);
            }
          } catch (e) {
            matchesDate = true;
          }
        } else if (selectedTimeFilter == 'This Month') {
          try {
            var dateValue = po['expectedDeliveryDate'];
            if (dateValue is Timestamp) {
              DateTime poDate = dateValue.toDate();
              DateTime now = DateTime.now();
              DateTime startOfMonth = DateTime(now.year, now.month, 1);
              matchesDate =
                  poDate.isAfter(startOfMonth.subtract(Duration(days: 1)));
            }
          } catch (e) {
            matchesDate = true;
          }
        }
        // For 'All Time', matchesDate remains true (no filtering)

        return matchesSearch && matchesSupplier && matchesStatus && matchesDate;
      }).toList();
    }

    List<Map<String, dynamic>> getPaginatedPurchaseOrders(
        List<Map<String, dynamic>> filtered) {
      final startIndex = currentPage * itemsPerPage;
      final endIndex = (startIndex + itemsPerPage).clamp(0, filtered.length);

      if (startIndex >= filtered.length) return [];
      return filtered.sublist(startIndex, endIndex);
    }

    int getTotalPages(List<Map<String, dynamic>> filtered) {
      return (filtered.length / itemsPerPage).ceil();
    }

    String buildOrderCountText() {
      int remainingOrders = purchaseOrders
          .where((po) => ['APPROVED', 'PARTIALLY_RECEIVED']
              .contains(po['status']?.toString() ?? ''))
          .length;
      int totalOrders = purchaseOrders.length;
      int selectedCount = selectedPurchaseOrders.length;
      return 'Remaining Orders: $remainingOrders | Total Orders: $totalOrders ($selectedCount selected)';
    }

    bool areAllFilteredPOsSelected(List<Map<String, dynamic>> filtered) {
      if (filtered.isEmpty) return false;
      return filtered.every((po) =>
          selectedPurchaseOrders.any((selected) => selected['id'] == po['id']));
    }

    List<Map<String, dynamic>> filteredPOs = getFilteredPurchaseOrders();
    List<Map<String, dynamic>> paginatedPOs =
        getPaginatedPurchaseOrders(filteredPOs);
    int totalPages = getTotalPages(filteredPOs);
    bool allSelected = areAllFilteredPOsSelected(filteredPOs);

    List<Widget> slivers = [];

    // Search and filters section - FIXED
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // header with select all checkbox
              Row(
                children: [
                  if (filteredPOs.isNotEmpty) ...[
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: allSelected,
                        onChanged: (value) {
                          if (value == true) {
                            onSelectAllPurchaseOrders();
                          } else {
                            onClearAllSelection();
                          }
                        },
                        activeColor: Color(0xFF3B82F6),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      'Select All',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
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
                      isFiltersExpanded ? 'Hide' : 'Filters',
                      style: TextStyle(fontSize: 14),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Color(0xFF3B82F6),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),

              // collapsible filters section
              if (isFiltersExpanded) ...[
                const SizedBox(height: 12),

                // FIXED: Simplified search with working dropdown
                _SmartSearchDropdown(
                  purchaseOrders: purchaseOrders,
                  searchQuery: searchQuery,
                  selectedSuppliers: selectedSuppliers,
                  onSearchChanged: onSearchChanged,
                  onSuppliersChanged: onSuppliersChanged,
                  onShowPODetails: onShowDetails,
                ),

                const SizedBox(height: 12),

                // time filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: timeFilters.map((filter) {
                      bool isSelected = selectedTimeFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            filter,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            onTimeFilterChanged(filter);
                            if (filter == 'Custom Date Range') {
                              _showDateRangePicker(context, startDate, endDate,
                                  onDateRangeChanged);
                            }
                          },
                          backgroundColor: Colors.white,
                          selectedColor: Color(0xFF3B82F6).withOpacity(0.2),
                          checkmarkColor: Color(0xFF3B82F6),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Color(0xFF3B82F6)
                                : Colors.grey[700],
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? Color(0xFF3B82F6)
                                : Colors.grey[300]!,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // selected suppliers tags
                if (selectedSuppliers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: selectedSuppliers.map((supplier) {
                      return Container(
                        constraints: BoxConstraints(maxWidth: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                supplier,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                List<String> newSelection =
                                    List.from(selectedSuppliers);
                                newSelection.remove(supplier);
                                onSuppliersChanged(newSelection);
                              },
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.blue[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );

    // order count display
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[50],
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  buildOrderCountText(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Fixed pagination - always at top when there are results
    if (filteredPOs.isNotEmpty && totalPages > 1) {
      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[200]!, width: 1),
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Page ${currentPage + 1} of ${totalPages > 0 ? totalPages : 1}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPaginationButton(
                      Icons.chevron_left,
                      currentPage > 0,
                      () => onPageChanged(currentPage - 1),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      constraints: BoxConstraints(minWidth: 32),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Color(0xFF3B82F6).withOpacity(0.3)),
                      ),
                      child: Text(
                        '${currentPage + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildPaginationButton(
                      Icons.chevron_right,
                      currentPage < totalPages - 1,
                      () => onPageChanged(currentPage + 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // purchase orders list - FIXED overflow
    if (filteredPOs.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No purchase orders found',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No purchase orders available',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      // po cards list - FIXED to prevent overflow
      for (int i = 0; i < paginatedPOs.length; i++) {
        Map<String, dynamic> po = paginatedPOs[i];
        bool isSelected = selectedPurchaseOrders
            .any((selected) => selected['id'] == po['id']);

        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: i == 0 ? 16 : 0,
                bottom: 12,
              ),
              child: _buildCompactPurchaseOrderCard(
                  po, isSelected, onToggleSelection, onShowDetails),
            ),
          ),
        );
      }

      // Bottom spacing for sticky bar - FIXED
      if (selectedPurchaseOrders.isNotEmpty) {
        slivers.add(
          SliverToBoxAdapter(
            child: SizedBox(height: 120), // Increased for keyboard safety
          ),
        );
      } else {
        // Add some bottom padding anyway
        slivers.add(
          SliverToBoxAdapter(
            child: SizedBox(height: 50),
          ),
        );
      }
    }

    return slivers;
  }

  // Helper methods (unchanged)
  static Widget _buildPaginationButton(
      IconData icon, bool enabled, VoidCallback? onPressed) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon),
        iconSize: 16,
        color: enabled ? Colors.grey[700] : Colors.grey[400],
        padding: EdgeInsets.zero,
      ),
    );
  }

  static Future<void> _showDateRangePicker(
      BuildContext context,
      DateTime? startDate,
      DateTime? endDate,
      Function(DateTimeRange?) onDateRangeChanged) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate, end: endDate)
          : null,
    );

    if (picked != null) {
      onDateRangeChanged(picked);
    }
  }

  static Widget _buildCompactPurchaseOrderCard(
    Map<String, dynamic> po,
    bool isSelected,
    Function(Map<String, dynamic>) onToggleSelection,
    Function(Map<String, dynamic>) onShowDetails,
  ) {
    String poNumber = po['poNumber']?.toString() ?? 'N/A';
    String supplierName = po['supplierName']?.toString() ?? 'Unknown Supplier';
    String status = po['status']?.toString() ?? 'UNKNOWN';
    double totalAmount = (po['totalAmount'] ?? 0).toDouble();
    List<dynamic> lineItems = po['lineItems'] ?? [];
    int totalItems = lineItems.length;

    DateTime? expectedDate;
    try {
      var dateValue = po['expectedDeliveryDate'];
      if (dateValue is Timestamp) {
        expectedDate = dateValue.toDate();
      }
    } catch (e) {
      // handle date parsing error
    }

    Color statusColor = _getStatusColor(status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: Color(0xFF3B82F6), width: 2)
            : Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? Color(0xFF3B82F6).withOpacity(0.15)
                : Colors.black.withOpacity(0.05),
            blurRadius: isSelected ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onToggleSelection(po),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // header row
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color:
                            isSelected ? Color(0xFF3B82F6) : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? Color(0xFF3B82F6)
                              : Colors.grey[400]!,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: isSelected
                          ? Icon(Icons.check, color: Colors.white, size: 14)
                          : null,
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        poNumber,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color:
                              isSelected ? Color(0xFF3B82F6) : Colors.grey[800],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // action buttons
                    IconButton(
                      onPressed: () => onShowDetails(po),
                      icon: Icon(Icons.visibility,
                          size: 18, color: Colors.grey[600]),
                      iconSize: 18,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      tooltip: 'View Details',
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // info layout - FIXED overflow
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            supplierName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        Text(
                          '$totalItems items',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'RM ${totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                        const Spacer(),
                        if (expectedDate != null)
                          Text(
                            'Due: ${_formatDate(expectedDate)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  static Color _getStatusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return Color(0xFF3B82F6);
      case 'COMPLETED':
        return Color(0xFF10B981);
      case 'CANCELLED':
        return Color(0xFFEF4444);
      case 'PARTIALLY_RECEIVED':
        return Color(0xFFF59E0B);
      default:
        return Colors.grey;
    }
  }
}

// FIXED: Separate stateful widget for search dropdown
class _SmartSearchDropdown extends StatefulWidget {
  final List<Map<String, dynamic>> purchaseOrders;
  final String searchQuery;
  final List<String> selectedSuppliers;
  final Function(String) onSearchChanged;
  final Function(List<String>) onSuppliersChanged;
  final Function(Map<String, dynamic>) onShowPODetails;

  const _SmartSearchDropdown({
    required this.purchaseOrders,
    required this.searchQuery,
    required this.selectedSuppliers,
    required this.onSearchChanged,
    required this.onSuppliersChanged,
    required this.onShowPODetails,
  });

  @override
  State<_SmartSearchDropdown> createState() => _SmartSearchDropdownState();
}

class _SmartSearchDropdownState extends State<_SmartSearchDropdown> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _isDropdownOpen = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _hideDropdown();
    super.dispose();
  }

  @override
  void didUpdateWidget(_SmartSearchDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _controller.text = widget.searchQuery;
    }
    // 🔧 FIX: Force rebuild when selected suppliers change for immediate visual feedback
    if (oldWidget.selectedSuppliers != widget.selectedSuppliers) {
      setState(() {});
      // 🔧 FIX: Use post-frame callback to avoid markNeedsBuild during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_overlayEntry != null && mounted) {
          _overlayEntry!.markNeedsBuild();
        }
      });
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _showDropdown();
    }
  }

  void _showDropdown() {
    if (_overlayEntry != null) return;

    setState(() {
      _isDropdownOpen = true;
    });

    _overlayEntry = OverlayEntry(
      builder: (context) => _buildDropdownOverlay(),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideDropdown() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    setState(() {
      _isDropdownOpen = false;
    });
  }

  void _toggleSupplier(String supplier) {
    List<String> newSelection = List.from(widget.selectedSuppliers);
    if (newSelection.contains(supplier)) {
      newSelection.remove(supplier);
    } else {
      newSelection.add(supplier);
    }

    // Immediately update local state for instant visual feedback
    setState(() {});

    // Notify parent of the change
    widget.onSuppliersChanged(newSelection);

    // Force immediate overlay rebuild without waiting for frame
    if (_overlayEntry != null && mounted) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  Widget _buildDropdownOverlay() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return Container();

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    // Get all available suppliers
    List<String> allSuppliers = widget.purchaseOrders
        .map((po) => po['supplierName']?.toString() ?? '')
        .toSet()
        .where((s) => s.isNotEmpty)
        .toList();

    // Get filtered results
    List<Map<String, dynamic>> filteredPOs = widget.searchQuery.isEmpty
        ? widget.purchaseOrders
            .where((po) => ['APPROVED', 'PARTIALLY_RECEIVED']
                .contains(po['status']?.toString() ?? ''))
            .toList()
        : widget.purchaseOrders.where((po) {
            return (po['poNumber']?.toString() ?? '')
                .toLowerCase()
                .contains(widget.searchQuery.toLowerCase());
          }).toList();

    List<String> filteredSuppliers = widget.searchQuery.isEmpty
        ? allSuppliers
        : allSuppliers
            .where((supplier) => supplier
                .toLowerCase()
                .contains(widget.searchQuery.toLowerCase()))
            .toList();

    return GestureDetector(
      onTap: _hideDropdown,
      behavior: HitTestBehavior.translucent,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(color: Colors.transparent),
            ),
            Positioned(
              left: position.dx,
              top: position.dy + size.height + 4,
              width: size.width,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: 300,
                  minHeight: 60,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Results summary
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Text(
                        '${filteredPOs.length + filteredSuppliers.length} results found',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),

                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Purchase Orders section
                            if (filteredPOs.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                color: Colors.blue[50],
                                child: Text(
                                  'PURCHASE ORDERS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[800],
                                  ),
                                ),
                              ),
                              ...filteredPOs.map((po) {
                                int remainingOrders =
                                    _getRemainingOrdersForPO(po);
                                return InkWell(
                                  onTap: () {
                                    _hideDropdown();
                                    widget.onSearchChanged('');
                                    widget.onShowPODetails(po);
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                            color: Colors.grey[200]!,
                                            width: 0.5),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.description,
                                            size: 16, color: Colors.blue[600]),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                po['poNumber']?.toString() ??
                                                    'N/A',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color: Colors.blue[700],
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Supplier: ${po['supplierName']?.toString() ?? 'Unknown'} | Remaining orders: $remainingOrders',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.visibility,
                                            size: 16, color: Colors.grey[500]),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],

                            // Suppliers section
                            if (filteredSuppliers.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                color: Colors.green[50],
                                child: Text(
                                  'SUPPLIERS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                  ),
                                ),
                              ),
                              ...filteredSuppliers.map((supplier) {
                                // 🔧 SIMPLE: Use widget state directly (parent setState ensures fresh data)
                                bool isSelected =
                                    widget.selectedSuppliers.contains(supplier);
                                int supplierOrderCount = _getSupplierOrderCount(
                                    widget.purchaseOrders, supplier);

                                return InkWell(
                                  onTap: () => _toggleSupplier(supplier),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.green[50]
                                          : Colors.white,
                                      border: Border(
                                        bottom: BorderSide(
                                            color: Colors.grey[200]!,
                                            width: 0.5),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                supplier,
                                                style: TextStyle(
                                                  fontWeight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.w500,
                                                  fontSize: 14,
                                                  color: isSelected
                                                      ? Colors.blue[700]
                                                      : Colors.grey[800],
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Available orders: $supplierOrderCount',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isSelected
                                                      ? Colors.blue[600]
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Right tick design - always show, but different styles for selected/unselected
                                        const SizedBox(width: 12),
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.blue[600]
                                                : Colors.grey[300],
                                            shape: BoxShape.circle,
                                            border: isSelected
                                                ? null
                                                : Border.all(
                                                    color: Colors.grey[400]!,
                                                    width: 1),
                                          ),
                                          child: Icon(
                                            Icons.check,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.grey[500],
                                            size: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],

                            // No results
                            if (filteredPOs.isEmpty &&
                                filteredSuppliers.isEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    Icon(Icons.search_off,
                                        size: 32, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No results found',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getRemainingOrdersForPO(Map<String, dynamic> po) {
    List<dynamic> lineItems = po['lineItems'] ?? [];
    int remaining = 0;

    for (var item in lineItems) {
      int ordered = item['quantityOrdered'] ?? 0;
      int received = item['quantityReceived'] ?? 0;
      int damaged = item['quantityDamaged'] ?? 0;
      remaining += (ordered - received - damaged);
    }

    return remaining;
  }

  int _getSupplierOrderCount(
      List<Map<String, dynamic>> purchaseOrders, String supplier) {
    return purchaseOrders
        .where((po) =>
            (po['supplierName']?.toString() ?? '') == supplier &&
            ['APPROVED', 'PARTIALLY_RECEIVED']
                .contains(po['status']?.toString() ?? ''))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isDropdownOpen ? Color(0xFF3B82F6) : Colors.grey[300]!,
            width: _isDropdownOpen ? 2 : 1,
          ),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Search by PO number or Supplier...',
            prefixIcon: Icon(Icons.search,
                color: _isDropdownOpen ? Color(0xFF3B82F6) : Colors.grey[600],
                size: 20),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.searchQuery.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[600], size: 18),
                    onPressed: () {
                      _controller.clear();
                      widget.onSearchChanged('');
                      _focusNode.requestFocus();
                    },
                  ),
                Icon(
                  _isDropdownOpen
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
              ],
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          onChanged: (value) {
            widget.onSearchChanged(value);
            if (!_isDropdownOpen) {
              _showDropdown();
            }
          },
          onTap: () {
            if (!_isDropdownOpen) {
              _showDropdown();
            }
          },
        ),
      ),
    );
  }
}
