// models/warehouse_location.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class WarehouseLocation {
  final String locationId; // e.g., "Z1-R3-A-2"
  final String zoneId; // e.g., "Z1"
  final String rackId; // e.g., "R3"
  final String rowId; // e.g., "A"
  final int level; // e.g., 2
  final bool isOccupied;
  final String? purchaseOrderId;
  final String? productId;
  final String? productName;
  final int? quantityStored;
  final DateTime? occupiedDate;
  final DateTime? lastUpdated;
  final Map<String, dynamic>? metadata; // Additional storage info

  WarehouseLocation({
    required this.locationId,
    required this.zoneId,
    required this.rackId,
    required this.rowId,
    required this.level,
    this.isOccupied = false,
    this.purchaseOrderId,
    this.productId,
    this.productName,
    this.quantityStored,
    this.occupiedDate,
    this.lastUpdated,
    this.metadata,
  });

  // Create from Firestore
  factory WarehouseLocation.fromFirestore(Map<String, dynamic> data) {
    return WarehouseLocation(
      locationId: data['locationId'] ?? '',
      zoneId: data['zoneId'] ?? '',
      rackId: data['rackId'] ?? '',
      rowId: data['rowId'] ?? '',
      level: data['level'] ?? 1,
      isOccupied: data['isOccupied'] ?? false,
      purchaseOrderId: data['purchaseOrderId'],
      productId: data['productId'],
      productName: data['productName'],
      quantityStored: data['quantityStored'],
      occupiedDate: data['occupiedDate'] != null
          ? (data['occupiedDate'] as Timestamp).toDate()
          : null,
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] as Timestamp).toDate()
          : null,
      metadata: data['metadata'],
    );
  }

  // Convert to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'locationId': locationId,
      'zoneId': zoneId,
      'rackId': rackId,
      'rowId': rowId,
      'level': level,
      'isOccupied': isOccupied,
      'purchaseOrderId': purchaseOrderId,
      'productId': productId,
      'productName': productName,
      'quantityStored': quantityStored,
      'occupiedDate': occupiedDate != null
          ? Timestamp.fromDate(occupiedDate!)
          : null,
      'lastUpdated': Timestamp.fromDate(DateTime.now()),
      'metadata': metadata,
    };
  }

  // Copy with method
  WarehouseLocation copyWith({
    String? locationId,
    String? zoneId,
    String? rackId,
    String? rowId,
    int? level,
    bool? isOccupied,
    String? purchaseOrderId,
    String? productId,
    String? productName,
    int? quantityStored,
    DateTime? occupiedDate,
    DateTime? lastUpdated,
    Map<String, dynamic>? metadata,
  }) {
    return WarehouseLocation(
      locationId: locationId ?? this.locationId,
      zoneId: zoneId ?? this.zoneId,
      rackId: rackId ?? this.rackId,
      rowId: rowId ?? this.rowId,
      level: level ?? this.level,
      isOccupied: isOccupied ?? this.isOccupied,
      purchaseOrderId: purchaseOrderId ?? this.purchaseOrderId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantityStored: quantityStored ?? this.quantityStored,
      occupiedDate: occupiedDate ?? this.occupiedDate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      metadata: metadata ?? this.metadata,
    );
  }
}


class StorageAllocationResult {
  final bool success;
  final String? targetZone;
  final List<WarehouseLocation> availableLocations;
  final String? errorMessage;
  final Map<String, dynamic>? allocationReasoning;
  final List<LocationAllocationPlan>? allocationPlan;

  StorageAllocationResult({
    required this.success,
    this.targetZone,
    this.availableLocations = const [],
    this.errorMessage,
    this.allocationReasoning,
    this.allocationPlan,
  });
}


class LocationAllocationPlan {
  final WarehouseLocation location;
  final int quantityToPlace;
  final bool isConsolidation;
  final ConsolidationInfo? consolidationInfo;

  LocationAllocationPlan({
    required this.location,
    required this.quantityToPlace,
    required this.isConsolidation,
    this.consolidationInfo,
  });
}


