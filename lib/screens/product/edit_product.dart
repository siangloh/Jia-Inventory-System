import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:assignment/models/products_model.dart';
import 'package:assignment/models/product_name_model.dart';
import 'package:assignment/models/product_brand_model.dart';
import 'package:assignment/models/product_category_model.dart';
import 'package:assignment/dao/product_name_dao.dart';
import 'package:assignment/dao/product_brand_dao.dart';
import 'package:assignment/dao/product_category_dao.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

// Import your new ProductImageService
import 'package:assignment/services/product_image_service.dart';

class ProductEditScreen extends StatefulWidget {
  final Product product;
  final ProductNameModel? productName;
  final ProductBrandModel? productBrand;
  final CategoryModel? productCategory;

  const ProductEditScreen({
    super.key,
    required this.product,
    this.productName,
    this.productBrand,
    this.productCategory,
  });

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _skuController = TextEditingController();
  final _partNumberController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _weightController = TextEditingController();
  final _unitController = TextEditingController();

  // Physical dimensions controllers
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();

  // Selection variables
  ProductNameModel? _selectedProductName;
  ProductBrandModel? _selectedBrand;
  CategoryModel? _selectedCategory;

  // Available options
  List<ProductNameModel> _availableProductNames = [];
  List<ProductBrandModel> _availableBrands = [];
  List<CategoryModel> _availableCategories = [];

  // Storage information
  String? _selectedStorageType;
  String? _selectedMovementFrequency;
  bool _requiresClimateControl = false;
  bool _isHazardousMaterial = false;
  bool _isActive = true;

  // Dropdown options
  final List<String> _storageTypes = [
    'floor',
    'shelf',
    'rack',
    'bulk',
    'special'
  ];
  final List<String> _movementFrequencies = ['fast', 'medium', 'slow'];

  // Storage type display names
  final Map<String, String> _storageTypeNames = {
    'floor': 'Floor Storage',
    'shelf': 'Shelf Storage',
    'rack': 'Rack System',
    'bulk': 'Bulk Storage',
    'special': 'Special Storage',
  };

  // Movement frequency display names
  final Map<String, String> _movementFrequencyNames = {
    'fast': 'Fast Moving',
    'medium': 'Medium',
    'slow': 'Slow Moving',
  };

  // Images
  List<String> _productImages = [];
  final ImagePicker _imagePicker = ImagePicker();

  // Loading states
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoadingData = true;
  bool _isUploadingImage = false;

