import 'package:flutter/material.dart';
import '../../../../services/adjustment/snackbar_manager.dart';

class ProcessItemsStep extends StatelessWidget {
  final List<Map<String, dynamic>> selectedPurchaseOrders;
  final Function(Map<String, dynamic>, int, bool) onToggleAllReceived;
  final Function(Map<String, dynamic>, int, int, int) onProcessItem;
  final Function(Map<String, dynamic>, int) onReportDiscrepancy;
  final Function() onBack;
  final Function() onProceedToReview;
  final bool canProceedToReview;

  const ProcessItemsStep({
    Key? key,
    required this.selectedPurchaseOrders,
    required this.onToggleAllReceived,
    required this.onProcessItem,
    required this.onReportDiscrepancy,
    required this.onBack,
    required this.onProceedToReview,
    required this.canProceedToReview,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container();
  }

  static List<Widget> buildSlivers({
    required List<Map<String, dynamic>> selectedPurchaseOrders,
    required Function(Map<String, dynamic>, int, bool) onToggleAllReceived,
    required Function(Map<String, dynamic>, int, int, int) onProcessItem,
    required Function(Map<String, dynamic>, int) onReportDiscrepancy,
    required Function() onBack,
    required Function() onProceedToReview,
    required bool canProceedToReview,
    required BuildContext context,
  }) {
    if (selectedPurchaseOrders.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Text('No purchase orders selected'),
          ),
        ),
      ];
    }

    List<Widget> slivers = [];

    // Header
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            children: [
              Icon(Icons.inventory_2, color: Color(0xFF3B82F6), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Process Line Items',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to expand PO cards, swipe through items',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(0xFF3B82F6).withOpacity(0.3)),
                ),
                child: Text(
                  '${selectedPurchaseOrders.length} POs',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Collapsible PO Cards
    for (int poIndex = 0; poIndex < selectedPurchaseOrders.length; poIndex++) {
      Map<String, dynamic> po = selectedPurchaseOrders[poIndex];

      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _CollapsiblePOCard(
              po: po,
              poIndex: poIndex,
              onToggleAllReceived: onToggleAllReceived,
              onProcessItem: onProcessItem,
              onReportDiscrepancy: onReportDiscrepancy,
            ),
          ),
        ),
      );
    }

    return slivers;
  }
}

// Collapsible PO Card with Horizontal Swiper
class _CollapsiblePOCard extends StatefulWidget {
  final Map<String, dynamic> po;
  final int poIndex;
  final Function(Map<String, dynamic>, int, bool) onToggleAllReceived;
  final Function(Map<String, dynamic>, int, int, int) onProcessItem;
  final Function(Map<String, dynamic>, int) onReportDiscrepancy;

  const _CollapsiblePOCard({
    Key? key,
    required this.po,
    required this.poIndex,
    required this.onToggleAllReceived,
    required this.onProcessItem,
    required this.onReportDiscrepancy,
  }) : super(key: key);

  @override
  State<_CollapsiblePOCard> createState() => _CollapsiblePOCardState();
}

class _CollapsiblePOCardState extends State<_CollapsiblePOCard> {
  bool _isExpanded = true;
  late PageController _pageController;
  int _currentItemIndex = 0;
  bool _isMarkAllChecked = false;
  Map<String, Map<String, int>> _originalValues = {};
  bool _hasOriginalData = false; // Track if PO has any saved data

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _storeOriginalValues();
    _updateMarkAllState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _storeOriginalValues() {
    List<dynamic> lineItems = widget.po['lineItems'] ?? [];
    _hasOriginalData = false;

    for (var item in lineItems) {
      String itemId = item['id'] ?? '';
      int originalReceived = item['quantityReceived'] ?? 0;
      int originalDamaged = item['quantityDamaged'] ?? 0;

      _originalValues[itemId] = {
        'received': originalReceived,
        'damaged': originalDamaged,
      };

      // Check if this PO has any actual saved data
      if (originalReceived > 0 || originalDamaged > 0) {
        _hasOriginalData = true;
      }
    }
  }

  @override
  void didUpdateWidget(_CollapsiblePOCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateMarkAllState();
  }

  void _updateMarkAllState() {
    List<dynamic> lineItems = widget.po['lineItems'] ?? [];
    bool allItemsFullyReceived = true;
    int totalOrdered = 0;
    int totalReceived = 0;
    int totalDamaged = 0;

    for (var item in lineItems) {
      int ordered = item['quantityOrdered'] ?? 0;
      int received = item['quantityReceived'] ?? 0;
      int damaged = item['quantityDamaged'] ?? 0;

      totalOrdered += ordered;
      totalReceived += received;
      totalDamaged += damaged;

      if (received + damaged < ordered) {
        allItemsFullyReceived = false;
      }
    }

    bool newMarkAllState = allItemsFullyReceived && totalOrdered > 0;

    if (mounted) {
      setState(() {
        _isMarkAllChecked = newMarkAllState;
      });
    }
  }

