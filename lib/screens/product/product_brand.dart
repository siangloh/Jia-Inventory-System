import 'package:flutter/material.dart';
import 'dart:async';
import '../../dao/product_brand_dao.dart';
import '../../models/product_brand_model.dart';
import '../../services/statistics/product_brand_service.dart';

class ProductBrandManagementScreen extends StatefulWidget {
  const ProductBrandManagementScreen({super.key});

  @override
  State<ProductBrandManagementScreen> createState() =>
      _ProductBrandManagementScreenState();
}

class _ProductBrandManagementScreenState
    extends State<ProductBrandManagementScreen> {
  final _dao = ProductBrandDAO();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Statistics integration
  StreamSubscription<ProductBrandStatistics>? _statisticsSubscription;
  ProductBrandStatistics? _currentStatistics;

  // State variables
  List<ProductBrandModel> brands = [];
  List<ProductBrandModel> filteredBrands = [];
  bool isLoading = true;
  String? errorMessage;
  String searchQuery = '';
  String selectedBrandType = 'All';
  String selectedCountry = 'All';
  String selectedStatus = 'All';
  String sortBy = 'name';
  bool isAscending = true;

  // Filter options
  List<String> availableBrandTypes = [
    'All',
    'OEM',
    'Aftermarket',
    'Performance',
    'Economy',
    'Premium'
  ];
  List<String> availableCountries = ['All'];
  List<String> availableStatus = ['All', 'Active', 'Inactive', 'Unused'];

  // Common countries
  static const List<String> commonCountries = [
    'Japan',
    'Germany',
    'USA',
    'South Korea',
    'Italy',
    'France',
    'Sweden',
    'United Kingdom',
    'China',
    'India',
    'Taiwan',
    'Malaysia'
  ];

  @override
  void initState() {
    super.initState();
    _setupRealtimeUpdates();
    _setupStatisticsUpdates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _statisticsSubscription?.cancel();
    _dao.dispose();
    super.dispose();
  }

  void _setupStatisticsUpdates() {
    _statisticsSubscription =
        _dao.statisticsService.getProductBrandStatisticsStream().listen(
      (statistics) {
        print('Brand statistics updated: ${statistics.toString()}');
        setState(() {
          _currentStatistics = statistics;

          // Update usage counts in brands list
          brands = brands.map((brand) {
            final usageStats = statistics.usageStats[brand.brandName];
            if (usageStats != null) {
              return brand.copyWith(usageCount: usageStats.usageCount);
            }
            return brand.copyWith(usageCount: 0);
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

    _dao.brandsStream.listen(
      (brandsList) {
        print('Received ${brandsList.length} brands');

        final Set<String> countries = {'All'};
        for (var brand in brandsList) {
          if (brand.countryOfOrigin.isNotEmpty) {
            countries.add(brand.countryOfOrigin);
          }
        }

        setState(() {
          brands = brandsList;
          availableCountries = countries.toList()..sort();
          isLoading = false;
          errorMessage = null;
        });

        _applyFilters();
      },
      onError: (error) {
        print('Brands stream error: $error');
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load brands: $error';
        });
      },
    );
  }

  Future<void> _refreshBrands() async {
    setState(() => isLoading = true);
    // Statistics service handles refresh automatically
    setState(() => isLoading = false);
  }

  void _applyFilters() {
    List<ProductBrandModel> filtered = List.from(brands);

    // Search filter
    if (searchQuery.isNotEmpty) {
      filtered =
          filtered.where((brand) => brand.matchesSearch(searchQuery)).toList();
    }

    // Brand type filter
    if (selectedBrandType != 'All') {
      filtered = filtered
          .where((brand) => brand.brandTypeDisplayName == selectedBrandType)
          .toList();
    }

    // Country filter
    if (selectedCountry != 'All') {
      filtered = filtered
          .where((brand) => brand.countryOfOrigin == selectedCountry)
          .toList();
    }

    // Status filter
    if (selectedStatus != 'All') {
      if (selectedStatus == 'Active') {
        filtered = filtered.where((brand) => brand.isActive).toList();
      } else if (selectedStatus == 'Inactive') {
        filtered = filtered.where((brand) => !brand.isActive).toList();
      } else if (selectedStatus == 'Unused') {
        filtered = filtered.where((brand) => brand.usageCount == 0).toList();
      }
    }

    // Sort
    filtered.sort((a, b) {
      int comparison;
      switch (sortBy) {
        case 'name':
          comparison = a.brandName.compareTo(b.brandName);
          break;
        case 'type':
          comparison = a.brandTypeDisplayName.compareTo(b.brandTypeDisplayName);
          break;
        case 'country':
          comparison = a.countryOfOrigin.compareTo(b.countryOfOrigin);
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
          comparison = a.brandName.compareTo(b.brandName);
      }
      return isAscending ? comparison : -comparison;
    });

    setState(() => filteredBrands = filtered);
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    final color = backgroundColor ??
        (message.contains('success') ? Colors.green : Colors.red);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green
                  ? Icons.check_circle
                  : color == Colors.red
                      ? Icons.error
                      : Icons.info,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // CRUD Handlers
  Future<void> _createBrand(ProductBrandModel brand) async {
    final success = await _dao.createBrand(brand);
    if (success) {
      _showSnackBar('Brand created successfully!',
          backgroundColor: Colors.green);
    } else {
      _showSnackBar('Brand already exists', backgroundColor: Colors.orange);
    }
  }

  Future<void> _updateBrand(ProductBrandModel brand) async {
    final success = await _dao.updateBrand(brand);
    _showSnackBar(
      success ? 'Brand updated successfully!' : 'Failed to update brand',
      backgroundColor: success ? Colors.green : Colors.red,
    );
  }

  Future<void> _deleteBrand(ProductBrandModel brand) async {
    // Use the statistics service to check usage count
    final usageCount =
        await _dao.statisticsService.getBrandUsageCount(brand.brandName);

    if (usageCount > 0) {
      _showSnackBar(
        'Cannot delete brand used by $usageCount products. Update those products first.',
        backgroundColor: Colors.red,
      );
      return;
    }

    final success = await _dao.toggleBrandStatus(brand.id!, brand.isActive);
    if (success) {
      _showSnackBar(
          'Brand ${brand.isActive ? 'deleted' : 'restored'} successfully!',
          backgroundColor: Colors.green);
    } else {
      _showSnackBar('Failed to delete brand', backgroundColor: Colors.red);
    }
  }

  void _showAddBrandDialog() => _showBrandFormDialog(null);

  void _showEditBrandDialog(ProductBrandModel brand) =>
      _showBrandFormDialog(brand);

  void _showBrandFormDialog(ProductBrandModel? brand) {
    final isEditing = brand != null;
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(text: brand?.brandName ?? '');
    final descriptionController =
        TextEditingController(text: brand?.description ?? '');
    final countryController =
        TextEditingController(text: brand?.countryOfOrigin ?? '');

    BrandType selectedBrandType = brand?.brandType ?? BrandType.AFTERMARKET;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(isEditing ? 'Edit Brand' : 'Add New Brand'),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Brand Name *',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Toyota, Bosch',
                      ),
                      validator: (value) => value?.isEmpty ?? true
                          ? 'Please enter brand name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        hintText: 'Brief description of the brand (optional)',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<BrandType>(
                            dropdownColor: Colors.white,
                            value: selectedBrandType,
                            decoration: const InputDecoration(
                              labelText: 'Brand Type *',
                              border: OutlineInputBorder(),
                            ),
                            items: BrandType.values
                                .map((type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type.name,
                                          style: const TextStyle(fontSize: 12)),
                                    ))
                                .toList(),
                            onChanged: (value) => setDialogState(
                                () => selectedBrandType = value!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            dropdownColor: Colors.white,
                            value: countryController.text.isEmpty
                                ? null
                                : countryController.text,
                            decoration: const InputDecoration(
                              labelText: 'Country of Origin',
                              border: OutlineInputBorder(),
                            ),
                            items: ['', ...commonCountries]
                                .map((country) => DropdownMenuItem(
                                      value: country,
                                      child: Text(
                                          country.isEmpty
                                              ? 'Select Country'
                                              : country,
                                          style: const TextStyle(fontSize: 12)),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                countryController.text = value ?? '',
                          ),
                        ),
                      ],
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
                  final newBrand = ProductBrandModel(
                    id: brand?.id,
                    brandName: nameController.text.trim(),
                    description: descriptionController.text.trim(),
                    countryOfOrigin: countryController.text.trim(),
                    brandType: selectedBrandType,
                    isActive: brand?.isActive ?? true,
                    usageCount: brand?.usageCount ?? 0,
                    createdAt: brand?.createdAt ?? now,
                    updatedAt: now,
                    createdBy: brand?.createdBy ?? 'current_user',
                  );

                  Navigator.pop(context);
                  if (isEditing) {
                    _updateBrand(newBrand);
                  } else {
                    _createBrand(newBrand);
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

  void _showDeleteConfirmation(ProductBrandModel brand) {
    // Get usage count from the current statistics
    final usageStats = _currentStatistics?.usageStats[brand.brandName];
    final usageCount = usageStats?.usageCount ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('${brand.isActive ? 'Delete' : 'Restore'} Brand'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Are you sure you want to ${brand.isActive ? 'delete' : 'restore'} "${brand.brandName}"?'),
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
                        'This brand is used by $usageCount products. You cannot delete it until all products are updated.',
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
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
                _deleteBrand(brand);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(brand.isActive ? 'Delete' : 'Restore',
                  style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  // void _showStatisticsDialog() {
  //   if (_currentStatistics == null) return;
  //
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Brand Statistics'),
  //       content: SizedBox(
  //         width: double.maxFinite,
  //         child: SingleChildScrollView(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               _buildStatisticsSection('Overall Statistics', [
  //                 'Total Brands: ${_currentStatistics!.totalBrands}',
  //                 'Active Brands: ${_currentStatistics!.activeBrands}',
  //                 'Inactive Brands: ${_currentStatistics!.inactiveBrands}',
  //                 'Unused Brands: ${_currentStatistics!.unusedBrands}',
  //               ]),
  //               const SizedBox(height: 16),
  //               _buildStatisticsSection(
  //                 'Brand Type Breakdown',
  //                 _currentStatistics!.brandTypeStats.values
  //                     .map((stat) =>
  //                         '${stat.brandType.name}: ${stat.totalBrands} brands (${stat.totalUsageCount} total usage)')
  //                     .toList(),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('Close'),
  //         ),
  //         ElevatedButton(
  //           onPressed: () {
  //             Navigator.pop(context);
  //             _showUnusedBrandsDialog();
  //           },
  //           child: const Text('View Unused Brands'),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  //
  // Widget _buildStatisticsSection(String title, List<String> items) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         title,
  //         style: const TextStyle(
  //           fontSize: 16,
  //           fontWeight: FontWeight.bold,
  //         ),
  //       ),
  //       const SizedBox(height: 8),
  //       ...items.map((item) => Padding(
  //             padding: const EdgeInsets.only(left: 16, bottom: 4),
  //             child: Text('• $item'),
  //           )),
  //     ],
  //   );
  // }

  // void _showUnusedBrandsDialog() {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Unused Brands'),
  //       content: SizedBox(
  //         width: double.maxFinite,
  //         height: 400,
  //         child: FutureBuilder<List<ProductBrandUsageStats>>(
  //           future: _dao.statisticsService.getUnusedBrands(),
  //           builder: (context, snapshot) {
  //             if (snapshot.connectionState == ConnectionState.waiting) {
  //               return const Center(child: CircularProgressIndicator());
  //             }
  //
  //             if (snapshot.hasError) {
  //               return Text('Error: ${snapshot.error}');
  //             }
  //
  //             final unusedBrands = snapshot.data ?? [];
  //
  //             if (unusedBrands.isEmpty) {
  //               return const Center(
  //                 child: Text('No unused brands found!'),
  //               );
  //             }
  //
  //             return ListView.builder(
  //               itemCount: unusedBrands.length,
  //               itemBuilder: (context, index) {
  //                 final unusedBrand = unusedBrands[index];
  //                 return ListTile(
  //                   title: Text(unusedBrand.brandName),
  //                   subtitle: Text('Type: ${unusedBrand.brandType.name}'),
  //                   trailing: Row(
  //                     mainAxisSize: MainAxisSize.min,
  //                     children: [
  //                       if (!unusedBrand.isActive)
  //                         const Icon(Icons.warning,
  //                             color: Colors.orange, size: 16),
  //                       PopupMenuButton<String>(
  //                         onSelected: (action) {
  //                           Navigator.pop(context);
  //                           if (action == 'delete') {
  //                             _deleteBrand(
  //                                 unusedBrand.brandId, unusedBrand.brandName);
  //                           }
  //                         },
  //                         itemBuilder: (context) => [
  //                           const PopupMenuItem(
  //                             value: 'delete',
  //                             child: Row(
  //                               children: [
  //                                 Icon(Icons.delete,
  //                                     size: 16, color: Colors.red),
  //                                 SizedBox(width: 8),
  //                                 Text('Delete'),
  //                               ],
  //                             ),
  //                           ),
  //                         ],
  //                       ),
  //                     ],
  //                   ),
  //                 );
  //               },
  //             );
  //           },
  //         ),
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('Close'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  void _handleMenuAction(String action, ProductBrandModel brand) {
    switch (action) {
      case 'edit':
        _showEditBrandDialog(brand);
        break;
      case 'delete':
        _showDeleteConfirmation(brand);
        break;
    }
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
                      child: filteredBrands.isEmpty
                          ? _buildEmptyState()
                          : _buildBrandsList(),
                    ),
                  ],
                ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Optional: Add statistics button
          if (_currentStatistics?.unusedBrands != null &&
              _currentStatistics!.unusedBrands > 0)
            // FloatingActionButton.small(
            //   // onPressed: () => _showUnusedBrandsDialog(),
            //   backgroundColor: Colors.orange,
            //   tooltip:
            //       'View Unused Brands (${_currentStatistics!.unusedBrands})',
            //   heroTag: 'unused_brands',
            //   child: const Icon(Icons.warning, color: Colors.white),
            // ),
            const SizedBox(height: 8),
          FloatingActionButton(
            onPressed: _showAddBrandDialog,
            backgroundColor: Colors.orange[600],
            tooltip: 'Add New Brand',
            heroTag: 'add_brand',
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // UI Builder Methods
  Widget _buildLoadingScreen() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading brands...',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );

  Widget _buildErrorScreen() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text('Error Loading Brands',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  )),
              const SizedBox(height: 8),
              Text(errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  )),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _refreshBrands,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

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
          )
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
                    hintText: 'Search brands, types, countries...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => searchQuery = '');
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
                    setState(() => searchQuery = value);
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
              Expanded(child: _buildBrandTypeFilter()),
              const SizedBox(width: 8),
              Expanded(child: _buildCountryFilter()),
              const SizedBox(width: 8),
              Expanded(child: _buildStatusFilter()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrandTypeFilter() => DropdownButtonFormField<String>(
        value: selectedBrandType,
        dropdownColor: Colors.white,
        decoration: InputDecoration(
          labelText: 'Brand Type',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: availableBrandTypes
            .map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type, style: const TextStyle(fontSize: 12)),
                ))
            .toList(),
        onChanged: (value) {
          setState(() => selectedBrandType = value!);
          _applyFilters();
        },
      );

  Widget _buildCountryFilter() => DropdownButtonFormField<String>(
        dropdownColor: Colors.white,
        value: selectedCountry,
        decoration: InputDecoration(
          labelText: 'Country',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: availableCountries
            .map((country) => DropdownMenuItem(
                  value: country,
                  child: Text(country, style: const TextStyle(fontSize: 12)),
                ))
            .toList(),
        onChanged: (value) {
          setState(() => selectedCountry = value!);
          _applyFilters();
        },
      );

  Widget _buildStatusFilter() => DropdownButtonFormField<String>(
        dropdownColor: Colors.white,
        value: selectedStatus,
        decoration: InputDecoration(
          labelText: 'Status',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: availableStatus
            .map((status) => DropdownMenuItem(
                  value: status,
                  child: Text(status, style: const TextStyle(fontSize: 12)),
                ))
            .toList(),
        onChanged: (value) {
          setState(() => selectedStatus = value!);
          _applyFilters();
        },
      );

  Widget _buildSortButton() => PopupMenuButton<String>(
        icon: const Icon(Icons.sort, size: 20),
        color: Colors.white,
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
          _buildSortMenuItem('name', 'Brand Name', Icons.text_fields),
          _buildSortMenuItem('type', 'Brand Type', Icons.category),
          _buildSortMenuItem('country', 'Country', Icons.flag),
          _buildSortMenuItem('usage', 'Usage Count', Icons.trending_up),
          _buildSortMenuItem('created', 'Created Date', Icons.schedule),
          _buildSortMenuItem('updated', 'Updated Date', Icons.update),
        ],
      );

  PopupMenuItem<String> _buildSortMenuItem(
          String value, String label, IconData icon) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
            if (sortBy == value)
              Icon(
                isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
              ),
          ],
        ),
      );

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

    final total = filteredBrands.length;
    final active = filteredBrands.where((b) => b.isActive).length;
    final inactive = filteredBrands.where((b) => !b.isActive).length;
    final unused = filteredBrands.where((b) => b.usageCount == 0 && b.isActive).length;

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
              _buildStatChip('$total total', Colors.orange),
              _buildStatChip('$active active', Colors.blue),
              if (inactive > 0)
                _buildStatChip('$inactive inactive', Colors.red),
              if (unused > 0) _buildStatChip('$unused unused', Colors.grey),
            ],
          ),
          const SizedBox(height: 8),
          // Usage efficiency
          // FutureBuilder<double>(
          //   future: _dao.statisticsService.getUsageEfficiency(),
          //   builder: (context, snapshot) {
          //     if (snapshot.hasData) {
          //       final efficiency = snapshot.data!;
          //       return Container(
          //         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          //         decoration: BoxDecoration(
          //           color: efficiency >= 80 ? Colors.green.withOpacity(0.1) :
          //           efficiency >= 60 ? Colors.orange.withOpacity(0.1) :
          //           Colors.red.withOpacity(0.1),
          //           borderRadius: BorderRadius.circular(6),
          //           border: Border.all(
          //             color: efficiency >= 80 ? Colors.green.withOpacity(0.3) :
          //             efficiency >= 60 ? Colors.orange.withOpacity(0.3) :
          //             Colors.red.withOpacity(0.3),
          //           ),
          //         ),
          //         child: Row(
          //           mainAxisSize: MainAxisSize.min,
          //           children: [
          //             Icon(
          //               Icons.analytics,
          //               size: 14,
          //               color: efficiency >= 80 ? Colors.green :
          //               efficiency >= 60 ? Colors.orange : Colors.red,
          //             ),
          //             const SizedBox(width: 4),
          //             Text(
          //               'Usage Efficiency: ${efficiency.toStringAsFixed(1)}%',
          //               style: TextStyle(
          //                 fontSize: 12,
          //                 fontWeight: FontWeight.w500,
          //                 color: efficiency >= 80 ? Colors.green :
          //                 efficiency >= 60 ? Colors.orange : Colors.red,
          //               ),
          //             ),
          //           ],
          //         ),
          //       );
          //     }
          //     return const SizedBox.shrink();
          //   },
          // ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            )),
      );

  Widget _buildEmptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.business, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 24),
              Text('No Brands Found',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  )),
              const SizedBox(height: 8),
              Text(
                searchQuery.isNotEmpty
                    ? 'No brands match your search criteria'
                    : 'No brands created yet',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showAddBrandDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create First Brand'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                ),
              ),
              if (searchQuery.isNotEmpty || selectedBrandType != 'All') ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      searchQuery = '';
                      selectedBrandType = 'All';
                      selectedCountry = 'All';
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

  Widget _buildBrandsList() => RefreshIndicator(
        onRefresh: _refreshBrands,
        backgroundColor: Colors.white,
        color: Colors.blue,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: filteredBrands.length,
          itemBuilder: (context, index) =>
              _buildBrandCard(filteredBrands[index]),
        ),
      );

  Widget _buildBrandCard(ProductBrandModel brand) {
    // Get usage stats from the current statistics
    final usageStats = _currentStatistics?.usageStats[brand.brandName];
    final usageCount = usageStats?.usageCount ?? 0;
    final itemCount = usageStats?.itemCount ?? 0;
    final isUnused = usageCount == 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: brand.isActive
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: brand.brandTypeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.business,
                      color: brand.brandTypeColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(brand.brandName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: brand.isActive
                                      ? Colors.black
                                      : Colors.grey[600],
                                )),
                          ),
                          if (!brand.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Text('INACTIVE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[700],
                                  )),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: brand.brandTypeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: brand.brandTypeColor.withOpacity(0.3)),
                            ),
                            child: Text(brand.brandTypeDisplayName,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: brand.brandTypeColor,
                                )),
                          ),
                          if (brand.countryOfOrigin.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(brand.countryOfOrigin,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                )),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  color: Colors.white,
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (action) => _handleMenuAction(action, brand),
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
                          Icon(brand.isActive ? Icons.delete : Icons.restore,
                              size: 16,
                              color:
                                  brand.isActive ? Colors.red : Colors.green),
                          const SizedBox(width: 8),
                          Text(brand.isActive ? 'Delete' : 'Restore',
                              style: TextStyle(
                                  color: brand.isActive
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

            if (brand.description.isNotEmpty) ...[
              Text(brand.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
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

            Row(
              children: [
                Expanded(
                  child: Text('Created: ${_formatDate(brand.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      )),
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
          String value, String label, Color color, IconData icon) =>
      Container(
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
                Text(value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    )),
                Text(label, style: TextStyle(fontSize: 9, color: color)),
              ],
            ),
          ],
        ),
      );

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
