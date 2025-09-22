// ADD: MOCK DATA FOR INVENTORY ADJUSTMENT MODULE TESTING
// This file contains sample data for testing the inventory adjustment feature

class MockData {
  // sample spare parts data (Updated for batch tracking - no current_stock)
  static final List<Map<String, dynamic>> spareParts = [
    {
      'name': 'Oil Filter',
      'part_number': 'P-0001',
      'manufacturer_part_number': 'BOS-1987432041',
      'category': 'Filters',
      'location': 'Bay 1, Shelf A',
      'price': 25.50,
    },
    {
      'name': 'Air Filter',
      'part_number': 'P-0002',
      'manufacturer_part_number': 'BOS-1987432042',
      'category': 'Filters',
      'location': 'Bay 1, Shelf A',
      'price': 35.00,
    },
    {
      'name': 'Brake Pads (Front)',
      'part_number': 'P-0003',
      'manufacturer_part_number': 'BOS-1987432043',
      'category': 'Brakes',
      'location': 'Bay 2, Shelf B',
      'price': 85.00,
    },
    {
      'name': 'Brake Pads (Rear)',
      'part_number': 'P-0004',
      'manufacturer_part_number': 'BOS-1987432044',
      'category': 'Brakes',
      'location': 'Bay 2, Shelf B',
      'price': 75.00,
    },
    {
      'name': 'Spark Plugs',
      'part_number': 'P-0005',
      'manufacturer_part_number': 'NGK-1234567890',
      'category': 'Engine',
      'location': 'Bay 3, Shelf C',
      'price': 15.00,
    },
    {
      'name': 'Engine Oil (5L)',
      'part_number': 'P-0006',
      'manufacturer_part_number': 'MOB-9876543210',
      'category': 'Lubricants',
      'location': 'Bay 4, Shelf D',
      'price': 120.00,
    },
    {
      'name': 'Wiper Blades',
      'part_number': 'P-0007',
      'manufacturer_part_number': 'VAL-555666777',
      'category': 'Electrical',
      'location': 'Bay 5, Shelf E',
      'price': 45.00,
    },
    {
      'name': 'Headlight Bulb (H4)',
      'part_number': 'P-0008',
      'manufacturer_part_number': 'PHI-111222333',
      'category': 'Electrical',
      'location': 'Bay 5, Shelf E',
      'price': 30.00,
    },
    {
      'name': 'Timing Belt',
      'part_number': 'P-0009',
      'manufacturer_part_number': 'GAT-444555666',
      'category': 'Engine',
      'location': 'Bay 3, Shelf C',
      'price': 150.00,
    },
    {
      'name': 'Fuel Filter',
      'part_number': 'P-0010',
      'manufacturer_part_number': 'MAH-777888999',
      'category': 'Filters',
      'location': 'Bay 1, Shelf A',
      'price': 40.00,
    },
  ];

  // sample inventory batches data (for batch tracking system)
  static final List<Map<String, dynamic>> inventoryBatches = [
    {
      'part_id': 1, // Oil Filter
      'quantity_on_hand': 50,
      'cost_price': 20.00,
      'received_date': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      'supplier_name': 'Bosch Auto Parts',
      'purchase_order_number': 'PO-2024-001',
    },
    {
      'part_id': 2, // Air Filter
      'quantity_on_hand': 30,
      'cost_price': 28.00,
      'received_date': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
      'supplier_name': 'Bosch Auto Parts',
      'purchase_order_number': 'PO-2024-001',
    },
    {
      'part_id': 3, // Brake Pads (Front)
      'quantity_on_hand': 25,
      'cost_price': 65.00,
      'received_date': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      'supplier_name': 'Bosch Auto Parts',
      'purchase_order_number': 'PO-2024-001',
    },
    {
      'part_id': 4, // Brake Pads (Rear)
      'quantity_on_hand': 20,
      'cost_price': 55.00,
      'received_date': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      'supplier_name': 'Bosch Auto Parts',
      'purchase_order_number': 'PO-2024-001',
    },
    {
      'part_id': 5, // Spark Plugs
      'quantity_on_hand': 100,
      'cost_price': 12.00,
      'received_date': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'supplier_name': 'NGK Spark Plugs',
      'purchase_order_number': 'PO-2024-002',
    },
    {
      'part_id': 6, // Engine Oil
      'quantity_on_hand': 40,
      'cost_price': 95.00,
      'received_date': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'supplier_name': 'Mobil Oil',
      'purchase_order_number': 'PO-2024-003',
    },
    {
      'part_id': 7, // Wiper Blades
      'quantity_on_hand': 25,
      'cost_price': 35.00,
      'received_date': DateTime.now().subtract(const Duration(hours: 8)).toIso8601String(),
      'supplier_name': 'Valeo Auto Parts',
      'purchase_order_number': 'PO-2024-004',
    },
    {
      'part_id': 8, // Headlight Bulb
      'quantity_on_hand': 60,
      'cost_price': 22.00,
      'received_date': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'supplier_name': 'Philips Lighting',
      'purchase_order_number': 'PO-2024-005',
    },
    {
      'part_id': 9, // Timing Belt
      'quantity_on_hand': 15,
      'cost_price': 120.00,
      'received_date': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'supplier_name': 'Gates Corporation',
      'purchase_order_number': 'PO-2024-006',
    },
    {
      'part_id': 10, // Fuel Filter
      'quantity_on_hand': 30,
      'cost_price': 32.00,
      'received_date': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'supplier_name': 'Mahle Filters',
      'purchase_order_number': 'PO-2024-007',
    },
  ];

