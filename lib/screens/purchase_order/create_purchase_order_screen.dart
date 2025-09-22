import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:assignment/models/purchase_order.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp
import 'package:assignment/services/purchase_order/purchase_order_service.dart';
import 'package:assignment/services/purchase_order/purchase_order_service.dart' as PurchaseService;
import 'package:assignment/dao/user_dao.dart';
import 'package:assignment/services/login/load_user_data.dart';
import 'package:assignment/models/user_model.dart';
import 'package:assignment/models/product_item.dart';

import 'package:assignment/dao/product_brand_dao.dart';
import 'package:assignment/dao/product_category_dao.dart';
import 'package:assignment/dao/product_name_dao.dart';
import 'package:assignment/models/product_brand_model.dart';
import 'package:assignment/models/product_category_model.dart';
import 'package:assignment/models/product_name_model.dart';
import 'package:assignment/models/supplier_model.dart';
import 'package:assignment/models/product_model.dart';
import 'package:assignment/models/form_data_models.dart';

class CreatePurchaseOrderScreen extends StatefulWidget {
  const CreatePurchaseOrderScreen({super.key});

  @override
  State<CreatePurchaseOrderScreen> createState() => _CreatePurchaseOrderScreenState();
}

class _CreatePurchaseOrderScreenState extends State<CreatePurchaseOrderScreen>
    with TickerProviderStateMixin {

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final PurchaseOrderService _purchaseOrderService = PurchaseOrderService();
  final PageController _pageController = PageController();
  UserModel? currentUser;

  late AnimationController _fadeController;
  late AnimationController _slideController;

  int currentStep = 0;
  final int totalSteps = 4;

  // DAO instances
  final ProductBrandDAO _brandDao = ProductBrandDAO();
  final CategoryDao _categoryDao = CategoryDao();
  final ProductNameDao _productNameDao = ProductNameDao();

  List<String> availableBrands = ['All'];
  List<String> availableCategories = ['All'];
  List<String> availableProductNames = ['All'];

  String? selectedBrandName;
  String? selectedCategoryName;
  String? selectedProductName;

  StreamSubscription? _brandsSubscription;
  StreamSubscription? _categoriesSubscription;
  StreamSubscription? _productNamesSubscription;

  String? selectedProductNameId;
  String? selectedCategoryId;
  String? selectedBrandId;

  List<Product> filteredProducts = [];

  // Form controllers
  final TextEditingController _expectedDeliveryController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _deliveryInstructionsController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(text: '0.00');
  final TextEditingController _shippingController = TextEditingController();
  final TextEditingController _taxRateController = TextEditingController(text: '8.0');

  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  String selectedMovementFrequency = 'medium';
  bool requiresClimateControl = false;
  bool isHazardousMaterial = false;
  String selectedStorageType = 'shelf';

  StreamSubscription? _requestsSubscription;
  StreamSubscription? _productsSubscription;

  final GlobalKey<FormState> _lineItemFormKey = GlobalKey<FormState>();
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _unitPriceController = TextEditingController();
  final TextEditingController _lineNotesController = TextEditingController();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _partNumberController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();

  POPriority selectedPriority = POPriority.NORMAL;
  String? selectedSupplierId;
  String? selectedSupplierName;
  DateTime? expectedDeliveryDate;
  List<POLineItem> lineItems = [];

  bool isAddingItem = false;
  bool isNewProduct = false;
  String? selectedProductId;
  double lineTotal = 0.0;
  int? editingItemIndex;

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

  String selectedCategory = 'engine'; // Default category

  static const List<String> productCategories = [
    'engine',
    'brake',
    'electrical',
    'body'
  ];

  static const Map<String, String> categoryDisplayNames = {
    'engine': 'Engine',
    'brake': 'Brake',
    'electrical': 'Electrical',
    'body': 'Body'
  };

  static const Map<String, IconData> categoryIcons = {
    'engine': Icons.precision_manufacturing,
    'brake': Icons.radio_button_checked,
    'electrical': Icons.electrical_services,
    'body': Icons.directions_car,
  };

  List<Product> availableProducts = [];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setExpectedDeliveryDate();
    _setupLineItemCalculation();
    _setupProductsListener();
    _taxRateController.text = '8.0';
    setupRequestsListener();
    _loadUser();
    _loadBrands();
    _loadCategories();
    _loadProductNames();
  }

  Future<String?> _getProductNameId(String productName) async {
    try {
      final productNameModel = await _productNameDao.getProductNameByName(productName);
      return productNameModel?.id;
    } catch (e) {
      print('Error getting product name ID: $e');
      return null;
    }
  }

  Future<String?> _getCategoryId(String categoryName) async {
    try {
      final categoryModel = await _categoryDao.getCategoryByName(categoryName);
      return categoryModel?.id;
    } catch (e) {
      print('Error getting category ID: $e');
      return null;
    }
  }

  Future<String?> _getBrandId(String brandName) async {
    try {
      final brandModel = await _brandDao.getBrandByName(brandName);
      return brandModel?.id;
    } catch (e) {
      print('Error getting brand ID: $e');
      return null;
    }
  }

  Future<void> _loadBrands() async {
    try {
      final brands = await _brandDao.getDistinctBrands();
      if (mounted) {
        setState(() {
          availableBrands = brands;
        });
      }
    } catch (e) {
      print('Error loading brands: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryDao.getCategoryNames();
      if (mounted) {
        setState(() {
          availableCategories = categories;
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _loadProductNames() async {
    try {
      final productNames = await _productNameDao.getDistinctProductName();
      if (mounted) {
        setState(() {
          availableProductNames = productNames;
        });
      }
    } catch (e) {
      print('Error loading product names: $e');
    }
  }

  void setupRequestsListener() {
    _requestsSubscription?.cancel();

    _requestsSubscription = FirebaseFirestore.instance
        .collection('purchaseOrders')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          print('Received ${snapshot.docs.length} purchase orders from Firebase');
        });
      }
    }, onError: (error) {
      print('Error listening to requests: $error');
    });
  }

  void _setupProductsListener() async {
    try {
      setState(() {
        isLoading = true;
      });

      _productsSubscription?.cancel();

      _productsSubscription = FirebaseFirestore.instance
          .collection('products')
          .where('isActive', isEqualTo: true)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            final previousProducts = Map<String, Product>.fromIterable(
              availableProducts,
              key: (product) => product.id,
              value: (product) => product,
            );

            // Create a map to ensure unique products by ID
            final Map<String, Product> uniqueProducts = {};

            for (final doc in snapshot.docs) {
              final data = doc.data();
              final product = Product(
                id: doc.id,
                name: data['name'] ?? '',
                sku: data['sku'] ?? '',
                price: (data['price'] ?? 0.0).toDouble(),
                brand: data['brand'] ?? '',
                category: data['category'] ?? 'engine',
                description: data['description'],
                partNumber: data['partNumber'],
                isActive: data['isActive'] ?? true,
                stockQuantity: data['stockQuantity'] ?? 0,
                unit: data['unit'],
                dimensions: data['dimensions'] != null
                    ? ProductDimensions(
                  length: (data['dimensions']['length'] ?? 0.1).toDouble(),
                  width: (data['dimensions']['width'] ?? 0.1).toDouble(),
                  height: (data['dimensions']['height'] ?? 0.1).toDouble(),
                )
                    : ProductDimensions(length: 0.1, width: 0.1, height: 0.1),
                weight: (data['weight'] ?? 1.0).toDouble(),
                movementFrequency: data['movementFrequency'] ?? 'medium',
                requiresClimateControl: data['requiresClimateControl'] ?? false,
                isHazardousMaterial: data['isHazardousMaterial'] ?? false,
                storageType: data['storageType'] ?? 'shelf',
              );

              // Only add if not already present (prevents duplicates)
              uniqueProducts[product.id] = product;
            }

            // Convert map values back to list
            availableProducts = uniqueProducts.values.toList();

            // Sort products by name for consistent ordering
            availableProducts.sort((a, b) => a.name.compareTo(b.name));

            // Check if currently selected product has changed
            if (selectedProductId != null && !isNewProduct) {
              try {
                final currentProduct = availableProducts.firstWhere(
                      (p) => p.id == selectedProductId,
                );

                final previousProduct = previousProducts[selectedProductId!];

                // If any product data changed, update the form
                if (previousProduct != null) {
                  bool productChanged = previousProduct.price != currentProduct.price ||
                      previousProduct.name != currentProduct.name ||
                      previousProduct.sku != currentProduct.sku ||
                      previousProduct.brand != currentProduct.brand;

                  if (productChanged) {
                    _unitPriceController.text = currentProduct.price.toString();
                    _calculateLineTotal();

                    List<String> changes = [];
                    if (previousProduct.name != currentProduct.name) changes.add('name');
                    if (previousProduct.price != currentProduct.price) changes.add('price');
                    if (previousProduct.sku != currentProduct.sku) changes.add('SKU');
                    if (previousProduct.brand != currentProduct.brand) changes.add('brand');

                    _showSnackBar(
                      'Product updated: ${currentProduct.name} (${changes.join(', ')} changed)',
                      Colors.orange,
                    );
                  }
                }
              } catch (e) {
                print('Selected product not found: $e');
                // Clear selection if product no longer exists
                selectedProductId = null;
                _unitPriceController.clear();
                _calculateLineTotal();
              }
            }

            // Update existing line items with ALL changed product data
            _updateExistingLineItemsPrices(previousProducts);

            // Force refresh of UI components
            _refreshProductDetails();

            isLoading = false;
          });

          print('Products updated: ${availableProducts.length} unique products loaded');
        }
      }, onError: (error) {
        print('Error listening to products: $error');
        if (mounted) {
          setState(() {
            isLoading = false;
          });
          _showSnackBar('Failed to load products: $error', Colors.red);
        }
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        _showSnackBar('Failed to setup products listener: $e', Colors.red);
      }
    }
  }

  void _updateExistingLineItemsPrices(Map<String, Product> previousProducts) {
    bool anyProductChanged = false;
    List<String> changedProducts = [];

    for (int i = 0; i < lineItems.length; i++) {
      final lineItem = lineItems[i];

      // Only update existing products, not new products
      if (!lineItem.isNewProduct && lineItem.productId != null) {
        // Try to find the current product
        Product? currentProduct;
        try {
          currentProduct = availableProducts.firstWhere(
                (p) => p.id == lineItem.productId,
          );
        } catch (e) {
          // Product not found in current list, skip this item
          print('Product ${lineItem.productId} not found in current products list');
          continue;
        }

        final previousProduct = previousProducts[lineItem.productId!];

        // Check if ANY product data has changed, not just price
        bool productChanged = false;
        if (previousProduct != null) {
          productChanged = previousProduct.price != currentProduct.price ||
              previousProduct.name != currentProduct.name ||
              previousProduct.sku != currentProduct.sku ||
              previousProduct.brand != currentProduct.brand;
        }

        // If any product data changed, update the entire line item
        if (productChanged) {
          final updatedLineItem = POLineItem(
            id: lineItem.id,
            productId: lineItem.productId,
            productName: currentProduct.name,
            productSKU: currentProduct.sku.isNotEmpty ? currentProduct.sku : null,
            productDescription: currentProduct.description,
            partNumber: currentProduct.partNumber,
            brand: currentProduct.brand.isNotEmpty ? currentProduct.brand : null,

            quantityOrdered: lineItem.quantityOrdered,
            unitPrice: currentProduct.price,
            lineTotal: lineItem.quantityOrdered * currentProduct.price,
            notes: lineItem.notes,
            isNewProduct: lineItem.isNewProduct,
            status: lineItem.status,
          );

          lineItems[i] = updatedLineItem;
          anyProductChanged = true;
          changedProducts.add(currentProduct.name);

          print('Updated line item: ${previousProduct?.name ?? 'Unknown'} → ${currentProduct.name}');
          if (previousProduct?.price != currentProduct.price) {
            print('Price changed from ${previousProduct?.price} to ${currentProduct.price}');
          }
        }
      }
    }

    if (anyProductChanged) {
      String message = changedProducts.length == 1
          ? 'Product "${changedProducts.first}" was updated in your order.'
          : '${changedProducts.length} products were updated in your order.';

      _showSnackBar(message, Colors.orange);
    }
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _fadeController.forward();
  }

  Future<void> _loadUser() async {
    final user = await loadCurrentUser();
    setState(() {
      currentUser = user;
    });
  }

  void _setupLineItemCalculation() {
    _quantityController.addListener(_calculateLineTotal);
    _unitPriceController.addListener(_calculateLineTotal);
  }

  void _calculateLineTotal() {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final unitPrice = double.tryParse(_unitPriceController.text) ?? 0.0;
    setState(() {
      lineTotal = quantity * unitPrice;
    });
  }

  void _setExpectedDeliveryDate() {
    final DateTime today = DateTime.now();
    expectedDeliveryDate = DateTime(today.year, today.month, today.day).add(const Duration(days: 14)); // Exactly 2 weeks from today
    _expectedDeliveryController.text = _formatDateForInput(expectedDeliveryDate!);
  }

  String _formatDateForInput(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pageController.dispose();
    _expectedDeliveryController.dispose();
    _notesController.dispose();
    _deliveryInstructionsController.dispose();
    _discountController.dispose();
    _shippingController.dispose();
    _taxRateController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _lineNotesController.dispose();
    _productNameController.dispose();
    _skuController.dispose();
    _descriptionController.dispose();
    _partNumberController.dispose();
    _brandController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _requestsSubscription?.cancel();
    _productsSubscription?.cancel();
    _brandsSubscription?.cancel();
    _categoriesSubscription?.cancel();
    _productNamesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create Purchase Order'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: AnimatedBuilder(
              animation: _fadeController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeController,
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildBasicInfoStep(),
                      _buildSupplierStep(),
                      _buildLineItemsStep(),
                      _buildReviewStep(),
                    ],
                  ),
                );
              },
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (int i = 0; i < totalSteps; i++) ...[
                _buildStepIndicator(i),
                if (i < totalSteps - 1) _buildStepConnector(i),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _getStepTitle(currentStep),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            _getStepDescription(currentStep),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step) {
    final isActive = step == currentStep;
    final isCompleted = step < currentStep;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green : (isActive ? Colors.blue : Colors.grey[300]),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : Text(
          '${step + 1}',
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildStepConnector(int step) {
    final isCompleted = step < currentStep;

    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isCompleted ? Colors.green : Colors.grey[300],
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Basic Information';
      case 1:
        return 'Supplier Selection';
      case 2:
        return 'Add Line Items';
      case 3:
        return 'Review & Submit';
      default:
        return '';
    }
  }

  String _getStepDescription(int step) {
    switch (step) {
      case 0:
        return 'Set priority, delivery date, and basic details';
      case 1:
        return 'Choose supplier and delivery information';
      case 2:
        return 'Add products and quantities to your order';
      case 3:
        return 'Review all details before submitting';
      default:
        return '';
    }
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCard(
              title: 'Priority Level',
              child: Column(
                children: [
                  _buildPrioritySelector(),
                  const SizedBox(height: 16),
                  _buildExpectedDeliveryField(),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildCard(
              title: 'Additional Information',
              child: Column(
                children: [
                  _buildNotesField(),
                  const SizedBox(height: 16),
                  _buildDeliveryInstructionsField(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            title: 'Select Supplier',
            child: _buildSupplierSelector(),
          ),
          if (selectedSupplierId != null) ...[
            const SizedBox(height: 20),
            _buildCard(
              title: 'Supplier Details',
              child: _buildSupplierDetails(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLineItemsStep() {
    return Column(
      children: [
        // Header section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey, width: 0.2),
            ),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Line Items',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!isAddingItem)
                ElevatedButton.icon(
                  onPressed: _startAddingItem,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Item'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
            ],
          ),
        ),

        // Main content
        Expanded(
          child: isAddingItem
              ? _buildAddItemFormWithList()
              : (lineItems.isEmpty
              ? _buildEmptyLineItems()
              : _buildLineItemsListView()),
        ),

        if (lineItems.isNotEmpty) _buildLineItemsSummary(),
      ],
    );
  }

  Widget _buildAddItemFormWithList() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.02),
              border: Border(
                bottom: BorderSide(color: Colors.blue.withOpacity(0.2)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _lineItemFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          editingItemIndex != null ? Icons.edit : Icons.add_shopping_cart,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            editingItemIndex != null ? 'Edit Line Item' : 'Add New Line Item',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _cancelAddingItem,
                          icon: const Icon(Icons.close),
                          tooltip: 'Cancel',
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Product type selection
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<bool>(
                            title: const Text('Existing Product'),
                            subtitle: const Text('Select from available products'),
                            value: false,
                            groupValue: isNewProduct,
                            onChanged: (value) {
                              setState(() {
                                isNewProduct = value!;
                                if (!isNewProduct) {
                                  _clearNewProductFields();
                                } else {
                                  selectedProductId = null;
                                  _unitPriceController.clear();
                                }
                              });
                            },
                          ),
                          const Divider(height: 1),
                          RadioListTile<bool>(
                            title: const Text('New Product'),
                            subtitle: const Text('Add a product not in the system'),
                            value: true,
                            groupValue: isNewProduct,
                            onChanged: (value) {
                              setState(() {
                                isNewProduct = value!;
                                if (!isNewProduct) {
                                  _clearNewProductFields();
                                } else {
                                  selectedProductId = null;
                                  _unitPriceController.clear();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Product selection or creation
                    if (!isNewProduct) ...[
                      _buildExistingProductSection(),
                    ] else ...[
                      _buildNewProductSection(),
                    ],

                    const SizedBox(height: 20),

                    // Quantity and pricing in responsive layout
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 600) {
                          return Row(
                            children: [
                              Expanded(child: _buildQuantityField()),
                              const SizedBox(width: 12),
                              Expanded(child: _buildUnitPriceField()),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 150,
                                child: _buildLineTotalDisplay(),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: _buildQuantityField()),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildUnitPriceField()),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildLineTotalDisplay(),
                            ],
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _lineNotesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                        helperText: 'Any special instructions or notes for this item',
                      ),
                      maxLines: 2,
                    ),

                    const SizedBox(height: 20),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _cancelAddingItem,
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _addOrUpdateItem,
                            child: Text(editingItemIndex != null ? 'Update Item' : 'Add Item'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Existing items list (if any)
          if (lineItems.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey, width: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.list, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Existing Items (${lineItems.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            ...lineItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Card(
                  key: ValueKey('inline_item_${item.id}_${availableProducts.length}_${item.quantityOrdered}_${item.lineTotal}'),
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _getCurrentProductName(item),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => _editLineItem(index),
                                  icon: const Icon(Icons.edit, size: 18),
                                  tooltip: 'Edit',
                                  visualDensity: VisualDensity.compact,
                                ),
                                IconButton(
                                  onPressed: () => _deleteLineItem(index),
                                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                  tooltip: 'Delete',
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ],
                        ),

                        if (item.productSKU?.isNotEmpty == true || item.brand?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 16,
                            children: [
                              if (item.productSKU?.isNotEmpty == true)
                                Text(
                                  'SKU: ${item.productSKU}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              if (item.brand?.isNotEmpty == true)
                                Text(
                                  'Brand: ${item.brand}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Always use compact layout for items in this view
                        Column(
                          children: [
                            Row(
                              children: [
                                _buildItemDetailColumn('Quantity', '${item.quantityOrdered}'),
                                _buildItemDetailColumn('Unit Price', 'RM ${item.unitPrice.toStringAsFixed(2)}'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildItemDetailColumn('Total', '\$${item.lineTotal.toStringAsFixed(2)}', isTotal: true),
                              ],
                            ),
                          ],
                        ),

                        if (item.notes?.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Notes: ${item.notes}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  String _getCurrentProductName(POLineItem item) {
    if (item.isNewProduct) {
      return item.productName;
    }

    if (item.productId != null) {
      try {
        final currentProduct = availableProducts.firstWhere((p) => p.id == item.productId);
        return currentProduct.name;
      } catch (e) {
        return item.productName;
      }
    }

    return item.productName;
  }

  Widget _buildExistingProductSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isLoading
            ? Container(
          height: 56,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        )
            : FutureBuilder<List<DropdownMenuItem<String>>>(
          key: ValueKey('products_${availableProducts.length}_${availableProducts.map((p) => p.id).join('_')}'),
          future: _buildAllProductsDropdownItems(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 56,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Container(
                height: 56,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text(
                    'Error loading products',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              );
            }

            return DropdownButtonFormField<String>(
              value: selectedProductId,
              decoration: const InputDecoration(
                labelText: 'Select Product',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.shopping_bag),
                helperText: 'Choose from available products',
              ),
              isExpanded: true,
              isDense: false,
              menuMaxHeight: 400, // Limit dropdown menu height
              items: snapshot.data ?? [],
              onChanged: (value) {
                _handleProductSelection(value);
              },
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Please select a product';
                return null;
              },
            );
          },
        ),

        if (selectedProductId != null) ...[
          const SizedBox(height: 16),
          _buildSelectedProductDetailsSimple(),
        ],
      ],
    );
  }

  Future<List<DropdownMenuItem<String>>> _buildAllProductsDropdownItems() async {
    List<DropdownMenuItem<String>> items = [];

    // Create a set to track processed product IDs and avoid duplicates
    final Set<String> processedIds = {};

    for (Product product in availableProducts) {
      // Skip if we've already processed this product ID
      if (processedIds.contains(product.id)) {
        print('Skipping duplicate product ID: ${product.id}');
        continue;
      }

      processedIds.add(product.id);

      String displayName = '';
      String displayBrand = '';
      String displayCategory = '';

      try {
        // Get product name from ID
        if (product.name.isNotEmpty) {
          final productNameModel = await _productNameDao.getProductNameById(product.name);
          displayName = productNameModel?.productName ?? product.name;
        }

        // Get brand name from ID
        if (product.brand.isNotEmpty) {
          final brandModel = await _brandDao.getBrandById(product.brand);
          displayBrand = brandModel?.brandName ?? product.brand;
        }

        // Get category name from ID
        if (product.category.isNotEmpty) {
          final categoryModel = await _categoryDao.getCategoryById(product.category);
          displayCategory = categoryModel?.name ?? product.category;
        }
      } catch (e) {
        print('Error getting display names for product ${product.id}: $e');
        // Fallback to stored values if lookup fails
        displayName = product.name;
        displayBrand = product.brand;
        displayCategory = product.category;
      }

      items.add(DropdownMenuItem<String>(
        value: product.id,
        child: Container(
          constraints: const BoxConstraints(
            maxHeight: 60,
            minHeight: 40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  displayName.isNotEmpty ? displayName : 'Unnamed Product',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (product.sku.isNotEmpty || displayBrand.isNotEmpty || displayCategory.isNotEmpty) ...[
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    _buildProductDetailsText(product.sku, displayBrand, displayCategory, product.price),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ));
    }

    print('Built ${items.length} dropdown items from ${availableProducts.length} products');
    return items;
  }

  String _buildProductDetailsText(String sku, String brand, String category, double price) {
    List<String> parts = [];

    if (sku.isNotEmpty) {
      String skuText = sku.length > 12 ? '${sku.substring(0, 12)}...' : sku;
      parts.add('SKU: $skuText');
    }

    if (brand.isNotEmpty) {
      String brandText = brand.length > 15 ? '${brand.substring(0, 15)}...' : brand;
      parts.add('Brand: $brandText');
    }

    if (category.isNotEmpty) {
      String categoryText = category.length > 12 ? '${category.substring(0, 12)}...' : category;
      parts.add('Category: $categoryText');
    }

    parts.add('RM ${price.toStringAsFixed(2)}');

    String result = parts.join(' • ');

    if (result.length > 80) {
      result = '${result.substring(0, 77)}...';
    }

    return result;
  }

  void _handleProductSelection(String? productId) {
    setState(() {
      selectedProductId = productId;
      if (productId != null) {
        final product = availableProducts.firstWhere((p) => p.id == productId);
        _unitPriceController.text = product.price.toString();
        _calculateLineTotal();
        print('Product selected: ${product.name} at RM${product.price}');
      } else {
        _unitPriceController.clear();
        _calculateLineTotal();
      }
    });
  }

  Widget _buildSelectedProductDetailsSimple() {
    final product = availableProducts.firstWhere(
          (p) => p.id == selectedProductId,
      orElse: () => throw StateError('Product not found'),
    );

    return FutureBuilder<Map<String, String>>(
      future: _getSimpleProductDisplayNames(product),
      builder: (context, snapshot) {
        final displayNames = snapshot.data ?? {
          'name': product.name,
          'brand': product.brand,
          'category': product.category,
        };

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'Selected Product Details',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                displayNames['name']!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (product.sku.isNotEmpty) Text('SKU: ${product.sku}'),
                  if (displayNames['brand']!.isNotEmpty) Text('Brand: ${displayNames['brand']}'),
                  if (displayNames['category']!.isNotEmpty) Text('Category: ${displayNames['category']}'),
                  Text('Price: RM ${product.price.toStringAsFixed(2)}'),
                  if (product.stockQuantity > 0)
                    Text('Stock: ${product.stockQuantity}'),
                ],
              ),
              if (product.description?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  'Description: ${product.description}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, String>> _getSimpleProductDisplayNames(Product product) async {
    String productName = '';
    String brandName = '';
    String categoryName = '';

    try {
      // Get product name
      if (product.name.isNotEmpty) {
        final productNameModel = await _productNameDao.getProductNameById(product.name);
        productName = productNameModel?.productName ?? product.name;
      }

      // Get brand name
      if (product.brand.isNotEmpty) {
        final brandModel = await _brandDao.getBrandById(product.brand);
        brandName = brandModel?.brandName ?? product.brand;
      }

      // Get category name
      if (product.category.isNotEmpty) {
        final categoryModel = await _categoryDao.getCategoryById(product.category);
        categoryName = categoryModel?.name ?? product.category;
      }
    } catch (e) {
      print('Error getting display names: $e');
      productName = product.name;
      brandName = product.brand;
      categoryName = product.category;
    }

    return {
      'name': productName,
      'brand': brandName,
      'category': categoryName,
    };
  }

  Widget _buildNewProductSection() {
    return Column(
      children: [
        // **PRODUCT NAME DROPDOWN**
        DropdownButtonFormField<String>(
          value: selectedProductName,
          decoration: const InputDecoration(
            labelText: 'Product Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.shopping_bag),
          ),
          items: availableProductNames
              .where((name) => name != 'All')
              .map((name) => DropdownMenuItem<String>(
            value: name,
            child: Text(name),
          ))
              .toList(),
          onChanged: (value) async {
            setState(() {
              selectedProductName = value;
              _productNameController.text = value ?? '';
            });

            if (value != null) {
              selectedProductNameId = await _getProductNameId(value);
            } else {
              selectedProductNameId = null;
            }
          },
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Product name is required';
            return null;
          },
        ),
        const SizedBox(height: 16),

        // **CATEGORY DROPDOWN**
        DropdownButtonFormField<String>(
          value: selectedCategoryName,
          decoration: const InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category),
          ),
          items: availableCategories
              .where((cat) => cat != 'All')
              .map((cat) => DropdownMenuItem<String>(
            value: cat,
            child: Text(cat),
          ))
              .toList(),
          onChanged: (value) async {
            setState(() {
              selectedCategoryName = value;
              selectedCategory = value ?? 'engine';
            });

            if (value != null) {
              selectedCategoryId = await _getCategoryId(value);
            } else {
              selectedCategoryId = null;
            }
          },
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Please select a category';
            return null;
          },
        ),
        const SizedBox(height: 16),

        // **BRAND DROPDOWN**
        DropdownButtonFormField<String>(
          value: selectedBrandName,
          decoration: const InputDecoration(
            labelText: 'Brand',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.branding_watermark),
          ),
          items: availableBrands
              .where((brand) => brand != 'All')
              .map((brand) => DropdownMenuItem<String>(
            value: brand,
            child: Text(brand),
          ))
              .toList(),
          onChanged: (value) async {
            setState(() {
              selectedBrandName = value;
              _brandController.text = value ?? '';
            });

            if (value != null) {
              selectedBrandId = await _getBrandId(value);
            } else {
              selectedBrandId = null;
            }
          },
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Brand is required';
            return null;
          },
        ),
        const SizedBox(height: 16),

        // ** PHYSICAL DIMENSIONS **
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.straighten, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Physical Properties (Required for Warehouse)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Dimensions row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _lengthController,
                      decoration: const InputDecoration(
                        labelText: 'Length (m)',
                        border: OutlineInputBorder(),
                        helperText: 'meters',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')), // Only digits and one dot
                      ],
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Required';
                        if (double.tryParse(value!) == null) return 'Invalid';
                        if (double.parse(value) <= 0) return 'Must be > 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _widthController,
                      decoration: const InputDecoration(
                        labelText: 'Width (m)',
                        border: OutlineInputBorder(),
                        helperText: 'meters',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')), // Only digits and one dot
                      ],
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Required';
                        if (double.tryParse(value!) == null) return 'Invalid';
                        if (double.parse(value) <= 0) return 'Must be > 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _heightController,
                      decoration: const InputDecoration(
                        labelText: 'Height (m)',
                        border: OutlineInputBorder(),
                        helperText: 'meters',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')), // Only digits and one dot
                      ],
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Required';
                        if (double.tryParse(value!) == null) return 'Invalid';
                        if (double.parse(value) <= 0) return 'Must be > 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Weight and Movement Frequency
              LayoutBuilder(
                builder: (context, constraints) {
                  // If screen is narrow, stack vertically
                  if (constraints.maxWidth < 500) {
                    return Column(
                      children: [
                        TextFormField(
                          controller: _weightController,
                          decoration: const InputDecoration(
                            labelText: 'Weight (kg)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.fitness_center),
                            helperText: 'kilograms',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')), // Only digits and one dot
                          ],
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Required';
                            if (double.tryParse(value!) == null) return 'Invalid';
                            if (double.parse(value) <= 0) return 'Must be > 0';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedMovementFrequency,
                          decoration: const InputDecoration(
                            labelText: 'Movement Frequency',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.speed),
                            helperText: 'How often item is picked',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'fast', child: Text('Fast Moving')),
                            DropdownMenuItem(value: 'medium', child: Text('Medium')),
                            DropdownMenuItem(value: 'slow', child: Text('Slow Moving')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedMovementFrequency = value!;
                            });
                          },
                        ),
                      ],
                    );
                  }

                  // If screen is wide enough, display side by side
                  return Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _weightController,
                          decoration: const InputDecoration(
                            labelText: 'Weight (kg)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.fitness_center),
                            helperText: 'kilograms',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Required';
                            if (double.tryParse(value!) == null) return 'Invalid';
                            if (double.parse(value) <= 0) return 'Must be > 0';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedMovementFrequency,
                          decoration: const InputDecoration(
                            labelText: 'Movement Frequency',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.speed),
                            helperText: 'How often item is picked',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'fast', child: Text('Fast Moving')),
                            DropdownMenuItem(value: 'medium', child: Text('Medium')),
                            DropdownMenuItem(value: 'slow', child: Text('Slow Moving')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedMovementFrequency = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Storage Requirements
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warehouse, color: Colors.purple, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Storage Requirements',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: selectedStorageType,
                decoration: const InputDecoration(
                  labelText: 'Preferred Storage Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory_2),
                ),
                items: const [
                  DropdownMenuItem(value: 'floor', child: Text('Floor Storage')),
                  DropdownMenuItem(value: 'shelf', child: Text('Shelf Storage')),
                  DropdownMenuItem(value: 'rack', child: Text('Rack System')),
                  DropdownMenuItem(value: 'bulk', child: Text('Bulk Storage')),
                  DropdownMenuItem(value: 'special', child: Text('Special Storage')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedStorageType = value!;
                  });
                },
              ),
              const SizedBox(height: 12),

              CheckboxListTile(
                title: const Text('Requires Climate Control'),
                subtitle: const Text('Temperature/humidity controlled'),
                value: requiresClimateControl,
                onChanged: (value) {
                  setState(() {
                    requiresClimateControl = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),

              CheckboxListTile(
                title: const Text('Hazardous Material'),
                subtitle: const Text('Requires special handling'),
                value: isHazardousMaterial,
                onChanged: (value) {
                  setState(() {
                    isHazardousMaterial = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // SKU and Part Number (Optional)
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _skuController,
                decoration: const InputDecoration(
                  labelText: 'SKU (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _partNumberController,
                decoration: const InputDecoration(
                  labelText: 'Part Number (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Description
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description (Optional)',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildQuantityField() {
    return TextFormField(
      controller: _quantityController,
      decoration: const InputDecoration(
        labelText: 'Quantity',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.numbers),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value?.isEmpty ?? true) return 'Required';
        if (int.tryParse(value!) == null) return 'Invalid number';
        if (int.parse(value) <= 0) return 'Must be greater than 0';
        return null;
      },
    );
  }

  Widget _buildUnitPriceField() {
    return TextFormField(
      controller: _unitPriceController,
      decoration: InputDecoration(
        labelText: 'Unit Price',
        prefixText: 'RM',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.attach_money),
        // Add visual indication when read-only
        filled: !isNewProduct,
        fillColor: !isNewProduct ? Colors.grey[100] : null,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      readOnly: !isNewProduct, // READ-ONLY when existing product is selected
      validator: (value) {
        if (value?.isEmpty ?? true) return 'Required';
        if (double.tryParse(value!) == null) return 'Invalid price';
        if (double.parse(value) < 0) return 'Must be positive';
        return null;
      },
    );
  }

  Widget _buildLineTotalDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Line Total',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          Text(
            'RM ${lineTotal.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItemsListView() {
    if (lineItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      key: ValueKey('lineitems_${lineItems.length}'),
      padding: const EdgeInsets.all(20),
      itemCount: lineItems.length,
      itemBuilder: (context, index) {
        final item = lineItems[index];
        return Card(
          key: ValueKey('list_item_${item.id}_${availableProducts.length}_${item.quantityOrdered}_${item.lineTotal}'),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[200]!),
          ),
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
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _editLineItem(index),
                          icon: const Icon(Icons.edit, size: 18),
                          tooltip: 'Edit',
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          onPressed: () => _deleteLineItem(index),
                          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),

                if (item.productSKU?.isNotEmpty == true || item.brand?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 16,
                    children: [
                      if (item.productSKU?.isNotEmpty == true)
                        Text(
                          'SKU: ${item.productSKU}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      if (item.brand?.isNotEmpty == true)
                        Text(
                          'Brand: ${item.brand}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 400) {
                      return Row(
                        children: [
                          _buildItemDetailColumn('Quantity', '${item.quantityOrdered}'),
                          _buildItemDetailColumn('Unit Price', 'RM ${item.unitPrice.toStringAsFixed(2)}'),
                          _buildItemDetailColumn('Total', 'RM ${item.lineTotal.toStringAsFixed(2)}', isTotal: true),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          Row(
                            children: [
                              _buildItemDetailColumn('Quantity', '${item.quantityOrdered}'),
                              _buildItemDetailColumn('Unit Price', 'RM ${item.unitPrice.toStringAsFixed(2)}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildItemDetailColumn('Total', 'RM ${item.lineTotal.toStringAsFixed(2)}', isTotal: true),
                            ],
                          ),
                        ],
                      );
                    }
                  },
                ),

                if (item.notes?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Notes: ${item.notes}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemDetailColumn(String label, String value, {bool isTotal = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            title: 'Order Summary',
            child: _buildOrderSummary(),
          ),
          const SizedBox(height: 20),
          _buildCard(
            title: 'Financial Details',
            child: _buildFinancialDetails(),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Priority Level',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: POPriority.values.map((priority) {
            final isSelected = selectedPriority == priority;
            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedPriority = priority;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? _getPriorityColor(priority) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getPriorityColor(priority),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getPriorityIcon(priority),
                      size: 16,
                      color: isSelected ? Colors.white : _getPriorityColor(priority),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      priority.toString().split('.').last,
                      style: TextStyle(
                        color: isSelected ? Colors.white : _getPriorityColor(priority),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
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

  Widget _buildExpectedDeliveryField() {
    return TextFormField(
      controller: _expectedDeliveryController,
      decoration: const InputDecoration(
        labelText: 'Expected Delivery Date',
        hintText: 'Select delivery date (minimum 2 weeks)',
        prefixIcon: Icon(Icons.calendar_today),
        border: OutlineInputBorder(),
        helperText: 'Delivery must be scheduled at least 2 weeks from today',
      ),
      readOnly: true,
      onTap: _selectDeliveryDate,
      validator: (value) {
        if (value?.isEmpty ?? true) {
          return 'Please select expected delivery date';
        }

        // Strong validation to ensure date is at least 2 weeks from today
        if (expectedDeliveryDate != null) {
          final DateTime today = DateTime.now();
          final DateTime minimumDate = DateTime(today.year, today.month, today.day).add(const Duration(days: 14));
          final DateTime normalizedExpected = DateTime(
              expectedDeliveryDate!.year,
              expectedDeliveryDate!.month,
              expectedDeliveryDate!.day
          );

          if (normalizedExpected.isBefore(minimumDate)) {
            return 'Delivery date must be at least 2 weeks (14 days) from today';
          }
        }

        return null;
      },
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      decoration: const InputDecoration(
        labelText: 'Notes (Optional)',
        hintText: 'Add any special instructions or notes',
        alignLabelWithHint: true,
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
    );
  }

  Widget _buildDeliveryInstructionsField() {
    return TextFormField(
      controller: _deliveryInstructionsController,
      decoration: const InputDecoration(
        labelText: 'Delivery Instructions (Optional)',
        hintText: 'Special delivery instructions',
        prefixIcon: Icon(Icons.local_shipping),
        border: OutlineInputBorder(),
      ),
      maxLines: 2,
    );
  }

  Widget _buildSupplierSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: selectedSupplierId,
          decoration: const InputDecoration(
            labelText: 'Choose Supplier',
            prefixIcon: Icon(Icons.business),
            border: OutlineInputBorder(),
          ),
          items: availableSuppliers.map((supplier) {
            return DropdownMenuItem(
              value: supplier.id,
              child: Text(supplier.name),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedSupplierId = value;
              selectedSupplierName = availableSuppliers
                  .firstWhere((s) => s.id == value)
                  .name;
            });
          },
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Please select a supplier';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSupplierDetails() {
    final supplier = availableSuppliers.firstWhere((s) => s.id == selectedSupplierId);

    return Column(
      children: [
        _buildDetailRow('Company:', supplier.name),
        _buildDetailRow('Email:', supplier.email),
        _buildDetailRow('Phone:', supplier.phone),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
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

  Widget _buildEmptyLineItems() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No items added yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Add Item" to start building your order',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _startAddingItem,
            icon: const Icon(Icons.add),
            label: const Text('Add Your First Item'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItemsSummary() {
    final subtotal = _calculateCurrentSubtotal();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      key: ValueKey('summary_${lineItems.length}_${subtotal.toStringAsFixed(2)}_${DateTime.now().millisecondsSinceEpoch}'),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey, width: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal (${lineItems.length} items):',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  'RM ${subtotal.toStringAsFixed(2)}',
                  key: ValueKey('subtotal_text_$subtotal'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _calculateCurrentSubtotal() {
    return lineItems.fold(0.0, (sum, item) {
      if (!item.isNewProduct && item.productId != null) {
        try {
          final currentProduct = availableProducts.firstWhere(
                (p) => p.id == item.productId,
          );
          return sum + (item.quantityOrdered * currentProduct.price);
        } catch (e) {
          print('Product ${item.productId} not found for subtotal calculation, using stored price');
          return sum + item.lineTotal;
        }
      } else {
        // For new products, use stored price
        return sum + item.lineTotal;
      }
    });
  }

  void _refreshProductDetails() {
    if (mounted) {
      setState(() {
        // This will trigger a rebuild of all product cards and details
      });
    }
  }

  Widget _buildOrderSummary() {
    final supplier = selectedSupplierId != null
        ? availableSuppliers.firstWhere((s) => s.id == selectedSupplierId)
        : null;

    return Column(
      children: [
        _buildSummaryRow('Priority:', selectedPriority.toString().split('.').last),
        _buildSummaryRow('Supplier:', supplier?.name ?? 'Not selected'),
        _buildSummaryRow('Expected Delivery:',
            expectedDeliveryDate != null
                ? _formatDisplayDate(expectedDeliveryDate!)
                : 'Not set'),
        _buildSummaryRow('Total Items:', '${lineItems.length}'),
        if (_notesController.text.isNotEmpty)
          _buildSummaryRow('Notes:', _notesController.text),
        if (_deliveryInstructionsController.text.isNotEmpty)
          _buildSummaryRow('Delivery Instructions:', _deliveryInstructionsController.text),
      ],
    );
  }

  Widget _buildFinancialDetails() {
    final subtotal = _calculateCurrentSubtotal();
    final shipping = double.tryParse(_shippingController.text) ?? 0.0;
    final taxRate = 0.08;
    final taxAmount = subtotal * taxRate;
    final total = subtotal + shipping + taxAmount;

    return Column(
      children: [
        TextFormField(
          controller: _shippingController,
          decoration: const InputDecoration(
            labelText: 'Shipping Cost',
            prefixText: 'RM ',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.local_shipping),
            helperText: 'Required: Enter shipping charges (must be greater than 0)',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
          ],
          onChanged: (value) => setState(() {}),
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Shipping cost is required';
            }
            if (double.tryParse(value!) == null) {
              return 'Enter a valid amount';
            }
            final shippingAmount = double.parse(value);
            if (shippingAmount <= 0) {
              return 'Shipping cost must be greater than 0';
            }
            if (shippingAmount > 100) {
              return 'Shipping cost cannot exceed RM 100.00';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Tax rate field (read-only at 8%)
        TextFormField(
          controller: _taxRateController,
          decoration: const InputDecoration(
            labelText: 'Tax Rate',
            suffixText: '%',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.receipt_long),
            filled: true,
            fillColor: Color(0xFFF5F5F5),
          ),
          keyboardType: TextInputType.number,
          readOnly: true, // Make it read-only
        ),

        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),

        // Financial summary with animation
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: Column(
            children: [
              _buildFinancialRow('Subtotal:', 'RM ${subtotal.toStringAsFixed(2)}'),
              _buildFinancialRow('Shipping:', 'RM ${shipping.toStringAsFixed(2)}'),
              _buildFinancialRow('Tax (8.0%):', 'RM ${taxAmount.toStringAsFixed(2)}'),
              const Divider(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _buildFinancialRow(
                  'Total:',
                  'RM ${total.toStringAsFixed(2)}',
                  isTotal: true,
                  key: ValueKey('total_$total'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
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

  Widget _buildFinancialRow(String label, String value, {bool isTotal = false, Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? Colors.black : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isTotal ? 18 : 14,
              color: isTotal ? Colors.green : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDisplayDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                child: const Text('Previous'),
              ),
            ),
          if (currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: currentStep == 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: (_canProceedToNextStep() && !isLoading) ? _nextStep : null,
              child: isLoading
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Text(
                currentStep == totalSteps - 1 ? 'Create Order' : 'Next',
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceedToNextStep() {
    switch (currentStep) {
      case 0:
        return expectedDeliveryDate != null;
      case 1:
        return selectedSupplierId != null;
      case 2:
        return lineItems.isNotEmpty;
      case 3:
      // Check if shipping cost is valid before allowing order creation
        final shippingText = _shippingController.text.trim();
        if (shippingText.isEmpty) return false;
        final shipping = double.tryParse(shippingText);
        if (shipping == null || shipping <= 0) return false;
        return true;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (currentStep < totalSteps - 1) {
      setState(() {
        currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submitOrder();
    }
  }

  void _previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _selectDeliveryDate() async {
    final DateTime today = DateTime.now();
    final DateTime minimumDate = DateTime(today.year, today.month, today.day).add(const Duration(days: 14)); // Minimum 2 weeks, normalized to start of day

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: expectedDeliveryDate != null && expectedDeliveryDate!.isAfter(minimumDate)
          ? expectedDeliveryDate!
          : minimumDate,
      firstDate: minimumDate, // This prevents selection of earlier dates
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select Expected Delivery Date',
      errorFormatText: 'Enter valid date',
      errorInvalidText: 'Date must be at least 2 weeks from today',
      fieldHintText: 'MM/DD/YYYY',
      fieldLabelText: 'Expected Delivery Date',
      selectableDayPredicate: (DateTime date) {
        // Additional check: only allow dates that are 2+ weeks from today
        final DateTime normalizedToday = DateTime(today.year, today.month, today.day);
        final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
        return normalizedDate.isAfter(normalizedToday.add(const Duration(days: 13))); // After 13 days means 14+ days
      },
    );

    if (picked != null) {
      // Double-check the selected date meets our requirements
      final DateTime normalizedToday = DateTime(today.year, today.month, today.day);
      final DateTime normalizedPicked = DateTime(picked.year, picked.month, picked.day);

      if (normalizedPicked.isAfter(normalizedToday.add(const Duration(days: 13)))) {
        setState(() {
          expectedDeliveryDate = picked;
          _expectedDeliveryController.text = _formatDateForInput(picked);
        });
      } else {
        // Show error if somehow an invalid date was selected
        _showSnackBar('Selected date must be at least 2 weeks from today', Colors.red);
      }
    }
  }

  void _startAddingItem() {
    setState(() {
      isAddingItem = true;
      editingItemIndex = null;
      _clearItemForm();
    });
  }

  void _editLineItem(int index) async {
    final item = lineItems[index];
    setState(() {
      isAddingItem = true;
      editingItemIndex = index;

      // Populate form with item data
      if (item.isNewProduct) {
        isNewProduct = true;
        _productNameController.text = item.productName;
        _skuController.text = item.productSKU ?? '';
        _descriptionController.text = item.productDescription ?? '';
        _partNumberController.text = item.partNumber ?? '';
        _brandController.text = item.brand ?? '';
        selectedProductId = null;
        selectedProductName = null;
        filteredProducts = [];
      } else {
        isNewProduct = false;
        selectedProductId = item.productId;

        // For existing products, we need to determine the product name and set up filters
        if (item.productId != null) {
          // Find the product in availableProducts to get current data
          final currentProduct = availableProducts.firstWhere(
                (p) => p.id == item.productId,
            orElse: () => throw StateError('Product not found'),
          );

          // Set the product name based on current product data
          selectedProductName = item.productName;
          selectedProductNameId = currentProduct.name; // This should be the ID from your DAO

          // Set up the filtered products list with this single product
          filteredProducts = [currentProduct];

          // Note: You might want to also set category and brand filters here
          // based on the current product's data if you want them pre-selected
          selectedCategoryName = null; // Or get category name from ID
          selectedBrandName = null;    // Or get brand name from ID
        }

        _clearNewProductFields();
      }

      _quantityController.text = item.quantityOrdered.toString();
      _unitPriceController.text = item.unitPrice.toString();
      _lineNotesController.text = item.notes ?? '';
      lineTotal = item.lineTotal;
    });
  }

  void _deleteLineItem(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to remove "${lineItems[index].productName}" from this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                lineItems.removeAt(index);
              });
              Navigator.of(context).pop();

              // Force rebuild after dialog closes
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {});
                }
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _cancelAddingItem() {
    setState(() {
      isAddingItem = false;
      editingItemIndex = null;
      _clearItemForm();
    });
  }

  void _addOrUpdateItem() async {
    if (_lineItemFormKey.currentState!.validate()) {
      setState(() {
        isLoading = true;
      });

      try {
        final quantity = int.parse(_quantityController.text);
        final unitPrice = double.parse(_unitPriceController.text);

        POLineItem item;

        if (isNewProduct) {
          // For new products, check if a product with the same name already exists
          final productName = _productNameController.text.trim();
          final existingItemIndex = lineItems.indexWhere((item) =>
          item.isNewProduct &&
              item.productName.toLowerCase() == productName.toLowerCase());

          if (existingItemIndex != -1 && editingItemIndex != existingItemIndex) {
            // Product with same name already exists, automatically combine quantities
            final existingItem = lineItems[existingItemIndex];
            final newQuantity = existingItem.quantityOrdered + quantity;
            final newLineTotal = newQuantity * unitPrice;

            final updatedItem = POLineItem(
              id: existingItem.id,
              productId: existingItem.productId,
              productName: existingItem.productName,
              productSKU: existingItem.productSKU,
              productDescription: existingItem.productDescription,
              partNumber: existingItem.partNumber,
              brand: existingItem.brand,
              quantityOrdered: newQuantity,
              unitPrice: unitPrice,
              lineTotal: newLineTotal,
              notes: existingItem.notes,
              isNewProduct: true,
              status: 'PENDING',
            );

            setState(() {
              lineItems[existingItemIndex] = updatedItem;
              isAddingItem = false;
              editingItemIndex = null;
            });

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {});
              }
            });

            _clearItemForm();
            _showSnackBar('Quantity combined! New total: $newQuantity', Colors.green);
            return;
          }

          // Create new product with warehouse data
          final newProduct = Product(
            id: '',
            name: selectedProductNameId ?? '',
            sku: _skuController.text.trim().isNotEmpty ? _skuController.text.trim() : '',
            brand: selectedBrandId ?? '',
            price: unitPrice,
            category: selectedCategoryId ?? '',
            description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
            partNumber: _partNumberController.text.trim().isNotEmpty ? _partNumberController.text.trim() : null,
            productUri: null,
            isActive: true,
            stockQuantity: 0,
            unit: 'pieces',
            dimensions: ProductDimensions(
              length: double.parse(_lengthController.text),
              width: double.parse(_widthController.text),
              height: double.parse(_heightController.text),
            ),
            weight: double.parse(_weightController.text),
            movementFrequency: selectedMovementFrequency,
            requiresClimateControl: requiresClimateControl,
            isHazardousMaterial: isHazardousMaterial,
            storageType: selectedStorageType,
          );

          final generatedProductId = await _purchaseOrderService.createProduct(newProduct);

          final localProduct = Product(
            id: generatedProductId,
            name: newProduct.name,
            sku: newProduct.sku ?? '',
            price: newProduct.price,
            brand: newProduct.brand ?? '',
            category: newProduct.category ?? 'engine',
            description: newProduct.description,
            partNumber: newProduct.partNumber,
            isActive: newProduct.isActive,
            stockQuantity: newProduct.stockQuantity,
            unit: newProduct.unit,
            dimensions: newProduct.dimensions,
            weight: newProduct.weight!,
            movementFrequency: newProduct.movementFrequency!,
            requiresClimateControl: newProduct.requiresClimateControl!,
            isHazardousMaterial: newProduct.isHazardousMaterial!,
            storageType: newProduct.storageType!,
          );

          setState(() {
            availableProducts.add(localProduct);
          });

          item = POLineItem(
            id: editingItemIndex != null ? lineItems[editingItemIndex!].id : 'line_${DateTime.now().millisecondsSinceEpoch}',
            productId: generatedProductId,
            productName: selectedProductName ?? '',
            productSKU: newProduct.sku,
            productDescription: newProduct.description,
            partNumber: newProduct.partNumber,
            brand: selectedBrandName ?? '',
            quantityOrdered: quantity,
            unitPrice: unitPrice,
            lineTotal: lineTotal,
            notes: _lineNotesController.text.trim().isNotEmpty ? _lineNotesController.text.trim() : null,
            isNewProduct: true,
            status: 'PENDING',
          );

          _showSnackBar('New product created with warehouse data and added to order!', Colors.green);
        } else {
          // Use existing product - FIXED SECTION
          if (selectedProductId == null) {
            throw Exception('Please select a product');
          }

          // Check if this existing product is already in the line items
          final existingItemIndex = lineItems.indexWhere((item) =>
          !item.isNewProduct &&
              item.productId == selectedProductId);

          if (existingItemIndex != -1 && editingItemIndex != existingItemIndex) {
            // Product already exists, automatically combine quantities
            final existingItem = lineItems[existingItemIndex];
            final newQuantity = existingItem.quantityOrdered + quantity;
            final newLineTotal = newQuantity * unitPrice;

            final updatedItem = POLineItem(
              id: existingItem.id,
              productId: existingItem.productId,
              productName: existingItem.productName,
              productSKU: existingItem.productSKU,
              productDescription: existingItem.productDescription,
              partNumber: existingItem.partNumber,
              brand: existingItem.brand,
              quantityOrdered: newQuantity,
              unitPrice: unitPrice,
              lineTotal: newLineTotal,
              notes: existingItem.notes,
              isNewProduct: false,
              status: 'PENDING',
            );

            setState(() {
              lineItems[existingItemIndex] = updatedItem;
              isAddingItem = false;
              editingItemIndex = null;
            });

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {});
              }
            });

            _clearItemForm();
            _showSnackBar('Quantity combined! New total: $newQuantity', Colors.green);
            return;
          }

          final product = availableProducts.firstWhere(
                (p) => p.id == selectedProductId,
            orElse: () => throw Exception('Selected product not found'),
          );

          // ✅ RESOLVE IDs TO DISPLAY NAMES FOR EXISTING PRODUCTS
          String displayProductName = '';
          String displayBrandName = '';

          try {
            // Get actual product name from ID
            if (product.name.isNotEmpty) {
              final productNameModel = await _productNameDao.getProductNameById(product.name);
              displayProductName = productNameModel?.productName ?? product.name;
            } else {
              displayProductName = 'Unknown Product';
            }

            // Get actual brand name from ID
            if (product.brand.isNotEmpty) {
              final brandModel = await _brandDao.getBrandById(product.brand);
              displayBrandName = brandModel?.brandName ?? product.brand;
            }
          } catch (e) {
            print('Error resolving display names: $e');
            // Fallback to IDs if resolution fails
            displayProductName = product.name.isNotEmpty ? product.name : 'Unknown Product';
            displayBrandName = product.brand;
          }

          item = POLineItem(
            id: editingItemIndex != null ? lineItems[editingItemIndex!].id : 'line_${DateTime.now().millisecondsSinceEpoch}',
            productId: selectedProductId!,
            productName: displayProductName,  // ✅ Use resolved display name
            productSKU: product.sku.isNotEmpty ? product.sku : null,
            productDescription: product.description,
            partNumber: product.partNumber,
            brand: displayBrandName.isNotEmpty ? displayBrandName : null,  // ✅ Use resolved brand name
            quantityOrdered: quantity,
            unitPrice: unitPrice,
            lineTotal: lineTotal,
            notes: _lineNotesController.text.trim().isNotEmpty ? _lineNotesController.text.trim() : null,
            isNewProduct: false,
            status: 'PENDING',
          );

          _showSnackBar('Item added successfully!', Colors.green);
        }

        // Add or update the line item
        setState(() {
          if (editingItemIndex != null) {
            lineItems[editingItemIndex!] = item;
          } else {
            lineItems.add(item);
          }
          isAddingItem = false;
          editingItemIndex = null;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });

        _clearItemForm();

      } catch (e) {
        String errorMessage = 'Failed to add item';

        if (e.toString().contains('Exception:')) {
          errorMessage = e.toString().replaceAll('Exception: ', '');
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection and try again.';
        } else if (e.toString().contains('permission')) {
          errorMessage = 'Permission denied. Please check your access rights.';
        } else if (e.toString().contains('FormatException')) {
          errorMessage = 'Invalid input format. Please check your entries.';
        } else if (e.toString().contains('Firebase')) {
          errorMessage = 'Database error. Please try again later.';
        }

        _showSnackBar(errorMessage, Colors.red);
        print('Error adding item: $e');

      } finally {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    }
  }

  void _clearItemForm() {
    _quantityController.text = '1';
    _unitPriceController.clear();
    _lineNotesController.clear();
    selectedProductId = null;
    selectedProductName = null;
    selectedCategoryName = null;
    selectedBrandName = null;
    filteredProducts = [];
    isNewProduct = false;
    lineTotal = 0.0;
    selectedCategory = 'engine';
    _clearNewProductFields();
  }

  void _clearNewProductFields() {
    _productNameController.clear();
    _skuController.clear();
    _descriptionController.clear();
    _partNumberController.clear();
    _brandController.clear();
    _lengthController.clear();
    _widthController.clear();
    _heightController.clear();
    _weightController.clear();
    selectedMovementFrequency = 'medium';
    requiresClimateControl = false;
    isHazardousMaterial = false;
    selectedStorageType = 'shelf';

    selectedProductNameId = null;
    selectedCategoryId = null;
    selectedBrandId = null;
  }

  Supplier? _getSelectedSupplier() {
    if (selectedSupplierId == null) return null;
    try {
      return availableSuppliers.firstWhere((s) => s.id == selectedSupplierId);
    } catch (e) {
      return null;
    }
  }

  void _submitOrder() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Validate all required data
      if (selectedSupplierId == null || selectedSupplierName == null) {
        throw Exception('Please select a supplier');
      }

      if (expectedDeliveryDate == null) {
        throw Exception('Please select expected delivery date');
      }

      if (lineItems.isEmpty) {
        throw Exception('Please add at least one item');
      }

      // Parse financial values
      final discount = double.tryParse(_discountController.text) ?? 0.0;
      final shipping = double.tryParse(_shippingController.text) ?? 0.0;
      final taxRate = double.tryParse(_taxRateController.text) ?? 0.0;

      // Get supplier details
      final supplier = _getSelectedSupplier();

      // Create purchase order using the service helper method
      final purchaseOrder = PurchaseOrderService.createFromFormData(
        priority: selectedPriority,
        supplierId: selectedSupplierId!,
        supplierName: selectedSupplierName!,
        expectedDeliveryDate: expectedDeliveryDate!,
        lineItems: lineItems,
        status : POStatus.APPROVED,
        createdByUserId: currentUser!.employeeId!,
        createdByUserName: currentUser!.firstName + ' ' + currentUser!.lastName,
        creatorRole: POCreatorRole.WORKSHOP_MANAGER, // Get from user profile
        supplierEmail: supplier?.email,
        supplierPhone: supplier?.phone,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        deliveryInstructions: _deliveryInstructionsController.text.isNotEmpty
            ? _deliveryInstructionsController.text : null,
        discountAmount: discount,
        shippingCost: shipping,
        taxRate: taxRate,
        deliveryAddress: 'Default Workshop Address',
        jobId: null,
        jobNumber: null,
        customerName: null,
      );

      // Save to Firebase
      final createdPOId = await _purchaseOrderService.createPurchaseOrder(purchaseOrder);

      await _createProductItemsForPurchaseOrder(createdPOId, lineItems);

      // Success - show message and navigate back
      _showSnackBar('Purchase order created successfully! PO ID: $createdPOId', Colors.green);

      // Wait a moment to show success message, then navigate back
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pop(createdPOId); // Return the created PO ID
      }

    } catch (e) {
      // Error handling
      String errorMessage = 'Failed to create purchase order';

      if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      }

      _showSnackBar(errorMessage, Colors.red);

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

      int totalItemsCreated = 0;

      // Process each line item
      for (final lineItem in lineItems) {
        final createdItemIds = await productItemService.createProductItems(
          lineItem.productId,
          purchaseOrderId,
          lineItem.quantityOrdered,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              backgroundColor == Colors.green ? Icons.check_circle : Icons.info,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
