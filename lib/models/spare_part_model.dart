class SparePartModel {
  final int? id;
  final String name;
  final String partNumber;           // Internal part number (e.g., BP-001)
  final String? manufacturerPartNumber; // External manufacturer part number
  final String? category;
  final String? location;
  final double? price;
  final DateTime? createdAt;

  SparePartModel({
    this.id,
    required this.name,
    required this.partNumber,
    required this.manufacturerPartNumber,
    required this.category,
    required this.location,
    required this.price,
    this.createdAt,
  });

  factory SparePartModel.fromJson(Map<String, dynamic> data) => SparePartModel(
        id: data['id'],
        name: data['name'],
        partNumber: data['part_number'],
        manufacturerPartNumber: data['manufacturer_part_number'],
        category: data['category'],
        location: data['location'],
        price: data['price'] != null ? data['price'].toDouble() : null,
        createdAt: DateTime.tryParse(data['created_at'].toString()),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'part_number': partNumber,
        'manufacturer_part_number': manufacturerPartNumber,
        'category': category,
        'location': location,
        'price': price,
        'created_at': createdAt,
      };

  // Helper method to get display name with part number
  String get displayName => '$name ($partNumber)';
  
  // Helper method to check if stock is low (less than 10 items)
  // Note: Stock levels are now tracked at batch level, not part level
  bool get isLowStock => false; // Will be calculated from batches
  
  // Helper method to check if out of stock
  // Note: Stock levels are now tracked at batch level, not part level
  bool get isOutOfStock => false; // Will be calculated from batches
}
