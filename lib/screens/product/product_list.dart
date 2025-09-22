// lib/screens/warehouse/car_inventory_screen.dart
import 'package:assignment/screens/product/product_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:assignment/models/warehouse_location.dart';
import 'package:assignment/models/purchase_order.dart';
import 'package:assignment/models/product_name_model.dart';
import 'package:assignment/models/product_brand_model.dart';
import 'package:assignment/services/warehouse/warehouse_allocation_service.dart';
import 'package:assignment/screens/warehouse/stored_product_detail_screen.dart';
import 'package:assignment/dao/product_name_dao.dart';
import 'package:assignment/dao/product_brand_dao.dart';
import 'package:assignment/dao/product_category_dao.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:assignment/widgets/qr/qr_generator_dialog.dart';
import 'package:assignment/widgets/qr/qr_scanner_dialog.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:assignment/widgets/purchase_order/request_po_dialog.dart';
import 'package:assignment/services/login/load_user_data.dart';
import 'package:assignment/models/user_model.dart';

import '../../models/product_item.dart';
import '../../models/products_model.dart';
import '../../models/product_category_model.dart';
import 'edit_product.dart';

// Aggregated model to combine Product with inventory information
class ProductInventoryItem {
  final Product product;
  final ProductNameModel? productName;
  final ProductBrandModel? brand;
  final CategoryModel? category;
  final int totalQuantityStored;
  final List<ProductItemLocation> locations;
  final Set<String> purchaseOrderNumbers;
  final Set<String> supplierNames;
  final DateTime? firstStoredDate;
  final DateTime? lastStoredDate;

  ProductInventoryItem({
    required this.product,
    this.productName,
    this.brand,
    this.category,
    required this.totalQuantityStored,
    required this.locations,
    required this.purchaseOrderNumbers,
    required this.supplierNames,
    this.firstStoredDate,
    this.lastStoredDate,
  });

  String get displayName => productName?.productName ?? 'Unknown Product';

  String get displayBrand => brand?.brandName ?? 'Unknown Brand';

  String get displayCategory => category?.name ?? 'Unknown Category';

  String get partNumber => product.partNumber ?? product.sku ?? 'N/A';

  double? get unitPrice => product.price;

  String get description => product.description ?? '';

  String get locationSummary {
    if (locations.isEmpty) {
      return 'No stored inventory';
    } else if (locations.length == 1) {
      final loc = locations.first;
      return 'Zone ${loc.zoneId}, ${loc.quantity} units';
    } else {
      final zones = locations.map((l) => l.zoneId).toSet();
      return '${locations.length} locations (Zones: ${zones.join(', ')})';
    }
  }

  String get supplierSummary {
    if (supplierNames.isEmpty) {
      return 'No suppliers';
    } else if (supplierNames.length == 1) {
      return supplierNames.first;
    } else {
      return '${supplierNames.length} suppliers';
    }
  }

  // Vehicle compatibility from metadata
  String get compatibilitySummary {
    final compatibility = product.metadata['vehicleCompatibility'] as String?;
    if (compatibility == null || compatibility.isEmpty) {
      return 'Universal';
    }
    final vehicles = compatibility.split(',');
    if (vehicles.length == 1) {
      return vehicles.first.trim();
    } else if (vehicles.length <= 3) {
      return vehicles.map((v) => v.trim()).join(', ');
    } else {
      return '${vehicles.take(2).map((v) => v.trim()).join(', ')} +${vehicles.length - 2} more';
    }
  }

  String? get condition => product.metadata['condition'] as String? ?? 'New';

  String? get oem => product.metadata['oem'] as String?;

  String? get warranty => product.metadata['warranty'] as String?;
}

// Location information for a product item
class ProductItemLocation {
  final String zoneId;
  final String locationId;
  final int quantity;
  final DateTime? storedDate;
  final String? purchaseOrderId;
  final String? supplierName;

