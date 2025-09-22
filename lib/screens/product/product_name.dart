import 'package:assignment/dao/product_category_dao.dart';
import 'package:assignment/models/product.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import '../../models/product_category_model.dart';
import '../../models/product_name_model.dart';
import '../../dao/product_name_dao.dart';
import '../../services/statistics/product_name_statistic_service.dart';
import '../../widgets/form/category_form.dart';

class ProductNameManagementScreen extends StatefulWidget {
  const ProductNameManagementScreen({super.key});

  @override
  State<ProductNameManagementScreen> createState() =>
      _ProductNameManagementScreenState();
}

class _ProductNameManagementScreenState
    extends State<ProductNameManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ProductNameDao _productNameDao = ProductNameDao();
  final CategoryDao _categoryDao = CategoryDao();
  final ProductNameStatisticsService _statisticsService =
      ProductNameStatisticsService();
  StreamSubscription<ProductNameStatistics>? _statisticsSubscription;
  ProductNameStatistics? _currentStatistics;

  // State variables
  List<ProductNameModel> productNames = [];
  List<ProductNameModel> filteredProductNames = [];
  bool isLoading = true;
  String? errorMessage;
  String searchQuery = '';
  String selectedCategory = 'All';
  String selectedStatus = 'All';
  String sortBy = 'name';
  bool isAscending = true;

  // Filter options
  List<String> availableCategories = ['All'];
  List<String> availableStatus = ['All', 'Active', 'Inactive', 'Unused'];

  // Real-time subscription
  StreamSubscription<List<ProductNameModel>>? _productNamesSubscription;
  StreamSubscription<List<CategoryModel>>? _categoriesSubscription;

  @override
  void initState() {
    super.initState();
    _updateCategoryNameMap();
    _setupRealtimeUpdates();
    _setupStatisticsUpdates(); // ADD THIS LINE
    _setupCategoryUpdates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _productNamesSubscription?.cancel();
    _categoriesSubscription?.cancel();
    _statisticsSubscription?.cancel(); // ADD THIS LINE
    super.dispose();
  }

  void _setupStatisticsUpdates() {
    _statisticsSubscription =
        _statisticsService.getProductNameStatisticsStream().listen(
      (statistics) {
        print('Product name statistics updated: ${statistics.toString()}');
        setState(() {
          _currentStatistics = statistics;

          productNames = productNames.map((productName) {
            final usageStats = statistics.usageStats[productName.productName];
            if (usageStats != null) {
              return productName.copyWith(
                usageCount: usageStats.usageCount,
              );
            }
            return productName.copyWith(usageCount: 0);
          }).toList();
        });
        _applyFilters();
      },
      onError: (error) {
        print('Statistics listener error: $error');
      },
    );
  }

  void _setupRealtimeUpdates() {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    _productNamesSubscription = _productNameDao.getProductNamesStream().listen(
      (names) {
        print('Product names collection changed: ${names.length} names');

        // Don't use the old _usageCounts map anymore,
        // the statistics service will provide usage counts
        setState(() {
          productNames = names;
          isLoading = false;
          errorMessage = null;
        });

        _applyFilters();
      },
      onError: (error) {
        print('Product names listener error: $error');
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load product names: $error';
        });
      },
    );
  }

  void _setupCategoryUpdates() {
    _categoriesSubscription = _categoryDao.getCategoriesStream().listen(
          (categories) {
        print('Categories updated: ${categories.length} categories');

        // Update category name map
        _categoryIdToNameMap = {
          for (final category in categories) category.id!: category.name
        };

        final categoryNames = [
          'All',
          ...categories.where((c) => c.isActive).map((c) => c.name).toList()
        ];

        setState(() {
          availableCategories = categoryNames;
        });

        // Reset selected category if it no longer exists
        if (!categoryNames.contains(selectedCategory)) {
          setState(() {
            selectedCategory = 'All';
          });
          _applyFilters();
        }
      },
      onError: (error) {
        print('Categories listener error: $error');
      },
    );
  }

  // Future<void> _refreshProductNames() async {
  //   setState(() {
  //     isLoading = true;
  //   });
  //   try {
  //     // Trigger a fresh data fetch
  //     await _productNameDao.getAllProductNames();
  //   } catch (e) {
  //     setState(() {
  //       errorMessage = 'Failed to refresh: $e';
  //     });
  //   } finally {
  //     setState(() {
  //       isLoading = false;
  //     });
  //   }
  // }

  Future<void> _refreshProductNames() async {
    // Show loading indicator
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // 1. Clear all subscriptions to stop listening
      _productNamesSubscription?.cancel();
      _categoriesSubscription?.cancel();
      _statisticsSubscription?.cancel();

      // 2. Wait for a brief moment to ensure subscriptions are cleared
      await Future.delayed(const Duration(milliseconds: 100));

      // 3. Force refresh all data sources
      final results = await Future.wait([
        _productNameDao.refreshProductNames(), // Add this method to DAO
        _categoryDao.refreshCategories(), // Add this method to DAO
        _statisticsService.refreshStatistics(), // Add this method to service
      ]);

      // 4. Check if all refreshes succeeded
      if (results.any((result) => result == false)) {
        throw Exception('Some data sources failed to refresh');
      }

      // 5. Re-setup all subscriptions for real-time updates
      await Future.delayed(const Duration(milliseconds: 50));
      _setupRealtimeUpdates();
      _setupCategoryUpdates();
      _setupStatisticsUpdates();

      // 6. Show success message
      _showSnackBar('Data refreshed successfully!', Colors.green);
    } catch (e) {
      // 7. Handle errors
      setState(() {
        errorMessage = 'Failed to refresh: $e';
      });
      _showSnackBar('Refresh failed: $e', Colors.red);

      // 8. Attempt to re-establish connections
      await Future.delayed(const Duration(milliseconds: 200));
      _setupRealtimeUpdates();
      _setupCategoryUpdates();
      _setupStatisticsUpdates();
    } finally {
      // 9. Always hide loading
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    List<ProductNameModel> filtered = List.from(productNames);

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((productName) {
        return productName.matchesSearch(searchQuery);
      }).toList();
    }

    // Apply category filter
    if (selectedCategory != 'All') {
      filtered = filtered
          .where((productName) => productName.category == selectedCategory)
          .toList();
    }

    // Apply status filter
    if (selectedStatus != 'All') {
      if (selectedStatus == 'Active') {
        filtered =
            filtered.where((productName) => productName.isActive).toList();
      } else if (selectedStatus == 'Inactive') {
        filtered =
            filtered.where((productName) => !productName.isActive).toList();
      } else if (selectedStatus == 'Unused') {
        filtered = filtered
            .where((productName) => productName.usageCount == 0)
            .toList();
      }
    }

    // Apply sorting
    filtered.sort((a, b) {
      int comparison;
      switch (sortBy) {
        case 'name':
          comparison = a.productName.compareTo(b.productName);
          break;
        case 'category':
          comparison = a.category.compareTo(b.category);
          break;
        case 'usage':
          comparison = a.usageCount.compareTo(b.usageCount);
          break;
        case 'created':
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case 'updated':
          comparison = a.updatedAt.compareTo(b.updatedAt);
          break;
        default:
          comparison = a.productName.compareTo(b.productName);
      }
      return isAscending ? comparison : -comparison;
    });

    setState(() {
      filteredProductNames = filtered;
    });
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              backgroundColor == Colors.green
                  ? Icons.check_circle
                  : backgroundColor == Colors.red
                      ? Icons.error
                      : Icons.info,
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

  // CRUD Operations using DAO
  Future<void> _createProductName(ProductNameModel productName) async {
    try {
      // Get category by name first
      CategoryModel? ctg = await _categoryDao.getCategoryByName(productName.category);
      if (ctg == null) {
        _showSnackBar('Category not found!', Colors.red);
        return;
      }

      // Update the productName with category ID
      productName = productName.copyWith(category: ctg.id!);

      final err = await _productNameDao.createProductName(productName);
      if (err) {
        _showSnackBar('Product name created successfully!', Colors.green);
      } else {
        _showSnackBar('Product name duplicated please changed it.', Colors.red);
      }
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
    }
  }

  Future<void> _updateProductName(ProductNameModel productName) async {
    try {
      // Get category by name first
      CategoryModel? ctg = await _categoryDao.getCategoryByName(productName.category);
      if (ctg == null) {
        _showSnackBar('Category not found!', Colors.red);
        return;
      }

      // Update the productName with category ID
      productName = productName.copyWith(category: ctg.id!);

      await _productNameDao.updateProductName(productName);
      _showSnackBar('Product name updated successfully!', Colors.green);
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
    }
  }

  Map<String, int> _calculateFilteredStats() {
    final totalNames = filteredProductNames.length;
    final activeNames = filteredProductNames.where((n) => n.isActive).length;
    final inactiveNames = filteredProductNames.where((n) => !n.isActive).length;
    final unusedNames =
        filteredProductNames.where((n) => n.usageCount == 0 && n.isActive).length;
    return {
      'total': totalNames,
      'active': activeNames,
      'inactive': inactiveNames,
      'unused': unusedNames,
    };
  }

  Future<void> _deleteProductName(ProductNameModel productName) async {
    // Use the statistics service to check usage count
    final usageCount = await _statisticsService
        .getProductNameUsageCount(productName.productName);

    if (usageCount > 0) {
      _showSnackBar(
        'Cannot delete product name used by $usageCount products. Update those products first.',
        Colors.red,
      );
      return;
    }

    try {
      await _productNameDao.toggleProductNameStatus(
          productName.id!, productName.isActive);
      _showSnackBar(
          'Product name ${productName.isActive ? 'deleted' : 'restored'} successfully!',
          Colors.green);
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
    }
  }

  // Category CRUD Operations
  Future<void> _createCategory(CategoryModel category) async {
    if (!mounted) return;

    try {
      final success = await _categoryDao.createCategoryWithValidation(category);
      if (mounted) {
        if (success) {
          _showSnackBar('Category created successfully!', Colors.green);
        } else {
          _showSnackBar(
              'Failed to create category. Name may already exist.', Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        print(e.toString());
        _showSnackBar('Error: ${e.toString()}', Colors.red);
      }
    }
  }

  // UI Methods
  void _showAddProductNameDialog() {
    _showProductNameFormDialog(null);
  }

  void _showEditProductNameDialog(ProductNameModel productName) {
    _showProductNameFormDialog(productName);
  }

  void _showProductNameFormDialog(ProductNameModel? productName) {
    final isEditing = productName != null;
    final formKey = GlobalKey<FormState>();

    // Controllers for form fields
    final nameController = TextEditingController(text: productName?.productName ?? '');
    final nameKey = GlobalKey<FormFieldState>();
    final descriptionController = TextEditingController(text: productName?.description ?? '');

    // Get category name from ID
    String selectedFormCategory = '';
    if (isEditing && productName!.category.isNotEmpty) {
      selectedFormCategory = _categoryIdToNameMap[productName.category] ?? productName.category;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(isEditing ? 'Edit Product Name' : 'Add New Product Name'),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name (unchanged)
                    TextFormField(
                      controller: nameController,
                      key: nameKey,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: 'e.g., Engine Oil Filter',
                        label: RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Product Name ',
                                style: TextStyle(color: Colors.black, fontSize: 16),
                              ),
                              TextSpan(
                                text: '*',
                                style: TextStyle(color: Colors.red, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter product name';
                        }
                        if (value.trim().length < 3) {
                          return 'Product name must be at least 3 characters.';
                        }
                        if (value.trim().length > 100) {
                          return 'Please make your product name shorter.';
                        }
                        return null;
                      },
                      onChanged: (_) {
                        nameKey.currentState!.validate();
                      },
                    ),
                    const SizedBox(height: 16),

                    // Category Dropdown
                    Text(
                      'Category *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey[400]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButtonFormField<String>(
                                dropdownColor: Colors.white,
                                value: selectedFormCategory.isEmpty ||
                                    !availableCategories.contains(selectedFormCategory)
                                    ? null
                                    : selectedFormCategory,
                                decoration: const InputDecoration(
                                  hintText: 'Select or create category',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                items: availableCategories
                                    .where((cat) => cat != 'All')
                                    .map((category) {
                                  return DropdownMenuItem(
                                    value: category,
                                    child: Text(
                                      category,
                                      style: const TextStyle(fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedFormCategory = value ?? '';
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a category';
                                  }
                                  return null;
                                },
                                isExpanded: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showCategoryFormDialog(null, setDialogState),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('New'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Description (unchanged)
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Description (Optional)',
                        hintText: 'Enter product description...',
                      ),
                      maxLines: 3,
                      maxLength: 500,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isEditing ? Colors.orange : Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final now = DateTime.now();

                  // Create ProductNameModel with category name (will be converted to ID in CRUD methods)
                  final newProductName = ProductNameModel(
                    id: productName?.id,
                    productName: nameController.text.trim(),
                    description: descriptionController.text.trim(),
                    category: selectedFormCategory, // This is the category NAME
                    isActive: productName?.isActive ?? true,
                    usageCount: productName?.usageCount ?? 0,
                    createdAt: productName?.createdAt ?? now,
                    updatedAt: now,
                    createdBy: productName?.createdBy ?? 'current_user',
                  );

                  Navigator.pop(context);

                  if (isEditing) {
                    _updateProductName(newProductName);
                  } else {
                    _createProductName(newProductName);
                  }
                }
              },
              child: Text(isEditing ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryFormDialog(
      CategoryModel? category, StateSetter? parentSetState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Add New Category'),
        content: SizedBox(
          width: double.maxFinite,
          child: CategoryFormWidget(
            category: category,
            onSubmit: (categoryData) {
              Navigator.pop(context);
              _createCategory(categoryData).then((_) {
                // Update the parent dialog's state if it exists
                if (parentSetState != null) {
                  // The category will be automatically added to availableCategories
                  // through the real-time subscription
                }
              });
            },
            onCancel: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(ProductNameModel productName) {
    // Get usage count from the current statistics
    final usageStats = _currentStatistics?.usageStats[productName.productName];
    final usageCount = usageStats?.usageCount ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title:
            Text('${productName.isActive ? 'Delete' : 'Restore'} Product Name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Are you sure you want to ${productName.isActive ? 'delete' : 'restore'} "${productName.productName}"?'),
            const SizedBox(height: 16),
            if (usageCount > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This product name is used by $usageCount products. You cannot delete it until all products are updated.',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Text('This action cannot be undone.'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (usageCount == 0)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteProductName(productName);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      productName.isActive ? Colors.red : Colors.green),
              child: Text(productName.isActive ? 'Delete' : 'Restore',
                  style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: isLoading
          ? _buildLoadingScreen()
          : errorMessage != null
              ? _buildErrorScreen()
              : Column(
                  children: [
                    _buildSearchAndFilters(),
                    _buildStatsBar(),
                    Expanded(
                      child: filteredProductNames.isEmpty
                          ? _buildEmptyState()
                          : _buildProductNamesList(),
                    ),
                  ],
                ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Optional: Add statistics button
          if (_currentStatistics?.unusedProductNames != null &&
              _currentStatistics!.unusedProductNames > 0)
            FloatingActionButton.small(
              onPressed: () => _showUnusedNamesDialog(),
              backgroundColor: Colors.orange,
              tooltip:
                  'View Unused Names (${_currentStatistics!.unusedProductNames})',
              heroTag: 'unused_names',
              child: const Icon(Icons.warning, color: Colors.white),
            ),
          const SizedBox(height: 8),
          FloatingActionButton(
            onPressed: _showAddProductNameDialog,
            backgroundColor: Colors.green[600],
            tooltip: 'Add New Product Name',
            heroTag: 'add_product_name',
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showStatisticsDialog() {
    if (_currentStatistics == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Name Statistics'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatisticsSection('Overall Statistics', [
                  'Total Product Names: ${_currentStatistics!.totalProductNames}',
                  'Active Product Names: ${_currentStatistics!.activeProductNames}',
                  'Inactive Product Names: ${_currentStatistics!.inactiveProductNames}',
                  'Unused Product Names: ${_currentStatistics!.unusedProductNames}',
                ]),
                const SizedBox(height: 16),
                _buildStatisticsSection(
                  'Category Breakdown',
                  _currentStatistics!.categoryStats.values
                      .map((stat) =>
                          '${stat.categoryName}: ${stat.totalProductNames} names (${stat.totalUsageCount} total usage)')
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showUnusedNamesDialog();
            },
            child: const Text('View Unused Names'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Text('• $item'),
            )),
      ],
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Colors.blue,
          ),
          SizedBox(height: 16),
          Text(
            'Loading product names...',
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
              'Error Loading Product Names',
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
              onPressed: _refreshProductNames,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search product names or categories',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                searchQuery = '';
                              });
                              _applyFilters();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              _buildSortButton(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            spacing: double.minPositive,
            children: [
              Expanded(child: _buildCategoryFilter()),
              const SizedBox(width: 3),
              Expanded(child: _buildStatusFilter()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return DropdownButtonFormField<String>(
      dropdownColor: Colors.white,
      value: selectedCategory,
      decoration: InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: availableCategories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Text(category, style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedCategory = value!;
        });
        _applyFilters();
      },
    );
  }

  Widget _buildStatusFilter() {
    return DropdownButtonFormField<String>(
      dropdownColor: Colors.white,
      value: selectedStatus,
      decoration: InputDecoration(
        labelText: 'Status',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: availableStatus.map((status) {
        return DropdownMenuItem(
          value: status,
          child: Text(status, style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedStatus = value!;
        });
        _applyFilters();
      },
    );
  }

  Widget _buildSortButton() {
    return PopupMenuButton<String>(
      color: Colors.white,
      icon: const Icon(Icons.sort, size: 20),
      tooltip: 'Sort Options',
      onSelected: (value) {
        setState(() {
          if (sortBy == value) {
            isAscending = !isAscending;
          } else {
            sortBy = value;
            isAscending = true;
          }
        });
        _applyFilters();
      },
      itemBuilder: (context) => [
        _buildSortMenuItem('name', 'Product Name', Icons.text_fields),
        _buildSortMenuItem('category', 'Category', Icons.category),
        _buildSortMenuItem('usage', 'Usage Count', Icons.trending_up),
        _buildSortMenuItem('created', 'Created Date', Icons.schedule),
        _buildSortMenuItem('updated', 'Updated Date', Icons.update),
      ],
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(
      String value, String label, IconData icon) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          if (sortBy == value)
            Icon(
              isAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
            ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    if (_currentStatistics == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: const Text(
          'Loading statistics...',
          style: TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    final filteredStats = _calculateFilteredStats();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          // Current filtered statistics
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatChip('${filteredStats['total']} total', Colors.green),
              _buildStatChip('${filteredStats['active']} active', Colors.blue),
              if (filteredStats['inactive']! > 0)
                _buildStatChip(
                    '${filteredStats['inactive']} inactive', Colors.orange),
              if (filteredStats['unused']! > 0)
                _buildStatChip('${filteredStats['unused']} unused', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String text, Color color) {
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
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'No Product Names Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isNotEmpty
                  ? 'No product names match your search criteria'
                  : 'No product names created yet',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddProductNameDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create First Product Name'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
              ),
            ),
            if (searchQuery.isNotEmpty || selectedCategory != 'All') ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    searchQuery = '';
                    selectedCategory = 'All';
                    selectedStatus = 'All';
                    _searchController.clear();
                  });
                  _applyFilters();
                },
                child: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductNamesList() {
    return RefreshIndicator(
      onRefresh: _refreshProductNames,
      backgroundColor: Colors.white,
      color: Colors.blue,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: filteredProductNames.length,
        itemBuilder: (context, index) {
          final productName = filteredProductNames[index];
          return _buildProductNameCard(productName);
        },
      ),
    );
  }

  Map<String, String> _categoryIdToNameMap = {};

// Add this method to update the category map
  Future<void> _updateCategoryNameMap() async {
    try {
      final categories = await _categoryDao.getAllCategories();
      _categoryIdToNameMap = {
        for (final category in categories) category.id!: category.name
      };
      print('Updated category name map: ${_categoryIdToNameMap.length} categories');
    } catch (e) {
      print('Error updating category name map: $e');
    }
  }

  Widget _buildProductNameCard(ProductNameModel productName) {
    // Get usage stats from the current statistics
    final usageStats = _currentStatistics?.usageStats[productName.productName];
    final usageCount = usageStats?.usageCount ?? 0;
    final itemCount = usageStats?.itemCount ?? 0;
    final isUnused = usageCount == 0;

    // Get category name from ID
    final categoryName = _categoryIdToNameMap[productName.category] ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: productName.isActive
              ? (isUnused ? Colors.orange[200]! : Colors.grey[200]!)
              : Colors.red[200]!,
          width: isUnused ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              productName.productName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: productName.isActive
                                    ? Colors.black
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                          if (!productName.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Text(
                                'INACTIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.category, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            categoryName, // Now shows category name instead of ID
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  color: Colors.white,
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (action) => _handleMenuAction(action, productName),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                              productName.isActive ? Icons.delete : Icons.restore,
                              size: 16,
                              color: productName.isActive
                                  ? Colors.red
                                  : Colors.green),
                          const SizedBox(width: 8),
                          Text(productName.isActive ? 'Delete' : 'Restore',
                              style: TextStyle(
                                  color: productName.isActive
                                      ? Colors.red
                                      : Colors.green)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Description
            if (productName.description.isNotEmpty) ...[
              Text(
                productName.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],

            // Metrics row - Now showing both product usage and item counts
            Row(
              children: [
                _buildMetricChip(
                  '$usageCount',
                  'Products',
                  isUnused ? Colors.red : Colors.blue,
                  Icons.inventory_2,
                ),
                const SizedBox(width: 8),
                _buildMetricChip(
                  '$itemCount',
                  'Items',
                  itemCount == 0 ? Colors.orange : Colors.green,
                  Icons.widgets,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Bottom info
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Created: ${_formatDate(productName.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                if (usageStats?.lastUsed != null)
                  Text(
                    'Last used: ${_formatDate(usageStats!.lastUsed)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(
      String value, String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, ProductNameModel productName) {
    switch (action) {
      case 'edit':
        _showEditProductNameDialog(productName);
        break;
      case 'delete':
        _showDeleteConfirmation(productName);
        break;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // ADD THIS METHOD TO SHOW UNUSED NAMES:
  void _showUnusedNamesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Unused Product Names'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: FutureBuilder<List<ProductNameUsageStats>>(
            future: _statisticsService.getUnusedProductNames(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }

              final unusedNames = snapshot.data ?? [];

              if (unusedNames.isEmpty) {
                return const Center(
                  child: Text('No unused product names found!'),
                );
              }

              return ListView.builder(
                itemCount: unusedNames.length,
                itemBuilder: (context, index) {
                  final unusedName = unusedNames[index];
                  return ListTile(
                    title: Text(unusedName.productName),
                    subtitle: Text('Category: ${unusedName.category}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!unusedName.isActive)
                          const Icon(Icons.warning,
                              color: Colors.orange, size: 16),
                        PopupMenuButton<String>(
                          onSelected: (action) {
                            Navigator.pop(context);
                            if (action == 'delete') {
                              _deleteProductName(
                                  unusedName as ProductNameModel);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      size: 16, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
