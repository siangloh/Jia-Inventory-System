// lib/models/product_name_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProductNameModel {
  String? id;
  final String productName;
  final String description;
  String category;
  final bool isActive;
  final int usageCount; // How many times this name is used
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final Map<String, dynamic> metadata; // Additional flexible data

  ProductNameModel({
    this.id,
    required this.productName,
    required this.description,
    required this.category,
    this.isActive = true,
    this.usageCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = '',
    this.metadata = const {},
  });

  Map<String, dynamic> toFirestore() {
    return {
      'productName': productName,
      'description': description,
      'category': category,
      'isActive': isActive,
      'usageCount': usageCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdBy': createdBy,
      'metadata': metadata,
    };
  }

  factory ProductNameModel.fromFirestore(String id, Map<String, dynamic> data) {
    return ProductNameModel(
      id: id,
      productName: data['productName'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      isActive: data['isActive'] ?? true,
      usageCount: data['usageCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  factory ProductNameModel.fromJson(Map<String, dynamic> json) {
    return ProductNameModel(
      id: json['id'] as String?,
      productName: json['productName'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      usageCount: json['usageCount'] as int? ?? 0,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      createdBy: json['createdBy'] as String? ?? '',
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  static DateTime _parseDateTime(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();

    if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        print('Error parsing date string: $dateValue, error: $e');
        return DateTime.now();
      }
    } else if (dateValue is int) {
      // Handle Unix timestamp
      return DateTime.fromMillisecondsSinceEpoch(dateValue);
    } else if (dateValue is DateTime) {
      return dateValue;
    }

    return DateTime.now();
  }

  ProductNameModel copyWith({
    String? id,
    String? productName,
    String? description,
    String? category,
    String? brand,
    List<String>? alternativeNames,
    List<String>? partNumbers,
    bool? isActive,
    int? usageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    Map<String, dynamic>? metadata,
  }) {
    return ProductNameModel(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      description: description ?? this.description,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      usageCount: usageCount ?? this.usageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      metadata: metadata ?? this.metadata,
    );
  }

  // Search helper - check if product matches search query
  bool matchesSearch(String query) {
    final lowerQuery = query.toLowerCase();
    return productName.toLowerCase().contains(lowerQuery) ||
        description.toLowerCase().contains(lowerQuery) ||
        category.toLowerCase().contains(lowerQuery);
  }
}
