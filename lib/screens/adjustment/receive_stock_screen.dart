import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/adjustment/inventory_service.dart';
import '../../services/adjustment/snackbar_manager.dart';
import '../../services/adjustment/exit_guard_service.dart';
import 'receive_stock/steps/select_orders_step.dart';
import 'receive_stock/steps/process_items_step.dart';
import 'receive_stock/steps/review_step.dart';
import 'receive_stock/steps/complete_step.dart';
import '../../dialogs/adjustment/po_details_dialog.dart';
import '../../dialogs/adjustment/report_discrepancy_dialog.dart';

class ReceiveStockScreen extends StatefulWidget {
  const ReceiveStockScreen({Key? key}) : super(key: key);

  @override
  State<ReceiveStockScreen> createState() => _ReceiveStockScreenState();
}

class _ReceiveStockScreenState extends State<ReceiveStockScreen> {
  final InventoryService _inventoryService = InventoryService();
  List<Map<String, dynamic>> _purchaseOrders = [];
  List<Map<String, dynamic>> _selectedPurchaseOrders = [];
  bool _isLoading = true;
  int _currentStep = 0;
  
  // REAL-TIME: Stream subscription for automatic updates
  StreamSubscription<List<Map<String, dynamic>>>? _purchaseOrdersSubscription;
  bool _isInitialized = false;

  // review step has two sub-steps: checklist and summary
  int _reviewSubStep = 0;

  // temporary storage for discrepancy reports created during receiving
  List<Map<String, dynamic>> _localDiscrepancyReports = [];

  // Snackbar manager instance
  final SnackbarManager _snackbarManager = SnackbarManager();
  
  // Exit guard service instance
  final ExitGuardService _exitGuardService = ExitGuardService();
  
  // Change tracking - only show exit dialog if user has actually interacted
  bool _hasUserInteracted = false;

  // Step 1 state
  String _searchQuery = '';
  List<String> _selectedSuppliers = [];
  String _selectedTimeFilter = 'All Time';
  bool _isFiltersExpanded = false;
  int _currentPage = 0;
  final int _itemsPerPage = 5;
  DateTime? _startDate;
  DateTime? _endDate;
  List<String> _suppliers = ['All Suppliers'];
  List<String> _timeFilters = [
    'All Time',
    'Last 7 Days',
    'This Month',
    'Custom Date Range'
  ];

