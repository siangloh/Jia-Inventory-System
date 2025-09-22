// lib/screens/adjustment/lists/discrepancy_report_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../widgets/adjustment/base_list_widget.dart';
import '../../../widgets/adjustment/expandable_card.dart';
import '../../../services/adjustment/discrepancy_service.dart';
import '../../../services/adjustment/snackbar_manager.dart';

class DiscrepancyReportsListScreen extends BaseListWidget<Map<String, dynamic>> {
  const DiscrepancyReportsListScreen({Key? key}) : super(
    key: key,
    title: 'Discrepancy Reports',
    subtitle: 'View all reported discrepancies',
    icon: Icons.warning_amber,
  );
  
  @override
  State<DiscrepancyReportsListScreen> createState() => _DiscrepancyReportsListScreenState();
}

class _DiscrepancyReportsListScreenState extends BaseListState<Map<String, dynamic>, DiscrepancyReportsListScreen> {
  final DiscrepancyService _discrepancyService = DiscrepancyService();
  
  // Additional filters specific to discrepancy reports
  String selectedType = 'All';
  String selectedTimeFilter = 'All';
  
  // Stream subscription for real-time updates
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;
  
  DiscrepancyReportsListScreen get widget => super.widget;
  
  // Helper functions to handle both data structures (old and new format)
  String _getProductName(Map<String, dynamic> report) {
    // New format: items array with productName inside
    if (report['items'] != null && (report['items'] as List).isNotEmpty) {
      final firstItem = (report['items'] as List).first;
      return firstItem['productName'] ?? 'N/A';
    }
    // Old format: partName at root level
    return report['partName'] ?? report['productName'] ?? 'N/A';
  }
  
  String _getPONumber(Map<String, dynamic> report) {
    // New format: items array with poNumber inside
    if (report['items'] != null && (report['items'] as List).isNotEmpty) {
      final firstItem = (report['items'] as List).first;
      return firstItem['poNumber'] ?? 'Unknown';
    }
    // Old format: poNumber at root level
    return report['poNumber'] ?? report['poId'] ?? 'Unknown';
  }
  
  int _getQuantityAffected(Map<String, dynamic> report) {
    // New format: items array with quantity inside
    if (report['items'] != null && (report['items'] as List).isNotEmpty) {
      final firstItem = (report['items'] as List).first;
      return firstItem['quantity'] ?? 0;
    }
    // Old format: quantityAffected at root level
    return report['quantityAffected'] ?? 0;
  }
  
  @override
  Future<void> loadData() async {
    setState(() => isLoading = true);
    
    try {
      final reports = await _discrepancyService.getDiscrepancyReports();
      
      
      setState(() {
        allItems = reports;
        isLoading = false;
      });
      
      applyFiltersAndSort();
    } catch (e) {
      setState(() => isLoading = false);
      SnackbarManager().showErrorMessage(
        context,
        message: 'Error loading discrepancy reports: $e',
      );
    }
  }

  // Real-time data loading method (following warehouse pattern)
  void _loadDataFromStream(List<Map<String, dynamic>> reports) {
    
    setState(() {
      allItems = reports;
      isLoading = false;
    });
    
    applyFiltersAndSort();
  }
  
  @override
  List<Map<String, dynamic>> applyCustomFilters(List<Map<String, dynamic>> items) {
    List<Map<String, dynamic>> filtered = items;
    
    // Type filter
    if (selectedType != 'All') {
      filtered = filtered.where((item) => 
        item['discrepancyType'] == selectedType).toList();
    }
    
    // Time filter
    if (selectedTimeFilter != 'All') {
      final now = DateTime.now();
      filtered = filtered.where((item) {
        final reportedAt = (item['reportedAt'] as Timestamp?)?.toDate() ?? DateTime(1900);
        
        switch (selectedTimeFilter) {
          case 'Today':
            return reportedAt.year == now.year && 
                   reportedAt.month == now.month && 
                   reportedAt.day == now.day;
          case 'This Week':
            final weekStart = now.subtract(Duration(days: now.weekday - 1));
            return reportedAt.isAfter(weekStart);
          case 'This Month':
            return reportedAt.year == now.year && reportedAt.month == now.month;
          default:
            return true;
        }
      }).toList();
    }
    
    return filtered;
  }
  
