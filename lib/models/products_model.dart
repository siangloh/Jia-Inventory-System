// Enhanced Product model with structured dimensions

import 'dart:math' as Math;

import 'package:cloud_firestore/cloud_firestore.dart';

// New Dimensions class for better structure
class ProductDimensions {
  final double length; // in meters
  final double width; // in meters
  final double height; // in meters

  const ProductDimensions({
    required this.length,
    required this.width,
    required this.height,
  });

  // Calculate volume in cubic meters
  double get volume => length * width * height;

  // Calculate volume in cubic centimeters
  double get volumeInCm3 => volume * 1000000;

  // Calculate volume in liters
  double get volumeInLiters => volume * 1000;

  // Check if item is considered large (volume > 0.5 cubic meters)
  bool get isLargeItem => volume > 0.5;

  // Check if item is oversized (any dimension > 2 meters)
  bool get isOversized => length > 2.0 || width > 2.0 || height > 2.0;

  // Get the longest dimension
  double get longestDimension =>
      [length, width, height].reduce((a, b) => a > b ? a : b);

  // Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'length': length,
      'width': width,
      'height': height,
      'volume': volume,
      'isLargeItem': isLargeItem,
      'isOversized': isOversized,
    };
  }

  // Create from Firestore map
  factory ProductDimensions.fromFirestore(Map<String, dynamic> data) {
    return ProductDimensions(
      length: (data['length'] ?? 0.0).toDouble(),
      width: (data['width'] ?? 0.0).toDouble(),
      height: (data['height'] ?? 0.0).toDouble(),
    );
  }

  // Create from individual values
  factory ProductDimensions.fromValues({
    required double length,
    required double width,
    required double height,
    String unit = 'meters',
  }) {
    return ProductDimensions(
      length: length,
      width: width,
      height: height,
    );
  }

  // Create default dimensions (for products without specific dimensions)
  factory ProductDimensions.defaultSize() {
    return const ProductDimensions(
      length: 0.1,
      width: 0.1,
      height: 0.1,
    );
  }

  // Copy with modifications
  ProductDimensions copyWith({
    double? length,
    double? width,
    double? height,
    String? unit,
  }) {
    return ProductDimensions(
      length: length ?? this.length,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  @override
  String toString() {
    return '${length.toStringAsFixed(2)} × ${width.toStringAsFixed(2)} × ${height.toStringAsFixed(2)})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductDimensions &&
        other.length == length &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode {
    return length.hashCode ^ width.hashCode ^ height.hashCode;
  }
}

// Enhanced Product class with structured dimensions
class Product {
  final String id;
  final String name; // productNameId
  final String sku;
  final String brand; // productBrandId
  final double? price;
  final String category; // categoryId
  final String description;
  final String? partNumber;
  final bool isActive;
  final int stockQuantity;
  final double? weight;
  final String unit;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProductDimensions dimensions; // Now structured!
  final String movementFrequency;
  final bool requiresClimateControl;
  final bool isHazardousMaterial;
  final String storageType;
  final Map<String, dynamic> metadata; // For additional flexible data

  Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.brand,
    this.price,
    required this.category,
    required this.description,
    this.partNumber,
    this.isActive = true,
    this.stockQuantity = 0,
    this.weight,
    required this.unit,
    required this.createdAt,
    required this.updatedAt,
    ProductDimensions? dimensions,
    this.movementFrequency = 'slow',
    this.requiresClimateControl = false,
    this.isHazardousMaterial = false,
    this.storageType = 'standard',
    this.metadata = const {},
  }) : dimensions = dimensions ?? ProductDimensions.defaultSize();

  // Convenience getters for warehouse calculations
  double get volume => dimensions.volume;

  bool get isLargeItem => dimensions.isLargeItem;

  bool get isOversized => dimensions.isOversized;

  // Create Product from Firestore document
  factory Product.fromFirestore(String docId, Map<String, dynamic> data) {
    // Handle legacy dimensions data
    ProductDimensions productDimensions;
    if (data['dimensions'] != null) {
      final dimensionsData = data['dimensions'] as Map<String, dynamic>;

      // Check if it's the new structured format
      if (dimensionsData.containsKey('length') &&
          dimensionsData.containsKey('width') &&
          dimensionsData.containsKey('height')) {
        productDimensions = ProductDimensions.fromFirestore(dimensionsData);
      } else {
        // Handle legacy format or convert from other formats
        productDimensions = _convertLegacyDimensions(dimensionsData);
      }
    } else {
      productDimensions = ProductDimensions.defaultSize();
    }

    return Product(
      id: docId,
      name: data['name'] ?? data['productNameId'] ?? '',
      sku: data['sku'] ?? '',
      brand: data['brand'] ?? data['productBrandId'] ?? '',
      price: (data['price'] ?? data['unitPrice'])?.toDouble(),
      category: data['category'] ?? data['categoryId'] ?? '',
      description: data['description'] ?? '',
      partNumber: data['partNumber'],
      isActive: data['isActive'] ?? true,
      stockQuantity: data['stockQuantity'] ?? 0,
      weight: data['weight']?.toDouble(),
      unit: data['unit'] ?? 'PCS',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dimensions: productDimensions,
      movementFrequency: data['movementFrequency'] ?? 'slow',
      requiresClimateControl: data['requiresClimateControl'] ?? false,
      isHazardousMaterial: data['isHazardousMaterial'] ?? false,
      storageType: data['storageType'] ?? 'standard',
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  // Helper method to convert legacy dimensions format
  static ProductDimensions _convertLegacyDimensions(
      Map<String, dynamic> legacyData) {
    // Try to extract dimensions from various possible formats
    double length = 0.1, width = 0.1, height = 0.1;

    // Format 1: Direct values
    if (legacyData['length'] != null) {
      length = (legacyData['length']).toDouble();
    }
    if (legacyData['width'] != null) {
      width = (legacyData['width']).toDouble();
    }
    if (legacyData['height'] != null) {
      height = (legacyData['height']).toDouble();
    }

    // Format 2: Size string parsing (e.g., "10x20x30")
    if (legacyData['size'] != null) {
      final sizeStr = legacyData['size'].toString();
      final parts = sizeStr.split('x');
      if (parts.length == 3) {
        length = double.tryParse(parts[0]) ?? 0.1;
        width = double.tryParse(parts[1]) ?? 0.1;
        height = double.tryParse(parts[2]) ?? 0.1;
      }
    }

    // Format 3: Volume-based estimation (cube root if only volume is available)
    if (length == 0.1 &&
        width == 0.1 &&
        height == 0.1 &&
        legacyData['volume'] != null) {
      final volume = (legacyData['volume']).toDouble();
      final side = Math.pow(volume, 1 / 3).toDouble();
      length = width = height = side;
    }

    return ProductDimensions.fromValues(
      length: length,
      width: width,
      height: height,
    );
  }

  // Convert Product to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'sku': sku,
      'brand': brand,
      'price': price,
      'category': category,
      'description': description,
      'partNumber': partNumber,
      'isActive': isActive,
      'stockQuantity': stockQuantity,
      'weight': weight,
      'unit': unit,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'dimensions': dimensions.toFirestore(),
      'movementFrequency': movementFrequency,
      'requiresClimateControl': requiresClimateControl,
      'isHazardousMaterial': isHazardousMaterial,
      'storageType': storageType,
      'metadata': metadata,
    };
  }

  // Enhanced copyWith method
  Product copyWith({
    String? id,
    String? name,
    String? sku,
    String? brand,
    double? price,
    String? category,
    String? description,
    String? partNumber,
    bool? isActive,
    int? stockQuantity,
    double? weight,
    String? unit,
    DateTime? createdAt,
    DateTime? updatedAt,
    ProductDimensions? dimensions,
    String? movementFrequency,
    bool? requiresClimateControl,
    bool? isHazardousMaterial,
    String? storageType,
    Map<String, dynamic>? metadata,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      brand: brand ?? this.brand,
      price: price ?? this.price,
      category: category ?? this.category,
      description: description ?? this.description,
      partNumber: partNumber ?? this.partNumber,
      isActive: isActive ?? this.isActive,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      weight: weight ?? this.weight,
      unit: unit ?? this.unit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dimensions: dimensions ?? this.dimensions,
      movementFrequency: movementFrequency ?? this.movementFrequency,
      requiresClimateControl:
          requiresClimateControl ?? this.requiresClimateControl,
      isHazardousMaterial: isHazardousMaterial ?? this.isHazardousMaterial,
      storageType: storageType ?? this.storageType,
      metadata: metadata ?? this.metadata,
    );
  }

  // Helper method to check storage requirements based on dimensions
  List<String> getStorageRequirements() {
    final requirements = <String>[];

    if (isOversized) {
      requirements.add('oversized_storage');
    }

    if (isLargeItem) {
      requirements.add('large_item_storage');
    }

    if (weight != null && weight! > 50) {
      requirements.add('heavy_duty_storage');
    }

    if (requiresClimateControl) {
      requirements.add('climate_controlled');
    }

    if (isHazardousMaterial) {
      requirements.add('hazmat_approved');
    }

    return requirements;
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, dimensions: $dimensions, weight: ${weight}kg)';
  }
}

