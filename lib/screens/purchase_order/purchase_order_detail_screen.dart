import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:assignment/models/supplier_model.dart';
import 'package:assignment/models/purchase_order.dart';
import 'package:assignment/services/purchase_order/purchase_order_service.dart';
import 'package:assignment/models/product_model.dart';

class PurchaseOrderDetailScreen extends StatefulWidget {
  final String purchaseOrderId;
  final PurchaseOrder? initialPurchaseOrder; // Optional initial data

  const PurchaseOrderDetailScreen({
    super.key,
    required this.purchaseOrderId,
    this.initialPurchaseOrder,
  });

  @override
  State<PurchaseOrderDetailScreen> createState() => _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends State<PurchaseOrderDetailScreen>
    with SingleTickerProviderStateMixin {

  final List<Supplier> availableSuppliers = [
    Supplier.fromMap({
      'id': 'supplier_1',
      'name': 'Auto Parts Direct',
      'email': 'sales@autopartsdirect.com',
      'phone': '+1-555-0123',
    }),
    Supplier.fromMap({
      'id': 'supplier_2',
      'name': 'Engine Components Ltd',
      'email': 'orders@enginecomponents.com',
      'phone': '+1-555-0456',
    }),
    Supplier.fromMap({
      'id': 'supplier_3',
      'name': 'Filter Tech Solutions',
      'email': 'sales@filtertech.com',
      'phone': '+1-555-0789',
    }),
    Supplier.fromMap({
      'id': 'supplier_4',
      'name': 'Fluid Solutions Inc',
      'email': 'contact@fluidsolutions.com',
      'phone': '+1-555-0321',
    }),
    Supplier.fromMap({
      'id': 'supplier_5',
      'name': 'Lighting Solutions',
      'email': 'orders@lightingsolutions.com',
      'phone': '+1-555-0654',
    }),
  ];

  String? selectedSupplierId;
  final PurchaseOrderService _purchaseOrderService = PurchaseOrderService();
  final _formKey = GlobalKey<FormState>();

  late TabController _tabController;

  // Real-time data
  StreamSubscription<PurchaseOrder?>? _purchaseOrderSubscription;
  PurchaseOrder? _currentPurchaseOrder;
  bool _isLoading = false;
  String? _loadError;

  // Form state
  bool isEditing = false;
  bool isSaving = false;

  // Form controllers
  late TextEditingController _supplierNameController;
  late TextEditingController _notesController;

  // Form values
  late POPriority _selectedPriority;
  late POStatus _selectedStatus;
  late DateTime? _expectedDeliveryDate;
  late List<POLineItem> _lineItems;

  PurchaseOrder? _originalOrder;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeControllers();
    _setupRealtimeListener();
  }

  void _initializeControllers() {
    _supplierNameController = TextEditingController();
    _notesController = TextEditingController();
  }

