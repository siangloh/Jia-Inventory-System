import 'package:flutter/material.dart';
import '../../widgets/main_layout.dart';
import '../../services/adjustment/return_service.dart';
import '../../services/adjustment/snackbar_manager.dart';
import '../../services/adjustment/exit_guard_service.dart';
import '../../models/adjustment/return_stock.dart';
import 'return_stock/steps/select_item_step.dart';
import 'return_stock/steps/return_detail_step.dart';
import 'return_stock/steps/logistics_step.dart';
import 'return_stock/steps/review_complete_step.dart';
import 'lists/return_history_list_screen.dart';
import 'dart:async';
import 'dart:io';


class ReturnStockScreen extends StatefulWidget {
  const ReturnStockScreen({Key? key}) : super(key: key);

  @override
  State<ReturnStockScreen> createState() => _ReturnStockScreenState();
}

class _ReturnStockScreenState extends State<ReturnStockScreen> {
  final ReturnService _returnService = ReturnService();
  final SnackbarManager _snackbarManager = SnackbarManager();
  final ExitGuardService _exitGuardService = ExitGuardService();

  // Wizard state
  int _currentStep = 0;
  bool _hasUserInteracted = false;

  // Step 1: Select Damaged Items
  List<Map<String, dynamic>> _damagedItems = [];
  List<Map<String, dynamic>> _selectedItems = [];
  String _searchQuery = '';
  Timer? _searchDebounceTimer;
  String _selectedReturnType = ''; // AUTO-DETECTED based on items
  List<String> _selectedSuppliers = [];
  String _timeFilter = 'All Time';
  int _currentPage = 0;
  final int _itemsPerPage = 10;
  bool _isLoading = false;

  // Step 2: Return Details
  Map<String, Map<String, dynamic>> _itemDetails = {};
  // Structure: {itemId: {quantity: int, reason: String, condition: String, notes: String}}

  // Step 3: Logistics
  String _returnMethod = ''; // PICKUP, SHIP, DROP_OFF
  String _carrierName = '';
  String _trackingNumber = '';
  Map<String, dynamic> _pickupDetails = {};
  Map<String, dynamic> _shipmentDetails = {};
  List<File> _returnDocuments = [];

  // Step 4: Review & Submit
  bool _isSubmitting = false;
  String? _returnId;

