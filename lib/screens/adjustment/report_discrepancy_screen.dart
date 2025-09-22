import 'package:flutter/material.dart';
import '../../services/adjustment/discrepancy_service.dart';
import '../../services/adjustment/snackbar_manager.dart';
import '../../services/adjustment/exit_guard_service.dart';
import 'report_discrepancy/steps/select_po_step.dart';
import 'report_discrepancy/steps/select_line_item_step.dart';
import 'report_discrepancy/steps/report_details_step.dart';
import 'report_discrepancy/steps/review_submit_step.dart';
import 'dart:async';
import 'dart:io';

class ReportDiscrepancyScreen extends StatefulWidget {
  const ReportDiscrepancyScreen({Key? key}) : super(key: key);

  @override
  State<ReportDiscrepancyScreen> createState() => _ReportDiscrepancyScreenState();
}

class _ReportDiscrepancyScreenState extends State<ReportDiscrepancyScreen> {
  final DiscrepancyService _discrepancyService = DiscrepancyService();
  final SnackbarManager _snackbarManager = SnackbarManager();
  final ExitGuardService _exitGuardService = ExitGuardService();
  
  // Wizard state
  int _currentStep = 0;
  int _reviewSubStep = 0;
  
  // Data state
  List<Map<String, dynamic>> _filteredPurchaseOrders = [];
  List<Map<String, dynamic>> _selectedItems = [];
  
  // Search state with debounce
  String _searchQuery = '';
  Timer? _searchDebounceTimer;
  
  // Filter state
  List<String> _selectedSuppliers = [];
  String _selectedTimeFilter = 'All Time';
  bool _isFiltersExpanded = false;
  int _currentPage = 0;
  final int _itemsPerPage = 5;
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Pagination for Step 2
  int _itemsPage = 0;
  final int _itemsPerPageStep2 = 5;
  
  List<String> _suppliers = [];
  final List<String> _timeFilters = [
    'All Time',
    'Last 7 Days', 
    'This Month',
    'Custom Date Range'
  ];
  
  // Discrepancy details
  String _discrepancyType = '';
  String _description = '';
  List<File> _localPhotoFiles = []; // Changed from List<String> to List<File>
  
  // Item quantities
  Map<String, int> _itemQuantities = {};
  
  // Loading states
  bool _isLoading = false;
  bool _isSubmitting = false;
  
  // Change tracking
  bool _hasUserInteracted = false;
  
  // Step configuration
  final List<Map<String, String>> _steps = [
    {'title': 'Identify\nItems', 'subtitle': 'Affected'},
    {'title': 'Specify\nQuantities', 'subtitle': 'Affected'},
    {'title': 'Document\nIssue', 'subtitle': 'Details'},
    {'title': 'Review\n& Submit', 'subtitle': 'Report'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPurchaseOrders();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  // Load initial data
  Future<void> _loadPurchaseOrders() async {
    setState(() => _isLoading = true);
    try {
      final orders = await _discrepancyService.getPurchaseOrdersWithReceivedItems();
      
      setState(() {
        _filteredPurchaseOrders = orders;
        _suppliers = orders
            .map((po) => po['supplierName']?.toString() ?? '')
            .toSet()
            .where((s) => s.isNotEmpty)
            .toList();
      });
      
    } catch (e) {
      if (mounted) {
        _snackbarManager.showErrorMessage(context, message: 'Error loading data: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Real-time search without page reload
  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      _hasUserInteracted = true;
    });

    // Cancel previous timer
    _searchDebounceTimer?.cancel();
    
    // No debounce - immediate search
    _executeSearch(query);
  }

  Future<void> _executeSearch(String query) async {
    if (!mounted) return;
    
    try {
      final results = await _discrepancyService.searchItemsRealtime(query);
      if (mounted) {
        setState(() {
          _filteredPurchaseOrders = results;
          _currentPage = 0; // Reset to first page
        });
      }
    } catch (e) {
      // Search error handled silently
    }
  }

  // Handle exit navigation
  Future<void> _handleBackNavigation() async {
    // Clean up any pending operations
    _searchDebounceTimer?.cancel();
    
    if (!_hasUserInteracted || _currentStep == 0) {
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }
    
    final shouldExit = await _exitGuardService.handleWorkflowExit(
      context: context,
      workflowName: 'Report Discrepancy',
      currentStep: _currentStep,
      totalSteps: _steps.length,
      stepName: _getCurrentStepName(),
    );
    
    if (shouldExit && mounted) {
      // Use pushReplacementNamed to avoid navigation stack issues
      Navigator.pushReplacementNamed(context, '/adjustment-hub');
    }
  }

  Future<void> _handleStepBackNavigation() async {
    if (_currentStep == 3 && _reviewSubStep == 1) {
      setState(() => _reviewSubStep = 0);
    } else if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        if (_currentStep == 1) {
          _itemsPage = 0; // Reset items pagination
        }
      });
    }
  }