  void _setupRealtimeListener() {
    setState(() {
      _isLoading = true;
      _loadError = null;

      if (widget.initialPurchaseOrder != null) {
        _currentPurchaseOrder = widget.initialPurchaseOrder;
        _initializeForm(_currentPurchaseOrder!);
        _isLoading = false;
      }
    });

    _purchaseOrderSubscription = _purchaseOrderService
        .getPurchaseOrderStream(widget.purchaseOrderId)
        .listen(
          (purchaseOrder) {
        if (mounted) {
          setState(() {
            _currentPurchaseOrder = purchaseOrder;
            _isLoading = false;
            _loadError = null;
          });

          if (purchaseOrder != null) {
            // Update form only if not currently editing
            if (!isEditing) {
              _initializeForm(purchaseOrder);
            }
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _loadError = 'Failed to load purchase order: ${error.toString()}';
          });
        }
      },
    );
  }

  void _initializeForm(PurchaseOrder purchaseOrder) {
    _originalOrder = purchaseOrder;

    _supplierNameController.text = purchaseOrder.supplierName;
    _notesController.text = purchaseOrder.notes ?? '';

    final supplierExists = availableSuppliers.any((s) => s.id == purchaseOrder.supplierId);
    selectedSupplierId = supplierExists ? purchaseOrder.supplierId : null;

    _selectedPriority = purchaseOrder.priority;
    _selectedStatus = purchaseOrder.status;
    _expectedDeliveryDate = purchaseOrder.expectedDeliveryDate;
    _lineItems = List.from(purchaseOrder.lineItems);
  }

  @override
  void dispose() {
    _purchaseOrderSubscription?.cancel();
    _tabController.dispose();
    _supplierNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _canEdit {
    return _currentPurchaseOrder?.status == POStatus.PENDING_APPROVAL;
  }

  bool get _canUpdateStatus {
    return _currentPurchaseOrder?.status != POStatus.COMPLETED &&
        _currentPurchaseOrder?.status != POStatus.CANCELLED &&
        _currentPurchaseOrder?.status != POStatus.READY &&
        _currentPurchaseOrder?.status != POStatus.APPROVED &&
        _currentPurchaseOrder?.status != POStatus.REJECTED;
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen
    if (_isLoading && _currentPurchaseOrder == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
          backgroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading purchase order details...'),
            ],
          ),
        ),
      );
    }

    // Show error screen
    if (_loadError != null && _currentPurchaseOrder == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    _setupRealtimeListener();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show purchase order not found
    if (_currentPurchaseOrder == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Not Found'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'Purchase order not found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'This purchase order may have been deleted or you may not have access to it.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Show real-time update indicator
          if (_loadError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _loadError!,
                      style: TextStyle(color: Colors.red[700], fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _setupRealtimeListener,
                    child: const Text('Retry', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          Form(
            key: _formKey,
            child: Expanded(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildTabBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildLineItemsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(_currentPurchaseOrder?.poNumber ?? 'Purchase Order'),
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      actions: [
        // Show real-time connection indicator
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (_canEdit)
          IconButton(
            icon: Icon(isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              setState(() {
                if (isEditing) {
                  _resetForm();
                }
                isEditing = !isEditing;
              });
            },
            tooltip: isEditing ? 'Cancel Edit' : 'Edit Order',
          ),
        if (_hasAvailableMenuActions())
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              if (_canUpdateStatus && !isEditing)
                const PopupMenuItem(
                  value: 'update_status',
                  child: Row(
                    children: [
                      Icon(Icons.update, size: 16),
                      SizedBox(width: 8),
                      Text('Update Status'),
                    ],
                  ),
                ),
              if (_currentPurchaseOrder?.status != POStatus.COMPLETED &&
                  _currentPurchaseOrder?.status != POStatus.CANCELLED &&
                  _currentPurchaseOrder?.status != POStatus.READY &&
                  _currentPurchaseOrder?.status != POStatus.APPROVED &&
                  _currentPurchaseOrder?.status != POStatus.REJECTED)
                const PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(Icons.cancel, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Cancel Order', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  bool _hasAvailableMenuActions() {
    return (_canUpdateStatus && !isEditing) ||
        (_currentPurchaseOrder?.status == POStatus.PENDING_APPROVAL);
  }

  Widget _buildHeader() {
    final purchaseOrder = _currentPurchaseOrder!;
    final isOverdue = purchaseOrder.expectedDeliveryDate != null &&
        purchaseOrder.expectedDeliveryDate!.isBefore(DateTime.now()) &&
        purchaseOrder.status != POStatus.COMPLETED &&
        purchaseOrder.status != POStatus.CANCELLED;

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      purchaseOrder.supplierName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Created by ${purchaseOrder.createdByUserName}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusChip(_selectedStatus),
                  const SizedBox(height: 8),
                  _buildPriorityChip(_selectedPriority),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Total Amount',
                  'RM ${_calculateCurrentTotal().toStringAsFixed(2)}',
                  Icons.attach_money,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'Items',
                  '${_lineItems.length}',
                  Icons.inventory,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  isOverdue ? 'Overdue' : 'Delivery',
                  _expectedDeliveryDate != null
                      ? _formatDate(_expectedDeliveryDate!)
                      : 'Not Set',
                  Icons.local_shipping,
                  isOverdue ? Colors.red : Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _calculateCurrentTotal() {
    return _lineItems.fold<double>(0.0, (sum, item) => sum + item.lineTotal);
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Theme.of(context).primaryColor,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Line Items'),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final purchaseOrder = _currentPurchaseOrder!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            'Basic Information',
            [
              _buildReadOnlyField('PO Number', purchaseOrder.poNumber),
              _buildReadOnlyField('Created Date', _formatDate(purchaseOrder.createdDate)),
              _buildReadOnlyField('Created By', purchaseOrder.createdByUserName),
              _buildReadOnlyField('Supplier ID', purchaseOrder.supplierId),
              if (isEditing)
                _buildSupplierDropdown()
              else
                _buildReadOnlyField('Supplier Name', purchaseOrder.supplierName),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Order Details',
            [
              if (isEditing)
                _buildPriorityDropdown()
              else
                _buildReadOnlyField('Priority', _selectedPriority.toString().split('.').last),
              _buildReadOnlyField('Status', _selectedStatus.toString().split('.').last.replaceAll('_', ' ')),
              if (isEditing)
                _buildDatePicker()
              else
                _buildReadOnlyField(
                    'Expected Delivery Date',
                    _expectedDeliveryDate != null ? _formatDate(_expectedDeliveryDate!) : 'Not set'
                ),
              _buildReadOnlyField('Total Amount', 'RM ${_calculateCurrentTotal().toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Additional Information',
            [
              if (isEditing)
                _buildEditableField(
                  'Notes',
                  _notesController,
                  maxLines: 3,
                )
              else
                _buildReadOnlyField('Notes', purchaseOrder.notes ?? 'No notes'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierDropdown() {
    final currentSupplierName = _supplierNameController.text;
    final isCustomSupplier = selectedSupplierId == null && currentSupplierName.isNotEmpty;

    return Column(
      children: [
        if (isCustomSupplier) ...[
          // Info message for custom supplier
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Select New Supplier',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Current: $currentSupplierName',
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please select a supplier from the predefined list below.',
                  style: TextStyle(
                    color: Colors.blue[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Dropdown for supplier selection (required for custom suppliers)
        DropdownButtonFormField<String>(
          value: selectedSupplierId,
          decoration: InputDecoration(
            labelText: isCustomSupplier ? 'Select New Supplier (Required)' : 'Choose Supplier',
            prefixIcon: const Icon(Icons.business),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          hint: Text(isCustomSupplier ? 'Must select from list' : 'Select supplier'),
          items: availableSuppliers.map((supplier) {
            return DropdownMenuItem(
              value: supplier.id,
              child: Text(
                supplier.name,
                overflow: TextOverflow.ellipsis, // Prevent overflow
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedSupplierId = value;
              if (value != null) {
                final selectedSupplier = availableSuppliers.firstWhere((s) => s.id == value);
                _supplierNameController.text = selectedSupplier.name;
              }
            });
          },
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return isCustomSupplier
                  ? 'Must select a supplier from the list'
                  : 'Please select a supplier';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildLineItemsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (isEditing && _canEdit)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton.icon(
                onPressed: _addNewLineItem,
                icon: const Icon(Icons.add),
                label: const Text('Add Line Item'),
              ),
            ),
          ..._lineItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildLineItemCard(item, index);
          }).toList(),
          if (_lineItems.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No line items'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLineItemCard(POLineItem item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (isEditing && _canEdit)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _removeLineItem(index),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (item.partNumber != null && item.partNumber!.isNotEmpty)
              Text(
                'Part Number: ${item.partNumber}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildLineItemDetail('Quantity', '${item.quantityOrdered}'),
                ),
                Expanded(
                  child: _buildLineItemDetail('Unit Price', 'RM ${item.unitPrice.toStringAsFixed(2)}'),
                ),
                Expanded(
                  child: _buildLineItemDetail('Total', 'RM ${item.lineTotal.toStringAsFixed(2)}'),
                ),
              ],
            ),
            if (isEditing && _canEdit) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('qty_${item.id}_$index'),
                      initialValue: item.quantityOrdered.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _updateLineItemQuantity(index, value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('price_${item.id}_$index'),
                      initialValue: item.unitPrice.toStringAsFixed(2),
                      decoration: InputDecoration(
                        labelText: 'Unit Price (Read-only)',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        prefixText: 'RM ',
                        filled: true,
                        fillColor: Colors.grey[100], // Light grey background to indicate read-only
                      ),
                      readOnly: true, // Make field read-only
                      style: TextStyle(
                        color: Colors.grey[600], // Muted text color
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLineItemDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(
      String label,
      TextEditingController controller, {
        int maxLines = 1,
        String? Function(String?)? validator,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        maxLines: maxLines,
        validator: validator,
      ),
    );
  }

  Widget _buildPriorityDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<POPriority>(
        value: _selectedPriority,
        decoration: const InputDecoration(
          labelText: 'Priority',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: POPriority.values.map((priority) {
          return DropdownMenuItem(
            value: priority,
            child: Text(priority.toString().split('.').last),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedPriority = value;
            });
          }
        },
      ),
    );
  }

  Widget _buildDatePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _expectedDeliveryDate ?? DateTime.now().add(const Duration(days: 7)),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (date != null) {
            setState(() {
              _expectedDeliveryDate = date;
            });
          }
        },
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Expected Delivery Date',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            suffixIcon: Icon(Icons.calendar_today),
          ),
          child: Text(
            _expectedDeliveryDate != null
                ? _formatDate(_expectedDeliveryDate!)
                : 'Select date',
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    if (!isEditing) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey, width: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isSaving ? null : () {
                _resetForm();
                setState(() {
                  isEditing = false;
                });
              },
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: isSaving ? null : _saveChanges,
              child: isSaving
                  ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(POStatus status) {
    Color color;
    String text = status.toString().split('.').last.replaceAll('_', ' ');

    switch (status) {
      case POStatus.READY:
        color = Colors.lightGreen;
        break;
      case POStatus.PARTIALLY_RECEIVED:
          color = Colors.lightGreen;
          break;
      case POStatus.PENDING_APPROVAL:
        color = Colors.orange;
        break;
      case POStatus.REJECTED:
        color = Colors.red;
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    if (_originalOrder != null) {
      _supplierNameController.text = _originalOrder!.supplierName;
      _notesController.text = _originalOrder!.notes ?? '';

      final supplierExists = availableSuppliers.any((s) => s.id == _originalOrder!.supplierId);
      selectedSupplierId = supplierExists ? _originalOrder!.supplierId : null;

      _selectedPriority = _originalOrder!.priority;
      _selectedStatus = _originalOrder!.status;
      _expectedDeliveryDate = _originalOrder!.expectedDeliveryDate;
      _lineItems = List.from(_originalOrder!.lineItems);
    }
  }

  void _addNewLineItem() {
    final newItem = POLineItem(
      id: 'new_${DateTime.now().millisecondsSinceEpoch}',
      productId: '',
      productName: 'New Product',
      quantityOrdered: 1,
      unitPrice: 0.0,
      lineTotal: 0.0,
      isNewProduct: true,
      status: 'PENDING',
    );

    setState(() {
      _lineItems.add(newItem);
    });
  }

  void _removeLineItem(int index) {
    setState(() {
      _lineItems.removeAt(index);
    });
  }

  void _updateLineItemQuantity(int index, String value) {
    final quantity = int.tryParse(value) ?? 1;
    setState(() {
      _lineItems[index] = _lineItems[index].copyWith(
        quantityOrdered: quantity,
        lineTotal: quantity * _lineItems[index].unitPrice,
      );
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if trying to save with custom supplier
    if (selectedSupplierId == null) {
      _showSnackBar('Cannot save: Please select a supplier from the predefined list', Colors.red);
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      // Calculate new total
      final newTotal = _lineItems.fold<double>(
        0.0,
            (sum, item) => sum + item.lineTotal,
      );

      final updatedOrder = _currentPurchaseOrder!.copyWith(
        supplierId: selectedSupplierId!, // Now guaranteed to be non-null
        supplierName: _supplierNameController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        priority: _selectedPriority,
        expectedDeliveryDate: _expectedDeliveryDate,
        lineItems: _lineItems,
        totalAmount: newTotal,
      );

      await _purchaseOrderService.updatePurchaseOrder(updatedOrder);

      setState(() {
        isEditing = false;
        isSaving = false;
      });

      _showSnackBar('Purchase order updated successfully!', Colors.green);

    } catch (e) {
      setState(() {
        isSaving = false;
      });
      _showSnackBar('Failed to update purchase order: $e', Colors.red);
    }
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'update_status':
        _showStatusUpdateDialog();
        break;
      case 'cancel':
        _showCancelOrderDialog();
        break;
    }
  }

  void _showStatusUpdateDialog() {

    final hasCustomSupplier = selectedSupplierId == null &&
        _supplierNameController.text.isNotEmpty;

    if (hasCustomSupplier) {
      // Show message for custom supplier
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Update Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_outlined, size: 48, color: Colors.orange[600]),
              const SizedBox(height: 16),
              const Text(
                'Supplier Required',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Please select a supplier from the predefined list before updating the status.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Switch to edit mode to select supplier
                setState(() {
                  isEditing = true;
                });
              },
              child: const Text('Select Supplier'),
            ),
          ],
        ),
      );
      return;
    }

    final availableStatuses = _getAvailableStatusOptions();

    if (availableStatuses.isEmpty) {
      // Show message when no status changes are available
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update Status'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No status changes available',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'This purchase order\'s status cannot be changed at this time.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _getAvailableStatusOptions().map((status) {
            return ListTile(
              title: Text(status.toString().split('.').last.replaceAll('_', ' ')),
              leading: Radio<POStatus>(
                value: status,
                groupValue: _selectedStatus,
                onChanged: (value) {
                  if (value != null) {
                    Navigator.of(context).pop();
                    _updateStatus(value);
                  }
                },
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  List<POStatus> _getAvailableStatusOptions() {
    final currentStatus = _currentPurchaseOrder?.status;

    // Remove COMPLETED and READY (handled by other processes)
    List<POStatus> availableStatuses = POStatus.values
        .where((status) => status != POStatus.COMPLETED && status != POStatus.READY)
        .toList();

    // Apply transition rules based on current status
    switch (currentStatus) {
      case POStatus.PENDING_APPROVAL:
        return [POStatus.APPROVED, POStatus.REJECTED,POStatus.CANCELLED];

      case POStatus.APPROVED:
      case POStatus.REJECTED:
      case POStatus.READY:
      // Cannot change status once approved or rejected
        availableStatuses = [];
        break;

      case POStatus.COMPLETED:
      case POStatus.CANCELLED:
      // Cannot change from these final states
        availableStatuses = [];
        break;

      default:
      // For other statuses, remove the current status from options
        availableStatuses = availableStatuses
            .where((status) => status != currentStatus)
            .toList();
    }

    return availableStatuses;
  }

  Future<void> _updateStatus(POStatus newStatus) async {
    try {
      await _purchaseOrderService.updatePurchaseOrderStatus(
        widget.purchaseOrderId,
        newStatus,
        updatedByUserId: 'current_user_id', // Replace with actual user ID
      );

      // Status will be updated via the real-time stream
      _showSnackBar('Status updated successfully!', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to update status: $e', Colors.red);
    }
  }

  void _showCancelOrderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Purchase Order'),
        content: Text('Are you sure you want to cancel ${_currentPurchaseOrder?.poNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _updateStatus(POStatus.CANCELLED);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Order', style: TextStyle(color: Colors.white)),
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
    } else if (difference.inDays == -1) {
      return 'Tomorrow';
    } else if (difference.inDays < 7 && difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays > -7 && difference.inDays < 0) {
      return 'In ${-difference.inDays} days';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
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
        duration: const Duration(seconds: 3),
      ),
    );
  }
}