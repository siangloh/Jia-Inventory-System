// Step 4: Review & Submit for discrepancy reporting
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../services/adjustment/discrepancy_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewSubmitStep extends StatelessWidget {
  const ReviewSubmitStep({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container();
  }

  // ============ CHECKLIST VIEW (Sub-step 1) ============
  static List<Widget> buildChecklistSlivers({
    required List<Map<String, dynamic>> selectedItems,
    required Map<String, int> itemQuantities,
    required String discrepancyType,
    required String description,
    required List<File> localPhotoFiles,
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
              ],
            ),
          ),
        ),
      ];
    }

    List<Widget> slivers = [];

    // Header
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            border: Border(bottom: BorderSide(color: Colors.blue[200]!)),
          ),
          child: Row(
            children: [
              Icon(Icons.checklist_rtl, color: Colors.blue[600], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review Checklist',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      'Verify all information before submitting',
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
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Ready',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Checklist content
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Items summary
              _buildChecklistItem(
                title: 'Affected Items',
                description: '${selectedItems.length} item${selectedItems.length != 1 ? 's' : ''} selected',
                isCompleted: selectedItems.isNotEmpty,
                details: selectedItems.take(5).map((item) {
                  final itemKey = '${item['poId']}_${item['itemId']}';
                  final quantity = itemQuantities[itemKey] ?? 1;
                  return '• ${item['productName']} (${item['partNumber'] ?? 'N/A'}) - ${quantity} units';
                }).join('\n') + (selectedItems.length > 5 ? '\n... and ${selectedItems.length - 5} more items' : ''),
                icon: Icons.inventory_2,
                color: Colors.blue,
              ),
              
              const SizedBox(height: 16),
              
              // Discrepancy type
              _buildChecklistItem(
                title: 'Discrepancy Type',
                description: DiscrepancyService.getDiscrepancyTypeLabel(discrepancyType),
                isCompleted: discrepancyType.isNotEmpty,
                icon: Icons.category,
                color: Colors.purple,
              ),
              
              const SizedBox(height: 16),
              
              // Description
              _buildChecklistItem(
                title: 'Description',
                description: description.isNotEmpty ? 'Provided' : 'Missing',
                isCompleted: description.trim().isNotEmpty,
                details: description.isNotEmpty ? description : null,
                icon: Icons.description,
                color: Colors.orange,
              ),
              
              const SizedBox(height: 16),
              
              // Photos
              _buildChecklistItem(
                title: 'Photo Documentation',
                description: localPhotoFiles.isNotEmpty 
                    ? '${localPhotoFiles.length} photo${localPhotoFiles.length != 1 ? 's' : ''} ready to upload' 
                    : 'No photos',
                isCompleted: true, // Photos are optional
                icon: Icons.camera_alt,
                color: Colors.green,
                showPhotoPreviews: localPhotoFiles.isNotEmpty,
                localPhotoFiles: localPhotoFiles,
              ),
              
              const SizedBox(height: 24),
              
              // Validation summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: discrepancyType.isNotEmpty && description.trim().isNotEmpty
                      ? Colors.green[50]
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: discrepancyType.isNotEmpty && description.trim().isNotEmpty
                        ? Colors.green[300]!
                        : Colors.red[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      discrepancyType.isNotEmpty && description.trim().isNotEmpty
                          ? Icons.check_circle
                          : Icons.error_outline,
                      color: discrepancyType.isNotEmpty && description.trim().isNotEmpty
                          ? Colors.green[600]
                          : Colors.red[600],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        discrepancyType.isNotEmpty && description.trim().isNotEmpty
                            ? 'All required fields are complete. You can proceed to review the summary.'
                            : 'Please complete all required fields before submitting.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: discrepancyType.isNotEmpty && description.trim().isNotEmpty
                              ? Colors.green[700]
                              : Colors.red[700],
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
    );

    // Bottom spacing
    slivers.add(
      SliverToBoxAdapter(
        child: const SizedBox(height: 100),
      ),
    );

    return slivers;
  }

  // ============ SUMMARY VIEW (Sub-step 2) ============
  static List<Widget> buildSummarySlivers({
    required List<Map<String, dynamic>> selectedItems,
    required Map<String, int> itemQuantities,
    required String discrepancyType,
    required String description,
    required List<File> localPhotoFiles,
    required BuildContext context,
  }) {
    List<Widget> slivers = [];

    // Calculate total impact
    double totalImpact = 0.0;
    int totalQuantity = 0;
    for (final item in selectedItems) {
      final itemKey = '${item['poId']}_${item['itemId']}';
      final quantity = itemQuantities[itemKey] ?? 1;
      final unitPrice = (item['unitPrice'] ?? 0.0) as num;
      totalImpact += unitPrice * quantity;
      totalQuantity += quantity;
    }

    // Summary header
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[50]!, Colors.green[100]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(bottom: BorderSide(color: Colors.green[200]!)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.summarize, color: Colors.green[600], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Discrepancy Report Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          'Final review before submission',
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
                      color: Colors.green[600],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.send, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Ready to Submit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Key metrics
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.inventory_2,
                      label: 'Total Items',
                      value: '${selectedItems.length}',
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.numbers,
                      label: 'Total Quantity',
                      value: '$totalQuantity',
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.attach_money,
                      label: 'Cost Impact',
                      value: 'RM ${totalImpact.toStringAsFixed(2)}',
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Summary content
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Discrepancy details section
              _buildSummarySection(
                title: 'Discrepancy Information',
                icon: Icons.warning,
                color: Colors.red,
                children: [
                  _buildSummaryDetailRow(
                    label: 'Type',
                    value: DiscrepancyService.getDiscrepancyTypeLabel(discrepancyType),
                    valueColor: Colors.red[600],
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryDetailRow(
                    label: 'Description',
                    value: description,
                    isMultiline: true,
                  ),
                  if (localPhotoFiles.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildSummaryDetailRow(
                      label: 'Documentation',
                      value: '${localPhotoFiles.length} photo${localPhotoFiles.length != 1 ? 's' : ''} will be uploaded',
                      icon: Icons.camera_alt,
                      iconColor: Colors.green,
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Affected items section
              _buildSummarySection(
                title: 'Affected Items',
                icon: Icons.inventory_2,
                color: Colors.blue,
                children: [
                  Container(
                    constraints: BoxConstraints(maxHeight: 300),
                    child: SingleChildScrollView(
                      child: Column(
                        children: selectedItems.map((item) {
                          final itemKey = '${item['poId']}_${item['itemId']}';
                          final quantity = itemQuantities[itemKey] ?? 1;
                          final unitPrice = (item['unitPrice'] ?? 0.0) as num;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
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
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['productName'] ?? '',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Part: ${item['partNumber'] ?? 'N/A'} • PO: ${item['poNumber'] ?? 'Unknown'}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$quantity units',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      'Unit Price: RM ${unitPrice.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Impact: RM ${(unitPrice * quantity).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.orange[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Photos preview
              if (localPhotoFiles.isNotEmpty)
                _buildSummarySection(
                  title: 'Photo Documentation',
                  icon: Icons.photo_library,
                  color: Colors.green,
                  children: [
                    Container(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: localPhotoFiles.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => _showPhotoPreview(context, localPhotoFiles, index),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(
                                      localPhotoFiles[index],
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey[200],
                                          child: const Icon(
                                            Icons.broken_image,
                                            color: Colors.red,
                                          ),
                                        );
                                      },
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.3),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${index + 1}/${localPhotoFiles.length}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              
              const SizedBox(height: 24),
              
              // Final confirmation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[50]!, Colors.green[100]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.green[700], size: 32),
                    const SizedBox(height: 12),
                    Text(
                      'Ready to Submit Report',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Once submitted, this report will be sent for review. Photos will be uploaded automatically.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check, size: 16, color: Colors.green[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${localPhotoFiles.length} photos ready for upload',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Bottom spacing
    slivers.add(
      SliverToBoxAdapter(
        child: const SizedBox(height: 100),
      ),
    );

    return slivers;
  }

  // Helper widgets
  static Widget _buildChecklistItem({
    required String title,
    required String description,
    required bool isCompleted,
    String? details,
    required IconData icon,
    required Color color,
    bool showPhotoPreviews = false,
    List<File>? localPhotoFiles,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted ? color.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? color.withOpacity(0.3) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCompleted ? color : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted ? Icons.check : Icons.close,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      description,
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
          if (details != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                details,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (showPhotoPreviews && localPhotoFiles != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: localPhotoFiles.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        localPhotoFiles[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image, size: 20),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color.withValues(alpha: 0.7),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSummarySection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  static Widget _buildSummaryDetailRow({
    required String label,
    required String value,
    bool isMultiline = false,
    Color? valueColor,
    IconData? icon,
    Color? iconColor,
  }) {
    return Row(
      crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: iconColor ?? Colors.grey[600]),
          const SizedBox(width: 8),
        ],
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: isMultiline ? const EdgeInsets.all(12) : null,
            decoration: isMultiline
                ? BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  )
                : null,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? Colors.grey[800],
                fontWeight: valueColor != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static void _showPhotoPreview(BuildContext context, List<File> photos, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  child: Image.file(
                    photos[index],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.black,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white,
                            size: 64,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}