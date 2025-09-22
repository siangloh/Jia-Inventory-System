import 'package:flutter/material.dart';
import '../../../../models/adjustment/return_stock.dart';

class ReturnDetailsStep {
  static List<Widget> buildSlivers({
    required List<Map<String, dynamic>> selectedItems,
    required Map<String, Map<String, dynamic>> itemDetails,
    required String returnType,
    required Function(String, Map<String, dynamic>) onDetailsUpdated,
    required BuildContext context,
  }) {
    List<Widget> slivers = [];
    
    // Header
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            children: [
              Icon(Icons.assignment, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Specify Return Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enter quantity and reason for each item',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Text(
                  '${selectedItems.length} items',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    // Summary stats
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange[400]!, Colors.deepOrange[400]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Items',
                  selectedItems.length.toString(),
                  Icons.inventory_2,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _buildStatCard(
                  'Total Quantity',
                  _calculateTotalQuantity(itemDetails, selectedItems).toString(),
                  Icons.numbers,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _buildStatCard(
                  'Est. Value',
                  _calculateEstValue(selectedItems, itemDetails),
                  Icons.attach_money,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    // Items list
    slivers.add(
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = selectedItems[index];
              final itemId = item['id'] ?? item['productId'] ?? '';
              final details = itemDetails[itemId] ?? {};
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ReturnDetailCard(
                  item: item,
                  returnType: returnType,
                  details: details,
                  onDetailsUpdated: (updatedDetails) {
                    onDetailsUpdated(itemId, updatedDetails);
                  },
                ),
              );
            },
            childCount: selectedItems.length,
          ),
        ),
      ),
    );
    
    return slivers;
  }
  
  static Widget _buildStatCard(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }
  
  static int _calculateTotalQuantity(Map<String, Map<String, dynamic>> details, List<Map<String, dynamic>> items) {
    int total = 0;
    for (var item in items) {
      final itemId = item['id'] ?? item['productId'] ?? '';
      final quantity = details[itemId]?['quantity'];
      if (quantity != null) {
        total += quantity is int ? quantity : int.tryParse(quantity.toString()) ?? 0;
      }
    }
    return total;
  }
  
  static String _calculateEstValue(List<Map<String, dynamic>> items, Map<String, Map<String, dynamic>> details) {
    double total = 0;
    for (var item in items) {
      final itemId = item['id'] ?? item['productId'] ?? '';
      final qty = (details[itemId]?['quantity'] ?? 0) as int;
      
      // Try to get unit price from item data or nested items
      double price = 0.0;
      if (item['unitPrice'] != null) {
        price = (item['unitPrice'] as num).toDouble();
      } else if (item['items'] != null && item['items'] is List) {
        // Calculate from nested items
        final nestedItems = item['items'] as List;
        if (nestedItems.isNotEmpty) {
          final firstItem = nestedItems[0];
          if (firstItem['unitPrice'] != null) {
            price = (firstItem['unitPrice'] as num).toDouble();
          }
        }
      }
      
      total += qty * price;
    }
    return '\$${total.toStringAsFixed(2)}';
  }
}

class _ReturnDetailCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final String returnType;
  final Map<String, dynamic> details;
  final Function(Map<String, dynamic>) onDetailsUpdated;
  
  const _ReturnDetailCard({
    required this.item,
    required this.returnType,
    required this.details,
    required this.onDetailsUpdated,
  });
  
  @override
  State<_ReturnDetailCard> createState() => _ReturnDetailCardState();
}

class _ReturnDetailCardState extends State<_ReturnDetailCard> {
  late TextEditingController _quantityController;
  late TextEditingController _notesController;
  String? _selectedReason;
  String? _selectedCondition;
  bool _isExpanded = false;
  
  // Simplified condition labels for better UI fit
  final Map<String, String> _conditionDisplayNames = {
    'Damaged - Unusable': 'Unusable',
    'Damaged - Partially Usable': 'Partial Use',
    'Defective': 'Defective',
    'Expired': 'Expired',
    'Wrong Item': 'Wrong Item',
    'Missing Parts': 'Missing Parts',
  };
  
  final Map<String, List<String>> _returnReasons = {
    'SUPPLIER_RETURN': [
      'Manufacturing defect',
      'Damaged in shipping',
      'Wrong item delivered',
      'Quality issues',
      'Expired product',
      'Incomplete/Missing parts',
      'Not as described',
      'Other',
    ],
    'INTERNAL_RETURN': [
      'Internal handling damage',
      'Storage damage',
      'Water/moisture damage', 
      'Expired in warehouse',
      'Quality degradation',
      'Contamination',
      'Other',
    ],
    'MIXED_RETURN': [
      'Manufacturing defect',
      'Damaged in shipping',
      'Internal handling damage',
      'Storage damage',
      'Water/moisture damage',
      'Quality issues',
      'Other',
    ],
  };
  
  final List<String> _conditions = ReturnCondition.ALL_CONDITIONS;
  
