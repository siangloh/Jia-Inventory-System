import 'package:flutter/material.dart';
import '../../../services/adjustment/snackbar_manager.dart';

class LineItemCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final int index;
  final bool isCompleted;
  final bool isAllReceived;
  final Function(Map<String, dynamic>, int, bool) onToggleAllReceived;
  final Function(Map<String, dynamic>, int, int, int) onProcessItem;
  final Function(Map<String, dynamic>, int) onReportDiscrepancy;

  const LineItemCard({
    Key? key,
    required this.item,
    required this.index,
    required this.isCompleted,
    required this.isAllReceived,
    required this.onToggleAllReceived,
    required this.onProcessItem,
    required this.onReportDiscrepancy,
  }) : super(key: key);

  @override
  State<LineItemCard> createState() => _LineItemCardState();
}

class _LineItemCardState extends State<LineItemCard> {
  late int _receivedQty;
  late int _damagedQty;
  late int _orderedQty;
  late int _remainingQty;
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
  void didUpdateWidget(LineItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    int newReceived = widget.item['quantityReceived'] ?? 0;
    int newDamaged = widget.item['quantityDamaged'] ?? 0;
    
    if (newReceived != _receivedQty || newDamaged != _damagedQty) {
      setState(() {
        _receivedQty = newReceived;
        _damagedQty = newDamaged;
        _remainingQty = _orderedQty - _receivedQty - _damagedQty;
        _receivedController.text = newReceived.toString();
        _damagedController.text = newDamaged.toString();
      });
    }
  }

  void _initializeQuantities() {
    _orderedQty = widget.item['quantityOrdered'] ?? 0;
    _receivedQty = widget.item['quantityReceived'] ?? 0;
    _damagedQty = widget.item['quantityDamaged'] ?? 0;
    _remainingQty = _orderedQty - _receivedQty - _damagedQty;
    _originalReceivedQty = _receivedQty;
    _originalDamagedQty = _damagedQty;
  }

  void _updateQuantities() {
    setState(() {
      _remainingQty = _orderedQty - _receivedQty - _damagedQty;
    });
  }

  void _onReceivedChanged(int value) {
    if (value < _originalReceivedQty) {
      SnackbarManager().showWarningMessage(
        context,
        message: 'Cannot reduce below saved quantity ($_originalReceivedQty)',
      );
      _receivedController.text = _receivedQty.toString();
      return;
    }
    
    if (value + _damagedQty > _orderedQty) {
      SnackbarManager().showErrorMessage(
        context,
        message: 'Total cannot exceed ordered quantity ($_orderedQty)',
      );
      _receivedController.text = _receivedQty.toString();
      return;
    }
    
    setState(() {
      _receivedQty = value;
      _updateQuantities();
      _receivedController.text = value.toString();
    });
    
    widget.onProcessItem(widget.item, widget.index, _receivedQty, _damagedQty);
  }

  void _onDamagedChanged(int value) {
    if (value < _originalDamagedQty) {
      SnackbarManager().showWarningMessage(
        context,
        message: 'Cannot reduce below saved quantity ($_originalDamagedQty)',
      );
      _damagedController.text = _damagedQty.toString();
      return;
    }
    
    if (_receivedQty + value > _orderedQty) {
      SnackbarManager().showErrorMessage(
        context,
        message: 'Total cannot exceed ordered quantity ($_orderedQty)',
      );
      _damagedController.text = _damagedQty.toString();
      return;
    }
    
    setState(() {
      _damagedQty = value;
      _updateQuantities();
      _damagedController.text = value.toString();
    });
    
    widget.onProcessItem(widget.item, widget.index, _receivedQty, _damagedQty);
  }

  void _processItem() {
    if (_receivedQty + _damagedQty <= _orderedQty) {
      widget.onProcessItem(widget.item, widget.index, _receivedQty, _damagedQty);
    } else {
      SnackbarManager().showErrorMessage(
        context,
        message: 'Total quantity cannot exceed ordered quantity ($_orderedQty)',
      );
    }
  }