  String _getCurrentStepName() {
    switch (_currentStep) {
      case 0:
        return 'Identify Affected Items';
      case 1:
        return 'Specify Quantities';
      case 2:
        return 'Document Issue';
      case 3:
        return _reviewSubStep == 0 ? 'Review Checklist' : 'Final Summary';
      default:
        return '';
    }
  }

  // Item selection
  void _onItemSelected(Map<String, dynamic> item) {
    setState(() {
      _hasUserInteracted = true;
      
      final itemKey = '${item['poId']}_${item['itemId']}';
      final existingIndex = _selectedItems.indexWhere((selectedItem) => 
        selectedItem['poId'] == item['poId'] && 
        selectedItem['itemId'] == item['itemId']
      );
      
      if (existingIndex >= 0) {
        _selectedItems.removeAt(existingIndex);
        _itemQuantities.remove(itemKey);
      } else {
        // Ensure we have all the enhanced data fields
        final enhancedItem = {
          'poId': item['poId'],
          'poNumber': item['poNumber'],
          'itemId': item['itemId'],
          'productId': item['productId'],
          'productName': item['productName'] ?? 'Unknown Product',
          'category': item['category'] ?? 'Unknown Category',
          'brand': item['brand'] ?? 'Unknown Brand',
          'quantityAvailable': item['quantityAvailable'] ?? 0,
          'unitPrice': item['unitPrice'] ?? 0.0,
          'supplierName': item['supplierName'] ?? '',
        };
        _selectedItems.add(enhancedItem);
        _itemQuantities[itemKey] = enhancedItem['quantityAvailable'] ?? 1;
      }
    });
  }

  void _selectAllItems() {
    setState(() {
      _hasUserInteracted = true;
      _selectedItems.clear();
      _itemQuantities.clear();
      
      for (var po in _filteredPurchaseOrders) {
        List<dynamic> lineItems = po['lineItems'] ?? [];
        for (var item in lineItems) {
          if ((item['availableQuantity'] ?? 0) > 0) {
            // Use the enhanced item data that already has proper product names
            final itemData = {
              'poId': po['id'],
              'poNumber': po['poNumber'],
              'itemId': item['id'] ?? item['productId'],
              'productId': item['productId'], // Keep productId for reference
              'productName': item['productName'] ?? 'Unknown Product',
              'category': item['category'] ?? 'Unknown Category',
              'brand': item['brand'] ?? 'Unknown Brand',
              'quantityAvailable': item['availableQuantity'] ?? 0,
              'unitPrice': item['unitPrice'] ?? 0.0,
              'supplierName': po['supplierName'] ?? '',
            };
            _selectedItems.add(itemData);
            final itemKey = '${itemData['poId']}_${itemData['itemId']}';
            _itemQuantities[itemKey] = itemData['quantityAvailable'] ?? 1;
          }
        }
      }
    });
  }

  void _clearAllSelection() {
    setState(() {
      _selectedItems.clear();
      _itemQuantities.clear();
      _hasUserInteracted = true;
    });
  }

  // Check if can proceed from each step
  bool _canProceedFromStep(int step) {
    switch (step) {
      case 0:
        return _selectedItems.isNotEmpty;
      case 1:
        return _selectedItems.isNotEmpty && _itemQuantities.isNotEmpty;
      case 2:
        return _discrepancyType.isNotEmpty && _description.trim().isNotEmpty;
      case 3:
        return true; // Review step always can proceed
      default:
        return false;
    }
  }

