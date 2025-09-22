// lib/widgets/request_po_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:assignment/models/purchase_order.dart';
import 'package:assignment/services/purchase_order/purchase_order_service.dart';
import 'package:assignment/services/login/load_user_data.dart';
import 'package:assignment/models/user_model.dart';
import 'package:assignment/models/product_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added missing import

class RequestPODialog extends StatefulWidget {
  final String productId;
  final String productName;
  final String category;
  final int currentStock;
  final double? currentPrice;
  final String? brand;
  final String? sku;
  final bool isCriticalStock;

  const RequestPODialog({
    super.key,
    required this.productId,
    required this.productName,
    required this.category,
    required this.currentStock,
    this.currentPrice,
    this.brand,
    this.sku,
    this.isCriticalStock = false,
  });

  @override
  State<RequestPODialog> createState() => _RequestPODialogState();
}

class _RequestPODialogState extends State<RequestPODialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final PurchaseOrderService _purchaseOrderService = PurchaseOrderService();

  UserModel? currentUser;
  bool isLoading = false;
  bool isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _setDefaultQuantity();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      final user = await loadCurrentUser();
      setState(() {
        currentUser = user;
        isLoadingUser = false;
      });
    } catch (e) {
      setState(() {
        isLoadingUser = false;
      });
      _showSnackBar('Failed to load user information', Colors.red);
    }
  }

  void _setDefaultQuantity() {
    // Suggest a reasonable reorder quantity based on stock level
    int suggestedQty;
    if (widget.currentStock <= 5) {
      suggestedQty = 50; // Critical - order more
    } else if (widget.currentStock <= 10) {
      suggestedQty = 30; // Low - moderate order
    } else {
      suggestedQty = 20; // Normal reorder
    }
    _quantityController.text = suggestedQty.toString();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width > 500 ? 400.0 : screenSize.width * 0.9;
    final dialogHeight = screenSize.height * 0.8; // Use 80% of screen height

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: dialogHeight,
          maxWidth: dialogWidth,
        ),
        child: isLoadingUser
            ? _buildLoadingState()
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed header
            _buildHeader(),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),
                    _buildProductInfo(),
                    const SizedBox(height: 20),
                    _buildRequestForm(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Fixed bottom buttons
            Container(
              padding: const EdgeInsets.all(24),
              child: _buildActionButtons(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 200,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.isCriticalStock ? Colors.red[100] : Colors.orange[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.isCriticalStock ? Icons.warning : Icons.shopping_cart,
              color: widget.isCriticalStock ? Colors.red[600] : Colors.orange[600],
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isCriticalStock ? 'Urgent PO Request' : 'Request Purchase Order',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: widget.isCriticalStock ? Colors.red[800] : Colors.orange[800],
                  ),
                ),
                Text(
                  widget.isCriticalStock
                      ? 'Critical stock level - immediate action needed'
                      : 'Low stock detected - request reorder',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildProductInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory, color: Colors.blue[600], size: 16),
              const SizedBox(width: 8),
              const Text(
                'Product Details',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.productName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip('Current Stock', '${widget.currentStock}',
                  widget.currentStock <= 5 ? Colors.red : Colors.orange),
              _buildInfoChip('Category', widget.category, Colors.blue),
              if (widget.brand != null)
                _buildInfoChip('Brand', widget.brand!, Colors.purple),
              if (widget.sku != null)
                _buildInfoChip('SKU', widget.sku!, Colors.green),
              if (widget.currentPrice != null)
                _buildInfoChip('Unit Price', '\$${widget.currentPrice!.toStringAsFixed(2)}', Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: Colors.blue.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildRequestForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quantity field
          TextFormField(
            controller: _quantityController,
            decoration: InputDecoration(
              labelText: 'Requested Quantity',
              hintText: 'Enter quantity to order',
              prefixIcon: Icon(Icons.numbers, color: Colors.blue[600]),
              border: const OutlineInputBorder(),
              helperText: 'Suggested based on current stock level',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Quantity is required';
              final qty = int.tryParse(value!);
              if (qty == null || qty <= 0) return 'Enter a valid quantity';
              if (qty > 10000) return 'Quantity seems too large';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Reason/Notes field
          TextFormField(
            controller: _reasonController,
            decoration: InputDecoration(
              labelText: 'Reason for Request',
              hintText: 'Why is this order needed? (optional)',
              prefixIcon: Icon(Icons.note_add, color: Colors.blue[600]),
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),

          if (widget.currentPrice != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimated Cost',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _quantityController,
                    builder: (context, value, child) {
                      final qty = int.tryParse(value.text) ?? 0;
                      final total = qty * widget.currentPrice!;
                      return Text(
                        '\$${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      );
                    },
                  ),
                  Text(
                    '${_quantityController.text.isEmpty ? "0" : _quantityController.text} × \$${widget.currentPrice!.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isLoading ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: isLoading ? null : _submitRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isCriticalStock ? Colors.red[600] : Colors.orange[600],
              foregroundColor: Colors.white,
            ),
            child: isLoading
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Text(widget.isCriticalStock ? 'Submit Urgent Request' : 'Submit Request'),
          ),
        ),
      ],
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (currentUser == null) {
      _showSnackBar('User information not available', Colors.red);
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final quantity = int.parse(_quantityController.text);
      final reason = _reasonController.text.trim();
      final estimatedPrice = widget.currentPrice ?? 0.0;
      final lineTotal = quantity * estimatedPrice;

      // Create POLineItem for the request
      final lineItem = POLineItem(
        id: 'line_${DateTime.now().millisecondsSinceEpoch}',
        productId: widget.productId,
        productName: widget.productName,
        productSKU: widget.sku,
        brand: widget.brand,
        quantityOrdered: quantity,
        unitPrice: estimatedPrice,
        lineTotal: lineTotal,
        notes: reason.isNotEmpty ? reason : null,
        isNewProduct: false,
        status: 'PENDING',
      );

      // Use the same helper method as create PO screen
      final purchaseOrder = PurchaseOrderService.createFromFormData(
        priority: widget.isCriticalStock ? POPriority.URGENT : POPriority.HIGH,
        supplierId: 'TBD', // Placeholder - manager will fill
        supplierName: 'To be determined by manager',
        expectedDeliveryDate: DateTime.now().add(const Duration(days: 14)),
        lineItems: [lineItem],
        status: POStatus.PENDING_APPROVAL, // Key difference from manager PO
        createdByUserId: currentUser!.employeeId!,
        createdByUserName: '${currentUser!.firstName} ${currentUser!.lastName}',
        creatorRole: POCreatorRole.WORKSHOP_MANAGER,
        supplierEmail: null, // Manager will fill
        supplierPhone: null, // Manager will fill
        notes: widget.isCriticalStock
            ? 'URGENT: Critical stock level (${widget.currentStock} remaining). ${reason.isNotEmpty ? "Reason: $reason" : ""}'
            : 'Low stock reorder request. ${reason.isNotEmpty ? "Reason: $reason" : ""}',
        deliveryInstructions: null, // Manager will fill
        discountAmount: 0.0, // Manager will set
        shippingCost: 0.0, // Manager will set
        taxRate: 0.0, // Manager will set
        deliveryAddress: 'Default Warehouse Address',
        jobId: null,
        jobNumber: null,
        customerName: null,
      );

      // Submit the request using existing service method
      final poId = await _purchaseOrderService.createPurchaseOrder(purchaseOrder);


      await _createProductItemsForPurchaseOrder(poId, [lineItem]);

      // Success - close dialog and let inventory screen show message
      if (mounted) {
        Navigator.pop(context, poId);
      }

    } catch (e) {
      String errorMessage = 'Failed to submit PO request';

      final errorString = e.toString().toLowerCase();
      if (errorString.contains('permission') || errorString.contains('denied')) {
        errorMessage = 'Permission denied. Please check your access rights.';
      } else if (errorString.contains('network') || errorString.contains('connection')) {
        errorMessage = 'Network error. Please check connection and try again.';
      } else if (errorString.contains('firebase') || errorString.contains('firestore')) {
        errorMessage = 'Database error. Please try again later.';
      }

      if (mounted) {
        _showSnackBar(errorMessage, Colors.red);
      }
      print('PO request error: $e');

    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _createProductItemsForPurchaseOrder(
      String purchaseOrderId,
      List<POLineItem> lineItems
      ) async {
    try {
      final productItemService = ProductItemService();

      // Track total items created for logging
      int totalItemsCreated = 0;

      // Process each line item
      for (final lineItem in lineItems) {
        // Create individual ProductItem records for the quantity ordered
        final createdItemIds = await productItemService.createProductItems(
          lineItem.productId,           // Product ID from line item
          purchaseOrderId,              // Purchase Order ID
          lineItem.quantityOrdered,     // Number of items to create
        );

        totalItemsCreated += createdItemIds.length;

        // Optional: Log the created items
        print('Created ${createdItemIds.length} items for product ${lineItem.productName}');
        print('Item IDs: ${createdItemIds.join(', ')}');
      }

      print('Total ProductItems created: $totalItemsCreated for PO: $purchaseOrderId');

    } catch (e) {
      // Log error but don't fail the entire PO creation
      print('Error creating ProductItems: $e');

      // Optionally show a warning to the user
      _showSnackBar('Purchase Order created, but there was an issue creating inventory items. Please check manually.', Colors.orange);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              backgroundColor == Colors.green ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}