  // Step configuration - Consistent numbered icons with proper colors
  final List<Map<String, dynamic>> _steps = [
    {
      'title': 'Select\nItems',
      'subtitle': 'Damaged',
      'icon': Icons.looks_one, // Number 1
      'color': Colors.blue, // Return = Blue
    },
    {
      'title': 'Return\nDetails',
      'subtitle': 'Specify',
      'icon': Icons.looks_two, // Number 2
      'color': Colors.blue, // Return = Blue
    },
    {
      'title': 'Logistics\nInfo',
      'subtitle': 'Shipping',
      'icon': Icons.looks_3, // Number 3
      'color': Colors.blue, // Return = Blue
    },
    {
      'title': 'Review\n& Submit',
      'subtitle': 'Confirm',
      'icon': Icons.looks_4, // Number 4
      'color': Colors.blue, // Return = Blue
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDamagedItems();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDamagedItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _returnService.getDamagedItemsFromDiscrepancies(
        timeFilter: _timeFilter,
        suppliers: _selectedSuppliers,
        excludeReturned: true, // Only show items that haven't been returned yet
      );
      setState(() {
        _damagedItems = items;
      });
    } catch (e) {
      if (mounted) {
        _snackbarManager.showErrorMessage(context,
            message: 'Error loading items: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Real-time search
  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      _hasUserInteracted = true;
    });

    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(Duration(milliseconds: 300), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    if (!mounted) return;

    try {
      final results = await _returnService.searchDamagedItems(query);
      if (mounted) {
        setState(() {
          _damagedItems = results;
          _currentPage = 0;
        });
      }
    } catch (e) {
      // Search error handled silently
    }
  }

  // Auto-detect return type based on selected items
  void _updateReturnType() {
    if (_selectedItems.isEmpty) {
      setState(() => _selectedReturnType = '');
      return;
    }

    // Check if all items are from supplier (have supplierId)
    bool allSupplierItems = _selectedItems.every((item) =>
        item['supplierId'] != null && item['supplierId'].toString().isNotEmpty);

    // Check if all items are internal damage
    bool allInternalItems = _selectedItems.every((item) =>
        item['discrepancyType'] == 'physicalDamage' &&
        item['rootCause']?.contains('Internal') == true);

    setState(() {
      if (allSupplierItems && !allInternalItems) {
        _selectedReturnType = 'SUPPLIER_RETURN';
      } else if (allInternalItems) {
        _selectedReturnType = 'INTERNAL_RETURN';
      } else {
        _selectedReturnType = 'MIXED_RETURN'; // Handle mixed scenarios
      }
    });
  }

  // Item selection
  void _onItemToggled(Map<String, dynamic> item) {
    setState(() {
      _hasUserInteracted = true;

      final itemId = item['id'] ?? item['productId'];
      final existingIndex = _selectedItems
          .indexWhere((i) => (i['id'] ?? i['productId']) == itemId);

      if (existingIndex >= 0) {
        _selectedItems.removeAt(existingIndex);
        _itemDetails.remove(itemId);
      } else {
        _selectedItems.add(item);
        // Initialize with default details
        _itemDetails[itemId] = {
          'quantity': item['quantityAffected'] ?? 1,
          'reason': _getDefaultReason(item),
          'condition': ReturnCondition.DAMAGED_UNUSABLE,
          'notes': '',
        };
      }

      _updateReturnType();
    });
  }

  String _getDefaultReason(Map<String, dynamic> item) {
    final discrepancyType = item['discrepancyType'] ?? '';
    switch (discrepancyType) {
      case 'manufacturingDefect':
        return 'Manufacturing defect - returning to supplier';
      case 'physicalDamage':
        return item['rootCause']?.contains('Internal') == true
            ? 'Internal handling damage'
            : 'Damaged in shipping';
      case 'wrongItem':
        return 'Wrong item delivered';
      default:
        return 'Quality issues';
    }
  }

  // Navigation
  Future<void> _handleBackNavigation() async {
    if (!_hasUserInteracted) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final shouldExit = await _exitGuardService.handleWorkflowExit(
      context: context,
      workflowName: 'Return Stock',
      currentStep: _currentStep,
      totalSteps: _steps.length,
      stepName: _getCurrentStepName(),
    );

    if (shouldExit && mounted) {
      Navigator.pop(context);
    }
  }

  String _getCurrentStepName() {
    return _steps[_currentStep]['title']!.replaceAll('\n', ' ') +
        ' ' +
        _steps[_currentStep]['subtitle']!;
  }

  // Validation
  bool _canProceedFromStep(int step) {
    switch (step) {
      case 0:
        return _selectedItems.isNotEmpty;
      case 1:
        return _validateReturnDetails();
      case 2:
        return _validateLogistics();
      case 3:
        return true;
      default:
        return false;
    }
  }

  bool _validateReturnDetails() {
    if (_selectedItems.isEmpty) return false;

    for (var item in _selectedItems) {
      final itemId = item['id'] ?? item['productId'];
      final details = _itemDetails[itemId];
      if (details == null) return false;
      if ((details['quantity'] ?? 0) <= 0) return false;
      if ((details['reason'] ?? '').isEmpty) return false;
      if ((details['condition'] ?? '').isEmpty) return false;
    }
    return true;
  }

  bool _validateLogistics() {
    if (_returnMethod.isEmpty) return false;

    switch (_returnMethod) {
      case 'PICKUP':
        return _pickupDetails['date'] != null &&
            _pickupDetails['timeSlot'] != null;
      case 'SHIP':
        return _carrierName.isNotEmpty && _shipmentDetails['address'] != null;
      case 'DROP_OFF':
        return _shipmentDetails['location'] != null;
      default:
        return false;
    }
  }

  // Submit return
  Future<void> _submitReturn() async {
    setState(() => _isSubmitting = true);

    try {
      // Prepare return data with proper structure
      final returnData = {
        'returnType': _selectedReturnType,
        'items': _selectedItems,
        'itemDetails': _itemDetails,
        'returnMethod': _returnMethod,
        'carrierName': _carrierName,
        'trackingNumber': _trackingNumber,
        'pickupDetails': _pickupDetails,
        'shipmentDetails': _shipmentDetails,
        'documents': [], // Will be uploaded to Supabase
      };

      // Process return
      final result = await _returnService.createReturn(returnData);
      _returnId = result['returnId'];

      // Upload documents if any
      if (_returnDocuments.isNotEmpty) {
        await _returnService.uploadReturnDocuments(
            _returnId!, _returnDocuments);
      }

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        _snackbarManager.showErrorMessage(context, message: 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Return Submitted'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Return ID: $_returnId'),
            SizedBox(height: 8),
            Text('Type: $_selectedReturnType'),
            SizedBox(height: 8),
            Text('Items: ${_selectedItems.length}'),
            if (_trackingNumber.isNotEmpty) ...[
              SizedBox(height: 8),
              Text('Tracking: $_trackingNumber'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Remove all previous screens from stack and go to return history
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const MainLayout(
                    title: 'Return History',
                    currentRoute: 'adjustment',
                    showSearch: false,
                    child: ReturnHistoryListScreen(),
                  ),
                ),
                (route) => route
                    .isFirst, // Keep only the very first screen (main menu)
              );
            },
            child: Text('View History'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _resetFlow(); // Start new return
            },
            child: Text('New Return'),
          ),
        ],
      ),
    );
  }

  void _resetFlow() {
    setState(() {
      _currentStep = 0;
      _selectedItems.clear();
      _itemDetails.clear();
      _returnMethod = '';
      _carrierName = '';
      _trackingNumber = '';
      _pickupDetails.clear();
      _shipmentDetails.clear();
      _returnDocuments.clear();
      _hasUserInteracted = false;
      _returnId = null;
    });
    _loadDamagedItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            physics: ClampingScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),

              // Wizard
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

              // Step content
              ..._buildCurrentStepSlivers(),

              // Bottom padding
              if (_shouldShowBottomBar())
                SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
            ],
          ),

          // Sticky bottom bar
          if (_shouldShowBottomBar())
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
                  'Process Returns',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Return damaged items to suppliers or process internally',
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
                color: _selectedReturnType == 'SUPPLIER_RETURN'
                    ? Colors.red[100]
                    : Colors.blue[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_selectedItems.length} items',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _selectedReturnType == 'SUPPLIER_RETURN'
                      ? Colors.red[700]
                      : Colors.blue[700],
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
                // ENHANCED: Full-width background line
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    color: Colors.grey[300],
                  ),
                ),

                // ENHANCED: Full-width progress line
                Positioned(
                  top: 20,
                  left: 0,
                  child: Container(
                    width: _currentStep == 0
                        ? 0 // No progress line on first step
                        : _currentStep >= _steps.length - 1
                            ? MediaQuery.of(context)
                                .size
                                .width // Full width on last step
                            : (MediaQuery.of(context).size.width /
                                    (_steps.length - 1)) *
                                _currentStep, // Progress to current step
                    height: 2,
                    color: _steps[_currentStep]['color'],
                  ),
                ),

                // Step indicators
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
                                  ? Colors.green
                                  : isCurrent
                                      ? step['color']
                                      : Colors.white,
                              border: Border.all(
                                color: isCompleted
                                    ? Colors.green
                                    : isCurrent
                                        ? step['color']
                                        : Colors.grey[300]!,
                                width: 2,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: isCompleted
                                  ? Icon(Icons.check,
                                      color: Colors.white, size: 20)
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
                                  ? step['color']
                                  : isCompleted
                                      ? Colors.green
                                      : Colors.grey[600],
                            ),
                            maxLines: 2,
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
        children: [
          Expanded(
            child: Text(
              'Step ${_currentStep + 1}: ${_getCurrentStepName()}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _steps[_currentStep]['color'],
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
                      ? Colors.green
                      : isCurrent
                          ? _steps[index]['color']
                          : Colors.white,
                  border: Border.all(
                    color: isCompleted
                        ? Colors.green
                        : isCurrent
                            ? _steps[index]['color']
                            : Colors.grey[300]!,
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check, color: Colors.white, size: 14)
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
        return SelectDamagedItemsStep.buildSlivers(
          damagedItems: _damagedItems,
          selectedItems: _selectedItems,
          isLoading: _isLoading,
          searchQuery: _searchQuery,
          selectedSuppliers: _selectedSuppliers,
          timeFilter: _timeFilter,
          currentPage: _currentPage,
          itemsPerPage: _itemsPerPage,
          returnType: _selectedReturnType,
          onSearchChanged: _performSearch,
          onItemToggled: _onItemToggled,
          onSuppliersChanged: (suppliers) {
            setState(() => _selectedSuppliers = suppliers);
            _loadDamagedItems();
          },
          onTimeFilterChanged: (filter) {
            setState(() => _timeFilter = filter);
            _loadDamagedItems();
          },
          onPageChanged: (page) => setState(() => _currentPage = page),
          onSelectAll: () {
            setState(() {
              _selectedItems = List.from(_damagedItems);
              for (var item in _damagedItems) {
                final itemId = item['id'] ?? item['productId'];
                _itemDetails[itemId] = {
                  'quantity': item['quantityAffected'] ?? 1,
                  'reason': _getDefaultReason(item),
                  'condition': ReturnCondition.DAMAGED_UNUSABLE,
                  'notes': '',
                };
              }
              _updateReturnType();
            });
          },
          onClearAll: () {
            setState(() {
              _selectedItems.clear();
              _itemDetails.clear();
              _selectedReturnType = '';
            });
          },
          context: context,
        );

      case 1:
        return ReturnDetailsStep.buildSlivers(
          selectedItems: _selectedItems,
          itemDetails: _itemDetails,
          returnType: _selectedReturnType,
          onDetailsUpdated: (itemId, details) {
            setState(() {
              _itemDetails[itemId] = details;
              _hasUserInteracted = true;
            });
          },
          context: context,
        );

      case 2:
        return LogisticsStep.buildSlivers(
          returnType: _selectedReturnType,
          selectedItems: _selectedItems,
          returnMethod: _returnMethod,
          carrierName: _carrierName,
          trackingNumber: _trackingNumber,
          pickupDetails: _pickupDetails,
          shipmentDetails: _shipmentDetails,
          returnDocuments: _returnDocuments,
          onReturnMethodChanged: (method) {
            setState(() {
              _returnMethod = method;
              _hasUserInteracted = true;
            });
          },
          onCarrierNameChanged: (name) {
            setState(() => _carrierName = name);
          },
          onTrackingNumberChanged: (number) {
            setState(() => _trackingNumber = number);
          },
          onPickupDetailsChanged: (details) {
            setState(() => _pickupDetails = details);
          },
          onShipmentDetailsChanged: (details) {
            setState(() => _shipmentDetails = details);
          },
          onDocumentsChanged: (docs) {
            setState(() => _returnDocuments = docs);
          },
          context: context,
        );

      case 3:
        return ReviewSubmitStep.buildSlivers(
          selectedItems: _selectedItems,
          itemDetails: _itemDetails,
          returnType: _selectedReturnType,
          returnMethod: _returnMethod,
          carrierName: _carrierName,
          trackingNumber: _trackingNumber,
          pickupDetails: _pickupDetails,
          shipmentDetails: _shipmentDetails,
          returnDocuments: _returnDocuments,
          isSubmitting: _isSubmitting,
          context: context,
        );

      default:
        return [SliverToBoxAdapter(child: Container())];
    }
  }

  bool _shouldShowBottomBar() {
    return true; // Always show for navigation
  }

  Widget _buildBottomBar() {
    bool canProceed = _canProceedFromStep(_currentStep);

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
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _currentStep--),
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
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: canProceed
                  ? () {
                      if (_currentStep < _steps.length - 1) {
                        setState(() => _currentStep++);
                      } else {
                        _submitReturn();
                      }
                    }
                  : null,
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
                      _currentStep == _steps.length - 1
                          ? Icons.check_circle
                          : Icons.arrow_forward,
                      size: 18,
                    ),
              label: Text(
                _isSubmitting
                    ? 'Processing...'
                    : _currentStep == _steps.length - 1
                        ? 'Submit Return'
                        : _getNextButtonText(),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: canProceed
                    ? (_currentStep == _steps.length - 1
                        ? Colors.green
                        : _steps[_currentStep]['color'])
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
  }

  String _getNextButtonText() {
    switch (_currentStep) {
      case 0:
        return 'Enter Details (${_selectedItems.length})';
      case 1:
        return 'Setup Logistics';
      case 2:
        return 'Review Return';
      default:
        return 'Next';
    }
  }
}
