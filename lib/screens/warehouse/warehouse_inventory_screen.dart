// lib/screens/warehouse/warehouse_inventory_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:assignment/models/warehouse_location.dart';
import 'package:assignment/models/purchase_order.dart';
import 'package:assignment/services/warehouse/warehouse_allocation_service.dart';
//import 'package:assignment/services/inventory/product_service.dart';
import 'package:assignment/screens/warehouse/stored_product_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:assignment/widgets/qr/qr_generator_dialog.dart';
import 'package:assignment/widgets/qr/qr_scanner_dialog.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:assignment/widgets/purchase_order/request_po_dialog.dart';
import 'package:assignment/services/login/load_user_data.dart';
import 'package:assignment/models/user_model.dart';
import 'package:assignment/dao/product_brand_dao.dart';
import 'package:assignment/dao/product_category_dao.dart';
import 'package:assignment/dao/product_name_dao.dart';

import 'package:assignment/models/stored_product_model.dart';
import 'package:assignment/models/po_supplier_info_model.dart';


class WarehouseInventoryScreen extends StatefulWidget {
  const WarehouseInventoryScreen({super.key});

  @override
  State<WarehouseInventoryScreen> createState() => _WarehouseInventoryScreenState();
}

class _WarehouseInventoryScreenState extends State<WarehouseInventoryScreen> {
  final WarehouseAllocationService _warehouseService = WarehouseAllocationService();
  //final ProductService _productService = ProductService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Map<String, PurchaseOrder?> _pendingRequests = {};
  Map<String, PurchaseOrder?> _rejectedRequests = {};
  bool _isLoadingRequests = false;
  UserModel? currentUser;
  StreamSubscription<QuerySnapshot>? _productNamesSubscription;
  StreamSubscription<QuerySnapshot>? _categoriesSubscription;
  StreamSubscription<QuerySnapshot>? _brandsSubscription;

  static const int LOW_STOCK_THRESHOLD = 10;
  static const int CRITICAL_STOCK_THRESHOLD = 5;

  // State variables
  List<StoredProduct> storedProducts = [];
  List<StoredProduct> filteredProducts = [];
  bool isLoading = true;
  String? errorMessage;
  String searchQuery = '';
  String selectedZone = 'All';
  String selectedCategory = 'All';
  String selectedBrand = 'All';

  String sortBy = 'name';
  bool isAscending = true;

  // Filter options
  List<String> availableZones = ['All'];
  List<String> availableCategories = ['All'];
  List<String> availableBrands = ['All'];

  // Real-time subscription
  StreamSubscription<QuerySnapshot>? _warehouseSubscription;
  StreamSubscription<QuerySnapshot>? _productsSubscription;

  Map<String, Map<String, dynamic>> _productsCache = {};
  QuerySnapshot? _latestWarehouseSnapshot;

  late SpeechToText _speechToText;
  bool _speechEnabled = false;
  bool _speechListening = false;
  String _speechText = '';
  double _speechConfidence = 0.0;

  final ProductBrandDAO _brandDao = ProductBrandDAO();
  final CategoryDao _categoryDao = CategoryDao();
  final ProductNameDao _productNameDao = ProductNameDao();

  final Map<String, String> _productNameCache = {};
  final Map<String, String> _categoryNameCache = {};
  final Map<String, String> _brandNameCache = {};

  @override
  void initState() {
    super.initState();
    _testFirebaseConnection();
    _setupRealtimeUpdates();
    _loadPendingRequests();
    _setupNameListeners();
    _loadUser();
    _initializeSpeech();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _warehouseSubscription?.cancel();
    _productsSubscription?.cancel();
    _speechToText.stop();
    _productNamesSubscription?.cancel();
    _categoriesSubscription?.cancel();
    _brandsSubscription?.cancel();
    _productNameCache.clear();
    _categoryNameCache.clear();
    _brandNameCache.clear();
    super.dispose();
  }

