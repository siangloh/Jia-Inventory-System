import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';

class Product {
  final String id;
  String name;
  String partNumber;
  String category;
  int quantity;
  double price;
  int minStockLevel;
  final DateTime addedAt;
  String? brand;
  String? description;

  // Enhanced fields for advanced inventory management
  final String warehouseBay;
  final String shelfNumber;
  final String supplier;
  final List<String> alternativeParts;
  final String? imageUrl;
  final double weight;
  final String dimensions;
  final int reorderPoint;
  final int maxStockLevel;
  final DateTime? lastRestocked;
  final List<String> compatibleVehicles;
  int viewCount;
  double rating;
  final List<String> tags;

  Product({
    required this.id,
    required this.name,
    required this.partNumber,
    required this.category,
    required this.quantity,
    required this.price,
    this.minStockLevel = 10,
    DateTime? addedAt,
    this.brand,
    this.description,
    required this.warehouseBay,
    required this.shelfNumber,
    required this.supplier,
    this.alternativeParts = const [],
    this.imageUrl,
    this.weight = 0.0,
    this.dimensions = '',
    this.reorderPoint = 5,
    this.maxStockLevel = 100,
    this.lastRestocked,
    this.compatibleVehicles = const [],
    this.viewCount = 0,
    this.rating = 0.0,
    this.tags = const [],
  }) : addedAt = addedAt ?? DateTime.now();

  bool get isLowStock => quantity <= minStockLevel;
  bool get isOutOfStock => quantity == 0;
  bool get isCriticalStock => quantity <= reorderPoint;
  bool get isOverStock => quantity > maxStockLevel;

  String get stockStatus {
    if (isOutOfStock) return 'Out of Stock';
    if (isCriticalStock) return 'Critical';
    if (isLowStock) return 'Low Stock';
    if (isOverStock) return 'Overstock';
    return 'In Stock';
  }

  Color get stockStatusColor {
    if (isOutOfStock) return Colors.red;
    if (isCriticalStock) return Colors.orange;
    if (isLowStock) return Colors.amber;
    if (isOverStock) return Colors.purple;
    return Colors.green;
  }

  String get fullLocation => '$warehouseBay-$shelfNumber';

  // Search score calculation for ML-powered recommendations
  double calculateSearchScore(String query, List<String> userHistory) {
    double score = 0.0;
    final lowerQuery = query.toLowerCase();

    // Name match (highest priority)
    if (name.toLowerCase().contains(lowerQuery)) score += 10.0;

    // Part number match (high priority)
    if (partNumber.toLowerCase().contains(lowerQuery)) score += 8.0;

    // Brand match
    if (brand?.toLowerCase().contains(lowerQuery) ?? false) score += 6.0;

    // Category match
    if (category.toLowerCase().contains(lowerQuery)) score += 5.0;

    // Supplier match
    if (supplier.toLowerCase().contains(lowerQuery)) score += 4.0;

    // Compatible vehicles match
    for (String vehicle in compatibleVehicles) {
      if (vehicle.toLowerCase().contains(lowerQuery)) {
        score += 3.0;
        break;
      }
    }

    // Tags match
    for (String tag in tags) {
      if (tag.toLowerCase().contains(lowerQuery)) {
        score += 2.0;
        break;
      }
    }

    // Boost based on view count (popularity)
    score += viewCount * 0.1;

    // Boost based on rating
    score += rating;

    // Boost if user has searched similar items before
    for (String historyItem in userHistory) {
      if (historyItem.toLowerCase().contains(lowerQuery) ||
          lowerQuery.contains(historyItem.toLowerCase())) {
        score += 1.0;
        break;
      }
    }

    return score;
  }
}

class SearchAnalytics {
  String query;
  DateTime timestamp;
  int resultCount;
  String? selectedProduct;

  SearchAnalytics({
    required this.query,
    required this.timestamp,
    required this.resultCount,
    this.selectedProduct,
  });
}