  // step configuration with two-line design
  final List<Map<String, String>> _steps = [
    {'title': 'Select\nPurchase', 'subtitle': 'Orders'},
    {'title': 'Process\nLine', 'subtitle': 'Items'},
    {'title': 'Review\nChanges', 'subtitle': 'Changes'},
    {'title': 'Complete\nReceiving', 'subtitle': 'Receiving'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeRealTimeUpdates();
  }

  /// Handles back navigation with exit confirmation
  Future<void> _handleBackNavigation() async {
    // Only show exit dialog if user has actually interacted with the page
    if (!_hasUserInteracted) {
      // No changes made, exit directly
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }
    
    // User has made changes, show exit confirmation dialog
    final shouldExit = await _exitGuardService.handleWorkflowExit(
      context: context,
      workflowName: 'Receive Stock',
      currentStep: _currentStep,
      totalSteps: _steps.length,
      stepName: _getCurrentStepName(),
    );
    
    if (shouldExit && mounted) {
      Navigator.pop(context);
    }
  }

  /// Handles step back navigation (should NOT show exit dialog)
  Future<void> _handleStepBackNavigation() async {
    // Step back navigation should NOT show exit dialog
    // Just move to previous step if available
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  /// Checks if the current state is back to initial state (no user changes)
  bool _isBackToInitialState() {
    return _selectedPurchaseOrders.isEmpty && 
        _searchQuery.isEmpty && 
        _selectedSuppliers.isEmpty && 
        _selectedTimeFilter == 'All Time' &&
        _startDate == null &&
        _endDate == null;
  }

  /// Gets the current step name for display
  String _getCurrentStepName() {
    switch (_currentStep) {
      case 0:
        return 'Select Purchase Orders';
      case 1:
        return 'Process Line Items';
      case 2:
        return _reviewSubStep == 0 ? 'Review Checklist' : 'Review Summary';
      case 3:
        return 'Complete Receiving';
      default:
        return '';
    }
  }

  // REAL-TIME: Initialize stream for automatic updates
  void _initializeRealTimeUpdates() {
    setState(() => _isLoading = true); // ✅ Show loading immediately
    
    try {
      _purchaseOrdersSubscription?.cancel(); // Cancel any existing subscription
      
      _purchaseOrdersSubscription = _inventoryService.getAllPurchaseOrdersStream(
        statusFilter: [], // Get ALL POs for accurate total count
        includeResolved: true,
        fastInitialLoad: true, // 🚀 NEW: Load basic data first
      ).listen(
        (orders) {
          if (mounted) {
            setState(() {
              _purchaseOrders = orders;
              _suppliers = [
                'All Suppliers',
                ...orders
                    .map((po) => po['supplierName'] ?? '')
                    .toSet()
                    .where((s) => s.isNotEmpty)
                    .toList()
              ];
              _isLoading = false; // ✅ Hide loading when basic data loads
              _isInitialized = true;
            });
            
            // 🚀 PERFORMANCE: Resolve product data in background
            _resolveProductDataInBackground(orders);
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() => _isLoading = false); // ✅ Hide loading on error
            _snackbarManager.showErrorMessage(context, message: 'Error loading purchase orders: $error');
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false); // ✅ Hide loading on exception
        _snackbarManager.showErrorMessage(context, message: 'Error initializing real-time updates: $e');
      }
    }
  }

  // 🚀 PERFORMANCE: Resolve product data in background for better UX
  void _resolveProductDataInBackground(List<Map<String, dynamic>> orders) async {
    try {
      // Collect all line items that need resolution
      List<Map<String, dynamic>> allLineItems = [];
      for (final order in orders) {
        final lineItems = order['lineItems'] as List<dynamic>?;
        if (lineItems != null) {
          for (final item in lineItems) {
            final lineItem = Map<String, dynamic>.from(item as Map);
            if (lineItem['isResolving'] == true) {
              allLineItems.add(lineItem);
            }
          }
        }
      }

      // Resolve in background
      if (allLineItems.isNotEmpty) {
        await _inventoryService.resolveProductDataInBackground(allLineItems);
        
        // Update UI with resolved data
        if (mounted) {
          setState(() {
            // Trigger rebuild to show resolved data
            _purchaseOrders = List<Map<String, dynamic>>.from(_purchaseOrders);
          });
        }
      }
    } catch (e) {
      print('Error resolving product data in background: $e');
    }
  }

  @override
  void dispose() {
    _purchaseOrdersSubscription?.cancel();
    _isInitialized = false;
    super.dispose();
  }


  // Check if we should show sticky bottom bar for current step
  bool _shouldShowStickyBottomBar() {
    switch (_currentStep) {
      case 0: // Step 1: Show if any POs selected
        return _selectedPurchaseOrders.isNotEmpty;
      case 1: // Step 2: Show if can proceed to review
        return _canProceedToReview();
      case 2: // Step 3: Always show (either checklist → summary or summary → complete)
        return true;
      case 3: // Step 4: No bottom bar needed
        return false;
      default:
        return false;
    }
  }

  // Get bottom bar content for current step
  Widget _buildStickyBottomBar() {
    switch (_currentStep) {
      case 0: // Step 1: Selection summary
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[300]!)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF3B82F6), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_selectedPurchaseOrders.length} Purchase Order${_selectedPurchaseOrders.length == 1 ? '' : 's'} Selected',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearAllSelection,
                    child: Text('Clear All'),
              ),
            ],
          ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => _currentStep = 1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Process Selected Purchase Orders',
          style: TextStyle(
                      fontSize: 15,
            fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      case 1: // Step 2: Process items
    return Container(
          padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handleStepBackNavigation,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _canProceedToReview()
                      ? () => setState(() {
                            _currentStep = 2;
                            _reviewSubStep = 0; // Start with checklist
                          })
              : null,
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Review Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _canProceedToReview() ? Colors.green : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      case 2: // Step 3: Review (either checklist → summary or summary → complete)
        return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
        ),
        child: Row(
          children: [
            Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (_reviewSubStep == 0) {
                      // From checklist back to process items - no confirmation needed (review step)
                      setState(() => _currentStep = 1);
                    } else {
                      // From summary back to checklist - no confirmation needed (review step)
                      setState(() => _reviewSubStep = 0);
                    }
                  },
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_reviewSubStep == 0) {
                      // From checklist to summary
                      setState(() => _reviewSubStep = 1);
                    } else {
                      // From summary to complete
                      _handleCompleteReceiving();
                    }
                  },
                  icon: Icon(
                      _reviewSubStep == 0
                          ? Icons.summarize
                          : Icons.check_circle,
                      size: 18),
                  label: Text(_reviewSubStep == 0
                      ? 'View Summary'
                      : 'Complete Receiving'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
          ),
        ],
      ),
        );

      default:
        return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure subscription is initialized
    if (!_isInitialized && _purchaseOrdersSubscription == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeRealTimeUpdates();
      });
    }
    
    return Scaffold(
      body: Stack(
        children: [
          // single scrollable view for the entire page with overflow protection
          LayoutBuilder(
            builder: (context, constraints) {
              return CustomScrollView(
                physics:
                    ClampingScrollPhysics(), // Prevent bounce that can cause overflow
                slivers: [
                  // Title header (always visible at top)
                  SliverToBoxAdapter(
                    child: _buildSubHeader(),
                  ),

                  // collapsing wizard with proper spacing to avoid overflow
                  SliverAppBar(
                    backgroundColor: Colors.white,
                    elevation: 0,
                    pinned: true,
                    floating: false,
                    snap: false,
                    expandedHeight:
                        130.0, // Increased to eliminate remaining 5.7px overflow
                    collapsedHeight:
                        65.0, // Increased to eliminate remaining 5.7px overflow
                    automaticallyImplyLeading: false,
                    toolbarHeight: 0,
                    surfaceTintColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    flexibleSpace: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                        final expandedHeight = 130.0;
                        final collapsedHeight = 65.0;
                        final currentHeight = constraints.maxHeight;
                        final shrinkRatio = ((expandedHeight - currentHeight) /
                                (expandedHeight - collapsedHeight))
                            .clamp(0.0, 1.0);
                        return Container(
        color: Colors.white,
                          padding: EdgeInsets.symmetric(
                              vertical: 4), // Slightly increased padding
                          alignment: Alignment.center,
                          child: shrinkRatio < 0.5
                              ? _buildExpandedWizard(shrinkRatio)
                              : _buildCollapsedWizard(shrinkRatio),
                        );
                      },
                    ),
                  ),

                  // Step content - pure slivers, no nested scrolls
                  ..._buildCurrentStepSlivers(),

                  // Bottom padding for sticky bar
                  if (_shouldShowStickyBottomBar())
                    SliverToBoxAdapter(
                      child: SizedBox(
                          height:
                              80), // Further increased space for sticky bottom bar to prevent overflow
                    ),
                ],
              );
            },
          ),

          // Single sticky bottom bar
          if (_shouldShowStickyBottomBar())
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildStickyBottomBar(),
            ),
        ],
            ),
    );
  }

  Widget _buildSubHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
        color: Colors.white,
            border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
          ),
          child: Row(
            children: [
          IconButton(
            onPressed: () => _handleBackNavigation(),
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey[100],
              foregroundColor: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                  'Receive Stock',
                      style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                          Text(
                  'Receive arrival stocks and process inventory adjustments',
                            style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
                    ),
                  );
  }

  // two-line wizard design for step display
  Widget _buildExpandedWizard(double shrinkRatio) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: 1 - shrinkRatio,
            child: Stack(
              children: [
                // ENHANCED: Full-width background line
                Positioned(
                  top: 20, // Center vertically with the circles (circle radius is 20)
                  left: 0, // Start from left edge
                  right: 0, // End at right edge
                  child: Container(
                    height: 2,
            decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),

                // ENHANCED: Full-width progress line
                Positioned(
                  top: 20, // Center vertically with the circles
                  left: 0, // Start from left edge
                  child: Container(
                    width: _currentStep == 0 
                        ? 0 // No progress line on first step
                        : _currentStep >= _steps.length - 1
                            ? MediaQuery.of(context).size.width // Full width on last step
                            : (MediaQuery.of(context).size.width / (_steps.length - 1)) * _currentStep, // Progress to current step
                    height: 2,
                    decoration: BoxDecoration(
                      color: Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),

                // Step circles and labels - properly aligned design
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(_steps.length, (index) {
                    bool isCompleted = index < _currentStep;
                    bool isCurrent = index == _currentStep;
                    final step = _steps[index];

                    return Expanded(
                      child: Column(
      children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? Colors.green // Receive = Green
                                  : isCurrent
                                      ? Colors.green // Receive = Green
                                      : Colors.white,
                              border: Border.all(
                                color: isCompleted
                                    ? Colors.green // Receive = Green
                                    : isCurrent
                                        ? Colors.green // Receive = Green
                                        : Colors.grey[300]!,
                                width: 2,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: isCompleted
                                  ? Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: isCurrent
                                            ? Colors.white
                                            : Colors.grey[600],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            step['title']!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  isCurrent ? FontWeight.w600 : FontWeight.w500,
                              color: isCurrent
                                  ? Colors.green // Receive = Green
                                  : isCompleted
                                      ? Colors.green // Receive = Green
                                      : Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedWizard(double shrinkRatio) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // Center the row content
      children: [
          // Current step text - more compact
          Expanded(
            child: Text(
              'Step ${_currentStep + 1}: ${_steps[_currentStep]['title']!.replaceAll('\n', ' ')}',
          style: TextStyle(
                fontSize: 13,
            fontWeight: FontWeight.w600,
                color: Colors.green, // Receive = Green
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Compact progress indicators
          Row(
            children: List.generate(_steps.length, (index) {
              bool isCompleted = index < _currentStep;
              bool isCurrent = index == _currentStep;

              return Container(
                margin: EdgeInsets.only(left: index > 0 ? 6 : 0),
                width: 20,
                height: 20,
          decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green // Receive = Green
                      : isCurrent
                          ? Colors.green // Receive = Green
                          : Colors.white,
                  border: Border.all(
                    color: isCompleted
                        ? Colors.green // Receive = Green
                        : isCurrent
                            ? Colors.green // Receive = Green
                            : Colors.grey[300]!,
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        )
                      : Text(
                          '${index + 1}',
                  style: TextStyle(
                            color: isCurrent ? Colors.white : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                  ),
                ),
              ),
              );
            }),
              ),
            ],
          ),
    );
  }

  List<Widget> _buildCurrentStepSlivers() {
    switch (_currentStep) {
      case 0:
        return SelectOrdersStep.buildSlivers(
          purchaseOrders: _purchaseOrders,
          selectedPurchaseOrders: _selectedPurchaseOrders,
          isLoading: _isLoading,
          searchQuery: _searchQuery,
          selectedSuppliers: _selectedSuppliers,
          selectedTimeFilter: _selectedTimeFilter,
          isFiltersExpanded: _isFiltersExpanded,
          currentPage: _currentPage,
          itemsPerPage: _itemsPerPage,
          startDate: _startDate,
          endDate: _endDate,
          suppliers: _suppliers,
          timeFilters: _timeFilters,
          onSearchChanged: (value) {
            setState(() {
              _searchQuery = value;
              _currentPage = 0;
              
              // Check if we're back to initial state and update interaction tracking
              _hasUserInteracted = !_isBackToInitialState();
            });
          },
          onSuppliersChanged: (value) {
            setState(() {
              _selectedSuppliers = value;
              _currentPage = 0;
              
              // Check if we're back to initial state and update interaction tracking
              _hasUserInteracted = !_isBackToInitialState();
            });
          },
          onTimeFilterChanged: (value) {
            setState(() {
              _selectedTimeFilter = value;
              _currentPage = 0;
              // Clear date range when switching to non-custom filters
              if (value != 'Custom Date Range') {
                _startDate = null;
                _endDate = null;
              }
              
              // Check if we're back to initial state and update interaction tracking
              _hasUserInteracted = !_isBackToInitialState();
            });
          },
          onToggleFilters: () {
            _hasUserInteracted = true;
            setState(() {
              _isFiltersExpanded = !_isFiltersExpanded;
            });
          },
          onPageChanged: (page) {
            _hasUserInteracted = true;
            setState(() => _currentPage = page);
          },
          onDateRangeChanged: (range) {
            setState(() {
              _startDate = range?.start;
              _endDate = range?.end;
              _currentPage = 0;
              
              // Check if we're back to initial state and update interaction tracking
              _hasUserInteracted = !_isBackToInitialState();
            });
          },
          onToggleSelection: _togglePurchaseOrderSelection,
          onShowDetails: _showPODetails,
          onClearAllSelection: _clearAllSelection,
          onSelectAllPurchaseOrders: _selectAllPurchaseOrders,
          onProceedToNextStep: () => setState(() => _currentStep = 1),
      context: context,
        );
      case 1:
        return ProcessItemsStep.buildSlivers(
          selectedPurchaseOrders: _selectedPurchaseOrders,
          onToggleAllReceived: _toggleAllReceived,
          onProcessItem: _processItem,
          onReportDiscrepancy: _reportDiscrepancy,
          onBack: _handleStepBackNavigation,
          onProceedToReview: () => setState(() {
            _currentStep = 2;
            _reviewSubStep = 0;
          }),
          canProceedToReview: _canProceedToReview(),
          context: context,
        );
      case 2:
        // Split review into two sub-screens
        if (_reviewSubStep == 0) {
          // Item checklist view
          return ReviewStep.buildChecklistSlivers(
            selectedPurchaseOrders: _selectedPurchaseOrders,
            onBack: () => setState(() => _currentStep = 1),
            onProceedToSummary: () => setState(() => _reviewSubStep = 1),
        context: context,
          );
        } else {
          // Summary dashboard view
          return ReviewStep.buildSummarySlivers(
            selectedPurchaseOrders: _selectedPurchaseOrders,
            onBack: () => setState(() => _reviewSubStep = 0),
            onProceedToComplete: _handleCompleteReceiving,
            context: context,
          );
        }
      case 3:
        return CompleteStep.buildSlivers(
          selectedPurchaseOrders: _selectedPurchaseOrders,
          onPrintReceipt: _printReceipt,
          onStartNewReceiving: _startNewReceiving,
          context: context,
        );
      default:
        return [SliverToBoxAdapter(child: Container())];
    }
  }

  // Business logic methods...
  void _togglePurchaseOrderSelection(Map<String, dynamic> po) {
    setState(() {
      if (_selectedPurchaseOrders
          .any((selected) => selected['id'] == po['id'])) {
        _selectedPurchaseOrders
            .removeWhere((selected) => selected['id'] == po['id']);
      } else {
        Map<String, dynamic> poCopy = Map<String, dynamic>.from(po);
        if (po['lineItems'] != null) {
          poCopy['lineItems'] = List<dynamic>.from(
              po['lineItems'].map((item) => Map<String, dynamic>.from(item)));
        }
        _selectedPurchaseOrders.add(poCopy);
      }
      
      // Check if we're back to initial state and update interaction tracking
      _hasUserInteracted = !_isBackToInitialState();
    });
  }

  void _clearAllSelection() {
    setState(() {
      _selectedPurchaseOrders.clear();
      
      // Check if we're back to initial state and update interaction tracking
      _hasUserInteracted = !_isBackToInitialState();
    });
  }

  void _selectAllPurchaseOrders() {
    _hasUserInteracted = true;
    setState(() {
      _selectedPurchaseOrders.clear();
      List<Map<String, dynamic>> approvedPOs = _purchaseOrders.where((po) {
        bool matchesStatus =
            ['APPROVED', 'PARTIALLY_RECEIVED'].contains(po['status'] ?? '');
        bool matchesSearch = _searchQuery.isEmpty ||
            (po['poNumber'] ?? '')
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            (po['supplierName'] ?? '')
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
        bool matchesSupplier = _selectedSuppliers.isEmpty ||
            _selectedSuppliers.contains(po['supplierName'] ?? '');
        return matchesStatus && matchesSearch && matchesSupplier;
      }).toList();

      for (var po in approvedPOs) {
        Map<String, dynamic> poCopy = Map<String, dynamic>.from(po);
        if (po['lineItems'] != null) {
          poCopy['lineItems'] = List<dynamic>.from(
              po['lineItems'].map((item) => Map<String, dynamic>.from(item)));
        }
        _selectedPurchaseOrders.add(poCopy);
      }
    });
  }

  void _showPODetails(Map<String, dynamic> po) async {
    bool isSelected =
        _selectedPurchaseOrders.any((selected) => selected['id'] == po['id']);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => PODetailsDialog(
        purchaseOrder: po,
        isSelected: isSelected,
      ),
    );

    if (result == true) {
      _togglePurchaseOrderSelection(po);
    }
  }

  void _processItem(Map<String, dynamic> item, int index, int receivedQty,
      int damagedQty) async {

    // Get original saved values from database (not current local values)
    int originalReceived = 0;
    int originalDamaged = 0;
    bool isPartiallyReceived = false;

    // Find the original values from database by checking the po status
    for (var po in _selectedPurchaseOrders) {
      List<dynamic> lineItems = po['lineItems'] ?? [];
      for (var lineItem in lineItems) {
        if (lineItem['id'] == item['id']) {
          // Check if this PO has been partially received (has saved data in database)
          if (po['status'] == 'PARTIALLY_RECEIVED' ||
              po['status'] == 'COMPLETED') {
            // For partially received POs, get the saved values
            // These are the values that cannot be reduced
            originalReceived = lineItem['quantityReceived'] ?? 0;
            originalDamaged = lineItem['quantityDamaged'] ?? 0;
            isPartiallyReceived = true;
          } else {
            // For approved POs, there are no saved values yet
            originalReceived = 0;
            originalDamaged = 0;
            isPartiallyReceived = false;
          }
          break;
        }
      }
    }

    // Check if user is reducing quantity to 0 and has existing photos/reports
    bool hasExistingPhotos = false;
    
    // Check for existing discrepancy reports with photos
    for (var report in _localDiscrepancyReports) {
      if (report['lineItemId'] == item['id']) {
        List<dynamic> photos = report['photos'] ?? [];
        if (photos.isNotEmpty) {
          hasExistingPhotos = true;
          break;
        }
      }
    }
    
    // Show confirmation dialog if reducing to 0 with existing photos
    if ((receivedQty == 0 && damagedQty == 0) && hasExistingPhotos) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange[700]),
              const SizedBox(width: 8),
              const Text('Clear Photos?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('You have already uploaded photos for this item.'),
              const SizedBox(height: 8),
              const Text('If you reduce the quantity to 0, the photos and description will be cleared.'),
              const SizedBox(height: 8),
              const Text('Are you sure you want to continue?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Clear All'),
            ),
          ],
        ),
      );
      
      if (shouldProceed != true) {
        return; // User cancelled
      }
      
      // Clear existing reports and photos for this item
      _localDiscrepancyReports.removeWhere((report) => report['lineItemId'] == item['id']);
    }
    
    // Silently prevent reduction below original saved values for partially received POs
    if (isPartiallyReceived) {
      // Don't allow reducing below saved values - just return without updating
      if (receivedQty < originalReceived) {
        return; // Silently ignore
      }
      if (damagedQty < originalDamaged) {
        return; // Silently ignore
      }
    }

    // 🔧 FIX: IMMEDIATELY update local state - no database calls until final submit
      setState(() {
      item['quantityReceived'] = receivedQty;
      item['quantityDamaged'] = damagedQty;
      _updateLocalPOStatus();
    });

    // Update local PO status for UI purposes only
    _updateLocalPOStatus();

    // 🔧 FIX: Force UI rebuild after a brief delay to ensure all state changes are applied
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
      setState(() {
        });
      }
    });
  }

  void _reportDiscrepancy(Map<String, dynamic> item, int index) async {
    String? poId;
    String? lineItemId = item['id'];

    for (var po in _selectedPurchaseOrders) {
      List<dynamic> lineItems = po['lineItems'] ?? [];
      for (var lineItem in lineItems) {
        if (lineItem['id'] == lineItemId) {
          poId = po['id'];
          break;
        }
      }
      if (poId != null) break;
    }

    if (poId == null || lineItemId == null) {
      _snackbarManager.showErrorMessage(context, message: 'Error: Could not find PO or line item information');
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ReportDiscrepancyDialog(
        lineItem: item,
        lineItemIndex: index,
        poId: poId ?? '',
        lineItemId: lineItemId,
        productId: item['productId'] ?? '',
        productName: item['productName'] ?? '',
      ),
    );

    if (result != null) {
      setState(() {
        _localDiscrepancyReports.add(result);
      });
    }
  }

  // 🔧 FIXED: Only update local status for UI, no database calls
  void _updateLocalPOStatus() {

    for (var po in _selectedPurchaseOrders) {
      List<dynamic> lineItems = po['lineItems'] ?? [];
      bool allItemsProcessed = true;
      bool hasAnyProcessedItems = false;
      String originalStatus = po['status'] ?? 'APPROVED';

      for (var item in lineItems) {
        int ordered = item['quantityOrdered'] ?? 0;
        int received = item['quantityReceived'] ?? 0;
        int damaged = item['quantityDamaged'] ?? 0;

        if (received > 0 || damaged > 0) {
          hasAnyProcessedItems = true;
        }

        if (received + damaged < ordered) {
          allItemsProcessed = false;
        }
      }

      // Only update status for POs that were already partially received or completed
      // For APPROVED POs, keep them as APPROVED until final submission
      if (originalStatus == 'PARTIALLY_RECEIVED' || originalStatus == 'COMPLETED') {
        if (allItemsProcessed && hasAnyProcessedItems) {
          po['status'] = 'COMPLETED';
        } else if (hasAnyProcessedItems) {
          po['status'] = 'PARTIALLY_RECEIVED';
        }
      } else {
        // For APPROVED POs, keep the original status
        po['status'] = originalStatus;
      }
    }
  }

  bool _canProceedToReview() {
    if (_selectedPurchaseOrders.isEmpty) {
      return false;
    }

    bool hasAnyChanges = false;

    for (var po in _selectedPurchaseOrders) {
      List<dynamic> lineItems = po['lineItems'] ?? [];

      // Get original PO data for comparison
      var originalPO = _purchaseOrders.firstWhere(
        (originalPo) => originalPo['id'] == po['id'],
        orElse: () => po,
      );

      var originalLineItems = originalPO['lineItems'] as List<dynamic>? ?? [];

      for (var item in lineItems) {
        String itemId = item['id'] ?? '';
        int currentReceived = item['quantityReceived'] ?? 0;
        int currentDamaged = item['quantityDamaged'] ?? 0;

        // Find original values
        var originalItem = originalLineItems.firstWhere(
          (origItem) => origItem['id'] == itemId,
          orElse: () => {'quantityReceived': 0, 'quantityDamaged': 0},
        );

        int originalReceived = originalItem['quantityReceived'] ?? 0;
        int originalDamaged = originalItem['quantityDamaged'] ?? 0;

        // Check if values changed
        if (currentReceived != originalReceived ||
            currentDamaged != originalDamaged) {
          hasAnyChanges = true;
          break; // Found a change, no need to check more
        }
      }

      if (hasAnyChanges)
        break; // Found changes in this PO, no need to check more POs
    }

    return hasAnyChanges;
  }

  void _toggleAllReceived(
      Map<String, dynamic> po, int index, bool allReceived) {

    // Find the PO in the selected list
    var selectedPO = _selectedPurchaseOrders.firstWhere(
      (p) => p['id'] == po['id'],
      orElse: () => po,
    );

    List<dynamic> lineItems = selectedPO['lineItems'] ?? [];
    bool isPartiallyReceived = selectedPO['status'] == 'PARTIALLY_RECEIVED' ||
        selectedPO['status'] == 'COMPLETED';

    // Store original values for partially received POs
    Map<String, Map<String, int>> originalValues = {};
    if (isPartiallyReceived) {
      // Get original values from the source PO data
      var originalPO = _purchaseOrders.firstWhere(
        (originalPo) => originalPo['id'] == po['id'],
        orElse: () => po,
      );

      var originalLineItems = originalPO['lineItems'] as List<dynamic>? ?? [];
      for (var originalItem in originalLineItems) {
        String itemId = originalItem['id'] ?? '';
        originalValues[itemId] = {
          'received': originalItem['quantityReceived'] ?? 0,
          'damaged': originalItem['quantityDamaged'] ?? 0,
        };
      }
    }

    // Update all line items immediately
    for (var item in lineItems) {
      String itemId = item['id'] ?? '';
      int orderedQty = item['quantityOrdered'] ?? 0;
      int currentReceived = item['quantityReceived'] ?? 0;
      int currentDamaged = item['quantityDamaged'] ?? 0;

      if (allReceived) {
        // Mark remaining as received
        int remainingQty = orderedQty - currentReceived - currentDamaged;
        if (remainingQty > 0) {
          item['quantityReceived'] = currentReceived + remainingQty;
        }
      } else {
        // Reset to original or zero
        if (isPartiallyReceived && originalValues.containsKey(itemId)) {
          item['quantityReceived'] = originalValues[itemId]!['received']!;
          item['quantityDamaged'] = originalValues[itemId]!['damaged']!;
        } else {
          item['quantityReceived'] = 0;
          item['quantityDamaged'] = 0;
        }
      }
    }

    // Force immediate UI update
    setState(() {
      // Update local PO status
      _updateLocalPOStatus();
    });
  }

  void _printReceipt() {
    _snackbarManager.showValidationMessage(context, message: 'Please use the PDF generation feature in Step 4', backgroundColor: Colors.blue);
  }

  void _startNewReceiving() {
      setState(() {
      _currentStep = 0;
      _reviewSubStep = 0;
      _selectedPurchaseOrders.clear();
      _localDiscrepancyReports.clear(); // Also clear discrepancy reports
      _searchQuery = '';
      _selectedSuppliers.clear();
      _selectedTimeFilter = 'All Time';
      _currentPage = 0;
      _startDate = null;
      _endDate = null;
      _isFiltersExpanded = false; // Reset filter state
    });

    // Reset initialization flag and reinitialize
    _isInitialized = false;
    _initializeRealTimeUpdates();
  }

  Future<void> _handleCompleteReceiving() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
            children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Saving changes to database...'),
                ],
              ),
            ),
          ),
        ),
      );

      // NOW save all changes to database
      for (var po in _selectedPurchaseOrders) {
        List<dynamic> lineItems = po['lineItems'] ?? [];

        // Update each line item in database
        for (var item in lineItems) {
          String lineItemId = item['id'] ?? '';
          int currentReceived = item['quantityReceived'] ?? 0;
          int currentDamaged = item['quantityDamaged'] ?? 0;

          // Get original saved values to calculate increments
          int originalReceived = 0;
          int originalDamaged = 0;

          // Find original values from the original PO data
          var originalPO = _purchaseOrders.firstWhere(
            (originalPo) => originalPo['id'] == po['id'],
            orElse: () => po,
          );
          var originalLineItems =
              originalPO['lineItems'] as List<dynamic>? ?? [];
          for (var originalItem in originalLineItems) {
            if (originalItem['id'] == lineItemId) {
              originalReceived = originalItem['quantityReceived'] ?? 0;
              originalDamaged = originalItem['quantityDamaged'] ?? 0;
              break;
            }
          }

          // Calculate increments (only save the difference)
          int receivedIncrement = currentReceived - originalReceived;
          int damagedIncrement = currentDamaged - originalDamaged;

          // Only update if there are changes
          if (receivedIncrement != 0 || damagedIncrement != 0) {
            await _inventoryService.updateLineItemQuantities(
              poId: po['id'],
              lineItemId: lineItemId,
              quantityReceived: receivedIncrement,
              quantityDamaged: damagedIncrement,
            );
          }
        }

        // Update PO status
        bool allItemsCompleted = true;
        bool hasProcessedItems = false;

        for (var item in lineItems) {
          int ordered = item['quantityOrdered'] ?? 0;
          int received = item['quantityReceived'] ?? 0;
          int damaged = item['quantityDamaged'] ?? 0;

          if (received > 0 || damaged > 0) {
            hasProcessedItems = true;
          }

          if (received + damaged < ordered) {
            allItemsCompleted = false;
          }
        }

        String newStatus;
        if (allItemsCompleted && hasProcessedItems) {
          newStatus = 'COMPLETED';
        } else if (hasProcessedItems) {
          newStatus = 'PARTIALLY_RECEIVED';
        } else {
          newStatus = 'APPROVED';
        }

        await _inventoryService.updatePurchaseOrderStatusWithBroadcast(po['id'], newStatus);
      }

      // Save discrepancy reports
      if (_localDiscrepancyReports.isNotEmpty) {
        for (var po in _selectedPurchaseOrders) {
          var poReports = _localDiscrepancyReports
              .where((report) => report['poId'] == po['id'])
              .toList();
          if (poReports.isNotEmpty) {
            await _inventoryService.saveLocalDiscrepancyReportsToFirebase(
              poId: po['id'],
              localDiscrepancyReports: poReports,
            );
          }
        }
      }

      _localDiscrepancyReports.clear();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

        if (mounted && context.mounted) {
        _snackbarManager.showSuccessMessage(context, message: 'Successfully completed receiving process');
        setState(() => _currentStep = 3);
      }
    } catch (e) {
      // Close loading dialog
        if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted && context.mounted) {
        _snackbarManager.showErrorMessage(context, message: 'Error completing receiving: $e');
      }
    }
  }
}
