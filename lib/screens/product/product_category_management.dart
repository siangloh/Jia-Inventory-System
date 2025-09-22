import 'package:flutter/material.dart';
import 'dart:async';

import '../../dao/product_category_dao.dart';
import '../../models/product_category_model.dart';
import '../../services/statistics/product_statistics.dart';
import '../../widgets/form/category_form.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen>
    with TickerProviderStateMixin {
  bool _isDisposed = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final CategoryDao _categoryDao = CategoryDao();
  final ProductStatisticsService _statisticsService =
      ProductStatisticsService(); // Add this

  // State variables
  List<CategoryModel> categories = [];
  List<CategoryModel> filteredCategories = [];
  bool isLoading = true;
  String? errorMessage;
  String searchQuery = '';
  String selectedStatus = 'All';
  String sortBy = 'name';
  bool isAscending = true;

  // Add product statistics
  ProductStatistics? productStatistics;

  // Filter options
  List<String> availableStatuses = ['All', 'Active', 'Inactive'];

  // Available icons for categories (needed for card display)
  static const Map<String, IconData> availableIcons = {
    'category': Icons.category,
    'build': Icons.build,
    'car_repair': Icons.car_repair,
    'electrical_services': Icons.electrical_services,
    'local_gas_station': Icons.local_gas_station,
    'tire_repair': Icons.tire_repair,
    'settings': Icons.settings,
    'lightbulb': Icons.lightbulb,
    'air': Icons.air,
    'speed': Icons.speed,
    'ac_unit': Icons.ac_unit,
    'water_drop': Icons.water_drop,
    'power': Icons.power,
    'tune': Icons.tune,
    'directions_car': Icons.directions_car,
  };

  // Real-time subscriptions
  StreamSubscription<List<CategoryModel>>? _categoriesSubscription;
  StreamSubscription<ProductStatistics>? _statisticsSubscription;

  @override
  void initState() {
    super.initState();
    _setupRealtimeUpdates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _categoriesSubscription?.cancel();
    _statisticsSubscription?.cancel();
    _isDisposed = true;
    super.dispose();
  }

  void _setupRealtimeUpdates() {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    // Setup categories subscription
    _categoriesSubscription =
        _categoryDao.getCategoriesWithProductCountsStream().listen(
      (categoriesList) {
        print('Categories updated: ${categoriesList.length} categories');

        if (mounted) {
          setState(() {
            categories = categoriesList;
            isLoading = false;
            errorMessage = null;
          });

          _applyFilters();
        }
      },
      onError: (error) {
        print('Categories listener error: $error');
        if (mounted) {
          setState(() {
            isLoading = false;
            errorMessage = 'Failed to load categories: $error';
          });
        }
      },
    );

    // Setup product statistics subscription
    _statisticsSubscription =
        _statisticsService.getProductStatisticsStream().listen(
      (statistics) {
        print(
            'Product statistics updated: ${statistics.totalItems} total items');

        if (mounted) {
          setState(() {
            productStatistics = statistics;
          });
        }
      },
      onError: (error) {
        print('Statistics listener error: $error');
      },
    );
  }

  Future<void> _refreshCategories() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Cancel and resubscribe streams for fresh data
      _categoriesSubscription?.cancel();
      _statisticsSubscription?.cancel();

      await Future.delayed(const Duration(milliseconds: 100));

      // Force DAO refresh (add refresh methods to DAOs)
      await _categoryDao.refreshCategories();
      await _statisticsService.refreshStatistics();

      // Resubscribe
      _setupRealtimeUpdates();

      _showSnackBar('Data refreshed!', Colors.green);
    } catch (e) {
      errorMessage = 'Refresh failed: $e';
      _showSnackBar('Refresh error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyFilters() {
    List<CategoryModel> filtered = List.from(categories);

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((category) {
        return category.name.toLowerCase().contains(query);
      }).toList();
    }

    // Apply status filter
    if (selectedStatus != 'All') {
      if (selectedStatus == 'Active') {
        filtered = filtered.where((category) => category.isActive).toList();
      } else {
        filtered = filtered.where((category) => !category.isActive).toList();
      }
    }

    // Apply sorting
    filtered.sort((a, b) {
      int comparison;
      switch (sortBy) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'productCount':
          comparison = a.productCount.compareTo(b.productCount);
          break;
        case 'items':
          // Sort by actual product items count
          final aItems =
              productStatistics?.categoryStats[a.id]?.totalItems ?? 0;
          final bItems =
              productStatistics?.categoryStats[b.id]?.totalItems ?? 0;
          comparison = aItems.compareTo(bItems);
          break;
        case 'created':
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case 'updated':
          comparison = a.updatedAt.compareTo(b.updatedAt);
          break;
        default:
          comparison = a.name.compareTo(b.name);
      }
      return isAscending ? comparison : -comparison;
    });

    setState(() {
      filteredCategories = filtered;
    });
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (_isDisposed) return;
    if (mounted) {
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
  }

  // CRUD Operations using CategoryService
  Future<void> _createCategory(CategoryModel category) async {
    if (_isDisposed || !mounted) return;

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

  Future<void> _updateCategory(CategoryModel category) async {
    if (_isDisposed || !mounted) return;

    try {
      await _categoryDao.updateCategoryWithValidation(category);
      if (mounted) {
        _showSnackBar('Category updated successfully!', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: ${e.toString()}', Colors.red);
      }
    }
  }

  Future<void> _deleteCategory(CategoryModel category) async {
    if (_isDisposed || !mounted) return;

    try {
      await _categoryDao.deleteCategoryWithSafetyChecks(category);
      if (mounted) {
        _showSnackBar('Category ${category.isActive ? 'deleted' : 'restored'} successfully!', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: ${e.toString()}', Colors.red);
      }
    }
  }

  // UI Methods - Now using the CategoryFormWidget
  // void _showAddCategoryDialog() {
  //   _showCategoryFormDialog(null);
  // }
  //
  // void _showEditCategoryDialog(CategoryModel category) {
  //   _showCategoryFormDialog(category);
  // }

  void _showCategoryFormDialog(CategoryModel? category) {
    final isEditing = category != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(isEditing ? 'Edit Category' : 'Add New Category'),
        content: SizedBox(
          width: double.maxFinite,
          child: CategoryFormWidget(
            category: category,
            onSubmit: (categoryData) {
              Navigator.pop(context);
              if (isEditing) {
                _updateCategory(categoryData);
              } else {
                _createCategory(categoryData);
              }
            },
            onCancel: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(CategoryModel category) {
    // Get actual item count from statistics
    final categoryStats = productStatistics?.categoryStats[category.id];
    final actualItemCount = categoryStats?.totalItems ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('${category.isActive ? 'Delete' : 'Restore'} Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Are you sure you want to ${category.isActive ? 'delete' : 'restore'} "${category.name}"?'),
            const SizedBox(height: 16),
            if (category.productCount > 0 || actualItemCount > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cannot delete this category:',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (category.productCount > 0)
                      Text(
                        '• ${category.productCount} products using this category',
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    if (actualItemCount > 0)
                      Text(
                        '• $actualItemCount product items in inventory',
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
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
          if (category.productCount == 0 && actualItemCount == 0)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteCategory(category);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      category.isActive ? Colors.red : Colors.green),
              child: Text(category.isActive ? 'Delete' : 'Restore',
                  style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

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
                      child: filteredCategories.isEmpty
                          ? _buildEmptyState()
                          : _buildCategoriesList(),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryFormDialog(null),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
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
            'Loading categories...',
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
              'Error Loading Categories',
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
              onPressed: _refreshCategories,
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
                    hintText: 'Search categories by name or description...',
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
            children: [
              Expanded(
                child: _buildStatusFilter(),
              ),
            ],
          ),
        ],
      ),
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
      items: availableStatuses.map((status) {
        return DropdownMenuItem(
          value: status,
          child: Text(status, style: const TextStyle(fontSize: 14)),
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
      icon: const Icon(Icons.sort, size: 20),
      color: Colors.white,
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
        _buildSortMenuItem('name', 'Name', Icons.text_fields),
        _buildSortMenuItem('productCount', 'Product Count', Icons.inventory),
        _buildSortMenuItem('items', 'Item Count', Icons.inventory_2),
        // New sort option
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
    final totalCategories = filteredCategories.length;
    final activeCategories = filteredCategories.where((c) => c.isActive).length;
    final inactiveCategories =
        filteredCategories.where((c) => !c.isActive).length;

    // Use product statistics for more accurate data
    final totalItems = productStatistics?.totalItems ?? 0;
    final availableItems = productStatistics?.availableItems ?? 0;
    final damagedItems = productStatistics?.damagedItems ?? 0;
    // final outOfStockItems = productStatistics?.outOfStockItems ?? 0;
    final outOfStockItems = productStatistics?.outOfStockItems ?? 0;

    print('OUT: $outOfStockItems');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Category stats
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatChip('$totalCategories total', Colors.purple),
              _buildStatChip('$activeCategories active', Colors.green),
              if (inactiveCategories > 0)
                _buildStatChip('$inactiveCategories inactive', Colors.orange),
            ],
          ),

          // Product item stats
          if (productStatistics != null) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatChip('$totalItems total items', Colors.blue),
                _buildStatChip('$availableItems available', Colors.green),
                if (damagedItems > 0)
                  _buildStatChip('$damagedItems damaged', Colors.red),
                if (outOfStockItems > 0)
                  _buildStatChip(
                      '$outOfStockItems out of stock', Colors.orange),
              ],
            ),
          ],
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
            Icon(Icons.category, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'No Categories Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isNotEmpty
                  ? 'No categories match your search criteria'
                  : 'No categories created yet',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCategoryFormDialog(null),
              icon: const Icon(Icons.add),
              label: const Text('Create First Category'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[600],
                foregroundColor: Colors.white,
              ),
            ),
            if (searchQuery.isNotEmpty || selectedStatus != 'All') ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    searchQuery = '';
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

  Widget _buildCategoriesList() {
    return RefreshIndicator(
      onRefresh: _refreshCategories,
      backgroundColor: Colors.white,
      color: Colors.blue,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: filteredCategories.length,
        itemBuilder: (context, index) {
          final category = filteredCategories[index];
          return _buildCategoryCard(category);
        },
      ),
    );
  }

  Widget _buildCategoryCard(CategoryModel category) {
    // Get statistics for this category
    final categoryStats = productStatistics?.categoryStats[category.id];
    final productCount = categoryStats?.productCount ?? 0;
    final totalItems = categoryStats?.totalItems ?? 0;
    final availableItems = categoryStats?.availableItems ?? 0;
    final damagedItems = categoryStats?.damagedItems ?? 0;
    final outOfStockItems = categoryStats?.outOfStockItems ?? 0;
print('OUT: $outOfStockItems');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: category.isActive ? Colors.grey[200]! : Colors.red[200]!,
          width: category.isActive ? 1 : 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    availableIcons[category.iconName] ?? Icons.category,
                    color: category.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              category.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: category.isActive
                                    ? Colors.black
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                          if (!category.isActive)
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
                      if (category.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          category.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  color: Colors.white,
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (action) => _handleMenuAction(action, category),
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
                            category.isActive ? Icons.delete : Icons.restore,
                            size: 16,
                            color:
                                category.isActive ? Colors.red : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(category.isActive ? 'Delete' : 'Restore',
                              style: TextStyle(
                                  color: category.isActive
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

            // Enhanced metrics with product items statistics
            Row(
              children: [
                _buildMetricChip(
                  '$productCount',
                  'Products',
                  totalItems > 0 ? Colors.purple : Colors.grey,
                  Icons.inventory_2,
                ),
                const SizedBox(width: 8),
                _buildMetricChip(
                  '$totalItems',
                  'Items',
                  totalItems > 0 ? Colors.purple : Colors.grey,
                  Icons.inventory_2,
                ),
                if (availableItems > 0) ...[
                  const SizedBox(width: 8),
                  _buildMetricChip(
                    '$availableItems',
                    'Available',
                    Colors.green,
                    Icons.check_circle,
                  ),
                ],
              ],
            ),
            // Show damaged and out of stock items if any
            if (damagedItems > 0 || outOfStockItems > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (damagedItems > 0) ...[
                    _buildMetricChip(
                      '$damagedItems',
                      'Damaged',
                      Colors.red,
                      Icons.error,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (outOfStockItems > 0) ...[
                    _buildMetricChip(
                      '$outOfStockItems',
                      'Out of Stock',
                      Colors.orange,
                      Icons.warning,
                    ),
                  ],
                ],
              ),
            ],

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Created: ${_formatDate(category.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                Text(
                  'Updated: ${_formatDate(category.updatedAt)}',
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

  void _handleMenuAction(String action, CategoryModel category) {
    switch (action) {
      case 'edit':
        _showCategoryFormDialog(category);
        break;
      case 'delete':
        _showDeleteConfirmation(category);
        break;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
