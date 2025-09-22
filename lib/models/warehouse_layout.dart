import 'package:flutter/material.dart';
import 'dart:math' as math;

class WarehouseLayout {
  final String id;
  final String name;
  final double width;
  final double height;
  final List<WarehouseBay> bays;
  final List<WarehouseAisle> aisles;
  final List<WarehouseZone> zones;
  final WarehouseEntrance entrance;

  WarehouseLayout({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.bays,
    required this.aisles,
    required this.zones,
    required this.entrance,
  });

  WarehouseBay? findBayById(String bayId) {
    return bays.firstWhere((bay) => bay.id == bayId, orElse: () => throw Exception('Bay not found'));
  }

  List<WarehouseBay> getBaysByZone(String zoneId) {
    return bays.where((bay) => bay.zoneId == zoneId).toList();
  }
}

class WarehouseBay {
  final String id; // e.g., "A1", "B2", "C3"
  final String zoneId;
  final Offset position;
  final double width;
  final double height;
  final List<WarehouseShelf> shelves;
  final BayOrientation orientation;

  WarehouseBay({
    required this.id,
    required this.zoneId,
    required this.position,
    required this.width,
    required this.height,
    required this.shelves,
    required this.orientation,
  });

  WarehouseShelf? findShelfById(String shelfId) {
    try {
      return shelves.firstWhere((shelf) => shelf.id == shelfId);
    } catch (e) {
      return null;
    }
  }

  Rect get bounds => Rect.fromLTWH(position.dx, position.dy, width, height);
}

class WarehouseShelf {
  final String id; // e.g., "S01", "S02", "S03"
  final String bayId;
  final Offset relativePosition; // Position relative to bay
  final double width;
  final double height;
  final List<ShelfRow> rows;
  final ShelfType type;

  WarehouseShelf({
    required this.id,
    required this.bayId,
    required this.relativePosition,
    required this.width,
    required this.height,
    required this.rows,
    required this.type,
  });

  ShelfRow? findRowByNumber(int rowNumber) {
    try {
      return rows.firstWhere((row) => row.number == rowNumber);
    } catch (e) {
      return null;
    }
  }
}

class ShelfRow {
  final int number; // 1, 2, 3, 4, 5 (from bottom to top)
  final String label; // "Row 1", "Row 2", etc.
  final double heightFromFloor; // in meters
  final int maxCapacity;
  final RowAccessibility accessibility;

  ShelfRow({
    required this.number,
    required this.label,
    required this.heightFromFloor,
    required this.maxCapacity,
    required this.accessibility,
  });
}

class WarehouseAisle {
  final String id;
  final String name;
  final List<Offset> path; // Aisle centerline
  final double width;
  final AisleType type;
  final bool isTwoWay;

  WarehouseAisle({
    required this.id,
    required this.name,
    required this.path,
    required this.width,
    required this.type,
    required this.isTwoWay,
  });
}

class WarehouseZone {
  final String id;
  final String name;
  final Color color;
  final List<Offset> boundary;
  final ZoneType type;
  final String description;

  WarehouseZone({
    required this.id,
    required this.name,
    required this.color,
    required this.boundary,
    required this.type,
    required this.description,
  });
}

class WarehouseEntrance {
  final Offset position;
  final String name;
  final double width;
  final EntranceType type;

  WarehouseEntrance({
    required this.position,
    required this.name,
    required this.width,
    required this.type,
  });
}

// Navigation and pathfinding
class WarehouseNavigation {
  final WarehouseLayout layout;

  WarehouseNavigation(this.layout);

  List<Offset> findPath(Offset from, String toBayId, String toShelfId) {
    final bay = layout.findBayById(toBayId);
    final shelf = bay?.findShelfById(toShelfId);

    if (bay == null || shelf == null) {
      return [];
    }

    // Calculate destination position
    final destination = Offset(
      bay.position.dx + shelf.relativePosition.dx + shelf.width / 2,
      bay.position.dy + shelf.relativePosition.dy + shelf.height / 2,
    );

    // Simple pathfinding - in real implementation, use A* algorithm
    return _calculateOptimalPath(from, destination);
  }

  List<Offset> _calculateOptimalPath(Offset from, Offset to) {
    // Simplified pathfinding - connects through main aisles
    final List<Offset> path = [];

    // Find nearest aisle intersection to start point
    final startAislePoint = _findNearestAislePoint(from);

    // Find nearest aisle intersection to end point
    final endAislePoint = _findNearestAislePoint(to);

    path.add(from);
    if (startAislePoint != null) path.add(startAislePoint);

    // Navigate through main aisles
    path.addAll(_navigateThroughAisles(startAislePoint ?? from, endAislePoint ?? to));

    if (endAislePoint != null && endAislePoint != path.last) path.add(endAislePoint);
    path.add(to);

    return path;
  }

