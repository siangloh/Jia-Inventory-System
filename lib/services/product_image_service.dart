
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductImageService {
  static final ImagePicker _imagePicker = ImagePicker();
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Shows a dialog to select photo source (Camera or Gallery)
  static Future<XFile?> showPhotoSourceSelection(BuildContext context) async {
    return showDialog<XFile?>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Select Photo Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Camera'),
                onTap: () async {
                  // Close dialog first, then pick image
                  Navigator.of(dialogContext).pop();

                  try {
                    final XFile? photo = await _imagePicker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 80,
                    );

                    // Use the original context's navigator to pop with result
                    if (context.mounted) {
                      Navigator.of(context).pop(photo);
                    }
                  } catch (e) {
                    print('Error picking image from camera: $e');
                    if (context.mounted) {
                      Navigator.of(context).pop(null);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error accessing camera: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('Gallery'),
                onTap: () async {
                  // Close dialog first, then pick image
                  Navigator.of(dialogContext).pop();

                  try {
                    final XFile? photo = await _imagePicker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 80,
                    );

                    // Use the original context's navigator to pop with result
                    if (context.mounted) {
                      Navigator.of(context).pop(photo);
                    }
                  } catch (e) {
                    print('Error picking image from gallery: $e');
                    if (context.mounted) {
                      Navigator.of(context).pop(null);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error accessing gallery: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// Alternative approach - returns the source selection instead of the file
  static Future<ImageSource?> selectPhotoSource(BuildContext context) async {
    return showDialog<ImageSource?>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Select Photo Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Camera'),
                onTap: () =>
                    Navigator.of(dialogContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('Gallery'),
                onTap: () =>
                    Navigator.of(dialogContext).pop(ImageSource.gallery),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// Pick image from selected source
  static Future<XFile?> pickImageFromSource(ImageSource source) async {
    try {
      return await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
      );
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  /// Upload product image to Supabase storage
  static Future<String?> uploadProductImage(XFile imageFile) async {
    try {
      final String fileName =
          'product_${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';
      final File file = File(imageFile.path);

      await _supabase.storage.from('product_images').upload(fileName, file);

      return fileName;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  /// Get signed URL for product image
  static Future<String?> getProductImageSignedUrl(String fileName) async {
    try {
      final signedUrl = await _supabase.storage
          .from('product_images')
          .createSignedUrl(fileName, 3600); // 1 hour expiry

      return signedUrl;
    } catch (e) {
      print('Error getting signed URL: $e');
      return null;
    }
  }

  /// Delete product image from Supabase storage
  static Future<bool> deleteProductImage(String fileName) async {
    try {
      await _supabase.storage.from('product_images').remove([fileName]);

      return true;
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }
}
