// screens/adjustment/lists/return_history_list_screen.dart
import 'package:flutter/material.dart';
import '../../../services/adjustment/return_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReturnHistoryListScreen extends StatefulWidget {
  const ReturnHistoryListScreen({Key? key}) : super(key: key);

  @override
  State<ReturnHistoryListScreen> createState() => _ReturnHistoryListScreenState();
}

class _ReturnHistoryListScreenState extends State<ReturnHistoryListScreen> {
  final ReturnService _returnService = ReturnService();
  String _selectedStatus = 'All';
  String _searchQuery = '';
  
  final List<String> _statusOptions = ['All', 'PENDING', 'COMPLETED', 'CANCELLED'];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Return History'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/adjustment/return-stock');
            },
            icon: Icon(Icons.add),
            tooltip: 'New Return',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with search and filters
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search bar
                TextField(
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by return ID, product, or supplier...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                
                SizedBox(height: 12),
                
                // Status filter
                Row(
                  children: [
                    Text(
                      'Status: ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _statusOptions.map((status) {
                            final isSelected = _selectedStatus == status;
                            return Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(status),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() => _selectedStatus = status);
                                },
                                backgroundColor: Colors.grey[100],
                                selectedColor: Colors.blue[100],
                                checkmarkColor: Colors.blue[700],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Returns list
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _returnService.getReturnsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: Colors.red[300]),
                        SizedBox(height: 16),
                        Text('Error loading returns'),
                        SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                
                List<Map<String, dynamic>> returns = snapshot.data ?? [];
                
                // Apply filters
                if (_selectedStatus != 'All') {
                  returns = returns.where((return_) => 
                    return_['status'] == _selectedStatus
                  ).toList();
                }
                
                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  returns = returns.where((return_) {
                    final returnId = (return_['returnId'] ?? '').toString().toLowerCase();
                    final returnNumber = (return_['returnNumber'] ?? '').toString().toLowerCase();
                    final returnType = (return_['returnType'] ?? '').toString().toLowerCase();
                    
                    // Search in items
                    bool itemsMatch = false;
                    final selectedItems = return_['selectedItems'] as List? ?? [];
                    for (var item in selectedItems) {
                      final productName = (item['productName'] ?? '').toString().toLowerCase();
                      final supplierName = (item['supplierName'] ?? '').toString().toLowerCase();
                      if (productName.contains(query) || supplierName.contains(query)) {
                        itemsMatch = true;
                        break;
                      }
                    }
                    
                    return returnId.contains(query) || 
                           returnNumber.contains(query) || 
                           returnType.contains(query) ||
                           itemsMatch;
      }).toList();
    }
    
                if (returns.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_return, size: 64, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text(
                          'No Returns Found',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty || _selectedStatus != 'All'
                            ? 'No returns match your current filters'
                            : 'No returns have been created yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/adjustment/return-stock');
                          },
                          icon: Icon(Icons.add),
                          label: Text('Create Return'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: returns.length,
                  itemBuilder: (context, index) {
                    final return_ = returns[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: _ReturnCard(
                        returnData: return_,
                        onStatusChanged: (newStatus) async {
                          try {
                            await _returnService.completeReturn(
                              returnId: return_['returnId'] ?? return_['id'],
                              resolution: newStatus == 'COMPLETED' ? 'CREDIT_ISSUED' : 'CANCELLED',
                              notes: newStatus == 'COMPLETED' ? 'Return processed successfully' : 'Return cancelled by user',
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Return status updated to $newStatus'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error updating status: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        onViewDetails: () {
                          _showReturnDetails(context, return_);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showReturnDetails(BuildContext context, Map<String, dynamic> returnData) {
    showDialog(
      context: context,
      builder: (context) => ReturnDetailsDialog(returnData: returnData),
    );
  }
}

class _ReturnCard extends StatelessWidget {
  final Map<String, dynamic> returnData;
  final Function(String) onStatusChanged;
  final VoidCallback onViewDetails;

  const _ReturnCard({
    required this.returnData,
    required this.onStatusChanged,
    required this.onViewDetails,
  });
  
  @override
  Widget build(BuildContext context) {
    final status = returnData['status']?.toString() ?? 'PENDING';
    final returnType = returnData['returnType']?.toString() ?? 'INTERNAL_RETURN';
    final totalItems = returnData['totalItems'] ?? 0;
    final totalQuantity = returnData['totalQuantity'] ?? 0;
    final totalValue = returnData['totalValue'] ?? 0.0;
    final createdAt = returnData['createdAt'];
    
    final statusColor = _getStatusColor(status);
    final typeColor = _getTypeColor(returnType);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onViewDetails,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              // Header row
          Row(
              children: [
              Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          returnData['returnId'] ?? returnData['id'] ?? 'N/A',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: statusColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                  ),
                ),
              ),
                            SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: typeColor.withOpacity(0.3)),
                ),
                child: Text(
                                _formatReturnType(returnType),
                  style: TextStyle(
                    fontSize: 11,
                                  color: typeColor,
                    fontWeight: FontWeight.w600,
                  ),
                      ),
                    ),
                  ],
                ),
                      ],
                    ),
                  ),
                  if (status == 'PENDING')
                    PopupMenuButton<String>(
                      onSelected: onStatusChanged,
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'COMPLETED',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 20),
                              SizedBox(width: 8),
                              Text('Mark as Completed'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'CANCELLED',
                          child: Row(
        children: [
                              Icon(Icons.cancel, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Cancel Return'),
                            ],
                          ),
                        ),
                      ],
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.more_vert, size: 20),
                ),
              ),
            ],
          ),
              
              SizedBox(height: 12),
              
              // Stats row
              Row(
                children: [
                  _buildStatChip(Icons.inventory_2, '$totalItems items', Colors.blue),
                  SizedBox(width: 8),
                  _buildStatChip(Icons.numbers, '$totalQuantity pcs', Colors.orange),
                  SizedBox(width: 8),
                  _buildStatChip(Icons.attach_money, '\$${totalValue.toStringAsFixed(2)}', Colors.green),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Date and method
              Row(
                      children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  SizedBox(width: 4),
                        Text(
                    createdAt != null ? _formatDate(createdAt) : 'N/A',
                          style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  Spacer(),
                  if (returnData['returnMethod']?.toString().isNotEmpty == true) ...[
                    Icon(Icons.local_shipping, size: 14, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      _formatReturnMethod(returnData['returnMethod']),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'SUPPLIER_RETURN':
        return Colors.red;
      case 'INTERNAL_RETURN':
        return Colors.blue;
      case 'MIXED_RETURN':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatReturnType(String type) {
    switch (type) {
      case 'SUPPLIER_RETURN':
        return 'Supplier';
      case 'INTERNAL_RETURN':
        return 'Internal';
      case 'MIXED_RETURN':
        return 'Mixed';
      default:
        return type;
    }
  }

  String _formatReturnMethod(String? method) {
    if (method == null || method.isEmpty) return 'N/A';
    switch (method) {
      case 'PICKUP':
        return 'Pickup';
      case 'SHIP':
        return 'Ship';
      case 'DROP_OFF':
        return 'Drop Off';
      default:
        return method;
    }
  }

  String _formatDate(dynamic date) {
    try {
      if (date == null) return 'N/A';
      DateTime dateTime;
      if (date is Timestamp) {
        dateTime = date.toDate();
      } else if (date is DateTime) {
        dateTime = date;
      } else {
        dateTime = DateTime.parse(date.toString());
      }
      return DateFormat('MMM dd, yyyy').format(dateTime);
    } catch (e) {
      return 'N/A';
    }
  }
}

class ReturnDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> returnData;

  const ReturnDetailsDialog({Key? key, required this.returnData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final selectedItems = returnData['selectedItems'] as List? ?? [];
    final itemDetails = returnData['itemDetails'] as Map? ?? {};
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
                  Container(
              padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                color: Colors.blue[600],
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
              child: Row(
                children: [
                  Icon(Icons.assignment_return, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Return Details',
                  style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          returnData['returnId'] ?? 'N/A',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
              ],
            ),
          ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Return info
                    _buildInfoSection('Return Information', [
                      _buildInfoRow('Status', returnData['status'] ?? 'N/A'),
                      _buildInfoRow('Type', _formatReturnType(returnData['returnType'] ?? '')),
                      _buildInfoRow('Method', _formatReturnMethod(returnData['returnMethod'])),
                      _buildInfoRow('Created', _formatDate(returnData['createdAt'])),
                      if (returnData['carrierName']?.toString().isNotEmpty == true)
                        _buildInfoRow('Carrier', returnData['carrierName']),
                      if (returnData['trackingNumber']?.toString().isNotEmpty == true)
                        _buildInfoRow('Tracking', returnData['trackingNumber']),
                    ]),
                    
                    SizedBox(height: 20),
                    
                    // Items
                    _buildInfoSection('Items (${selectedItems.length})', [
                      ...selectedItems.map((item) {
                        final itemId = item['id'] ?? item['productId'];
                        final details = itemDetails[itemId] ?? {};
                        final quantity = details['quantity'] ?? 0;
                        final reason = details['reason'] ?? 'N/A';
                        
    return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                            color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                                    child: Text(
                                      item['productName'] ?? 'N/A',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$quantity pcs',
                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange[700],
                                      ),
                      ),
                    ),
                  ],
                ),
                              SizedBox(height: 8),
                              Text(
                                'Brand: ${item['brandName'] ?? 'N/A'}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
                  Text(
                                'SKU: ${item['sku'] ?? 'N/A'}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              Text(
                                'Reason: $reason',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
                        );
                      }).toList(),
                    ]),
                  ],
                ),
              ),
            ),
            
            // Footer with navigation
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                      ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
        ),
          ),
    );
  }
  
  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatReturnType(String type) {
    switch (type) {
      case 'SUPPLIER_RETURN':
        return 'Supplier Return';
      case 'INTERNAL_RETURN':
        return 'Internal Return';
      case 'MIXED_RETURN':
        return 'Mixed Return';
      default:
        return type.isNotEmpty ? type : 'N/A';
    }
  }

  String _formatReturnMethod(String? method) {
    if (method == null || method.isEmpty) return 'N/A';
    switch (method) {
      case 'PICKUP':
        return 'Supplier Pickup';
      case 'SHIP':
        return 'Ship to Supplier';
      case 'DROP_OFF':
        return 'Drop Off';
      default:
        return method;
    }
  }
  
  String _formatDate(dynamic date) {
    try {
      if (date == null) return 'N/A';
      DateTime dateTime;
      if (date is Timestamp) {
        dateTime = date.toDate();
      } else if (date is DateTime) {
        dateTime = date;
    } else {
        dateTime = DateTime.parse(date.toString());
      }
      return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
    } catch (e) {
      return 'N/A';
    }
  }
}