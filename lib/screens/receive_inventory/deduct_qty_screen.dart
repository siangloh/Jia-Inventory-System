// lib/screens/warehouse/deduct_qty_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:assignment/models/warehouse_location.dart';
import 'package:assignment/services/warehouse/warehouse_allocation_service.dart';
import 'dart:async';
import 'package:assignment/dao/warehouse_deduction_dao.dart';


class DeductQtyScreen extends StatefulWidget {
  const DeductQtyScreen({super.key});

  @override
  State<DeductQtyScreen> createState() => _DeductQtyScreenState();
}

class _DeductQtyScreenState extends State<DeductQtyScreen> {
  final WarehouseDeductionDao _dao = WarehouseDeductionDao();
  Map<String, Map<String, dynamic>> _productsCache = {};
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  bool _isSuccess = false;
  // State variables
  List<AvailableProduct> availableProducts = [];
  bool isLoading = true;
  String? errorMessage;
  bool isProcessing = false;

  // Form values
  String? selectedProductId;
  String? selectedProductName;
  AvailableProduct? selectedProduct;
  int deductQuantity = 0;
  String deductReason = '';

  // Real-time subscription
  StreamSubscription<QuerySnapshot>? _warehouseSubscription;
  StreamSubscription<QuerySnapshot>? _productsSubscription;

  @override
  void initState() {
    super.initState();
    _setupRealtimeUpdates();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    _warehouseSubscription?.cancel();
    _productsSubscription?.cancel();
    super.dispose();
  }



  void _setupRealtimeUpdates() {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    // Listen to products collection for product details
    _setupProductsListener();

    // Listen to warehouse locations for available quantities
    _setupWarehouseListener();
  }

  void _setupProductsListener() {
    _productsSubscription = _dao.getProductsStream().listen(
          (snapshot) {
        print('Products collection changed: ${snapshot.docs.length} products');
        _productsCache = _dao.updateProductsCache(snapshot);
        _refreshAvailableProducts();
      },
      onError: (error) {
        print('Products listener error: $error');
        setState(() {
          errorMessage = 'Products update failed: $error';
        });
      },
    );
  }

  void _setupWarehouseListener() {
    _warehouseSubscription = _dao.getOccupiedWarehouseLocationsStream().listen(
          (snapshot) {
        print('Warehouse collection changed: ${snapshot.docs.length} locations');
        _processWarehouseSnapshot(snapshot);
      },
      onError: (error) {
        print('Warehouse listener error: $error');
        setState(() {
          isLoading = false;
          errorMessage = 'Real-time update failed: $error';
        });
      },
    );
  }

  void _refreshAvailableProducts() {
    // Re-process the latest warehouse data when products change
    _setupWarehouseListener();
  }

