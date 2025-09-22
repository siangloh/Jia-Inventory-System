import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/receive_stock_photo_data.dart';

class ReceiveStockImageService {
  static final ImagePicker _picker = ImagePicker();

  // Show photo source selection (camera or gallery)
  static Future<ReceiveStockPhotoData?> showPhotoSourceSelection(BuildContext context) async {
    return showModalBottomSheet<ReceiveStockPhotoData?>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Photo Source',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPhotoOption(
                  context,
                  Icons.camera_alt,
                  'Camera',
                  () async {
                    Navigator.pop(context, await getImageFromCamera());
                  },
                ),
                _buildPhotoOption(
                  context,
                  Icons.photo_library,
                  'Gallery',
                  () async {
                    Navigator.pop(context, await getImageFromGallery());
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildPhotoOption(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(icon, size: 40, color: Colors.blue[600]),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  // Get image from camera
  static Future<ReceiveStockPhotoData?> getImageFromCamera() async {
    try {
      final XFile? pickerFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (pickerFile != null) {
        return await _saveImageToAppFolder(File(pickerFile.path));
      }
    } catch (e) {
      print('Error getting image from camera: $e');
    }
    return null;
  }

  // Get image from gallery
  static Future<ReceiveStockPhotoData?> getImageFromGallery() async {
    try {
      final XFile? pickerFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (pickerFile != null) {
        return await _saveImageToAppFolder(File(pickerFile.path));
      }
    } catch (e) {
      print('Error getting image from gallery: $e');
    }
    return null;
  }

  // Save image to app folder (like in your example)
  static Future<ReceiveStockPhotoData?> _saveImageToAppFolder(File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        return null;
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      final String receiveStockPhotoDir = '${appDocDir.path}/receive_stock_photos';
      final Directory photoDir = Directory(receiveStockPhotoDir);
      
      if (!await photoDir.exists()) {
        await photoDir.create(recursive: true);
      }

      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String extension = imageFile.path.split('.').last;
      final String newFileName = 'receive_stock_$timestamp.$extension';
      final String newImagePath = '$receiveStockPhotoDir/$newFileName';
      
      final File newFile = await imageFile.copy(newImagePath);
      
      if (await newFile.exists()) {
        print('✅ Photo saved successfully: $newImagePath');
        return ReceiveStockPhotoData(
          imageFile: newFile,
          fileName: newFileName,
          capturedAt: DateTime.now(),
        );
      }
    } catch (e) {
      print('❌ Error saving photo: $e');
    }
    return null;
  }

  // Delete photo
  static Future<bool> deletePhoto(ReceiveStockPhotoData photo) async {
    try {
      return await photo.delete();
    } catch (e) {
      print('❌ Error deleting photo: $e');
      return false;
    }
  }

  // Load existing photos from app folder
  static Future<List<ReceiveStockPhotoData>> loadExistingPhotos() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final String receiveStockPhotoDir = '${appDocDir.path}/receive_stock_photos';
      final Directory photoDir = Directory(receiveStockPhotoDir);
      
      if (!await photoDir.exists()) {
        return [];
      }

      final List<FileSystemEntity> files = await photoDir.list().toList();
      final List<ReceiveStockPhotoData> photos = [];

      for (final file in files) {
        if (file is File && _isImageFile(file.path)) {
          photos.add(ReceiveStockPhotoData(
            imageFile: file,
            fileName: file.path.split('/').last,
            capturedAt: DateTime.now(), // We don't store creation time, so use current time
          ));
        }
      }

      return photos;
    } catch (e) {
      print('❌ Error loading existing photos: $e');
      return [];
    }
  }

  // Check if file is an image
  static bool _isImageFile(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }
}
