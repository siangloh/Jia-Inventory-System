// dialog widget for reporting discrepancies during stock receiving
// stores photos locally in memory until final submission
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/adjustment/inventory_service.dart';
import '../../services/adjustment/snackbar_manager.dart';

class ReportDiscrepancyDialog extends StatefulWidget {
  final Map<String, dynamic> lineItem;
  final int lineItemIndex;
  final String poId;
  final String lineItemId;
  final String productId;
  final String productName;

  const ReportDiscrepancyDialog({
    Key? key,
    required this.lineItem,
    required this.lineItemIndex,
    required this.poId,
    required this.lineItemId,
    required this.productId,
    required this.productName,
  }) : super(key: key);

  @override
  State<ReportDiscrepancyDialog> createState() => _ReportDiscrepancyDialogState();
}

class _ReportDiscrepancyDialogState extends State<ReportDiscrepancyDialog> {
  final TextEditingController _descriptionController = TextEditingController();
  final InventoryService _inventoryService = InventoryService();
  final SnackbarManager _snackbarManager = SnackbarManager();
  
  // Store File objects locally (not uploaded to Supabase yet)
  List<File> _localPhotoFiles = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_isLoading) return;
    
    // Check max photos limit
    if (_localPhotoFiles.length >= 5) {
      _snackbarManager.showWarningMessage(
        context, 
        message: 'Maximum 5 photos allowed'
      );
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      
      // Show source selection dialog
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(context).pop(null),
              ),
            ],
          ),
        ),
      );

      if (source != null) {
        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );

        if (image != null) {
          final file = File(image.path);
          if (await file.exists()) {
            if (mounted) {
              setState(() {
                _localPhotoFiles.add(file);
              });
              
              _snackbarManager.showSuccessMessage(
                context,
                message: 'Photo added (will upload when submitting)',
              );
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error picking photo: $e');
      if (mounted) {
        _snackbarManager.showErrorMessage(
          context,
          message: 'Error picking photo: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _removePhoto(int index) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Photo'),
        content: const Text('Remove this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      setState(() {
        _localPhotoFiles.removeAt(index);
      });
    }
  }

  Future<void> _clearAllPhotos() async {
    if (_localPhotoFiles.isEmpty) return;

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Photos'),
        content: Text('Remove all ${_localPhotoFiles.length} photos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (shouldClear == true && mounted) {
      setState(() {
        _localPhotoFiles.clear();
      });
    }
  }

  Future<void> _submitReport() async {
    // Validate description
    if (_descriptionController.text.trim().isEmpty) {
      _snackbarManager.showWarningMessage(
        context, 
        message: 'Please provide a description of the issue'
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create local report with File paths (not uploaded to Supabase yet)
      Map<String, dynamic> localReport = {
        'id': 'LOCAL-${DateTime.now().millisecondsSinceEpoch}',
        'poId': widget.poId,
        'lineItemId': widget.lineItemId,
        'productId': widget.productId,
        'productName': widget.productName,
        'discrepancyType': 'physicalDamage',
        'quantityAffected': 1,
        'description': _descriptionController.text.trim(),
        'localPhotoFiles': _localPhotoFiles, // Store File objects locally
        'photos': [], // Will be filled with Supabase URLs at final submission
        'reportedBy': 'EMP0001',
        'reportedByName': 'kskppp jsjss',
        'status': 'local',
        'createdAt': DateTime.now(),
      };

      if (mounted) {
        Navigator.of(context).pop(localReport);
        _snackbarManager.showValidationMessage(
          context,
          message: 'Report saved locally (photos will upload at final step)',
          backgroundColor: Colors.blue,
        );
      }
    } catch (e) {
      print('❌ Error creating report: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _snackbarManager.showErrorMessage(
          context,
          message: 'Error: ${e.toString()}'
        );
      }
    }
  }

  Widget _buildPhotoThumbnail(File photoFile, int index) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              photoFile,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: Colors.red[400], size: 20),
                      const SizedBox(height: 4),
                      Text(
                        'Error',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red[600],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removePhoto(index),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.red[600],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Report Discrepancy',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.productName} (ID: ${widget.productId})',
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
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description field
                    Text(
                      'Describe the issue:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Describe the damage or issue with this item...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.orange[400]!),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Photo section header
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _pickPhoto,
                            icon: const Icon(Icons.add_a_photo, size: 18),
                            label: const Text('Add Photo'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green[600],
                              side: BorderSide(color: Colors.green[300]!),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (_localPhotoFiles.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _clearAllPhotos,
                            label: const Text('Clear All'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red[600],
                              side: BorderSide(color: Colors.red[300]!),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    Text(
                      'Add photos to document the discrepancy (optional)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    
                    // Photo thumbnails preview
                    if (_localPhotoFiles.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 14, color: Colors.blue[700]),
                                const SizedBox(width: 4),
                                Text(
                                  'Photos will be uploaded when finalizing',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _localPhotoFiles.asMap().entries.map((entry) {
                                final index = entry.key;
                                final photoFile = entry.value;
                                return _buildPhotoThumbnail(photoFile, index);
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_localPhotoFiles.length}/5 photos',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[600],
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Save Locally'),
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
}