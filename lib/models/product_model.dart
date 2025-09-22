// models/product_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;          // This will be the productNameId from your DAO
  final String sku;
  final double price;
  final String brand;         // This will be the brandId from your DAO
  final String category;      // This will be the categoryId from your DAO
  final String? description;
  final String? partNumber;
  final bool isActive;
  final int stockQuantity;
  final String? unit;
  final String? productUri;
  final ProductDimensions dimensions;
  final double weight;
  final String movementFrequency;
  final bool requiresClimateControl;
  final bool isHazardousMaterial;
  final String storageType;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.brand,
    required this.category,
    this.description,
    this.partNumber,
    this.isActive = true,
    this.stockQuantity = 0,
    this.unit,
    this.productUri,
    required this.dimensions,
    required this.weight,
    this.movementFrequency = 'medium',
    this.requiresClimateControl = false,
    this.isHazardousMaterial = false,
    this.storageType = 'shelf',
    this.createdAt,
    this.updatedAt,
  });

  // Computed property for volume
  double get volume => dimensions.volume;

  // Convert to Firebase document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,                    // productNameId
      'sku': sku,
      'price': price,
      'brand': brand,                  // brandId
      'category': category,            // categoryId
      'description': description,
      'partNumber': partNumber,
      'productUri': productUri?.isNotEmpty == true ? productUri : null,
      'isActive': isActive,
      'stockQuantity': stockQuantity,
      'unit': unit,
      'dimensions': dimensions.toMap(),
      'weight': weight,
      'movementFrequency': movementFrequency,
      'requiresClimateControl': requiresClimateControl,
      'isHazardousMaterial': isHazardousMaterial,
      'storageType': storageType,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  // Create from Firebase document
  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      sku: data['sku'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      brand: data['brand'] ?? '',
      category: data['category'] ?? '',
      description: data['description'],
      partNumber: data['partNumber'],
      productUri: data['productUri']?.toString().isNotEmpty == true
          ? data['productUri']
          : null,
      isActive: data['isActive'] ?? true,
      stockQuantity: data['stockQuantity'] ?? 0,
      unit: data['unit'],
      dimensions: data['dimensions'] != null
          ? ProductDimensions.fromMap(data['dimensions'])
          : ProductDimensions(length: 0.1, width: 0.1, height: 0.1),
      weight: (data['weight'] ?? 1.0).toDouble(),
      movementFrequency: data['movementFrequency'] ?? 'medium',
      requiresClimateControl: data['requiresClimateControl'] ?? false,
      isHazardousMaterial: data['isHazardousMaterial'] ?? false,
      storageType: data['storageType'] ?? 'shelf',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Create from map
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      sku: map['sku'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      brand: map['brand'] ?? '',
      category: map['category'] ?? '',
      description: map['description'],
      partNumber: map['partNumber'],
      productUri: map['productUri'],
      isActive: map['isActive'] ?? true,
      stockQuantity: map['stockQuantity'] ?? 0,
      unit: map['unit'],
      dimensions: map['dimensions'] != null
          ? ProductDimensions.fromMap(map['dimensions'])
          : ProductDimensions(length: 0.1, width: 0.1, height: 0.1),
      weight: (map['weight'] ?? 1.0).toDouble(),
      movementFrequency: map['movementFrequency'] ?? 'medium',
      requiresClimateControl: map['requiresClimateControl'] ?? false,
      isHazardousMaterial: map['isHazardousMaterial'] ?? false,
      storageType: map['storageType'] ?? 'shelf',
    );
  }

  // Copy with method
  Product copyWith({
    String? id,
    String? name,
    String? sku,
    double? price,
    String? brand,
    String? category,
    String? description,
    String? partNumber,
    bool? isActive,
    int? stockQuantity,
    String? unit,
    String? productUri,
    ProductDimensions? dimensions,
    double? weight,
    String? movementFrequency,
    bool? requiresClimateControl,
    bool? isHazardousMaterial,
    String? storageType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      description: description ?? this.description,
      partNumber: partNumber ?? this.partNumber,
      isActive: isActive ?? this.isActive,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      unit: unit ?? this.unit,
      productUri: productUri ?? this.productUri,
      dimensions: dimensions ?? this.dimensions,
      weight: weight ?? this.weight,
      movementFrequency: movementFrequency ?? this.movementFrequency,
      requiresClimateControl: requiresClimateControl ?? this.requiresClimateControl,
      isHazardousMaterial: isHazardousMaterial ?? this.isHazardousMaterial,
      storageType: storageType ?? this.storageType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Product{id: $id, name: $name, sku: $sku, price: $price}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Product &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class ProductDimensions {
  final double length; // meters
  final double width;  // meters
  final double height; // meters

  ProductDimensions({
    required this.length,
    required this.width,
    required this.height,
  });

  double get volume => length * width * height;

  bool canFit(ProductDimensions containerDims) {
    return length <= containerDims.length &&
        width <= containerDims.width &&
        height <= containerDims.height;
  }

  // Convert to map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'length': length,
      'width': width,
      'height': height,
    };
  }

  // Create from map
  factory ProductDimensions.fromMap(Map<String, dynamic> map) {
    return ProductDimensions(
      length: (map['length'] ?? 0.1).toDouble(),
      width: (map['width'] ?? 0.1).toDouble(),
      height: (map['height'] ?? 0.1).toDouble(),
    );
  }

  // Copy with method
  ProductDimensions copyWith({
    double? length,
    double? width,
    double? height,
  }) {
    return ProductDimensions(
      length: length ?? this.length,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  @override
  String toString() {
    return 'ProductDimensions{length: $length, width: $width, height: $height}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ProductDimensions &&
              runtimeType == other.runtimeType &&
              length == other.length &&
              width == other.width &&
              height == other.height;

  @override
  int get hashCode => length.hashCode ^ width.hashCode ^ height.hashCode;
}

// Enums for better type safety
enum MovementFrequency {
  fast,
  medium,
  slow
}

enum StorageType {
  floor,
  shelf,
  rack,
  bulk,
  special
}

// Extension methods for enum conversions
extension MovementFrequencyExtension on MovementFrequency {
  String get value {
    switch (this) {
      case MovementFrequency.fast:
        return 'fast';
      case MovementFrequency.medium:
        return 'medium';
      case MovementFrequency.slow:
        return 'slow';
    }
  }

  static MovementFrequency fromString(String value) {
    switch (value.toLowerCase()) {
      case 'fast':
        return MovementFrequency.fast;
      case 'medium':
        return MovementFrequency.medium;
      case 'slow':
        return MovementFrequency.slow;
      default:
        return MovementFrequency.medium;
    }
  }
}

extension StorageTypeExtension on StorageType {
  String get value {
    switch (this) {
      case StorageType.floor:
        return 'floor';
      case StorageType.shelf:
        return 'shelf';
      case StorageType.rack:
        return 'rack';
      case StorageType.bulk:
        return 'bulk';
      case StorageType.special:
        return 'special';
    }
  }

  static StorageType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'floor':
        return StorageType.floor;
      case 'shelf':
        return StorageType.shelf;
      case 'rack':
        return StorageType.rack;
      case 'bulk':
        return StorageType.bulk;
      case 'special':
        return StorageType.special;
      default:
        return StorageType.shelf;
    }
  }
}