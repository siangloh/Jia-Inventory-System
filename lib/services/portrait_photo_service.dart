import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_image.dart';

class PortraitPhotoService {
  static final ImagePicker _picker = ImagePicker();

  /// Show photo source selection dialog (Camera or Gallery)
  static Future<UserImageModel?> showPhotoSourceSelection(
      BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Photo Source'),
          backgroundColor: Colors.white,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                subtitle: const Text('Take a new photo'),
                onTap: () => Navigator.of(context).pop('camera'),
              ),
              const SizedBox(
                height: 10.0,
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                subtitle: const Text('Choose from gallery'),
                onTap: () => Navigator.of(context).pop('gallery'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (result == null) return null;

    if (result == 'camera') {
      return await _takePhotoWithCamera(context);
    } else if (result == 'gallery') {
      return await _pickFromGallery(context);
    }

    return null;
  }

  /// Take photo using custom camera screen or system camera
  static Future<UserImageModel?> _takePhotoWithCamera(
      BuildContext context) async {
    try {
      // Fallback to system camera
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
        preferredCameraDevice:
            CameraDevice.front, // Use front camera for profile photos
      );

      if (image != null) {
        final file = File(image.path);
        print('System camera result: ${image.path}');
        print('File size: ${await file.length()} bytes');

        return UserImageModel(
          imageFile: file,
          imagePath: image.path,
          userID: '',
        );
      }
    } catch (e) {
      print('Error taking photo: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    return null;
  }

  /// Pick photo from gallery
  static Future<UserImageModel?> _pickFromGallery(BuildContext context) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        print('Gallery selection result: ${image.path}');
        print('File size: ${await file.length()} bytes');

        return UserImageModel(
          imageFile: file,
          imagePath: image.path,
          userID: '',
        );
      }
    } catch (e) {
      print('Error picking from gallery: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    return null;
  }

  /// Quick camera access (bypasses dialog)
  static Future<UserImageModel?> takePhotoDirectly() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );

      if (image != null) {
        final file = File(image.path);
        return UserImageModel(
          imageFile: file,
          imagePath: image.path,
          userID: '',
        );
      }
    } catch (e) {
      print('Error taking photo directly: $e');
    }
    return null;
  }

  /// Quick gallery access (bypasses dialog)
  static Future<UserImageModel?> pickFromGalleryDirectly() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        return UserImageModel(
          imageFile: file,
          imagePath: image.path,
          userID: '',
        );
      }
    } catch (e) {
      print('Error picking from gallery directly: $e');
    }
    return null;
  }
}
