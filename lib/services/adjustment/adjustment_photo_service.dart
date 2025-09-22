import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class AdjustmentPhotoService {
  static const String _bucketName = 'discrepancy-photos';
  static const int _signedUrlExpiry = 3600; // 1 hour

  /// Upload a photo to Supabase Storage
  static Future<String?> uploadPhoto({
    required File imageFile,
    required String workflowType,
    required String workflowId,
  }) async {
    try {
      // Validate file before upload
      if (!await imageFile.exists()) {
        print('❌ Image file does not exist: ${imageFile.path}');
        return null;
      }

      final fileSize = await imageFile.length();
      if (fileSize == 0) {
        print('❌ Image file is empty: ${imageFile.path}');
        return null;
      }

      // Check file size limit (10MB)
      const maxFileSize = 10 * 1024 * 1024; // 10MB
      if (fileSize > maxFileSize) {
        print('❌ Image file too large: ${fileSize} bytes (max: ${maxFileSize} bytes)');
        return null;
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last.toLowerCase();
      
      // Validate file extension
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
      if (!allowedExtensions.contains(extension)) {
        print('❌ Invalid file extension: $extension');
        return null;
      }

      // Generate shorter filename like DISC-{timestamp}_photo{index}.jpg
      final fileName = 'DISC-${timestamp}_photo${DateTime.now().microsecond}.$extension';

      print('📤 Uploading photo: $fileName (${fileSize} bytes) to bucket: $_bucketName');

      // Upload to Supabase Storage
      await Supabase.instance.client.storage
          .from(_bucketName)
          .upload(fileName, imageFile, fileOptions: const FileOptions(upsert: true));

      print('✅ Photo uploaded successfully: $fileName to bucket: $_bucketName');
      return fileName; // Return only the filename, not full URL
    } catch (e) {
      print('❌ Error uploading photo: $e');
      return null;
    }
  }

  /// Get signed URL for displaying photo
  static Future<String?> getSignedUrl(String fileName) async {
    if (fileName.isEmpty) {
      print('❌ Empty fileName provided to getSignedUrl');
      return null;
    }

    try {
      print('🔗 Generating signed URL for: $fileName');
      final signedUrl = await Supabase.instance.client.storage
          .from(_bucketName)
          .createSignedUrl(fileName, _signedUrlExpiry);
      
      if (signedUrl.isNotEmpty) {
        print('✅ Signed URL generated successfully for: $fileName');
        return signedUrl;
      } else {
        print('❌ Empty signed URL returned for: $fileName');
        return null;
      }
    } catch (e) {
      print("❌ Error generating signed URL for $fileName: $e");
      return null;
    }
  }

  /// Delete photo from Supabase Storage
  static Future<bool> deletePhoto(String fileName) async {
    try {
      await Supabase.instance.client.storage
          .from(_bucketName)
          .remove([fileName]);
      
      print('✅ Photo deleted successfully: $fileName');
      return true;
    } catch (e) {
      print('❌ Error deleting photo $fileName: $e');
      return false;
    }
  }

  /// Pick image from camera or gallery
  static Future<File?> pickImage({
    required BuildContext context,
    ImageSource source = ImageSource.camera,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: maxWidth ?? 1024,
        maxHeight: maxHeight ?? 1024,
        imageQuality: imageQuality ?? 80,
      );

      if (image != null) {
        final file = File(image.path);
        
        // Validate file exists and has content
        if (await file.exists()) {
          final fileSize = await file.length();
          if (fileSize > 0) {
            print('✅ Image picked successfully: ${image.path} (${fileSize} bytes)');
            return file;
          } else {
            print('❌ Image file is empty: ${image.path}');
            return null;
          }
        } else {
          print('❌ Image file does not exist: ${image.path}');
          return null;
        }
      }
      return null;
    } catch (e) {
      print('❌ Error picking image: $e');
      return null;
    }
  }

  /// Show photo source selection dialog - FIXED
  static Future<File?> showPhotoSourceSelection(BuildContext context) async {
    return await showModalBottomSheet<File?>(
      context: context,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () async {
                  Navigator.of(bottomSheetContext).pop(); // Close bottom sheet first
                  try {
                    final file = await pickImage(
                      context: context,
                      source: ImageSource.camera,
                    );
                    if (file != null && await file.exists()) {
                      Navigator.of(context).pop(file); // Return the file
                    } else {
                      Navigator.of(context).pop(null);
                    }
                  } catch (e) {
                    print('❌ Error taking photo: $e');
                    Navigator.of(context).pop(null);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.of(bottomSheetContext).pop(); // Close bottom sheet first
                  try {
                    final file = await pickImage(
                      context: context,
                      source: ImageSource.gallery,
                    );
                    if (file != null && await file.exists()) {
                      Navigator.of(context).pop(file); // Return the file
                    } else {
                      Navigator.of(context).pop(null);
                    }
                  } catch (e) {
                    print('❌ Error picking from gallery: $e');
                    Navigator.of(context).pop(null);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(bottomSheetContext).pop(null),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Convert File to Uint8List (for temporary storage)
  static Future<Uint8List?> fileToBytes(File file) async {
    try {
      return await file.readAsBytes();
    } catch (e) {
      print('❌ Error converting file to bytes: $e');
      return null;
    }
  }

  /// Create temporary file from bytes
  static Future<File?> bytesToFile(Uint8List bytes, String fileName) async {
    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);
      return tempFile;
    } catch (e) {
      print('❌ Error creating temp file from bytes: $e');
      return null;
    }
  }

  /// Batch upload multiple photos
  static Future<List<String>> uploadMultiplePhotos({
    required List<File> imageFiles,
    required String workflowType,
    required String workflowId,
  }) async {
    final List<String> uploadedFileNames = [];
    
    for (final imageFile in imageFiles) {
      final fileName = await uploadPhoto(
        imageFile: imageFile,
        workflowType: workflowType,
        workflowId: workflowId,
      );
      
      if (fileName != null) {
        uploadedFileNames.add(fileName);
      }
    }
    
    return uploadedFileNames;
  }

  /// Batch delete multiple photos
  static Future<bool> deleteMultiplePhotos(List<String> fileNames) async {
    if (fileNames.isEmpty) return true;
    
    try {
      await Supabase.instance.client.storage
          .from(_bucketName)
          .remove(fileNames);
      
      print('✅ ${fileNames.length} photos deleted successfully');
      return true;
    } catch (e) {
      print('❌ Error deleting multiple photos: $e');
      return false;
    }
  }
}