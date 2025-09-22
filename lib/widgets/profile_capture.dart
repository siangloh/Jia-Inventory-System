import 'dart:io';

import 'package:assignment/models/user_image.dart';
import 'package:assignment/services/login/load_user_data.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../services/firebase_auth_service.dart';
import '../services/portrait_photo_service.dart';

class ProfilePhotoWidget extends StatefulWidget {
  final String userId;
  final UserImageModel? photo;
  final ValueChanged<UserImageModel?> onPhotoChanged;

  const ProfilePhotoWidget({
    super.key,
    required this.userId,
    required this.photo,
    required this.onPhotoChanged,
  });

  @override
  State<ProfilePhotoWidget> createState() => _ProfilePhotoWidgetState();
}

class _ProfilePhotoWidgetState extends State<ProfilePhotoWidget> {
  bool _isLoading = false;

  Future<String?> _getSignedUrl(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return null;

    try {
      return await Supabase.instance.client.storage
          .from('profile_photos')
          .createSignedUrl(filePath, 3600);
    } catch (e) {
      print("Error generating signed URL: $e");
      return null;
    }
  }

  Widget _buildProfileImage(String? imageUrl) {
    return CircleAvatar(
      radius: 50,
      backgroundColor: Colors.grey[300],
      backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
          ? NetworkImage(imageUrl)
          : null,
      child: (imageUrl == null || imageUrl.isEmpty)
          ? const Icon(Icons.person, size: 50, color: Colors.white)
          : null,
    );
  }

  Future<void> _pickPhoto() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final newPhoto =
          await PortraitPhotoService.showPhotoSourceSelection(context);

      if (newPhoto != null) {
        final file = File(newPhoto.imagePath);
        widget.onPhotoChanged(newPhoto);

        final imageUrl = await userDao.updateUserImg(file);

        if (imageUrl != null) {
          // ✅ Update Firestore `profilePhotoUrl` with new filename
          // Firestore listener (stream) will auto rebuild UI
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Error picking photo: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: getUserStream(widget.userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, size: 50, color: Colors.white),
          );
        }

        final user = snapshot.data!;

        return FutureBuilder<String?>(
          future: _getSignedUrl(user.profilePhotoUrl), // 🔥 get signed URL
          builder: (context, imgSnapshot) {
            final signedUrl = imgSnapshot.data;

            return Stack(
              children: [
                _buildProfileImage(signedUrl),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _isLoading ? null : _pickPhoto,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[600],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.edit,
                              size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
