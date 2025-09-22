// service/warehouse/warehouse_allocation_service.dart
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:assignment/models/warehouse_location.dart';
import 'package:assignment/models/purchase_order.dart';
import 'package:assignment/services/purchase_order/purchase_order_service.dart';
import 'package:assignment/models/product_item.dart';

import '../../models/product_model.dart' show Product;

class WarehouseAllocationService {
  static const String _warehouseCollectionName = 'warehouseLocations';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _warehouseCollection =>
      _firestore.collection(_warehouseCollectionName);

  // ==================== INITIALIZATION METHODS ====================

  /// Initialize all warehouse locations in Firebase (run once)
  Future<void> initializeWarehouseLocations() async {
    try {
      print('🏭 Initializing warehouse locations...');

      final batch = _firestore.batch();
      final allLocationIds = WarehouseConfig.getAllLocationIds();

      print('📍 Creating ${allLocationIds.length} warehouse locations');

      for (String locationId in allLocationIds) {
        final locationParts = locationId.split('-');
        final zoneId = locationParts[0];
        final rackId = locationParts[1];
        final rowId = locationParts[2];
        final level = int.parse(locationParts[3]);

        final location = WarehouseLocation(
          locationId: locationId,
          zoneId: zoneId,
          rackId: rackId,
          rowId: rowId,
          level: level,
          isOccupied: false,
        );

        batch.set(
            _warehouseCollection.doc(locationId),
            location.toFirestore()
        );
      }

      await batch.commit();
      print('✅ Warehouse locations initialized successfully');


    } catch (e) {
      print('❌ Error initializing warehouse locations: $e');
      throw Exception('Failed to initialize warehouse locations: $e');
    }
  }