  void _setupNameListeners() {
    // Listen to productNames collection
    _productNamesSubscription = FirebaseFirestore.instance
        .collection('productNames') // Use your actual collection name
        .snapshots()
        .listen((snapshot) {
      print('ProductNames collection changed');
      _productNameCache.clear();
      _refreshCombinedData();
    });

    // Listen to categories collection
    _categoriesSubscription = FirebaseFirestore.instance
        .collection('categories') // Use your actual collection name
        .snapshots()
        .listen((snapshot) {
      print('Categories collection changed');
      _categoryNameCache.clear();
      _refreshCombinedData();
    });

    // Listen to brands collection
    _brandsSubscription = FirebaseFirestore.instance
        .collection('brands') // Use your actual collection name
        .snapshots()
        .listen((snapshot) {
      print('Brands collection changed');
      _brandNameCache.clear();
      _refreshCombinedData();
    });
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

    // Check cache first
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

  Future<void> _loadUser() async {
    final user = await loadCurrentUser();
    setState(() {
      currentUser = user;
    });
  }

  Future<void> _loadPendingRequests() async {
    setState(() {
      _isLoadingRequests = true;
    });

    try {
      // Get ALL purchase orders to determine the latest one for each product
      final snapshot = await FirebaseFirestore.instance
          .collection('purchaseOrder')
          .orderBy('createdDate', descending: true)
          .get();

      final Map<String, PurchaseOrder> pendingRequests = {};
      final Map<String, PurchaseOrder> rejectedRequests = {};
      final Map<String, PurchaseOrder> latestPOPerProduct = {}; // Track latest PO per product
      final now = DateTime.now();

      // First pass: Find the latest PO for each product
      for (var doc in snapshot.docs) {
        try {
          final po = PurchaseOrder.fromFirestore(doc.data());
          if (po.lineItems.isNotEmpty) {
            final productId = po.lineItems.first.productId;

            // Update latest PO if this one is more recent
            if (!latestPOPerProduct.containsKey(productId) ||
                po.createdDate.isAfter(latestPOPerProduct[productId]!.createdDate)) {
              latestPOPerProduct[productId] = po;
            }
          }
        } catch (e) {
          print('Error parsing PO ${doc.id}: $e');
        }
      }

      // Second pass: Apply business logic based on latest PO status
      for (var entry in latestPOPerProduct.entries) {
        final productId = entry.key;
        final latestPO = entry.value;

        // If latest PO is COMPLETED or READY, don't show any status indicators
        if (latestPO.status == POStatus.COMPLETED || latestPO.status == POStatus.READY) {
          continue; // Skip this product entirely
        }

        // Apply existing logic for other statuses
        if (latestPO.status == POStatus.REJECTED) {
          // Only show rejected if it's the latest request
          rejectedRequests[productId] = latestPO;
        } else if (latestPO.status == POStatus.PENDING_APPROVAL) {
          pendingRequests[productId] = latestPO;
        } else if (latestPO.status == POStatus.APPROVED) {
          final daysSinceApproval = now.difference(latestPO.createdDate).inDays;
          if (daysSinceApproval < 7) {
            pendingRequests[productId] = latestPO;
          }
        }
      }

      setState(() {
        _pendingRequests = pendingRequests;
        _rejectedRequests = rejectedRequests;
        _isLoadingRequests = false;
      });

      print('DEBUG: Loaded ${pendingRequests.length} pending requests and ${rejectedRequests.length} rejected requests');

    } catch (e) {
      print('Error loading requests: $e');
      setState(() {
        _isLoadingRequests = false;
      });
    }
  }

  bool _hasPendingRequest(String productId) {
    final hasPending = _pendingRequests.containsKey(productId);
    print('🔍 DEBUG: _hasPendingRequest($productId) = $hasPending');
    print('🔍 DEBUG: Current _pendingRequests keys: ${_pendingRequests.keys.toList()}');
    return hasPending;
  }

  bool _hasRejectedRequest(String productId) {
    return _rejectedRequests.containsKey(productId);
  }

  PurchaseOrder? _getRejectedRequest(String productId) {
    return _rejectedRequests[productId];
  }

  String _getRequestStatus(String productId) {
    final request = _pendingRequests[productId];
    if (request == null) return 'none';

    switch (request.status) {
      case POStatus.PENDING_APPROVAL:
        return 'pending';
      case POStatus.APPROVED:
        return 'approved';
      case POStatus.REJECTED:
        return 'rejected';
      default:
        return 'unknown';
    }
  }

  bool _isLowStock(StoredProduct product) {
    return product.totalQuantityStored <= LOW_STOCK_THRESHOLD;
  }

  bool _isCriticalStock(StoredProduct product) {
    return product.totalQuantityStored <= CRITICAL_STOCK_THRESHOLD;
  }

  void _initializeSpeech() async {
    _speechToText = SpeechToText();
    _speechEnabled = await _speechToText.initialize(
      onError: (error) {
        print('Speech recognition error: $error');
        setState(() {
          _speechListening = false;
        });
        _showSnackBar('Speech recognition error: ${error.errorMsg}', Colors.red);
      },
      onStatus: (status) {
        print('Speech recognition status: $status');
        if (status == 'done' || status == 'notListening') {
          setState(() {
            _speechListening = false;
          });
        }
      },
    );

    if (!_speechEnabled) {
      _showSnackBar('Speech recognition not available on this device', Colors.orange);
    }
  }

  void _startListening() async {
    // Check microphone permission
    final micPermission = await Permission.microphone.request();
    if (micPermission != PermissionStatus.granted) {
      _showSnackBar('Microphone permission denied', Colors.red);
      return;
    }

    if (!_speechEnabled) {
      _showSnackBar('Speech recognition not available', Colors.red);
      return;
    }

    setState(() {
      _speechListening = true;
      _speechText = '';
      _speechConfidence = 0.0;
    });

    // Show helpful tip for first-time users
    _showSnackBar('Listening... Speak clearly into your microphone', Colors.blue);

    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _speechText = result.recognizedWords;
          _speechConfidence = result.confidence;
        });

