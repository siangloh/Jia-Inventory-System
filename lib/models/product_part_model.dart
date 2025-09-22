// lib/models/car_part_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CarPartModel {
  final String? id;
  final String partNumber; // Unique part identifier
  final String name; // Product name
  final String description;
  final String category; // Engine, Brakes, Electrical, etc.
  final String brand; // Toyota, Honda, Bosch, etc.
  final List<String> compatibleModels; // Car models this part fits
  final double costPrice; // Purchase price
  final double sellingPrice; // Selling price
  final int currentStock; // Current quantity in stock
  final int minimumStock; // Minimum stock level for alerts
  final String warehouseBay; // Warehouse location - bay
  final String shelfNumber; // Warehouse location - shelf
  final String supplier; // Supplier name
  final String supplierContact; // Supplier contact info
  final bool isActive; // Is product active for sale
  final String condition; // New, Used, Refurbished
  final String imageUrl; // Product image URL
  final List<String> tags; // Search tags
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastRestockedAt; // Last restock date

  CarPartModel({
    this.id,
    required this.partNumber,
    required this.name,
    required this.description,
    required this.category,
    required this.brand,
    this.compatibleModels = const [],
    required this.costPrice,
    required this.sellingPrice,
    this.currentStock = 0,
    this.minimumStock = 5,
    this.warehouseBay = '',
    this.shelfNumber = '',
    this.supplier = '',
    this.supplierContact = '',
    this.isActive = true,
    this.condition = 'New',
    this.imageUrl = '',
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.lastRestockedAt,
  });

  // Computed properties
  bool get isLowStock => currentStock <= minimumStock;

  bool get isOutOfStock => currentStock == 0;

  double get profitMargin => sellingPrice - costPrice;

  double get profitPercentage =>
      costPrice > 0 ? (profitMargin / costPrice) * 100 : 0;

  String get stockStatus {
    if (isOutOfStock) return 'Out of Stock';
    if (isLowStock) return 'Low Stock';
    return 'In Stock';
  }

  Color get stockStatusColor {
    if (isOutOfStock) return Colors.red;
    if (isLowStock) return Colors.orange;
    return Colors.green;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'partNumber': partNumber,
      'name': name,
      'description': description,
      'category': category,
      'brand': brand,
      'compatibleModels': compatibleModels,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'currentStock': currentStock,
      'minimumStock': minimumStock,
      'warehouseBay': warehouseBay,
      'shelfNumber': shelfNumber,
      'supplier': supplier,
      'supplierContact': supplierContact,
      'isActive': isActive,
      'condition': condition,
      'imageUrl': imageUrl,
      'tags': tags,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastRestockedAt': lastRestockedAt,
    };
  }

  factory CarPartModel.fromFirestore(String id, Map<String, dynamic> data) {
    return CarPartModel(
      id: id,
      partNumber: data['partNumber'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      brand: data['brand'] ?? '',
      compatibleModels: List<String>.from(data['compatibleModels'] ?? []),
      costPrice: (data['costPrice'] ?? 0).toDouble(),
      sellingPrice: (data['sellingPrice'] ?? 0).toDouble(),
      currentStock: data['currentStock'] ?? 0,
      minimumStock: data['minimumStock'] ?? 5,
      warehouseBay: data['warehouseBay'] ?? '',
      shelfNumber: data['shelfNumber'] ?? '',
      supplier: data['supplier'] ?? '',
      supplierContact: data['supplierContact'] ?? '',
      isActive: data['isActive'] ?? true,
      condition: data['condition'] ?? 'New',
      imageUrl: data['imageUrl'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastRestockedAt: (data['lastRestockedAt'] as Timestamp?)?.toDate(),
    );
  }

  CarPartModel copyWith({
    String? id,
    String? partNumber,
    String? name,
    String? description,
    String? category,
    String? brand,
    List<String>? compatibleModels,
    double? costPrice,
    double? sellingPrice,
    int? currentStock,
    int? minimumStock,
    String? warehouseBay,
    String? shelfNumber,
    String? supplier,
    String? supplierContact,
    bool? isActive,
    String? condition,
    String? imageUrl,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastRestockedAt,
  }) {
    return CarPartModel(
      id: id ?? this.id,
      partNumber: partNumber ?? this.partNumber,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      compatibleModels: compatibleModels ?? this.compatibleModels,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      currentStock: currentStock ?? this.currentStock,
      minimumStock: minimumStock ?? this.minimumStock,
      warehouseBay: warehouseBay ?? this.warehouseBay,
      shelfNumber: shelfNumber ?? this.shelfNumber,
      supplier: supplier ?? this.supplier,
      supplierContact: supplierContact ?? this.supplierContact,
      isActive: isActive ?? this.isActive,
      condition: condition ?? this.condition,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastRestockedAt: lastRestockedAt ?? this.lastRestockedAt,
    );
  }
}

// Constants for the system
class CarPartsConstants {
  static const List<String> categories = [
    'Engine Parts',
    'Brake System',
    'Electrical Parts',
    'Suspension',
    'Transmission',
    'Cooling System',
    'Exhaust System',
    'Interior Parts',
    'Exterior Parts',
    'Filters',
    'Belts & Hoses',
    'Spark Plugs',
    'Battery & Charging',
    'Lights & Bulbs',
    'Tires & Wheels',
    'Oil & Fluids',
  ];

  static const List<String> conditions = [
    'New',
    'Used',
    'Refurbished',
    'Damaged',
  ];

  static const List<String> popularBrands = [
    'Toyota',
    'Honda',
    'Ford',
    'BMW',
    'Mercedes-Benz',
    'Audi',
    'Volkswagen',
    'Nissan',
    'Hyundai',
    'Kia',
    'Mazda',
    'Subaru',
    'Bosch',
    'NGK',
    'Denso',
    'ACDelco',
    'Mobil 1',
    'Castrol',
    'Valvoline',
  ];

  static const Map<String, IconData> categoryIcons = {
    'Engine Parts': Icons.engineering,
    'Brake System': Icons.speed,
    'Electrical Parts': Icons.electrical_services,
    'Suspension': Icons.expand_more,
    'Transmission': Icons.settings,
    'Cooling System': Icons.ac_unit,
    'Exhaust System': Icons.air,
    'Interior Parts': Icons.airline_seat_recline_normal,
    'Exterior Parts': Icons.directions_car,
    'Filters': Icons.filter_alt,
    'Belts & Hoses': Icons.linear_scale,
    'Spark Plugs': Icons.flash_on,
    'Battery & Charging': Icons.battery_charging_full,
    'Lights & Bulbs': Icons.lightbulb,
    'Tires & Wheels': Icons.trip_origin,
    'Oil & Fluids': Icons.water_drop,
  };
}