// Helper class for dimension validation
class DimensionValidator {
  static const double maxLength = 10.0; // 10 meters
  static const double maxWidth = 10.0; // 10 meters
  static const double maxHeight = 5.0; // 5 meters
  static const double maxVolume = 50.0; // 50 cubic meters

  static ValidationResult validateDimensions(ProductDimensions dimensions) {
    final errors = <String>[];

    if (dimensions.length <= 0) {
      errors.add('Length must be greater than 0');
    } else if (dimensions.length > maxLength) {
      errors.add('Length cannot exceed $maxLength meters');
    }

    if (dimensions.width <= 0) {
      errors.add('Width must be greater than 0');
    } else if (dimensions.width > maxWidth) {
      errors.add('Width cannot exceed $maxWidth meters');
    }

    if (dimensions.height <= 0) {
      errors.add('Height must be greater than 0');
    } else if (dimensions.height > maxHeight) {
      errors.add('Height cannot exceed $maxHeight meters');
    }

    if (dimensions.volume > maxVolume) {
      errors.add('Volume cannot exceed $maxVolume cubic meters');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}

class ValidationResult {
  final bool isValid;
  final List<String> errors;

  ValidationResult({
    required this.isValid,
    this.errors = const [],
  });
}

// Usage examples and migration helper
class ProductDimensionsHelper {
  // Create dimensions from common formats
  static ProductDimensions fromCentimeters(
      double length, double width, double height) {
    return ProductDimensions.fromValues(
      length: length / 100,
      width: width / 100,
      height: height / 100,
    );
  }

  static ProductDimensions fromInches(
      double length, double width, double height) {
    const inchToMeter = 0.0254;
    return ProductDimensions.fromValues(
      length: length * inchToMeter,
      width: width * inchToMeter,
      height: height * inchToMeter,
    );
  }

  // Migration helper for existing data
  static Future<void> migrateLegacyDimensions() async {
    final firestore = FirebaseFirestore.instance;

    final snapshot = await firestore.collection('products').get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['dimensions'] != null) {
        final oldDimensions = data['dimensions'] as Map<String, dynamic>;

        // Check if already in new format
        if (!oldDimensions.containsKey('length') ||
            !oldDimensions.containsKey('width') ||
            !oldDimensions.containsKey('height')) {
          // Convert to new format
          final newDimensions = Product._convertLegacyDimensions(oldDimensions);

          await doc.reference.update({
            'dimensions': newDimensions.toFirestore(),
          });

          print('Migrated dimensions for product: ${doc.id}');
        }
      }
    }
  }
}