        // Update search field in real-time
        _searchController.text = _speechText;
        searchQuery = _speechText;
        _applyFilters();
      },
      listenFor: const Duration(seconds: 15), // Increased timeout
      pauseFor: const Duration(seconds: 5), // Longer pause tolerance
      partialResults: true,
      localeId: 'en_US',
      cancelOnError: false,
      listenMode: ListenMode.confirmation,
    );
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _speechListening = false;
    });

    if (_speechText.isNotEmpty) {
      _showSnackBar('Voice search: "${_speechText}"', Colors.green);
    }
  }

  void _toggleSpeechRecognition() {
    if (_speechListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  void _setupRealtimeUpdates() {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    // Listen to products collection for product details
    _setupProductsListener();

    // Listen to warehouse locations for inventory data
    _setupWarehouseListener();

    _setupRequestsListener();
  }

  void _setupRequestsListener() {
    FirebaseFirestore.instance
        .collection('purchaseOrder')
        .orderBy('createdDate', descending: true)
        .snapshots()
        .listen((snapshot) {
      final Map<String, PurchaseOrder> pendingRequests = {};
      final Map<String, PurchaseOrder> rejectedRequests = {};
      final Map<String, PurchaseOrder> latestPOPerProduct = {}; // Track latest PO per product
      final now = DateTime.now();

      for (var doc in snapshot.docs) {
        try {
          final po = PurchaseOrder.fromFirestore(doc.data());
          if (po.lineItems.isNotEmpty) {
            final productId = po.lineItems.first.productId;

            // Update latest PO if this one is more recent
            if (!latestPOPerProduct.containsKey(productId) ||
                po.createdDate.isAfter(latestPOPerProduct[productId]!.createdDate)) {
              latestPOPerProduct[productId] = po;
            }
          }
        } catch (e) {
          print('Error parsing PO ${doc.id}: $e');
        }
      }

      for (var entry in latestPOPerProduct.entries) {
        final productId = entry.key;
        final latestPO = entry.value;

        if (latestPO.status == POStatus.COMPLETED || latestPO.status == POStatus.READY) {
          continue;
        }

        if (latestPO.status == POStatus.REJECTED) {
          // Only show rejected if it's the latest request
          rejectedRequests[productId] = latestPO;
        } else if (latestPO.status == POStatus.PENDING_APPROVAL) {
          pendingRequests[productId] = latestPO;
        } else if (latestPO.status == POStatus.APPROVED) {
          final daysSinceApproval = now.difference(latestPO.createdDate).inDays;
          if (daysSinceApproval < 7) {
            pendingRequests[productId] = latestPO;
          }
        }
      }

      setState(() {
        _pendingRequests = pendingRequests;
        _rejectedRequests = rejectedRequests;
      });
    });
  }

  void _setupProductsListener() {
    _productsSubscription = FirebaseFirestore.instance
        .collection('products')
        .snapshots()
        .listen(
          (snapshot) {
        print('Products collection changed: ${snapshot.docs.length} products');

        // CLEAR NAME CACHES when products change
        _productNameCache.clear();
        _categoryNameCache.clear();
        _brandNameCache.clear();

        // Update products cache
        _productsCache.clear();
        for (var doc in snapshot.docs) {
          _productsCache[doc.id] = doc.data();
        }

        // Re-process warehouse data with updated product info
        _refreshCombinedData();
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
    _warehouseSubscription = FirebaseFirestore.instance
        .collection('warehouseLocations')
        .where('isOccupied', isEqualTo: true)
        .snapshots()
        .listen(
          (snapshot) {
        print('Warehouse collection changed: ${snapshot.docs.length} locations');

        // Store the latest snapshot
        _latestWarehouseSnapshot = snapshot;

        // Process the warehouse data
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

  void _refreshCombinedData() {
    // Re-process the latest warehouse snapshot with updated product data
    if (_latestWarehouseSnapshot != null) {
      print('Refreshing combined data with ${_productsCache.length} products');
      _processWarehouseSnapshot(_latestWarehouseSnapshot!);
    }
  }

  Future<void> _processWarehouseSnapshot(QuerySnapshot snapshot) async {
    try {
      print('Processing warehouse snapshot: ${snapshot.docs.length} documents');

      // Convert snapshot to WarehouseLocation objects
      final occupiedLocations = snapshot.docs
          .map((doc) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          print('Processing location: ${doc.id} with data: $data');
          return WarehouseLocation.fromFirestore(data);
        } catch (e) {
          print('Error converting document ${doc.id}: $e');
          return null;
        }
      })
          .where((location) => location != null)
          .cast<WarehouseLocation>()
          .toList();

      print('Successfully converted ${occupiedLocations.length} locations');

      if (occupiedLocations.isEmpty) {
        print('No occupied locations found');
        setState(() {
          storedProducts = [];
          filteredProducts = [];
          availableZones = ['All'];
          availableCategories = ['All'];
          String selectedBrand = 'All';
          isLoading = false;
        });
        _applyFilters();
        return;
      }

      final Map<String, List<WarehouseLocation>> groupedByProduct = {};
      for (final location in occupiedLocations) {
        if (location.productId != null) {
          groupedByProduct.putIfAbsent(location.productId!, () => []).add(location);
        }
      }

      print('Grouped into ${groupedByProduct.length} unique products');
      print('Products cache has ${_productsCache.length} products');

      final List<StoredProduct> aggregatedProducts = [];
      final Set<String> categoryNames = {'All'};
      final Set<String> brandNames = {'All'};

      for (final entry in groupedByProduct.entries) {
        final productId = entry.key;
        final locations = entry.value;

        final productData = _productsCache[productId];

        final totalQuantity = locations.fold<int>(0, (sum, loc) => sum + (loc.quantityStored ?? 0));

        final poNumbersAndSuppliers = await _getActualPOsFromProductItems(productId, locations);
        final allPONumbers = poNumbersAndSuppliers.poNumbers;
        final allSupplierNames = poNumbersAndSuppliers.supplierNames;

        // Get dates from warehouse locations
        final occupiedDates = locations
            .where((loc) => loc.occupiedDate != null)
            .map((loc) => loc.occupiedDate!)
            .toList();
        occupiedDates.sort();

        // Create StoredProduct with resolved names
        StoredProduct storedProduct;

        if (productData == null) {
          final firstLocation = locations.first;
          storedProduct = StoredProduct(
            productId: productId,
            productName: firstLocation.productName ?? 'Unknown Product ($productId)',
            partNumber: 'N/A',
            category: 'Unknown',
            totalQuantityStored: totalQuantity,
            locations: locations,
            purchaseOrderNumbers: allPONumbers,
            supplierNames: allSupplierNames,
          );
          categoryNames.add('Unknown');
          brandNames.add('Unknown');
        } else {
          print('Found product data for $productId: ${productData['name']}');

          // Resolve IDs to display names
          final productName = await _resolveProductName(
              productData['name'] ?? productData['productName']
          );
          final categoryName = await _resolveCategoryName(
              productData['category']
          );
          final brandName = await _resolveBrandName(
              productData['brand']
          );

          storedProduct = StoredProduct(
            productId: productId,
            // Use resolved names instead of IDs
            productName: productName,
            partNumber: productData['partNumber'] ??
                productData['sku'] ??
                productData['code'] ??
                'N/A',
            category: categoryName,
            productBrand: brandName,
            productDescription: productData['description'] ??
                productData['desc'],
            unitPrice: (productData['unitPrice'] ??
                productData['price'] ??
                productData['cost'])?.toDouble(),
            // Use data from warehouse locations
            totalQuantityStored: totalQuantity,
            locations: locations,
            firstStoredDate: occupiedDates.isNotEmpty ? occupiedDates.first : null,
            lastStoredDate: occupiedDates.isNotEmpty ? occupiedDates.last : null,
            purchaseOrderNumbers: allPONumbers,
            supplierNames: allSupplierNames,
          );

          // Add to category filter options
          categoryNames.add(categoryName);
          brandNames.add(brandName);
        }

        aggregatedProducts.add(storedProduct);
      }

      print('Created ${aggregatedProducts.length} aggregated products');

      // Extract filter options
      final zones = occupiedLocations.map((l) => l.zoneId).toSet().toList();
      zones.sort();

      final categories = categoryNames.toList();
      categories.sort();

      final brands = brandNames.toList();
      brands.sort();

      setState(() {
        storedProducts = aggregatedProducts;
        availableZones = ['All', ...zones];
        availableCategories = categories;
        availableBrands = brands;
        isLoading = false;
        errorMessage = null;
      });

      _applyFilters();
      print('UI updated with ${storedProducts.length} products');

    } catch (e) {
      print('Error processing warehouse snapshot: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to process warehouse data: $e';
      });
    }
  }

  Future<POAndSupplierInfo> _getActualPOsFromProductItems(String productId, List<WarehouseLocation> locations) async {
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

      print('🔍 Found ${snapshot.docs.length} ProductItems for product $productId at locations $locationIds');

      // Collect unique PO IDs from ProductItems
      final Set<String> actualPOIds = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final poId = data['purchaseOrderId'] as String?;
        if (poId != null && poId.isNotEmpty) {
          actualPOIds.add(poId);
        }
      }

      print('🔍 Found actual PO IDs from ProductItems: ${actualPOIds.toList()}');

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

  POAndSupplierInfo _getFallbackPOsFromMetadata(List<WarehouseLocation> locations) {
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

      // Only add consolidated POs if they exist and are different
      final consolidatedPOs = location.metadata?['consolidatedPOs'] as List<dynamic>?;
      if (consolidatedPOs != null) {
        for (final consolidatedPO in consolidatedPOs) {
          if (consolidatedPO is String && consolidatedPO.isNotEmpty) {
            // Get the PO number for the consolidated PO
            final consolidatedPONumber = _getPONumberFromPOId(consolidatedPO);
            if (consolidatedPONumber.isNotEmpty && consolidatedPONumber != poNumber) {
              allPONumbers.add(consolidatedPONumber);
            }
          }
        }
      }
    }

    return POAndSupplierInfo(
      poNumbers: allPONumbers,
      supplierNames: allSupplierNames,
    );
  }




  String _getPONumberFromPOId(String poId) {

    if (poId.startsWith('PO-') && poId.length > 3) {
      return poId; // Use the PO ID as PO number if they're similar
    }

    return poId;
  }

  Future<void> _testFirebaseConnection() async {
    try {
      print('Testing Firebase connection...');

      // Test products collection
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .limit(1)
          .get();
      print('Products collection accessible: ${productsSnapshot.docs.length} docs');

      // Test warehouse locations collection
      final warehouseSnapshot = await FirebaseFirestore.instance
          .collection('warehouseLocations')
          .limit(1)
          .get();
      print('Warehouse locations collection accessible: ${warehouseSnapshot.docs.length} docs');

      // Test with actual query
      final occupiedSnapshot = await FirebaseFirestore.instance
          .collection('warehouseLocations')
          .where('isOccupied', isEqualTo: true)
          .limit(5)
          .get();
      print('Occupied locations found: ${occupiedSnapshot.docs.length}');

      if (occupiedSnapshot.docs.isNotEmpty) {
        final firstDoc = occupiedSnapshot.docs.first;
        print('First occupied location: ${firstDoc.id} -> ${firstDoc.data()}');
      }

    } catch (e) {
      print('Firebase connection test failed: $e');
      setState(() {
        errorMessage = 'Firebase connection failed: $e';
      });
    }
  }

  Future<void> _refreshInventory() async {
    // Cancel existing subscriptions and restart
    await _warehouseSubscription?.cancel();
    await _productsSubscription?.cancel();
    _setupRealtimeUpdates();
  }

  void _applyFilters() {
    List<StoredProduct> filtered = List.from(storedProducts);

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((product) {
        return product.productName.toLowerCase().contains(query) ||
            product.category.toLowerCase().contains(query) ||
            (product.productBrand?.toLowerCase().contains(query) ?? false) ||
            product.purchaseOrderNumbers.any((po) => po.toLowerCase().contains(query)) ||
            product.supplierNames.any((supplier) => supplier.toLowerCase().contains(query)) ||
            product.locations.any((loc) => loc.locationId.toLowerCase().contains(query));
      }).toList();
    }

    if (selectedZone != 'All') {
      filtered = filtered.where((product) {
        return product.locations.any((loc) => loc.zoneId == selectedZone);
      }).toList();
    }

    if (selectedCategory != 'All') {
      filtered = filtered.where((product) => product.category == selectedCategory).toList();
    }


    if (selectedBrand != 'All') {
      filtered = filtered.where((product) => product.productBrand == selectedBrand).toList();
    }

    filtered.sort((a, b) {
      int comparison;
      switch (sortBy) {
        case 'name':
          comparison = a.productName.compareTo(b.productName);
          break;
        case 'quantity':
          comparison = a.totalQuantityStored.compareTo(b.totalQuantityStored);
          break;
        case 'category':
          comparison = a.category.compareTo(b.category);
          break;
        case 'brand': // ADD new sort option
          comparison = (a.productBrand ?? '').compareTo(b.productBrand ?? '');
          break;
        case 'date':
          final aDate = a.lastStoredDate ?? DateTime(1970);
          final bDate = b.lastStoredDate ?? DateTime(1970);
          comparison = aDate.compareTo(bDate);
          break;
        case 'locations':
          comparison = a.locations.length.compareTo(b.locations.length);
          break;
        default:
          comparison = a.productName.compareTo(b.productName);
      }
      return isAscending ? comparison : -comparison;
    });

    setState(() {
      filteredProducts = filtered;
    });
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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildSearchSuffixIcons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // UPDATED: Voice search with speech-to-text
        Container(
          decoration: BoxDecoration(
            color: _speechListening ? Colors.red[50] : null,
            borderRadius: BorderRadius.circular(20),
          ),
          child: IconButton(
            icon: Icon(
              _speechListening ? Icons.mic : Icons.mic_none,
              size: 20,
              color: _speechListening ? Colors.red[600] : Colors.grey[600],
            ),
            onPressed: _speechEnabled ? _toggleSpeechRecognition : null,
            tooltip: _speechListening ? 'Stop Voice Search' : 'Voice Search',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
        ),
        // QR scan icon
        IconButton(
          icon: const Icon(Icons.qr_code_scanner, size: 20),
          onPressed: _showQRScannerPopup,
          tooltip: 'QR Scanner',
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
        ),
        // Clear icon (only show when there's text)
        if (searchQuery.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear, size: 20),
            onPressed: () {
              _searchController.clear();
              setState(() {
                searchQuery = '';
                _speechText = '';
              });
              _applyFilters();
            },
            tooltip: 'Clear Search',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
      ],
    );
  }

  Widget _buildSpeechStatus() {
    if (!_speechListening) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          // Animated microphone icon
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mic,
              color: Colors.red[600],
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Listening...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[800],
                  ),
                ),
                if (_speechText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _speechText,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red[700],
                    ),
                  ),
                ],
                // Confidence indicator
                if (_speechConfidence > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Confidence: ${(_speechConfidence * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: _speechConfidence,
                          backgroundColor: Colors.red[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.red[600]!,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Stop button
          IconButton(
            onPressed: _stopListening,
            icon: Icon(Icons.stop, color: Colors.red[600], size: 20),
            tooltip: 'Stop Listening',
          ),
        ],
      ),
    );
  }



  void _showQRScannerPopup() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismiss by tapping outside
      builder: (context) => const QRScannerDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? _buildLoadingScreen()
          : errorMessage != null
          ? _buildErrorScreen()
          : Column(
        children: [
          _buildSearchAndFilters(),
          _buildStatsBar(),
          Expanded(
            child: filteredProducts.isEmpty
                ? _buildEmptyState()
                : _buildProductList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQRScannerPopup, // Show popup instead of navigate
        backgroundColor: Colors.blue[600],
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
        tooltip: 'Scan QR Code',
      ),
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
            'Loading warehouse inventory...',
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
              'Error Loading Inventory',
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
              onPressed: _refreshInventory,
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
          // Search bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products, locations, PO numbers...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _buildSearchSuffixIcons(),
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

          // Speech recognition status
          _buildSpeechStatus(),

          const SizedBox(height: 12),

          IntrinsicHeight(
            child: Row(
              children: [
                Flexible(
                  flex: 1,
                  child: _buildZoneFilter(),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 1,
                  child: _buildCategoryFilter(),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 1,
                  child: _buildBrandFilter(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandFilter() {
    return DropdownButtonFormField<String>(
      value: selectedBrand,
      decoration: InputDecoration(
        labelText: 'Brand',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      isExpanded: true, // Prevents overflow in dropdown
      items: availableBrands.map((brand) {
        return DropdownMenuItem(
          value: brand,
          child: Text(
            brand,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis, // Truncate long text
            maxLines: 1, // Limit to single line
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedBrand = value!;
        });
        _applyFilters();
      },
    );
  }

  Widget _buildZoneFilter() {
    return DropdownButtonFormField<String>(
      value: selectedZone,
      decoration: InputDecoration(
        labelText: 'Zone',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      isExpanded: true, // Prevents overflow in dropdown
      items: availableZones.map((zone) {
        return DropdownMenuItem(
          value: zone,
          child: Text(
            zone,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis, // Truncate long text
            maxLines: 1, // Limit to single line
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedZone = value!;
        });
        _applyFilters();
      },
    );
  }

  Widget _buildCategoryFilter() {
    return DropdownButtonFormField<String>(
      value: selectedCategory,
      decoration: InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      isExpanded: true, // Prevents overflow in dropdown
      items: availableCategories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Text(
            category,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis, // Truncate long text
            maxLines: 1, // Limit to single line
          ),
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

  Widget _buildSortButton() {
    return PopupMenuButton<String>(
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
        _buildSortMenuItem('name', 'Product Name', Icons.inventory),
        _buildSortMenuItem('quantity', 'Quantity', Icons.numbers),
        _buildSortMenuItem('category', 'Category', Icons.category),
        _buildSortMenuItem('brand', 'Brand', Icons.branding_watermark), // ADD brand sort
        _buildSortMenuItem('date', 'Date Stored', Icons.schedule),
        _buildSortMenuItem('locations', 'Location Count', Icons.location_on),
      ],
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(String value, String label, IconData icon) {
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
    final totalProducts = filteredProducts.length;
    final totalQuantity = filteredProducts.fold<int>(0, (sum, p) => sum + p.totalQuantityStored);
    final uniqueLocations = filteredProducts
        .expand((p) => p.locations)
        .map((l) => l.locationId)
        .toSet()
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          _buildStatChip('$totalProducts products', Colors.blue),
          const SizedBox(width: 8),
          _buildStatChip('$totalQuantity total qty', Colors.green),
          const SizedBox(width: 8),
          _buildStatChip('$uniqueLocations locations', Colors.purple),
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
            Icon(Icons.warehouse, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'No Products in Warehouse',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isNotEmpty
                  ? 'No products match your search criteria'
                  : 'No products have been stored in the warehouse yet',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            // UPDATE: Clear filters to include brand
            if (searchQuery.isNotEmpty || selectedZone != 'All' || selectedCategory != 'All' || selectedBrand != 'All') ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    searchQuery = '';
                    selectedZone = 'All';
                    selectedCategory = 'All';
                    selectedBrand = 'All'; // ADD brand reset
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

  Widget _buildProductList() {
    return RefreshIndicator(
      onRefresh: _refreshInventory,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: filteredProducts.length,
        itemBuilder: (context, index) {
          final product = filteredProducts[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  Widget _buildProductCard(StoredProduct product) {
    final hasPendingRequest = _hasPendingRequest(product.productId);
    final hasRejectedRequest = _hasRejectedRequest(product.productId);
    final requestStatus = _getRequestStatus(product.productId);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StoredProductDetailScreen(
                productId: product.productId,
                initialProductName: product.productName,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
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
                        Text(
                          product.productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              product.category,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            // Show pending request status
                            if (hasPendingRequest)
                              _buildRequestStatusChip(requestStatus, product.productId),
                            // Show rejected request indicator
                            if (hasRejectedRequest && !hasPendingRequest)
                              _buildRejectedRequestChip(product.productId),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (action) => _handleMenuAction(action, product),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility, size: 16),
                            SizedBox(width: 8),
                            Text('View Detail'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'qr',
                        child: Row(
                          children: [
                            Icon(Icons.qr_code, size: 16),
                            SizedBox(width: 8),
                            Text('Generate qr'),
                          ],
                        ),
                      ),
                      if (_isLowStock(product)) ...[
                        if (hasPendingRequest) ...[
                          // Show pending request details
                          PopupMenuItem(
                            value: 'view_request',
                            child: Row(
                              children: [
                                Icon(Icons.pending_actions, size: 16, color: Colors.blue[600]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'View Request',
                                        style: TextStyle(
                                          color: Colors.blue[600],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'by ${_getRequestCreator(product.productId)}',
                                        style: TextStyle(
                                          color: Colors.blue[500],
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (hasRejectedRequest) ...[
                          // Simple "Try Again" option for rejected requests
                          PopupMenuItem(
                            value: 'try_again',
                            child: Row(
                              children: [
                                Icon(Icons.refresh, size: 16, color: Colors.green[600]),
                                const SizedBox(width: 8),
                                Text(
                                  'Try Request Again',
                                  style: TextStyle(color: Colors.green[600]),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Normal request option
                          PopupMenuItem(
                            value: 'request_po',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.shopping_cart,
                                  size: 16,
                                  color: _isCriticalStock(product) ? Colors.red : Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isCriticalStock(product) ? 'Urgent PO Request' : 'Request PO',
                                  style: TextStyle(
                                    color: _isCriticalStock(product) ? Colors.red : Colors.orange,
                                    fontWeight: _isCriticalStock(product) ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Key metrics row
              Row(
                children: [
                  _buildMetricChip(
                    '${product.totalQuantityStored}',
                    'Total Qty',
                    _isCriticalStock(product)
                        ? Colors.red
                        : _isLowStock(product)
                        ? Colors.orange
                        : Colors.blue,
                    Icons.inventory,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricChip(
                    '${product.locations.length}',
                    'Locations',
                    Colors.green,
                    Icons.location_on,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricChip(
                    '${product.purchaseOrderNumbers.length}',
                    'POs',
                    Colors.purple,
                    Icons.receipt,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Location summary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Locations:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.locationSummary,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (product.locations.length > 1) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: product.locations.take(3).map((location) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Text(
                              '${location.locationId}: ${location.quantityStored}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (product.locations.length > 3)
                        Text(
                          '+ ${product.locations.length - 3} more locations',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Supplier and date info
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Supplier: ${product.supplierSummary}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (product.lastStoredDate != null)
                    Text(
                      'Last stored: ${_formatDate(product.lastStoredDate!)}',
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
      ),
    );
  }

  void _showRejectionFeedbackDialog(StoredProduct product) {
    final rejectedRequest = _getRejectedRequest(product.productId);
    if (rejectedRequest == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text('Request Rejected'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product: ${product.productName}'),
            const SizedBox(height: 8),
            Text('Request ID: ${rejectedRequest.poNumber}'),
            const SizedBox(height: 16),

            // Simple rejection message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: Colors.red[700], size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Your request has been rejected.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.red[800],
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Please try request again.',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Open new request dialog
              _showNewRequestAfterRejection(product);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Try Again', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showNewRequestAfterRejection(StoredProduct product) {
    showDialog(
      context: context,
      builder: (context) => RequestPODialog(
        productId: product.productId,
        productName: product.productName,
        category: product.category,
        currentStock: product.totalQuantityStored,
        currentPrice: product.unitPrice,
        brand: product.productBrand,
        sku: product.partNumber,
        isCriticalStock: _isCriticalStock(product),
      ),
    ).then((poId) {
      if (poId != null) {
        _showSnackBar('New PO request submitted!', Colors.green);
        _loadPendingRequests();
      }
    });
  }

  Widget _buildRejectedRequestChip(String productId) {
    final rejectedRequest = _getRejectedRequest(productId);
    if (rejectedRequest == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cancel, size: 12, color: Colors.red),
          const SizedBox(width: 4),
          Text(
            'Request Rejected',
            style: TextStyle(
              fontSize: 10,
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showRequestDetailsDialog(StoredProduct product) {
    final request = _pendingRequests[product.productId];
    if (request == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('PO Request Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request ID: ${request.poNumber}'),
            const SizedBox(height: 8),
            Text('Status: ${request.status.toString().split('.').last}'),
            const SizedBox(height: 8),
            Text('Requested by: ${request.createdByUserName}'), // Show who made request
            const SizedBox(height: 8),
            Text('Created: ${_formatDate(request.createdDate)}'),
            const SizedBox(height: 8),
            Text('Expected Delivery: ${request.expectedDeliveryDate != null ? _formatDate(request.expectedDeliveryDate!) : "Not set"}'),
            if (request.notes != null) ...[
              const SizedBox(height: 8),
              Text('Notes: ${request.notes}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          // Only allow cancellation if current user made the request
          if (request.status == POStatus.PENDING_APPROVAL &&
              currentUser?.employeeId == request.createdByUserId)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _cancelRequest(product, request);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cancel Request'),
            ),
        ],
      ),
    );
  }

  Future<void> _cancelRequest(StoredProduct product, PurchaseOrder request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request'),
        content: Text('Are you sure you want to cancel the PO request for ${product.productName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Update request status to cancelled
        await FirebaseFirestore.instance
            .collection('purchaseOrder')
            .doc(request.id)
            .update({
          'status': 'CANCELLED',
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedByUserId': currentUser?.employeeId,
        });

        _showSnackBar('Request cancelled successfully', Colors.green);
        _loadPendingRequests(); // Refresh

      } catch (e) {
        _showSnackBar('Failed to cancel request', Colors.red);
      }
    }
  }

  String _getRequestCreator(String productId) {
    final request = _pendingRequests[productId];
    return request?.createdByUserName ?? '';
  }

  Widget _buildRequestStatusChip(String status, String productId) {
    final request = _pendingRequests[productId];
    if (request == null) return const SizedBox.shrink();

    Color color;
    String label;
    IconData icon;

    if (request.status == POStatus.PENDING_APPROVAL) {
      color = Colors.orange;
      label = 'Pending Approval';
      icon = Icons.pending;
    } else if (request.status == POStatus.APPROVED) {
      // Show how many days since approved
      final daysSinceApproval = DateTime.now().difference(request.createdDate).inDays;
      color = Colors.blue;
      label = 'Approved ${daysSinceApproval}d ago';
      icon = Icons.local_shipping;
    } else {
      return const SizedBox.shrink();
    }

    final creator = _getRequestCreator(productId);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            creator.isNotEmpty ? '$label by $creator' : label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String value, String label, Color color, IconData icon) {
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
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, StoredProduct product) {
    print('🔍 DEBUG: _handleMenuAction called with action: $action, productId: ${product.productId}');
    switch (action) {
      case 'view':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoredProductDetailScreen(
              productId: product.productId,
              initialProductName: product.productName,
            ),
          ),
        );
        break;
      case 'qr':
        showDialog(
          context: context,
          builder: (context) => QRGeneratorDialog(
            productId: product.productId,
            productName: product.productName,
            category: product.category,
            quantity: product.totalQuantityStored,
          ),
        );
      case 'request_po':
        if (_hasPendingRequest(product.productId)) {
          final request = _pendingRequests[product.productId]!;
          final creator = _getRequestCreator(product.productId);

          String message;
          if (request.status == POStatus.PENDING_APPROVAL) {
            message = 'This product has a pending approval request${creator.isNotEmpty ? " by $creator" : ""}';
          } else if (request.status == POStatus.APPROVED) {
            final daysSinceApproval = DateTime.now().difference(request.createdDate).inDays;
            message = 'This product has an approved order from ${daysSinceApproval} days ago${creator.isNotEmpty ? " by $creator" : ""}. Wait for delivery or contact manager.';
          } else {
            message = 'This product already has a pending request${creator.isNotEmpty ? " by $creator" : ""}';
          }

          _showSnackBar(message, Colors.orange);
          return;
        }

        showDialog(
          context: context,
          builder: (context) => RequestPODialog(
            productId: product.productId,
            productName: product.productName,
            category: product.category,
            currentStock: product.totalQuantityStored,
            currentPrice: product.unitPrice,
            brand: product.productBrand,
            sku: product.partNumber,
            isCriticalStock: _isCriticalStock(product),
          ),
        ).then((poId) {
          if (poId != null) {
            _showSnackBar(
              'PO request submitted! Managers will review request $poId',
              Colors.green,
            );
            // Refresh to get updated pending requests
            _loadPendingRequests();
          }
        });
        break;

      case 'view_request':
        _showRequestDetailsDialog(product);
        break;
      case 'try_again':
      // Show simple rejection message and allow try again
        _showRejectionFeedbackDialog(product);
        break;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
