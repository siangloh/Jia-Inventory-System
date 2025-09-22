import 'dart:io';

class ReceiveStockPhotoData {
  final File imageFile;
  final String fileName;
  final DateTime capturedAt;

  ReceiveStockPhotoData({
    required this.imageFile,
    required this.fileName,
    required this.capturedAt,
  });

  String get filePath => imageFile.path;

  Future<int> get fileSize async {
    try {
      return await imageFile.length();
    } catch (e) {
      return 0;
    }
  }

  Future<bool> get exists async {
    return await imageFile.exists();
  }

  Future<bool> delete() async {
    try {
      if (await imageFile.exists()) {
        await imageFile.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
