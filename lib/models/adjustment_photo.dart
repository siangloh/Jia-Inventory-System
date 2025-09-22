import 'dart:io';

class AdjustmentPhotoModel {
  final int? id;
  final String workflowType; // 'discrepancy', 'receive_stock', 'return_stock'
  final String workflowId; // ID of the specific workflow instance
  final File imageFile;
  final String imagePath; // Supabase storage path
  final String fileName;
  final DateTime? createAt;
  final DateTime? updateAt;

  factory AdjustmentPhotoModel.fromJson(Map<String, dynamic> data) => AdjustmentPhotoModel(
        id: data['id'],
        workflowType: data['workflowType'],
        workflowId: data['workflowId'],
        imageFile: data['imageFile'],
        imagePath: data['imagePath'],
        fileName: data['fileName'],
        createAt: data['createAt'],
        updateAt: data['updateAt'],
      );

  AdjustmentPhotoModel({
    this.id,
    required this.workflowType,
    required this.workflowId,
    required this.imageFile,
    required this.imagePath,
    required this.fileName,
    DateTime? createAt,
    this.updateAt,
  }) : createAt = createAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'workflowType': workflowType,
        'workflowId': workflowId,
        'imageFile': imageFile,
        'imagePath': imagePath,
        'fileName': fileName,
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
    return 'AdjustmentPhotoModel(id: $id, workflowType: $workflowType, fileName: $fileName, created: $createAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdjustmentPhotoModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