  String _getCheckboxText() {
    List<dynamic> lineItems = widget.po['lineItems'] ?? [];
    int totalOrdered = 0;
    int totalReceived = 0;
    int totalDamaged = 0;
    int totalRemaining = 0;

    for (var item in lineItems) {
      int ordered = item['quantityOrdered'] ?? 0;
      int received = item['quantityReceived'] ?? 0;
      int damaged = item['quantityDamaged'] ?? 0;

      totalOrdered += ordered;
      totalReceived += received;
      totalDamaged += damaged;

      int itemRemaining = ordered - received - damaged;
      if (itemRemaining > 0) {
        totalRemaining += itemRemaining;
      }
    }

    bool isPartiallyReceived = widget.po['status'] == 'PARTIALLY_RECEIVED' ||
        widget.po['status'] == 'COMPLETED';
    bool isApproved = widget.po['status'] == 'APPROVED';

    if (_isMarkAllChecked) {
      if (isApproved) {
        return 'Uncheck to reset all items';
      } else if (isPartiallyReceived) {
        return 'Reset to original partially received state';
      } else {
        return 'Uncheck to reset all items';
      }
    } else {
      if (totalRemaining > 0) {
        return 'Mark remaining $totalRemaining items as received';
      } else if (totalOrdered > 0) {
        return 'Mark all $totalOrdered items as received';
      } else {
        return 'No items to receive';
      }
    }
  }