  // DAOs
  final ProductNameDao _productNameDao = ProductNameDao();
  final ProductBrandDAO _productBrandDao = ProductBrandDAO();
  final CategoryDao _productCategoryDao = CategoryDao();

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 4, vsync: this); // Increased to 4 tabs
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _skuController.dispose();
    _partNumberController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _weightController.dispose();
    _unitController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      // Load available options
      await Future.wait([
        _loadProductNames(),
        _loadBrands(),
        _loadCategories(),
      ]);

      // Initialize form with current product data
      _initializeFormFields();

      setState(() {
        _isLoadingData = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoadingData = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _loadProductNames() async {
    try {
      _availableProductNames = await _productNameDao.getAllProductNames();

      // Set current selection
      if (widget.productName != null) {
        _selectedProductName = _availableProductNames.firstWhere(
          (name) => name.id == widget.productName!.id,
          orElse: () => widget.productName!,
        );
      }
    } catch (e) {
      print('Error loading product names: $e');
    }
  }

  Future<void> _loadBrands() async {
    try {
      _availableBrands = await _productBrandDao.getAllBrands();

      // Set current selection
      if (widget.productBrand != null) {
        _selectedBrand = _availableBrands.firstWhere(
          (brand) => brand.id == widget.productBrand!.id,
          orElse: () => widget.productBrand!,
        );
      }
    } catch (e) {
      print('Error loading brands: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      _availableCategories = await _productCategoryDao.getAllCategories();

      // Set current selection
      if (widget.productCategory != null) {
        _selectedCategory = _availableCategories.firstWhere(
          (category) => category.id == widget.productCategory!.id,
          orElse: () => widget.productCategory!,
        );
      }
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  void _initializeFormFields() {
    // Basic fields
    _skuController.text = widget.product.sku;
    _partNumberController.text = widget.product.partNumber ?? '';
    _descriptionController.text = widget.product.description;
    _priceController.text = widget.product.price?.toString() ?? '';
    _weightController.text = widget.product.weight?.toString() ?? '';
    _unitController.text = widget.product.unit;

    // Physical dimensions - safely access from metadata
    final dimensions =
        widget.product.metadata['dimensions'] as Map<String, dynamic>?;
    if (dimensions != null) {
      _lengthController.text =
          (dimensions['length'] as double?)?.toString() ?? '';
      _widthController.text =
          (dimensions['width'] as double?)?.toString() ?? '';
      _heightController.text =
          (dimensions['height'] as double?)?.toString() ?? '';
    }

    // Storage Information - safely access metadata and product properties
    _selectedStorageType =
        widget.product.metadata['storageType'] as String? ?? 'shelf';
    _selectedMovementFrequency =
        widget.product.metadata['movementFrequency'] as String? ?? 'medium';
    _requiresClimateControl =
        widget.product.metadata['requiresClimateControl'] as bool? ?? false;
    _isHazardousMaterial =
        widget.product.metadata['isHazardousMaterial'] as bool? ?? false;
    _isActive = widget.product.metadata['isActive'] as bool? ?? true;

    // Images - safely handle image list
    final imageUrls = widget.product.metadata['images'];
    if (imageUrls != null && imageUrls is List) {
      _productImages = List<String>.from(imageUrls);
    } else {
      _productImages = [];
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Prepare metadata - preserve existing metadata and add new fields
      final Map<String, dynamic> metadata =
          Map<String, dynamic>.from(widget.product.metadata);

      // Add/update specific fields
      if (_productImages.isNotEmpty) {
        metadata['images'] = _productImages;
      } else {
        metadata.remove('images');
      }

      // Physical dimensions
      if (_lengthController.text.isNotEmpty &&
          _widthController.text.isNotEmpty &&
          _heightController.text.isNotEmpty) {
        metadata['dimensions'] = {
          'length': double.tryParse(_lengthController.text) ?? 0.1,
          'width': double.tryParse(_widthController.text) ?? 0.1,
          'height': double.tryParse(_heightController.text) ?? 0.1,
        };
      }

      // Storage information
      metadata['storageType'] = _selectedStorageType ?? 'shelf';
      metadata['movementFrequency'] = _selectedMovementFrequency ?? 'medium';
      metadata['requiresClimateControl'] = _requiresClimateControl;
      metadata['isHazardousMaterial'] = _isHazardousMaterial;
      metadata['isActive'] = _isActive;

      // Prepare update data
      final Map<String, dynamic> updateData = {
        'name': _selectedProductName?.id ?? widget.product.name,
        'sku': _skuController.text.trim(),
        'brand': _selectedBrand?.id ?? widget.product.brand,
        'category': _selectedCategory?.id ?? widget.product.category,
        'description': _descriptionController.text.trim(),
        'unit': _unitController.text.trim(),
        'isActive': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
        'metadata': metadata,
      };

      // Add optional fields only if they have values
      if (_partNumberController.text.trim().isNotEmpty) {
        updateData['partNumber'] = _partNumberController.text.trim();
      }

      if (_priceController.text.trim().isNotEmpty) {
        final price = double.tryParse(_priceController.text);
        if (price != null) {
          updateData['price'] = price;
        }
      }

      if (_weightController.text.trim().isNotEmpty) {
        final weight = double.tryParse(_weightController.text);
        if (weight != null) {
          updateData['weight'] = weight;
        }
      }

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.product.id)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Return success
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print('Error saving product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving product: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    if (_isUploadingImage) return;

    try {
      setState(() {
        _isUploadingImage = true;
      });

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final XFile imageFile = XFile(pickedFile.path);

        // Upload image to your service
        final uploadedFileName =
            await ProductImageService.uploadProductImage(imageFile);

        if (uploadedFileName != null && mounted) {
          setState(() {
            _productImages.add(uploadedFileName);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload image. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error picking/uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _removeImage(int index) async {
    if (index < 0 || index >= _productImages.length) return;

    final fileName = _productImages[index];

    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text('Are you sure you want to delete this image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        // Delete from storage if it's not a placeholder
        if (!fileName.startsWith('placeholder_')) {
          await ProductImageService.deleteProductImage(fileName);
        }

        // Remove from local list
        if (mounted) {
          setState(() {
            _productImages.removeAt(index);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('Error deleting image: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting image: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Product'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton.icon(
              onPressed: _saveProduct,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue[700],
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue[700],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.blue[700],
          isScrollable: true,
          tabs: const [
            Tab(text: 'Basic Info'),
            Tab(text: 'Physical'),
            Tab(text: 'Storage'),
            Tab(text: 'Images'),
          ],
        ),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBasicInfoTab(),
                  _buildPhysicalTab(),
                  _buildStorageTab(),
                  _buildImagesTab(),
                ],
              ),
            ),
    );
  }

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Product Identification'),
          const SizedBox(height: 16),

          // Product Name Selection
          _buildProductNameDropdown(),
          const SizedBox(height: 16),

          // SKU Field
          TextFormField(
            controller: _skuController,
            decoration: const InputDecoration(
              labelText: 'SKU *',
              hintText: 'Enter product SKU',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'SKU is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Part Number Field
          TextFormField(
            controller: _partNumberController,
            decoration: const InputDecoration(
              labelText: 'Part Number',
              hintText: 'Enter part number (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 32),

          _buildSectionHeader('Classification'),
          const SizedBox(height: 16),

          // Brand Selection
          _buildBrandDropdown(),
          const SizedBox(height: 16),

          // Category Selection
          _buildCategoryDropdown(),
          const SizedBox(height: 32),

          _buildSectionHeader('Pricing & Details'),
          const SizedBox(height: 16),

          // Price and Unit in row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Unit Price (RM)',
                    hintText: 'Enter price',
                    border: OutlineInputBorder(),
                    prefixText: 'RM ',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _unitController,
                  decoration: const InputDecoration(
                    labelText: 'Unit *',
                    hintText: 'e.g., PCS, KG, LITER',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Unit is required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Description Field
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description *',
              hintText: 'Enter product description',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Description is required';
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          // Product Status
          _buildSectionHeader('Product Status'),
          const SizedBox(height: 16),

          SwitchListTile(
            title: const Text('Product is Active'),
            subtitle:
                const Text('Inactive products will be hidden from listings'),
            value: _isActive,
            onChanged: (value) {
              setState(() {
                _isActive = value;
              });
            },
            secondary: const Icon(Icons.visibility),
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildPhysicalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    const Icon(Icons.straighten,
                        color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Physical Properties',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Dimensions row
                const Text(
                  'Dimensions (required for warehouse allocation)',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*$')),
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*$')),
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*$')),
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
                const SizedBox(height: 16),

                // Weight
                TextFormField(
                  controller: _weightController,
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.fitness_center),
                    helperText: 'kilograms',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                  ],
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Weight is required';
                    if (double.tryParse(value!) == null)
                      return 'Invalid weight';
                    if (double.parse(value) <= 0)
                      return 'Must be greater than 0';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      'Storage & Handling Requirements',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.purple,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Storage Type
                DropdownButtonFormField<String>(
                  value: _selectedStorageType,
                  decoration: const InputDecoration(
                    labelText: 'Preferred Storage Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory_2),
                    helperText: 'How this product should be stored',
                  ),
                  items: _storageTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_storageTypeNames[type] ?? type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStorageType = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Movement Frequency
                DropdownButtonFormField<String>(
                  value: _selectedMovementFrequency,
                  decoration: const InputDecoration(
                    labelText: 'Movement Frequency',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.speed),
                    helperText: 'How often this item is picked/moved',
                  ),
                  items: _movementFrequencies.map((frequency) {
                    return DropdownMenuItem(
                      value: frequency,
                      child:
                          Text(_movementFrequencyNames[frequency] ?? frequency),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedMovementFrequency = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Special Requirements
                const Text(
                  'Special Requirements',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),

                CheckboxListTile(
                  title: const Text('Requires Climate Control'),
                  subtitle:
                      const Text('Temperature/humidity controlled environment'),
                  value: _requiresClimateControl,
                  onChanged: (value) {
                    setState(() {
                      _requiresClimateControl = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),

                CheckboxListTile(
                  title: const Text('Hazardous Material'),
                  subtitle: const Text('Requires special handling and storage'),
                  value: _isHazardousMaterial,
                  onChanged: (value) {
                    setState(() {
                      _isHazardousMaterial = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSectionHeader('Product Images'),
              ),
              ElevatedButton.icon(
                onPressed: _isUploadingImage ? null : _showImageSourceDialog,
                icon: _isUploadingImage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_photo_alternate),
                label: Text(_isUploadingImage ? 'Uploading...' : 'Add Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          if (_productImages.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Icon(Icons.photo_library, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No Images Added',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add images to showcase your product',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: _productImages.length,
              itemBuilder: (context, index) {
                return _buildImageTile(_productImages[index], index);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _showImageSourceDialog() async {
    if (_isUploadingImage) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Add Product Image',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how you want to add an image',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),

                // Camera option
                _buildImageSourceOption(
                  icon: Icons.camera_alt,
                  title: 'Take Photo',
                  subtitle: 'Capture a new photo with camera',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromSource(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 12),

                // Gallery option
                _buildImageSourceOption(
                  icon: Icons.photo_library,
                  title: 'Choose from Gallery',
                  subtitle: 'Select an existing photo',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromSource(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 20),

                // Cancel button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    if (_isUploadingImage) return;

    try {
      setState(() {
        _isUploadingImage = true;
      });

      // Different settings for camera vs gallery
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: source == ImageSource.camera ? 1920 : 1920,
        maxHeight: source == ImageSource.camera ? 1080 : 1080,
        imageQuality: source == ImageSource.camera ? 90 : 85,
        preferredCameraDevice: CameraDevice.rear, // Use rear camera by default
      );

      if (pickedFile != null) {
        final XFile imageFile = XFile(pickedFile.path);

        // Upload image to your service
        final uploadedFileName =
            await ProductImageService.uploadProductImage(imageFile);

        if (uploadedFileName != null && mounted) {
          setState(() {
            _productImages.add(uploadedFileName);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    source == ImageSource.camera
                        ? 'Photo captured and uploaded successfully!'
                        : 'Image uploaded successfully!',
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.error,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text('Failed to upload image. Please try again.'),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error picking/uploading image: $e');
      if (mounted) {
        String errorMessage = 'Error uploading image: $e';

        // Provide more specific error messages
        if (e.toString().contains('camera')) {
          errorMessage = source == ImageSource.camera
              ? 'Camera access denied. Please check app permissions.'
              : 'Error accessing gallery. Please try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.warning,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Widget _buildImageTile(String fileName, int index) {
    return FutureBuilder<String?>(
      future: fileName.startsWith('placeholder_')
          ? Future.value(null)
          : ProductImageService.getProductImageSignedUrl(fileName),
      builder: (context, snapshot) {
        final signedUrl = snapshot.data;

        return Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (signedUrl != null && signedUrl.isNotEmpty)
                    ? Image.network(
                        signedUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading image: $error');
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, color: Colors.grey[400]),
                              const SizedBox(height: 4),
                              Text(
                                'Failed to load',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          );
                        },
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image, color: Colors.grey[400]),
                          const SizedBox(height: 4),
                          Text(
                            fileName.startsWith('placeholder_')
                                ? 'Placeholder'
                                : 'Loading...',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removeImage(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildProductNameDropdown() {
    return DropdownButtonFormField<ProductNameModel>(
      value: _selectedProductName,
      decoration: const InputDecoration(
        labelText: 'Product Name *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.shopping_bag),
      ),
      items: _availableProductNames.map((productName) {
        return DropdownMenuItem(
          value: productName,
          child: Text(productName.productName),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedProductName = value;
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Product name is required';
        }
        return null;
      },
    );
  }

  Widget _buildBrandDropdown() {
    return DropdownButtonFormField<ProductBrandModel>(
      value: _selectedBrand,
      decoration: const InputDecoration(
        labelText: 'Brand',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.branding_watermark),
      ),
      items: _availableBrands.map((brand) {
        return DropdownMenuItem(
          value: brand,
          child: Text(brand.brandName),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedBrand = value;
        });
      },
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<CategoryModel>(
      value: _selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.category),
      ),
      items: _availableCategories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Text(category.name),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCategory = value;
        });
      },
    );
  }
}
