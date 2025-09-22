// lib/screens/receive_inventory/receive_inventory_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:assignment/models/purchase_order.dart';
import 'package:assignment/models/warehouse_location.dart';
import 'package:assignment/services/purchase_order/purchase_order_service.dart';
import 'package:assignment/services/warehouse/warehouse_allocation_service.dart';
import 'dart:async';
import 'package:assignment/models/product_model.dart';

class ReceiveInventoryScreenWithAllocation extends StatefulWidget {
  const ReceiveInventoryScreenWithAllocation({super.key});

  @override
  State<ReceiveInventoryScreenWithAllocation> createState() => _ReceiveInventoryScreenWithAllocationState();
}

extension FirstWhereOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
enum StatusChangeSeverity {
  WARNING,
  CRITICAL,
}
enum InventoryStep {
  PO_SELECTION,
  PRODUCT_SELECTION,
  PLACEMENT_REVIEW,
  PROCESSING
}

class _ReceiveInventoryScreenWithAllocationState extends State<ReceiveInventoryScreenWithAllocation> {
  final PurchaseOrderService _purchaseOrderService = PurchaseOrderService();
  final WarehouseAllocationService _warehouseService = WarehouseAllocationService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _quantityController = TextEditingController();


  InventoryStep currentStep = InventoryStep.PO_SELECTION;
  Timer? _statusCheckTimer;
  bool _isStatusValidationEnabled = true;
  String? _lastKnownValidStatus;

  // State variables
  List<PurchaseOrder> availablePOs = [];
  PurchaseOrder? selectedPO;
  POLineItem? selectedLineItem;
  Product? selectedProduct;

  List<POLineItem> availableLineItems = [];
  List<POLineItem> selectedLineItems = [];
  Map<String, Product> productCache = {};
  Map<String, int> receivingQuantities = {};
  Map<String, StorageAllocationResult> allocationResults = {};
  Map<String, List<WarehouseLocation>> productAllocationOptions = {};
  Map<String, WarehouseLocation?> selectedPlacements = {};
  bool showPlacementReview = false;

  bool isLoading = true;
  bool isProcessing = false;
  String? errorMessage;

  // Warehouse allocation state
  StorageAllocationResult? allocationResult;
  WarehouseLocation? selectedLocation;
  bool showAllocationResults = false;
  bool isAllocating = false;

  StreamSubscription<List<PurchaseOrder>>? _purchaseOrderSubscription;

  // Category icons and colors
  static const Map<String, IconData> categoryIcons = {
    'engine': Icons.precision_manufacturing,
    'brake': Icons.radio_button_checked,
    'electrical': Icons.electrical_services,
    'body': Icons.directions_car,
  };

  static const Map<String, Color> categoryColors = {
    'engine': Colors.red,
    'brake': Colors.orange,
    'electrical': Colors.purple,
    'body': Colors.green,
  };

  @override
  void initState() {
    super.initState();
    _initializeSystem();
  }