  Offset? _findNearestAislePoint(Offset position) {
    double minDistance = double.infinity;
    Offset? nearest;

    for (final aisle in layout.aisles) {
      for (final point in aisle.path) {
        final distance = (point - position).distance;
        if (distance < minDistance) {
          minDistance = distance;
          nearest = point;
        }
      }
    }

    return nearest;
  }

  List<Offset> _navigateThroughAisles(Offset from, Offset to) {
    // Simple aisle navigation - in practice, use graph algorithms
    return [from, to];
  }

  double estimateWalkingTime(List<Offset> path) {
    if (path.length < 2) return 0;

    double totalDistance = 0;
    for (int i = 0; i < path.length - 1; i++) {
      totalDistance += (path[i + 1] - path[i]).distance;
    }

    // Assume average walking speed of 1.2 m/s in warehouse
    // Convert from pixels to meters (approximate scale)
    final metersDistance = totalDistance * 0.1; // Adjust scale factor as needed
    return metersDistance / 1.2; // time in seconds
  }
}

// Enums
enum BayOrientation { north, south, east, west }
enum ShelfType { standard, heavyDuty, refrigerated, hazmat, picker }
enum RowAccessibility { ground, forklift, picker, manual }
enum AisleType { main, cross, picking, loading }
enum ZoneType { receiving, storage, picking, shipping, returns, quarantine }
enum EntranceType { main, emergency, loading, personnel }

// Default warehouse layout factory
class WarehouseLayoutFactory {
  static WarehouseLayout createStandardLayout() {
    final List<WarehouseBay> bays = [];
    final List<WarehouseAisle> aisles = [];
    final List<WarehouseZone> zones = [];

    // Create zones
    zones.addAll([
      WarehouseZone(
        id: 'engine_zone',
        name: 'Engine Components',
        color: Colors.red.withOpacity(0.2),
        boundary: [
          const Offset(50, 50),
          const Offset(250, 50),
          const Offset(250, 200),
          const Offset(50, 200),
        ],
        type: ZoneType.storage,
        description: 'Heavy engine parts and components',
      ),
      WarehouseZone(
        id: 'brake_zone',
        name: 'Brake Systems',
        color: Colors.orange.withOpacity(0.2),
        boundary: [
          const Offset(270, 50),
          const Offset(470, 50),
          const Offset(470, 200),
          const Offset(270, 200),
        ],
        type: ZoneType.storage,
        description: 'Brake pads, discs, and components',
      ),
      WarehouseZone(
        id: 'electrical_zone',
        name: 'Electrical',
        color: Colors.yellow.withOpacity(0.2),
        boundary: [
          const Offset(50, 220),
          const Offset(250, 220),
          const Offset(250, 370),
          const Offset(50, 370),
        ],
        type: ZoneType.storage,
        description: 'Electrical components and wiring',
      ),
      WarehouseZone(
        id: 'body_zone',
        name: 'Body Parts',
        color: Colors.green.withOpacity(0.2),
        boundary: [
          const Offset(270, 220),
          const Offset(470, 220),
          const Offset(470, 370),
          const Offset(270, 370),
        ],
        type: ZoneType.storage,
        description: 'Body panels and exterior components',
      ),
    ]);

    // Create bays with realistic naming
    final bayConfigs = [
      // Engine Zone - A row
      {'id': 'A1', 'zone': 'engine_zone', 'pos': Offset(60, 70), 'shelves': 4},
      {'id': 'A2', 'zone': 'engine_zone', 'pos': Offset(120, 70), 'shelves': 4},
      {'id': 'A3', 'zone': 'engine_zone', 'pos': Offset(180, 70), 'shelves': 4},
      {'id': 'A4', 'zone': 'engine_zone', 'pos': Offset(60, 130), 'shelves': 4},
      {'id': 'A5', 'zone': 'engine_zone', 'pos': Offset(120, 130), 'shelves': 4},
      {'id': 'A6', 'zone': 'engine_zone', 'pos': Offset(180, 130), 'shelves': 4},

      // Brake Zone - B row
      {'id': 'B1', 'zone': 'brake_zone', 'pos': Offset(280, 70), 'shelves': 4},
      {'id': 'B2', 'zone': 'brake_zone', 'pos': Offset(340, 70), 'shelves': 4},
      {'id': 'B3', 'zone': 'brake_zone', 'pos': Offset(400, 70), 'shelves': 4},
      {'id': 'B4', 'zone': 'brake_zone', 'pos': Offset(280, 130), 'shelves': 4},
      {'id': 'B5', 'zone': 'brake_zone', 'pos': Offset(340, 130), 'shelves': 4},
      {'id': 'B6', 'zone': 'brake_zone', 'pos': Offset(400, 130), 'shelves': 4},

      // Electrical Zone - C row
      {'id': 'C1', 'zone': 'electrical_zone', 'pos': Offset(60, 240), 'shelves': 4},
      {'id': 'C2', 'zone': 'electrical_zone', 'pos': Offset(120, 240), 'shelves': 4},
      {'id': 'C3', 'zone': 'electrical_zone', 'pos': Offset(180, 240), 'shelves': 4},
      {'id': 'C4', 'zone': 'electrical_zone', 'pos': Offset(60, 300), 'shelves': 4},
      {'id': 'C5', 'zone': 'electrical_zone', 'pos': Offset(120, 300), 'shelves': 4},
      {'id': 'C6', 'zone': 'electrical_zone', 'pos': Offset(180, 300), 'shelves': 4},

      // Body Zone - D row
      {'id': 'D1', 'zone': 'body_zone', 'pos': Offset(280, 240), 'shelves': 4},
      {'id': 'D2', 'zone': 'body_zone', 'pos': Offset(340, 240), 'shelves': 4},
      {'id': 'D3', 'zone': 'body_zone', 'pos': Offset(400, 240), 'shelves': 4},
      {'id': 'D4', 'zone': 'body_zone', 'pos': Offset(280, 300), 'shelves': 4},
      {'id': 'D5', 'zone': 'body_zone', 'pos': Offset(340, 300), 'shelves': 4},
      {'id': 'D6', 'zone': 'body_zone', 'pos': Offset(400, 300), 'shelves': 4},
    ];

    for (final config in bayConfigs) {
      final shelves = _createShelvesForBay(
        config['id'] as String,
        config['shelves'] as int,
      );

      bays.add(WarehouseBay(
        id: config['id'] as String,
        zoneId: config['zone'] as String,
        position: config['pos'] as Offset,
        width: 50,
        height: 40,
        shelves: shelves,
        orientation: BayOrientation.north,
      ));
    }

    // Create main aisles
    aisles.addAll([
      WarehouseAisle(
        id: 'main_aisle_1',
        name: 'Main Aisle 1',
        path: [
          const Offset(260, 50),
          const Offset(260, 370),
        ],
        width: 4.0,
        type: AisleType.main,
        isTwoWay: true,
      ),
      WarehouseAisle(
        id: 'main_aisle_2',
        name: 'Main Aisle 2',
        path: [
          const Offset(50, 210),
          const Offset(470, 210),
        ],
        width: 4.0,
        type: AisleType.main,
        isTwoWay: true,
      ),
      WarehouseAisle(
        id: 'cross_aisle_1',
        name: 'Cross Aisle 1',
        path: [
          const Offset(35, 50),
          const Offset(35, 370),
        ],
        width: 2.0,
        type: AisleType.cross,
        isTwoWay: false,
      ),
      WarehouseAisle(
        id: 'cross_aisle_2',
        name: 'Cross Aisle 2',
        path: [
          const Offset(485, 50),
          const Offset(485, 370),
        ],
        width: 2.0,
        type: AisleType.cross,
        isTwoWay: false,
      ),
    ]);

    return WarehouseLayout(
      id: 'main_warehouse',
      name: 'Main Parts Warehouse',
      width: 520,
      height: 420,
      bays: bays,
      aisles: aisles,
      zones: zones,
      entrance: WarehouseEntrance(
        position: const Offset(260, 20),
        name: 'Main Entrance',
        width: 8.0,
        type: EntranceType.main,
      ),
    );
  }

