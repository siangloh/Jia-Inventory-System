// screens/adjustment/return_details_screen.dart
import 'package:flutter/material.dart';
import '../../../services/adjustment/return_service.dart';
import '../../../services/adjustment/snackbar_manager.dart';

class ReturnDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> returnData;
  
  const ReturnDetailsScreen({Key? key, required this.returnData}) : super(key: key);
  
  @override
  State<ReturnDetailsScreen> createState() => _ReturnDetailsScreenState();
}

class _ReturnDetailsScreenState extends State<ReturnDetailsScreen> {
  final ReturnService _returnService = ReturnService();
  final SnackbarManager _snackbarManager = SnackbarManager();
  
  late Map<String, dynamic> _returnData;
  bool _isLoading = false;
  bool _isCompleting = false;
  final TextEditingController _resolutionController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _returnData = widget.returnData;
    _loadReturnDetails();
  }
  
  @override
  void dispose() {
    _resolutionController.dispose();
    super.dispose();
  }
  
  Future<void> _loadReturnDetails() async {
    setState(() => _isLoading = true);
    try {
      final details = await _returnService.getReturnDetails(_returnData['returnId']);
      setState(() {
        _returnData = details;
      });
    } catch (e) {
      if (mounted) {
        _snackbarManager.showErrorMessage(context, message: 'Error loading details: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _completeReturn() async {
    if (_resolutionController.text.trim().isEmpty) {
      _snackbarManager.showErrorMessage(context, message: 'Please enter resolution notes');
      return;
    }
    
    setState(() => _isCompleting = true);
    try {
      await _returnService.completeReturn(
        returnId: _returnData['returnId'],
        resolution: _resolutionController.text.trim(),
      );
      
      if (mounted) {
        _snackbarManager.showSuccessMessage(context, message: 'Return completed successfully');
        Navigator.pop(context, true); // Return true to trigger refresh
      }
    } catch (e) {
      if (mounted) {
        _snackbarManager.showErrorMessage(context, message: 'Error completing return: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
    }
  }
  
  void _showCompleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Return'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter resolution notes:'),
            const SizedBox(height: 16),
            TextField(
              controller: _resolutionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g., Credit issued, replacement sent, etc.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isCompleting
              ? null
              : () {
                  Navigator.pop(context);
                  _completeReturn();
                },
            child: _isCompleting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Complete'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final status = _returnData['status'] ?? 'PENDING';
    final isPending = status == 'PENDING';
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[700]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _returnData['returnId'] ?? 'Return Details',
          style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600),
        ),
        actions: [
          if (isPending)
            IconButton(
              icon: Icon(Icons.check_circle, color: Colors.green),
              onPressed: _showCompleteDialog,
              tooltip: 'Complete Return',
            ),
        ],
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Column(
              children: [
                // Status header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isPending 
                        ? [Colors.orange[400]!, Colors.orange[600]!]
                        : [Colors.green[400]!, Colors.green[600]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isPending ? Icons.pending_actions : Icons.check_circle,
                        color: Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isPending ? 'PENDING' : 'COMPLETED',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isPending && _returnData['resolvedAt'] != null)
                        Text(
                          'Completed on ${_formatDate(_returnData['resolvedAt'])}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Return information
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Return Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Return ID', _returnData['returnId'] ?? 'N/A'),
                      _buildInfoRow('Return Type', _formatReturnType(_returnData['returnType'])),
                      _buildInfoRow('Total Items', '${_returnData['totalItems'] ?? 0}'),
                      _buildInfoRow('Total Quantity', '${_returnData['totalQuantity'] ?? 0}'),
                      _buildInfoRow('Return Method', _formatReturnMethod(_returnData['returnMethod'])),
                      if (_returnData['trackingNumber'] != null)
                        _buildInfoRow('Tracking Number', _returnData['trackingNumber']),
                      _buildInfoRow('Created By', _returnData['createdByUserName'] ?? 'Unknown'),
                      _buildInfoRow('Created At', _formatDate(_returnData['createdAt'])),
                      if (_returnData['resolution'] != null)
                        _buildInfoRow('Resolution', _returnData['resolution']),
                    ],
                  ),
                ),
                
                // Items list
                if (_returnData['items'] != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Returned Items',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...(_returnData['items'] as List).map((item) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['productName'] ?? 'Unknown Product',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Part #: ${item['partNumber'] ?? 'N/A'} | Qty: ${item['returnQuantity'] ?? 0}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (item['reason'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Reason: ${item['reason']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 80),
              ],
            ),
          ),
      floatingActionButton: isPending
        ? FloatingActionButton.extended(
            onPressed: _showCompleteDialog,
            backgroundColor: Colors.green,
            icon: const Icon(Icons.check),
            label: const Text('Complete Return'),
          )
        : null,
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    // Implement proper date formatting
    return 'Recent';
  }
  
  String _formatReturnType(String? type) {
    switch (type) {
      case 'SUPPLIER_RETURN':
        return 'Supplier Return';
      case 'INTERNAL_RETURN':
        return 'Internal Return';
      default:
        return type ?? 'Unknown';
    }
  }
  
  String _formatReturnMethod(String? method) {
    switch (method) {
      case 'PICKUP':
        return 'Supplier Pickup';
      case 'SHIP':
        return 'Ship to Supplier';
      case 'DROP_OFF':
        return 'Drop Off';
      default:
        return method ?? 'Unknown';
    }
  }
}