class ConsolidationInfo {
  final String existingPO;
  final int existingQuantity;
  final int newQuantity;
  final int totalAfter;

  ConsolidationInfo({
    required this.existingPO,
    required this.existingQuantity,
    required this.newQuantity,
    required this.totalAfter,
  });
}

class WarehouseLocationWithCapacity {
  final WarehouseLocation location;
  final int maxCapacity;
  final int currentQuantity;
  final int availableCapacity;

  WarehouseLocationWithCapacity({
    required this.location,
    required this.maxCapacity,
    required this.currentQuantity,
    required this.availableCapacity,
  });
}

// Zone configuration
class ZoneConfig {
  final String zoneId;
  final String name;
  final String description;
  final int totalRacks;
  final int rowsPerRack;
  final int levelsPerRow;
  final List<String> supportedStorageTypes;
  final bool supportsClimateControl;
  final bool supportsHazardousMaterials;

  ZoneConfig({
    required this.zoneId,
    required this.name,
    required this.description,
    required this.totalRacks,
    required this.rowsPerRack,
    required this.levelsPerRow,
    required this.supportedStorageTypes,
    this.supportsClimateControl = false,
    this.supportsHazardousMaterials = false,
  });

  int get totalLocations => totalRacks * rowsPerRack * levelsPerRow;
}

// Warehouse configuration
class WarehouseConfig {
  static final Map<String, ZoneConfig> zones = {
    'Z1': ZoneConfig(
      zoneId: 'Z1',
      name: 'Fast-Moving Zone',
      description: 'Brake pads, spark plugs, fuses, filters',
      totalRacks: 5,
      rowsPerRack: 2,
      levelsPerRow: 5,
      supportedStorageTypes: ['shelf', 'rack'],
    ),
    'Z2': ZoneConfig(
      zoneId: 'Z2',
      name: 'Medium-Moving Zone',
      description: 'Alternators, brake discs, small ECUs',
      totalRacks: 10,
      rowsPerRack: 2,
      levelsPerRow: 4,
      supportedStorageTypes: ['shelf', 'rack'],
    ),
    'Z3': ZoneConfig(
      zoneId: 'Z3',
      name: 'Slow-Moving Zone',
      description: 'Engines, body panels, rare parts',
      totalRacks: 8,
      rowsPerRack: 2,
      levelsPerRow: 3,
      supportedStorageTypes: ['floor', 'shelf', 'rack'],
    ),
    'Z4': ZoneConfig(
      zoneId: 'Z4',
      name: 'Bulk Storage Area',
      description: 'Oils, coolants, nuts & bolts',
      totalRacks: 3,
      rowsPerRack: 2,
      levelsPerRow: 2,
      supportedStorageTypes: ['bulk', 'floor'],
    ),
    'Z5': ZoneConfig(
      zoneId: 'Z5',
      name: 'Climate-Controlled Area',
      description: 'ECUs, sensors, rubber gaskets',
      totalRacks: 4,
      rowsPerRack: 2,
      levelsPerRow: 4,
      supportedStorageTypes: ['shelf', 'rack', 'special'],
      supportsClimateControl: true,
    ),
    'Z6': ZoneConfig(
      zoneId: 'Z6',
      name: 'Hazardous Material Area',
      description: 'Batteries, airbags, brake fluid, paints',
      totalRacks: 2,
      rowsPerRack: 2,
      levelsPerRow: 3,
      supportedStorageTypes: ['special', 'floor', 'shelf'],
      supportsHazardousMaterials: true,
    ),
  };

  static List<String> getAllLocationIds() {
    List<String> locations = [];

    zones.forEach((zoneId, config) {
      for (int rack = 1; rack <= config.totalRacks; rack++) {
        for (String row in ['A', 'B']) {
          for (int level = 1; level <= config.levelsPerRow; level++) {
            locations.add('$zoneId-R$rack-$row-$level');
          }
        }
      }
    });

    return locations;
  }
}