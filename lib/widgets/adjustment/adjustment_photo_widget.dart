import 'package:flutter/material.dart';
import '../../services/adjustment/adjustment_photo_service.dart';

class AdjustmentPhotoWidget extends StatefulWidget {
  final String workflowType;
  final String workflowId;
  final List<String> photoFileNames; // Supabase storage filenames
  final Function(List<String>) onPhotosChanged;
  final int maxPhotos;
  final String? hintText;

  const AdjustmentPhotoWidget({
    Key? key,
    required this.workflowType,
    required this.workflowId,
    required this.photoFileNames,
    required this.onPhotosChanged,
    this.maxPhotos = 5,
    this.hintText,
  }) : super(key: key);

  @override
  State<AdjustmentPhotoWidget> createState() => _AdjustmentPhotoWidgetState();
}

class _AdjustmentPhotoWidgetState extends State<AdjustmentPhotoWidget> {
  bool _isLoading = false;

  Future<void> _pickPhoto() async {
    if (_isLoading) return;
    
    // Check max photos limit
    if (widget.photoFileNames.length >= widget.maxPhotos) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maximum ${widget.maxPhotos} photos allowed'),
            backgroundColor: Colors.orange[600],
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final imageFile = await AdjustmentPhotoService.showPhotoSourceSelection(context);
      
      if (imageFile != null && await imageFile.exists()) {
        
        // Show uploading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uploading photo...'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
        
        // Upload to Supabase
        final fileName = await AdjustmentPhotoService.uploadPhoto(
          imageFile: imageFile,
          workflowType: widget.workflowType,
          workflowId: widget.workflowId,
        );

        if (fileName != null && fileName.isNotEmpty) {
          final newPhotos = List<String>.from(widget.photoFileNames);
          newPhotos.add(fileName);
          widget.onPhotosChanged(newPhotos);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Photo added successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to upload photo. Please try again.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No photo selected'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removePhoto(int index) async {
    final fileName = widget.photoFileNames[index];
    
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Photo'),
        content: const Text('Are you sure you want to remove this photo?'),
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

    if (shouldDelete == true) {
      // Delete from Supabase
      final success = await AdjustmentPhotoService.deletePhoto(fileName);
      
      if (success) {
        final newPhotos = List<String>.from(widget.photoFileNames);
        newPhotos.removeAt(index);
        widget.onPhotosChanged(newPhotos);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to remove photo'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _clearAllPhotos() async {
    if (widget.photoFileNames.isEmpty) return;

    // Show confirmation dialog
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Photos'),
        content: Text('Are you sure you want to remove all ${widget.photoFileNames.length} photos?'),
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

    if (shouldClear == true) {
      // Delete all from Supabase
      final success = await AdjustmentPhotoService.deleteMultiplePhotos(widget.photoFileNames);
      
      if (success) {
        widget.onPhotosChanged([]);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to clear photos'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildPhotoThumbnail(String fileName, int index) {
    return FutureBuilder<String?>(
      key: ValueKey('photo_$fileName'),
      future: AdjustmentPhotoService.getSignedUrl(fileName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[200],
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.red[50],
              border: Border.all(color: Colors.red[300]!),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red[400], size: 20),
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
        }

        final imageUrl = snapshot.data;
        
        
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
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
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
                                Icon(Icons.broken_image, color: Colors.red[400], size: 20),
                                const SizedBox(height: 4),
                                Text(
                                  'Failed',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_not_supported, color: Colors.grey[400], size: 20),
                            const SizedBox(height: 4),
                            Text(
                              'No URL',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _pickPhoto,
                icon: _isLoading 
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_a_photo, size: 18),
                label: Text(_isLoading ? 'Uploading...' : 'Add Photo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green[600],
                  side: BorderSide(color: Colors.green[300]!),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (widget.photoFileNames.isNotEmpty)
              OutlinedButton.icon(
                onPressed: _clearAllPhotos,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear All'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[600],
                  side: BorderSide(color: Colors.red[300]!),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
          ],
        ),

        // Hint text
        if (widget.hintText != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.hintText!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],

        // Photo thumbnails
        if (widget.photoFileNames.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.photoFileNames.asMap().entries.map((entry) {
              final index = entry.key;
              final fileName = entry.value;
              return _buildPhotoThumbnail(fileName, index);
            }).toList(),
          ),
        ],

        // Photo count info
        if (widget.photoFileNames.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${widget.photoFileNames.length}/${widget.maxPhotos} photos',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }
}