  /// Check if warehouse is initialized
  Future<bool> isWarehouseInitialized() async {
    try {
      final snapshot = await _warehouseCollection.limit(1).get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<List<WarehouseLocationWithCapacity>> _findConsolidationOpportunities(
      String productId,
      int quantityNeeded,
      ) async {
    try {
      print('🔄 Looking for consolidation opportunities for $quantityNeeded units of product $productId');

      // Query for same product from ANY PO (not just current PO)
      final snapshot = await _warehouseCollection
          .where('productId', isEqualTo: productId)
          .where('isOccupied', isEqualTo: true)
          .get(); // Remove ordering here, we'll sort in memory

      print('📍 Found ${snapshot.docs.length} existing locations with product $productId');

      final opportunities = <WarehouseLocationWithCapacity>[];

      for (final doc in snapshot.docs) {
        final location = WarehouseLocation.fromFirestore(doc.data() as Map<String, dynamic>);

        // 🐛 CRITICAL: Make sure this method returns correct capacity
        final maxCapacity = _getMaxCapacityForLocation(location);
        final currentQuantity = location.quantityStored ?? 0;
        final availableCapacity = maxCapacity - currentQuantity;

        print('   📦 Location ${location.locationId}:');
        print('      - Current: $currentQuantity units');
        print('      - Max capacity: $maxCapacity units');
        print('      - Available: $availableCapacity units');
        print('      - From PO: ${location.purchaseOrderId}');

        // Only add if there's available capacity
        if (availableCapacity > 0) {
          opportunities.add(WarehouseLocationWithCapacity(
            location: location,
            maxCapacity: maxCapacity,
            currentQuantity: currentQuantity,
            availableCapacity: availableCapacity,
          ));

          print('   ✅ Added as consolidation opportunity: ${location.locationId} can take $availableCapacity more units');
        } else {
          print('   ❌ Location ${location.locationId} is at full capacity');
        }
      }

      // Sort by available capacity (locations with most available space first)
      opportunities.sort((a, b) => b.availableCapacity.compareTo(a.availableCapacity));

      print('🎯 Final consolidation opportunities: ${opportunities.length}');
      for (final opp in opportunities) {
        print('   - ${opp.location.locationId}: ${opp.availableCapacity} units available');
      }

      return opportunities;

    } catch (e) {
      print('❌ Error finding consolidation opportunities: $e');
      return [];
    }
  }



  // ==================== ALLOCATION ALGORITHM ====================

  Future<StorageAllocationResult> calculateStorageAllocation(
      Product product,
      PurchaseOrder purchaseOrder,
      int quantityToStore,
      ) async {
    try {
      print('');
      print('🧮 ========== ALLOCATION CALCULATION DEBUG ==========');
      print('🧮 Product: ${product.name} (ID: ${product.id})');
      print('🧮 PO: ${purchaseOrder.poNumber} (ID: ${purchaseOrder.id})');
      print('🧮 Quantity to store: $quantityToStore units');
      print('');

      final allocationPlan = <LocationAllocationPlan>[];
      int remainingQuantity = quantityToStore;

      // STEP 1: Check for consolidation opportunities
      print('📍 STEP 1: Looking for consolidation opportunities...');
      final consolidationOpportunities = await _findConsolidationOpportunities(
        product.id,
        quantityToStore,
      );

      if (consolidationOpportunities.isEmpty) {
        print('   ❌ No consolidation opportunities found');
      } else {
        print('   ✅ Found ${consolidationOpportunities.length} consolidation opportunities');
      }

      // Try to use existing locations first
      for (final opportunity in consolidationOpportunities) {
        if (remainingQuantity <= 0) break;

        final canTake = math.min(remainingQuantity, opportunity.availableCapacity);
        if (canTake > 0) {
          allocationPlan.add(LocationAllocationPlan(
            location: opportunity.location,
            quantityToPlace: canTake,
            isConsolidation: true,
            consolidationInfo: ConsolidationInfo(
              existingPO: opportunity.location.purchaseOrderId ?? 'Unknown',
              existingQuantity: opportunity.currentQuantity,
              newQuantity: canTake,
              totalAfter: opportunity.currentQuantity + canTake,
            ),
          ));

          remainingQuantity -= canTake;
          print('   📦 CONSOLIDATION PLANNED:');
          print('      - Location: ${opportunity.location.locationId}');
          print('      - Taking: $canTake units');
          print('      - Existing PO: ${opportunity.location.purchaseOrderId}');
          print('      - Will have: ${opportunity.currentQuantity + canTake} total units');
          print('      - Remaining to allocate: $remainingQuantity units');
        }
      }

      // STEP 2: Find new locations for remaining quantity
      if (remainingQuantity > 0) {
        print('');
        print('📍 STEP 2: Need $remainingQuantity more units in new locations');

        final targetZone = _determineTargetZone(product);
        print('   🎯 Target zone: $targetZone');

        final availableLocations = await _findAvailableLocations(
          targetZone,
          product,
          remainingQuantity,
        );

        print('   📍 Found ${availableLocations.length} available locations');

        // Allocate remaining quantity across new locations
        for (final location in availableLocations) {
          if (remainingQuantity <= 0) break;

          final maxCapacity = _getMaxCapacityForLocation(location);
          final canTake = math.min(remainingQuantity, maxCapacity);

          allocationPlan.add(LocationAllocationPlan(
            location: location,
            quantityToPlace: canTake,
            isConsolidation: false,
          ));

          remainingQuantity -= canTake;
          print('   🆕 NEW LOCATION PLANNED:');
          print('      - Location: ${location.locationId}');
          print('      - Taking: $canTake units');
          print('      - Remaining to allocate: $remainingQuantity units');
        }
      }

      print('');
      print('📊 FINAL ALLOCATION PLAN:');
      for (int i = 0; i < allocationPlan.length; i++) {
        final plan = allocationPlan[i];
        print('   ${i + 1}. ${plan.location.locationId}: ${plan.quantityToPlace} units (${plan.isConsolidation ? "CONSOLIDATION" : "NEW"})');
      }

      // Check if we can accommodate all quantity
      if (remainingQuantity > 0) {
        print('❌ ALLOCATION FAILED: $remainingQuantity units could not be allocated');
        print('🧮 ========== END ALLOCATION DEBUG ==========');
        return StorageAllocationResult(
          success: false,
          errorMessage: 'Insufficient space: $remainingQuantity units could not be allocated',
        );
      }

      print('✅ ALLOCATION SUCCESS: All $quantityToStore units allocated across ${allocationPlan.length} locations');
      print('🧮 ========== END ALLOCATION DEBUG ==========');
      print('');

      return StorageAllocationResult(
        success: true,
        targetZone: _determineTargetZone(product),
        availableLocations: allocationPlan.map((plan) => plan.location).toList(),
        allocationReasoning: _buildEnhancedAllocationReasoning(product, allocationPlan),
        allocationPlan: allocationPlan,
      );

    } catch (e) {
      print('❌ Error in enhanced storage allocation: $e');
      print('🧮 ========== END ALLOCATION DEBUG ==========');
      return StorageAllocationResult(
        success: false,
        errorMessage: 'Allocation calculation failed: $e',
      );
    }
  }

  Future<void> executeMultiLocationStorageAllocation(
      List<LocationAllocationPlan> allocationPlan,
      Product product,
      PurchaseOrder purchaseOrder,
      PurchaseOrderService purchaseOrderService,
      ) async {
    try {
      print('📥 Executing multi-location storage allocation for ${allocationPlan.length} locations');

      final batch = _firestore.batch();
      int totalProcessed = 0;

      for (final plan in allocationPlan) {
        await _executeIndividualPlacement(
          plan,
          product,
          purchaseOrder,
          batch,
        );
        totalProcessed += plan.quantityToPlace;
      }

      // Update POLineItem's quantityPlaced field (total across all locations)
      await _updatePOLineItemQuantityPlaced(
        purchaseOrder,
        product.id,
        totalProcessed,
        batch,
        purchaseOrderService,
      );

      // Update ProductItem status and locations
      await _updateProductItemsStatusMultiLocation(
        purchaseOrder.id,
        product.id,
        allocationPlan,
        batch,
      );

      await batch.commit();

      print('✅ Multi-location storage completed: $totalProcessed units across ${allocationPlan.length} locations');

      // 🆕 NEW: Check if ALL received items are now placed and update PO status to READY
      await _checkAndUpdatePOStatusToReady(purchaseOrder, purchaseOrderService);

    } catch (e) {
      throw Exception('Failed to execute multi-location storage: $e');
    }
  }

  Future<void> _checkAndUpdatePOStatusToReady(
      PurchaseOrder purchaseOrder,
      PurchaseOrderService purchaseOrderService,
      ) async {
    try {
      // Only check if PO is currently COMPLETED (meaning all items received)
      if (purchaseOrder.status == POStatus.COMPLETED) {
        final allItemsPlaced = await _areAllReceivedItemsPlaced(
          purchaseOrder.id,
          purchaseOrderService,
        );

        if (allItemsPlaced) {
          await purchaseOrderService.updatePurchaseOrderStatus(
            purchaseOrder.id,
            POStatus.READY,
            updatedByUserId: 'warehouse_system',
          );
          print('✅ Purchase Order ${purchaseOrder.poNumber} updated to READY - all received items placed');
        } else {
          print('ℹ️ Purchase Order ${purchaseOrder.poNumber} remains COMPLETED - some received items not yet placed');
        }
      }
      // Also check PARTIALLY_RECEIVED status
      else if (purchaseOrder.status == POStatus.PARTIALLY_RECEIVED) {
        final allReceivedItemsPlaced = await _areAllReceivedItemsPlaced(
          purchaseOrder.id,
          purchaseOrderService,
        );

        if (allReceivedItemsPlaced) {
          // Check if ALL items (including not yet received) are actually fully received
          final allItemsFullyReceived = await _areAllItemsFullyReceived(
            purchaseOrder.id,
            purchaseOrderService,
          );

          if (allItemsFullyReceived) {
            // Update to READY since everything is received and placed
            await purchaseOrderService.updatePurchaseOrderStatus(
              purchaseOrder.id,
              POStatus.READY,
              updatedByUserId: 'warehouse_system',
            );
            print('✅ Purchase Order ${purchaseOrder.poNumber} updated to READY - all items received and placed');
          } else {
            print('ℹ️ Purchase Order ${purchaseOrder.poNumber} remains PARTIALLY_RECEIVED - some items not fully received yet');
          }
        }
      }

    } catch (e) {
      print('❌ Error checking PO status update: $e');
      // Don't throw error here as storage was successful
    }
  }

  Future<bool> _areAllItemsFullyReceived(
      String purchaseOrderId,
      PurchaseOrderService purchaseOrderService,
      ) async {
    try {
      // Get the current PO with latest data
      final po = await purchaseOrderService.getPurchaseOrder(purchaseOrderId);
      if (po == null) return false;

      // Check each line item
      for (final lineItem in po.lineItems) {
        final orderedQty = lineItem.quantityOrdered;
        final receivedQty = lineItem.quantityReceived ?? 0;

        // If any item is not fully received, return false
        if (receivedQty < orderedQty) {
          print('   📦 Product ${lineItem.productName}: Ordered $orderedQty, Received $receivedQty - NOT fully received');
          return false;
        }
      }

      print('   ✅ All items have been fully received');
      return true;

    } catch (e) {
      print('❌ Error checking if all items are fully received: $e');
      return false;
    }
  }


  Future<void> _executeIndividualPlacement(
      LocationAllocationPlan plan,
      Product product,
      PurchaseOrder purchaseOrder,
      WriteBatch batch,
      ) async {
    final location = plan.location;
    final quantityToPlace = plan.quantityToPlace;

    // Calculate new total quantity
    final newTotalQuantity = plan.isConsolidation
        ? (location.quantityStored ?? 0) + quantityToPlace
        : quantityToPlace;

    // FIXED: Handle null safety properly for metadata
    final existingMetadata = location.metadata ?? <String, dynamic>{};
    final existingConsolidatedPOs = (existingMetadata['consolidatedPOs'] as List<dynamic>?)
        ?.cast<String>() ?? [];

    // Build the metadata map properly
    Map<String, dynamic> newMetadata = {
      ...existingMetadata,
      'productCategory': product.category ?? 'unknown',
      'lastUpdateDate': DateTime.now().toIso8601String(),
      'isConsolidated': plan.isConsolidation,
    };

    // Add consolidation-specific or new placement-specific metadata
    if (plan.isConsolidation) {
      // For consolidation, preserve existing PO info and add new PO info
      newMetadata.addAll({
        'poNumber': existingMetadata['poNumber'] ?? '',
        'supplierName': existingMetadata['supplierName'] ?? '',
        'consolidatedPOs': [
          ...existingConsolidatedPOs,
          location.purchaseOrderId ?? '',
          purchaseOrder.id,
        ].where((id) => id.isNotEmpty).toSet().toList(),
        'latestPO': purchaseOrder.id,
        'latestPONumber': purchaseOrder.poNumber,
        'consolidationCount': (existingMetadata['consolidationCount'] as int? ?? 0) + 1,
      });
    } else {
      // For new placement
      newMetadata.addAll({
        'poNumber': purchaseOrder.poNumber,
        'supplierName': purchaseOrder.supplierName,
        'storageReason': 'Purchase Order Receipt',
      });
    }

    // Create updated location
    final updatedLocation = location.copyWith(
      isOccupied: true,
      // For consolidation, keep original PO, for new placement use current PO
      purchaseOrderId: plan.isConsolidation ? location.purchaseOrderId : purchaseOrder.id,
      productId: product.id,
      productName: product.name,
      quantityStored: newTotalQuantity,
      occupiedDate: location.occupiedDate ?? DateTime.now(),
      metadata: newMetadata,
    );

    // Update warehouse location
    batch.update(
      _warehouseCollection.doc(location.locationId),
      updatedLocation.toFirestore(),
    );

    print('📦 Prepared update for ${location.locationId}: $quantityToPlace units (${plan.isConsolidation ? "consolidation" : "new"})');
  }


  Future<void> _updateProductItemsStatusMultiLocation(
      String purchaseOrderId,
      String productId,
      List<LocationAllocationPlan> allocationPlan,
      WriteBatch batch,
      ) async {
    try {
      // Get ProductItems with 'received' status
      final snapshot = await _firestore
          .collection('productItems')
          .where('purchaseOrderId', isEqualTo: purchaseOrderId)
          .where('productId', isEqualTo: productId)
          .where('status', isEqualTo: ProductItemStatus.received)
          .get();

      print('Found ${snapshot.docs.length} ProductItems to update');

      int processedCount = 0;

      // Process each allocation plan
      for (final plan in allocationPlan) {
        final quantityForThisLocation = plan.quantityToPlace;

        // Update ProductItems for this specific location
        for (int i = 0; i < quantityForThisLocation && processedCount < snapshot.docs.length; i++) {
          final doc = snapshot.docs[processedCount];

          batch.update(doc.reference, {
            'status': ProductItemStatus.stored,
            'location': plan.location.locationId,
          });

          processedCount++;
        }
      }

      print('✅ Updated $processedCount ProductItems across ${allocationPlan.length} locations');

    } catch (e) {
      print('❌ Error updating ProductItems: $e');
      throw Exception('Failed to update ProductItems: $e');
    }
  }

  Map<String, dynamic> _buildEnhancedAllocationReasoning(
      Product product,
      List<LocationAllocationPlan> allocationPlan,
      ) {
    final consolidations = allocationPlan.where((plan) => plan.isConsolidation).length;
    final newLocations = allocationPlan.where((plan) => !plan.isConsolidation).length;

    final reasoning = <String, String>{};

    if (consolidations > 0) {
      reasoning['consolidation'] = 'Consolidated with existing stock in $consolidations location(s)';
      reasoning['efficiency'] = 'Maximizes space utilization and reduces picking locations';
    }

    if (newLocations > 0) {
      reasoning['newPlacements'] = 'Created $newLocations new storage location(s)';
    }

    final targetZone = _determineTargetZone(product);
    final zoneConfig = WarehouseConfig.zones[targetZone];
    reasoning['zoneSelection'] = 'Zone $targetZone selected based on product characteristics';

    return {
      'targetZone': targetZone,
      'zoneName': zoneConfig?.name ?? 'Unknown Zone',
      'reasoning': reasoning,
      'consolidationSummary': {
        'totalLocations': allocationPlan.length,
        'consolidatedLocations': consolidations,
        'newLocations': newLocations,
        'spaceOptimized': consolidations > 0,
      },
      'productProperties': {
        'movementFrequency': product.movementFrequency,
        'storageType': product.storageType,
        'requiresClimateControl': product.requiresClimateControl,
        'isHazardousMaterial': product.isHazardousMaterial,
      },
    };
  }

  bool _canAccommodateAdditionalQuantity(
      WarehouseLocation location,
      int additionalQuantity
      ) {
    // Define maximum capacity per location based on zone and level
    final maxCapacityPerLocation = _getMaxCapacityForLocation(location);
    final currentQuantity = location.quantityStored ?? 0;
    final totalAfterAddition = currentQuantity + additionalQuantity;

    final canAccommodate = totalAfterAddition <= maxCapacityPerLocation;

    print('📊 Location ${location.locationId}: current=$currentQuantity, adding=$additionalQuantity, max=$maxCapacityPerLocation, canAccommodate=$canAccommodate');

    return canAccommodate;
  }

  int _getMaxCapacityForLocation(WarehouseLocation location) {
    return 100;
  }

  Future<WarehouseLocation?> _findExistingProductLocation(
      String purchaseOrderId,
      String productId
      ) async {
    try {
      print('🔍 Checking for existing storage of product $productId from PO $purchaseOrderId');

      final snapshot = await _warehouseCollection
          .where('purchaseOrderId', isEqualTo: purchaseOrderId)
          .where('productId', isEqualTo: productId)
          .where('isOccupied', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final location = WarehouseLocation.fromFirestore(
            snapshot.docs.first.data() as Map<String, dynamic>
        );
        print('✅ Found existing location: ${location.locationId} with ${location.quantityStored} units');
        return location;
      }

      print('ℹ️ No existing location found for this product and PO');
      return null;
    } catch (e) {
      print('❌ Error finding existing location: $e');
      return null;
    }
  }

  /// Determine target zone based on product properties and priority rules
  String _determineTargetZone(Product product) {
    // Priority Rule 1: Hazardous materials → Zone 6 (highest priority)
    if (product.isHazardousMaterial == true) {
      print('⚠️ Hazardous material detected → Zone 6');
      return 'Z6';
    }

    // Priority Rule 2: Climate control → Zone 5 (unless hazardous)
    if (product.requiresClimateControl == true) {
      print('🌡️ Climate control required → Zone 5');
      return 'Z5';
    }

    // Priority Rule 3: Bulk storage → Zone 4 (unless hazardous/climate)
    if (product.storageType == 'bulk') {
      print('📦 Bulk storage type → Zone 4');
      return 'Z4';
    }

    // Priority Rule 4: Movement frequency → Zones 1-3 (default)
    switch (product.movementFrequency) {
      case 'fast':
        print('⚡ Fast-moving product → Zone 1');
        return 'Z1';
      case 'medium':
        print('🚶 Medium-moving product → Zone 2');
        return 'Z2';
      case 'slow':
      default:
        print('🐌 Slow-moving product → Zone 3');
        return 'Z3';
    }
  }

  /// Find available locations in the target zone
  Future<List<WarehouseLocation>> _findAvailableLocations(
      String targetZone,
      Product product,
      int quantityNeeded,
      ) async {
    try {
      print('🔍 Querying available locations in $targetZone...');

      // Query available locations in target zone
      final snapshot = await _warehouseCollection
          .where('zoneId', isEqualTo: targetZone)
          .where('isOccupied', isEqualTo: false)
          .orderBy('locationId')
          .get();

      print('📋 Firebase query returned ${snapshot.docs.length} documents');

      final availableLocations = snapshot.docs
          .map((doc) => WarehouseLocation.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();

      print('📦 Converted to ${availableLocations.length} WarehouseLocation objects');

      // Check if locations list is empty before filtering
      if (availableLocations.isEmpty) {
        print('❌ No unoccupied locations found in zone $targetZone');
        return [];
      }

      // Filter locations based on storage requirements within zone
      final suitableLocations = _filterLocationsByStorageRequirements(
        availableLocations,
        product,
      );

      print('✅ After filtering: ${suitableLocations.length} suitable locations');
      print('🏗️ Product storage requirements: storageType=${product.storageType}, weight=${product.weight}, volume=${product.volume}');

      // Sort by optimal placement (lower levels for heavy items, etc.)
      suitableLocations.sort((a, b) => _compareLocationSuitability(a, b, product));

      // Return enough locations for the quantity
      // final result = suitableLocations.take(quantityNeeded).toList();
      // print('🎯 Returning ${result.length} locations for quantity $quantityNeeded');
      //
      // return result;

      print('🎯 Returning all ${suitableLocations.length} suitable locations (quantity needed: $quantityNeeded)');

      return suitableLocations;

    } catch (e) {
      print('❌ Error finding available locations: $e');
      return [];
    }
  }

  /// Filter locations based on storage requirements
  List<WarehouseLocation> _filterLocationsByStorageRequirements(
      List<WarehouseLocation> locations,
      Product product,
      ) {
    if (locations.isEmpty) {
      print('⚠️ No locations to filter');
      return locations;
    }

    final zoneConfig = WarehouseConfig.zones[locations.first.zoneId];
    print('🔧 Zone config for ${locations.first.zoneId}: ${zoneConfig?.name}');

    if (zoneConfig == null) {
      print('⚠️ No zone config found, returning all locations');
      return locations;
    }

    print('📝 Supported storage types in zone: ${zoneConfig.supportedStorageTypes}');

    final filtered = locations.where((location) {
      // Check if storage type is supported in this zone
      if (product.storageType != null &&
          !zoneConfig.supportedStorageTypes.contains(product.storageType)) {
        print('❌ Location ${location.locationId} filtered out: storage type ${product.storageType} not supported');
        return false;
      }

      // For heavy items (>50kg), prefer ground level (level 1) or floor storage
      if ((product.weight ?? 0) > 50 && location.level > 2) {
        print('❌ Location ${location.locationId} filtered out: too high for heavy item (level ${location.level})');
        return false;
      }

      // For large items, prefer lower levels and certain storage types
      if (_isLargeItem(product) && location.level > 3) {
        print('❌ Location ${location.locationId} filtered out: too high for large item (level ${location.level})');
        return false;
      }

      print('✅ Location ${location.locationId} passed all filters');
      return true;
    }).toList();

    return filtered;
  }

  /// Compare location suitability for optimal placement
  int _compareLocationSuitability(WarehouseLocation a, WarehouseLocation b, Product product) {
    // Heavy items: prefer lower levels
    if ((product.weight ?? 0) > 50) {
      return a.level.compareTo(b.level);
    }

    // Large items: prefer lower levels
    if (_isLargeItem(product)) {
      return a.level.compareTo(b.level);
    }

    // Default: prefer accessible locations (lower levels, front rows)
    final aScore = a.level + (a.rowId == 'A' ? 0 : 1);
    final bScore = b.level + (b.rowId == 'A' ? 0 : 1);
    return aScore.compareTo(bScore);
  }

  /// Check if item is considered large based on dimensions
  bool _isLargeItem(Product product) {
    if (product.dimensions == null) return false;

    final volume = product.volume;
    return volume > 0.5; // Threshold: 0.5 cubic meters
  }

  /// Build allocation reasoning for user display
  Map<String, dynamic> _buildAllocationReasoning(Product product, String targetZone) {
    final reasoning = <String, String>{};
    final zoneConfig = WarehouseConfig.zones[targetZone];

    // Explain why this zone was chosen
    if (product.isHazardousMaterial == true) {
      reasoning['primary'] = 'Hazardous material requires specialized storage';
      reasoning['safety'] = 'Zone 6 has proper safety equipment and isolation';
    } else if (product.requiresClimateControl == true) {
      reasoning['primary'] = 'Product requires climate-controlled environment';
      reasoning['quality'] = 'Zone 5 maintains optimal temperature and humidity';
    } else if (product.storageType == 'bulk') {
      reasoning['primary'] = 'Bulk storage type requires dedicated area';
      reasoning['efficiency'] = 'Zone 4 optimized for bulk storage operations';
    } else {
      reasoning['primary'] = 'Allocated based on movement frequency: ${product.movementFrequency}';
      reasoning['efficiency'] = '${zoneConfig?.name} optimizes picking efficiency';
    }

    // Add additional considerations
    if ((product.weight ?? 0) > 50) {
      reasoning['weight'] = 'Heavy item will be placed on lower levels';
    }

    if (_isLargeItem(product)) {
      reasoning['size'] = 'Large dimensions require accessible placement';
    }

    return {
      'targetZone': targetZone,
      'zoneName': zoneConfig?.name ?? 'Unknown Zone',
      'reasoning': reasoning,
      'productProperties': {
        'movementFrequency': product.movementFrequency,
        'storageType': product.storageType,
        'requiresClimateControl': product.requiresClimateControl,
        'isHazardousMaterial': product.isHazardousMaterial,
        'weight': product.weight,
        'volume': product.volume,
      },
    };
  }

  // ==================== STORAGE EXECUTION METHODS ====================

  /// Execute storage allocation
  /// Execute storage allocation
  /// Execute storage allocation
  Future<void> executeStorageAllocation(
      WarehouseLocation location,
      Product product,
      PurchaseOrder purchaseOrder,
      int quantityStored,
      PurchaseOrderService purchaseOrderService
      ) async {
    try {
      print('📥 Executing storage allocation at ${location.locationId}');

      final batch = _firestore.batch();

      // Check if this is consolidation (adding to existing) or new placement
      final isConsolidation = location.isOccupied &&
          location.purchaseOrderId == purchaseOrder.id &&
          location.productId == product.id;

      final updatedLocation = location.copyWith(
        isOccupied: true,
        purchaseOrderId: purchaseOrder.id,
        productId: product.id,
        productName: product.name,
        quantityStored: isConsolidation
            ? (location.quantityStored ?? 0) + quantityStored  // Add to existing
            : quantityStored,  // New placement
        occupiedDate: location.occupiedDate ?? DateTime.now(), // Keep original date if consolidating
        metadata: {
          ...?location.metadata, // Preserve existing metadata
          'poNumber': purchaseOrder.poNumber,
          'supplierName': purchaseOrder.supplierName,
          'productCategory': product.category ?? 'unknown',
          'storageReason': isConsolidation ? 'Partial Delivery Consolidation' : 'Purchase Order Receipt',
          'lastUpdateDate': DateTime.now().toIso8601String(),
          'totalReceived': (location.quantityStored ?? 0) + quantityStored,
          'consolidationCount': ((location.metadata?['consolidationCount'] as int?) ?? 0) + (isConsolidation ? 1 : 0),
        },
      );

      // Update warehouse location
      batch.update(
          _warehouseCollection.doc(location.locationId),
          updatedLocation.toFirestore()
      );

      // NEW: Update POLineItem's quantityPlaced field
      await _updatePOLineItemQuantityPlaced(
          purchaseOrder,
          product.id,
          quantityStored,
          batch,
          purchaseOrderService
      );

      await _updateProductItemsStatus(
        purchaseOrder.id,
        product.id,
        quantityStored,
        batch,
        location.locationId,
      );

      await batch.commit();

      if (isConsolidation) {
        print('✅ Consolidated ${quantityStored} units with existing ${location.quantityStored} units');
      } else {
        print('✅ New storage allocation executed successfully');
      }


      if (purchaseOrder.status == POStatus.COMPLETED) {
        final allItemsPlaced = await _areAllReceivedItemsPlaced(purchaseOrder.id, purchaseOrderService);

        if (allItemsPlaced) {
          await purchaseOrderService.updatePurchaseOrderStatus(
            purchaseOrder.id,
            POStatus.READY,
            updatedByUserId: 'warehouse_system',
          );
          print('✅ Purchase Order ${purchaseOrder.poNumber} updated to READY - all received items placed');
        } else {
          print('ℹ️ Purchase Order ${purchaseOrder.poNumber} remains COMPLETED - some received items not yet placed');
        }
      }

    } catch (e) {
      throw Exception('Failed to execute storage allocation: $e');
    }
  }

  Future<bool> _areAllReceivedItemsPlaced(
      String purchaseOrderId,
      PurchaseOrderService purchaseOrderService,
      ) async {
    try {
      // Get the current PO with latest data
      final po = await purchaseOrderService.getPurchaseOrder(purchaseOrderId);
      if (po == null) return false;

      // Check each line item
      for (final lineItem in po.lineItems) {
        final receivedQty = lineItem.quantityReceived ?? 0;
        final placedQty = lineItem.quantityPlaced ?? 0;

        // If there are received items that haven't been placed, return false
        if (receivedQty > 0 && placedQty < receivedQty) {
          print('   📦 Product ${lineItem.productName}: Received $receivedQty, Placed $placedQty - NOT fully placed');
          return false;
        }
      }

      print('   ✅ All received items have been placed in warehouse locations');
      return true;

    } catch (e) {
      print('❌ Error checking if all received items are placed: $e');
      return false;
    }
  }



  Future<List<WarehouseLocation>> findExistingProductLocations(
      String purchaseOrderId,
      String productId
      ) async {
    try {
      print('🔍 Finding all existing locations for product $productId from PO $purchaseOrderId');

      final snapshot = await _warehouseCollection
          .where('purchaseOrderId', isEqualTo: purchaseOrderId)
          .where('productId', isEqualTo: productId)
          .where('isOccupied', isEqualTo: true)
          .get();

      final locations = snapshot.docs
          .map((doc) => WarehouseLocation.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();

      print('✅ Found ${locations.length} existing locations for this product and PO');
      return locations;
    } catch (e) {
      print('❌ Error finding existing locations: $e');
      return [];
    }
  }

  /// Update POLineItem's quantityPlaced field
  Future<void> _updatePOLineItemQuantityPlaced(
      PurchaseOrder purchaseOrder,
      String productId,
      int quantityPlaced,
      WriteBatch batch,
      PurchaseOrderService purchaseOrderService
      ) async {
    try {
      print('🔄 Updating POLineItem quantityPlaced for product $productId');

      // Find the line item for this product
      final lineItemIndex = purchaseOrder.lineItems.indexWhere(
              (item) => item.productId == productId
      );

      if (lineItemIndex == -1) {
        print('❌ Line item not found for product $productId');
        return;
      }

      final currentLineItem = purchaseOrder.lineItems[lineItemIndex];
      final currentPlaced = currentLineItem.quantityPlaced ?? 0;
      final newQuantityPlaced = currentPlaced + quantityPlaced;

      // Create updated line item
      final updatedLineItem = currentLineItem.copyWith(
        quantityPlaced: newQuantityPlaced,
      );

      // Create updated line items list
      final updatedLineItems = List<POLineItem>.from(purchaseOrder.lineItems);
      updatedLineItems[lineItemIndex] = updatedLineItem;

      // Update the purchase order document
      final poDocRef = _firestore.collection('purchaseOrder').doc(purchaseOrder.id);
      batch.update(poDocRef, {
        'lineItems': updatedLineItems.map((item) => item.toFirestore()).toList(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      print('✅ Updated POLineItem quantityPlaced: ${currentPlaced} + ${quantityPlaced} = ${newQuantityPlaced}');

    } catch (e) {
      print('❌ Error updating POLineItem quantityPlaced: $e');
      throw Exception('Failed to update POLineItem quantityPlaced: $e');
    }
  }

  Map<String, dynamic> _buildConsolidationReasoning(
      WarehouseLocation existingLocation,
      int additionalQuantity
      ) {
    return {
      'targetZone': existingLocation.zoneId,
      'zoneName': WarehouseConfig.zones[existingLocation.zoneId]?.name ?? 'Unknown Zone',
      'reasoning': {
        'primary': 'Consolidating with existing stock at ${existingLocation.locationId}',
        'efficiency': 'Reduces picking locations and improves inventory management',
        'consistency': 'Keeps same product from same PO in one location',
        'currentStock': '${existingLocation.quantityStored} units already stored',
        'addingStock': '$additionalQuantity additional units',
      },
      'consolidationType': 'PARTIAL_DELIVERY_CONSOLIDATION',
    };
  }

  /// Update ProductItem status from 'received' to 'stored'
  Future<void> _updateProductItemsStatus(
      String purchaseOrderId,
      String productId,
      int quantityToStore,
      WriteBatch batch,
      String locationId,
      ) async {
    try {
      print('Updating ProductItem status for PO: $purchaseOrderId, Product: $productId');

      // Query ProductItems with status 'received' for this PO and product
      final snapshot = await _firestore
          .collection('productItems')
          .where('purchaseOrderId', isEqualTo: purchaseOrderId)
          .where('productId', isEqualTo: productId)
          .where('status', isEqualTo: ProductItemStatus.received)
          .limit(quantityToStore) // Only update the quantity being stored
          .get();

      print('Found ${snapshot.docs.length} ProductItems with status "received"');

      if (snapshot.docs.isEmpty) {
        print('No ProductItems with "received" status found for this PO and product');
        return;
      }

      // Update status from 'received' to 'stored' for the required quantity
      int updatedCount = 0;
      for (final doc in snapshot.docs) {
        if (updatedCount >= quantityToStore) break;

        batch.update(doc.reference, {
          'status': ProductItemStatus.stored,
          'location': locationId,
        });

        updatedCount++;
        print('Updated ProductItem ${doc.id} status to "stored"');
      }

      print('Updated $updatedCount ProductItems from "received" to "stored"');

    } catch (e) {
      print('Error updating ProductItem status: $e');
      throw Exception('Failed to update ProductItem status: $e');
    }
  }

  // ==================== QUERY METHODS ====================

  /// Get all warehouse locations
  Future<List<WarehouseLocation>> getAllWarehouseLocations() async {
    try {
      final snapshot = await _warehouseCollection
          .orderBy('locationId')
          .get();

      return snapshot.docs
          .map((doc) => WarehouseLocation.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get warehouse locations: $e');
    }
  }

  /// Get occupied locations
  Future<List<WarehouseLocation>> getOccupiedLocations() async {
    try {
      final snapshot = await _warehouseCollection
          .where('isOccupied', isEqualTo: true)
          .orderBy('occupiedDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => WarehouseLocation.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get occupied locations: $e');
    }
  }

  /// Get available locations in zone
  Future<List<WarehouseLocation>> getAvailableLocationsInZone(String zoneId) async {
    try {
      final snapshot = await _warehouseCollection
          .where('zoneId', isEqualTo: zoneId)
          .where('isOccupied', isEqualTo: false)
          .orderBy('locationId')
          .get();

      return snapshot.docs
          .map((doc) => WarehouseLocation.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get available locations: $e');
    }
  }

  /// Get warehouse statistics
  Future<Map<String, dynamic>> getWarehouseStatistics() async {
    try {
      final allLocations = await getAllWarehouseLocations();
      final occupiedLocations = allLocations.where((loc) => loc.isOccupied).toList();

      final stats = <String, dynamic>{};

      // Overall statistics
      stats['totalLocations'] = allLocations.length;
      stats['occupiedLocations'] = occupiedLocations.length;
      stats['availableLocations'] = allLocations.length - occupiedLocations.length;
      stats['occupancyRate'] = (occupiedLocations.length / allLocations.length * 100).round();

      // Zone-wise statistics
      final zoneStats = <String, Map<String, int>>{};

      for (String zoneId in WarehouseConfig.zones.keys) {
        final zoneLocations = allLocations.where((loc) => loc.zoneId == zoneId).toList();
        final zoneOccupied = zoneLocations.where((loc) => loc.isOccupied).toList();

        zoneStats[zoneId] = {
          'total': zoneLocations.length,
          'occupied': zoneOccupied.length,
          'available': zoneLocations.length - zoneOccupied.length,
          'occupancyRate': zoneLocations.isEmpty ? 0 :
          (zoneOccupied.length / zoneLocations.length * 100).round(),
        };
      }

      stats['zoneStatistics'] = zoneStats;

      return stats;
    } catch (e) {
      throw Exception('Failed to get warehouse statistics: $e');
    }
  }

  /// Search locations by product or PO
  Future<List<WarehouseLocation>> searchLocations(String searchTerm) async {
    try {
      final searchTermLower = searchTerm.toLowerCase();

      // Get all occupied locations and filter locally
      final occupiedLocations = await getOccupiedLocations();

      return occupiedLocations.where((location) {
        return (location.productName?.toLowerCase().contains(searchTermLower) ?? false) ||
            (location.purchaseOrderId?.toLowerCase().contains(searchTermLower) ?? false) ||
            (location.locationId.toLowerCase().contains(searchTermLower)) ||
            (location.metadata?['poNumber']?.toString().toLowerCase().contains(searchTermLower) ?? false);
      }).toList();

    } catch (e) {
      throw Exception('Failed to search locations: $e');
    }
  }

  /// Release location (mark as available)
  Future<void> releaseLocation(String locationId) async {
    try {
      await _warehouseCollection.doc(locationId).update({
        'isOccupied': false,
        'purchaseOrderId': null,
        'productId': null,
        'productName': null,
        'quantityStored': null,
        'occupiedDate': null,
        'metadata': null,
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });

      print('✅ Location $locationId released successfully');
    } catch (e) {
      throw Exception('Failed to release location: $e');
    }
  }
}