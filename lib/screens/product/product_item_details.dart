import 'package:assignment/screens/product/product_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:assignment/models/warehouse_location.dart';
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
import 'package:assignment/services/login/load_user_data.dart';
import 'package:assignment/screens/warehouse/stored_product_detail_screen.dart';
import 'package:assignment/screens/warehouse/warehouse_map_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:assignment/widgets/qr/qr_generator_dialog.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';

import '../../services/warehouse/warehouse_movement.dart';

// Enhanced models for item details
class ItemMovementHistory {
  final String id;
  final DateTime timestamp;
  final String action;
  final String? fromLocation;
  final String? toLocation;
  final String? fromZone;
  final String? toZone;
  final ProductItemsStatus? fromStatus;
  final ProductItemsStatus? toStatus;
  final String? performedBy;
  final String? notes;
  final String? reason;

  ItemMovementHistory({
    required this.id,
    required this.timestamp,
    required this.action,
    this.fromLocation,
    this.toLocation,
    this.fromZone,
    this.toZone,
    this.fromStatus,
    this.toStatus,
    this.performedBy,
    this.notes,
    this.reason,
  });

  factory ItemMovementHistory.fromFirestore(Map<String, dynamic> data) {
    try {
      // Validate required fields
      if (data['id'] == null) {
        throw Exception('Missing required field: id');
      }

      if (data['timestamp'] == null) {
        throw Exception('Missing required field: timestamp');
      }

      if (data['action'] == null) {
        throw Exception('Missing required field: action');
      }

      // Handle timestamp conversion safely
      DateTime timestamp;
      if (data['timestamp'] is Timestamp) {
        timestamp = (data['timestamp'] as Timestamp).toDate();
      } else if (data['timestamp'] is String) {
        timestamp = DateTime.parse(data['timestamp']);
      } else {
        throw Exception(
            'Invalid timestamp format: ${data['timestamp'].runtimeType}');
      }

      return ItemMovementHistory(
        id: data['id'] ?? '',
        timestamp: timestamp,
        action: data['action'] ?? '',
        fromLocation: data['fromLocation'],
        toLocation: data['toLocation'],
        fromZone: data['fromZone'],
        toZone: data['toZone'],
        fromStatus: data['fromStatus'] != null
            ? _parseStatus(data['fromStatus'])
            : null,
        toStatus:
            data['toStatus'] != null ? _parseStatus(data['toStatus']) : null,
        performedBy: data['performedBy'],
        notes: data['notes'],
        reason: data['reason'],
      );
    } catch (e) {
      print('❌ ItemMovementHistory.fromFirestore error: $e');
      print('📄 Data: $data');
      rethrow;
    }
  }

  static ProductItemsStatus? _parseStatus(dynamic statusValue) {
    if (statusValue == null) return null;

    try {
      String statusString = statusValue.toString();

      // Handle both "stored" and "ProductItemsStatus.stored" formats
      if (statusString.contains('.')) {
        statusString = statusString.split('.').last;
      }

      return ProductItemsStatus.values.firstWhere(
        (e) =>
            e.toString().split('.').last.toLowerCase() ==
            statusString.toLowerCase(),
        orElse: () => ProductItemsStatus.inTransit,
      );
    } catch (e) {
      print('⚠️ Error parsing status: $statusValue -> $e');
      return ProductItemsStatus.inTransit;
    }
  }
}

class LocationDetails {
  final String locationId;
  final String zoneId;
  final String zoneName;
  final String locationName;
  final String? description;
  final Map<String, dynamic>? coordinates;
  final bool isActive;
  final int? capacity;
  final int? currentOccupancy;

  LocationDetails({
    required this.locationId,
    required this.zoneId,
    required this.zoneName,
    required this.locationName,
    this.description,
    this.coordinates,
    required this.isActive,
    this.capacity,
    this.currentOccupancy,
  });

  factory LocationDetails.fromFirestore(
      String locationId, Map<String, dynamic> data) {
    return LocationDetails(
      locationId: locationId,
      zoneId: data['zoneId'] ?? '',
      zoneName: _getZoneName(data['zoneId'] ?? ''),
      locationName: data['name'] ?? locationId,
      description: data['description'],
      coordinates: data['coordinates'],
      isActive: data['isActive'] ?? true,
      capacity: data['capacity'],
      currentOccupancy: data['currentOccupancy'],
    );
  }