  @override
  void dispose() {
    _purchaseOrderSubscription?.cancel();
    _quantityController.dispose();
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeSystem() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Check if warehouse is initialized
      final isWarehouseReady = await _warehouseService.isWarehouseInitialized();

      if (!isWarehouseReady) {
        print('Initializing warehouse locations...');
        await _warehouseService.initializeWarehouseLocations();
        _showMessage('Warehouse system initialized successfully!', Colors.green);
      }

      // Start real-time updates
      _initializeRealtimeUpdates();

    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to initialize system: $e';
      });
    }
  }

  void _initializeRealtimeUpdates() {
    print('Setting up enhanced real-time updates for receive inventory...');

    _purchaseOrderSubscription = _purchaseOrderService.getPurchaseOrdersStream().listen(
          (allPOs) {
        final receivablePOs = allPOs.where((po) =>
        po.status == POStatus.COMPLETED ||
            po.status == POStatus.PARTIALLY_RECEIVED
        ).toList();

        // Handle changes to currently selected PO
        if (selectedPO != null && _isStatusValidationEnabled) {
          _handleSelectedPOStatusChange(allPOs);
        }

        setState(() {
          availablePOs = receivablePOs;
          isLoading = false;
          errorMessage = null;
        });
      },
      onError: (error) {
        setState(() {
          isLoading = false;
          errorMessage = 'Real-time updates failed: $error';
        });
      },
    );

    // Set up periodic validation for critical steps
    _setupPeriodicStatusValidation();
  }

  void _handleSelectedPOStatusChange(List<PurchaseOrder> allPOs) {
    final updatedSelectedPO = allPOs.where((po) => po.id == selectedPO!.id).firstOrNull;

    if (updatedSelectedPO == null) {
      _handlePODeleted();
      return;
    }

    final oldStatus = selectedPO!.status;
    final newStatus = updatedSelectedPO.status;

    // Status hasn't changed, just update the PO data
    if (oldStatus == newStatus) {
      setState(() {
        selectedPO = updatedSelectedPO;
      });
      return;
    }

    // Handle different status change scenarios based on current step
    _handleStatusChangeByStep(updatedSelectedPO, oldStatus, newStatus);
  }

  void _handleStatusChangeByStep(PurchaseOrder updatedPO, POStatus oldStatus, POStatus newStatus) {
    switch (currentStep) {
      case InventoryStep.PO_SELECTION:
      // User is still on PO selection - just update the list
        setState(() {
          selectedPO = null; // Clear selection to refresh the view
        });
        break;

      case InventoryStep.PRODUCT_SELECTION:
        _handleStatusChangeInProductSelection(updatedPO, oldStatus, newStatus);
        break;

      case InventoryStep.PLACEMENT_REVIEW:
        _handleStatusChangeInPlacementReview(updatedPO, oldStatus, newStatus);
        break;

      case InventoryStep.PROCESSING:
        _handleStatusChangeWhileProcessing(updatedPO, oldStatus, newStatus);
        break;
    }
  }

  void _handleStatusChangeInProductSelection(PurchaseOrder updatedPO, POStatus oldStatus, POStatus newStatus) {
    // Check if new status still allows receiving
    if (_isStatusValidForReceiving(newStatus)) {
      // Update PO data but continue with current selection
      setState(() {
        selectedPO = updatedPO;
      });

      if (newStatus != oldStatus) {
        _showStatusChangeWarning(oldStatus, newStatus, false);
      }
    } else {
      // Status no longer valid - clear selection and notify user
      _showStatusChangeDialog(
        title: 'Purchase Order Status Changed',
        message: 'PO ${updatedPO.poNumber} status changed from ${_formatStatus(oldStatus)} to ${_formatStatus(newStatus)}.\n\nThis PO is no longer available for receiving.',
        onConfirm: () {
          _clearSelection();
          Navigator.of(context).pop();
        },
      );
    }
  }

  void _handleStatusChangeInPlacementReview(PurchaseOrder updatedPO, POStatus oldStatus, POStatus newStatus) {
    if (_isStatusValidForReceiving(newStatus)) {
      // Continue with placement but warn user
      setState(() {
        selectedPO = updatedPO;
      });
      _showStatusChangeWarning(oldStatus, newStatus, true);
    } else {
      // Critical status change - stop placement process
      _showStatusChangeDialog(
        title: 'Cannot Complete Placement',
        message: 'PO ${updatedPO.poNumber} status changed to ${_formatStatus(newStatus)} during placement review.\n\nPlacement has been cancelled for safety.',
        onConfirm: () {
          _clearSelection();
          Navigator.of(context).pop();
        },
        severity: StatusChangeSeverity.CRITICAL,
      );
    }
  }

  void _handleStatusChangeWhileProcessing(PurchaseOrder updatedPO, POStatus oldStatus, POStatus newStatus) {
    if (!_isStatusValidForReceiving(newStatus)) {
      // Critical - stop processing immediately
      setState(() {
        isProcessing = false;
        _isStatusValidationEnabled = false; // Prevent further interruptions
      });

      _showStatusChangeDialog(
        title: 'Processing Interrupted',
        message: 'PO ${updatedPO.poNumber} status changed to ${_formatStatus(newStatus)} during processing.\n\nProcessing has been stopped to prevent data inconsistency.',
        onConfirm: () {
          _clearSelection();
          Navigator.of(context).pop();
        },
        severity: StatusChangeSeverity.CRITICAL,
      );
    }
    // If status is still valid, continue processing but log the change
    else {
      print('⚠️ PO status changed during processing: ${_formatStatus(oldStatus)} → ${_formatStatus(newStatus)}');
      setState(() {
        selectedPO = updatedPO;
      });
    }
  }

  void _setupPeriodicStatusValidation() {
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (selectedPO != null &&
          (currentStep == InventoryStep.PLACEMENT_REVIEW || currentStep == InventoryStep.PROCESSING)) {
        _validateCurrentPOStatus();
      }
    });
  }

  Future<void> _validateCurrentPOStatus() async {
    if (selectedPO == null || !_isStatusValidationEnabled) return;

    try {
      final currentPO = await _purchaseOrderService.getPurchaseOrder(selectedPO!.id);
      if (currentPO == null) {
        _handlePODeleted();
      } else if (!_isStatusValidForReceiving(currentPO.status)) {
        _handleInvalidStatusDetected(currentPO);
      }
    } catch (e) {
      print('Error validating PO status: $e');
    }
  }

  bool _isStatusValidForReceiving(POStatus status) {
    return status == POStatus.COMPLETED ||
        status == POStatus.PARTIALLY_RECEIVED; // Include READY for additional quantities
  }

  void _handlePODeleted() {
    _showStatusChangeDialog(
      title: 'Purchase Order Deleted',
      message: 'The selected purchase order has been deleted from the system.',
      onConfirm: () {
        _clearSelection();
        Navigator.of(context).pop();
      },
      severity: StatusChangeSeverity.CRITICAL,
    );
  }

  void _handleInvalidStatusDetected(PurchaseOrder po) {
    _showStatusChangeDialog(
      title: 'Invalid PO Status Detected',
      message: 'PO ${po.poNumber} status is now ${_formatStatus(po.status)}, which is not valid for receiving operations.',
      onConfirm: () {
        _clearSelection();
        Navigator.of(context).pop();
      },
      severity: StatusChangeSeverity.CRITICAL,
    );
  }

  String _formatStatus(POStatus status) {
    return status.toString().split('.').last.replaceAll('_', ' ').toLowerCase();
  }

  void _showStatusChangeWarning(POStatus oldStatus, POStatus newStatus, bool isInCriticalStep) {
    final message = isInCriticalStep
        ? 'PO status changed from ${_formatStatus(oldStatus)} to ${_formatStatus(newStatus)} during placement review. Please verify before proceeding.'
        : 'PO status changed from ${_formatStatus(oldStatus)} to ${_formatStatus(newStatus)}.';

    _showMessage(message, isInCriticalStep ? Colors.orange : Colors.blue);
  }

  void _showStatusChangeDialog({
    required String title,
    required String message,
    required VoidCallback onConfirm,
    StatusChangeSeverity severity = StatusChangeSeverity.WARNING,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              severity == StatusChangeSeverity.CRITICAL ? Icons.error : Icons.warning,
              color: severity == StatusChangeSeverity.CRITICAL ? Colors.red : Colors.orange,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: onConfirm,
            style: TextButton.styleFrom(
              backgroundColor: severity == StatusChangeSeverity.CRITICAL
                  ? Colors.red
                  : Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _selectPurchaseOrder(PurchaseOrder po) async {
    setState(() {
      currentStep = InventoryStep.PRODUCT_SELECTION;
      isProcessing = true;
      selectedPO = po;
      selectedLineItems.clear();
      productCache.clear();
      receivingQuantities.clear();
      allocationResults.clear();
      showPlacementReview = false; // Ensure this is false
      _clearAllocationResults();
    });

    try {
      // Set available line items AFTER clearing state
      availableLineItems = List.from(po.lineItems); // Create a copy

      // Load all products for all line items
      for (final lineItem in availableLineItems) {
        try {
          final product = await _purchaseOrderService.getProduct(lineItem.productId);
          if (product != null) {
            productCache[lineItem.productId] = product;
          }
        } catch (e) {
          print('Failed to load product ${lineItem.productId}: $e');
        }
      }

      // Final state update
      setState(() {
        isProcessing = false;
        errorMessage = null; // Clear any previous errors
      });

      print('Successfully loaded PO ${po.poNumber} with ${availableLineItems.length} line items and ${productCache.length} products');

    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load product details: $e';
        isProcessing = false;
        availableLineItems.clear(); // Clear on error
      });
      print('Error selecting PO: $e');
    }
  }

  Widget _buildPOHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey, width: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.inventory_2,
                color: Colors.blue[600],
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receiving: ${selectedPO!.poNumber}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      selectedPO!.supplierName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Add cross button here
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: _clearSelection,
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear Selection',
                  iconSize: 20,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Text(
                  '${selectedLineItems.length}/${availableLineItems.length} selected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineItemCard(POLineItem lineItem, Product? product) {
    final isSelected = selectedLineItems.any((item) => item.id == lineItem.id);
    final receivedQty = lineItem.quantityReceived ?? 0;
    final placedQty = lineItem.quantityPlaced ?? 0;  // NEW: Track placed quantity
    final availableForPlacement = receivedQty - placedQty;  // NEW: Actual quantity available
    final remainingQty = lineItem.quantityOrdered - receivedQty;
    final categoryColor = product != null ? (categoryColors[product.category] ?? Colors.grey) : Colors.grey;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.grey[200]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _toggleLineItemSelection(lineItem),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with checkbox and product name
              Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleLineItemSelection(lineItem),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (product != null) ...[
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        categoryIcons[product.category] ?? Icons.inventory,
                        color: categoryColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lineItem.productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        if (product?.category != null)
                          Text(
                            product!.category!.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              color: categoryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ENHANCED: Show detailed quantity breakdown
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuantityChip('Ordered', lineItem.quantityOrdered, Colors.blue),
                  _buildQuantityChip('Received', receivedQty, receivedQty > 0 ? Colors.green : Colors.grey),
                  if (placedQty > 0)
                    _buildQuantityChip('Placed', placedQty, Colors.purple),
                  if (availableForPlacement > 0)
                    _buildQuantityChip('Available', availableForPlacement, Colors.orange),
                  if (remainingQty > 0)
                    _buildQuantityChip('Pending', remainingQty, Colors.grey),
                ],
              ),

              // NEW: Show existing warehouse placement info
              if (placedQty > 0) ...[
                const SizedBox(height: 12),
                FutureBuilder<List<WarehouseLocation>>(
                  future: _getExistingPlacements(lineItem.productId),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      return _buildExistingPlacementInfo(snapshot.data!);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],

              // Placement info for selected items
              if (isSelected && availableForPlacement > 0) ...[
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: '$availableForPlacement',
                  decoration: InputDecoration(
                    labelText: 'New Quantity to Place',
                    prefixIcon: Icon(Icons.place, color: Colors.blue[600]),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: Colors.blue[50],
                    suffixText: 'units',
                  ),
                  readOnly: true,
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
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
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          placedQty > 0
                              ? 'Will attempt to consolidate with existing placement'
                              : 'New placement will be created',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Show message for items with no available quantity
              if (isSelected && availableForPlacement <= 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_outlined, color: Colors.orange[700], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'All received quantities have already been placed',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Status for unselected items
              if (!isSelected) ...[
                const SizedBox(height: 8),
                if (availableForPlacement > 0)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warehouse, color: Colors.green[600], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Ready for placement ($availableForPlacement units)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (placedQty > 0)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.purple[600], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'All received quantities placed',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.purple[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey[600], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'No received quantity to place',
                          style: TextStyle(
                            fontSize: 12,
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
    );
  }


  Future<List<WarehouseLocation>> _getExistingPlacements(String productId) async {
    if (selectedPO == null) return [];

    try {
      return await _warehouseService.findExistingProductLocations(
          selectedPO!.id,
          productId
      );
    } catch (e) {
      print('Error getting existing placements: $e');
      return [];
    }
  }




  Widget _buildExistingPlacementInfo(List<WarehouseLocation> locations) {
    final totalPlaced = locations.fold(0, (sum, loc) => sum + (loc.quantityStored ?? 0));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.purple[700], size: 16),
              const SizedBox(width: 8),
              Text(
                'Existing Placements ($totalPlaced units)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.purple[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...locations.map((location) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(Icons.circle, size: 8, color: Colors.purple[600]),
                const SizedBox(width: 8),
                Text(
                  '${location.locationId}: ${location.quantityStored} units',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.purple[600],
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  void _toggleLineItemSelection(POLineItem lineItem) {
    final receivedQty = lineItem.quantityReceived ?? 0;
    final placedQty = lineItem.quantityPlaced ?? 0;
    final availableForPlacement = receivedQty - placedQty;

    // Only allow selection if there are unplaced received items
    if (availableForPlacement <= 0) {
      if (placedQty > 0) {
        _showMessage('All received quantities have already been placed', Colors.orange);
      } else {
        _showMessage('No received quantity available for placement', Colors.orange);
      }
      return;
    }

    setState(() {
      if (selectedLineItems.any((item) => item.id == lineItem.id)) {
        selectedLineItems.removeWhere((item) => item.id == lineItem.id);
        receivingQuantities.remove(lineItem.id);
      } else {
        selectedLineItems.add(lineItem);
        // Set the quantity to place as the available (unplaced) quantity
        receivingQuantities[lineItem.id] = availableForPlacement;
      }
    });
  }

  Widget _buildQuantityChip(String label, int quantity, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $quantity',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMultiProductActions() {
    final hasValidSelections = selectedLineItems.isNotEmpty &&
        receivingQuantities.values.any((qty) => qty > 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey, width: 0.2)),
      ),
      child: Column(
        children: [
          if (selectedLineItems.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                'Selected ${selectedLineItems.length} item(s) for receiving',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearSelection,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: hasValidSelections ? _processSelectedProducts : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Process Selected Items'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _processSelectedProducts() async {
    setState(() {
      currentStep = InventoryStep.PLACEMENT_REVIEW;
    });
    if (selectedLineItems.isEmpty) return;

    setState(() {
      isProcessing = true;
      productAllocationOptions.clear();
      selectedPlacements.clear();
    });

    try {
      // Calculate allocations for all products first
      for (final lineItem in selectedLineItems) {
        final product = productCache[lineItem.productId];
        final quantity = receivingQuantities[lineItem.id] ?? 0;

        if (product != null && quantity > 0) {
          final result = await _warehouseService.calculateStorageAllocation(
            product,
            selectedPO!,
            quantity,
          );

          if (result.success && result.availableLocations.isNotEmpty) {
            productAllocationOptions[lineItem.id] = result.availableLocations;
            selectedPlacements[lineItem.id] = result.availableLocations.first; // Default selection
          } else {
            throw Exception('No storage space available for ${product.name}');
          }
        }
      }

      // Show placement review screen
      setState(() {
        showPlacementReview = true;
        isProcessing = false;
      });

    } catch (e) {
      _showMessage('Error calculating placements: $e', Colors.red);
      setState(() {
        isProcessing = false;
      });
    }
  }

  Widget _buildPlacementReviewView() {
    return Expanded(
      child: Column(
        children: [
          // Header - Fixed at top
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.map, color: Colors.blue[600], size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Review Product Placements',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                // Back button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: () => setState(() => showPlacementReview = false),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back to Product Selection',
                    iconSize: 20,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Cross button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: _clearSelection,
                    icon: const Icon(Icons.close),
                    tooltip: 'Clear Selection',
                    iconSize: 20,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Rest of the placement review content...
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildOptimizationSuggestions(),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: selectedLineItems.length,
                    itemBuilder: (context, index) {
                      final lineItem = selectedLineItems[index];
                      final product = productCache[lineItem.productId];
                      return _buildProductPlacementCard(lineItem, product);
                    },
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          _buildPlacementActions(),
        ],
      ),
    );
  }

  Widget _buildOptimizationSuggestions() {
    return Container(
      margin: const EdgeInsets.all(16),
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
              Icon(Icons.map, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Placement Plan Summary',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Show actual placement details for each product
          ...selectedLineItems.map((lineItem) {
            final product = productCache[lineItem.productId];
            final quantity = receivingQuantities[lineItem.id] ?? 0;

            return FutureBuilder<StorageAllocationResult>(
              future: product != null && quantity > 0
                  ? _warehouseService.calculateStorageAllocation(product, selectedPO!, quantity)
                  : null,
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.success) {
                  return _buildProductPlacementSummaryCard(
                    lineItem.productName,
                    quantity,
                    'Calculating placement...',
                    [],
                    Colors.grey,
                  );
                }

                final result = snapshot.data!;
                final plan = result.allocationPlan ?? [];

                // Count consolidations and new locations
                final consolidations = plan.where((p) => p.isConsolidation).toList();
                final newPlacements = plan.where((p) => !p.isConsolidation).toList();

                String summary;
                Color color;

                if (consolidations.isNotEmpty && newPlacements.isNotEmpty) {
                  summary = '${consolidations.length} consolidation(s) + ${newPlacements.length} new location(s)';
                  color = Colors.orange;
                } else if (consolidations.isNotEmpty) {
                  summary = '${consolidations.length} consolidation(s) only';
                  color = Colors.green;
                } else {
                  summary = '${newPlacements.length} new location(s)';
                  color = Colors.blue;
                }

                return _buildProductPlacementSummaryCard(
                  lineItem.productName,
                  quantity,
                  summary,
                  plan,
                  color,
                );
              },
            );
          }).toList(),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildProductPlacementSummaryCard(
      String productName,
      int quantity,
      String summary,
      List<LocationAllocationPlan> plan,
      Color color
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              Expanded(
                child: Text(
                  productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$quantity units',
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            summary,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),

          // Show specific locations if available
          if (plan.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: plan.take(3).map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: p.isConsolidation ? Colors.green[100] : Colors.blue[100],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: p.isConsolidation ? Colors.green[300]! : Colors.blue[300]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        p.isConsolidation ? Icons.merge_type : Icons.add_location,
                        size: 10,
                        color: p.isConsolidation ? Colors.green[700] : Colors.blue[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${p.location.locationId}: ${p.quantityToPlace}',
                        style: TextStyle(
                          fontSize: 10,
                          color: p.isConsolidation ? Colors.green[700] : Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            if (plan.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${plan.length - 3} more locations',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }


  Widget _buildPlacementActions() {
    final allPlacementsSelected = selectedLineItems.every((item) =>
    selectedPlacements[item.id] != null);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey, width: 0.2)),
      ),
      child: Column(
        children: [
          // Summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: allPlacementsSelected ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: allPlacementsSelected ? Colors.green[200]! : Colors.orange[200]!,
              ),
            ),
            child: Text(
              allPlacementsSelected
                  ? 'All ${selectedLineItems.length} products have assigned locations'
                  : 'Please select locations for all products',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: allPlacementsSelected ? Colors.green[700] : Colors.orange[700],
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => showPlacementReview = false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Back to Products'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: allPlacementsSelected && !isProcessing
                      ? _confirmAllPlacements : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: isProcessing
                      ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      ),
                      SizedBox(width: 8),
                      Text('Storing...'),
                    ],
                  )
                      : const Text('Confirm All Placements'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAllPlacements() async {
    setState(() {
      currentStep = InventoryStep.PROCESSING;
      isProcessing = true;
      _isStatusValidationEnabled = true;
    });

    try {
      for (final lineItem in selectedLineItems) {
        final product = productCache[lineItem.productId];
        final quantity = receivingQuantities[lineItem.id] ?? 0;

        if (product != null && quantity > 0) {
          // Get the enhanced allocation result with plan
          final result = await _warehouseService.calculateStorageAllocation(
            product,
            selectedPO!,
            quantity,
          );

          if (result.success && result.allocationPlan != null) {
            // NEW: Execute multi-location allocation
            await _warehouseService.executeMultiLocationStorageAllocation(
              result.allocationPlan!,
              product,
              selectedPO!,
              _purchaseOrderService,
            );

            // Show consolidation info if applicable
            final consolidationCount = result.allocationPlan!
                .where((plan) => plan.isConsolidation)
                .length;

            if (consolidationCount > 0) {
              print('✅ ${product.name}: Consolidated in $consolidationCount existing location(s)');
            }
          } else {
            throw Exception('No storage space available for ${product.name}');
          }
        }
      }

      _showMessage('All products stored successfully with optimized placement!', Colors.green);
      _clearSelection();
      setState(() {
        _isStatusValidationEnabled = false;
        currentStep = InventoryStep.PO_SELECTION;
        showPlacementReview = false;
      });

    } catch (e) {
      _showMessage('Error storing products: $e', Colors.red);
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  Widget _buildProductPlacementCard(POLineItem lineItem, Product? product) {
    final quantity = receivingQuantities[lineItem.id] ?? 0;
    final categoryColor = product != null ? (categoryColors[product.category] ?? Colors.grey) : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product header
            Row(
              children: [
                if (product != null) ...[
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      categoryIcons[product.category] ?? Icons.inventory,
                      color: categoryColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lineItem.productName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Quantity: $quantity units',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ENHANCED: Show detailed placement breakdown
            FutureBuilder<StorageAllocationResult>(
              future: product != null && quantity > 0 ? _warehouseService.calculateStorageAllocation(
                product,
                selectedPO!,
                quantity,
              ) : null,
              builder: (context, snapshot) {
                if (!snapshot.hasData || product == null || quantity == 0) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      quantity == 0 ? 'No quantity to store' : 'Calculating placement...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  );
                }

                final result = snapshot.data!;

                if (!result.success) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      result.errorMessage ?? 'Cannot allocate storage space',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[700],
                      ),
                    ),
                  );
                }

                final plan = result.allocationPlan ?? [];
                final consolidations = plan.where((p) => p.isConsolidation).toList();
                final newLocations = plan.where((p) => !p.isConsolidation).toList();

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: consolidations.isNotEmpty ? Colors.green[50] : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: consolidations.isNotEmpty ? Colors.green[200]! : Colors.blue[200]!,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            consolidations.isNotEmpty ? Icons.merge_type : Icons.add_location,
                            color: consolidations.isNotEmpty ? Colors.green[700] : Colors.blue[700],
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Detailed Placement Plan',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: consolidations.isNotEmpty ? Colors.green[700] : Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Show each location with specific details
                      ...plan.asMap().entries.map((entry) {
                        final index = entry.key;
                        final p = entry.value;
                        final isLast = index == plan.length - 1;

                        return Container(
                          margin: EdgeInsets.only(bottom: isLast ? 0 : 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: p.isConsolidation ? Colors.green[300]! : Colors.blue[300]!,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    p.isConsolidation ? Icons.merge_type : Icons.add_location,
                                    size: 12,
                                    color: p.isConsolidation ? Colors.green[600] : Colors.blue[600],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    p.location.locationId,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: p.isConsolidation ? Colors.green[700] : Colors.blue[700],
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (p.isConsolidation ? Colors.green[200] : Colors.blue[200]),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${p.quantityToPlace} units',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: p.isConsolidation ? Colors.green[800] : Colors.blue[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (p.isConsolidation && p.consolidationInfo != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Existing: ${p.consolidationInfo!.existingQuantity} units from PO ${p.consolidationInfo!.existingPO}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  'Total after: ${p.consolidationInfo!.totalAfter} units',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ] else if (!p.isConsolidation) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'New placement in Zone ${p.location.zoneId}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _clearSelection() {
    print('Clearing selection...');
    setState(() {
      selectedPO = null;
      selectedLineItem = null;
      selectedProduct = null;
      availableLineItems.clear();
      selectedLineItems.clear();
      productCache.clear();
      receivingQuantities.clear();
      productAllocationOptions.clear();
      selectedPlacements.clear();
      showPlacementReview = false;
      isProcessing = false;
      _quantityController.clear();
      errorMessage = null;
      currentStep = InventoryStep.PO_SELECTION;
      _isStatusValidationEnabled = true;
      _lastKnownValidStatus = null;
      _clearAllocationResults();
    });
  }

  void _clearAllocationResults() {
    setState(() {
      allocationResult = null;
      selectedLocation = null;
      showAllocationResults = false;
      isAllocating = false;
    });
  }

  Future<void> _executeStorageAllocation() async {
    if (!_formKey.currentState!.validate()) return;

    final quantity = selectedLineItem!.quantityReceived ?? 0;

    setState(() {
      isAllocating = true;
      showAllocationResults = false;
    });

    try {
      // Run allocation algorithm
      final result = await _warehouseService.calculateStorageAllocation(
        selectedProduct!,
        selectedPO!,
        quantity,
      );

      setState(() {
        allocationResult = result;
        showAllocationResults = true;
        isAllocating = false;
      });

      if (result.success) {
        _showMessage('Storage allocation calculated successfully!', Colors.green);
      } else {
        _showMessage(result.errorMessage ?? 'No available space found', Colors.red);
      }

    } catch (e) {
      setState(() {
        isAllocating = false;
        errorMessage = 'Allocation failed: $e';
      });
      _showMessage('Storage allocation failed: $e', Colors.red);
    }
  }

  Future<void> _confirmStorageAllocation() async {
    if (selectedLocation == null) return;

    setState(() {
      isProcessing = true;
    });

    try {
      final quantity = selectedLineItem!.quantityReceived ?? 0;

      if (quantity <= 0) {
        _showMessage('No received items to store', Colors.orange);
        setState(() {
          isProcessing = false;
        });
        return;
      }

      // Execute the storage allocation
      await _warehouseService.executeStorageAllocation(
        selectedLocation!,
        selectedProduct!,
        selectedPO!,
        quantity,
        _purchaseOrderService,
      );

      // Show success message
      _showMessage(
        'Product stored successfully at ${selectedLocation!.locationId}!',
        Colors.green,
      );

      // Clear everything and return to PO selection
      _clearSelection();

    } catch (e) {
      setState(() {
        isProcessing = false;
      });
      _showMessage('Storage execution failed: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          if (selectedPO == null)
            _buildPOSelectionView()
          else if (showPlacementReview)
            _buildPlacementReviewView()  // Add this new view
          else if (!showAllocationResults)
              _buildMultiProductReceivingView()
            else
              _buildAllocationResultsView(),
        ],
      ),
    );
  }



  Widget _buildMultiProductReceivingView() {
    return Expanded(
      child: Column(
        children: [
          _buildPOHeader(),

          // Add empty state check and processing state
          Expanded(
            child: isProcessing
                ? const Center(child: CircularProgressIndicator())
                : availableLineItems.isEmpty
                ? _buildEmptyLineItemsView()  // Show empty state
                : ListView.builder(
              itemCount: availableLineItems.length,
              itemBuilder: (context, index) {
                final lineItem = availableLineItems[index];
                final product = productCache[lineItem.productId];
                return _buildLineItemCard(lineItem, product);
              },
            ),
          ),

          _buildMultiProductActions(),
        ],
      ),
    );
  }

  Widget _buildEmptyLineItemsView() {
    // Determine the specific reason for empty state
    String title;
    String description;
    IconData icon;

    if (selectedPO?.lineItems.isEmpty == true) {
      title = 'No Line Items in Purchase Order';
      description = 'This purchase order contains no line items.';
      icon = Icons.list_alt_outlined;
    } else {
      // Check if all items are already fully placed
      final hasUnplacedItems = selectedPO?.lineItems.any((item) {
        final receivedQty = item.quantityReceived ?? 0;
        final placedQty = item.quantityPlaced ?? 0;
        return (receivedQty - placedQty) > 0;
      }) ?? false;

      if (!hasUnplacedItems) {
        title = 'All Items Already Placed';
        description = 'All received items from this purchase order have already been placed in the warehouse.';
        icon = Icons.check_circle_outline;
      } else {
        title = 'No Items Available';
        description = 'No items are currently available for placement from this purchase order.';
        icon = Icons.inventory_2_outlined;
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _clearSelection,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Select Different PO'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPOSelectionView() {
    return Expanded(
      child: Column(
        children: [
          // Header with top padding to account for no app bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 20), // Added top padding
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey, width: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.inbox,
                      color: Colors.blue[600],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Select Purchase Order',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a purchase order to arrange inventory',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                ? _buildErrorView()
                : availablePOs.isEmpty
                ? _buildEmptyView()
                : _buildPOList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAllocationResultsView() {
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey, width: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: Colors.blue[600],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Storage Allocation Results',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => showAllocationResults = false),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back to Product Details',
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (allocationResult?.success == true) ...[
                    _buildAllocationReasoningCard(),
                    const SizedBox(height: 20),
                    _buildAvailableLocationsCard(),
                    const SizedBox(height: 24),
                    _buildConfirmationButtons(),
                  ] else ...[
                    _buildAllocationErrorCard(),
                    const SizedBox(height: 24),
                    _buildRetryButton(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationReasoningCard() {
    final reasoning = allocationResult?.allocationReasoning;
    if (reasoning == null) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb,
                  color: Colors.green[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recommended Zone: ${reasoning['targetZone']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reasoning['zoneName'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),

            // Reasoning explanations
            ...reasoning['reasoning'].entries.map<Widget>((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green[600],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${entry.key.toUpperCase()}: ${entry.value}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableLocationsCard() {
    final locations = allocationResult?.availableLocations ?? [];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Colors.blue[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Available Locations (${locations.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (locations.isEmpty)
              Text(
                'No available locations in recommended zone',
                style: TextStyle(color: Colors.red[600]),
              )
            else
              ...locations.take(5).map((location) => _buildLocationTile(location)).toList(),

            if (locations.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+ ${locations.length - 5} more locations available',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTile(WarehouseLocation location) {
    final isSelected = selectedLocation?.locationId == location.locationId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          Icons.location_on,
          color: isSelected ? Colors.blue : Colors.grey[600],
          size: 20,
        ),
        title: Text(
          location.locationId,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.blue[800] : Colors.black87,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          _getLocationDescription(location),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: Colors.blue, size: 20)
            : null,
        onTap: () {
          setState(() {
            selectedLocation = location;
          });
        },
      ),
    );
  }

  String _getLocationDescription(WarehouseLocation location) {
    final parts = [
      'Zone ${location.zoneId}',
      'Rack ${location.rackId}',
      'Row ${location.rowId}',
      'Level ${location.level}',
    ];
    return parts.join(' • ');
  }

  Widget _buildAllocationErrorCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[600],
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'No Available Space',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              allocationResult?.errorMessage ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: selectedLocation != null && !isProcessing
                ? _confirmStorageAllocation
                : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: isProcessing
                ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Storing Product...'),
              ],
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle),
                const SizedBox(width: 8),
                Text(selectedLocation != null
                    ? 'Confirm Storage at ${selectedLocation!.locationId}'
                    : 'Select a Location First'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => setState(() => showAllocationResults = false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Back to Product Details'),
          ),
        ),
      ],
    );
  }

  Widget _buildRetryButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _executeStorageAllocation,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh),
            SizedBox(width: 8),
            Text('Try Different Allocation'),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard() {
    final product = selectedProduct!;
    final lineItem = selectedLineItem!;
    final categoryColor = categoryColors[product.category] ?? Colors.grey;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: categoryColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name with category
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    categoryIcons[product.category],
                    color: categoryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        product.category?.toUpperCase() ?? 'N/A',
                        style: TextStyle(
                          fontSize: 12,
                          color: categoryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Product details
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (product.sku?.isNotEmpty == true)
                  _buildDetailItem('SKU', product.sku!),
                if (product.brand?.isNotEmpty == true)
                  _buildDetailItem('Brand', product.brand!),
                _buildDetailItem('Unit Price', 'RM ${lineItem.unitPrice.toStringAsFixed(2)}'),
                _buildDetailItem('Ordered Qty', '${lineItem.quantityOrdered}'),
                _buildDetailItem('Line Total', ' RM ${lineItem.lineTotal.toStringAsFixed(2)}'),
              ],
            ),

            if (product.description?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  product.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseInfoCard() {
    final product = selectedProduct!;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warehouse,
                  color: Colors.blue[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Warehouse Allocation Info',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Physical properties
            if (product.dimensions != null) ...[
              Text(
                'Physical Properties',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildDimensionItem('L', '${product.dimensions.length.toStringAsFixed(2)} m'),
                  _buildDimensionItem('W', '${product.dimensions.width.toStringAsFixed(2)} m'),
                  _buildDimensionItem('H', '${product.dimensions.height.toStringAsFixed(2)} m'),
                  if (product.weight != null)
                    _buildDimensionItem('Weight', '${product.weight!.toStringAsFixed(2)} kg'),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Storage requirements
            Text(
              'Storage Requirements',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildRequirementChip(
                  product.movementFrequency?.toUpperCase() ?? 'UNKNOWN',
                  _getMovementFrequencyColor(product.movementFrequency),
                ),
                if (product.requiresClimateControl == true)
                  _buildRequirementChip('CLIMATE CONTROL', Colors.blue),
                if (product.isHazardousMaterial == true)
                  _buildRequirementChip('HAZARDOUS', Colors.red),
                if (product.storageType != null)
                  _buildRequirementChip(
                    product.storageType!.toUpperCase(),
                    Colors.purple,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityInput() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quantity to Receive',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),

            // Read-only field for already received quantity
            TextFormField(
              initialValue: '${selectedLineItem?.quantityReceived ?? 0}',
              decoration: InputDecoration(
                labelText: 'Already Received',
                prefixIcon: Icon(Icons.done_all, color: Colors.green[600]),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey[50],
                suffixIcon: Icon(
                  Icons.lock,
                  color: Colors.grey[400],
                  size: 16,
                ),
              ),
              readOnly: true,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),


          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isAllocating ? null : _executeStorageAllocation,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isAllocating
                ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Calculating Allocation...'),
              ],
            )
                : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calculate),
                SizedBox(width: 8),
                Text('Calculate Storage Allocation'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _clearSelection,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancel & Select Different PO'),
          ),
        ),
      ],
    );
  }

  // Helper widgets and methods remain the same as in your original code...
  Widget _buildPOList() {
    return RefreshIndicator(
      onRefresh: () async => _showMessage('Data refreshed automatically in real-time!', Colors.green),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: availablePOs.length,
        itemBuilder: (context, index) {
          final po = availablePOs[index];
          return _buildPOCard(po);
        },
      ),
    );
  }

  Widget _buildPOCard(PurchaseOrder po) {
    final lineItem = po.lineItems.isNotEmpty ? po.lineItems.first : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () => _selectPurchaseOrder(po),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(po.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      po.poNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(po.status),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _getPriorityIcon(po.priority),
                    color: _getPriorityColor(po.priority),
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Supplier
              Text(
                po.supplierName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),

              // Product info (if available)
              if (lineItem != null) ...[
                Text(
                  lineItem.productName,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),

                // Quantity and total
                Row(
                  children: [
                    _buildInfoChip(
                      'Qty: ${lineItem.quantityOrdered}',
                      Icons.inventory,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      '\$${po.totalAmount.toStringAsFixed(2)}',
                      Icons.attach_money,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),

              // Expected delivery
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Expected: ${_formatDate(po.expectedDeliveryDate)}',
                    style: TextStyle(
                      fontSize: 12,
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
  }

  // Helper widgets
  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildDimensionItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blue[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeSystem,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Purchase Orders Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No approved purchase orders ready for receiving.\nOrders update automatically when status changes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Color _getStatusColor(POStatus status) {
    switch (status) {
      case POStatus.PENDING_APPROVAL:
        return Colors.orange;
      case POStatus.APPROVED:
        return Colors.green;
      case POStatus.REJECTED:
        return Colors.red;
      case POStatus.COMPLETED:
        return Colors.teal;
      case POStatus.PARTIALLY_RECEIVED:  // Add this
        return Colors.blue;
      case POStatus.READY:
        return Colors.purple; // New color for READY status
      default:
        return Colors.grey;
    }
  }

  IconData _getPriorityIcon(POPriority priority) {
    switch (priority) {
      case POPriority.LOW:
        return Icons.keyboard_arrow_down;
      case POPriority.NORMAL:
        return Icons.remove;
      case POPriority.HIGH:
        return Icons.keyboard_arrow_up;
      case POPriority.URGENT:
        return Icons.priority_high;
    }
  }

  Color _getPriorityColor(POPriority priority) {
    switch (priority) {
      case POPriority.LOW:
        return Colors.green;
      case POPriority.NORMAL:
        return Colors.blue;
      case POPriority.HIGH:
        return Colors.orange;
      case POPriority.URGENT:
        return Colors.red;
    }
  }

  Color _getMovementFrequencyColor(String? frequency) {
    switch (frequency) {
      case 'fast':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'slow':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    return '${date.day}/${date.month}/${date.year}';
  }
}