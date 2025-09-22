import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:assignment/services/warehouse/warehouse_allocation_service.dart';
import 'package:assignment/models/warehouse_location.dart';
import 'package:assignment/models/product_item.dart';
import 'package:assignment/models/products_model.dart';

class WarehouseMovementService {
  final WarehouseAllocationService _allocationService =
  WarehouseAllocationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Enhanced move item method that integrates allocation services
  Future<MovementResult> moveItem({
    required String productItemId,
    required String currentLocationId,
    required String targetLocationId,
    required Product product,
    required String performedBy,
    String? notes,
    String reason = 'Item relocation',
  }) async {
    try {
      print('🚚 Starting enhanced item movement: $productItemId');
      print('   From: $currentLocationId → To: $targetLocationId');

      // Step 1: Validate the movement
      final validation = await _validateMovement(
        productItemId,
        currentLocationId,
        targetLocationId,
        product,
      );

      if (!validation.isValid) {
        return MovementResult(
          success: false,
          message: validation.errorMessage ?? 'Movement validation failed',
        );
      }

      // Step 2: Check if target location is suitable for the product
      final suitabilityCheck = await _checkLocationSuitability(
        targetLocationId,
        product,
      );

      if (!suitabilityCheck.isSuitable) {
        return MovementResult(
          success: false,
          message: suitabilityCheck.reason ??
              'Target location not suitable for this product',
        );
      }

      // Step 3: Execute the movement using transaction for consistency
      final result = await _firestore.runTransaction((transaction) async {
        return await _executeMovementTransaction(
          transaction,
          productItemId,
          currentLocationId,
          targetLocationId,
          product,
          performedBy,
          notes,
          reason,
        );
      });

      if (result.success) {
        print('✅ Enhanced item movement completed successfully');
      }

      return result;
    } catch (e) {
      print('❌ Error in enhanced item movement: $e');
      return MovementResult(
        success: false,
        message: 'Movement failed: $e',
      );
    }
  }

  /// Get suitable locations for moving an item, filtered by product requirements
  Future<List<WarehouseLocationOption>> getSuitableLocationsForProduct(
      Product product,
      {String? excludeLocationId}) async {
    try {
      print('🔍 Finding suitable locations for product: ${product.name}');

      // Step 1: Determine optimal zone for this product
      final targetZone = _determineTargetZone(product);
      print('   Target zone: $targetZone');

      // Step 2: Get available locations in target zone
      final availableLocations =
      await _allocationService.getAvailableLocationsInZone(targetZone);
      print(
          '   Found ${availableLocations.length} available locations in $targetZone');

      // Step 3: Filter locations based on product requirements
      final suitableLocations = <WarehouseLocationOption>[];

      for (final location in availableLocations) {
        if (excludeLocationId != null &&
            location.locationId == excludeLocationId) {
          continue; // Skip current location
        }

        final suitability =
        await _checkLocationSuitability(location.locationId, product);
        if (suitability.isSuitable) {
          suitableLocations.add(WarehouseLocationOption(
            location: location,
            suitabilityScore: suitability.score,
            reason: suitability.reason ?? 'Compatible location',
          ));
        }
      }

      // Step 4: Check for consolidation opportunities (same product, different POs)
      final consolidationOpportunities =
      await _findConsolidationOpportunities(product.id!);
      for (final opportunity in consolidationOpportunities) {
        if (excludeLocationId != null &&
            opportunity.location.locationId == excludeLocationId) {
          continue;
        }

        suitableLocations.add(WarehouseLocationOption(
          location: opportunity.location,
          suitabilityScore: opportunity.availableCapacity > 0 ? 90 : 60,
          reason:
          'Consolidation opportunity - ${opportunity.availableCapacity} units capacity available',
          isConsolidation: true,
          availableCapacity: opportunity.availableCapacity,
        ));
      }

      // Step 5: Sort by suitability score (highest first)
      suitableLocations
          .sort((a, b) => b.suitabilityScore.compareTo(a.suitabilityScore));

      print('   Final suitable locations: ${suitableLocations.length}');
      return suitableLocations;
    } catch (e) {
      print('❌ Error finding suitable locations: $e');
      return [];
    }
  }

