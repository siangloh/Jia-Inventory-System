// models/stored_product_model.dart
import 'package:assignment/models/warehouse_location.dart';

/// Model to represent aggregated stored product information
/// Combines data from multiple warehouse locations for the same product
class StoredProduct {
  final String productId;
  final String productName;
  final String partNumber;
  final String category;
  final int totalQuantityStored;
  final List<WarehouseLocation> locations;
  final double? unitPrice;
  final String? productBrand;
  final String? productDescription;
  final DateTime? firstStoredDate;
  final DateTime? lastStoredDate;
  final Set<String> purchaseOrderNumbers;
  final Set<String> supplierNames;

  StoredProduct({
    required this.productId,
    required this.productName,
    required this.partNumber,
    required this.category,
    required this.totalQuantityStored,
    required this.locations,
    this.unitPrice,
    this.productBrand,
    this.productDescription,
    this.firstStoredDate,
    this.lastStoredDate,
    required this.purchaseOrderNumbers,
    required this.supplierNames,
  });

  /// Summary of locations where this product is stored
  String get locationSummary {
    if (locations.length == 1) {
      return locations.first.locationId;
    } else {
      final zones = locations.map((l) => l.zoneId).toSet();
      return '${locations.length} locations (${zones.join(', ')})';
    }
  }

  /// Summary of suppliers for this product
  String get supplierSummary {
    if (supplierNames.length == 1) {
      return supplierNames.first;
    } else {
      return '${supplierNames.length} suppliers';
    }
  }

  /// Check if product has low stock based on threshold
  bool isLowStock(int threshold) {
    return totalQuantityStored <= threshold;
  }

  /// Check if product has critical stock based on threshold
  bool isCriticalStock(int threshold) {
    return totalQuantityStored <= threshold;
  }

  /// Get all unique zones where this product is stored
  Set<String> get zones {
    return locations.map((l) => l.zoneId).toSet();
  }

  /// Get total number of storage locations
  int get locationCount => locations.length;

  /// Get the most recent storage date
  DateTime? get lastActivity {
    final dates = locations
        .where((loc) => loc.occupiedDate != null)
        .map((loc) => loc.occupiedDate!)
        .toList();

    if (dates.isEmpty) return null;
    dates.sort();
    return dates.last;
  }

  /// Copy with method for creating modified instances
  StoredProduct copyWith({
    String? productId,
    String? productName,
    String? partNumber,
    String? category,
    int? totalQuantityStored,
    List<WarehouseLocation>? locations,
    double? unitPrice,
    String? productBrand,
    String? productDescription,
    DateTime? firstStoredDate,
    DateTime? lastStoredDate,
    Set<String>? purchaseOrderNumbers,
    Set<String>? supplierNames,
  }) {
    return StoredProduct(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      partNumber: partNumber ?? this.partNumber,
      category: category ?? this.category,
      totalQuantityStored: totalQuantityStored ?? this.totalQuantityStored,
      locations: locations ?? this.locations,
      unitPrice: unitPrice ?? this.unitPrice,
      productBrand: productBrand ?? this.productBrand,
      productDescription: productDescription ?? this.productDescription,
      firstStoredDate: firstStoredDate ?? this.firstStoredDate,
      lastStoredDate: lastStoredDate ?? this.lastStoredDate,
      purchaseOrderNumbers: purchaseOrderNumbers ?? this.purchaseOrderNumbers,
      supplierNames: supplierNames ?? this.supplierNames,
    );
  }

  @override
  String toString() {
    return 'StoredProduct{id: $productId, name: $productName, qty: $totalQuantityStored, locations: ${locations.length}}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is StoredProduct &&
              runtimeType == other.runtimeType &&
              productId == other.productId;

  @override
  int get hashCode => productId.hashCode;
}