  @override
  Map<String, dynamic> calculateStats(List<Map<String, dynamic>> items) {
    int physicalDamage = 0;
    int manufacturingDefects = 0;
    int qualityIssues = 0;
    double totalImpact = 0.0;
    
    for (final report in items) {
      switch (report['discrepancyType']) {
        case 'physicalDamage':
          physicalDamage++;
          break;
        case 'manufacturingDefect':
          manufacturingDefects++;
          break;
        case 'qualityIssue':
          qualityIssues++;
          break;
      }
      totalImpact += (report['costImpact'] ?? 0.0) as num;
    }
    
    return {
      'Total': items.length,
      'Damage': physicalDamage,
      'Defects': manufacturingDefects,
      'Quality': qualityIssues,
      'Impact': 'RM ${totalImpact.toStringAsFixed(0)}',
    };
  }
  
  @override
  Widget buildCard(Map<String, dynamic> item) {
    final itemId = getItemId(item);
    final isExpanded = expandedCards.contains(itemId);
    final type = item['discrepancyType'] ?? '';
    final typeColor = _getTypeColor(type);
    
    return ExpandableCard(
      id: itemId,
      isExpanded: isExpanded,
      onToggleExpand: () => toggleCardExpansion(itemId),
      statusColor: typeColor,
      statusText: DiscrepancyService.getDiscrepancyTypeLabel(type),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getProductName(item),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'PO: ${_getPONumber(item)}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      content: Column(
        children: [
          // Three colored sub-cards as shown in the image
          Row(
            children: [
              // Red card - Qty Affected
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.numbers, size: 16, color: Colors.red[700]),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Qty Affected',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red[600],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_getQuantityAffected(item)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Yellow card - Impact
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.attach_money, size: 16, color: Colors.orange[700]),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Impact',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange[600],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'RM ${((item['costImpact'] ?? 0.0) as num).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Blue card - Reported
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.calendar_today, size: 16, color: Colors.blue[700]),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Reported',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue[600],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(item['reportedAt']),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Status and priority indicators
          Row(
            children: [
              _buildStatusChip(item['status'] ?? 'submitted'),
              const Spacer(),
              _buildPriorityChip(item),
            ],
          ),
        ],
      ),
      expandedContent: buildExpandedDetails(item),
    );
  }
  
  @override
  Widget buildExpandedDetails(Map<String, dynamic> item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Description', item['description'] ?? 'No description'),
        if (item['rootCause'] != null && item['rootCause'].toString().isNotEmpty)
          _buildDetailRow('Root Cause', item['rootCause']),
        if (item['preventionMeasures'] != null && item['preventionMeasures'].toString().isNotEmpty)
          _buildDetailRow('Prevention', item['preventionMeasures']),
        _buildDetailRow('Reported By', _formatUserInfo(item)),
        _buildDetailRow('Status', item['status'] ?? 'submitted'),
        
        // Photos section with preview functionality
        if ((item['photos'] as List?)?.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          Text(
            'Attached Photos',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _showPhotoPreview(item['photos'] as List),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.photo_library, size: 16, color: Colors.blue[700]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${(item['photos'] as List).length} photo(s) attached',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap to preview',
                style: TextStyle(
                  fontSize: 12,
                            color: Colors.blue[600],
                ),
              ),
            ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 14, color: Colors.blue[600]),
                ],
              ),
            ),
          ),
        ],
        
      ],
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
  
  
  @override
  Widget buildQuickFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Time filter chips
          ...['All', 'Today', 'This Week', 'This Month'].map((timeFilter) {
            final isSelected = selectedTimeFilter == timeFilter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  timeFilter,
                  style: TextStyle(fontSize: 12),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => selectedTimeFilter = selected ? timeFilter : 'All');
                  applyFiltersAndSort();
                },
                selectedColor: Colors.blue.withOpacity(0.2),
                checkmarkColor: Colors.blue,
                avatar: isSelected 
                    ? Icon(Icons.check, size: 16, color: Colors.blue) 
                    : null,
              ),
            );
          }),
          
          const SizedBox(width: 16),
          
          // Type filter chips
          ...['All', 'physicalDamage', 'manufacturingDefect', 'qualityIssue'].map((type) {
            final isSelected = selectedType == type;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  type == 'All' ? 'All Types' : DiscrepancyService.getDiscrepancyTypeLabel(type),
                  style: TextStyle(fontSize: 12),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => selectedType = selected ? type : 'All');
                  applyFiltersAndSort();
                },
                selectedColor: _getTypeColor(type).withOpacity(0.2),
                checkmarkColor: _getTypeColor(type),
                avatar: type != 'All' 
                    ? Icon(_getTypeIcon(type), size: 16) 
                    : null,
              ),
            );
          }),
          
        ],
      ),
    );
  }
  
  @override
  List<String> getSortOptions() {
    return ['Date', 'Item Name', 'Type', 'Impact'];
  }
  
  @override
  int compareItems(Map<String, dynamic> a, Map<String, dynamic> b, String sortBy) {
    switch (sortBy.toLowerCase()) {
      case 'date':
        final aDate = (a['reportedAt'] as Timestamp?)?.toDate() ?? DateTime(1900);
        final bDate = (b['reportedAt'] as Timestamp?)?.toDate() ?? DateTime(1900);
        return bDate.compareTo(aDate);
      case 'item name':
        return (a['partName'] ?? '').compareTo(b['partName'] ?? '');
      case 'type':
        return (a['discrepancyType'] ?? '').compareTo(b['discrepancyType'] ?? '');
      case 'impact':
        final aImpact = ((a['costImpact'] ?? 0.0) as num).toDouble();
        final bImpact = ((b['costImpact'] ?? 0.0) as num).toDouble();
        return bImpact.compareTo(aImpact);
      default:
        return 0;
    }
  }
  
  @override
  String getItemId(Map<String, dynamic> item) {
    return item['id'] ?? '';
  }
  
  @override
  bool matchesSearch(Map<String, dynamic> item, String query) {
    final searchLower = query.toLowerCase();
    final searchText = [
      _getProductName(item),
      _getPONumber(item),
      item['description'] ?? '',
    ].join(' ').toLowerCase();
    return searchText.contains(searchLower);
  }
  
  @override
  DateTime getItemDate(Map<String, dynamic> item) {
    final timestamp = item['reportedAt'] as Timestamp?;
    return timestamp?.toDate() ?? DateTime.now();
  }
  


  Widget _buildStatusChip(String status) {
    Color statusColor;
    IconData statusIcon;
    
    switch (status.toLowerCase()) {
      case 'submitted':
        statusColor = Colors.blue;
        statusIcon = Icons.send;
        break;
      case 'under_review':
        statusColor = Colors.orange;
        statusIcon = Icons.visibility;
        break;
      case 'resolved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 12, color: statusColor),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(Map<String, dynamic> item) {
    final quantity = item['quantityAffected'] ?? 0;
    final impact = (item['costImpact'] ?? 0.0) as num;
    
    String priority;
    Color priorityColor;
    IconData priorityIcon;
    
    if (quantity > 10 || impact > 1000) {
      priority = 'HIGH';
      priorityColor = Colors.red;
      priorityIcon = Icons.priority_high;
    } else if (quantity > 5 || impact > 500) {
      priority = 'MED';
      priorityColor = Colors.orange;
      priorityIcon = Icons.remove;
    } else {
      priority = 'LOW';
      priorityColor = Colors.green;
      priorityIcon = Icons.keyboard_arrow_down;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: priorityColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: priorityColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(priorityIcon, size: 12, color: priorityColor),
          const SizedBox(width: 4),
          Text(
            priority,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: priorityColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoPreview(List photos) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.photo_library, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Attached Photos (${photos.length})',
                style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              // Photo grid
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    itemCount: photos.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () => _showFullScreenPhoto(photos[index], index + 1, photos.length),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: _buildPhotoWidget(photos[index]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoWidget(dynamic photo) {
    if (photo is String) {
      if (photo.startsWith('http')) {
        // Network image
        return Image.network(
          photo,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[200],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red[400]),
                  const SizedBox(height: 4),
                  Text(
                    'Failed to load',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red[600],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      } else {
        // Supabase Storage filename - use signed URL
        return FutureBuilder<String?>(
          future: _getSignedUrl(photo),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            
            if (snapshot.hasError || snapshot.data == null) {
              return Container(
                color: Colors.grey[200],
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red[400]),
                    const SizedBox(height: 4),
                    Text(
                      'Failed to load',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red[600],
                      ),
                    ),
                  ],
                ),
              );
            }
            
            return Image.network(
              snapshot.data!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: Colors.red[400]),
                      const SizedBox(height: 4),
                      Text(
                        'Failed to load',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red[600],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      }
    }
    
    // Default placeholder
    return Container(
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image, color: Colors.grey[400]),
          const SizedBox(height: 4),
          Text(
            'Photo',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenPhoto(dynamic photo, int currentIndex, int totalPhotos) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            // Full screen photo
            Center(
              child: _buildPhotoWidget(photo),
            ),
            
            // Close button
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
              ),
            ),
            
            // Photo counter
            Positioned(
              top: 40,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$currentIndex / $totalPhotos',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatUserInfo(Map<String, dynamic> item) {
    final reportedBy = item['reportedBy'] ?? '';
    final reportedByName = item['reportedByName'] ?? '';
    
    if (reportedByName.isNotEmpty && reportedBy.isNotEmpty) {
      return '$reportedByName ($reportedBy)';
    } else if (reportedByName.isNotEmpty) {
      return reportedByName;
    } else if (reportedBy.isNotEmpty) {
      return 'Employee ($reportedBy)';
    } else {
      return 'Unknown User';
    }
  }
  
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else {
      return 'N/A';
    }
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }
    
    return '${date.day}/${date.month}/${date.year}';
  }
  
  Color _getTypeColor(String type) {
    switch (type) {
      case 'physicalDamage':
        return Colors.red;
      case 'manufacturingDefect':
        return Colors.orange;
      case 'qualityIssue':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
  
  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'physicalDamage':
        return Icons.broken_image;
      case 'manufacturingDefect':
        return Icons.build;
      case 'qualityIssue':
        return Icons.warning;
      default:
        return Icons.help_outline;
    }
  }
  
  // Get signed URL for Supabase Storage
  Future<String?> _getSignedUrl(String fileName) async {
    if (fileName.isEmpty) {
      return null;
    }
    try {
      final signedUrl = await Supabase.instance.client.storage
          .from('discrepancy-photos')
          .createSignedUrl(fileName, 3600); // 1 hour expiry
      
      if (signedUrl.isNotEmpty) {
        return signedUrl;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    // Dispose stream subscription to prevent memory leaks
    _streamSubscription?.cancel();
    super.dispose();
  }

  // Override build method to use StreamBuilder for real-time updates
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _discrepancyService.getDiscrepancyReportsStream(),
      builder: (context, snapshot) {
        // Handle different connection states
        if (snapshot.connectionState == ConnectionState.waiting && allItems.isEmpty) {
          // Show loading only if we don't have any data yet
          return Material(
            child: Container(
              color: Colors.grey[50],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading discrepancy reports...'),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          // Show error state
          return Material(
            child: Container(
              color: Colors.grey[50],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text('Error loading data: ${snapshot.error}'),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => loadData(), // Fallback to manual loading
                      child: Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasData && mounted) {
          Future.microtask(() {
            if (mounted) {
              _loadDataFromStream(snapshot.data!);
            }
          });
        }

        // Use the base widget's build method for the UI
        return super.build(context);
      },
    );
  }
}