  @override
  void initState() {
    super.initState();
    
    // Calculate max quantity from item data
    int maxQuantity = _getMaxQuantity();
    
    _quantityController = TextEditingController(
      text: (widget.details['quantity'] ?? maxQuantity).toString()
    );
    
    // Get available reasons based on return type
    final availableReasons = _returnReasons[widget.returnType] ?? 
                             _returnReasons['INTERNAL_RETURN'] ?? [];
    final savedReason = widget.details['reason']?.toString();
    
    if (savedReason != null && availableReasons.contains(savedReason)) {
      _selectedReason = savedReason;
    } else if (availableReasons.isNotEmpty) {
      _selectedReason = availableReasons.first;
    }
    
    // Set condition with fallback
    final savedCondition = widget.details['condition']?.toString();
    _selectedCondition = _conditions.contains(savedCondition) 
        ? savedCondition 
        : ReturnCondition.DAMAGED_UNUSABLE;
    
    _notesController = TextEditingController(text: widget.details['notes'] ?? '');
    
    // Trigger initial update if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.details.isEmpty || widget.details['reason'] == null) {
        _updateDetails();
      }
    });
  }
  
  int _getMaxQuantity() {
    final item = widget.item;
    
    // Try quantityAffected first
    if (item['quantityAffected'] != null) {
      return item['quantityAffected'] as int;
    }
    
    // Calculate from nested items if available
    if (item['items'] != null && item['items'] is List) {
      final items = item['items'] as List;
      return items.fold(0, (sum, subItem) => 
        sum + ((subItem['quantity'] ?? subItem['quantityOrdered'] ?? 1) as int));
    }
    
    // Fallback to quantity field or 1
    return item['quantity'] ?? 1;
  }
  
  String _getProductName() {
    final item = widget.item;
    
    // Try direct productName
    if (item['productName'] != null && item['productName'].toString().isNotEmpty) {
      return item['productName'];
    }
    
    // Try from nested items
    if (item['items'] != null && item['items'] is List) {
      final items = item['items'] as List;
      if (items.isNotEmpty && items[0]['productName'] != null) {
        return items[0]['productName'];
      }
    }
    
    // Fallback
    return item['partName'] ?? 'Unknown Product';
  }
  
  String _getSku() {
    final item = widget.item;
    
    // Try direct SKU fields
    if (item['sku'] != null && item['sku'].toString().isNotEmpty) {
      return item['sku'];
    }
    if (item['productSKU'] != null && item['productSKU'].toString().isNotEmpty) {
      return item['productSKU'];
    }
    
    // Try from nested items
    if (item['items'] != null && item['items'] is List) {
      final items = item['items'] as List;
      if (items.isNotEmpty) {
        return items[0]['sku'] ?? items[0]['partNumber'] ?? 'N/A';
      }
    }
    
    return item['partNumber'] ?? 'N/A';
  }
  
  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  void _updateDetails() {
    widget.onDetailsUpdated({
      'quantity': int.tryParse(_quantityController.text) ?? 0,
      'reason': _selectedReason ?? '',
      'condition': _selectedCondition ?? '',
      'notes': _notesController.text,
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final productName = _getProductName();
    final sku = _getSku();
    final maxQuantity = _getMaxQuantity();
    
    final isComplete = _selectedReason != null && 
                       int.tryParse(_quantityController.text) != null &&
                       int.parse(_quantityController.text) > 0;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isComplete ? Colors.green[300]! : Colors.grey[300]!,
          width: isComplete ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isComplete ? Colors.green[50] : Colors.grey[50],
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(12),
                  bottom: Radius.circular(_isExpanded ? 0 : 12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SKU: $sku | Max: $maxQuantity',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isComplete)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check, size: 14, color: Colors.green[700]),
                          const SizedBox(width: 4),
                          Text(
                            '${_quantityController.text} pcs',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Expanded content
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quantity and Condition row - Fixed overflow issue
                  Row(
                    children: [
                      // Quantity field
                      SizedBox(
                        width: 120,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quantity *',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _quantityController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateDetails(),
                              decoration: InputDecoration(
                                hintText: 'Qty',
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                suffixText: '/$maxQuantity',
                                suffixStyle: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Condition dropdown - Fixed width to prevent overflow
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Condition *',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedCondition,
                              isExpanded: true,
                              decoration: InputDecoration(
                                hintText: 'Select',
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              items: _conditions.map((condition) {
                                return DropdownMenuItem(
                                  value: condition,
                                  child: Text(
                                    _conditionDisplayNames[condition] ?? condition,
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedCondition = value);
                                _updateDetails();
                              },
                              selectedItemBuilder: (BuildContext context) {
                                return _conditions.map<Widget>((String item) {
                                  return Container(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _conditionDisplayNames[item] ?? item,
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Return reason
                  Text(
                    'Return Reason *',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedReason,
                    hint: const Text('Select reason'),
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    items: (_returnReasons[widget.returnType] ?? 
                            _returnReasons['INTERNAL_RETURN'] ?? [])
                        .map((reason) {
                      return DropdownMenuItem<String>(
                        value: reason,
                        child: Text(
                          reason, 
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedReason = value);
                      _updateDetails();
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Additional notes
                  Text(
                    'Additional Notes (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    onChanged: (_) => _updateDetails(),
                    decoration: InputDecoration(
                      hintText: 'Enter any additional notes...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}