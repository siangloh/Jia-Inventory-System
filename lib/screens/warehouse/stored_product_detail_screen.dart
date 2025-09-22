// lib/screens/warehouse/stored_product_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:assignment/models/warehouse_location.dart';
import 'package:assignment/screens/warehouse/warehouse_inventory_screen.dart';
import 'package:assignment/screens/warehouse/warehouse_map_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:assignment/widgets/qr/qr_generator_dialog.dart';
import 'package:assignment/widgets/qr/qr_scanner_dialog.dart';
import 'package:assignment/dao/product_brand_dao.dart';
import 'package:assignment/dao/product_category_dao.dart';
import 'package:assignment/dao/product_name_dao.dart';
import 'dart:async';

import 'package:assignment/models/stored_product_model.dart';
import 'package:assignment/models/po_supplier_info_model.dart';

class StoredProductDetailScreen extends StatefulWidget {
  final String productId; // Change from StoredProduct to just productId
  final String initialProductName; // For initial app bar title

  const StoredProductDetailScreen({
    super.key,
    required this.productId,
    required this.initialProductName,
  });

  @override
  State<StoredProductDetailScreen> createState() =>
      _StoredProductDetailScreenState();
}

class _StoredProductDetailScreenState extends State<StoredProductDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // Real-time data
  StoredProduct? storedProduct;
  Map<String, dynamic>? productData;
  List<WarehouseLocation> warehouseLocations = [];

  Timer? _errorDelayTimer;
  bool _hasShownInitialData = false;

  // Loading states
  bool isLoading = true;
  String? errorMessage;

  // Real-time subscriptions
  StreamSubscription<DocumentSnapshot>? _productSubscription;
  StreamSubscription<QuerySnapshot>? _warehouseSubscription;

  final ProductBrandDAO _brandDao = ProductBrandDAO();
  final CategoryDao _categoryDao = CategoryDao();
  final ProductNameDao _productNameDao = ProductNameDao();

  final Map<String, String> _productNameCache = {};
  final Map<String, String> _categoryNameCache = {};
  final Map<String, String> _brandNameCache = {};


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _setupRealtimeUpdates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _productSubscription?.cancel();
    _warehouseSubscription?.cancel();
    _errorDelayTimer?.cancel();
    _productNameCache.clear();
    _categoryNameCache.clear();
    _brandNameCache.clear();
    super.dispose();
  }


  Future<String> _resolveProductName(String? productNameId) async {
    if (productNameId == null || productNameId.isEmpty) return 'Unknown Product';

    // Check cache first
    if (_productNameCache.containsKey(productNameId)) {
      return _productNameCache[productNameId]!;
    }

    try {
      final productNameModel = await _productNameDao.getProductNameById(productNameId);
      final name = productNameModel?.productName ?? 'Unknown Product';
      _productNameCache[productNameId] = name;
      return name;
    } catch (e) {
      print('Error resolving product name ID $productNameId: $e');
      return 'Unknown Product';
    }
  }

  Future<String> _resolveCategoryName(String? categoryId) async {
    if (categoryId == null || categoryId.isEmpty) return 'Unknown Category';

    // Check cache first
    if (_categoryNameCache.containsKey(categoryId)) {
      return _categoryNameCache[categoryId]!;
    }

    try {
      final categoryModel = await _categoryDao.getCategoryById(categoryId);
      final name = categoryModel?.name ?? 'Unknown Category';
      _categoryNameCache[categoryId] = name;
      return name;
    } catch (e) {
      print('Error resolving category ID $categoryId: $e');
      return 'Unknown Category';
    }
  }

  Future<String> _resolveBrandName(String? brandId) async {
    if (brandId == null || brandId.isEmpty) return 'Unknown Brand';

    if (_brandNameCache.containsKey(brandId)) {
      return _brandNameCache[brandId]!;
    }

    try {
      final brandModel = await _brandDao.getBrandById(brandId);
      final name = brandModel?.brandName ?? 'Unknown Brand';
      _brandNameCache[brandId] = name;
      return name;
    } catch (e) {
      print('Error resolving brand ID $brandId: $e');
      return 'Unknown Brand';
    }
  }

  void _setupRealtimeUpdates() {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    // Listen to specific product document
    _setupProductListener();

    // Listen to warehouse locations for this product
    _setupWarehouseListener();
  }

  void _setupProductListener() {
    _productSubscription = FirebaseFirestore.instance
        .collection('products')
        .doc(widget.productId)
        .snapshots()
        .listen(
          (snapshot) {
        print('Product data changed for ${widget.productId}');

        if (snapshot.exists) {
          productData = snapshot.data();
          print('Product data updated: ${productData?['productName']}');

          // Clear any pending error timers since we got data
          _errorDelayTimer?.cancel();

          // Clear error state if we successfully got data
          if (errorMessage != null) {
            setState(() {
              errorMessage = null;
            });
          }

          _hasShownInitialData = true;
        } else {
          productData = null;
          print('Product document not found');
        }

        _combineData();
      },
      onError: (error) {
        print('Product listener error: $error');

        // Only show error after initial load attempts
        if (_hasShownInitialData) {
          setState(() {
            errorMessage = 'Failed to load product details: $error';
          });
        } else {
          // Delay error display for initial load
          _scheduleErrorDisplay('Failed to load product details: $error');
        }
      },
    );
  }

  void _setupWarehouseListener() {
    _warehouseSubscription = FirebaseFirestore.instance
        .collection('warehouseLocations')
        .where('productId', isEqualTo: widget.productId)
        .where('isOccupied', isEqualTo: true)
        .snapshots()
        .listen(
          (snapshot) {
        print('Warehouse locations changed for ${widget.productId}: ${snapshot.docs.length} locations');

        warehouseLocations = snapshot.docs
            .map((doc) {
          try {
            return WarehouseLocation.fromFirestore(doc.data());
          } catch (e) {
            print('Error converting warehouse location ${doc.id}: $e');
            return null;
          }
        })
            .where((location) => location != null)
            .cast<WarehouseLocation>()
            .toList();

        print('Successfully converted ${warehouseLocations.length} locations');

        // Clear any pending error timers since we got data
        _errorDelayTimer?.cancel();

        // Clear error state if we successfully got data
        if (errorMessage != null) {
          setState(() {
            errorMessage = null;
          });
        }

        _hasShownInitialData = true;
        _combineData();
      },
      onError: (error) {
        print('Warehouse listener error: $error');

        // Only show error after initial load attempts
        if (_hasShownInitialData) {
          setState(() {
            errorMessage = 'Failed to load warehouse data: $error';
          });
        } else {
          // Delay error display for initial load
          _scheduleErrorDisplay('Failed to load warehouse data: $error');
        }
      },
    );
  }

  void _scheduleErrorDisplay(String error) {
    _errorDelayTimer?.cancel();

    _errorDelayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_hasShownInitialData) {
        setState(() {
          errorMessage = error;
          isLoading = false;
        });
      }
    });
  }

  Future<void> _combineData() async {
    try {
      print(
          'Combining data: productData=${productData != null}, locations=${warehouseLocations.length}');

      if (productData == null) {
        print('Product data not available yet, waiting...');
        return;
      }

      if (warehouseLocations.isEmpty) {
        print('No warehouse locations found for this product');
        setState(() {
          storedProduct = null;
          isLoading = false;
          errorMessage = 'This product is no longer stored in the warehouse';
        });
        return;
      }

      // Calculate warehouse-derived data
      final totalQuantity = warehouseLocations.fold<int>(
          0, (sum, loc) => sum + (loc.quantityStored ?? 0));

      // Get actual POs from ProductItems
      final poNumbersAndSuppliers = await _getActualPOsFromProductItems(
          widget.productId, warehouseLocations);
      final purchaseOrderNumbers = poNumbersAndSuppliers.poNumbers;
      final supplierNames = poNumbersAndSuppliers.supplierNames;

      print(
          '🔍 Product ${widget.productId} found actual PO numbers: ${purchaseOrderNumbers.toList()}');
      print(
          '🔍 Product ${widget.productId} found suppliers: ${supplierNames.toList()}');

      // Get dates
      final occupiedDates = warehouseLocations
          .where((loc) => loc.occupiedDate != null)
          .map((loc) => loc.occupiedDate!)
          .toList();
      occupiedDates.sort();

      // UPDATED: Resolve IDs to display names
      final productName = await _resolveProductName(
          productData!['name'] ?? productData!['productName']
      );
      final categoryName = await _resolveCategoryName(
          productData!['category']
      );
      final brandName = await _resolveBrandName(
          productData!['brand']
      );

      // Create combined StoredProduct with resolved names
      final combinedProduct = StoredProduct(
        productId: widget.productId,
        // UPDATED: Use resolved names instead of IDs
        productName: productName,
        partNumber: productData!['partNumber'] ?? productData!['sku'] ?? 'N/A',
        category: categoryName,
        productBrand: brandName.isNotEmpty ? brandName : null,
        productDescription: productData!['description'],
        unitPrice:
        (productData!['unitPrice'] ?? productData!['price'])?.toDouble(),
        // Warehouse-derived data
        totalQuantityStored: totalQuantity,
        locations: warehouseLocations,
        firstStoredDate: occupiedDates.isNotEmpty ? occupiedDates.first : null,
        lastStoredDate: occupiedDates.isNotEmpty ? occupiedDates.last : null,
        purchaseOrderNumbers: purchaseOrderNumbers,
        supplierNames: supplierNames,
      );

      setState(() {
        storedProduct = combinedProduct;
        isLoading = false;
        errorMessage = null;
      });

      print('Successfully combined data for ${combinedProduct.productName}');
    } catch (e) {
      print('Error combining data: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to process product data: $e';
      });
    }
  }


  Future<POAndSupplierInfo> _getActualPOsFromProductItems(
      String productId, List<WarehouseLocation> locations) async {
    try {
      final Set<String> poNumbers = {};
      final Set<String> supplierNames = {};

      // Get all location IDs for this product
      final locationIds = locations.map((loc) => loc.locationId).toList();

      // Query ProductItems that are at these locations for this product
      final snapshot = await FirebaseFirestore.instance
          .collection('productItems')
          .where('productId', isEqualTo: productId)
          .where('location', whereIn: locationIds)
          .where('status', isEqualTo: 'stored') // Only stored items
          .get();

      print(
          '🔍 Found ${snapshot.docs.length} ProductItems for product $productId at locations $locationIds');

      // Collect unique PO IDs from ProductItems
      final Set<String> actualPOIds = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final poId = data['purchaseOrderId'] as String?;
        if (poId != null && poId.isNotEmpty) {
          actualPOIds.add(poId);
        }
      }

      print(
          '🔍 Found actual PO IDs from ProductItems: ${actualPOIds.toList()}');

      // Get PO numbers and supplier names for each unique PO ID
      for (final poId in actualPOIds) {
        try {
          final poDoc = await FirebaseFirestore.instance
              .collection('purchaseOrder')
              .doc(poId)
              .get();

          if (poDoc.exists) {
            final poData = poDoc.data() as Map<String, dynamic>;
            final poNumber = poData['poNumber'] as String?;
            final supplierName = poData['supplierName'] as String?;

            if (poNumber != null && poNumber.isNotEmpty) {
              poNumbers.add(poNumber);
            }
            if (supplierName != null && supplierName.isNotEmpty) {
              supplierNames.add(supplierName);
            }

            print('🔍 PO $poId -> Number: $poNumber, Supplier: $supplierName');
          }
        } catch (e) {
          print('Error fetching PO $poId: $e');
        }
      }

      return POAndSupplierInfo(
        poNumbers: poNumbers,
        supplierNames: supplierNames,
      );
    } catch (e) {
      print('Error getting actual POs from ProductItems: $e');
      // Fallback to metadata approach if ProductItems query fails
      return _getFallbackPOsFromMetadata(locations);
    }
  }

