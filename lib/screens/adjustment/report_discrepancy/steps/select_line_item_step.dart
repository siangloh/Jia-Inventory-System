// Step 2: Specify Quantities with Pagination
import 'package:flutter/material.dart';

class SelectLineItemStep extends StatelessWidget {
  const SelectLineItemStep({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container();
  }

  static List<Widget> buildSlivers({
    required List<Map<String, dynamic>> selectedItems,
    required Map<String, int> itemQuantities,
    required int currentPage,
    required int itemsPerPage,
    required Function(Map<String, dynamic>, int) onQuantityChanged,
    required Function(int) onPageChanged,
    required BuildContext context,
  }) {

    if (selectedItems.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No items selected',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please go back and select affected items',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    // Calculate pagination
    final totalPages = (selectedItems.length / itemsPerPage).ceil();
    final startIndex = currentPage * itemsPerPage;
    final endIndex = (startIndex + itemsPerPage).clamp(0, selectedItems.length);
    final paginatedItems = selectedItems.sublist(startIndex, endIndex);

    List<Widget> slivers = [];

    // Header section
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange[50]!, Colors.orange[100]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(bottom: BorderSide(color: Colors.orange[200]!)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.inventory_2,
                        color: Colors.orange[600],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Specify Affected Quantities',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Set the quantity for each affected item',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Summary card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[600], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${selectedItems.length} item${selectedItems.length != 1 ? 's' : ''} selected for discrepancy reporting',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Pagination controls at top
    if (totalPages > 1) {
      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: currentPage > 0 
                      ? () => onPageChanged(currentPage - 1) 
                      : null,
                  icon: Icon(Icons.chevron_left),
                  color: Colors.orange[600],
                  disabledColor: Colors.grey[400],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    'Page ${currentPage + 1} of $totalPages',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: currentPage < totalPages - 1
                      ? () => onPageChanged(currentPage + 1)
                      : null,
                  icon: Icon(Icons.chevron_right),
                  color: Colors.orange[600],
                  disabledColor: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Items list with quantity selectors
    slivers.add(
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= paginatedItems.length) return null;
            
            final item = paginatedItems[index];
            final itemKey = '${item['poId']}_${item['itemId']}';
            final currentQuantity = itemQuantities[itemKey] ?? 1;
            final maxQuantity = item['quantityAvailable'] ?? 1;
            
            return _buildItemQuantityCard(
              item: item,
              currentQuantity: currentQuantity,
              maxQuantity: maxQuantity,
              onQuantityChanged: (quantity) => onQuantityChanged(item, quantity),
              context: context,
            );
          },
          childCount: paginatedItems.length,
        ),
      ),
    );

    // Page indicator at bottom
    if (totalPages > 1) {
      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPages, (index) {
                bool isCurrentPage = index == currentPage;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isCurrentPage 
                        ? Colors.orange[600] 
                        : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ),
        ),
      );
    }

    // Bottom spacing
    slivers.add(
      SliverToBoxAdapter(
        child: const SizedBox(height: 100),
      ),
    );

    return slivers;
  }

  static Widget _buildItemQuantityCard({
    required Map<String, dynamic> item,
    required int currentQuantity,
    required int maxQuantity,
    required Function(int) onQuantityChanged,
    required BuildContext context,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['productName'] ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Part: ${item['partNumber'] ?? ''} • Brand: ${item['brand'] ?? ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.receipt, size: 14, color: Colors.blue[600]),
                    const SizedBox(width: 4),
                    Text(
                      'PO: ${item['poNumber'] ?? 'Unknown'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.inventory, size: 14, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Available: ${maxQuantity} units',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Quantity selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Text(
                    'Affected Quantity',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Quantity controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Decrease button
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: currentQuantity > 1 ? Colors.red[100] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: currentQuantity > 1 ? Colors.red[300]! : Colors.grey[300]!,
                          ),
                        ),
                        child: IconButton(
                          onPressed: currentQuantity > 1 
                              ? () => onQuantityChanged(currentQuantity - 1)
                              : null,
                          icon: Icon(
                            Icons.remove,
                            color: currentQuantity > 1 ? Colors.red[600] : Colors.grey[400],
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      
                      const SizedBox(width: 20),
                      
                      // Quantity input field
                      Container(
                        width: 100,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.white, Colors.grey[50]!],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[300]!, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: TextEditingController(text: currentQuantity.toString()),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: '0',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 20,
                            ),
                          ),
                          onChanged: (value) {
                            final intValue = int.tryParse(value) ?? 0;
                            if (intValue >= 1 && intValue <= maxQuantity) {
                              onQuantityChanged(intValue);
                            }
                          },
                          onSubmitted: (value) {
                            final intValue = int.tryParse(value) ?? currentQuantity;
                            if (intValue < 1) {
                              onQuantityChanged(1);
                            } else if (intValue > maxQuantity) {
                              onQuantityChanged(maxQuantity);
                              // Show max quantity reached message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Maximum available: $maxQuantity units'),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else {
                              onQuantityChanged(intValue);
                            }
                          },
                        ),
                      ),
                      
                      const SizedBox(width: 20),
                      
                      // Increase button
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: currentQuantity < maxQuantity ? Colors.green[100] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: currentQuantity < maxQuantity ? Colors.green[300]! : Colors.grey[300]!,
                          ),
                        ),
                        child: IconButton(
                          onPressed: currentQuantity < maxQuantity 
                              ? () => onQuantityChanged(currentQuantity + 1)
                              : null,
                          icon: Icon(
                            Icons.add,
                            color: currentQuantity < maxQuantity ? Colors.green[600] : Colors.grey[400],
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Quantity info
                  Text(
                    'of $maxQuantity units available',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  
                  // Quick selection buttons
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildQuickSelectButton(
                        label: '1',
                        value: 1,
                        currentValue: currentQuantity,
                        onTap: () => onQuantityChanged(1),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickSelectButton(
                        label: 'ALL',
                        value: maxQuantity,
                        currentValue: currentQuantity,
                        onTap: () => onQuantityChanged(maxQuantity),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildQuickSelectButton({
    required String label,
    required int value,
    required int currentValue,
    required VoidCallback onTap,
  }) {
    final isSelected = currentValue == value;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange[100] : Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? Colors.orange[300]! : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.orange[700] : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}