  // ENHANCED: Helper method with N/A fallback for display
  String _getDisplayValue(dynamic value, {String defaultValue = 'N/A'}) {
    if (value == null) return defaultValue;
    String stringValue = value.toString().trim();
    if (stringValue.isEmpty || stringValue == 'null') return defaultValue;
    return stringValue;
  }

  // ENHANCED: Check if value should be displayed
  bool _shouldDisplay(dynamic value) {
    if (value == null) return false;
    String stringValue = value.toString().trim();
    return stringValue.isNotEmpty && stringValue != 'null' && stringValue != 'N/A';
  }

  Widget _buildQuantityInput({
    required String label,
    required int value,
    required int maxValue,
    required int minValue,
    required Color color,
    required Function(int) onChanged,
    required TextEditingController controller,
  }) {
    bool canDecrease = value > minValue;
    bool canIncrease = value < maxValue;
    
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
                  onPressed: canDecrease ? () => onChanged(value - 1) : null,
                  icon: Icon(Icons.remove, size: 18),
                  color: canDecrease ? Colors.grey[700] : Colors.grey[400],
                  padding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (text) {
                    int? newValue = int.tryParse(text);
                    if (newValue != null) {
                      onChanged(newValue);
                    }
                  },
                  onSubmitted: (text) {
                    int? newValue = int.tryParse(text);
                    if (newValue == null || newValue < minValue || newValue > maxValue) {
                      controller.text = value.toString();
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
                  onPressed: canIncrease ? () => onChanged(value + 1) : null,
                  icon: Icon(Icons.add, size: 18),
                  color: canIncrease ? Colors.grey[700] : Colors.grey[400],
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ENHANCED: Build expandable product details with proper field handling
  Widget _buildProductDetails() {
    return ExpansionTile(
      title: Text(
        'Product Details',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
      leading: Icon(Icons.info_outline, size: 18, color: Colors.blue[600]),
      childrenPadding: EdgeInsets.all(12),
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            children: _buildDetailRows(),
          ),
        ),
      ],
    );
  }

  // ENHANCED: Build detail rows with proper optional field handling
  List<Widget> _buildDetailRows() {
    List<Widget> rows = [];
    
    // Essential details (always show if available)
    if (_shouldDisplay(widget.item['productId'])) {
      rows.add(_buildDetailRow('Product ID', _getDisplayValue(widget.item['productId'])));
    }
    
    // Optional fields - only show if they have meaningful values
    if (_shouldDisplay(widget.item['sku'])) {
      rows.add(_buildDetailRow('SKU', _getDisplayValue(widget.item['sku'])));
    }
    
    if (_shouldDisplay(widget.item['partNumber'])) {
      rows.add(_buildDetailRow('Part Number', _getDisplayValue(widget.item['partNumber'])));
    }
    
    if (_shouldDisplay(widget.item['description'])) {
      rows.add(_buildDetailRow('Description', _getDisplayValue(widget.item['description'])));
    }
    
    if (_shouldDisplay(widget.item['categoryName'])) {
      rows.add(_buildDetailRow('Category', _getDisplayValue(widget.item['categoryName'])));
    }
    
    // Physical specifications - enhanced display
    if (_shouldDisplay(widget.item['dimensionsDisplay'])) {
      rows.add(_buildDetailRow('Dimensions', _getDisplayValue(widget.item['dimensionsDisplay'])));
    }
    
    if (_shouldDisplay(widget.item['weight'])) {
      rows.add(_buildDetailRow('Weight', _getDisplayValue(widget.item['weight'])));
    }
    
    // Storage requirements - only if specified
    if (_shouldDisplay(widget.item['storageType'])) {
      rows.add(_buildDetailRow('Storage Type', _getDisplayValue(widget.item['storageType'])));
    }
    
    if (_shouldDisplay(widget.item['movementFrequency'])) {
      rows.add(_buildDetailRow('Movement Frequency', _getDisplayValue(widget.item['movementFrequency'])));
    }
    
    // Safety flags - only show if true
    if (widget.item['requiresClimateControl'] == true) {
      rows.add(_buildDetailRow('Climate Control', 'Required', valueColor: Colors.orange[700]));
    }
    
    if (widget.item['isHazardousMaterial'] == true) {
      rows.add(_buildDetailRow('Hazardous Material', 'Yes', valueColor: Colors.red[700]));
    }
    
    // If no meaningful details found, show basic info
    if (rows.isEmpty) {
      rows.add(_buildDetailRow('Status', 'Basic product information available'));
    }
    
    return rows;
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: valueColor ?? Colors.grey[800],
                fontWeight: valueColor != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ENHANCED: Get properly resolved product information with fallbacks
    String productName = _getDisplayValue(
      widget.item['displayName'] ?? widget.item['productName'],
      defaultValue: 'Unknown Product'
    );
    String brandName = _getDisplayValue(
      widget.item['brandName'] ?? widget.item['brand'],
      defaultValue: 'Unknown Brand'
    );
    String productId = _getDisplayValue(widget.item['productId']);
    String categoryName = _getDisplayValue(widget.item['categoryName']);
    double unitPrice = (widget.item['unitPrice'] ?? widget.item['price'] ?? 0).toDouble();
    
    bool isCompleted = _remainingQty == 0 && (_receivedQty > 0 || _damagedQty > 0);
    bool isPartiallyReceived = _receivedQty > 0 && _remainingQty > 0;
    bool hasValidationError = _receivedQty + _damagedQty > _orderedQty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? Colors.green[200]! : 
                hasValidationError ? Colors.red[300]! : Colors.grey[200]!,
          width: hasValidationError ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ENHANCED: Header with better product information display
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isCompleted ? Colors.green : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: isCompleted 
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                    ),
                    const SizedBox(width: 12),
                    
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          
                          // ENHANCED: Better product info chips layout
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (brandName != 'N/A') 
                                _buildInfoChip('Brand', brandName, Colors.blue),
                              if (categoryName != 'N/A')
                                _buildInfoChip('Category', categoryName, Colors.green),
                              if (productId != 'N/A')
                                _buildInfoChip('ID', productId, Colors.purple),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCompleted ? Colors.green[100] : 
                               (isPartiallyReceived ? Colors.orange[100] : Colors.grey[100]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isCompleted ? 'COMPLETE' : 
                        (isPartiallyReceived ? 'PARTIAL' : 'PENDING'),
                        style: TextStyle(
                          color: isCompleted ? Colors.green[800] : 
                                 (isPartiallyReceived ? Colors.orange[800] : Colors.grey[800]),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Product summary info
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailInfo('Ordered', '$_orderedQty PCS', Colors.blue),
                    ),
                    Expanded(
                      child: _buildDetailInfo('Price', 'RM ${unitPrice.toStringAsFixed(2)}', Colors.green),
                    ),
                    Expanded(
                      child: _buildDetailInfo('Remaining', '$_remainingQty PCS', 
                        _remainingQty > 0 ? Colors.orange : Colors.green),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Input fields and actions
                if (!isCompleted) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuantityInput(
                          label: 'Qty Received',
                          value: _receivedQty,
                          maxValue: _orderedQty - _damagedQty,
                          minValue: _originalReceivedQty,
                          onChanged: _onReceivedChanged,
                          color: Colors.green,
                          controller: _receivedController,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildQuantityInput(
                          label: 'Qty Damaged',
                          value: _damagedQty,
                          maxValue: _orderedQty - _receivedQty,
                          minValue: _originalDamagedQty,
                          onChanged: _onDamagedChanged,
                          color: Colors.red,
                          controller: _damagedController,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _processItem,
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Process'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      if (_damagedQty > 0) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => widget.onReportDiscrepancy(widget.item, widget.index),
                            icon: const Icon(Icons.warning, size: 16),
                            label: const Text('Report'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  if (hasValidationError) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Total quantity cannot exceed ordered quantity ($_orderedQty)',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Item fully received',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (_damagedQty > 0)
                          OutlinedButton.icon(
                            onPressed: () => widget.onReportDiscrepancy(widget.item, widget.index),
                            icon: const Icon(Icons.warning, size: 16),
                            label: const Text('Report'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                              minimumSize: Size(100, 32),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Expandable product details
          _buildProductDetails(),
        ],
      ),
    );
  }

  // ENHANCED: Info chip widget
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
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDetailInfo(String label, String value, Color color) {
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
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}