  ProductItemLocation({
    required this.zoneId,
    required this.locationId,
    required this.quantity,
    this.storedDate,
    this.purchaseOrderId,
    this.supplierName,
  });
}

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final WarehouseAllocationService _warehouseService =
      WarehouseAllocationService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Map<String, PurchaseOrder?> _pendingRequests = {};
  Map<String, PurchaseOrder?> _rejectedRequests = {};
  bool _isLoadingRequests = false;
  UserModel? currentUser;

  // DAOs
  final ProductNameDao _productNameDao = ProductNameDao();
  final ProductBrandDAO _productBrandDao = ProductBrandDAO();
  final CategoryDao _productCategoryDao = CategoryDao();

  static const int LOW_STOCK_THRESHOLD = 5;
  static const int CRITICAL_STOCK_THRESHOLD = 2;

  // State variables
  List<ProductInventoryItem> inventoryItems = [];
  List<ProductInventoryItem> filteredItems = [];
  bool isLoading = true;
  String? errorMessage;
  String searchQuery = '';
  String selectedZone = 'All';
  String selectedCategory = 'All';
  String selectedBrand = 'All';
  String selectedCondition = 'All';
  String sortBy = 'name';
  bool isAscending = true;

  // Filter options
  List<String> availableZones = ['All'];
  List<String> availableCategories = ['All'];
  List<String> availableBrands = ['All'];
  List<String> availableConditions = ['All', 'New', 'Used', 'Refurbished'];

  // Real-time subscriptions
  StreamSubscription<QuerySnapshot>? _productsSubscription;
  StreamSubscription<QuerySnapshot>? _productItemsSubscription;

  // Cache
  Map<String, ProductNameModel> _productNamesCache = {};
  Map<String, ProductBrandModel> _brandsCache = {};
  Map<String, CategoryModel> _categoriesCache = {};

  late SpeechToText _speechToText;
  bool _speechEnabled = false;
  bool _speechListening = false;
  String _speechText = '';
  double _speechConfidence = 0.0;

  @override
  void initState() {
    super.initState();
    _setupRealtimeUpdates();
    _loadPendingRequests();
    _loadUser();
    _initializeSpeech();
    _loadCacheData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _productsSubscription?.cancel();
    _productItemsSubscription?.cancel();
    _speechToText.stop();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await loadCurrentUser();
    setState(() {
      currentUser = user;
    });
  }

  Future<void> _loadCacheData() async {
    try {
      // Load product names
      final productNames = await _productNameDao.getAllProductNames();
      _productNamesCache = {for (var name in productNames) name.id!: name};

      // Load brands
      final brands = await _productBrandDao.getAllBrands();
      _brandsCache = {for (var brand in brands) brand.id!: brand};

      // Load categories
      final categories = await _productCategoryDao.getAllCategories();
      _categoriesCache = {
        for (var category in categories) category.id!: category
      };
    } catch (e) {
      print('Error loading cache data: $e');
    }
  }

  Future<void> _loadPendingRequests() async {
    setState(() {
      _isLoadingRequests = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('purchaseOrder')
          .where('status',
              whereIn: ['PENDING_APPROVAL', 'APPROVED', 'REJECTED']).get();

      final Map<String, PurchaseOrder> requests = {};
      final Map<String, PurchaseOrder> rejectedRequests = {};
      final now = DateTime.now();

      for (var doc in snapshot.docs) {
        try {
          final po = PurchaseOrder.fromFirestore(doc.data());
          if (po.lineItems.isNotEmpty) {
            final productId = po.lineItems.first.productId;

            if (po.status == POStatus.REJECTED) {
              rejectedRequests[productId] = po;
            } else {
              bool shouldBlock = false;
              if (po.status == POStatus.PENDING_APPROVAL) {
                shouldBlock = true;
              } else if (po.status == POStatus.APPROVED) {
                final daysSinceApproval = now.difference(po.createdDate).inDays;
                shouldBlock = daysSinceApproval < 7;
              }

              if (shouldBlock) {
                requests[productId] = po;
              }
            }
          }
        } catch (e) {
          print('Error parsing PO ${doc.id}: $e');
        }
      }

      setState(() {
        _pendingRequests = requests;
        _rejectedRequests = rejectedRequests;
        _isLoadingRequests = false;
      });
    } catch (e) {
      print('Error loading requests: $e');
      setState(() {
        _isLoadingRequests = false;
      });
    }
  }

  void _setupRealtimeUpdates() {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    _setupProductsListener();
    _setupProductItemsListener();
    _setupRequestsListener();
  }

  void _setupProductsListener() {
    _productsSubscription =
        FirebaseFirestore.instance.collection('products').snapshots().listen(
      (snapshot) {
        print('Products collection changed: ${snapshot.docs.length} products');
        _processInventoryData();
      },
      onError: (error) {
        print('Products listener error: $error');
        setState(() {
          errorMessage = 'Products update failed: $error';
        });
      },
    );
  }

  void _setupProductItemsListener() {
    _productItemsSubscription = FirebaseFirestore.instance
        .collection('productItems')
        .where('status', isEqualTo: ProductItemStatus.stored)
        .snapshots()
        .listen(
      (snapshot) {
        print('Product items changed: ${snapshot.docs.length} items');
        _processInventoryData();
      },
      onError: (error) {
        print('Product items listener error: $error');
        setState(() {
          errorMessage = 'Inventory update failed: $error';
        });
      },
    );
  }

  void _setupRequestsListener() {
    FirebaseFirestore.instance
        .collection('purchaseOrder')
        .where('status', whereIn: ['PENDING_APPROVAL', 'APPROVED', 'REJECTED'])
        .snapshots()
        .listen((snapshot) {
          final Map<String, PurchaseOrder> requests = {};
          final now = DateTime.now();

          for (var doc in snapshot.docs) {
            try {
              final po = PurchaseOrder.fromFirestore(doc.data());
              if (po.lineItems.isNotEmpty) {
                final productId = po.lineItems.first.productId;

                if (po.status == POStatus.PENDING_APPROVAL) {
                  requests[productId] = po;
                } else if (po.status == POStatus.APPROVED) {
                  final daysSinceApproval =
                      now.difference(po.createdDate).inDays;
                  if (daysSinceApproval < 7) {
                    requests[productId] = po;
                  }
                }
              }
            } catch (e) {
              print('Error parsing PO ${doc.id}: $e');
            }
          }

          setState(() {
            _pendingRequests = requests;
          });
        });
  }

  Future<void> _processInventoryData() async {
    try {
      // Get products and product items
      final productsSnapshot =
          await FirebaseFirestore.instance.collection('products').get();

      final productItemsSnapshot = await FirebaseFirestore.instance
          .collection('productItems')
          .where('status', isEqualTo: ProductItemStatus.stored)
          .get();

      // Group product items by product ID
      final Map<String, List<ProductItem>> itemsByProduct = {};
      for (var doc in productItemsSnapshot.docs) {
        try {
          final item = ProductItem.fromFirestore(doc);
          itemsByProduct.putIfAbsent(item.productId, () => []).add(item);
        } catch (e) {
          print('Error parsing product item ${doc.id}: $e');
        }
      }

      // Create inventory items
      final List<ProductInventoryItem> items = [];
      final Set<String> zones = {};
      final Set<String> categories = {};
      final Set<String> brands = {};

      for (var productDoc in productsSnapshot.docs) {
        try {
          final product =
              Product.fromFirestore(productDoc.id, productDoc.data());
          final productItems = itemsByProduct[product.id] ?? [];

          // Process ALL products, even those with no stored items
          // Get locations from warehouse locations (if product has stored items)
          final locations = <ProductItemLocation>[];
          final purchaseOrderIds = <String>{};
          final supplierNames = <String>{};
          final storedDates = <DateTime>[];

          // Group items by location
          final Map<String, List<ProductItem>> itemsByLocation = {};
          for (var item in productItems) {
            if (item.location != null) {
              itemsByLocation.putIfAbsent(item.location!, () => []).add(item);
              if (item.purchaseOrderId.isNotEmpty) {
                purchaseOrderIds.add(item.purchaseOrderId);
              }
            }
          }

          // Get location details and create ProductItemLocation objects
          for (var locationEntry in itemsByLocation.entries) {
            final locationId = locationEntry.key;
            final itemsAtLocation = locationEntry.value;

            try {
              final locationDoc = await FirebaseFirestore.instance
                  .collection('warehouseLocations')
                  .doc(locationId)
                  .get();

              if (locationDoc.exists) {
                final locationData = locationDoc.data()!;
                final zoneId = locationData['zoneId'] ?? 'Unknown';
                zones.add('Zone $zoneId');

                // Get supplier info from metadata or PO
                String? supplierName;
                DateTime? storedDate;
                String? purchaseOrderId;

                if (itemsAtLocation.isNotEmpty) {
                  final firstItem = itemsAtLocation.first;
                  purchaseOrderId = firstItem.purchaseOrderId;

                  // Try to get supplier from purchase order
                  if (purchaseOrderId.isNotEmpty) {
                    try {
                      final poDoc = await FirebaseFirestore.instance
                          .collection('purchaseOrder')
                          .doc(purchaseOrderId)
                          .get();
                      if (poDoc.exists) {
                        final poData = poDoc.data()!;
                        supplierName = poData['supplierName'] as String?;
                        storedDate =
                            (poData['createdDate'] as Timestamp?)?.toDate();
                      }
                    } catch (e) {
                      print('Error getting PO data: $e');
                    }
                  }
                }

                if (supplierName != null) supplierNames.add(supplierName);
                if (storedDate != null) storedDates.add(storedDate);

                locations.add(ProductItemLocation(
                  zoneId: zoneId,
                  locationId: locationId,
                  quantity: itemsAtLocation.length,
                  storedDate: storedDate,
                  purchaseOrderId: purchaseOrderId,
                  supplierName: supplierName,
                ));
              }
            } catch (e) {
              print('Error getting location details for $locationId: $e');
            }
          }

          // Get resolved names for ALL products (whether they have inventory or not)
          final productName = _productNamesCache[product.name];
          final brand = _brandsCache[product.brand];
          final category = _categoriesCache[product.category];

          // Add to filter options (include all categories/brands, not just those with inventory)
          if (category != null) {
            final categoryName = category.name;
            if (!categories.contains(categoryName)) {
              categories.add(categoryName);
            }
          } else {
            // If category not found in cache, add "Unknown Category"
            if (!categories.contains('Unknown Category')) {
              categories.add('Unknown Category');
            }
          }

          if (brand != null) {
            final brandName = brand.brandName;
            if (!brands.contains(brandName)) {
              brands.add(brandName);
            }
          } else {
            // If brand not found in cache, add "Unknown Brand"
            if (!brands.contains('Unknown Brand')) {
              brands.add('Unknown Brand');
            }
          }

          storedDates.sort();

          // Create inventory item for ALL products (including those with 0 quantity)
          final inventoryItem = ProductInventoryItem(
            product: product,
            productName: productName,
            brand: brand,
            category: category,
            totalQuantityStored: productItems.length,
            // This will be 0 for products with no stored items
            locations: locations,
            // This will be empty for products with no stored items
            purchaseOrderNumbers: purchaseOrderIds,
            supplierNames: supplierNames,
            firstStoredDate: storedDates.isNotEmpty ? storedDates.first : null,
            lastStoredDate: storedDates.isNotEmpty ? storedDates.last : null,
          );

          items.add(inventoryItem);
        } catch (e) {
          print('Error processing product ${productDoc.id}: $e');
        }
      }

      // Update filter options
      final sortedZones = zones.toList()..sort();
      final sortedCategories = categories.toList()..sort();
      final sortedBrands = brands.toList()..sort();

      setState(() {
        inventoryItems = items;
        availableZones = ['All', ...sortedZones];
        availableCategories = ['All', ...sortedCategories];
        availableBrands = ['All', ...sortedBrands];
        isLoading = false;
        errorMessage = null;
      });

      _applyFilters();
      print('Processed ${items.length} inventory items');
    } catch (e) {
      print('Error processing inventory data: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to process inventory: $e';
      });
    }
  }

  bool _hasPendingRequest(String productId) {
    return _pendingRequests.containsKey(productId);
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

  bool _isLowStock(ProductInventoryItem item) {
    return item.totalQuantityStored <= LOW_STOCK_THRESHOLD;
  }

  bool _isCriticalStock(ProductInventoryItem item) {
    return item.totalQuantityStored <= CRITICAL_STOCK_THRESHOLD;
  }

  void _initializeSpeech() async {
    _speechToText = SpeechToText();
    _speechEnabled = await _speechToText.initialize(
      onError: (error) {
        print('Speech recognition error: $error');
        setState(() {
          _speechListening = false;
        });
        _showSnackBar(
            'Speech recognition error: ${error.errorMsg}', Colors.red);
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
      _showSnackBar(
          'Speech recognition not available on this device', Colors.orange);
    }
  }

  void _startListening() async {
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

    _showSnackBar(
        'Listening... Say part name, part number, or category', Colors.blue);

    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _speechText = result.recognizedWords;
          _speechConfidence = result.confidence;
        });

        _searchController.text = _speechText;
        searchQuery = _speechText;
        _applyFilters();
      },
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 5),
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

  Future<void> _refreshInventory() async {
    await _productsSubscription?.cancel();
    await _productItemsSubscription?.cancel();
    await _loadCacheData();
    _setupRealtimeUpdates();
  }

  void _applyFilters() {
    List<ProductInventoryItem> filtered = List.from(inventoryItems);

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        return item.displayName.toLowerCase().contains(query) ||
            item.partNumber.toLowerCase().contains(query) ||
            item.displayCategory.toLowerCase().contains(query) ||
            item.displayBrand.toLowerCase().contains(query) ||
            (item.compatibilitySummary.toLowerCase().contains(query)) ||
            (item.oem?.toLowerCase().contains(query) ?? false) ||
            item.purchaseOrderNumbers
                .any((po) => po.toLowerCase().contains(query)) ||
            item.supplierNames
                .any((supplier) => supplier.toLowerCase().contains(query)) ||
            item.locations
                .any((loc) => loc.locationId.toLowerCase().contains(query));
      }).toList();
    }

    // Apply zone filter
    if (selectedZone != 'All') {
      final zoneNumber = selectedZone.replaceFirst('Zone ', '');
      filtered = filtered.where((item) {
        return item.locations.any((loc) => loc.zoneId == zoneNumber);
      }).toList();
    }

    // Apply category filter
    if (selectedCategory != 'All') {
      filtered = filtered
          .where((item) => item.displayCategory == selectedCategory)
          .toList();
    }

    // Apply brand filter
    if (selectedBrand != 'All') {
      filtered =
          filtered.where((item) => item.displayBrand == selectedBrand).toList();
    }

    // Apply condition filter
    if (selectedCondition != 'All') {
      filtered = filtered
          .where((item) => item.condition == selectedCondition)
          .toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      int comparison;
      switch (sortBy) {
        case 'name':
          comparison = a.displayName.compareTo(b.displayName);
          break;
        case 'partNumber':
          comparison = a.partNumber.compareTo(b.partNumber);
          break;
        case 'quantity':
          comparison = a.totalQuantityStored.compareTo(b.totalQuantityStored);
          break;
        case 'category':
          comparison = a.displayCategory.compareTo(b.displayCategory);
          break;
        case 'brand':
          comparison = a.displayBrand.compareTo(b.displayBrand);
          break;
        case 'price':
          comparison = (a.unitPrice ?? 0).compareTo(b.unitPrice ?? 0);
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
          comparison = a.displayName.compareTo(b.displayName);
      }
      return isAscending ? comparison : -comparison;
    });

    setState(() {
      filteredItems = filtered;
    });
  }

  void _showSnackBar(String message, Color backgroundColor) {
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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildSearchSuffixIcons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
                  'Listening for car parts...',
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
      barrierDismissible: false,
      builder: (context) => const QRScannerDialog(
        productDetails: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // appBar: AppBar(
      //   title: const Text(
      //     'Products Inventory',
      //     style: TextStyle(fontWeight: FontWeight.w600),
      //   ),
      //   backgroundColor: Colors.blue[700],
      //   foregroundColor: Colors.white,
      //   elevation: 2,
      //   actions: [
      //     IconButton(
      //       icon: const Icon(Icons.refresh),
      //       onPressed: _refreshInventory,
      //       tooltip: 'Refresh Inventory',
      //     ),
      //   ],
      // ),
      body: isLoading
          ? _buildLoadingScreen()
          : errorMessage != null
              ? _buildErrorScreen()
              : Column(
                  children: [
                    _buildSearchAndFilters(),
                    _buildStatsBar(),
                    Expanded(
                      child: filteredItems.isEmpty
                          ? _buildEmptyState()
                          : _buildItemsList(),
                    ),
                  ],
                ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _showQRScannerPopup,
      //   backgroundColor: Colors.blue[600],
      //   child: const Icon(Icons.qr_code_scanner, color: Colors.white),
      //   tooltip: 'Scan QR Code',
      // ),
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
            'Loading products inventory...',
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
            Icon(Icons.car_repair, size: 64, color: Colors.red[300]),
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
                    hintText:
                        'Search parts by name, part number, brand, category...',
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

          _buildSpeechStatus(),

          const SizedBox(height: 12),
          // Filter chips
          Row(
            children: [
              Expanded(child: _buildZoneFilter()),
              const SizedBox(width: 8),
              Expanded(child: _buildCategoryFilter()),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildBrandFilter()),
              const SizedBox(width: 8),
              Expanded(child: _buildConditionFilter()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZoneFilter() {
    return DropdownButtonFormField<String>(
      dropdownColor: Colors.white,
      value: selectedZone,
      decoration: InputDecoration(
        labelText: 'Zone',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: availableZones.map((zone) {
        return DropdownMenuItem(
          value: zone,
          child: Text(zone, style: const TextStyle(fontSize: 14)),
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
      dropdownColor: Colors.white,
      decoration: InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: availableCategories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Text(category, style: const TextStyle(fontSize: 14)),
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

  Widget _buildBrandFilter() {
    return DropdownButtonFormField<String>(
      value: selectedBrand,
      dropdownColor: Colors.white,
      decoration: InputDecoration(
        labelText: 'Brand',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: availableBrands.map((brand) {
        return DropdownMenuItem(
          value: brand,
          child: Text(brand, style: const TextStyle(fontSize: 14)),
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

  Widget _buildConditionFilter() {
    return DropdownButtonFormField<String>(
      value: selectedCondition,
      dropdownColor: Colors.white,
      decoration: InputDecoration(
        labelText: 'Condition',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: availableConditions.map((condition) {
        return DropdownMenuItem(
          value: condition,
          child: Text(condition, style: const TextStyle(fontSize: 14)),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedCondition = value!;
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
        _buildSortMenuItem('name', 'Part Name', Icons.text_fields),
        _buildSortMenuItem('partNumber', 'Part Number', Icons.tag),
        _buildSortMenuItem('quantity', 'Stock Level', Icons.numbers),
        _buildSortMenuItem('category', 'Category', Icons.category),
        _buildSortMenuItem('brand', 'Brand', Icons.business),
        _buildSortMenuItem('price', 'Price', Icons.attach_money),
        _buildSortMenuItem('date', 'Date Stored', Icons.schedule),
        _buildSortMenuItem('locations', 'Location Count', Icons.location_on),
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
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
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
    final totalParts = filteredItems.length;
    final partsWithInventory =
        filteredItems.where((item) => item.totalQuantityStored > 0).length;
    final partsWithoutInventory = totalParts - partsWithInventory;
    final totalQuantity =
        filteredItems.fold<int>(0, (sum, p) => sum + p.totalQuantityStored);
    final uniqueLocations = filteredItems
        .where((item) => item.locations.isNotEmpty)
        .expand((p) => p.locations)
        .map((l) => l.locationId)
        .toSet()
        .length;
    final lowStockCount = filteredItems.where(_isLowStock).length;
    final criticalStockCount = filteredItems.where(_isCriticalStock).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildStatChip('$totalParts products', Colors.blue),
          _buildStatChip('$partsWithInventory in stock', Colors.green),
          if (partsWithoutInventory > 0)
            _buildStatChip('$partsWithoutInventory no stock', Colors.grey),
          _buildStatChip('$totalQuantity total qty', Colors.green),
          if (uniqueLocations > 0)
            _buildStatChip('$uniqueLocations locations', Colors.purple),
          if (lowStockCount > 0)
            _buildStatChip('$lowStockCount low stock', Colors.orange),
          if (criticalStockCount > 0)
            _buildStatChip('$criticalStockCount critical', Colors.red),
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
            Icon(Icons.car_repair, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'No Products Found',
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
                  : 'No products have been added yet',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            if (searchQuery.isNotEmpty ||
                selectedZone != 'All' ||
                selectedCategory != 'All' ||
                selectedBrand != 'All') ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    searchQuery = '';
                    selectedZone = 'All';
                    selectedCategory = 'All';
                    selectedBrand = 'All';
                    selectedCondition = 'All';
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

  Widget _buildItemsList() {
    return RefreshIndicator(
      onRefresh: _refreshInventory,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: filteredItems.length,
        itemBuilder: (context, index) {
          final item = filteredItems[index];
          return _buildItemCard(item);
        },
      ),
    );
  }

  Widget _buildItemCard(ProductInventoryItem item) {
    final hasPendingRequest = _hasPendingRequest(item.product.id!);
    final hasRejectedRequest = _hasRejectedRequest(item.product.id!);
    final requestStatus = _getRequestStatus(item.product.id!);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(
                productId: item.product.id!,
                // initialProductName: item.displayName,
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
                          item.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Text(
                                item.product.id == null
                                    ? 'N/A'
                                    : item.product.id!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.displayCategory,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (hasRejectedRequest && !hasPendingRequest) ...[
                              const SizedBox(width: 8),
                              _buildRejectedRequestChip(item.product.id!),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    color: Colors.white,
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (action) => _handleMenuAction(action, item),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility,
                                size: 18, color: Colors.blue),
                            SizedBox(width: 12),
                            Text('View Details'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18, color: Colors.orange),
                            SizedBox(width: 12),
                            Text('Edit Details'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'qr',
                        child: Row(
                          children: [
                            Icon(Icons.qr_code, size: 18, color: Colors.green),
                            SizedBox(width: 12),
                            Text('Generate QR'),
                          ],
                        ),
                      ),
                      if (_isLowStock(item)) ...[
                        if (hasPendingRequest) ...[
                          PopupMenuItem(
                            value: 'view_request',
                            child: Row(
                              children: [
                                Icon(Icons.pending_actions,
                                    size: 16, color: Colors.blue[600]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'View Request',
                                        style: TextStyle(
                                          color: Colors.blue[600],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'by ${_getRequestCreator(item.product.id!)}',
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
                          PopupMenuItem(
                            value: 'try_again',
                            child: Row(
                              children: [
                                Icon(Icons.refresh,
                                    size: 16, color: Colors.green[600]),
                                const SizedBox(width: 8),
                                Text(
                                  'Try Request Again',
                                  style: TextStyle(color: Colors.green[600]),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          PopupMenuItem(
                            value: 'request_po',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.shopping_cart,
                                  size: 16,
                                  color: _isCriticalStock(item)
                                      ? Colors.red
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isCriticalStock(item)
                                      ? 'Urgent Part Order'
                                      : 'Request Part',
                                  style: TextStyle(
                                    color: _isCriticalStock(item)
                                        ? Colors.red
                                        : Colors.orange,
                                    fontWeight: _isCriticalStock(item)
                                        ? FontWeight.w600
                                        : FontWeight.normal,
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

              // Brand and compatibility row
              if (item.displayBrand.isNotEmpty ||
                  item.compatibilitySummary.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      if (item.displayBrand.isNotEmpty &&
                          item.displayBrand != 'Unknown Brand') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.business,
                                  size: 12, color: Colors.green[700]),
                              const SizedBox(width: 4),
                              Text(
                                item.displayBrand,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          'Fits: ${item.compatibilitySummary}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              // Key metrics row
              Row(
                children: [
                  _buildMetricChip(
                    '${item.totalQuantityStored}',
                    'In Stock',
                    _isCriticalStock(item)
                        ? Colors.red
                        : _isLowStock(item)
                            ? Colors.orange
                            : Colors.blue,
                    Icons.inventory,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricChip(
                    '${item.locations.length}',
                    'Locations',
                    Colors.blue,
                    Icons.location_on,
                  ),
                  if (item.unitPrice != null) ...[
                    const SizedBox(width: 8),
                    _buildMetricChip(
                      '\$${item.unitPrice!.toStringAsFixed(2)}',
                      'Price',
                      Colors.purple,
                      Icons.attach_money,
                    ),
                  ],
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.condition == 'New'
                          ? Colors.green[50]
                          : item.condition == 'Used'
                              ? Colors.orange[50]
                              : Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: item.condition == 'New'
                            ? Colors.green[200]!
                            : item.condition == 'Used'
                                ? Colors.orange[200]!
                                : Colors.blue[200]!,
                      ),
                    ),
                    child: Text(
                      item.condition ?? 'New',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: item.condition == 'New'
                            ? Colors.green[700]
                            : item.condition == 'Used'
                                ? Colors.orange[700]
                                : Colors.blue[700],
                      ),
                    ),
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
                        Icon(Icons.warehouse,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Storage Locations:',
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
                      item.locationSummary,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.locations.length > 1) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: item.locations.take(3).map((location) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Text(
                              'Zone ${location.zoneId}: ${location.quantity}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (item.locations.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '+ ${item.locations.length - 3} more locations',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Additional info row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Supplier: ${item.supplierSummary}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.lastStoredDate != null)
                    Text(
                      'Last stored: ${_formatDate(item.lastStoredDate!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),

              // OEM info if available
              if (item.oem != null && item.oem!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'OEM: ${item.oem}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRejectionFeedbackDialog(ProductInventoryItem item) {
    final rejectedRequest = _getRejectedRequest(item.product.id!);
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
            Text('Part: ${item.displayName}'),
            Text('Part Number: ${item.partNumber}'),
            const SizedBox(height: 8),
            Text('Request ID: ${rejectedRequest.poNumber}'),
            const SizedBox(height: 16),
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
                    'Your part request has been rejected.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.red[800],
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You can submit a new request if needed.',
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
              _showNewRequestAfterRejection(item);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Request Again',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showNewRequestAfterRejection(ProductInventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => RequestPODialog(
        productId: item.product.id!,
        productName: item.displayName,
        category: item.displayCategory,
        currentStock: item.totalQuantityStored,
        currentPrice: item.unitPrice,
        brand: item.displayBrand,
        sku: item.partNumber,
        isCriticalStock: _isCriticalStock(item),
      ),
    ).then((poId) {
      if (poId != null) {
        _showSnackBar('New part request submitted!', Colors.green);
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

  void _showRequestDetailsDialog(ProductInventoryItem item) {
    final request = _pendingRequests[item.product.id!];
    if (request == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Part Order Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request ID: ${request.poNumber}'),
            const SizedBox(height: 8),
            Text('Status: ${request.status.toString().split('.').last}'),
            const SizedBox(height: 8),
            Text('Requested by: ${request.createdByUserName}'),
            const SizedBox(height: 8),
            Text('Created: ${_formatDate(request.createdDate)}'),
            const SizedBox(height: 8),
            Text(
                'Expected Delivery: ${request.expectedDeliveryDate != null ? _formatDate(request.expectedDeliveryDate!) : "Not set"}'),
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
          if (request.status == POStatus.PENDING_APPROVAL &&
              currentUser?.employeeId == request.createdByUserId)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _cancelRequest(item, request);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cancel Request'),
            ),
        ],
      ),
    );
  }

  Future<void> _cancelRequest(
      ProductInventoryItem item, PurchaseOrder request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request'),
        content: Text(
            'Are you sure you want to cancel the order request for ${item.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('purchaseOrder')
            .doc(request.id)
            .update({
          'status': 'CANCELLED',
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedByUserId': currentUser?.employeeId,
        });

        _showSnackBar('Request cancelled successfully', Colors.green);
        _loadPendingRequests();
      } catch (e) {
        _showSnackBar('Failed to cancel request', Colors.red);
      }
    }
  }

  String _getRequestCreator(String productId) {
    final request = _pendingRequests[productId];
    return request?.createdByUserName ?? '';
  }

  // Widget _buildRequestStatusChip(String status, String productId) {
  //   final request = _pendingRequests[productId];
  //   if (request == null) return const SizedBox.shrink();
  //
  //   Color color;
  //   String label;
  //   IconData icon;
  //
  //   if (request.status == POStatus.PENDING_APPROVAL) {
  //     color = Colors.orange;
  //     label = 'Pending Approval';
  //     icon = Icons.pending;
  //   } else if (request.status == POStatus.APPROVED) {
  //     final daysSinceApproval = DateTime.now().difference(request.createdDate).inDays;
  //     color = Colors.blue;
  //     label = 'Approved ${daysSinceApproval}d ago';
  //     icon = Icons.local_shipping;
  //   } else {
  //     return const SizedBox.shrink();
  //   }
  //
  //   final creator = _getRequestCreator(productId);
  //
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  //     decoration: BoxDecoration(
  //       color: color.withOpacity(0.1),
  //       borderRadius: BorderRadius.circular(12),
  //       border: Border.all(color: color.withOpacity(0.3)),
  //     ),
  //     child: Row(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         Icon(icon, size: 12, color: color),
  //         const SizedBox(width: 4),
  //         Text(
  //           creator.isNotEmpty ? '$label by $creator' : label,
  //           style: TextStyle(
  //             fontSize: 10,
  //             color: color,
  //             fontWeight: FontWeight.w600,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

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

  void _handleMenuAction(String action, ProductInventoryItem item) {
    print(
        '🔍 DEBUG: _handleMenuAction called with action: $action, productId: ${item.product.id}');
    switch (action) {
      case 'view':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              productId: item.product.id,
              // initialProductName: item.displayName,
            ),
          ),
        );
        break;
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductEditScreen(
              product: item.product,
              productBrand: item.brand,
              productCategory: item.category,
              productName: item.productName,
            ),
          ),
        );
        break;
      case 'qr':
        showDialog(
          context: context,
          builder: (context) => QRGeneratorDialog(
            productId: item.product.id!,
            productName: item.displayName,
            category: item.displayCategory,
            quantity: item.totalQuantityStored,
          ),
        );
        break;
      case 'request_po':
        if (_hasPendingRequest(item.product.id!)) {
          final request = _pendingRequests[item.product.id!]!;
          final creator = _getRequestCreator(item.product.id!);

          String message;
          if (request.status == POStatus.PENDING_APPROVAL) {
            message =
                'This part has a pending approval request${creator.isNotEmpty ? " by $creator" : ""}';
          } else if (request.status == POStatus.APPROVED) {
            final daysSinceApproval =
                DateTime.now().difference(request.createdDate).inDays;
            message =
                'This part has an approved order from ${daysSinceApproval} days ago${creator.isNotEmpty ? " by $creator" : ""}. Wait for delivery or contact manager.';
          } else {
            message =
                'This part already has a pending request${creator.isNotEmpty ? " by $creator" : ""}';
          }

          _showSnackBar(message, Colors.orange);
          return;
        }

        showDialog(
          context: context,
          builder: (context) => RequestPODialog(
            productId: item.product.id!,
            productName: item.displayName,
            category: item.displayCategory,
            currentStock: item.totalQuantityStored,
            currentPrice: item.unitPrice,
            brand: item.displayBrand,
            sku: item.partNumber,
            isCriticalStock: _isCriticalStock(item),
          ),
        ).then((poId) {
          if (poId != null) {
            _showSnackBar(
              'Part order request submitted! Managers will review request $poId',
              Colors.green,
            );
            _loadPendingRequests();
          }
        });
        break;
      case 'view_request':
        _showRequestDetailsDialog(item);
        break;
      case 'try_again':
        _showRejectionFeedbackDialog(item);
        break;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}