  void _processWarehouseSnapshot(QuerySnapshot snapshot) {
    try {
      final products = _dao.processWarehouseSnapshot(snapshot, _productsCache);

      setState(() {
        availableProducts = products;
        isLoading = false;
        errorMessage = null;

        // Reset selection if current product is no longer available
        if (selectedProductId != null) {
          final stillAvailable = products.any((p) => p.productId == selectedProductId);
          if (!stillAvailable) {
            selectedProductId = null;
            selectedProductName = null;
            selectedProduct = null;
            _quantityController.clear();
          }
        }
      });

    } catch (e) {
      print('Error processing warehouse snapshot: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to process warehouse data: $e';
      });
    }
  }

  Future<void> _processDeduction() async {
    // Validate using DAO
    final validationError = _dao.validateDeductionRequest(
      product: selectedProduct,
      quantity: deductQuantity,
      reason: deductReason,
    );

    if (validationError != null) {
      _showSnackBar(validationError, Colors.red);
      return;
    }

    setState(() {
      isProcessing = true;
      _isSuccess = false;
    });

    try {
      // Process deduction using DAO
      final result = await _dao.processQuantityDeduction(
        product: selectedProduct!,
        quantityToDeduct: deductQuantity,
        reason: deductReason,
      );

      if (result.success) {
        // Show success state
        setState(() {
          _isSuccess = true;
        });

        // Wait for user to see success message
        await Future.delayed(const Duration(milliseconds: 2000));

        // Reset the form
        setState(() {
          isProcessing = false;
          _isSuccess = false;
          selectedProductId = null;
          selectedProductName = null;
          selectedProduct = null;
          deductQuantity = 0;
          deductReason = '';
        });

        // Clear the form controllers
        _quantityController.clear();
        _reasonController.clear();

        _showSnackBar(result.message, Colors.green);
      } else {
        throw Exception(result.message);
      }

    } catch (e) {
      print('Error processing deduction: $e');
      setState(() {
        isProcessing = false;
        _isSuccess = false;
      });
      _showSnackBar('Failed to process deduction: $e', Colors.red);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'No Products Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'All products have been deducted or no stock available for deduction.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            // ElevatedButton.icon(
            //   onPressed: () => Navigator.pop(context),
            //   icon: const Icon(Icons.arrow_back),
            //   label: const Text('Go Back'),
            // ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Deduct Quantity'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: isLoading
          ? _buildLoadingScreen()
          : errorMessage != null
          ? _buildErrorScreen()
          : _buildForm(),
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
            'Loading available products...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error Loading Products',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _setupRealtimeUpdates,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    if (availableProducts.isEmpty) {
      return _buildEmptyState();
    }

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCard(
              title: 'Select Product',
              child: _buildProductSelector(),
            ),
            if (selectedProduct != null) ...[
              const SizedBox(height: 16),
              _buildCard(
                title: 'Product Details',
                child: _buildProductDetails(),
              ),
              const SizedBox(height: 16),
              _buildCard(
                title: 'Deduction Details',
                child: _buildDeductionForm(),
              ),
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ],
        ),
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
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildProductSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: selectedProductId,
          decoration: const InputDecoration(
            labelText: 'Choose Product',
            prefixIcon: Icon(Icons.inventory),
            border: OutlineInputBorder(),
          ),
          isExpanded: true, // This is crucial to prevent overflow
          items: availableProducts.map((product) {
            return DropdownMenuItem(
              value: product.productId,
              child: Container(
                constraints: const BoxConstraints(
                  maxHeight: 50, // Limit the height of each item
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // Important: minimize the column size
                  children: [
                    Flexible(
                      child: Text(
                        product.productName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis, // Handle long names
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Flexible(
                      child: Text(
                        '${product.category} • Available: ${product.totalQuantity}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis, // Handle long text
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedProductId = value;
              selectedProduct = availableProducts.firstWhere((p) => p.productId == value);
              selectedProductName = selectedProduct!.productName;
              // Reset quantity when product changes
              _quantityController.clear();
              deductQuantity = 0;
            });
          },
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Please select a product';
            }
            return null;
          },
          // Add these properties to handle long content better
          menuMaxHeight: 300, // Limit dropdown menu height
          isDense: false, // Give more space for content
        ),
        if (availableProducts.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No products available for deduction',
                    style: TextStyle(color: Colors.orange[700]),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProductDetails() {
    final product = selectedProduct!;

    // Get product data to access price
    final productData = _productsCache[product.productId];

    // Debug: Print the entire product data to see the structure
    print('Product Data for ${product.productId}: $productData');
    if (productData != null) {
      print('Available keys: ${productData.keys.toList()}');
      print('Price field: ${productData['price']}');
      print('Price field type: ${productData['price'].runtimeType}');
    }

    final price = productData?['price'] ?? productData?['unitPrice'] ?? 0.0;

    return Column(
      children: [
        _buildDetailRow('Product Name', product.productName),
        _buildDetailRow('Category', product.category),
        _buildDetailRow('Part Number', product.partNumber ?? 'N/A'),
        if (product.brand != null)
          _buildDetailRow('Brand', product.brand!),
        _buildDetailRow('Price per Unit', 'RM ${price.toStringAsFixed(2)}'),
        _buildDetailRow('Total Available', '${product.totalQuantity} units'),
        _buildDetailRow('Storage Locations', '${product.locations.length} locations'),
        _buildDetailRow('Storage Locations', '${product.locations.length} locations'),

        const SizedBox(height: 12),
        const Text(
          'Location Breakdown:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...product.locations.map((locationWithId) => Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  locationWithId.location.locationId,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${locationWithId.location.quantityStored} units',
                style: TextStyle(color: Colors.blue[700]),
              ),
            ],
          ),
        )).toList(),
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

  Widget _buildDeductionForm() {
    return Column(
      children: [
        TextFormField(
          controller: _quantityController,
          decoration: InputDecoration(
            labelText: 'Quantity to Deduct',
            prefixIcon: const Icon(Icons.remove_circle_outline),
            border: const OutlineInputBorder(),
            helperText: 'Maximum: ${selectedProduct?.totalQuantity ?? 0} units',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) {
            setState(() {
              deductQuantity = int.tryParse(value) ?? 0;
            });
          },
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Please enter quantity to deduct';
            }
            final qty = int.tryParse(value!);
            if (qty == null || qty <= 0) {
              return 'Please enter a valid quantity';
            }
            if (selectedProduct != null && qty > selectedProduct!.totalQuantity) {
              return 'Cannot exceed available quantity (${selectedProduct!.totalQuantity})';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for Deduction',
            prefixIcon: Icon(Icons.note),
            border: OutlineInputBorder(),
            hintText: 'e.g., Used for maintenance, Damaged, Quality control...',
          ),
          maxLines: 3,
          onChanged: (value) {
            setState(() {
              deductReason = value;
            });
          },
          validator: (value) {
            if (value?.trim().isEmpty ?? true) {
              return 'Please provide a reason for deduction';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isProcessing || selectedProduct == null || deductQuantity <= 0
            ? null
            : _processDeduction,
        style: ElevatedButton.styleFrom(
          backgroundColor: isProcessing && _isSuccess ? Colors.green : Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: isProcessing
            ? _isSuccess
            ? const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 20),
            SizedBox(width: 8),
            Text('Success! Redirecting...'),
          ],
        )
            : const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Processing Deduction...'),
          ],
        )
            : Text('Deduct ${deductQuantity > 0 ? deductQuantity : ""} Units'),
      ),
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
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
      ),
    );
  }
}