  static List<WarehouseShelf> _createShelvesForBay(String bayId, int shelfCount) {
    final shelves = <WarehouseShelf>[];

    for (int i = 1; i <= shelfCount; i++) {
      final shelfId = 'S${i.toString().padLeft(2, '0')}';

      // Create rows for each shelf (typically 5 rows: ground level + 4 elevated)
      final rows = <ShelfRow>[
        ShelfRow(
          number: 1,
          label: 'Ground Level',
          heightFromFloor: 0.0,
          maxCapacity: 20,
          accessibility: RowAccessibility.ground,
        ),
        ShelfRow(
          number: 2,
          label: 'Row 2',
          heightFromFloor: 1.5,
          maxCapacity: 15,
          accessibility: RowAccessibility.manual,
        ),
        ShelfRow(
          number: 3,
          label: 'Row 3',
          heightFromFloor: 2.5,
          maxCapacity: 15,
          accessibility: RowAccessibility.forklift,
        ),
        ShelfRow(
          number: 4,
          label: 'Row 4',
          heightFromFloor: 3.5,
          maxCapacity: 10,
          accessibility: RowAccessibility.forklift,
        ),
        ShelfRow(
          number: 5,
          label: 'Row 5',
          heightFromFloor: 4.5,
          maxCapacity: 10,
          accessibility: RowAccessibility.picker,
        ),
      ];

      shelves.add(WarehouseShelf(
        id: shelfId,
        bayId: bayId,
        relativePosition: Offset((i - 1) * 12.0, 5),
        width: 10,
        height: 30,
        rows: rows,
        type: ShelfType.standard,
      ));
    }

    return shelves;
  }
}