  // Submit discrepancy report
  Future<void> _submitDiscrepancyReport() async {
    setState(() => _isSubmitting = true);

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red[400]!),
                ),
                SizedBox(height: 20),
                Text(
                  'Submitting Report...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Uploading ${_localPhotoFiles.length} photo(s)',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      List<Map<String, dynamic>> itemsToReport = [];
      for (final item in _selectedItems) {
        final itemKey = '${item['poId']}_${item['itemId']}';
        itemsToReport.add({
          ...item,
          'quantity': _itemQuantities[itemKey] ?? 1,
        });
      }

      final reportId = await _discrepancyService.createMultiItemDiscrepancyReport(
        items: itemsToReport,
        discrepancyType: _discrepancyType,
        description: _description,
        localPhotoFiles: _localPhotoFiles,
        staffId: 'EMP0001',
        staffName: 'Current User',
      );

      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        
        // Show success dialog with report ID
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green[600],
                size: 48,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Report Submitted Successfully!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Report ID: $reportId',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
            Navigator.pushReplacementNamed(context, '/adjustment/discrepancy-reports-list');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text('View Reports'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red[600], size: 24),
                SizedBox(width: 12),
                Text('Submission Failed'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Failed to submit discrepancy report.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(
                    e.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            physics: ClampingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildSubHeader(),
              ),
              SliverAppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                pinned: true,
                floating: false,
                snap: false,
                expandedHeight: 130.0,
                collapsedHeight: 65.0,
                automaticallyImplyLeading: false,
                toolbarHeight: 0,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                flexibleSpace: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final expandedHeight = 130.0;
                    final collapsedHeight = 65.0;
                    final currentHeight = constraints.maxHeight;
                    final shrinkRatio = ((expandedHeight - currentHeight) /
                            (expandedHeight - collapsedHeight))
                        .clamp(0.0, 1.0);
                    return Container(
                      color: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 4),
                      alignment: Alignment.center,
                      child: shrinkRatio < 0.5
                          ? _buildExpandedWizard(shrinkRatio)
                          : _buildCollapsedWizard(shrinkRatio),
                    );
                  },
                ),
              ),
              ..._buildCurrentStepSlivers(),
              if (_shouldShowStickyBottomBar())
                SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
            ],
          ),
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
            onPressed: _handleBackNavigation,
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
                  'Report Discrepancy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Document and report inventory issues',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (_selectedItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_selectedItems.length} items',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[700],
                ),
              ),
            ),
        ],
      ),
    );
  }

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
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                // ENHANCED: Progress line fills full width and extends to current step
                Positioned(
                  top: 20,
                  left: 0,
                  child: Container(
                    width: _currentStep == 0 
                        ? 0 // No progress line on first step
                        : _currentStep >= _steps.length - 1
                            ? MediaQuery.of(context).size.width // Full width on last step
                            : (MediaQuery.of(context).size.width / (_steps.length - 1)) * _currentStep, // Progress to current step
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.red[400],
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
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
                                  ? Color(0xFF10B981)
                                  : isCurrent
                                      ? Colors.red[400]
                                      : Colors.white,
                              border: Border.all(
                                color: isCompleted
                                    ? Color(0xFF10B981)
                                    : isCurrent
                                        ? Colors.red[400]!
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
                              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                              color: isCurrent
                                  ? Colors.red[400]
                                  : isCompleted
                                      ? Color(0xFF10B981)
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              'Step ${_currentStep + 1}: ${_getCurrentStepName()}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.red[400],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
                      ? Color(0xFF10B981)
                      : isCurrent
                          ? Colors.red[400]
                          : Colors.white,
                  border: Border.all(
                    color: isCompleted
                        ? Color(0xFF10B981)
                        : isCurrent
                            ? Colors.red[400]!
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
        return SelectPOStep.buildSlivers(
          purchaseOrders: _filteredPurchaseOrders,
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
          onSearchChanged: _performSearch,
          onSuppliersChanged: (suppliers) {
            _hasUserInteracted = true;
            setState(() {
              _selectedSuppliers = suppliers;
              _currentPage = 0;
            });
          },
          onTimeFilterChanged: (filter) {
            _hasUserInteracted = true;
            setState(() {
              _selectedTimeFilter = filter;
              _currentPage = 0;
              if (filter != 'Custom Date Range') {
                _startDate = null;
                _endDate = null;
              }
            });
          },
          onToggleFilters: () => setState(() => _isFiltersExpanded = !_isFiltersExpanded),
          onPageChanged: (page) => setState(() => _currentPage = page),
          onDateRangeChanged: (range) {
            _hasUserInteracted = true;
            setState(() {
              _startDate = range?.start;
              _endDate = range?.end;
              _currentPage = 0;
            });
          },
          onItemSelected: _onItemSelected,
          selectedItems: _selectedItems,
          onClearAllSelection: _clearAllSelection,
          onSelectAllItems: _selectAllItems,
          context: context,
        );

      case 1:
        return SelectLineItemStep.buildSlivers(
          selectedItems: _selectedItems,
          itemQuantities: _itemQuantities,
          currentPage: _itemsPage,
          itemsPerPage: _itemsPerPageStep2,
          onQuantityChanged: (item, quantity) {
            _hasUserInteracted = true;
            setState(() {
              final itemKey = '${item['poId']}_${item['itemId']}';
              _itemQuantities[itemKey] = quantity;
            });
          },
          onPageChanged: (page) => setState(() => _itemsPage = page),
          context: context,
        );

      case 2:
        return ReportDetailsStep.buildSlivers(
          selectedItems: _selectedItems,
          itemQuantities: _itemQuantities,
          discrepancyType: _discrepancyType,
          description: _description,
          localPhotoFiles: _localPhotoFiles,
          onDiscrepancyTypeChanged: (type) {
            _hasUserInteracted = true;
            setState(() {
              _discrepancyType = type;
            });
          },
          onDescriptionChanged: (desc) {
            _hasUserInteracted = true;
            setState(() {
              _description = desc;
            });
          },
          onPhotoFilesChanged: (photoFiles) {
            _hasUserInteracted = true;
            setState(() {
              _localPhotoFiles = photoFiles;
            });
          },
          context: context,
        );

      case 3:
        if (_reviewSubStep == 0) {
          return ReviewSubmitStep.buildChecklistSlivers(
            selectedItems: _selectedItems,
            itemQuantities: _itemQuantities,
            discrepancyType: _discrepancyType,
            description: _description,
            localPhotoFiles: _localPhotoFiles,
            context: context,
          );
        } else {
          return ReviewSubmitStep.buildSummarySlivers(
            selectedItems: _selectedItems,
            itemQuantities: _itemQuantities,
            discrepancyType: _discrepancyType,
            description: _description,
            localPhotoFiles: _localPhotoFiles,
            context: context,
          );
        }

      default:
        return [SliverToBoxAdapter(child: Container())];
    }
  }

  bool _shouldShowStickyBottomBar() {
    return true;
  }

  Widget _buildStickyBottomBar() {
    bool canProceed = _canProceedFromStep(_currentStep);
    
    switch (_currentStep) {
      case 0:
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
              if (_selectedItems.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.red[400], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_selectedItems.length} Item${_selectedItems.length != 1 ? 's' : ''} Selected',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.red[600],
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
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canProceed
                    ? () => setState(() => _currentStep = 1)
                    : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canProceed 
                      ? Colors.red[400] 
                      : Colors.grey[300],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    canProceed
                      ? 'Specify Quantities'
                      : 'Select Items to Continue',
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

      case 1:
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
                  onPressed: canProceed
                    ? () => setState(() => _currentStep = 2)
                    : null,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Document Issue'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canProceed
                      ? Colors.red[400]
                      : Colors.grey[300],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      case 2:
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
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: canProceed
                      ? () => setState(() {
                            _currentStep = 3;
                            _reviewSubStep = 0;
                          })
                      : null,
                  icon: Icon(canProceed ? Icons.check_circle : Icons.lock, size: 18),
                  label: Text(canProceed ? 'Review Report' : 'Complete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canProceed ? Colors.green : Colors.grey[300],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        );

      case 3:
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
                  onPressed: () {
                    if (_reviewSubStep == 0) {
                      setState(() => _currentStep = 2);
                    } else {
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
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          if (_reviewSubStep == 0) {
                            setState(() => _reviewSubStep = 1);
                          } else {
                            _submitDiscrepancyReport();
                          }
                        },
                  icon: _isSubmitting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(
                          _reviewSubStep == 0
                              ? Icons.summarize
                              : Icons.check_circle,
                          size: 18,
                        ),
                  label: Text(_isSubmitting
                      ? 'Submitting...'
                      : _reviewSubStep == 0
                          ? 'View Summary'
                          : 'Submit Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
}