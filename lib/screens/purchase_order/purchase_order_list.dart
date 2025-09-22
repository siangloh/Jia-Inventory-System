import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:assignment/screens/purchase_order/create_purchase_order_screen.dart';
// Import your models and services
import 'package:assignment/models/purchase_order.dart';
import 'package:assignment/services/purchase_order/purchase_order_service.dart';

import 'package:assignment/screens/purchase_order/purchase_order_detail_screen.dart';

class PurchaseOrderListScreen extends StatefulWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  State<PurchaseOrderListScreen> createState() => _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState extends State<PurchaseOrderListScreen>
    with TickerProviderStateMixin {

  // Initialize the service
  final PurchaseOrderService _purchaseOrderService = PurchaseOrderService();
  bool showHighValueOnly = false;
  // Stream subscription for real-time updates
  StreamSubscription<List<PurchaseOrder>>? _purchaseOrderSubscription;

  // Data state
  List<PurchaseOrder> purchaseOrders = [];
  bool isLoadingOrders = false;
  String? loadError;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  String searchQuery = '';
  String selectedStatus = 'All';
  String selectedPriority = 'All';
  String selectedSupplier = 'All';
  String selectedCreator = 'All';
  String sortBy = 'date';
  bool isAscending = false; // Default to newest first
  bool isGridView = false;

  // Advanced filtering
  RangeValues totalRange = const RangeValues(0, 2000);
  bool showOverdueOnly = false;
  bool showUrgentOnly = false;
  bool showPendingApprovalOnly = false;

  bool showSuggestions = false;
  Timer? _debounceTimer;

  // Comparison
  Set<String> selectedForComparison = {};

  // Animation controllers
  late AnimationController _animationController;
  late AnimationController _filterAnimationController;
  late AnimationController _searchAnimationController;

  // Pagination for infinite scroll
  int currentPage = 0;
  int itemsPerPage = 20;
  bool isLoadingMore = false;
  List<PurchaseOrder> displayedOrders = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeRealtimeUpdates();
    _setupScrollListener();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _animationController.forward();
  }

  void _initializeRealtimeUpdates() {
    setState(() {
      isLoadingOrders = true;
      loadError = null;
    });

    // Subscribe to real-time updates
    _purchaseOrderSubscription = _purchaseOrderService.getPurchaseOrdersStream().listen(
          (orders) {
        print('Received ${orders.length} purchase orders from Firebase');
        setState(() {
          purchaseOrders = orders;
          isLoadingOrders = false;
          loadError = null;
        });
        _initializeData();
      },
      onError: (error) {
        print('Error loading purchase orders: $error');
        setState(() {
          isLoadingOrders = false;
          loadError = 'Failed to load purchase orders: ${error.toString()}';
        });
      },
    );
  }

  void _initializeData() {
    if (purchaseOrders.isNotEmpty) {
      totalRange = _calculateTotalRange(purchaseOrders);
      _loadInitialOrders();
    } else {
      setState(() {
        displayedOrders = [];
        currentPage = 0;
      });
    }
  }

  RangeValues _calculateTotalRange(List<PurchaseOrder> orders) {
    if (orders.isEmpty) return const RangeValues(0, 2000);

    double min = orders.map((o) => o.totalAmount).reduce((a, b) => a < b ? a : b);
    double max = orders.map((o) => o.totalAmount).reduce((a, b) => a > b ? a : b);

    // Add some padding
    min = (min * 0.9).floorToDouble();
    max = (max * 1.1).ceilToDouble();

    return RangeValues(min, max);
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreOrders();
      }
    });
  }

  List<PurchaseOrder> _getFilteredAndSortedOrders() {
    List<PurchaseOrder> filtered = purchaseOrders.where((order) {
      // Search query filter
      if (searchQuery.isNotEmpty) {
        final searchLower = searchQuery.toLowerCase();
        if (!order.poNumber.toLowerCase().contains(searchLower) &&
            !order.supplierName.toLowerCase().contains(searchLower) &&
            !order.createdByUserName.toLowerCase().contains(searchLower) &&
            !(order.customerName?.toLowerCase().contains(searchLower) ?? false) &&
            !order.lineItems.any((item) =>
            item.productName.toLowerCase().contains(searchLower) ||
                (item.partNumber?.toLowerCase().contains(searchLower) ?? false))) {
          return false;
        }
      }

      // Status filter
      if (selectedStatus != 'All' && order.status.toString().split('.').last != selectedStatus) {
        return false;
      }

      // Priority filter
      if (selectedPriority != 'All' && order.priority.toString().split('.').last != selectedPriority) {
        return false;
      }

      // Supplier filter
      if (selectedSupplier != 'All' && order.supplierName != selectedSupplier) {
        return false;
      }

      // Creator filter
      if (selectedCreator != 'All' && order.createdByUserName != selectedCreator) {
        return false;
      }

      // Total amount range filter
      if (order.totalAmount < totalRange.start || order.totalAmount > totalRange.end) {
        return false;
      }

      if (showHighValueOnly) {
        if (order.totalAmount < 500.0) {
          return false;
        }
      }

      // Advanced filters
      if (showOverdueOnly && order.expectedDeliveryDate != null &&
          order.expectedDeliveryDate!.isBefore(DateTime.now()) &&
          order.status != POStatus.COMPLETED && order.status != POStatus.CANCELLED) {
        // Only show if overdue
      } else if (showOverdueOnly) {
        return false;
      }

      if (showUrgentOnly && order.priority != POPriority.URGENT) {
        return false;
      }

      if (showPendingApprovalOnly && order.status != POStatus.PENDING_APPROVAL) {
        return false;
      }

      return true;
    }).toList();

    // Sort orders
    filtered.sort((a, b) {
      int result = 0;
      switch (sortBy) {
        case 'date':
          result = a.createdDate.compareTo(b.createdDate);
          break;
        case 'poNumber':
          result = a.poNumber.compareTo(b.poNumber);
          break;
        case 'supplier':
          result = a.supplierName.compareTo(b.supplierName);
          break;
        case 'total':
          result = a.totalAmount.compareTo(b.totalAmount);
          break;
        case 'status':
          result = a.status.toString().compareTo(b.status.toString());
          break;
        case 'priority':
          result = a.priority.index.compareTo(b.priority.index);
          break;
        case 'deliveryDate':
          final aDate = a.expectedDeliveryDate ?? DateTime(2099);
          final bDate = b.expectedDeliveryDate ?? DateTime(2099);
          result = aDate.compareTo(bDate);
          break;
        default:
          result = a.createdDate.compareTo(b.createdDate);
      }

      return isAscending ? result : -result;
    });

    return filtered;
  }

  void _loadInitialOrders() {
    final filteredOrders = _getFilteredAndSortedOrders();
    displayedOrders = filteredOrders.take(itemsPerPage).toList();
    currentPage = 1;
  }

  void _loadMoreOrders() {
    if (isLoadingMore) return;

    setState(() {
      isLoadingMore = true;
    });

    // Simulate API delay
    Future.delayed(const Duration(milliseconds: 500), () {
      final filteredOrders = _getFilteredAndSortedOrders();
      final startIndex = currentPage * itemsPerPage;
      final endIndex = math.min(startIndex + itemsPerPage, filteredOrders.length);

      if (startIndex < filteredOrders.length) {
        setState(() {
          displayedOrders.addAll(filteredOrders.sublist(startIndex, endIndex));
          currentPage++;
          isLoadingMore = false;
        });
      } else {
        setState(() {
          isLoadingMore = false;
        });
      }
    });
  }

  @override
  void dispose() {
    // Cancel the subscription to prevent memory leaks
    _purchaseOrderSubscription?.cancel();
    _animationController.dispose();
    _filterAnimationController.dispose();
    _searchAnimationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _performSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        searchQuery = query;
        _loadInitialOrders();
      });
    });
  }

  void _clearAllFilters() {
    setState(() {
      searchQuery = '';
      _searchController.clear();
      selectedStatus = 'All';
      selectedPriority = 'All';
      selectedSupplier = 'All';
      selectedCreator = 'All';
      showOverdueOnly = false;
      showUrgentOnly = false;
      showHighValueOnly = false;
      showPendingApprovalOnly = false;
      showSuggestions = false;
      _loadInitialOrders();
    });
  }

  Future<void> _refreshOrders() async {
    _showSnackBar('Orders are updated', Colors.green);
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoadingOrders && purchaseOrders.isEmpty
          ? _buildLoadingScreen()
          : Column(
        children: [
          if (loadError != null) _buildErrorBanner(),
          _buildSearchSection(theme),
          _buildFilterAndStatsRow(theme),
          if (selectedForComparison.isNotEmpty) _buildComparisonBar(theme),
          Expanded(
            child: displayedOrders.isEmpty
                ? _buildEmptyState()
                : _buildOrderDisplay(),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(theme),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading purchase orders from Firebase...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.red.withOpacity(0.1),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              loadError!,
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              // Reinitialize real-time updates
              _initializeRealtimeUpdates();
            },
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search orders, suppliers, PO numbers...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch('');
                      },
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: _performSearch,
                ),
              ),
              const SizedBox(width: 8),
              _buildViewToggle(),
              _buildSortMenu(),
              _buildAdvancedFilterButton(),
            ],
          ),
          const SizedBox(height: 12),
          _buildQuickFilters(),
        ],
      ),
    );
  }

  Widget _buildQuickFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildQuickFilterChip(
          'Pending Approval',
          showPendingApprovalOnly,
          Colors.orange,
              (value) {
            setState(() {
              showPendingApprovalOnly = value;
              if (value) {
                showPendingApprovalOnly = value;
                showHighValueOnly = false;
                showUrgentOnly = false;
              }
              _loadInitialOrders();
            });
          },
        ),
        _buildQuickFilterChip(
          'Urgent',
          showUrgentOnly,
          Colors.red,
              (value) {
            setState(() {
              showUrgentOnly = value;
              if (value) {
                showHighValueOnly = false;
                showPendingApprovalOnly = false;
              }
              _loadInitialOrders();
            });
          },
        ),
        _buildQuickFilterChip(
          'High Value (500+)',
          showHighValueOnly,
          Colors.purple,
              (value) {
            setState(() {
              showHighValueOnly = value;
              if (value) {
                showUrgentOnly = false;
                showPendingApprovalOnly = false;
              }
              _loadInitialOrders();
            });
          },
        ),
        _buildStatusDropdown(),
        _buildSupplierDropdown(),
      ],
    );
  }

  Widget _buildQuickFilterChip(String label, bool isSelected, Color color, Function(bool) onChanged) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: onChanged,
      backgroundColor: Colors.white,
      selectedColor: color,
      checkmarkColor: Colors.white,
      side: BorderSide(color: color),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selectedStatus,
        items: ['All', 'PENDING_APPROVAL', 'APPROVED', 'REJECTED', 'COMPLETED', 'READY', 'CANCELLED', 'PARTIALLY_RECEIVED']
            .map((status) => DropdownMenuItem(
          value: status,
          child: Text(
            status == 'All' ? 'All Status' : status.replaceAll('_', ' '),
            style: const TextStyle(fontSize: 12),
          ),
        ))
            .toList(),
        onChanged: (value) {
          setState(() {
            selectedStatus = value!;
            _loadInitialOrders();
          });
        },
      ),
    );
  }

  Widget _buildSupplierDropdown() {
    final suppliers = ['All'] + purchaseOrders.map((o) => o.supplierName).toSet().toList();
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selectedSupplier,
        items: suppliers
            .map((supplier) => DropdownMenuItem(
          value: supplier,
          child: Text(
            supplier == 'All' ? 'All Suppliers' : supplier,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ))
            .toList(),
        onChanged: (value) {
          setState(() {
            selectedSupplier = value!;
            _loadInitialOrders();
          });
        },
      ),
    );
  }

  Widget _buildViewToggle() {
    return IconButton(
      icon: Icon(isGridView ? Icons.list : Icons.grid_view, size: 20),
      onPressed: () {
        setState(() {
          isGridView = !isGridView;
        });
      },
      tooltip: isGridView ? 'List View' : 'Grid View',
    );
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort, size: 20),
      tooltip: 'Sort Options',
      onSelected: (value) {
        setState(() {
          if (sortBy == value) {
            isAscending = !isAscending;
          } else {
            sortBy = value;
            isAscending = value == 'date' ? false : true; // Newest first for date
          }
          _loadInitialOrders();
        });
      },
      itemBuilder: (context) => [
        _buildSortMenuItem('date', 'Created Date', Icons.calendar_today),
        _buildSortMenuItem('poNumber', 'PO Number', Icons.receipt_long),
        _buildSortMenuItem('supplier', 'Supplier', Icons.business),
        _buildSortMenuItem('total', 'Total Amount', Icons.attach_money),
        _buildSortMenuItem('status', 'Status', Icons.flag),
        _buildSortMenuItem('priority', 'Priority', Icons.priority_high),
        _buildSortMenuItem('deliveryDate', 'Delivery Date', Icons.local_shipping),
      ],
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(String value, String label, IconData icon) {
    return PopupMenuItem(
      value: value,
      child: SizedBox(
        width: 150,
        child: Row(
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 14)),
            ),
            if (sortBy == value)
              Icon(
                isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedFilterButton() {
    return IconButton(
      icon: const Icon(Icons.tune, size: 20),
      onPressed: _showAdvancedFilters,
      tooltip: 'Advanced Filters',
    );
  }

  void _showAdvancedFilters() {
    // Calculate the actual min and max for the slider based on purchase orders
    double sliderMin = 0;
    double sliderMax = 2000; // Default fallback

    if (purchaseOrders.isNotEmpty) {
      double dataMin = purchaseOrders.map((o) => o.totalAmount).reduce((a, b) => a < b ? a : b);
      double dataMax = purchaseOrders.map((o) => o.totalAmount).reduce((a, b) => a > b ? a : b);

      // Add padding and ensure bounds
      sliderMin = math.max(0, (dataMin * 0.9).floorToDouble());
      sliderMax = math.max(2000, (dataMax * 1.1).ceilToDouble());
    }

    // Ensure totalRange is within bounds
    RangeValues constrainedRange = RangeValues(
      math.max(sliderMin, math.min(totalRange.start, sliderMax)),
      math.min(sliderMax, math.max(totalRange.end, sliderMin)),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Advanced Filters'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Total Amount Range: RM ${constrainedRange.start.toInt()} - RM ${constrainedRange.end.toInt()}'),
                RangeSlider(
                  values: constrainedRange,
                  min: sliderMin,
                  max: sliderMax,
                  divisions: 20,
                  onChanged: (values) {
                    setDialogState(() {
                      constrainedRange = values;
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('High Value (RM 500+)'),
                  value: showHighValueOnly,
                  onChanged: (value) {
                    setDialogState(() {
                      showHighValueOnly = value ?? false;
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Show Urgent Only'),
                  value: showUrgentOnly,
                  onChanged: (value) {
                    setDialogState(() {
                      showUrgentOnly = value ?? false;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  totalRange = constrainedRange; // Update the main state
                });
                Navigator.pop(context);
                _loadInitialOrders();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterAndStatsRow(ThemeData theme) {
    final filteredCount = _getFilteredAndSortedOrders().length;
    final pendingCount = purchaseOrders.where((o) => o.status == POStatus.PENDING_APPROVAL).length;
    final readyCount = purchaseOrders.where((o) => o.status == POStatus.READY).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$filteredCount orders',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.primaryColor,
              ),
            ),
          ),
          _buildStatChip('$pendingCount pending', Colors.orange[700]!),
          const SizedBox(width: 8),
          _buildStatChip('$readyCount ready', Colors.green[700]!),
        ],
      ),
    );
  }

  Widget _buildStatChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildComparisonBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.primaryColor.withOpacity(0.1),
      child: Row(
        children: [
          Icon(Icons.compare_arrows, color: theme.primaryColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${selectedForComparison.length} selected for comparison',
              style: TextStyle(
                color: theme.primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              // Implement comparison functionality
              _showSnackBar('Comparison feature coming soon!', Colors.blue);
            },
            child: const Text('Compare', style: TextStyle(fontSize: 12)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                selectedForComparison.clear();
              });
            },
            child: const Text('Clear', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDisplay() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _animationController,
          child: RefreshIndicator(
            onRefresh: _refreshOrders,
            child: isGridView ? _buildGridView() : _buildListView(),
          ),
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: displayedOrders.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == displayedOrders.length) {
          return _buildLoadingIndicator();
        }

        final order = displayedOrders[index];
        return _buildOrderCard(order, false);
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getGridCrossAxisCount(),
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: displayedOrders.length + (isLoadingMore ? 2 : 0),
      itemBuilder: (context, index) {
        if (index >= displayedOrders.length) {
          return _buildLoadingCard();
        }

        final order = displayedOrders[index];
        return _buildOrderCard(order, true);
      },
    );
  }

  int _getGridCrossAxisCount() {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 600) return 3;
    if (screenWidth > 400) return 2;
    return 1;
  }

  Widget _buildOrderCard(PurchaseOrder order, bool isGridView) {
    final isOverdue = order.expectedDeliveryDate != null &&
        order.expectedDeliveryDate!.isBefore(DateTime.now()) &&
        order.status != POStatus.COMPLETED &&
        order.status != POStatus.CANCELLED;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selectedForComparison.contains(order.id) ? Colors.blue : Colors.grey[200]!,
          width: selectedForComparison.contains(order.id) ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showOrderDetails(order),
        onLongPress: () => _toggleComparisonSelection(order.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.poNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusChip(order.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.supplierName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildPriorityChip(order.priority),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.createdByUserName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatDate(order.createdDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              if (order.expectedDeliveryDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping,
                      size: 16,
                      color: isOverdue ? Colors.red[500] : Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Due: ${_formatDate(order.expectedDeliveryDate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverdue ? Colors.red[600] : Colors.grey[600],
                          fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'RM ${order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (action) => _handleMenuAction(action, order),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility, size: 16),
                            SizedBox(width: 8),
                            Text('View Details'),
                          ],
                        ),
                      ),
                      if (order.status == POStatus.PENDING_APPROVAL)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 16),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                      if (order.status == POStatus.PENDING_APPROVAL)
                        const PopupMenuItem(
                          value: 'approve',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, size: 16),
                              SizedBox(width: 8),
                              Text('Approve'),
                            ],
                          ),
                        ),
                      if (order.status != POStatus.COMPLETED &&
                          order.status != POStatus.CANCELLED &&
                          order.status != POStatus.APPROVED &&
                          order.status != POStatus.REJECTED &&
                          order.status != POStatus.READY)
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Row(
                            children: [
                              Icon(Icons.cancel, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Cancel', style: TextStyle(color: Colors.red)),
                            ],
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
    );
  }

  Widget _buildStatusChip(POStatus status) {
    Color color;
    String text = status.toString().split('.').last.replaceAll('_', ' ');

    switch (status) {
      case POStatus.PARTIALLY_RECEIVED:
        color = Colors.lightGreen;
        break;
      case POStatus.READY:
        color = Colors.lightGreen;
        break;
      case POStatus.REJECTED:
        color = Colors.red;
        break;
      case POStatus.PENDING_APPROVAL:
        color = Colors.orange;
        break;
      case POStatus.APPROVED:
        color = Colors.blue;
        break;
      case POStatus.COMPLETED:
        color = Colors.green;
        break;
      case POStatus.CANCELLED:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.blue[700],
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPriorityChip(POPriority priority) {
    Color color;
    IconData icon;
    String text = priority.toString().split('.').last;

    switch (priority) {
      case POPriority.LOW:
        color = Colors.green;
        icon = Icons.keyboard_arrow_down;
        break;
      case POPriority.NORMAL:
        color = Colors.blue;
        icon = Icons.remove;
        break;
      case POPriority.HIGH:
        color = Colors.orange;
        icon = Icons.keyboard_arrow_up;
        break;
      case POPriority.URGENT:
        color = Colors.red;
        icon = Icons.priority_high;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.blue[700]),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              color: Colors.blue[700],
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 16,
              color: Colors.grey[200],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 12,
              color: Colors.grey[200],
            ),
            const SizedBox(height: 8),
            Container(
              width: 100,
              height: 12,
              color: Colors.grey[200],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No purchase orders found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isNotEmpty
                  ? 'Try adjusting your search terms or filters'
                  : 'Create your first purchase order to get started',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (searchQuery.isNotEmpty || selectedStatus != 'All' || selectedSupplier != 'All')
              ElevatedButton(
                onPressed: _clearAllFilters,
                child: const Text('Clear All Filters'),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(ThemeData theme) {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CreatePurchaseOrderScreen(),
          ),
        ).then((result) {
          // The stream will automatically update when new data is added
          if (result != null) {
            _showSnackBar('Purchase order created successfully!', Colors.green);
          }
        });
      },
      icon: const Icon(Icons.add),
      label: const Text('New PO'),
      backgroundColor: theme.primaryColor,
      foregroundColor: Colors.white,
    );
  }

  void _toggleComparisonSelection(String orderId) {
    setState(() {
      if (selectedForComparison.contains(orderId)) {
        selectedForComparison.remove(orderId);
      } else {
        if (selectedForComparison.length < 4) {
          selectedForComparison.add(orderId);
        } else {
          _showSnackBar('Maximum 4 orders can be compared at once', Colors.orange);
        }
      }
    });
  }

  void _showOrderDetails(PurchaseOrder order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PurchaseOrderDetailScreen(
          purchaseOrderId: order.id,
          initialPurchaseOrder: order, // Provide initial data for faster loading
        ),
      ),
    ).then((result) {
      // Handle any result from the detail screen if needed
      // The stream will automatically update when data changes
      if (result != null) {
        _showSnackBar('Purchase order updated successfully!', Colors.green);
      }
    });
  }

  void _handleMenuAction(String action, PurchaseOrder order) async {
    switch (action) {
      case 'view':
        _showOrderDetails(order);
        break;
      case 'edit':
        _showSnackBar('Edit Purchase Order feature coming soon!', Colors.blue);
        break;
      case 'approve':
        await _approvePurchaseOrder(order);
        break;
      case 'cancel':
        await _cancelPurchaseOrder(order);
        break;
      case 'compare':
        _toggleComparisonSelection(order.id);
        break;
    }
  }

  Future<void> _approvePurchaseOrder(PurchaseOrder order) async {
    try {
      await _purchaseOrderService.updatePurchaseOrderStatus(
        order.id,
        POStatus.APPROVED,
        updatedByUserId: 'current_user_id', // Replace with actual user ID
      );
      _showSnackBar('Purchase order approved successfully!', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to approve purchase order: $e', Colors.red);
    }
  }

  Future<void> _cancelPurchaseOrder(PurchaseOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Purchase Order'),
        content: Text('Are you sure you want to cancel ${order.poNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Order', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _purchaseOrderService.updatePurchaseOrderStatus(
          order.id,
          POStatus.CANCELLED,
          updatedByUserId: 'current_user_id', // Replace with actual user ID
        );
        _showSnackBar('Purchase order cancelled', Colors.orange);
      } catch (e) {
        _showSnackBar('Failed to cancel purchase order: $e', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color backgroundColor, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              backgroundColor == Colors.green ? Icons.check_circle :
              backgroundColor == Colors.red ? Icons.error : Icons.info,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: action,
        duration: Duration(seconds: action != null ? 4 : 2),
      ),
    );
  }
}