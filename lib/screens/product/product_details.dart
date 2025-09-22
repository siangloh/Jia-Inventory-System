import 'package:assignment/screens/product/product_item_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:assignment/models/products_model.dart';
import 'package:assignment/models/product_item.dart';
import 'package:assignment/models/product_name_model.dart';
import 'package:assignment/models/product_brand_model.dart';
import 'package:assignment/models/product_category_model.dart';
import 'package:assignment/models/purchase_order.dart';
import 'package:assignment/models/user_model.dart';
import 'package:assignment/dao/product_name_dao.dart';
import 'package:assignment/dao/product_brand_dao.dart';
import 'package:assignment/dao/product_category_dao.dart';
import 'package:assignment/widgets/purchase_order/request_po_dialog.dart';
import 'package:assignment/services/login/load_user_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:assignment/widgets/qr/qr_generator_dialog.dart';
import 'package:assignment/services/product_image_service.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../widgets/barcode_scanner.dart';
import '../../widgets/qr/qr_scanner_dialog.dart';

// Enhanced ProductItem with location details for the Items tab
class ProductItemWithDetails {
  final ProductItem item;
  final String? locationName;
  final String? zoneName;
  final String? supplierName;
  final DateTime? storedDate;

  ProductItemWithDetails({
    required this.item,
    this.locationName,
    this.zoneName,
    this.supplierName,
    this.storedDate,
  });
}

// Move ProductItemLocation class to the top, outside other classes
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

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({
    super.key,
    required this.productId,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // Speech recognition variables
  late SpeechToText _speechToText;
  bool _speechEnabled = false;
  bool _speechListening = false;
  String _speechText = '';
  double _speechConfidence = 0.0;

  // Data models
  Product? product;
  ProductNameModel? productName;
  ProductBrandModel? productBrand;
  CategoryModel? productCategory;
  List<ProductItem> storedItems = [];
  List<ProductItemWithDetails> itemsWithDetails = [];
  List<ProductItemWithDetails> filteredItems = [];
  List<ProductItemLocation> locations = [];
  List<String> productImages = [];

  // Loading states
  bool isLoading = true;
  String? errorMessage;

  // Items tab search and filtering
  final TextEditingController _itemsSearchController = TextEditingController();
  String itemsSearchQuery = '';
  String selectedItemZone = 'All';
  String selectedItemStatus = 'All';
  String selectedItemSupplier = 'All';
  String itemsSortBy = 'date';
  bool itemsIsAscending = false;

  // Filter options for items
  List<String> availableItemZones = ['All'];
  List<String> availableItemStatuses = ['All'];
  List<String> availableItemSuppliers = ['All'];

  // Stock management
  Map<String, PurchaseOrder?> _pendingRequests = {};
  Map<String, PurchaseOrder?> _rejectedRequests = {};
  bool _isLoadingRequests = false;
  UserModel? currentUser;

  static const int LOW_STOCK_THRESHOLD = 5;
  static const int CRITICAL_STOCK_THRESHOLD = 2;

  // Real-time subscriptions
  StreamSubscription<DocumentSnapshot>? _productSubscription;
  StreamSubscription<QuerySnapshot>? _productItemsSubscription;

  // DAOs
  final ProductNameDao _productNameDao = ProductNameDao();
  final ProductBrandDAO _productBrandDao = ProductBrandDAO();
  final CategoryDao _productCategoryDao = CategoryDao();

  // QR Code key for PDF generation
  final GlobalKey _qrKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Start with 3 tabs
    _setupRealtimeUpdates();
    _loadUser();
    _loadPendingRequests();
    _initializeSpeech();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _productSubscription?.cancel();
    _productItemsSubscription?.cancel();
    _itemsSearchController.dispose();
    _speechToText.stop();
    super.dispose();
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
        'Listening... Say item ID, location, zone, or supplier', Colors.blue);

    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _speechText = result.recognizedWords;
          _speechConfidence = result.confidence;
        });

        _itemsSearchController.text = _speechText;
        itemsSearchQuery = _speechText;
        _applyItemsFilters();
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

  void _showQRScannerPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const QRScannerDialog(productDetails: true),
    );
  }

  void _showBarcodeScannerPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BarcodeScannerDialog(
        productDetails: true,
        title: 'Scan Item Barcode',
        hint: 'Scan to navigate to item details',
        autoNavigate: true,
        // Always enable auto-navigation
        parentContext: context,
        // Pass the parent context for navigation
        onBarcodeScanned: (String barcode) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductItemDetailsScreen(
                productItemId: barcode,
              ),
            ),
          );
          // Optional additional handling
          print('Barcode scanned: $barcode');
        },
      ),
    );
  }

  void _showBarcodeScannerForSearch() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BarcodeScannerDialog(
        productDetails: true,
        title: 'Scan Item Barcode',
        hint: 'Scan barcode to search for specific items',
        autoNavigate: false,
        // Disable auto-navigation for search mode
        onBarcodeScanned: (String barcode) {
          // Handle the scanned barcode for search
          _handleScannedBarcode(barcode);
        },
      ),
    );
  }