  void _handleMarkAllToggle(bool? value) {
    if (value == null) return;

    List<dynamic> lineItems = widget.po['lineItems'] ?? [];
    bool isPartiallyReceived = widget.po['status'] == 'PARTIALLY_RECEIVED' ||
        widget.po['status'] == 'COMPLETED';

    for (var item in lineItems) {
      String itemId = item['id'] ?? '';
      int orderedQty = item['quantityOrdered'] ?? 0;
      int currentReceived = item['quantityReceived'] ?? 0;
      int currentDamaged = item['quantityDamaged'] ?? 0;

      if (value) {
        int remainingQty = orderedQty - currentReceived - currentDamaged;
        if (remainingQty > 0) {
          item['quantityReceived'] = orderedQty - currentDamaged;
        }
      } else {
        if (isPartiallyReceived && _originalValues.containsKey(itemId)) {
          item['quantityReceived'] = _originalValues[itemId]!['received']!;
          item['quantityDamaged'] = _originalValues[itemId]!['damaged']!;
        } else {
          item['quantityReceived'] = 0;
          item['quantityDamaged'] = 0;
        }
      }
    }

    setState(() {
      _isMarkAllChecked = value;
      if (_currentItemIndex >= 0 && _currentItemIndex < lineItems.length) {
        _pageController.jumpToPage(_currentItemIndex);
      }
    });

    widget.onToggleAllReceived(widget.po, widget.poIndex, value);
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> lineItems = widget.po['lineItems'] ?? [];
    String poNumber = widget.po['poNumber'] ?? 'N/A';
    String supplierName = widget.po['supplierName'] ?? 'Unknown Supplier';

    int totalReceived = 0;
    int totalOrdered = 0;
    bool hasProcessedItems = false;

    for (var item in lineItems) {
      int ordered = item['quantityOrdered'] ?? 0;
      int received = item['quantityReceived'] ?? 0;
      int damaged = item['quantityDamaged'] ?? 0;

      totalOrdered += ordered;
      totalReceived += received;

      if (received > 0 || damaged > 0) {
        hasProcessedItems = true;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasProcessedItems ? Colors.green[200]! : Colors.grey[200]!,
          width: hasProcessedItems ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Collapsible Header
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(_isExpanded ? 0 : 12),
              bottomRight: Radius.circular(_isExpanded ? 0 : 12),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hasProcessedItems
                    ? Colors.green[50]
                    : Color(0xFF3B82F6).withOpacity(0.05),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(_isExpanded ? 0 : 12),
                  bottomRight: Radius.circular(_isExpanded ? 0 : 12),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: hasProcessedItems
                            ? Colors.green[600]
                            : Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.receipt_long,
                          color: hasProcessedItems
                              ? Colors.green[600]
                              : Color(0xFF3B82F6),
                          size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              poNumber,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: hasProcessedItems
                                    ? Colors.green[700]
                                    : Color(0xFF3B82F6),
                              ),
                            ),
                            Text(
                              supplierName,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
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
                              color: hasProcessedItems
                                  ? Colors.green.withOpacity(0.1)
                                  : Color(0xFF3B82F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${lineItems.length} items',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: hasProcessedItems
                                    ? Colors.green[700]
                                    : Color(0xFF3B82F6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalReceived/$totalOrdered received',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_isExpanded && lineItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _handleMarkAllToggle(!_isMarkAllChecked),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isMarkAllChecked
                              ? Colors.green[50]
                              : Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: _isMarkAllChecked
                                  ? Colors.green[400]!
                                  : Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: _isMarkAllChecked,
                                onChanged: _handleMarkAllToggle,
                                activeColor: _isMarkAllChecked
                                    ? Colors.green
                                    : Color(0xFF3B82F6),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getCheckboxText(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _isMarkAllChecked
                                      ? Colors.green[700]
                                      : Colors.blue[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Expandable Content with Swiper
          if (_isExpanded)
            Container(
              height: 400,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Column(
                children: [
                  // Item Counter and Navigation
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Item ${_currentItemIndex + 1}/${lineItems.length}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (lineItems.length > 1) ...[
                          IconButton(
                            onPressed: _currentItemIndex > 0
                                ? () {
                                    _pageController.previousPage(
                                      duration: Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                : null,
                            icon: Icon(
                              Icons.chevron_left,
                              color: _currentItemIndex > 0
                                  ? Colors.grey[700]
                                  : Colors.grey[400],
                            ),
                          ),
                          Text(
                            'Swipe',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          IconButton(
                            onPressed: _currentItemIndex < lineItems.length - 1
                                ? () {
                                    _pageController.nextPage(
                                      duration: Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                : null,
                            icon: Icon(
                              Icons.chevron_right,
                              color: _currentItemIndex < lineItems.length - 1
                                  ? Colors.grey[700]
                                  : Colors.grey[400],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Swipeable Items
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: lineItems.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentItemIndex = index;
                          _updateMarkAllState();
                        });
                      },
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: _LineItemCard(
                            item: lineItems[index],
                            itemIndex: index,
                            poIndex: widget.poIndex,
                            isPartiallyReceived:
                                widget.po['status'] == 'PARTIALLY_RECEIVED' ||
                                    widget.po['status'] == 'COMPLETED',
                            onProcessItem: widget.onProcessItem,
                            onReportDiscrepancy: () => widget
                                .onReportDiscrepancy(lineItems[index], index),
                            onQuantityChanged: () {
                              setState(() {
                                _updateMarkAllState();
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Individual Line Item Card - COMPLETE FIXED VERSION
class _LineItemCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final int itemIndex;
  final int poIndex;
  final bool isPartiallyReceived;
  final Function(Map<String, dynamic>, int, int, int) onProcessItem;
  final Function() onReportDiscrepancy;
  final Function() onQuantityChanged;

  const _LineItemCard({
    Key? key,
    required this.item,
    required this.itemIndex,
    required this.poIndex,
    required this.isPartiallyReceived,
    required this.onProcessItem,
    required this.onReportDiscrepancy,
    required this.onQuantityChanged,
  }) : super(key: key);

  @override
  State<_LineItemCard> createState() => _LineItemCardState();
}

class _LineItemCardState extends State<_LineItemCard> {
  late int _receivedQty;
  late int _damagedQty;
  late int _orderedQty;
  late int _originalReceivedQty;
  late int _originalDamagedQty;
  late TextEditingController _receivedController;
  late TextEditingController _damagedController;

  @override
  void initState() {
    super.initState();
    _initializeQuantities();
    _receivedController = TextEditingController(text: _receivedQty.toString());
    _damagedController = TextEditingController(text: _damagedQty.toString());
  }

  @override
  void dispose() {
    _receivedController.dispose();
    _damagedController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_LineItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    int parentReceived = widget.item['quantityReceived'] ?? 0;
    int parentDamaged = widget.item['quantityDamaged'] ?? 0;

    if (parentReceived != _receivedQty || parentDamaged != _damagedQty) {
      setState(() {
        _receivedQty = parentReceived;
        _damagedQty = parentDamaged;
        _receivedController.text = parentReceived.toString();
        _damagedController.text = parentDamaged.toString();
      });
    }
  }

  void _initializeQuantities() {
    _orderedQty = widget.item['quantityOrdered'] ?? 0;
    _receivedQty = widget.item['quantityReceived'] ?? 0;
    _damagedQty = widget.item['quantityDamaged'] ?? 0;
    _originalReceivedQty = _receivedQty;
    _originalDamagedQty = _damagedQty;
  }

  void _updateReceived(int value) {
    // Validate: cannot go below 0
    if (value < 0) {
      _receivedController.text = _receivedQty.toString();
      SnackbarManager().showErrorMessage(
        context,
        message: 'Received quantity cannot be negative',
      );
      return;
    }

    // Validate: total cannot exceed ordered
    if (value + _damagedQty > _orderedQty) {
      _receivedController.text = _receivedQty.toString();
      SnackbarManager().showErrorMessage(
        context,
        message:
            'Total quantity (received + damaged) cannot exceed ordered quantity ($_orderedQty)',
      );
      return;
    }

    // Validate: cannot reduce below original saved value for partially received items
    if (widget.isPartiallyReceived && value < _originalReceivedQty) {
      _receivedController.text = _receivedQty.toString();
      SnackbarManager().showWarningMessage(
        context,
        message: 'Cannot reduce below saved quantity ($_originalReceivedQty)',
      );
      return;
    }

    setState(() {
      _receivedQty = value;
      _receivedController.text = value.toString();
    });

    widget.item['quantityReceived'] = value;
    widget.onProcessItem(widget.item, widget.itemIndex, value, _damagedQty);
    widget.onQuantityChanged();
  }

  void _updateDamaged(int value) async {
    // Validate: cannot go below 0
    if (value < 0) {
      _damagedController.text = _damagedQty.toString();
      SnackbarManager().showErrorMessage(
        context,
        message: 'Damaged quantity cannot be negative',
      );
      return;
    }

    // Validate: total cannot exceed ordered
    if (_receivedQty + value > _orderedQty) {
      _damagedController.text = _damagedQty.toString();
      SnackbarManager().showErrorMessage(
        context,
        message:
            'Total quantity (received + damaged) cannot exceed ordered quantity ($_orderedQty)',
      );
      return;
    }

    // Validate: cannot reduce below original saved value for partially received items
    if (widget.isPartiallyReceived && value < _originalDamagedQty) {
      _damagedController.text = _damagedQty.toString();
      SnackbarManager().showWarningMessage(
        context,
        message: 'Cannot reduce below saved quantity ($_originalDamagedQty)',
      );
      return;
    }

    // Check if reducing damaged quantity to 0 and photos are uploaded
    if (value == 0 && _damagedQty > 0 && _hasUploadedPhotos()) {
      print('⚠️ PHOTO WARNING: Reducing damage to 0 but photos are uploaded');
      final shouldProceed = await _showPhotoRemovalConfirmation();
      if (!shouldProceed) {
        _damagedController.text = _damagedQty.toString();
        return;
      }
      // Clear photos if user confirms
      _clearUploadedPhotos();
    }

    setState(() {
      _damagedQty = value;
      _damagedController.text = value.toString();
    });

    widget.item['quantityDamaged'] = value;
    widget.onProcessItem(widget.item, widget.itemIndex, _receivedQty, value);
    widget.onQuantityChanged();
  }

  bool _hasUploadedPhotos() {
    // Check if there are any local discrepancy reports with photos for this item
    return widget.item['localDiscrepancyReport'] != null &&
        (widget.item['localDiscrepancyReport']['photos'] as List?)
                ?.isNotEmpty ==
            true;
  }

  void _clearUploadedPhotos() {
    // Clear the local discrepancy report photos
    if (widget.item['localDiscrepancyReport'] != null) {
      widget.item['localDiscrepancyReport']['photos'] = [];
      print('🗑️ CLEARED: Photos removed from local discrepancy report');
    }
  }

  Future<bool> _showPhotoRemovalConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[700]),
                const SizedBox(width: 8),
                const Text('Remove Photos?'),
              ],
            ),
            content: const Text(
                'You have uploaded photos for this damaged item. If you reduce the damaged quantity to 0, these photos will be removed. Do you want to continue?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Remove Photos'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    // ENHANCED: Get properly resolved product information
    String productName = widget.item['displayName'] ??
        widget.item['productName'] ??
        'Unknown Product';
    String brandName =
        widget.item['brandName'] ?? widget.item['brand'] ?? 'Unknown Brand';
    String categoryName = widget.item['categoryName'] ?? 'N/A';
    String productId = widget.item['productId'] ?? 'N/A';
    String sku = widget.item['sku'] ?? 'N/A';
    String partNumber = widget.item['partNumber'] ?? 'N/A';
    double unitPrice =
        (widget.item['unitPrice'] ?? widget.item['price'] ?? 0).toDouble();

    int remainingQty = _orderedQty - _receivedQty - _damagedQty;
    bool isCompleted =
        remainingQty == 0 && (_receivedQty > 0 || _damagedQty > 0);
    bool canReduceReceived =
        !widget.isPartiallyReceived || _receivedQty > _originalReceivedQty;
    bool canReduceDamaged =
        !widget.isPartiallyReceived || _damagedQty > _originalDamagedQty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? Colors.green[300]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // ENHANCED: Product information chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (brandName != 'N/A' && brandName != 'Unknown Brand')
                          _buildInfoChip('Brand', brandName, Colors.blue),
                        if (categoryName != 'N/A')
                          _buildInfoChip(
                              'Category', categoryName, Colors.green),
                        if (sku != 'N/A')
                          _buildInfoChip('SKU', sku, Colors.purple),
                        if (partNumber != 'N/A')
                          _buildInfoChip('Part', partNumber, Colors.orange),
                        if (productId != 'N/A')
                          _buildInfoChip('ID', productId, Colors.teal),
                      ],
                    ),
                  ],
                ),
              ),
              if (isCompleted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'COMPLETE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildDetailInfo('Ordered', '$_orderedQty PCS', Colors.blue),
              _buildDetailInfo(
                  'Price', 'RM ${unitPrice.toStringAsFixed(2)}', Colors.green),
              _buildDetailInfo('Remaining', '$remainingQty PCS',
                  remainingQty > 0 ? Colors.orange : Colors.green),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuantityInput(
                  label: 'Received',
                  value: _receivedQty,
                  maxValue: _orderedQty - _damagedQty,
                  color: Colors.green,
                  onChanged: _updateReceived,
                  canDecrease: canReduceReceived,
                  controller: _receivedController,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuantityInput(
                  label: 'Damaged',
                  value: _damagedQty,
                  maxValue: _orderedQty - _receivedQty,
                  color: Colors.red,
                  onChanged: _updateDamaged,
                  canDecrease: canReduceDamaged,
                  controller: _damagedController,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_damagedQty > 0) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onReportDiscrepancy,
                icon: Icon(Icons.report_problem,
                    size: 18, color: Colors.orange[700]),
                label: Text(
                  'Report Discrepancy',
                  style: TextStyle(color: Colors.orange[700]),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.orange[300]!),
                  backgroundColor: Colors.orange[50],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDetailInfo(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityInput({
    required String label,
    required int value,
    required int maxValue,
    required Color color,
    required Function(int) onChanged,
    required bool canDecrease,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  onPressed: (value > 0 && canDecrease)
                      ? () {
                          onChanged(value - 1);
                        }
                      : null,
                  icon: Icon(Icons.remove, size: 18),
                  color: (value > 0 && canDecrease)
                      ? Colors.grey[700]
                      : Colors.grey[400],
                  padding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (text) {
                    // Handle empty text (backspace to clear)
                    if (text.isEmpty) {
                      controller.text = '0';
                      onChanged(0);
                      return;
                    }

                    int? newValue = int.tryParse(text);
                    if (newValue != null) {
                      // Validate the new value
                      if (newValue < 0) {
                        SnackbarManager().showErrorMessage(
                          context,
                          message: 'Quantity cannot be negative',
                        );
                        controller.text = value.toString();
                        return;
                      }

                      if (newValue > maxValue) {
                        SnackbarManager().showErrorMessage(
                          context,
                          message:
                              'Cannot exceed maximum quantity of $maxValue',
                        );
                        controller.text = value.toString();
                        return;
                      }

                      onChanged(newValue);
                    } else {
                      // Invalid input, reset to current value
                      controller.text = value.toString();
                    }
                  },
                  onSubmitted: (text) {
                    int? newValue = int.tryParse(text);
                    if (newValue == null ||
                        newValue < 0 ||
                        newValue > maxValue) {
                      controller.text = value.toString();
                      if (newValue != null && newValue > maxValue) {
                        SnackbarManager().showErrorMessage(
                          context,
                          message:
                              'Cannot exceed maximum quantity of $maxValue',
                        );
                      }
                    }
                  },
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  onPressed: value < maxValue
                      ? () {
                          onChanged(value + 1);
                        }
                      : () {
                          // Show validation message when trying to exceed maximum
                          SnackbarManager().showErrorMessage(
                            context,
                            message:
                                'Cannot exceed maximum quantity of $maxValue',
                          );
                        },
                  icon: Icon(Icons.add, size: 18),
                  color: value < maxValue ? Colors.grey[700] : Colors.grey[400],
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