  static String _getZoneName(String zoneId) {
    switch (zoneId) {
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
}

class ProductItemDetailsScreen extends StatefulWidget {
  final String productItemId;

  const ProductItemDetailsScreen({
    super.key,
    required this.productItemId,
  });

  @override
  State<ProductItemDetailsScreen> createState() =>
      _ProductItemDetailsScreenState();
}

class _ProductItemDetailsScreenState extends State<ProductItemDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final WarehouseMovementService _movementService = WarehouseMovementService();

  // Data models
  ProductItem? productItem;
  Product? parentProduct;
  ProductNameModel? productName;
  ProductBrandModel? productBrand;
  CategoryModel? productCategory;
  LocationDetails? locationDetails;
  PurchaseOrder? purchaseOrder;
  List<ItemMovementHistory> movementHistory = [];
  List<ProductItem> relatedItems = [];
  List<WarehouseLocation> availableLocations = [];
  UserModel? currentUser;

  // Loading states
  bool isLoading = true;
  String? errorMessage;
  bool isMoving = false;

  // Real-time subscriptions
  StreamSubscription<DocumentSnapshot>? _itemSubscription;
  StreamSubscription<DocumentSnapshot>? _productSubscription;
  StreamSubscription<QuerySnapshot>? _historySubscription;

  // DAOs
  final ProductNameDao _productNameDao = ProductNameDao();
  final ProductBrandDAO _productBrandDao = ProductBrandDAO();
  final CategoryDao _productCategoryDao = CategoryDao();

  // Keys for PDF generation
  final GlobalKey _qrKey = GlobalKey();
  final GlobalKey _barcodeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _setupRealtimeUpdates();
    _loadUser();
    _loadAvailableLocations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _itemSubscription?.cancel();
    _productSubscription?.cancel();
    _historySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      final user = await loadCurrentUser();
      setState(() {
        currentUser = user;
      });
    } catch (e) {
      print('Error loading user: $e');
    }
  }

  // Enhanced location loading with proper product filtering
  Future<void> _loadAvailableLocations({Product? productFilter}) async {
    try {
      if (productFilter != null) {
        print('🔄 Loading suitable locations for ${productFilter.name}...');

        // Use the enhanced service to get suitable locations
        final suitableOptions =
            await _movementService.getSuitableLocationsForProduct(
          productFilter,
          excludeLocationId: productItem?.location,
        );

        availableLocations =
            suitableOptions.map((option) => option.location).toList();

        print(
            '✅ Loaded ${availableLocations.length} suitable locations for ${productFilter.name}');

        // Sort by suitability (consolidation opportunities first, then by zone preference)
        availableLocations.sort((a, b) {
          final aOption = suitableOptions
              .firstWhere((opt) => opt.location.locationId == a.locationId);
          final bOption = suitableOptions
              .firstWhere((opt) => opt.location.locationId == b.locationId);

          // Consolidation opportunities first
          if (aOption.isConsolidation && !bOption.isConsolidation) return -1;
          if (!aOption.isConsolidation && bOption.isConsolidation) return 1;

          // Then by suitability score
          return bOption.suitabilityScore.compareTo(aOption.suitabilityScore);
        });
      } else {
        // Fallback to basic query for unoccupied locations
        final snapshot = await FirebaseFirestore.instance
            .collection('warehouseLocations')
            .where('isOccupied', isEqualTo: false)
            .orderBy('locationId')
            .get();

        availableLocations = snapshot.docs
            .map((doc) {
              try {
                final data = doc.data();
                return WarehouseLocation(
                  locationId: data['locationId'] ?? doc.id,
                  zoneId: data['zoneId'] ?? '',
                  isOccupied: data['isOccupied'] ?? false,
                  productId: data['productId'],
                  quantityStored: data['quantityStored'],
                  occupiedDate: data['occupiedDate'] != null
                      ? (data['occupiedDate'] as Timestamp).toDate()
                      : null,
                  rackId: data['rackId'] ?? '',
                  rowId: data['rowId'] ?? '',
                  level: data['level'] ?? 1,
                  metadata: data['metadata'],
                );
              } catch (e) {
                print('Error parsing warehouse location ${doc.id}: $e');
                return null;
              }
            })
            .where((location) => location != null)
            .cast<WarehouseLocation>()
            .toList();
      }
    } catch (e) {
      print('❌ Error loading available locations: $e');
      availableLocations = [];
    }
  }

  // Client-side filtering for complex logic that can't be done in Firestore
  bool _isLocationSuitableForProduct(
      WarehouseLocation location, Product product) {
    // Check dimensional compatibility
    if (!_checkDimensionalFit(location, product)) {
      return false;
    }

    // Check weight capacity
    if (!_checkWeightCapacity(location, product)) {
      return false;
    }

    // Check special requirements
    if (!_checkSpecialRequirements(location, product)) {
      return false;
    }

    return true;
  }

  bool _checkDimensionalFit(WarehouseLocation location, Product product) {
    // Extract location dimensions from metadata if available
    if (location.metadata != null) {
      final metadata = location.metadata as Map<String, dynamic>?;
      if (metadata != null && metadata.containsKey('dimensions')) {
        final locationDims = metadata['dimensions'] as Map<String, dynamic>;

        final maxLength =
            (locationDims['length'] ?? double.infinity).toDouble();
        final maxWidth = (locationDims['width'] ?? double.infinity).toDouble();
        final maxHeight =
            (locationDims['height'] ?? double.infinity).toDouble();

        return product.dimensions.length <= maxLength &&
            product.dimensions.width <= maxWidth &&
            product.dimensions.height <= maxHeight;
      }
    }

    // If no dimensional data, assume it fits
    return true;
  }

  bool _checkWeightCapacity(WarehouseLocation location, Product product) {
    if (location.metadata != null) {
      final metadata = location.metadata as Map<String, dynamic>?;
      if (metadata != null && metadata.containsKey('maxWeight')) {
        final maxWeight = (metadata['maxWeight'] ?? double.infinity).toDouble();
        return product.weight! <= maxWeight;
      }
    }

    // If no weight data, assume it can handle the weight
    return true;
  }

  bool _checkSpecialRequirements(WarehouseLocation location, Product product) {
    if (location.metadata == null) return true;

    final metadata = location.metadata as Map<String, dynamic>?;
    if (metadata == null) return true;

    // Check climate control requirement
    if (product.requiresClimateControl) {
      final hasClimateControl = metadata['climateControlled'] ?? false;
      if (!hasClimateControl) return false;
    }

    // Check hazardous material requirement
    if (product.isHazardousMaterial) {
      final hazmatApproved = metadata['hazmatApproved'] ?? false;
      if (!hazmatApproved) return false;
    }

    return true;
  }

  void _setupRealtimeUpdates() {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    _setupItemListener();
    _setupHistoryListener();
  }

  void _setupItemListener() {
    _itemSubscription = FirebaseFirestore.instance
        .collection('productItems')
        .doc(widget.productItemId)
        .snapshots()
        .listen(
      (snapshot) async {
        print('Product item data changed for ${widget.productItemId}');

        if (snapshot.exists) {
          final data = snapshot.data()!;
          productItem = ProductItem.fromFirestore(snapshot);

          await _loadParentProduct();
          await _loadLocationDetails();
          await _loadPurchaseOrderDetails();
          await _loadRelatedItems();

          print('Product item data updated: ${productItem?.productId}');
        } else {
          productItem = null;
          parentProduct = null;
          print('Product item document not found');
        }

        await _combineData();
      },
      onError: (error) {
        print('Product item listener error: $error');
        setState(() {
          errorMessage = 'Failed to load product item details: $error';
        });
      },
    );
  }

  void _setupHistoryListener() {
    print(
        '🔍 Setting up history listener for productItemId: ${widget.productItemId}');

    _historySubscription = FirebaseFirestore.instance
        .collection('productItemHistory')
        .where('productItemId', isEqualTo: widget.productItemId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        print('📊 History snapshot received:');
        print('  - Document count: ${snapshot.docs.length}');
        print('  - Snapshot exists: ${snapshot.docs.isNotEmpty}');

        if (snapshot.docs.isEmpty) {
          print(
              '❌ No history documents found for productItemId: ${widget.productItemId}');
          // Check if there are ANY documents in the collection
          _debugCheckHistoryCollection();
        } else {
          print('✅ Found ${snapshot.docs.length} history documents');

          // Debug each document
          for (int i = 0; i < snapshot.docs.length; i++) {
            final doc = snapshot.docs[i];
            print('📄 Document $i (${doc.id}):');
            print('  Raw data: ${doc.data()}');
          }
        }

        movementHistory = snapshot.docs
            .map((doc) {
              try {
                print('🔄 Converting document ${doc.id}...');
                final data = doc.data();

                // Debug the data structure
                print('  - productItemId: ${data['productItemId']}');
                print(
                    '  - timestamp: ${data['timestamp']} (${data['timestamp'].runtimeType})');
                print('  - action: ${data['action']}');

                final history = ItemMovementHistory.fromFirestore(data);
                print('✅ Successfully converted document ${doc.id}');
                return history;
              } catch (e, stackTrace) {
                print('❌ Error converting history ${doc.id}: $e');
                print('📍 Stack trace: $stackTrace');
                print('📄 Document data: ${doc.data()}');
                return null;
              }
            })
            .where((history) => history != null)
            .cast<ItemMovementHistory>()
            .toList();

        print('🎯 Final movementHistory list: ${movementHistory.length} items');
        setState(() {});
      },
      onError: (error) {
        print('💥 History listener error: $error');
        print('🔍 This could be due to:');
        print('  - Firestore security rules');
        print('  - Missing index for orderBy');
        print('  - Network connectivity');
      },
    );
  }

  Future<void> _debugCheckHistoryCollection() async {
    try {
      print('🔍 Checking all documents in productItemHistory collection...');

      final allDocs = await FirebaseFirestore.instance
          .collection('productItemHistory')
          .limit(10) // Just check first 10
          .get();

      print('📊 Total documents in collection: ${allDocs.docs.length}');

      if (allDocs.docs.isNotEmpty) {
        print('📄 Sample documents:');
        for (final doc in allDocs.docs.take(3)) {
          final data = doc.data();
          print(
              '  - Doc ${doc.id}: productItemId=${data['productItemId']}, action=${data['action']}');
        }

        // Check if any match our productItemId
        final matchingDocs = await FirebaseFirestore.instance
            .collection('productItemHistory')
            .where('productItemId', isEqualTo: widget.productItemId)
            .get();

        print(
            '🎯 Documents matching productItemId ${widget.productItemId}: ${matchingDocs.docs.length}');
      } else {
        print('❌ No documents found in productItemHistory collection at all');
      }
    } catch (e) {
      print('💥 Error checking history collection: $e');
    }
  }

  Future<void> _loadParentProduct() async {
    if (productItem == null) return;

    try {
      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productItem!.productId)
          .get();

      if (productDoc.exists) {
        parentProduct =
            Product.fromFirestore(productItem!.productId, productDoc.data()!);
        await _loadResolvedProductData();
      }
    } catch (e) {
      print('Error loading parent product: $e');
    }
  }

  Future<void> _loadResolvedProductData() async {
    if (parentProduct == null) return;

    try {
      if (parentProduct!.name.isNotEmpty) {
        productName =
            await _productNameDao.getProductNameById(parentProduct!.name);
      }

      if (parentProduct!.brand.isNotEmpty) {
        productBrand =
            await _productBrandDao.getBrandById(parentProduct!.brand);
      }

      if (parentProduct!.category.isNotEmpty) {
        productCategory =
            await _productCategoryDao.getCategoryById(parentProduct!.category);
      }
    } catch (e) {
      print('Error loading resolved product data: $e');
    }
  }

  Future<void> _loadLocationDetails() async {
    if (productItem?.location == null || productItem!.location!.isEmpty) return;

    try {
      final locationDoc = await FirebaseFirestore.instance
          .collection('warehouseLocations')
          .doc(productItem!.location!)
          .get();

      if (locationDoc.exists) {
        locationDetails = LocationDetails.fromFirestore(
            productItem!.location!, locationDoc.data()!);
      }
    } catch (e) {
      print('Error loading location details: $e');
    }
  }

  Future<void> _loadPurchaseOrderDetails() async {
    if (productItem?.purchaseOrderId == null ||
        productItem!.purchaseOrderId.isEmpty) return;

    try {
      final poDoc = await FirebaseFirestore.instance
          .collection('purchaseOrder')
          .doc(productItem!.purchaseOrderId)
          .get();

      if (poDoc.exists) {
        purchaseOrder = PurchaseOrder.fromFirestore(poDoc.data()!);
      }
    } catch (e) {
      print('Error loading purchase order details: $e');
    }
  }

  Future<void> _loadRelatedItems() async {
    if (productItem == null) return;

    try {
      final relatedSnapshot = await FirebaseFirestore.instance
          .collection('productItems')
          .where('productId', isEqualTo: productItem!.productId)
          .where('status', isEqualTo: ProductItemsStatus.stored.toString())
          .limit(10)
          .get();

      relatedItems = relatedSnapshot.docs
          .map((doc) => ProductItem.fromFirestore(doc))
          .where((item) => item.itemId != productItem!.itemId)
          .toList();
    } catch (e) {
      print('Error loading related items: $e');
    }
  }

  Future<void> _combineData() async {
    try {
      if (productItem == null) {
        print('Product item data not available yet, waiting...');
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage = null;
      });

      print('Successfully combined data for item ${getDisplayName()}');
    } catch (e) {
      print('Error combining data: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to process product item data: $e';
      });
    }
  }

  // Navigation to stored product details
  void _navigateToProductDetails() {
    if (productItem == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          productId: productItem!.productId,
        ),
      ),
    );
  }

  // Movement functionality
  Future<void> _moveItem(String newLocationId, String? notes) async {
    if (productItem == null || parentProduct == null || isMoving) return;

    setState(() {
      isMoving = true;
    });

    try {
      final result = await _movementService.moveItem(
        productItemId: widget.productItemId,
        currentLocationId: productItem!.location ?? '',
        targetLocationId: newLocationId,
        product: parentProduct!,
        performedBy:
            '${currentUser?.firstName} ${currentUser?.lastName}' ?? 'Unknown',
        notes: notes,
        reason: notes?.isNotEmpty == true ? notes! : 'Manual item relocation',
      );

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh available locations after successful move
        await _loadAvailableLocations(productFilter: parentProduct);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error moving item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to move item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isMoving = false;
      });
    }
  }

  Future<void> _updateItemStatus(
      ProductItemsStatus newStatus, String? notes) async {
    if (productItem == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Update product item status
      final itemRef = FirebaseFirestore.instance
          .collection('productItems')
          .doc(widget.productItemId);

      batch.update(itemRef, {
        'status': newStatus.toString(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Create history record
      final historyRef =
          FirebaseFirestore.instance.collection('productItemHistory').doc();

      batch.set(historyRef, {
        'id': historyRef.id,
        'productItemId': widget.productItemId,
        'action': 'status_changed',
        'fromStatus': productItem!.status.toString(),
        'toStatus': newStatus.toString(),
        'timestamp': FieldValue.serverTimestamp(),
        'performedBy':
            '${currentUser?.firstName} ${currentUser?.lastName}' ?? 'Unknown',
        'notes': notes,
      });

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper methods for display data
  String getDisplayName() =>
      productName?.productName ?? parentProduct?.name ?? 'Unknown Product';

  String getDisplayBrand() => productBrand?.brandName ?? 'Unknown Brand';

  String getDisplayCategory() => productCategory?.name ?? 'Unknown Category';

  String getItemId() => productItem?.itemId ?? 'Unknown';

  String getStatus() =>
      productItem?.status.toString().split('.').last ?? 'Unknown';

  String getLocation() =>
      locationDetails?.locationName ?? productItem?.location ?? 'Not assigned';

  String getZone() => locationDetails?.zoneName ?? 'Unknown Zone';

  Color getStatusColor() {
    if (productItem == null) return Colors.grey;
    final statusString =
        productItem!.status.toString().split('.').last.toLowerCase();

    switch (statusString) {
      case 'stored':
        return Colors.green;
      case 'intransit':
        return Colors.blue;
      case 'damaged':
        return Colors.red;
      case 'returned':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData getStatusIcon() {
    if (productItem == null) return Icons.help_outline;

    // Convert to string and compare
    final statusString =
        productItem!.status.toString().split('.').last.toLowerCase();

    switch (statusString) {
      case 'stored':
        return Icons.inventory;
      case 'intransit':
        return Icons.local_shipping;
      case 'damaged':
        return Icons.warning;
      case 'returned':
        return Icons.keyboard_return;
      default:
        return Icons.help_outline;
    }
  }

  // Fixed PDF generation methods
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
                        'Product Item QR Code',
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
                        'Item ID: ${getItemId()}',
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
                            'Item Details',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 16),
                          _buildPDFDetailRow('Item ID:', getItemId()),
                          _buildPDFDetailRow('Product:', getDisplayName()),
                          _buildPDFDetailRow('Status:', getStatus()),
                          _buildPDFDetailRow('Location:', getLocation()),
                          _buildPDFDetailRow('Zone:', getZone()),
                          if (purchaseOrder != null)
                            _buildPDFDetailRow(
                                'Purchase Order:', purchaseOrder!.poNumber),
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
                        '- Scan this QR code to quickly access item details',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        '- Use for inventory tracking and management',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        '- Generated on: ${DateTime.now().toString().split('.')[0]}',
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

      final directory = await getApplicationDocumentsDirectory();
      final file = File(
          '${directory.path}/item_qr_${widget.productItemId}_${DateTime.now().millisecondsSinceEpoch}.pdf');

      await file.writeAsBytes(await pdf.save());

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('QR Code PDF saved to: ${file.path}'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Share',
            textColor: Colors.white,
            onPressed: () async {
              await Printing.sharePdf(
                  bytes: await pdf.save(),
                  filename: 'item_qr_${widget.productItemId}.pdf');
            },
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

  // Fixed move item dialog
  void _showMoveItemDialog() {
    String? selectedLocationId;
    String notes = '';
    bool isLoadingLocations = true;
    List<WarehouseLocation> dialogAvailableLocations = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Load locations only once when dialog first builds
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (isLoadingLocations) {
                _loadSuitableLocationsForDialog(
                  setModalState,
                  (locations) {
                    dialogAvailableLocations = locations;
                    isLoadingLocations = false;
                  },
                );
              }
            });

            return AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                children: [
                  const Text('Move Item'),
                  if (isLoadingLocations) ...[
                    const SizedBox(width: 12),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Location Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Location: ${getLocation()}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Zone: ${getZone()}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Text('Select New Location:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),

                    // Locations List with Loading State
                    Expanded(
                      child: isLoadingLocations
                          ? _buildLocationLoadingState()
                          : dialogAvailableLocations.isEmpty
                              ? _buildNoLocationsState(setModalState)
                              : _buildLocationsList(
                                  dialogAvailableLocations,
                                  selectedLocationId,
                                  (locationId) {
                                    setModalState(() {
                                      selectedLocationId = locationId;
                                    });
                                  },
                                ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isLoadingLocations ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedLocationId != null &&
                          !isMoving &&
                          !isLoadingLocations
                      ? () {
                          Navigator.pop(context);
                          _moveItem(selectedLocationId!,
                              notes.isNotEmpty ? notes : null);
                        }
                      : null,
                  child: isMoving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Move'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Fixed location loading method
  Future<void> _loadSuitableLocationsForDialog(
    StateSetter setModalState,
    Function(List<WarehouseLocation>) onLocationsLoaded,
  ) async {
    try {
      print('🔄 Loading suitable locations for move dialog...');

      if (parentProduct != null) {
        final suitableOptions =
            await _movementService.getSuitableLocationsForProduct(
          parentProduct!,
          excludeLocationId: productItem?.location,
        );

        final locations =
            suitableOptions.map((option) => option.location).toList();

        // Sort by suitability
        locations.sort((a, b) {
          final aOption = suitableOptions
              .firstWhere((opt) => opt.location.locationId == a.locationId);
          final bOption = suitableOptions
              .firstWhere((opt) => opt.location.locationId == b.locationId);

          if (aOption.isConsolidation && !bOption.isConsolidation) return -1;
          if (!aOption.isConsolidation && bOption.isConsolidation) return 1;

          return bOption.suitabilityScore.compareTo(aOption.suitabilityScore);
        });

        print('✅ Loaded ${locations.length} suitable locations');

        setModalState(() {
          onLocationsLoaded(locations);
        });
      } else {
        throw Exception('Product information not available');
      }
    } catch (e) {
      print('❌ Error loading locations: $e');
      setModalState(() {
        onLocationsLoaded([]);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load suitable locations: $e'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              setModalState(() {
                // Reset and retry
              });
              _loadSuitableLocationsForDialog(setModalState, onLocationsLoaded);
            },
          ),
        ),
      );
    }
  }

  // Fixed no locations state
  Widget _buildNoLocationsState(StateSetter setModalState) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Suitable Locations Found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No available locations match this product\'s storage requirements',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              setModalState(() {
                // Trigger reload
              });
              _loadSuitableLocationsForDialog(setModalState, (locations) {
                setModalState(() {
                  // Update will be handled by the callback
                });
              });
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue[600],
            ),
          ),
        ],
      ),
    );
  }

  // Fixed loading state widget
  Widget _buildLocationLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Finding suitable locations...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Analyzing warehouse capacity and product requirements',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Fixed locations list
  Widget _buildLocationsList(
    List<WarehouseLocation> locations,
    String? selectedLocationId,
    Function(String) onLocationSelected,
  ) {
    return ListView.builder(
      itemCount: locations.length,
      itemBuilder: (context, index) {
        final location = locations[index];
        final isSelected = selectedLocationId == location.locationId;
        final isConsolidation =
            location.isOccupied && location.productId == parentProduct?.id;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          child: Card(
            color: isSelected ? Colors.blue[50] : null,
            elevation: isSelected ? 2 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isSelected ? Colors.blue[300]! : Colors.grey[200]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: ListTile(
              leading: Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: _getZoneColor(location.zoneId),
                    child: Text(
                      location.zoneId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isConsolidation)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.merge_type,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              title: Text(
                location.locationId,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zone: ${location.zoneId} - ${_getZoneName(location.zoneId)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (isConsolidation)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Consolidation: ${location.quantityStored} units',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              trailing: isSelected
                  ? Icon(Icons.check_circle, color: Colors.blue[600])
                  : Icon(Icons.radio_button_unchecked, color: Colors.grey[400]),
              selected: isSelected,
              onTap: () => onLocationSelected(location.locationId),
            ),
          ),
        );
      },
    );
  }

  String _getZoneName(String zoneId) {
    switch (zoneId) {
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

  // void _showUpdateStatusDialog() {
  //   ProductItemsStatus? selectedStatus =
  //       ProductItemsStatus.values.byName(productItem!.status);
  //
  //   String notes = '';
  //
  //   showDialog(
  //     context: context,
  //     builder: (context) => StatefulBuilder(
  //       builder: (context, setModalState) => AlertDialog(
  //         title: const Text('Update Status'),
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             Text('Current Status: ${getStatus()}'),
  //             const SizedBox(height: 16),
  //             DropdownButtonFormField<ProductItemsStatus>(
  //               decoration: const InputDecoration(
  //                 labelText: 'New Status',
  //                 border: OutlineInputBorder(),
  //               ),
  //               value: selectedStatus,
  //               items: ProductItemsStatus.values.map((status) {
  //                 return DropdownMenuItem(
  //                   value: status,
  //                   child: Text(status.toString().split('.').last),
  //                 );
  //               }).toList(),
  //               onChanged: (value) {
  //                 setModalState(() {
  //                   selectedStatus = value;
  //                 });
  //               },
  //             ),
  //             const SizedBox(height: 16),
  //             TextField(
  //               decoration: const InputDecoration(
  //                 labelText: 'Notes (Optional)',
  //                 border: OutlineInputBorder(),
  //               ),
  //               onChanged: (value) => notes = value,
  //               maxLines: 3,
  //             ),
  //           ],
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(context),
  //             child: const Text('Cancel'),
  //           ),
  //           ElevatedButton(
  //             onPressed: selectedStatus != null &&
  //                     selectedStatus != productItem?.status
  //                 ? () {
  //                     Navigator.pop(context);
  //                     _updateItemStatus(
  //                         selectedStatus!, notes.isNotEmpty ? notes : null);
  //                   }
  //                 : null,
  //             child: const Text('Update'),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Add remaining UI methods...
  @override
  Widget build(BuildContext context) {
    final statusColor = getStatusColor();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Item ${getItemId()}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              getStatus().toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                color: statusColor.withOpacity(0.8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: statusColor.withOpacity(0.1),
        foregroundColor: statusColor,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            color: Colors.white,
            icon: const Icon(Icons.more_vert),
            onSelected: _handleAppBarMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Share Details'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'advanced',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Advanced Actions'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: statusColor,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: statusColor,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Location'),
            Tab(text: 'History'),
            Tab(text: 'Map'),
            Tab(text: 'Barcode'),
          ],
        ),
      ),
      body: _buildBody(),
      floatingActionButton: productItem != null
          ? FloatingActionButton.extended(
              onPressed: _showQuickActionsBottomSheet,
              backgroundColor: statusColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.flash_on),
              label: const Text('Quick Actions'),
            )
          : null,
    );
  }

  void _handleAppBarMenuAction(String action) {
    switch (action) {
      case 'refresh':
        _setupRealtimeUpdates();
        break;
      case 'export':
        _shareItemDetails();
        break;
      case 'move':
        _showMoveItemDialog();
        break;
      case 'advanced':
        _showAdvancedActionsBottomSheet();
        break;
    }
  }

  void _showQuickActionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionButton(
                          'Move Item',
                          Icons.drive_file_move,
                          Colors.blue,
                          () {
                            Navigator.pop(context);
                            _showMoveItemDialog();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionButton(
                          'QR Code',
                          Icons.qr_code,
                          Colors.purple,
                          () {
                            // Navigator.pop(context);
                            showDialog(
                              context: context,
                              builder: (context) => QRGeneratorDialog(
                                productId: widget.productItemId,
                                productName: 'Item ${getItemId()}',
                                category: getDisplayCategory(),
                                quantity: 1,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickActionButton(
                          'Barcode',
                          Icons.barcode_reader,
                          Colors.orange,
                          () {
                            Navigator.pop(context);
                            _downloadBarcodeAsPdf(widget.productItemId);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAdvancedActionsBottomSheet();
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('More Actions'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
      String title, IconData icon, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
            Text('Loading item details...'),
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
              const Text('Error Loading Item',
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

    if (productItem == null) {
      return const Center(child: Text('Product item not found'));
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildLocationTab(),
        _buildHistoryTab(),
        _buildMapTab(),
        _buildBarcodeTab(),
      ],
    );
  }

  // Continue with the rest of your existing UI methods...
  // Note: I'll include the key ones that need fixes

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildItemSummaryCard(),
          const SizedBox(height: 16),
          _buildProductInfoCard(),
          const SizedBox(height: 16),
          if (purchaseOrder != null) _buildPurchaseOrderCard(),
          if (relatedItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildRelatedItemsCard(),
          ],
          const SizedBox(height: 16),
          _buildQuickActionsCard(),
        ],
      ),
    );
  }

  // Add all your existing UI building methods here...
  // I'll include just the essential ones to keep within limits

  Widget _buildItemSummaryCard() {
    final statusColor = getStatusColor();
    final statusIcon = getStatusIcon();

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
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Item ${getItemId()}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          getStatus().toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
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
                    'Status',
                    getStatus(),
                    statusIcon,
                    statusColor,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Location',
                    locationDetails != null
                        ? locationDetails!.locationName
                        : 'Not assigned',
                    Icons.location_on,
                    locationDetails != null ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Zone',
                    getZone(),
                    Icons.map,
                    _getZoneColor(locationDetails?.zoneId ?? ''),
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Product',
                    getDisplayName(),
                    Icons.inventory,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard() {
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
                Icon(Icons.flash_on, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildActionButton(
                  'Move Item',
                  Icons.drive_file_move,
                  Colors.blue,
                  _showMoveItemDialog,
                ),
                _buildActionButton(
                  'Export PDF',
                  Icons.picture_as_pdf,
                  Colors.red,
                  _downloadCombinedLabel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      String title, IconData icon, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
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
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color),
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

  Color _getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'moved':
        return Colors.blue;
      case 'created':
        return Colors.green;
      case 'updated':
        return Colors.orange;
      case 'status_changed':
        return Colors.purple;
      case 'notes_added':
        return Colors.teal;
      case 'deleted':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'moved':
        return Icons.drive_file_move;
      case 'created':
        return Icons.add_circle;
      case 'updated':
        return Icons.edit;
      case 'status_changed':
        return Icons.update;
      case 'notes_added':
        return Icons.note_add;
      case 'deleted':
        return Icons.delete;
      default:
        return Icons.circle;
    }
  }

  String _formatActionText(ItemMovementHistory history) {
    switch (history.action.toLowerCase()) {
      case 'moved':
        return 'Moved from ${history.fromLocation ?? 'Unknown'} to ${history.toLocation ?? 'Unknown'}';
      case 'created':
        return 'Item created';
      case 'updated':
        return 'Item details updated';
      case 'status_changed':
        return 'Status changed from ${history.fromStatus?.toString().split('.').last ?? 'Unknown'} to ${history.toStatus?.toString().split('.').last ?? 'Unknown'}';
      case 'notes_added':
        return 'Notes added to item';
      default:
        return history.action;
    }
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  String _formatTime(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  Widget _buildProductInfoCard() {
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
                Icon(Icons.inventory, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Product Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _navigateToProductDetails,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('View Product'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Product Name', getDisplayName()),
            _buildDetailRow('Product ID', productItem?.productId ?? 'N/A'),
            _buildDetailRow('Category', getDisplayCategory()),
            _buildDetailRow('Brand', getDisplayBrand()),
            if (parentProduct?.description != null &&
                parentProduct!.description.isNotEmpty)
              _buildDetailRow('Description', parentProduct!.description),
            if (parentProduct?.partNumber != null)
              _buildDetailRow('Part Number', parentProduct!.partNumber!),
            if (parentProduct?.price != null)
              _buildDetailRow('Unit Price',
                  'RM ${parentProduct!.price!.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseOrderCard() {
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
                Icon(Icons.receipt, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Purchase Order Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow('PO Number', purchaseOrder!.poNumber),
            if (purchaseOrder!.supplierName.isNotEmpty)
              _buildDetailRow('Supplier', purchaseOrder!.supplierName),
            _buildDetailRow(
                'Status', purchaseOrder!.status.toString().split('.').last),
            _buildDetailRow(
                'Created Date', _formatDate(purchaseOrder!.createdDate)),
            if (purchaseOrder!.expectedDeliveryDate != null)
              _buildDetailRow('Expected Delivery',
                  _formatDate(purchaseOrder!.expectedDeliveryDate!)),
            _buildDetailRow('Created By', purchaseOrder!.createdByUserName),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedItemsCard() {
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
                Icon(Icons.group_work, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Related Items (${relatedItems.length})',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...relatedItems.take(5).map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.inventory_2,
                          color: Colors.blue[700], size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Item ${item.itemId}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Status: ${item.status.toString().split('.').last}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductItemDetailsScreen(
                              productItemId: item.itemId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      tooltip: 'View Item',
                    ),
                  ],
                ),
              );
            }).toList(),
            if (relatedItems.length > 5) ...[
              const SizedBox(height: 8),
              Text(
                '+ ${relatedItems.length - 5} more items',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCurrentLocationCard(),
          const SizedBox(height: 16),
          if (locationDetails != null) _buildLocationDetailsCard(),
        ],
      ),
    );
  }

  Widget _buildCurrentLocationCard() {
    final hasLocation = locationDetails != null;

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
                Icon(
                  Icons.location_on,
                  color: hasLocation ? Colors.green[700] : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Current Location',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (hasLocation) ...[
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
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getZoneColor(locationDetails!.zoneId),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            locationDetails!.zoneId,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                locationDetails!.locationName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                locationDetails!.zoneName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _showMoveItemDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          child: const Text('Move',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.location_off, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No Location Assigned',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _showMoveItemDialog,
                      child: const Text('Assign Location'),
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

  Widget _buildLocationDetailsCard() {
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
                  'Location Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Location ID', locationDetails!.locationId),
            _buildDetailRow('Zone',
                '${locationDetails!.zoneId} - ${locationDetails!.zoneName}'),
            _buildDetailRow(
                'Status', locationDetails!.isActive ? 'Active' : 'Inactive'),
            if (locationDetails!.description != null)
              _buildDetailRow('Description', locationDetails!.description!),
            if (locationDetails!.capacity != null)
              _buildDetailRow('Capacity', '${locationDetails!.capacity} items'),
            if (locationDetails!.currentOccupancy != null)
              _buildDetailRow('Current Occupancy',
                  '${locationDetails!.currentOccupancy} items'),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: Colors.white,
        elevation: 0,
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
                  Icon(Icons.history, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Movement History',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (movementHistory.isNotEmpty)
                    IconButton(
                      onPressed: _exportHistoryToPDF,
                      icon: Icon(Icons.download,
                          color: Colors.blue[600], size: 20),
                      tooltip: 'Export history',
                    ),
                ],
              ),
            ),
            if (movementHistory.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No History Available',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        'Movement history will appear here',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ...movementHistory.asMap().entries.map((entry) {
                final index = entry.key;
                final history = entry.value;
                final isLast = index == movementHistory.length - 1;

                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: isLast
                          ? BorderSide.none
                          : BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getActionColor(history.action)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            _getActionIcon(history.action),
                            color: _getActionColor(history.action),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatActionText(history),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              if (history.performedBy != null)
                                Text(
                                  'By: ${history.performedBy}',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600]),
                                ),
                              if (history.notes != null &&
                                  history.notes!.isNotEmpty)
                                Text(
                                  'Notes: ${history.notes}',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600]),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatDate(history.timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              _formatTime(history.timestamp),
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
          ],
        ),
      ),
    );
  }

  void _showHistoryFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter History'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.drive_file_move, color: Colors.blue[600]),
              title: const Text('Movement Records'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                // Implement filter logic
              },
            ),
            ListTile(
              leading: Icon(Icons.update, color: Colors.green[600]),
              title: const Text('Status Changes'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                // Implement filter logic
              },
            ),
            ListTile(
              leading: Icon(Icons.note_add, color: Colors.orange[600]),
              title: const Text('Notes Added'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                // Implement filter logic
              },
            ),
            ListTile(
              leading: Icon(Icons.clear_all, color: Colors.grey[600]),
              title: const Text('Show All'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                // Reset filters
              },
            ),
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

  Future<void> _exportHistoryToPDF() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
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
                      'Movement History Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Item: ${getItemId()} - ${getDisplayName()}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Generated on: ${DateTime.now().toString().split('.')[0]}',
                      style: const pw.TextStyle(
                          fontSize: 12, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'History Records (${movementHistory.length} total)',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              if (movementHistory.isEmpty)
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    'No movement history records found.',
                    style: const pw.TextStyle(fontSize: 14),
                    textAlign: pw.TextAlign.center,
                  ),
                )
              else
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Date/Time',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Action',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Details',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Performed By',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    ...movementHistory
                        .map((history) => pw.TableRow(
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Text(
                                    '${_formatDate(history.timestamp)}\n${_formatTime(history.timestamp)}',
                                    style: const pw.TextStyle(fontSize: 10),
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Text(
                                    history.action,
                                    style: const pw.TextStyle(fontSize: 10),
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Text(
                                    _formatActionText(history),
                                    style: const pw.TextStyle(fontSize: 10),
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Text(
                                    history.performedBy ?? 'Unknown',
                                    style: const pw.TextStyle(fontSize: 10),
                                  ),
                                ),
                              ],
                            ))
                        .toList(),
                  ],
                ),
            ];
          },
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final file = File(
          '${directory.path}/item_history_${widget.productItemId}_${DateTime.now().millisecondsSinceEpoch}.pdf');

      await file.writeAsBytes(await pdf.save());
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('History report saved to: ${file.path}'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Share',
            textColor: Colors.white,
            onPressed: () async {
              await Printing.sharePdf(
                  bytes: await pdf.save(),
                  filename: 'item_history_${widget.productItemId}.pdf');
            },
          ),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      print('Error generating history report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate history report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildMapTab() {
    if (locationDetails == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No Location Assigned',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Assign a location to view it on the map',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _showMoveItemDialog,
                child: const Text('Assign Location'),
              ),
            ],
          ),
        ),
      );
    }

    // Create a single location for the map with proper field handling
    final currentLocation = WarehouseLocation(
      locationId: locationDetails!.locationId,
      zoneId: locationDetails!.zoneId,
      isOccupied: true,
      productId: productItem!.productId,
      quantityStored: 1,
      occupiedDate: DateTime.now(),
      rackId: _extractRackId(locationDetails!.locationId),
      rowId: _extractRowId(locationDetails!.locationId),
      level: _extractLevel(locationDetails!.locationId)?.toInt() ?? 1,
      metadata: locationDetails!.coordinates != null
          ? {'coordinates': locationDetails!.coordinates}
          : null,
    );

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: getStatusColor().withOpacity(0.1),
            border: Border(
                bottom: BorderSide(color: getStatusColor().withOpacity(0.3))),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on, color: getStatusColor(), size: 20),
              const SizedBox(width: 8),
              Text(
                'Current Location: ${locationDetails!.locationName}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: getStatusColor(),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: getStatusColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  locationDetails!.zoneId,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: getStatusColor(),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: WarehouseMapScreen(
            productLocations: [currentLocation],
            productName: getDisplayName(),
          ),
        ),
      ],
    );
  }

  // Helper methods to extract location components from locationId
  String _extractRackId(String locationId) {
    final parts = locationId.split('-');
    if (parts.length >= 2) {
      return parts[1];
    }
    return 'A';
  }

  String _extractRowId(String locationId) {
    final parts = locationId.split('-');
    if (parts.length >= 3) {
      return parts[2];
    }
    return '01';
  }

  int? _extractLevel(String locationId) {
    final parts = locationId.split('-');
    for (final part in parts) {
      if (part.startsWith('L') && part.length > 1) {
        final levelStr = part.substring(1);
        return int.tryParse(levelStr);
      }
    }
    return 1;
  }

  Widget _buildBarcodeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQRCodeCard(),
          const SizedBox(height: 16),
          _buildBarcodeCard(),
        ],
      ),
    );
  }

  Widget _buildQRCodeCard() {
    return Card(
      elevation: 0,
      color: Colors.purple.withOpacity(0.1),
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
                        'Item QR Code',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scan to access item information',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
                    data: widget.productItemId,
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
                      Clipboard.setData(
                          ClipboardData(text: widget.productItemId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Item ID copied to clipboard')),
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

  Widget _buildBarcodeCard() {
    return Card(
      elevation: 0,
      color: Colors.green.withOpacity(0.1),
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
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.barcode_reader,
                      color: Colors.green[700], size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Item Barcode',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scan barcode for quick identification',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: RepaintBoundary(
                  key: _barcodeKey,
                  child: BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: widget.productItemId,
                    width: 250,
                    height: 80,
                    style: const TextStyle(fontSize: 12),
                    errorBuilder: (context, error) => Center(
                      child: Text('Error: $error'),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                widget.productItemId,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _downloadBarcodeAsPdf(widget.productItemId),
                    icon: const Icon(Icons.download, size: 20),
                    label: const Text('Download PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: widget.productItemId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Barcode data copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 20),
                    label: const Text('Copy Code'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green[600],
                      side: BorderSide(color: Colors.green[200]!),
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

  Widget _buildDetailRow(String label, String value) {
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

  // Enhanced barcode generation method
  Future<void> _downloadBarcodeAsPdf(String productId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final pdf = pw.Document();
      final barcode = Barcode.code128();
      final svg = barcode.toSvg(productId, width: 250, height: 80);

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
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Product Item Barcode',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green800,
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
                        'Item ID: ${getItemId()}',
                        style: const pw.TextStyle(
                            fontSize: 12, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(20),
                        decoration: pw.BoxDecoration(
                          border:
                              pw.Border.all(color: PdfColors.grey300, width: 2),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.SvgImage(svg: svg),
                      ),
                      pw.SizedBox(height: 16),
                      pw.Text(
                        productId,
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
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
                        'Item Information:',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      _buildPDFDetailRow('Product:', getDisplayName()),
                      _buildPDFDetailRow('Status:', getStatus()),
                      _buildPDFDetailRow('Location:', getLocation()),
                      _buildPDFDetailRow('Zone:', getZone()),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Generated on: ${DateTime.now().toString().split('.')[0]}',
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

      final directory = await getApplicationDocumentsDirectory();
      final file = File(
          '${directory.path}/item_barcode_${widget.productItemId}_${DateTime.now().millisecondsSinceEpoch}.pdf');

      await file.writeAsBytes(await pdf.save());
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode PDF saved to: ${file.path}'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Share',
            textColor: Colors.white,
            onPressed: () async {
              await Printing.sharePdf(
                  bytes: await pdf.save(),
                  filename: 'item_barcode_${widget.productItemId}.pdf');
            },
          ),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      print('Error generating barcode PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate barcode PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Advanced Actions Implementation
  void _showAdvancedActionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Advanced Actions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildAdvancedActionTile(
                    icon: Icons.inventory,
                    title: 'View Product Details',
                    subtitle: 'View complete product information',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToProductDetails();
                    },
                  ),
                  _buildAdvancedActionTile(
                    icon: Icons.print,
                    title: 'Print Labels',
                    subtitle: 'Print QR code and barcode labels',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      _showPrintOptionsDialog();
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing:
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  void _showPrintOptionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Print Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.qr_code, color: Colors.purple[600]),
              title: const Text('QR Code Label'),
              subtitle: const Text('Print QR code with item details'),
              onTap: () {
                Navigator.pop(context);
                _downloadQRCodeAsPDF();
              },
            ),
            ListTile(
              leading: Icon(Icons.barcode_reader, color: Colors.green[600]),
              title: const Text('Barcode Label'),
              subtitle: const Text('Print barcode with item details'),
              onTap: () {
                Navigator.pop(context);
                _downloadBarcodeAsPdf(widget.productItemId);
              },
            ),
            ListTile(
              leading: Icon(Icons.receipt, color: Colors.blue[600]),
              title: const Text('Combined Label'),
              subtitle: const Text('Print both QR code and barcode'),
              onTap: () {
                Navigator.pop(context);
                _downloadCombinedLabel();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadCombinedLabel() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Generate QR code programmatically without relying on widget
      Uint8List qrImageBytes;

      try {
        // Create a temporary QR widget to render
        final qrPainter = QrPainter(
          data: widget.productItemId,
          version: QrVersions.auto,
          gapless: false,
        );

        // Create a temporary picture recorder
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 200, 200));

        // Paint the QR code
        qrPainter.paint(canvas, const Size(200, 200));

        // Convert to image
        final picture = recorder.endRecording();
        final img = await picture.toImage(200, 200);
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          qrImageBytes = byteData.buffer.asUint8List();
        } else {
          throw Exception('Failed to generate QR code image');
        }

        picture.dispose();
      } catch (e) {
        print('Programmatic QR generation failed: $e');

        // Fallback: Try to use the widget if it's available
        if (_qrKey.currentContext != null) {
          RenderRepaintBoundary? qrBoundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

          if (qrBoundary != null) {
            ui.Image qrImage = await qrBoundary.toImage(pixelRatio: 3.0);
            ByteData? qrByteData =
            await qrImage.toByteData(format: ui.ImageByteFormat.png);

            if (qrByteData != null) {
              qrImageBytes = qrByteData.buffer.asUint8List();
            } else {
              throw Exception('Failed to generate QR code from widget');
            }
          } else {
            throw Exception('QR code widget render boundary not found');
          }
        } else {
          throw Exception('Cannot generate QR code: widget not available and programmatic generation failed');
        }
      }

      // Generate barcode
      final barcode = Barcode.code128();
      final barcodeSvg =
      barcode.toSvg(widget.productItemId, width: 250, height: 80);

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              children: [
                // Header
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
                        'Product Item Labels',
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
                        'Item ID: ${getItemId()}',
                        style: const pw.TextStyle(
                            fontSize: 12, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 30),

                // QR Code Section
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'QR Code',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.purple700,
                            ),
                          ),
                          pw.SizedBox(height: 16),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(16),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(
                                  color: PdfColors.grey300, width: 2),
                              borderRadius: pw.BorderRadius.circular(8),
                            ),
                            child: pw.Image(
                              pw.MemoryImage(qrImageBytes),
                              width: 150,
                              height: 150,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 30),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Item Details',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 16),
                          _buildPDFDetailRow('Item ID:', getItemId()),
                          _buildPDFDetailRow('Product:', getDisplayName()),
                          _buildPDFDetailRow('Status:', getStatus()),
                          _buildPDFDetailRow('Location:', getLocation()),
                          _buildPDFDetailRow('Zone:', getZone()),
                          if (purchaseOrder != null)
                            _buildPDFDetailRow('PO:', purchaseOrder!.poNumber),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 40),

                // Barcode Section
                pw.Column(
                  children: [
                    pw.Text(
                      'Barcode',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green700,
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(20),
                      decoration: pw.BoxDecoration(
                        border:
                        pw.Border.all(color: PdfColors.grey300, width: 2),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.SvgImage(svg: barcodeSvg),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      widget.productItemId,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                pw.Spacer(),

                // Footer
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
                        'Usage Instructions:',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '- Scan QR code for detailed item information',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        '- Scan barcode for quick item identification',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        '- Generated on: ${DateTime.now().toString().split('.')[0]}',
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

      final directory = await getApplicationDocumentsDirectory();
      final file = File(
          '${directory.path}/item_combined_label_${widget.productItemId}_${DateTime.now().millisecondsSinceEpoch}.pdf');

      await file.writeAsBytes(await pdf.save());
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Combined label saved to: ${file.path}'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Share',
            textColor: Colors.white,
            onPressed: () async {
              await Printing.sharePdf(
                  bytes: await pdf.save(),
                  filename: 'item_combined_label_${widget.productItemId}.pdf');
            },
          ),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      print('Error generating combined label: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate combined label: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _shareItemDetails() {
    final details = '''
Product Item Details
==================
Item ID: ${getItemId()}
Product: ${getDisplayName()}
Category: ${getDisplayCategory()}
Brand: ${getDisplayBrand()}
Status: ${getStatus()}
Location: ${getLocation()}
Zone: ${getZone()}

Purchase Order: ${purchaseOrder?.poNumber ?? 'N/A'}
Supplier: ${purchaseOrder?.supplierName ?? 'N/A'}

Generated on: ${DateTime.now().toString()}
''';

    // For sharing, you would typically use a package like share_plus
    // For now, we'll copy to clipboard
    Clipboard.setData(ClipboardData(text: details));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Item details copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red[600], size: 24),
            const SizedBox(width: 8),
            const Text('Delete Item'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Are you sure you want to delete this item? This action cannot be undone.'),
            const SizedBox(height: 16),
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
                  Text(
                    'Item: ${getItemId()}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text('Product: ${getDisplayName()}'),
                  Text('Status: ${getStatus()}'),
                  Text('Location: ${getLocation()}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteItem();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final batch = FirebaseFirestore.instance.batch();

      // Delete the product item
      final itemRef = FirebaseFirestore.instance
          .collection('productItems')
          .doc(widget.productItemId);
      batch.delete(itemRef);

      // Add deletion record to history
      final historyRef =
          FirebaseFirestore.instance.collection('productItemHistory').doc();

      batch.set(historyRef, {
        'id': historyRef.id,
        'productItemId': widget.productItemId,
        'action': 'deleted',
        'timestamp': FieldValue.serverTimestamp(),
        'performedBy':
            '${currentUser?.firstName} ${currentUser?.lastName}' ?? 'Unknown',
        'notes': 'Item permanently deleted',
      });

      // Update location occupancy if item was stored
      if (productItem?.location != null && productItem!.location!.isNotEmpty) {
        final locationRef = FirebaseFirestore.instance
            .collection('warehouseLocations')
            .doc(productItem!.location!);

        batch.update(locationRef, {
          'isOccupied': false,
          'productId': FieldValue.delete(),
          'quantityStored': FieldValue.delete(),
          'occupiedDate': FieldValue.delete(),
        });
      }

      await batch.commit();

      Navigator.of(context).pop(); // Close loading dialog
      Navigator.of(context).pop(); // Go back to previous screen

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      print('Error deleting item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addNotesToHistory(String notes) async {
    try {
      final historyRef =
          FirebaseFirestore.instance.collection('productItemHistory').doc();

      await historyRef.set({
        'id': historyRef.id,
        'productItemId': widget.productItemId,
        'action': 'notes_added',
        'timestamp': FieldValue.serverTimestamp(),
        'performedBy':
            '${currentUser?.firstName} ${currentUser?.lastName}' ?? 'Unknown',
        'notes': notes,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notes added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add notes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _duplicateItem() async {
    if (productItem == null) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final newItemRef =
          FirebaseFirestore.instance.collection('productItems').doc();

      await newItemRef.set({
        'productId': productItem!.productId,
        'purchaseOrderId': productItem!.purchaseOrderId,
        'status': ProductItemsStatus.inTransit.toString(),
        'location': null,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Create history record for the new item
      final historyRef =
          FirebaseFirestore.instance.collection('productItemHistory').doc();

      await historyRef.set({
        'id': historyRef.id,
        'productItemId': newItemRef.id,
        'action': 'created',
        'timestamp': FieldValue.serverTimestamp(),
        'performedBy':
            '${currentUser?.firstName} ${currentUser?.lastName}' ?? 'Unknown',
        'notes': 'Duplicated from item ${widget.productItemId}',
      });

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Item duplicated successfully. New item ID: ${newItemRef.id}'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductItemDetailsScreen(
                    productItemId: newItemRef.id,
                  ),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to duplicate item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddNotesDialog() {
    String notes = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Notes'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: 'Notes',
            border: OutlineInputBorder(),
            hintText: 'Enter notes about this item...',
          ),
          onChanged: (value) => notes = value,
          maxLines: 5,
          maxLength: 500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: notes.isNotEmpty
                ? () {
                    Navigator.pop(context);
                    _addNotesToHistory(notes);
                  }
                : null,
            child: const Text('Add Notes'),
          ),
        ],
      ),
    );
  }

  void _showDuplicateItemDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Item'),
        content: const Text(
            'This will create a new item with the same product details but different item ID. The new item will not be assigned to any location.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _duplicateItem();
            },
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );
  }
}
