import 'package:flutter/material.dart';
import '../models/receive_stock_photo_data.dart';
import '../services/receive_stock_image_service.dart';

class ReceiveStockPhotoWidget extends StatefulWidget {
  final List<ReceiveStockPhotoData> photos;
  final ValueChanged<List<ReceiveStockPhotoData>> onPhotosChanged;
  final int maxPhotos;

  const ReceiveStockPhotoWidget({
    Key? key,
    required this.photos,
    required this.onPhotosChanged,
    this.maxPhotos = 5,
  }) : super(key: key);

  @override
  State<ReceiveStockPhotoWidget> createState() => _ReceiveStockPhotoWidgetState();
}

class _ReceiveStockPhotoWidgetState extends State<ReceiveStockPhotoWidget> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Removed automatic photo loading to prevent persistence issues
    // Photos are now managed entirely by the parent screen
  }

  // Removed automatic loading of existing photos to prevent persistence issues
  // Photos are now managed entirely by the parent screen
  // Future<void> _loadExistingPhotos() async {
  //   if (widget.photos.isEmpty) {
  //     final existingPhotos = await ReceiveStockImageService.loadExistingPhotos();
  //     if (existingPhotos.isNotEmpty) {
  //       widget.onPhotosChanged(existingPhotos);
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photo Documentation (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        
        // Photo grid
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[50],
          ),
          child: Column(
            children: [
              // Photo count
              if (widget.photos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${widget.photos.length} photo${widget.photos.length == 1 ? '' : 's'} added',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              
              // Photo grid
              if (widget.photos.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: widget.photos.length,
                  itemBuilder: (context, index) {
                    return _buildPhotoItem(widget.photos[index], index);
                  },
                ),
              
              // Add photo button
              if (widget.photos.length < widget.maxPhotos)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 12),
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _addPhoto,
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_a_photo),
                    label: Text(_isLoading ? 'Adding...' : 'Add Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              
              // Instructional text
              const SizedBox(height: 12),
              Text(
                'Add photos of delivery slips, parts, or packaging for record keeping.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoItem(ReceiveStockPhotoData photo, int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Stack(
        children: [
          // Photo thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: GestureDetector(
              onTap: () => _showPhotoDetails(photo),
              child: Image.file(
                photo.imageFile,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.red[100],
                    child: const Icon(
                      Icons.error,
                      color: Colors.red,
                      size: 24,
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Delete button
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => _deletePhoto(index),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addPhoto() async {
    if (_isLoading || widget.photos.length >= widget.maxPhotos) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final ReceiveStockPhotoData? newPhoto = 
          await ReceiveStockImageService.showPhotoSourceSelection(context);
      
      if (newPhoto != null) {
        final List<ReceiveStockPhotoData> updatedPhotos = [...widget.photos, newPhoto];
        widget.onPhotosChanged(updatedPhotos);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add photo: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _deletePhoto(int index) {
    final photo = widget.photos[index];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(index);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(int index) async {
    try {
      final photo = widget.photos[index];
      await ReceiveStockImageService.deletePhoto(photo);
      
      final List<ReceiveStockPhotoData> updatedPhotos = List.from(widget.photos);
      updatedPhotos.removeAt(index);
      widget.onPhotosChanged(updatedPhotos);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete photo: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPhotoDetails(ReceiveStockPhotoData photo) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Photo
            Flexible(
              child: Image.file(
                photo.imageFile,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.red[100],
                    child: const Icon(
                      Icons.error,
                      color: Colors.red,
                      size: 64,
                    ),
                  );
                },
              ),
            ),
            
            // Close button
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