// 🆕 NEW: Fallback method using metadata (more conservative)
  POAndSupplierInfo _getFallbackPOsFromMetadata(
      List<WarehouseLocation> locations) {
    final Set<String> allPONumbers = {};
    final Set<String> allSupplierNames = {};

    for (final location in locations) {
      // Only get primary PO number (most reliable)
      final poNumber = location.metadata?['poNumber'] as String?;
      if (poNumber != null && poNumber.isNotEmpty) {
        allPONumbers.add(poNumber);
      }

      // Only get primary supplier name
      final supplierName = location.metadata?['supplierName'] as String?;
      if (supplierName != null && supplierName.isNotEmpty) {
        allSupplierNames.add(supplierName);
      }
    }

    return POAndSupplierInfo(
      poNumbers: allPONumbers,
      supplierNames: allSupplierNames,
    );
  }

  Future<void> _refreshData() async {
    // Cancel and restart subscriptions
    await _productSubscription?.cancel();
    await _warehouseSubscription?.cancel();
    _setupRealtimeUpdates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          storedProduct?.productName ?? widget.initialProductName,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: storedProduct != null
            ? TabBar(
                controller: _tabController,
                labelColor: Colors.blue[700],
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: Colors.blue[700],
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Locations'),
                  Tab(text: 'History'),
                  Tab(text: 'Analytics'),
                  Tab(text: 'Map'),
                ],
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return _buildLoadingScreen();
    }

    if (errorMessage != null) {
      return _buildErrorScreen();
    }

    if (storedProduct == null) {
      return _buildEmptyState();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildLocationsTab(),
        _buildHistoryTab(),
        _buildAnalyticsTab(),
        _buildMapTab(),
      ],
    );
  }

  Widget _buildMapTab() {
    return Column(
      children: [
        // Product locations header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            border: Border(bottom: BorderSide(color: Colors.blue[200]!)),
          ),
          child: Row(
            children: [
              Icon(Icons.map, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Product Locations for ${storedProduct!.productName}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${storedProduct!.locations.length} locations',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[800],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Embedded warehouse map
        Expanded(
          child: WarehouseMapScreen(
            productLocations: storedProduct!.locations,
            productName: storedProduct!.productName,
          ),
        ),
      ],
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
            'Loading product details...',
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
              'Error Loading Product',
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
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
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
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'Product Not in Warehouse',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This product is currently not stored in any warehouse location',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Inventory'),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProductSummaryCard(),
          const SizedBox(height: 16),
          _buildQRCodeCard(),
          const SizedBox(height: 16),
          _buildQuantityBreakdownCard(),
          const SizedBox(height: 16),
          _buildSupplierInfoCard(),
          const SizedBox(height: 16),
          _buildStorageTimelineCard(),
        ],
      ),
    );
  }

  Widget _buildQRCodeCard() {
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.qr_code,
                    color: Colors.purple[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Product QR Code',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Generate and share QR code for quick product identification',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // QR Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => QRGeneratorDialog(
                          productId: storedProduct!.productId,
                          productName: storedProduct!.productName,
                          category: storedProduct!.category,
                          quantity: storedProduct!.totalQuantityStored,
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code, size: 20),
                    label: const Text('Generate QR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLocationSummaryCard(),
          const SizedBox(height: 16),
          _buildLocationListCard(),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final sortedLocations =
        List<WarehouseLocation>.from(storedProduct!.locations);
    sortedLocations.sort((a, b) {
      final aDate = a.occupiedDate ?? DateTime(1970);
      final bDate = b.occupiedDate ?? DateTime(1970);
      return bDate.compareTo(aDate); // Most recent first
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Storage History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...sortedLocations.asMap().entries.map((entry) {
              final index = entry.key;
              final location = entry.value;
              final isLast = index == sortedLocations.length - 1;

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: isLast
                        ? BorderSide.none
                        : BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.history,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Stored at ${location.locationId}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Quantity: ${location.quantityStored ?? 0}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (location.metadata?['poNumber'] != null)
                              Text(
                                'From PO: ${location.metadata!['poNumber']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (location.occupiedDate != null) ...[
                            Text(
                              _formatDate(location.occupiedDate!),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              _formatTime(location.occupiedDate!),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalyticsOverviewCard(),
          const SizedBox(height: 16),
          _buildStorageEfficiencyCard(),
        ],
      ),
    );
  }

  Widget _buildProductSummaryCard() {
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.inventory,
                    color: Colors.blue[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storedProduct?.productName ?? widget.initialProductName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(storedProduct!.category)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _getCategoryColor(storedProduct!.category)
                                .withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          storedProduct!.category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getCategoryColor(storedProduct!.category),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Key metrics
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Total Quantity',
                    '${storedProduct!.totalQuantityStored}',
                    Icons.inventory_2,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Storage Locations',
                    '${storedProduct!.locations.length}',
                    Icons.location_on,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Purchase Orders',
                    '${storedProduct!.purchaseOrderNumbers.length}',
                    Icons.receipt,
                    Colors.purple,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Suppliers',
                    '${storedProduct!.supplierNames.length}',
                    Icons.business,
                    Colors.orange,
                  ),
                ),
              ],
            ),

            if (storedProduct!.unitPrice != null) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.attach_money,
                            color: Colors.green[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Value Information',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unit Price: RM ${storedProduct!.unitPrice!.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Total Value: RM ${(storedProduct!.unitPrice! * storedProduct!.totalQuantityStored).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityBreakdownCard() {
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
            Row(
              children: [
                Icon(Icons.pie_chart, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Quantity Breakdown by Zone',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Group by zones
            ...(_getQuantityByZone().entries.map((entry) {
              final zone = entry.key;
              final quantity = entry.value;
              final percentage =
                  (quantity / storedProduct!.totalQuantityStored * 100);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getZoneColor(zone),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _getZoneName(zone),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          '$quantity (${percentage.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(_getZoneColor(zone)),
                    ),
                  ],
                ),
              );
            }).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierInfoCard() {
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
            Row(
              children: [
                Icon(Icons.business, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Supplier Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...storedProduct!.supplierNames.map((supplier) {
              final supplierPOs = _getPOsForSupplier(supplier);
              final supplierQuantity = _getQuantityForSupplier(supplier);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            supplier,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Qty: $supplierQuantity',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: supplierPOs.map((po) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            po,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange[800],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageTimelineCard() {
    if (storedProduct!.firstStoredDate == null &&
        storedProduct!.lastStoredDate == null) {
      return const SizedBox.shrink();
    }

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
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Storage Timeline',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (storedProduct!.firstStoredDate != null)
              _buildTimelineItem(
                'First Stored',
                storedProduct!.firstStoredDate!,
                Icons.first_page,
                Colors.green,
              ),
            if (storedProduct!.lastStoredDate != null)
              _buildTimelineItem(
                'Last Stored',
                storedProduct!.lastStoredDate!,
                Icons.last_page,
                Colors.blue,
              ),
            if (storedProduct!.firstStoredDate != null &&
                storedProduct!.lastStoredDate != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timelapse, color: Colors.grey[600], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Storage Period: ${_calculateDaysBetween(storedProduct!.firstStoredDate!, storedProduct!.lastStoredDate!)} days',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSummaryCard() {
    final zoneGroups = <String, List<WarehouseLocation>>{};
    for (final location in storedProduct!.locations) {
      zoneGroups.putIfAbsent(location.zoneId, () => []).add(location);
    }

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
            const Text(
              'Location Distribution',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...zoneGroups.entries.map((entry) {
              final zone = entry.key;
              final locations = entry.value;
              final totalQty = locations.fold<int>(
                  0, (sum, loc) => sum + (loc.quantityStored ?? 0));

              return InkWell(
                // ← Changed from Container to InkWell
                onTap: () {
                  // Switch to Map tab (index 4)
                  _tabController.animateTo(4);
                },
                borderRadius: BorderRadius.circular(8), // For ripple effect
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getZoneColor(zone).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: _getZoneColor(zone).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getZoneColor(zone),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            zone,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getZoneName(zone),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${locations.length} locations • $totalQty items',
                              style: TextStyle(
                                fontSize: 12,
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
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationListCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'All Storage Locations',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...storedProduct!.locations.asMap().entries.map((entry) {
            final index = entry.key;
            final location = entry.value;
            final isLast = index == storedProduct!.locations.length - 1;

            return Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: isLast
                      ? BorderSide.none
                      : BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getZoneColor(location.zoneId).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _getZoneColor(location.zoneId).withOpacity(0.3)),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.location_on,
                      color: _getZoneColor(location.zoneId),
                      size: 20,
                    ),
                  ),
                ),
                title: Text(
                  location.locationId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quantity: ${location.quantityStored ?? 0}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (location.metadata?['poNumber'] != null)
                      Text(
                        'PO: ${location.metadata!['poNumber']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (location.occupiedDate != null)
                      Text(
                        _formatDate(location.occupiedDate!),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getZoneColor(location.zoneId).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        location.zoneId,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getZoneColor(location.zoneId),
                        ),
                      ),
                    ),
                  ],
                ),
                onTap: () => _showLocationDetails(location),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsOverviewCard() {
    final avgQuantityPerLocation =
        storedProduct!.totalQuantityStored / storedProduct!.locations.length;
    final zonesUsed =
        storedProduct!.locations.map((l) => l.zoneId).toSet().length;

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
            const Text(
              'Storage Analytics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAnalyticsMetric(
                    'Avg per Location',
                    avgQuantityPerLocation.toStringAsFixed(1),
                    Icons.analytics,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildAnalyticsMetric(
                    'Zones Used',
                    '$zonesUsed/6',
                    Icons.map,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildAnalyticsMetric(
                    'Storage Efficiency',
                    '${(zonesUsed / 6 * 100).toStringAsFixed(0)}%',
                    Icons.speed,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildAnalyticsMetric(
                    'Distribution Score',
                    _calculateDistributionScore(),
                    Icons.scatter_plot,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageEfficiencyCard() {
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
            Row(
              children: [
                Icon(Icons.insights, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Storage Insights',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._getStorageInsights().map((insight) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: insight['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: insight['color'].withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      insight['icon'],
                      color: insight['color'],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        insight['text'],
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // Helper widgets
  Widget _buildMetricItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
      String label, DateTime date, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDate(date),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                _formatTime(date),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsMetric(
      String label, String value, IconData icon, Color color) {
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
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper methods
  Map<String, int> _getQuantityByZone() {
    final Map<String, int> zoneQuantities = {};
    for (final location in storedProduct!.locations) {
      zoneQuantities[location.zoneId] = (zoneQuantities[location.zoneId] ?? 0) +
          (location.quantityStored ?? 0);
    }
    return zoneQuantities;
  }

  List<String> _getPOsForSupplier(String supplier) {
    return storedProduct!.locations
        .where((loc) => loc.metadata?['supplierName'] == supplier)
        .map((loc) => loc.metadata?['poNumber'] as String? ?? '')
        .where((po) => po.isNotEmpty)
        .toSet()
        .toList();
  }

  int _getQuantityForSupplier(String supplier) {
    return storedProduct!.locations
        .where((loc) => loc.metadata?['supplierName'] == supplier)
        .fold<int>(0, (sum, loc) => sum + (loc.quantityStored ?? 0));
  }

  String _calculateDistributionScore() {
    final totalZones = 6;
    final usedZones =
        storedProduct!.locations.map((l) => l.zoneId).toSet().length;
    final efficiency = (usedZones / totalZones * 100);

    if (efficiency >= 80) return 'Excellent';
    if (efficiency >= 60) return 'Good';
    if (efficiency >= 40) return 'Fair';
    return 'Poor';
  }

  List<Map<String, dynamic>> _getStorageInsights() {
    final insights = <Map<String, dynamic>>[];

    // Zone distribution insight
    final zoneCount =
        storedProduct!.locations.map((l) => l.zoneId).toSet().length;
    if (zoneCount == 1) {
      insights.add({
        'icon': Icons.warning,
        'color': Colors.orange,
        'text':
            'All items stored in a single zone. Consider diversifying storage locations.',
      });
    } else if (zoneCount >= 4) {
      insights.add({
        'icon': Icons.check_circle,
        'color': Colors.green,
        'text':
            'Good zone distribution. Items are well-spread across warehouse.',
      });
    }

    // Quantity distribution insight
    final avgQty =
        storedProduct!.totalQuantityStored / storedProduct!.locations.length;
    if (avgQty < 5) {
      insights.add({
        'icon': Icons.info,
        'color': Colors.blue,
        'text': 'Low quantity per location. Consider consolidating storage.',
      });
    } else if (avgQty > 20) {
      insights.add({
        'icon': Icons.inventory,
        'color': Colors.purple,
        'text': 'High quantity per location. Efficient space utilization.',
      });
    }

    // Supplier diversity insight
    if (storedProduct!.supplierNames.length == 1) {
      insights.add({
        'icon': Icons.business,
        'color': Colors.orange,
        'text':
            'Single supplier dependency. Consider diversifying supply sources.',
      });
    } else {
      insights.add({
        'icon': Icons.diversity_3,
        'color': Colors.green,
        'text': 'Multiple suppliers provide good supply chain resilience.',
      });
    }

    return insights;
  }

  Color _getCategoryColor(String category) {
    // Generate consistent color based on category name hash
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.yellow[700]!,
      Colors.green,
      Colors.blue,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.brown,
    ];

    final hash = category.hashCode;
    return colors[hash.abs() % colors.length];
  }

  Color _getZoneColor(String zone) {
    switch (zone) {
      case 'Z1':
        return Colors.red;
      case 'Z2':
        return Colors.orange;
      case 'Z3':
        return Colors.yellow[700]!;
      case 'Z4':
        return Colors.green;
      case 'Z5':
        return Colors.blue;
      case 'Z6':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getZoneName(String zone) {
    switch (zone) {
      case 'Z1':
        return 'Fast-Moving Zone';
      case 'Z2':
        return 'Medium-Moving Zone';
      case 'Z3':
        return 'Slow-Moving Zone';
      case 'Z4':
        return 'Bulk Storage Area';
      case 'Z5':
        return 'Climate-Controlled Area';
      case 'Z6':
        return 'Hazardous Material Area';
      default:
        return 'Unknown Zone';
    }
  }

  int _calculateDaysBetween(DateTime start, DateTime end) {
    return end.difference(start).inDays;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showLocationDetails(WarehouseLocation location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Location: ${location.locationId}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Zone: ${location.zoneId} (${_getZoneName(location.zoneId)})'),
            Text('Quantity: ${location.quantityStored ?? 0}'),
            if (location.metadata?['poNumber'] != null)
              Text('Purchase Order: ${location.metadata!['poNumber']}'),
            if (location.metadata?['supplierName'] != null)
              Text('Supplier: ${location.metadata!['supplierName']}'),
            if (location.occupiedDate != null)
              Text('Stored Date: ${_formatDate(location.occupiedDate!)}'),
          ],
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