  /// Execute movement within a transaction for data consistency
  /// FIXED: All reads first, then all writes (Firebase requirement)
  Future<MovementResult> _executeMovementTransaction(
      Transaction transaction,
      String productItemId,
      String currentLocationId,
      String targetLocationId,
      Product product,
      String performedBy,
      String? notes,
      String reason,
      ) async {
    try {
      // STEP 1: ALL READS FIRST (Firebase transaction requirement)
      print('   📖 Reading all documents first...');

      final sourceLocationRef =
      _firestore.collection('warehouseLocations').doc(currentLocationId);
      final targetLocationRef =
      _firestore.collection('warehouseLocations').doc(targetLocationId);
      final itemRef = _firestore.collection('productItems').doc(productItemId);

      // Read all documents we need to modify
      final sourceLocationDoc = await transaction.get(sourceLocationRef);
      final targetLocationDoc = await transaction.get(targetLocationRef);

      // Validate all reads completed successfully
      if (!sourceLocationDoc.exists) {
        throw Exception('Source location not found: $currentLocationId');
      }
      if (!targetLocationDoc.exists) {
        throw Exception('Target location not found: $targetLocationId');
      }

      // Parse location data using the WarehouseLocation model
      final sourceLocation =
      WarehouseLocation.fromFirestore(sourceLocationDoc.data()!);
      final targetLocation =
      WarehouseLocation.fromFirestore(targetLocationDoc.data()!);

      // Validate source location has sufficient quantity
      final currentQuantity = sourceLocation.quantityStored ?? 0;
      if (currentQuantity < 1) {
        throw Exception(
            'Insufficient quantity at source location: $currentQuantity < 1');
      }

      // STEP 2: ALL WRITES SECOND (after all reads are complete)
      print('   ✍️ Executing all writes...');

      // Update source location using copyWith method
      final newSourceQuantity = currentQuantity - 1;
      final updatedSourceLocation = sourceLocation.copyWith(
        quantityStored: newSourceQuantity,
        isOccupied: newSourceQuantity > 0,
        // Clear product info if location becomes empty
        purchaseOrderId:
        newSourceQuantity == 0 ? null : sourceLocation.purchaseOrderId,
        productId: newSourceQuantity == 0 ? null : sourceLocation.productId,
        productName: newSourceQuantity == 0 ? null : sourceLocation.productName,
        metadata: newSourceQuantity == 0 ? null : sourceLocation.metadata,
      );

      // Use toFirestore() method but add FieldValue.delete() for null fields
      final sourceUpdateData = updatedSourceLocation.toFirestore();
      if (newSourceQuantity == 0) {
        sourceUpdateData.addAll({
          'productId': FieldValue.delete(),
          'productName': FieldValue.delete(),
          'purchaseOrderId': FieldValue.delete(),
          'metadata': FieldValue.delete(),
        });
      }

      transaction.update(sourceLocationRef, sourceUpdateData);
      print(
          '   📤 Updated source location: $currentLocationId ($currentQuantity → $newSourceQuantity)');

      // Update target location
      final currentTargetQuantity = targetLocation.quantityStored ?? 0;
      final newTargetQuantity = currentTargetQuantity + 1;
      final isConsolidation =
          targetLocation.isOccupied && targetLocation.productId == product.id;

      final updatedTargetLocation = targetLocation.copyWith(
        quantityStored: newTargetQuantity,
        isOccupied: true,
        // Only update product info for new placements
        productId: isConsolidation ? targetLocation.productId : product.id!,
        productName:
        isConsolidation ? targetLocation.productName : product.name,
        occupiedDate:
        isConsolidation ? targetLocation.occupiedDate : DateTime.now(),
        metadata: isConsolidation
            ? targetLocation.metadata
            : {
          'productCategory': product.category ?? 'unknown',
          'movementReason': 'Item relocation',
          'lastUpdateDate': DateTime.now().toIso8601String(),
        },
      );

      transaction.update(
          targetLocationRef, updatedTargetLocation.toFirestore());
      print(
          '   📥 Updated target location: $targetLocationId ($currentTargetQuantity → $newTargetQuantity)');

      // Update product item record
      transaction.update(itemRef, {
        'location': targetLocationId,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      print('   📋 Updated product item: $productItemId → $targetLocationId');

      // Create movement history record
      final historyRef = _firestore.collection('productItemHistory').doc();
      transaction.set(historyRef, {
        'id': historyRef.id,
        'productItemId': productItemId,
        'action': 'moved',
        'fromLocation': currentLocationId,
        'toLocation': targetLocationId,
        'fromZone': _extractZoneFromLocation(currentLocationId),
        'toZone': _extractZoneFromLocation(targetLocationId),
        'timestamp': FieldValue.serverTimestamp(),
        'performedBy': performedBy,
        'notes': notes ?? '',
        'reason': reason,
      });
      print('   📝 Created movement history record');

      return MovementResult(
        success: true,
        message: 'Item moved successfully',
        fromLocation: currentLocationId,
        toLocation: targetLocationId,
      );
    } catch (e) {
      throw Exception('Transaction failed: $e');
    }
  }

  /// Validate movement request
  Future<ValidationResult> _validateMovement(
      String productItemId,
      String currentLocationId,
      String targetLocationId,
      Product product,
      ) async {
    // Check if locations are different
    if (currentLocationId == targetLocationId) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Source and target locations are the same',
      );
    }

    // Check if product item exists and is at current location
    final itemDoc =
    await _firestore.collection('productItems').doc(productItemId).get();
    if (!itemDoc.exists) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Product item not found',
      );
    }

    final item = ProductItem.fromFirestore(itemDoc);
    if (item.location != currentLocationId) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Product item is not at specified current location',
      );
    }

    // Check if current location has the product
    final currentLocationDoc = await _firestore
        .collection('warehouseLocations')
        .doc(currentLocationId)
        .get();
    if (!currentLocationDoc.exists) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Current location not found',
      );
    }

    final currentLocation =
    WarehouseLocation.fromFirestore(currentLocationDoc.data()!);
    if (!currentLocation.isOccupied ||
        currentLocation.productId != product.id) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Current location does not contain this product',
      );
    }

    // Check if target location exists
    final targetLocationDoc = await _firestore
        .collection('warehouseLocations')
        .doc(targetLocationId)
        .get();
    if (!targetLocationDoc.exists) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Target location not found',
      );
    }

    return ValidationResult(isValid: true);
  }

  /// Check if location is suitable for product using zone configuration
  Future<SuitabilityResult> _checkLocationSuitability(
      String locationId,
      Product product,
      ) async {
    try {
      final locationDoc = await _firestore
          .collection('warehouseLocations')
          .doc(locationId)
          .get();
      if (!locationDoc.exists) {
        return SuitabilityResult(
          isSuitable: false,
          reason: 'Location not found',
          score: 0,
        );
      }

      final location = WarehouseLocation.fromFirestore(locationDoc.data()!);
      final zoneConfig = WarehouseConfig.zones[location.zoneId];

      // Check if location is occupied by different product
      if (location.isOccupied && location.productId != product.id) {
        return SuitabilityResult(
          isSuitable: false,
          reason: 'Location occupied by different product',
          score: 0,
        );
      }

      // If same product, check capacity
      if (location.isOccupied && location.productId == product.id) {
        final currentQuantity = location.quantityStored ?? 0;
        final maxCapacity = _getMaxCapacityForLocation(location);
        if (currentQuantity >= maxCapacity) {
          return SuitabilityResult(
            isSuitable: false,
            reason: 'Location at full capacity',
            score: 0,
          );
        }

        return SuitabilityResult(
          isSuitable: true,
          reason: 'Consolidation opportunity available',
          score: 90,
        );
      }

      // Check zone compatibility using WarehouseConfig
      final targetZone = _determineTargetZone(product);
      int score = 50; // Base score

      if (location.zoneId == targetZone) {
        score += 30; // Preferred zone
      } else {
        score -= 10; // Not preferred zone
      }

      // Check storage type compatibility
      if (zoneConfig != null &&
          !zoneConfig.supportedStorageTypes.contains(product.storageType)) {
        score -= 20; // Storage type not supported
      }

      // Check special requirements
      if (product.requiresClimateControl &&
          !(zoneConfig?.supportsClimateControl ?? false)) {
        score -= 30; // Climate control required but not available
      }

      if (product.isHazardousMaterial &&
          !(zoneConfig?.supportsHazardousMaterials ?? false)) {
        score -= 30; // Hazmat handling required but not available
      }

      // Check level suitability for heavy items
      if ((product.weight ?? 0) > 50 && location.level <= 2) {
        score += 20; // Good for heavy items
      } else if ((product.weight ?? 0) > 50 && location.level > 2) {
        score -= 15; // Not ideal for heavy items
      }

      // Check accessibility
      if (location.rowId == 'A') {
        score += 10; // Front row is more accessible
      }

      return SuitabilityResult(
        isSuitable: score > 30,
        reason: score > 30
            ? 'Location suitable for product (Zone: ${zoneConfig?.name ?? "Unknown"})'
            : 'Location not ideal for product requirements',
        score: score,
      );
    } catch (e) {
      return SuitabilityResult(
        isSuitable: false,
        reason: 'Error checking location suitability: $e',
        score: 0,
      );
    }
  }

  /// Find consolidation opportunities for the same product
  Future<List<WarehouseLocationWithCapacity>> _findConsolidationOpportunities(
      String productId) async {
    try {
      final snapshot = await _firestore
          .collection('warehouseLocations')
          .where('productId', isEqualTo: productId)
          .where('isOccupied', isEqualTo: true)
          .get();

      final opportunities = <WarehouseLocationWithCapacity>[];

      for (final doc in snapshot.docs) {
        final location = WarehouseLocation.fromFirestore(doc.data());
        final maxCapacity = _getMaxCapacityForLocation(location);
        final currentQuantity = location.quantityStored ?? 0;
        final availableCapacity = maxCapacity - currentQuantity;

        if (availableCapacity > 0) {
          opportunities.add(WarehouseLocationWithCapacity(
            location: location,
            maxCapacity: maxCapacity,
            currentQuantity: currentQuantity,
            availableCapacity: availableCapacity,
          ));
        }
      }

      return opportunities;
    } catch (e) {
      print('Error finding consolidation opportunities: $e');
      return [];
    }
  }

  /// Helper methods
  String _determineTargetZone(Product product) {
    if (product.isHazardousMaterial == true) return 'Z6';
    if (product.requiresClimateControl == true) return 'Z5';
    if (product.storageType == 'bulk') return 'Z4';

    switch (product.movementFrequency) {
      case 'fast':
        return 'Z1';
      case 'medium':
        return 'Z2';
      case 'slow':
      default:
        return 'Z3';
    }
  }

  int _getMaxCapacityForLocation(WarehouseLocation location) {
    final zoneConfig = WarehouseConfig.zones[location.zoneId];

    // Base capacity varies by zone and level
    int baseCapacity = 100;

    if (zoneConfig != null) {
      switch (zoneConfig.zoneId) {
        case 'Z1': // Fast-moving zone - smaller items, higher density
          baseCapacity = 150;
          break;
        case 'Z2': // Medium-moving zone - standard capacity
          baseCapacity = 100;
          break;
        case 'Z3': // Slow-moving zone - larger items, lower density
          baseCapacity = 75;
          break;
        case 'Z4': // Bulk storage - higher capacity for bulk items
          baseCapacity = 200;
          break;
        case 'Z5': // Climate controlled - standard capacity
          baseCapacity = 100;
          break;
        case 'Z6': // Hazmat - lower capacity for safety
          baseCapacity = 50;
          break;
      }
    }

    // Adjust for level (lower levels can hold more weight)
    if (location.level > 3) {
      baseCapacity =
          (baseCapacity * 0.8).round(); // 20% reduction for high levels
    }

    return baseCapacity;
  }

  String _extractZoneFromLocation(String locationId) {
    return locationId.length >= 2 ? locationId.substring(0, 2) : 'Z1';
  }
}

// Supporting classes
class MovementResult {
  final bool success;
  final String message;
  final String? fromLocation;
  final String? toLocation;
  final List<String>? warnings;

  MovementResult({
    required this.success,
    required this.message,
    this.fromLocation,
    this.toLocation,
    this.warnings,
  });
}

class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final List<String>? warnings;

  ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.warnings,
  });
}

class SuitabilityResult {
  final bool isSuitable;
  final String? reason;
  final int score;

  SuitabilityResult({
    required this.isSuitable,
    this.reason,
    required this.score,
  });
}

class WarehouseLocationOption {
  final WarehouseLocation location;
  final int suitabilityScore;
  final String reason;
  final bool isConsolidation;
  final int? availableCapacity;

  WarehouseLocationOption({
    required this.location,
    required this.suitabilityScore,
    required this.reason,
    this.isConsolidation = false,
    this.availableCapacity,
  });
}