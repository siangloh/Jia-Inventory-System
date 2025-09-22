// lib/models/product_brand_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum BrandType {
  OEM, // Original Equipment Manufacturer
  AFTERMARKET, // Aftermarket parts
  PERFORMANCE, // Performance/Racing parts
  ECONOMY, // Budget/Economy parts
  PREMIUM, // Premium/Luxury parts
}

class ProductBrandModel {
  final String? id;
  final String brandName;
  final String description;
  final String countryOfOrigin;
  final BrandType brandType;
  final List<String>
      alternativeNames; // Brand variations (e.g., "BMW", "Bayerische Motoren Werke")
  final List<String> specializations; // What they specialize in
  final bool isActive;
  final int usageCount; // How many parts use this brand
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final Map<String, dynamic> metadata; // Additional flexible data
  final String logoUrl; // Brand logo URL
  // final double qualityRating;          // 1-5 star rating

  ProductBrandModel({
    this.id,
    required this.brandName,
    required this.description,
    this.countryOfOrigin = '',
    this.brandType = BrandType.AFTERMARKET,
    this.alternativeNames = const [],
    this.specializations = const [],
    this.isActive = true,
    this.usageCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = '',
    this.metadata = const {},
    this.logoUrl = '',
    // this.qualityRating = 3.0,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'brandName': brandName,
      'description': description,
      'countryOfOrigin': countryOfOrigin,
      'brandType': brandType.name,
      'alternativeNames': alternativeNames,
      'specializations': specializations,
      'isActive': isActive,
      'usageCount': usageCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdBy': createdBy,
      'metadata': metadata,
      'logoUrl': logoUrl,
      // 'qualityRating': qualityRating,
    };
  }

  factory ProductBrandModel.fromFirestore(
      String id, Map<String, dynamic> data) {
    return ProductBrandModel(
      id: id,
      brandName: data['brandName'] ?? '',
      description: data['description'] ?? '',
      countryOfOrigin: data['countryOfOrigin'] ?? '',
      brandType: _parseBrandType(data['brandType']),
      alternativeNames: List<String>.from(data['alternativeNames'] ?? []),
      specializations: List<String>.from(data['specializations'] ?? []),
      isActive: data['isActive'] ?? true,
      usageCount: data['usageCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      logoUrl: data['logoUrl'] ?? '',
      // qualityRating: (data['qualityRating'] ?? 3.0).toDouble(),
    );
  }

  static BrandType _parseBrandType(dynamic value) {
    if (value == null) return BrandType.AFTERMARKET;
    try {
      return BrandType.values.firstWhere(
        (e) => e.name == value.toString().toUpperCase(),
        orElse: () => BrandType.AFTERMARKET,
      );
    } catch (e) {
      return BrandType.AFTERMARKET;
    }
  }

  ProductBrandModel copyWith({
    String? id,
    String? brandName,
    String? description,
    String? countryOfOrigin,
    BrandType? brandType,
    String? website,
    String? contactInfo,
    List<String>? alternativeNames,
    List<String>? specializations,
    bool? isActive,
    int? usageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    Map<String, dynamic>? metadata,
    String? logoUrl,
    double? qualityRating,
  }) {
    return ProductBrandModel(
      id: id ?? this.id,
      brandName: brandName ?? this.brandName,
      description: description ?? this.description,
      countryOfOrigin: countryOfOrigin ?? this.countryOfOrigin,
      brandType: brandType ?? this.brandType,
      alternativeNames: alternativeNames ?? this.alternativeNames,
      specializations: specializations ?? this.specializations,
      isActive: isActive ?? this.isActive,
      usageCount: usageCount ?? this.usageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      metadata: metadata ?? this.metadata,
      logoUrl: logoUrl ?? this.logoUrl,
      // qualityRating: qualityRating ?? this.qualityRating,
    );
  }

  // Get brand type display name
  String get brandTypeDisplayName {
    switch (brandType) {
      case BrandType.OEM:
        return 'OEM';
      case BrandType.AFTERMARKET:
        return 'Aftermarket';
      case BrandType.PERFORMANCE:
        return 'Performance';
      case BrandType.ECONOMY:
        return 'Economy';
      case BrandType.PREMIUM:
        return 'Premium';
    }
  }

  // Get brand type color
  Color get brandTypeColor {
    switch (brandType) {
      case BrandType.OEM:
        return Colors.blue;
      case BrandType.AFTERMARKET:
        return Colors.green;
      case BrandType.PERFORMANCE:
        return Colors.red;
      case BrandType.ECONOMY:
        return Colors.orange;
      case BrandType.PREMIUM:
        return Colors.purple;
    }
  }

  // Search helper - check if brand matches search query
  bool matchesSearch(String query) {
    final lowerQuery = query.toLowerCase();
    return brandName.toLowerCase().contains(lowerQuery) ||
        description.toLowerCase().contains(lowerQuery) ||
        countryOfOrigin.toLowerCase().contains(lowerQuery) ||
        brandTypeDisplayName.toLowerCase().contains(lowerQuery) ||
        alternativeNames
            .any((name) => name.toLowerCase().contains(lowerQuery)) ||
        specializations.any((spec) => spec.toLowerCase().contains(lowerQuery));
  }

// Get quality stars display
// String get qualityStars {
//   final fullStars = qualityRating.floor();
//   final hasHalfStar = qualityRating - fullStars >= 0.5;
//
//   String stars = '★' * fullStars;
//   if (hasHalfStar) stars += '½';
//   stars += '☆' * (5 - fullStars - (hasHalfStar ? 1 : 0));
//
//   return stars;
// }
}