// Add this method to handle the scanned barcode:
  void _handleScannedBarcode(String barcode) {
    // Set the search field with the scanned barcode
    _itemsSearchController.text = barcode;
    setState(() {
      itemsSearchQuery = barcode;
    });
    _applyItemsFilters();

    // Show feedback to user
    _showSnackBar('Searching for barcode: $barcode', Colors.green);

    // Check if any items match the barcode
    final matchingItems = filteredItems.where((item) {
      return item.item.productId
          .toLowerCase()
          .contains(barcode.toLowerCase()) ||
          item.item.itemId.toLowerCase().contains(barcode.toLowerCase()) ||
          (item.locationName?.toLowerCase().contains(barcode.toLowerCase()) ??
              false) ||
          (item.supplierName?.toLowerCase().contains(barcode.toLowerCase()) ??
              false);
    }).toList();

    if (matchingItems.isEmpty) {
      // Show dialog if no matches found
      Future.delayed(const Duration(milliseconds: 500), () {
        _showNoMatchesDialog(barcode);
      });
    } else {
      // Show success feedback
      _showSnackBar(
          'Found ${matchingItems.length} matching item(s)', Colors.green);

      // If only one match, optionally show it directly
      if (matchingItems.length == 1) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          _showItemQuickView(matchingItems.first);
        });
      }
    }
  }

  // NEW: Show no matches dialog with better options
  void _showNoMatchesDialog(String barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.search_off, color: Colors.orange[600]),
            const SizedBox(width: 8),
            const Text('No Matches Found'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No items found matching barcode:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.barcode_reader, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      barcode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Suggestions:'),
            const SizedBox(height: 8),
            Text('• Check if the barcode was scanned correctly',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text('• Try scanning the barcode again',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text('• Verify the item exists in this product',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _itemsSearchController.clear();
              setState(() {
                itemsSearchQuery = '';
              });
              _applyItemsFilters();
            },
            child: const Text('Clear Search'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Search'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showBarcodeScannerPopup();
            },
            child: const Text('Scan Again'),
          ),
        ],
      ),
    );
  }

  // NEW: Quick view for single item match
  void _showItemQuickView(ProductItemWithDetails itemWithDetails) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600]),
            const SizedBox(width: 8),
            const Text('Item Found'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Item ID: ${itemWithDetails.item.itemId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (itemWithDetails.locationName != null)
                    _buildQuickViewRow(
                        'Location', itemWithDetails.locationName!),
                  if (itemWithDetails.zoneName != null)
                    _buildQuickViewRow('Zone', itemWithDetails.zoneName!),
                  if (itemWithDetails.supplierName != null)
                    _buildQuickViewRow(
                        'Supplier', itemWithDetails.supplierName!),
                  _buildQuickViewRow(
                      'Status',
                      itemWithDetails.item.status
                          .toString()
                          .split('.')
                          .last
                          .toUpperCase()),
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductItemDetailsScreen(
                    productItemId: itemWithDetails.item.itemId,
                  ),
                ),
              );
            },
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }

  // NEW: Helper widget for quick view rows
  Widget _buildQuickViewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSearchSuffixIcons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Voice search button
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

        // QR scanner button
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

        // UPDATED: Direct barcode scanner button (no dropdown)
        Container(
          child: IconButton(
            icon: const Icon(
              Icons.barcode_reader,
              size: 20,
            ),
            onPressed: _showBarcodeScannerPopup,
            // Direct navigation
            tooltip: 'Scan Barcode to Navigate',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
        ),

        // Clear button
        if (itemsSearchQuery.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear, size: 20),
            onPressed: () {
              _itemsSearchController.clear();
              setState(() {
                itemsSearchQuery = '';
                _speechText = '';
              });
              _applyItemsFilters();
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

  Widget _buildItemsSpeechStatus() {
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
                  'Listening for items...',
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

            if (productId == widget.productId) {
              if (po.status == POStatus.REJECTED) {
                rejectedRequests[productId] = po;
              } else {
                bool shouldBlock = false;
                if (po.status == POStatus.PENDING_APPROVAL) {
                  shouldBlock = true;
                } else if (po.status == POStatus.APPROVED) {
                  final daysSinceApproval =
                      now.difference(po.createdDate).inDays;
                  shouldBlock = daysSinceApproval < 7;
                }

                if (shouldBlock) {
                  requests[productId] = po;
                }
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

  bool _isLowStock() {
    return getTotalQuantity() <= LOW_STOCK_THRESHOLD && getTotalQuantity() > 0;
  }

  bool _isCriticalStock() {
    return getTotalQuantity() <= CRITICAL_STOCK_THRESHOLD &&
        getTotalQuantity() > 0;
  }

  bool _hasPendingRequest() {
    return _pendingRequests.containsKey(widget.productId);
  }

  bool _hasRejectedRequest() {
    return _rejectedRequests.containsKey(widget.productId);
  }

  void _setupRealtimeUpdates() {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    _setupProductListener();
    _setupProductItemsListener();
  }

  void _setupProductListener() {
    _productSubscription = FirebaseFirestore.instance
        .collection('products')
        .doc(widget.productId)
        .snapshots()
        .listen(
          (snapshot) async {
        print('Product data changed for ${widget.productId}');

        if (snapshot.exists) {
          final data = snapshot.data()!;
          product = Product.fromFirestore(widget.productId, data);
          await _loadResolvedData();
          await _loadProductImages();
          print('Product data updated: ${product?.name}');
        } else {
          product = null;
          productName = null;
          productBrand = null;
          productCategory = null;
          print('Product document not found');
        }

        await _combineData();
      },
      onError: (error) {
        print('Product listener error: $error');
        setState(() {
          errorMessage = 'Failed to load product details: $error';
        });
      },
    );
  }

  bool isLoadingItems = false;

  void _setupProductItemsListener() {
    // Set loading state when starting to load items
    setState(() {
      isLoadingItems = true;
    });

    _productItemsSubscription = FirebaseFirestore.instance
        .collection('productItems')
        .where('productId', isEqualTo: widget.productId)
        .where('status', isEqualTo: ProductItemStatus.stored)
        .snapshots()
        .listen(
          (snapshot) async {
        print(
            'Product items changed for ${widget.productId}: ${snapshot.docs.length} items');

        storedItems = snapshot.docs
            .map((doc) {
          try {
            return ProductItem.fromFirestore(doc);
          } catch (e) {
            print('Error converting product item ${doc.id}: $e');
            return null;
          }
        })
            .where((item) => item != null)
            .cast<ProductItem>()
            .toList();

        await _loadLocationData();
        await _loadItemsWithDetails();
        await _combineData();

        // Set loading complete after all data is loaded
        setState(() {
          isLoadingItems = false;
        });
      },
      onError: (error) {
        print('Product items listener error: $error');
        setState(() {
          errorMessage = 'Failed to load inventory data: $error';
          isLoadingItems = false; // Stop loading on error
        });
      },
    );
  }

  Future<void> _loadResolvedData() async {
    if (product == null) return;

    try {
      if (product!.name.isNotEmpty) {
        productName = await _productNameDao.getProductNameById(product!.name);
      }

      if (product!.brand.isNotEmpty) {
        productBrand = await _productBrandDao.getBrandById(product!.brand);
      }

      if (product!.category.isNotEmpty) {
        productCategory =
        await _productCategoryDao.getCategoryById(product!.category);
      }
    } catch (e) {
      print('Error loading resolved data: $e');
    }
  }

  Future<void> _loadProductImages() async {
    if (product == null) return;

    try {
      print('Loading product images...');
      final imageUrls = product!.metadata['images'] as List<dynamic>?;
      if (imageUrls != null) {
        productImages = imageUrls.cast<String>();
        print(
            'Found ${productImages.length} images in metadata: $productImages');
      } else {
        print('No images found in product metadata');
        try {
          final imagesSnapshot = await FirebaseFirestore.instance
              .collection('productImages')
              .where('productId', isEqualTo: widget.productId)
              .orderBy('order', descending: false)
              .get();

          productImages = imagesSnapshot.docs
              .map((doc) => doc.data()['imageUrl'] as String?)
              .where((url) => url != null && url.isNotEmpty)
              .cast<String>()
              .toList();

          print('Found ${productImages.length} images in separate collection');
        } catch (e) {
          print('Error loading from productImages collection: $e');
        }
      }
    } catch (e) {
      print('Error loading product images: $e');
      productImages = [];
    }
  }

  Future<void> _loadLocationData() async {
    locations.clear();

    if (storedItems.isEmpty) return;

    try {
      final Map<String, List<ProductItem>> itemsByLocation = {};
      for (var item in storedItems) {
        if (item.location != null && item.location!.isNotEmpty) {
          itemsByLocation.putIfAbsent(item.location!, () => []).add(item);
        }
      }

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

            String? supplierName;
            String? purchaseOrderId;
            DateTime? storedDate;

            if (itemsAtLocation.isNotEmpty) {
              final firstItem = itemsAtLocation.first;
              purchaseOrderId = firstItem.purchaseOrderId;

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
    } catch (e) {
      print('Error loading location data: $e');
    }
  }

  Future<void> _loadItemsWithDetails() async {
    if (storedItems.isEmpty) {
      setState(() {
        itemsWithDetails = [];
        filteredItems = [];
        availableItemZones = ['All'];
        availableItemSuppliers = ['All'];
        availableItemStatuses = ['All', 'Stored', 'In Transit', 'Delivered'];
      });
      return;
    }

    final List<ProductItemWithDetails> details = [];
    final Set<String> zones = {};
    final Set<String> suppliers = {};

    // Show progress for longer operations
    for (int i = 0; i < storedItems.length; i++) {
      final item = storedItems[i];
      String? locationName;
      String? zoneName;
      String? supplierName;
      DateTime? storedDate;

      // Get location details
      if (item.location != null && item.location!.isNotEmpty) {
        try {
          final locationDoc = await FirebaseFirestore.instance
              .collection('warehouseLocations')
              .doc(item.location!)
              .get();

          if (locationDoc.exists) {
            final locationData = locationDoc.data()!;
            final zoneId = locationData['zoneId'] ?? 'Unknown';
            locationName = item.location!;
            zoneName = 'Zone $zoneId';
            zones.add(zoneName);
          }
        } catch (e) {
          print('Error getting location details: $e');
        }
      }

      // Get supplier details from PO
      if (item.purchaseOrderId.isNotEmpty) {
        try {
          final poDoc = await FirebaseFirestore.instance
              .collection('purchaseOrder')
              .doc(item.purchaseOrderId)
              .get();
          if (poDoc.exists) {
            final poData = poDoc.data()!;
            supplierName = poData['supplierName'] as String?;
            storedDate = (poData['createdDate'] as Timestamp?)?.toDate();
            if (supplierName != null) suppliers.add(supplierName);
          }
        } catch (e) {
          print('Error getting PO details: $e');
        }
      }

      details.add(ProductItemWithDetails(
        item: item,
        locationName: locationName,
        zoneName: zoneName,
        supplierName: supplierName,
        storedDate: storedDate,
      ));

      // Update state periodically during loading for large datasets
      if (storedItems.length > 20 && (i + 1) % 10 == 0) {
        setState(() {
          // Partial update to show progress
        });
        // Small delay to prevent UI blocking
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }

    setState(() {
      itemsWithDetails = details;
      availableItemZones = ['All', ...zones.toList()..sort()];
      availableItemSuppliers = ['All', ...suppliers.toList()..sort()];
      availableItemStatuses = ['All', 'Stored', 'In Transit', 'Delivered'];
    });

    _applyItemsFilters();
  }

  void _applyItemsFilters() {
    List<ProductItemWithDetails> filtered = List.from(itemsWithDetails);

    // Search filter
    if (itemsSearchQuery.isNotEmpty) {
      final query = itemsSearchQuery.toLowerCase();
      filtered = filtered.where((item) {
        return item.item.productId.toLowerCase().contains(query) ||
            (item.locationName?.toLowerCase().contains(query) ?? false) ||
            (item.zoneName?.toLowerCase().contains(query) ?? false) ||
            (item.supplierName?.toLowerCase().contains(query) ?? false) ||
            item.item.purchaseOrderId.toLowerCase().contains(query);
      }).toList();
    }

    // Zone filter
    if (selectedItemZone != 'All') {
      filtered =
          filtered.where((item) => item.zoneName == selectedItemZone).toList();
    }

    // Status filter
    if (selectedItemStatus != 'All') {
      filtered = filtered
          .where((item) =>
      item.item.status.toString().split('.').last ==
          selectedItemStatus.toLowerCase())
          .toList();
    }

    // Supplier filter
    if (selectedItemSupplier != 'All') {
      filtered = filtered
          .where((item) => item.supplierName == selectedItemSupplier)
          .toList();
    }

    // Sort
    filtered.sort((a, b) {
      int comparison;
      switch (itemsSortBy) {
        case 'date':
          final aDate = a.storedDate ?? DateTime(1970);
          final bDate = b.storedDate ?? DateTime(1970);
          comparison = aDate.compareTo(bDate);
          break;
        case 'location':
          comparison = (a.locationName ?? '').compareTo(b.locationName ?? '');
          break;
        case 'zone':
          comparison = (a.zoneName ?? '').compareTo(b.zoneName ?? '');
          break;
        case 'supplier':
          comparison = (a.supplierName ?? '').compareTo(b.supplierName ?? '');
          break;
        case 'id':
          comparison = a.item.productId.compareTo(b.item.productId);
          break;
        default:
          comparison = a.item.productId.compareTo(b.item.productId);
      }
      return itemsIsAscending ? comparison : -comparison;
    });

    setState(() {
      filteredItems = filtered;
    });
  }

  Future<void> _combineData() async {
    try {
      if (product == null) {
        print('Product data not available yet, waiting...');
        return;
      }

      final hasInventory = storedItems.isNotEmpty;
      final newTabCount = hasInventory
          ? 6
          : 3; // Overview, Images, Items + (Locations, History, Analytics)

      if (_tabController.length != newTabCount) {
        _tabController.dispose();
        _tabController = TabController(length: newTabCount, vsync: this);
      }

      setState(() {
        isLoading = false;
        errorMessage = null;
      });

      print('Successfully combined data for ${getDisplayName()}');
    } catch (e) {
      print('Error combining data: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to process product data: $e';
      });
    }
  }

  // Helper methods for display data
  String getDisplayName() =>
      productName?.productName ?? product?.name ?? 'Unknown Product';

  String getDisplayBrand() => productBrand?.brandName ?? 'Unknown Brand';

  String getDisplayCategory() => productCategory?.name ?? 'Unknown Category';

  int getTotalQuantity() => storedItems.length;

  String getPartNumber() => product?.partNumber ?? product?.sku ?? 'N/A';

  Set<String> getPurchaseOrderNumbers() {
    return storedItems
        .where((item) => item.purchaseOrderId.isNotEmpty)
        .map((item) => item.purchaseOrderId)
        .toSet();
  }

  Set<String> getSupplierNames() {
    return locations
        .where(
            (loc) => loc.supplierName != null && loc.supplierName!.isNotEmpty)
        .map((loc) => loc.supplierName!)
        .toSet();
  }

  Map<String, int> _getQuantityByZone() {
    final Map<String, int> zoneQuantities = {};
    for (final location in locations) {
      zoneQuantities[location.zoneId] =
          (zoneQuantities[location.zoneId] ?? 0) + location.quantity;
    }
    return zoneQuantities;
  }

  List<String> _getPOsForSupplier(String supplier) {
    return locations
        .where((loc) => loc.supplierName == supplier)
        .map((loc) => loc.purchaseOrderId ?? '')
        .where((po) => po.isNotEmpty)
        .toSet()
        .toList();
  }

  int _getQuantityForSupplier(String supplier) {
    return locations
        .where((loc) => loc.supplierName == supplier)
        .fold<int>(0, (sum, loc) => sum + loc.quantity);
  }

  String _calculateDistributionScore() {
    final totalZones = 6;
    final usedZones = locations.map((l) => l.zoneId).toSet().length;
    final efficiency = (usedZones / totalZones * 100);

    if (efficiency >= 80) return 'Excellent';
    if (efficiency >= 60) return 'Good';
    if (efficiency >= 40) return 'Fair';
    return 'Poor';
  }

  List<Map<String, dynamic>> _getStorageInsights() {
    final insights = <Map<String, dynamic>>[];

    final zoneCount = locations.map((l) => l.zoneId).toSet().length;
    if (zoneCount == 1) {
      insights.add({
        'icon': Icons.warning,
        'color': Colors.orange,
        'text': 'Single zone storage - consider diversification',
      });
    } else if (zoneCount >= 4) {
      insights.add({
        'icon': Icons.check_circle,
        'color': Colors.green,
        'text': 'Well-distributed across zones',
      });
    }

    final avgQty = getTotalQuantity() / locations.length;
    if (avgQty < 5) {
      insights.add({
        'icon': Icons.info,
        'color': Colors.blue,
        'text': 'Low density - consider consolidation',
      });
    }

    return insights;
  }

  List<Map<String, dynamic>> _getDetailedStorageInsights() {
    final insights = <Map<String, dynamic>>[];

    final zoneCount = locations.map((l) => l.zoneId).toSet().length;
    if (zoneCount == 1) {
      insights.add({
        'icon': Icons.warning,
        'color': Colors.orange,
        'title': 'Zone Concentration Risk',
        'text':
        'All items in single zone. Consider spreading across multiple zones for better accessibility and risk management.',
      });
    } else if (zoneCount >= 4) {
      insights.add({
        'icon': Icons.check_circle,
        'color': Colors.green,
        'title': 'Excellent Distribution',
        'text':
        'Items well-spread across $zoneCount zones, providing good accessibility and reduced congestion.',
      });
    }

    final avgQty = getTotalQuantity() / locations.length;
    if (avgQty < 5) {
      insights.add({
        'icon': Icons.info,
        'color': Colors.blue,
        'title': 'Storage Density',
        'text':
        'Low item density per location (${avgQty.toStringAsFixed(1)} avg). Consider consolidating to reduce handling complexity.',
      });
    } else if (avgQty > 20) {
      insights.add({
        'icon': Icons.inventory,
        'color': Colors.purple,
        'title': 'High Density Storage',
        'text':
        'High item density per location (${avgQty.toStringAsFixed(1)} avg). Efficient space utilization.',
      });
    }

    final suppliers = getSupplierNames();
    if (suppliers.length == 1) {
      insights.add({
        'icon': Icons.business,
        'color': Colors.red,
        'title': 'Single Supplier Risk',
        'text':
        'All items from one supplier. Consider diversifying supply sources for better risk management.',
      });
    } else if (suppliers.length > 1) {
      insights.add({
        'icon': Icons.diversity_3,
        'color': Colors.green,
        'title': 'Supply Chain Resilience',
        'text':
        'Multiple suppliers (${suppliers.length}) provide good supply chain resilience and competitive pricing options.',
      });
    }

    return insights;
  }

  Widget _buildRejectedRequestChip() {
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

  Widget _buildPendingRequestStatus() {
    final request = _pendingRequests[widget.productId];
    if (request == null) return const SizedBox.shrink();

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (request.status == POStatus.PENDING_APPROVAL) {
      statusColor = Colors.orange;
      statusText = 'Pending Approval';
      statusIcon = Icons.pending;
    } else if (request.status == POStatus.APPROVED) {
      statusColor = Colors.blue;
      statusText = 'Approved - Awaiting Delivery';
      statusIcon = Icons.local_shipping;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Request: ${request.poNumber} by ${request.createdByUserName}',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showRequestDetailsDialog(request),
            child: Text(
              'View Details',
              style: TextStyle(color: statusColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showRequestPODialog() {
    if (getTotalQuantity() > LOW_STOCK_THRESHOLD) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This product has sufficient stock'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => RequestPODialog(
        productId: widget.productId,
        productName: getDisplayName(),
        category: getDisplayCategory(),
        currentStock: getTotalQuantity(),
        currentPrice: product?.price,
        brand: getDisplayBrand(),
        sku: getPartNumber(),
        isCriticalStock: _isCriticalStock(),
      ),
    ).then((poId) {
      if (poId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restock request submitted! Request ID: $poId'),
            backgroundColor: Colors.green,
          ),
        );
        _loadPendingRequests();
      }
    });
  }

  void _showRequestDetailsDialog(PurchaseOrder request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restock Request Details'),
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
                _cancelRequest(request);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cancel Request'),
            ),
        ],
      ),
    );
  }

  Future<void> _cancelRequest(PurchaseOrder request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request'),
        content: Text(
            'Are you sure you want to cancel the restock request for ${getDisplayName()}?'),
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadPendingRequests();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to cancel request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleAppBarMenuAction(String action) {
    switch (action) {
      case 'refresh':
        _setupRealtimeUpdates();
        break;
      case 'export':
        _exportProductDetails();
        break;
      case 'view_request':
        final request = _pendingRequests[widget.productId];
        if (request != null) {
          _showRequestDetailsDialog(request);
        }
        break;
    }
  }

  void _exportProductDetails() {
    final details = '''
Product Details Export
=====================
Product Name: ${getDisplayName()}
Part Number: ${getPartNumber()}
Category: ${getDisplayCategory()}
Brand: ${getDisplayBrand()}
Current Stock: ${getTotalQuantity()}
Storage Locations: ${locations.length}
Total Value: ${product?.price != null ? 'RM ${(product!.price! * getTotalQuantity()).toStringAsFixed(2)}' : 'N/A'}
Suppliers: ${getSupplierNames().join(', ')}
Purchase Orders: ${getPurchaseOrderNumbers().join(', ')}
Stock Status: ${_isCriticalStock() ? 'CRITICAL' : _isLowStock() ? 'LOW' : 'NORMAL'}
Request Status: ${_hasPendingRequest() ? 'PENDING' : 'NONE'}
Export Date: ${DateTime.now().toString()}
''';

    Clipboard.setData(ClipboardData(text: details));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Product details copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // QR Code and PDF methods
  Future<void> _downloadQRCodeAsPDF() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      RenderRepaintBoundary boundary =
      _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List qrImageBytes = byteData!.buffer.asUint8List();

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Product QR Code',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        getDisplayName(),
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Category: ${getDisplayCategory()}',
                        style: const pw.TextStyle(
                            fontSize: 12, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 200,
                      height: 200,
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        border:
                        pw.Border.all(color: PdfColors.grey300, width: 2),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Center(
                        child: pw.Image(
                          pw.MemoryImage(qrImageBytes),
                          width: 160,
                          height: 160,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 30),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Product Details',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 16),
                          _buildPDFDetailRow('Product ID:', widget.productId),
                          _buildPDFDetailRow('Name:', getDisplayName()),
                          _buildPDFDetailRow('Part Number:', getPartNumber()),
                          _buildPDFDetailRow('Brand:', getDisplayBrand()),
                          _buildPDFDetailRow('Category:', getDisplayCategory()),
                          _buildPDFDetailRow(
                              'Stock Quantity:', '${getTotalQuantity()}'),
                          if (product?.price != null)
                            _buildPDFDetailRow('Unit Price:',
                                'RM ${product!.price!.toStringAsFixed(2)}'),
                          if (locations.isNotEmpty)
                            _buildPDFDetailRow(
                                'Storage Locations:', '${locations.length}'),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Instructions:',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '• Scan this QR code with your mobile app to quickly access product details',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        '• Keep this document with the physical product for easy identification',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        '• Generated on: ${DateTime.now().toString().split('.')[0]}',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      final directory = await getDownloadsDirectory();
      final file = File(
          '${directory!.path}/product_qr_${widget.productId}_${DateTime.now().millisecondsSinceEpoch}.pdf');

      await file.writeAsBytes(await pdf.save());

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('QR Code PDF saved to: ${file.path}'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      print('Error generating PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  pw.Widget _buildPDFDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  // Navigation to product item details
  void _navigateToProductItemDetails(ProductItemWithDetails itemWithDetails) {
    // TODO: Replace with actual ProductItemDetailsScreen navigation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Product Item Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Item ID', itemWithDetails.item.productId),
              _buildDetailRow('Status',
                  itemWithDetails.item.status.toString().split('.').last),
              _buildDetailRow(
                  'Location', itemWithDetails.locationName ?? 'N/A'),
              _buildDetailRow('Zone', itemWithDetails.zoneName ?? 'N/A'),
              _buildDetailRow(
                  'Supplier', itemWithDetails.supplierName ?? 'N/A'),
              _buildDetailRow(
                  'Purchase Order', itemWithDetails.item.purchaseOrderId),
              if (itemWithDetails.storedDate != null)
                _buildDetailRow(
                    'Stored Date', _formatDate(itemWithDetails.storedDate!)),
            ],
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
              // TODO: Navigate to full ProductItemDetailsScreen
              // Navigator.push(context, MaterialPageRoute(
              //   builder: (context) => ProductItemDetailsScreen(
              //     productItemId: itemWithDetails.item.id,
              //   ),
              // ));
            },
            child: const Text('View Full Details'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasInventory = getTotalQuantity() > 0;
    final isLowStock = _isLowStock();
    final isCriticalStock = _isCriticalStock();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              getDisplayName(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
            if (isLowStock)
              Text(
                isCriticalStock ? 'CRITICAL STOCK' : 'LOW STOCK',
                style: TextStyle(
                  fontSize: 11,
                  color: isCriticalStock ? Colors.red[200] : Colors.orange[200],
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        backgroundColor: isCriticalStock
            ? Colors.red[700]
            : isLowStock
            ? Colors.orange[700]
            : Colors.white,
        foregroundColor: isLowStock ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          if (isLowStock && !_hasPendingRequest())
            IconButton(
              icon: Icon(
                isCriticalStock ? Icons.priority_high : Icons.add_shopping_cart,
                color: isLowStock ? Colors.white : Colors.grey[700],
              ),
              onPressed: _showRequestPODialog,
              tooltip: isCriticalStock ? 'Urgent Reorder' : 'Request Restock',
            ),
          PopupMenuButton<String>(
            color: Colors.white,
            icon: Icon(
              Icons.more_vert,
              color: isLowStock ? Colors.white : Colors.grey[700],
            ),
            onSelected: _handleAppBarMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 16),
                    SizedBox(width: 8),
                    Text('Refresh Data'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download, size: 16),
                    SizedBox(width: 8),
                    Text('Export Details'),
                  ],
                ),
              ),
              if (_hasPendingRequest())
                const PopupMenuItem(
                  value: 'view_request',
                  child: Row(
                    children: [
                      Icon(Icons.pending_actions, size: 16),
                      SizedBox(width: 8),
                      Text('View Request'),
                    ],
                  ),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: isLowStock ? Colors.white : Colors.blue[700],
          unselectedLabelColor:
          isLowStock ? Colors.white.withOpacity(0.7) : Colors.grey[600],
          indicatorColor: isLowStock ? Colors.white : Colors.blue[700],
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          isScrollable: true,
          tabs: [
            const Tab(text: 'Overview'),
            const Tab(text: 'Images'),
            if (hasInventory) ...[
              const Tab(text: 'Items'),
              const Tab(text: 'Locations'),
              const Tab(text: 'History'),
              const Tab(text: 'Analytics'),
            ],
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading product details...'),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text('Error Loading Product',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _setupRealtimeUpdates(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (product == null) {
      return const Center(child: Text('Product not found'));
    }

    final hasInventory = getTotalQuantity() > 0;

    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildImagesTab(),
        _buildItemsTab(), // NEW ITEMS TAB
        if (hasInventory) ...[
          _buildLocationsTab(),
          _buildHistoryTab(),
          _buildAnalyticsTab(),
        ],
      ],
    );
  }

  // NEW ITEMS TAB IMPLEMENTATION
  Widget _buildItemsTab() {
    return Column(
      children: [
        _buildItemsSearchAndFilters(),
        if (!isLoadingItems) _buildItemsStatsBar(),
        Expanded(
          child: isLoadingItems
              ? _buildItemsLoadingState()
              : filteredItems.isEmpty
              ? _buildItemsEmptyState()
              : _buildItemsList(),
        ),
      ],
    );
  }

  Widget _buildItemsLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated loading indicator
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
            ),
          ),
          const SizedBox(height: 24),

          // Loading title
          Text(
            'Loading Product Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),

          // Loading description
          Text(
            'Fetching individual items and their locations...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Loading details with animated dots
          _buildLoadingDetailsCard(),
        ],
      ),
    );
  }

  Widget _buildLoadingDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'What we\'re loading:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildLoadingItem('Product items from inventory', true),
          const SizedBox(height: 8),
          _buildLoadingItem('Storage location details', true),
          const SizedBox(height: 8),
          _buildLoadingItem('Supplier information', true),
          const SizedBox(height: 8),
          _buildLoadingItem('Purchase order data', true),
        ],
      ),
    );
  }

  Widget _buildLoadingItem(String text, bool isLoading) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: isLoading
              ? CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
          )
              : Icon(Icons.check_circle, color: Colors.green[600], size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[600],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsSearchAndFilters() {
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
          // Enhanced search bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _itemsSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search items by ID, location, zone, supplier...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _buildItemsSearchSuffixIcons(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      itemsSearchQuery = value;
                    });
                    _applyItemsFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              _buildItemsSortButton(),
            ],
          ),

          // Speech recognition status
          _buildItemsSpeechStatus(),

          const SizedBox(height: 12),
          // Filter dropdowns
          Row(
            children: [
              Expanded(child: _buildItemsZoneFilter()),
              const SizedBox(width: 8),
              Expanded(child: _buildItemsSupplierFilter()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsZoneFilter() {
    return DropdownButtonFormField<String>(
      dropdownColor: Colors.white,
      value: selectedItemZone,
      decoration: InputDecoration(
        labelText: 'Zone',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: availableItemZones.map((zone) {
        return DropdownMenuItem(
          value: zone,
          child: Text(zone, style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedItemZone = value!;
        });
        _applyItemsFilters();
      },
    );
  }

  Widget _buildItemsSupplierFilter() {
    return DropdownButtonFormField<String>(
      dropdownColor: Colors.white,
      value: selectedItemSupplier,
      decoration: InputDecoration(
        labelText: 'Supplier',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: availableItemSuppliers.map((supplier) {
        return DropdownMenuItem(
          value: supplier,
          child: Text(supplier, style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedItemSupplier = value!;
        });
        _applyItemsFilters();
      },
    );
  }

  Widget _buildItemsSortButton() {
    return PopupMenuButton<String>(
      color: Colors.white,
      icon: const Icon(Icons.sort, size: 20),
      tooltip: 'Sort Items',
      onSelected: (value) {
        setState(() {
          if (itemsSortBy == value) {
            itemsIsAscending = !itemsIsAscending;
          } else {
            itemsSortBy = value;
            itemsIsAscending = true;
          }
        });
        _applyItemsFilters();
      },
      itemBuilder: (context) => [
        _buildItemsSortMenuItem('date', 'Date Stored', Icons.schedule),
        _buildItemsSortMenuItem('id', 'Item ID', Icons.tag),
        _buildItemsSortMenuItem('location', 'Location', Icons.location_on),
        _buildItemsSortMenuItem('zone', 'Zone', Icons.map),
        _buildItemsSortMenuItem('supplier', 'Supplier', Icons.business),
      ],
    );
  }

  PopupMenuItem<String> _buildItemsSortMenuItem(
      String value, String label, IconData icon) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          if (itemsSortBy == value)
            Icon(
              itemsIsAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
            ),
        ],
      ),
    );
  }

  Widget _buildItemsStatsBar() {
    final totalItems = filteredItems.length;
    final uniqueLocations = filteredItems
        .where((item) => item.locationName != null)
        .map((item) => item.locationName!)
        .toSet()
        .length;
    final uniqueSuppliers = filteredItems
        .where((item) => item.supplierName != null)
        .map((item) => item.supplierName!)
        .toSet()
        .length;

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
          _buildItemsStatChip('$totalItems items', Colors.blue),
          if (uniqueLocations > 0)
            _buildItemsStatChip('$uniqueLocations locations', Colors.green),
          if (uniqueSuppliers > 0)
            _buildItemsStatChip('$uniqueSuppliers suppliers', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildItemsStatChip(String text, Color color) {
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

  Widget _buildItemsEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'No Items Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              itemsSearchQuery.isNotEmpty ||
                  selectedItemZone != 'All' ||
                  selectedItemSupplier != 'All'
                  ? 'No items match your search criteria'
                  : 'No individual items stored for this product',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            if (itemsSearchQuery.isNotEmpty ||
                selectedItemZone != 'All' ||
                selectedItemSupplier != 'All') ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    itemsSearchQuery = '';
                    selectedItemZone = 'All';
                    selectedItemSupplier = 'All';
                    _itemsSearchController.clear();
                  });
                  _applyItemsFilters();
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final itemWithDetails = filteredItems[index];
        return _buildItemCard(itemWithDetails);
      },
    );
  }

  Widget _buildItemCard(ProductItemWithDetails itemWithDetails) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductItemDetailsScreen(
              productItemId: itemWithDetails.item.itemId,
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                          'Item ID: ${itemWithDetails.item.itemId}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.green[200]!),
                              ),
                              child: Text(
                                itemWithDetails.item.status
                                    .toString()
                                    .split('.')
                                    .last
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[700],
                                ),
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
                    onSelected: (action) =>
                        _handleItemAction(action, itemWithDetails),
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
                        value: 'location',
                        child: Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 18, color: Colors.blue),
                            SizedBox(width: 12),
                            Text('View Location'),
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
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                        Icon(Icons.location_on,
                            size: 16, color: Colors.blue[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Location: ${itemWithDetails.locationName ?? "Not assigned"}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (itemWithDetails.zoneName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.map, size: 16, color: Colors.green[600]),
                          const SizedBox(width: 4),
                          Text(
                            itemWithDetails.zoneName!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (itemWithDetails.supplierName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.business,
                              size: 16, color: Colors.orange[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Supplier: ${itemWithDetails.supplierName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'PO: ${itemWithDetails.item.purchaseOrderId.isNotEmpty ? itemWithDetails.item.purchaseOrderId : "N/A"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  if (itemWithDetails.storedDate != null)
                    Text(
                      'Stored: ${_formatDate(itemWithDetails.storedDate!)}',
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

  void _handleItemAction(
      String action, ProductItemWithDetails itemWithDetails) {
    switch (action) {
      case 'view':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductItemDetailsScreen(
              productItemId: itemWithDetails.item.itemId,
            ),
          ),
        );
        break;
      case 'location':
        if (itemWithDetails.locationName != null) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Location Details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Location: ${itemWithDetails.locationName}'),
                  if (itemWithDetails.zoneName != null)
                    Text('Zone: ${itemWithDetails.zoneName}'),
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
        break;
      case 'qr':
        showDialog(
          context: context,
          builder: (context) => QRGeneratorDialog(
            productId: itemWithDetails.item.productId,
            productName: 'Item ${itemWithDetails.item.productId}',
            category: getDisplayCategory(),
            quantity: 1,
          ),
        );
        break;
    }
  }

  // ORIGINAL TAB IMPLEMENTATIONS (you need to implement these with your existing code)
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
          if (getTotalQuantity() > 0) ...[
            _buildQuantityBreakdownCard(),
            const SizedBox(height: 16),
            _buildSupplierInfoCard(),
            const SizedBox(height: 16),
          ],
          _buildProductSpecsCard(),
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
          Card(
            color: Colors.white,
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
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.photo_library,
                            color: Colors.orange[700], size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Product Images',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                            Text(
                              '${productImages.length} images available',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (productImages.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.photo_library,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No Images Available',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            'Product images will appear here when uploaded',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1,
                      ),
                      itemCount: productImages.length,
                      itemBuilder: (context, index) {
                        return _buildImageTile(productImages[index], index);
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageTile(String fileName, int index) {
    print('Building image tile for: $fileName');

    return GestureDetector(
      onTap: () => _showImagePreview(index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildImageContent(fileName),
      ),
    );
  }

  Widget _buildImageContent(String fileName) {
    if (fileName.startsWith('placeholder_')) {
      return Container(
        color: Colors.grey[200],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, color: Colors.grey[400], size: 32),
            const SizedBox(height: 4),
            const Text(
              'Placeholder',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<Map<String, String?>>(
      future: _getImageUrls(fileName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final urls = snapshot.data ?? {};
        final signedUrl = urls['signed'];
        final publicUrl = urls['public'];

        print(
            'URLs for $fileName - Signed: ${signedUrl != null}, Public: ${publicUrl != null}');

        final imageUrl = signedUrl ?? publicUrl;

        if (imageUrl != null && imageUrl.isNotEmpty) {
          return Image.network(
            imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                print('Image loaded successfully: $fileName');
                return child;
              }
              return Container(
                color: Colors.grey[200],
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                        : null,
                    strokeWidth: 2,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              print('Error loading image $fileName: $error');
              return Container(
                color: Colors.grey[200],
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, color: Colors.grey[400], size: 32),
                    const SizedBox(height: 4),
                    const Text(
                      'Failed to load',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      error.toString().contains('404')
                          ? 'Not found'
                          : 'Network error',
                      style: TextStyle(fontSize: 8, color: Colors.red[400]),
                    ),
                  ],
                ),
              );
            },
          );
        }

        return Container(
          color: Colors.grey[200],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, color: Colors.grey[400], size: 32),
              const SizedBox(width: 4),
              const Text(
                'No URL',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, String?>> _getImageUrls(String fileName) async {
    final Map<String, String?> urls = {};

    try {
      urls['signed'] =
      await ProductImageService.getProductImageSignedUrl(fileName);
    } catch (e) {
      print('Error getting signed URL: $e');
    }

    return urls;
  }

  void _showImagePreview(int initialIndex) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withOpacity(0.9),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                AppBar(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  title: Text(
                    'Image ${initialIndex + 1} of ${productImages.length}',
                  ),
                  elevation: 0,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Expanded(
                  child: PageView.builder(
                    controller: PageController(initialPage: initialIndex),
                    itemCount: productImages.length,
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        child: Center(
                          child: _buildFullSizeImage(productImages[index]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFullSizeImage(String fileName) {
    return FutureBuilder<Map<String, String?>>(
      future: _getImageUrls(fileName),
      builder: (context, snapshot) {
        final urls = snapshot.data ?? {};
        final imageUrl = urls['signed'] ?? urls['public'];

        if (imageUrl != null && imageUrl.isNotEmpty) {
          return Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.white, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              );
            },
          );
        }

        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported, color: Colors.white, size: 48),
              SizedBox(height: 16),
              Text(
                'Image not available',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        );
      },
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        color: Colors.white,
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ...locations.asMap().entries.map((entry) {
              final index = entry.key;
              final location = entry.value;
              final isLast = index == locations.length - 1;

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
                        child: Icon(Icons.history,
                            color: Colors.blue[700], size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Stored at ${location.locationId}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Quantity: ${location.quantity}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                            if (location.purchaseOrderId != null)
                              Text(
                                'From PO: ${location.purchaseOrderId}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                          ],
                        ),
                      ),
                      if (location.storedDate != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatDate(location.storedDate!),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              _formatTime(location.storedDate!),
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500]),
                            ),
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

  // Helper widgets (implement these with your existing code)
  Widget _buildProductSummaryCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
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
                  child:
                  Icon(Icons.inventory, color: Colors.blue[700], size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        getDisplayName(),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Text(
                              getDisplayCategory(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                          if (_hasRejectedRequest() &&
                              !_hasPendingRequest()) ...[
                            const SizedBox(width: 8),
                            _buildRejectedRequestChip(),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stock Level Alert (if low or critical stock)
            if (_isLowStock()) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                  _isCriticalStock() ? Colors.red[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isCriticalStock()
                        ? Colors.red[200]!
                        : Colors.orange[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isCriticalStock() ? Icons.error : Icons.warning,
                      color: _isCriticalStock()
                          ? Colors.red[700]
                          : Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isCriticalStock()
                                ? 'CRITICAL STOCK LEVEL'
                                : 'LOW STOCK ALERT',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isCriticalStock()
                                  ? Colors.red[800]
                                  : Colors.orange[800],
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Only ${getTotalQuantity()} units remaining',
                            style: TextStyle(
                              color: _isCriticalStock()
                                  ? Colors.red[700]
                                  : Colors.orange[700],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_hasPendingRequest() && !_hasRejectedRequest())
                      ElevatedButton(
                        onPressed: _showRequestPODialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isCriticalStock()
                              ? Colors.red[600]
                              : Colors.orange[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          _isCriticalStock() ? 'URGENT ORDER' : 'RESTOCK',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Pending Request Status
            if (_hasPendingRequest()) ...[
              _buildPendingRequestStatus(),
              const SizedBox(height: 16),
            ],

            // Key metrics with enhanced styling
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Total Quantity',
                    '${getTotalQuantity()}',
                    Icons.inventory_2,
                    _isCriticalStock()
                        ? Colors.red
                        : _isLowStock()
                        ? Colors.orange
                        : getTotalQuantity() == 0
                        ? Colors.grey
                        : Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Storage Locations',
                    '${locations.length}',
                    Icons.location_on,
                    locations.isNotEmpty ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),

            if (getTotalQuantity() > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      'Purchase Orders',
                      '${getPurchaseOrderNumbers().length}',
                      Icons.receipt,
                      Colors.purple,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Suppliers',
                      '${getSupplierNames().length}',
                      Icons.business,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
            ],

            // Value information
            if (product?.price != null) ...[
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
                      'Unit Price: RM ${product!.price!.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (getTotalQuantity() > 0)
                      Text(
                        'Total Value: RM ${(product!.price! * getTotalQuantity()).toStringAsFixed(2)}',
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

  Widget _buildQRCodeCard() {
    return Card(
      color: Colors.purple[10],
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
                  child:
                  Icon(Icons.qr_code, color: Colors.purple[700], size: 24),
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
                        'Scan to quickly access product information',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // QR Code Display
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: RepaintBoundary(
                  key: _qrKey,
                  child: QrImageView(
                    data: widget.productId,
                    version: QrVersions.auto,
                    size: 200,
                    gapless: false,
                    errorStateBuilder: (cxt, err) {
                      return const Center(
                        child: Text('Error generating QR code'),
                      );
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // QR Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _downloadQRCodeAsPDF,
                    icon: const Icon(Icons.download, size: 20),
                    label: const Text('Download PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.productId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Product ID copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 20),
                    label: const Text('Copy ID'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple[600],
                      side: BorderSide(color: Colors.purple[200]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
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

  Widget _buildQuantityBreakdownCard() {
    if (locations.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: Colors.white,
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
            ...(_getQuantityByZone().entries.map((entry) {
              final zone = entry.key;
              final quantity = entry.value;
              final percentage = (quantity / getTotalQuantity() * 100);

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
            if (locations.length > 1) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.blue[700], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Average per location: ${(getTotalQuantity() / locations.length).toStringAsFixed(1)} items',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue[700],
                        ),
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

  Widget _buildSupplierInfoCard() {
    final suppliers = getSupplierNames();
    if (suppliers.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: Colors.white,
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
                const Spacer(),
                if (_isLowStock() && !_hasPendingRequest())
                  ElevatedButton.icon(
                    onPressed: _showRequestPODialog,
                    icon: Icon(
                      _isCriticalStock()
                          ? Icons.priority_high
                          : Icons.add_shopping_cart,
                      size: 16,
                    ),
                    label: Text(_isCriticalStock() ? 'URGENT' : 'REORDER'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCriticalStock()
                          ? Colors.red[600]
                          : Colors.orange[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ...suppliers.map((supplier) {
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
                    if (supplierPOs.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Purchase Orders:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
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
                  ],
                ),
              );
            }).toList(),
            if (suppliers.length > 1) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Supplier diversity: ${suppliers.length} suppliers providing good supply chain resilience',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
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

  Widget _buildProductSpecsCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
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
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Product Specifications',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSpecRow('Product ID', widget.productId),
            _buildSpecRow('Part Number', getPartNumber()),
            _buildSpecRow('Brand', getDisplayBrand()),
            _buildSpecRow('Category', getDisplayCategory()),
            if (product?.description != null && product!.description.isNotEmpty)
              _buildSpecRow('Description', product!.description),
            if (product?.unit != null) _buildSpecRow('Unit', product!.unit),
            if (product?.weight != null)
              _buildSpecRow('Weight', '${product!.weight} kg'),
            if (product?.metadata != null && product!.metadata.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Additional Information',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...product!.metadata.entries
                  .where((entry) =>
              entry.key != 'images' &&
                  entry.value != null &&
                  entry.value.toString().isNotEmpty)
                  .map((entry) => _buildSpecRow(
                  _formatMetadataKey(entry.key), entry.value.toString())),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
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
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMetadataKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  Widget _buildLocationSummaryCard() {
    if (locations.isEmpty) return const SizedBox.shrink();

    final zoneGroups = <String, List<ProductItemLocation>>{};
    for (final location in locations) {
      zoneGroups.putIfAbsent(location.zoneId, () => []).add(location);
    }

    return Card(
      elevation: 0,
      color: Colors.white,
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
                Icon(Icons.location_on, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Location Distribution',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...zoneGroups.entries.map((entry) {
              final zone = entry.key;
              final zoneLocations = entry.value;
              final totalQty =
              zoneLocations.fold<int>(0, (sum, loc) => sum + loc.quantity);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _showZoneDetails(zone, zoneLocations),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getZoneColor(zone).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _getZoneColor(zone).withOpacity(0.3)),
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
                                '${zoneLocations.length} locations • $totalQty items',
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
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationListCard() {
    if (locations.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.list_alt, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'All Storage Locations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ...locations.asMap().entries.map((entry) {
            final index = entry.key;
            final location = entry.value;
            final isLast = index == locations.length - 1;

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
                      'Quantity: ${location.quantity}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (location.purchaseOrderId != null &&
                        location.purchaseOrderId!.isNotEmpty)
                      Text(
                        'PO: ${location.purchaseOrderId}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    if (location.supplierName != null)
                      Text(
                        'Supplier: ${location.supplierName}',
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
                    if (location.storedDate != null)
                      Text(
                        _formatDate(location.storedDate!),
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
    if (locations.isEmpty) return const SizedBox.shrink();

    final avgQuantityPerLocation = getTotalQuantity() / locations.length;
    final zonesUsed = locations.map((l) => l.zoneId).toSet().length;
    final totalZones = 6;

    return Card(
      elevation: 0,
      color: Colors.white,
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
                Icon(Icons.analytics, color: Colors.purple[700], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Storage Analytics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
                    '$zonesUsed/$totalZones',
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
                    '${(zonesUsed / totalZones * 100).toStringAsFixed(0)}%',
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Key Insights',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._getStorageInsights().map((insight) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          insight['icon'],
                          color: insight['color'],
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            insight['text'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageEfficiencyCard() {
    if (locations.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: Colors.white,
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
                  'Storage Efficiency & Insights',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.pie_chart,
                            color: Colors.green[700], size: 24),
                        const SizedBox(height: 8),
                        Text(
                          '${((locations.map((l) => l.zoneId).toSet().length / 6) * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                        Text(
                          'Zone Utilization',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.inventory,
                            color: Colors.blue[700], size: 24),
                        const SizedBox(height: 8),
                        Text(
                          '${(getTotalQuantity() / locations.length).toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        Text(
                          'Items per Location',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._getDetailedStorageInsights().map((insight) {
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            insight['title'],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: insight['color'],
                            ),
                          ),
                          Text(
                            insight['text'],
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
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

  Widget _buildMetricItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      margin: const EdgeInsets.only(right: 8),
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
            style: TextStyle(fontSize: 12, color: color),
            textAlign: TextAlign.center,
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
      margin: const EdgeInsets.only(right: 8),
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

  void _showLocationDetails(ProductItemLocation location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Location: ${location.locationId}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Zone: ${location.zoneId} (${_getZoneName(location.zoneId)})'),
            Text('Quantity: ${location.quantity}'),
            if (location.purchaseOrderId != null &&
                location.purchaseOrderId!.isNotEmpty)
              Text('Purchase Order: ${location.purchaseOrderId}'),
            if (location.supplierName != null)
              Text('Supplier: ${location.supplierName}'),
            if (location.storedDate != null)
              Text('Stored Date: ${_formatDate(location.storedDate!)}'),
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

  void _showZoneDetails(String zone, List<ProductItemLocation> zoneLocations) {
    final totalQuantity =
    zoneLocations.fold<int>(0, (sum, loc) => sum + loc.quantity);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Zone: $zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Zone Name: ${_getZoneName(zone)}'),
            Text('Locations: ${zoneLocations.length}'),
            Text('Total Quantity: $totalQuantity'),
            const SizedBox(height: 16),
            const Text('Locations in this zone:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...zoneLocations.map((loc) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• ${loc.locationId}: ${loc.quantity} items'),
            )),
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

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  String _formatTime(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
