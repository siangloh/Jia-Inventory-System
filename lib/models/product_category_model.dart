// Category Model
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CategoryModel {
  String? id;
  final String name;
  final String description;
  final String iconName;
  final Color color;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int productCount;

  CategoryModel({
    this.id,
    required this.name,
    required this.description,
    this.iconName = 'category',
    this.color = Colors.blue,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.productCount = 0,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'iconName': iconName,
      'colorValue': color.value,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory CategoryModel.fromFirestore(String docId, Map<String, dynamic> data) {
    return CategoryModel(
      id: docId,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      iconName: data['iconName'] ?? 'category',
      color: Color(data['colorValue'] ?? Colors.blue.value),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      productCount: data['productCount'] ?? 0,
    );
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      iconName: json['iconName'] as String? ?? 'category',
      color: _parseColor(json['colorValue']),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      productCount: json['productCount'] as int? ?? 0,
    );
  }

  // Helper method for color parsing
  static Color _parseColor(dynamic colorValue) {
    if (colorValue == null) return Colors.blue;

    if (colorValue is int) {
      // Parse from integer (ARGB format)
      return Color(colorValue);
    } else if (colorValue is String) {
      try {
        // Try parsing as hex string
        if (colorValue.startsWith('#')) {
          return Color(int.parse(colorValue.substring(1).padLeft(8, 'FF'), radix: 16) + 0xFF000000);
        } else {
          // Try parsing as integer string
          return Color(int.parse(colorValue));
        }
      } catch (e) {
        print('Error parsing color string: $colorValue, error: $e');
        return Colors.blue;
      }
    }

    return Colors.blue;
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

  CategoryModel copyWith({
    String? id,
    String? name,
    String? description,
    String? iconName,
    Color? color,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? productCount,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      productCount: productCount ?? this.productCount,
    );
  }
}
