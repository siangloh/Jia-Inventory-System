import 'dart:convert';
import 'dart:io';

class UserImageModel {
  final int? id;
  final String userID;
  final File imageFile;
  final String imagePath;
  final DateTime? createAt;
  final DateTime? updateAt;

  factory UserImageModel.fromJson(Map<String, dynamic> data) => UserImageModel(
        id: data['id'],
        userID: data['userID'],
        imageFile: data['imageFile'],
        imagePath: data['imagePath'],
        createAt: data['createAt'],
        updateAt: data['updateAt'],
      );

  UserImageModel({
    this.id,
    required this.userID,
    required this.imageFile,
    required this.imagePath,
    DateTime? createAt,
    this.updateAt,
  }) : createAt = createAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'userID': userID,
        'imageFile': imageFile,
        'imagePath': imagePath,
        'createAt': createAt!.toIso8601String(),
        'updateAt': updateAt?.toIso8601String(),
      };

  /// Check if file exists
  Future<bool> exists() async {
    return await imageFile.exists();
  }

  /// Get file size
  Future<int> getSize() async {
    if (await exists()) {
      return await imageFile.length();
    }
    return 0;
  }

  @override
  String toString() {
    return 'UserImageModel(id: $id, path: $imagePath, created: $createAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserImageModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