  // sample inventory adjustments data (10 records)
  static final List<Map<String, dynamic>> inventoryAdjustments = [
    {
      'part_id': 1, // Oil Filter
      'user_id': 1, // Default admin user
      'adjustment_type': 'RECEIVED',
      'quantity': 50,
      'reason_notes': 'New stock received from supplier',
      'supplier_name': 'Bosch Auto Parts',
      'purchase_order_number': 'PO-2024-001',
      'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
    },
    {
      'part_id': 2, // Air Filter
      'user_id': 1,
      'adjustment_type': 'DAMAGED',
      'quantity': 5,
      'reason_notes': 'Damaged during shipping - boxes crushed',
      'photo_url': '/storage/photos/damaged_air_filters.jpg',
      'created_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
    },
    {
      'part_id': 3, // Brake Pads (Front)
      'user_id': 1,
      'adjustment_type': 'RETURNED',
      'quantity': 2,
      'reason_notes': 'Returned from workshop - incorrect size ordered',
      'work_order_number': 'WO-2024-015',
      'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
    },
    {
      'part_id': 4, // Brake Pads (Rear)
      'user_id': 1,
      'adjustment_type': 'LOST',
      'quantity': 3,
      'reason_notes': 'Lost during warehouse reorganization',
      'photo_url': '/storage/photos/lost_brake_pads.jpg',
      'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
    },
    {
      'part_id': 5, // Spark Plugs
      'user_id': 1,
      'adjustment_type': 'RECEIVED',
      'quantity': 100,
      'reason_notes': 'Bulk order received',
      'supplier_name': 'NGK Spark Plugs',
      'purchase_order_number': 'PO-2024-002',
      'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    },
    {
      'part_id': 6, // Engine Oil
      'user_id': 1,
      'adjustment_type': 'EXPIRED',
      'quantity': 8,
      'reason_notes': 'Oil expired - past shelf life date',
      'photo_url': '/storage/photos/expired_oil.jpg',
      'created_at': DateTime.now().subtract(const Duration(hours: 12)).toIso8601String(),
    },
    {
      'part_id': 7, // Wiper Blades
      'user_id': 1,
      'adjustment_type': 'RECEIVED',
      'quantity': 25,
      'reason_notes': 'Restock order received',
      'supplier_name': 'Valeo Auto Parts',
      'purchase_order_number': 'PO-2024-003',
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'part_id': 8, // Headlight Bulb
      'user_id': 1,
      'adjustment_type': 'DAMAGED',
      'quantity': 10,
      'reason_notes': 'Bulbs broken during handling',
      'photo_url': '/storage/photos/damaged_bulbs.jpg',
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'part_id': 9, // Timing Belt
      'user_id': 1,
      'adjustment_type': 'RETURNED',
      'quantity': 1,
      'reason_notes': 'Returned - wrong model for vehicle',
      'work_order_number': 'WO-2024-022',
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'part_id': 10, // Fuel Filter
      'user_id': 1,
      'adjustment_type': 'RECEIVED',
      'quantity': 30,
      'reason_notes': 'Regular restock order',
      'supplier_name': 'Mahle Filters',
      'purchase_order_number': 'PO-2024-004',
      'created_at': DateTime.now().toIso8601String(),
    },
  ];
}
