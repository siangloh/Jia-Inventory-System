// lib/widgets/qr/qr_generator_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';

class QRGeneratorDialog extends StatefulWidget {
  final String productId;
  final String productName;
  final String category;
  final int quantity;

  const QRGeneratorDialog({
    super.key,
    required this.productId,
    required this.productName,
    required this.category,
    required this.quantity,
  });

  @override
  State<QRGeneratorDialog> createState() => _QRGeneratorDialogState();
}

class _QRGeneratorDialogState extends State<QRGeneratorDialog> {
  String qrDataType = 'product';
  final GlobalKey _qrKey = GlobalKey();
  bool isSaving = false;

  // Generate QR data based on selected type
  String get qrData {
    return 'WAREHOUSE_PRODUCT:${widget.productId}';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final maxHeight = screenSize.height * 0.9; // Maximum 90% of screen height
    final maxWidth = screenSize.width * 0.9; // Maximum 90% of screen width
    final dialogWidth = maxWidth > 400 ? 400.0 : maxWidth; // Cap at 400 or screen width

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
          maxWidth: dialogWidth,
          minWidth: 300, // Minimum width
        ),
        child: Container(
          width: dialogWidth,
          padding: const EdgeInsets.all(16), // Reduced padding for smaller screens
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 12),

              // Scrollable content area
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Product info card
                      _buildProductInfoCard(),
                      const SizedBox(height: 16),

                      // QR Code display
                      _buildQRCodeDisplay(),
                      const SizedBox(height: 12),

                      // QR Data display
                      _buildQRDataDisplay(),
                      const SizedBox(height: 16),

                      // Action buttons
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.qr_code, color: Colors.blue[600], size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Product QR Code',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, size: 18),
          constraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
          padding: const EdgeInsets.all(4),
        ),
      ],
    );
  }

  Widget _buildProductInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.productName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'ID: ${widget.productId}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Text(
                  'Qty: ${widget.quantity}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQRTypeSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'QR Code Type:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 6),
          // Use SingleChildScrollView for horizontal scrolling if needed
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQRTypeChip('product', 'In-App', Icons.smartphone),
                const SizedBox(width: 6),
                _buildQRTypeChip('deeplink', 'Deep Link', Icons.link),
                const SizedBox(width: 6),
                _buildQRTypeChip('web', 'Web URL', Icons.language),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodeDisplay() {
    final screenWidth = MediaQuery.of(context).size.width;
    final qrSize = (screenWidth * 0.4).clamp(150.0, 180.0); // Responsive QR size

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: RepaintBoundary(
        key: _qrKey,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: qrSize,
                  maxHeight: qrSize,
                ),
                child: BarcodeWidget(
                  barcode: Barcode.qrCode(),
                  data: qrData,
                  width: qrSize,
                  height: qrSize,
                  backgroundColor: Colors.white,
                  color: Colors.black,
                  errorBuilder: (context, error) => Container(
                    width: qrSize,
                    height: qrSize,
                    color: Colors.grey[100],
                    child: Center(
                      child: Text(
                        "Error generating QR code",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Product info below QR for saved image
              Text(
                widget.productName,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'ID: ${widget.productId} | Qty: ${widget.quantity}',
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQRDataDisplay() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 60), // Limit height
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        child: Text(
          qrData,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey[600],
            fontFamily: 'monospace',
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (isSaving) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.blue[600]),
            const SizedBox(height: 8),
            Text(
              'Saving QR Code...',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Only show save options - Gallery and App Folder
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saveToGallery,
                icon: const Icon(Icons.photo_library, size: 16),
                label: const Text(
                  'Save to Gallery',
                  style: TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(0, 42),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saveToAppFolder,
                icon: const Icon(Icons.folder, size: 16),
                label: const Text(
                  'Save to App',
                  style: TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(0, 42),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQRTypeChip(String value, String label, IconData icon) {
    final isSelected = qrDataType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          qrDataType = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[600] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue[600]! : Colors.blue[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 10,
              color: isSelected ? Colors.white : Colors.blue[600],
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: isSelected ? Colors.white : Colors.blue[600],
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _copyQRData() {
    Clipboard.setData(ClipboardData(text: qrData));
    _showSnackBar('QR data copied to clipboard', Icons.copy, Colors.blue);
  }

  void _shareQRData() {
    final text = '''
Product: ${widget.productName}
ID: ${widget.productId}
Category: ${widget.category}
Quantity: ${widget.quantity}

QR Data: $qrData

Scan this QR code with the warehouse app to view product details.
    ''';

    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('Product info copied to clipboard - you can paste to share', Icons.share, Colors.green);
  }

  // Save QR code image to device gallery
  Future<void> _saveToGallery() async {
    setState(() {
      isSaving = true;
    });

    try {
      // Check and request appropriate permissions based on Android version
      bool hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        _showSnackBar('Storage permission denied', Icons.error, Colors.red);
        return;
      }

      // Capture QR code as image
      final imageBytes = await _captureQRImage();
      if (imageBytes == null) {
        _showSnackBar('Failed to capture QR code', Icons.error, Colors.red);
        return;
      }

      // Save to gallery
      final result = await ImageGallerySaverPlus.saveImage(
        imageBytes,
        name: 'QR_${widget.productId}_${DateTime.now().millisecondsSinceEpoch}',
        quality: 100,
      );

      if (result['isSuccess'] == true) {
        _showSnackBar('QR code saved to gallery', Icons.check_circle, Colors.green);
      } else {
        _showSnackBar('Failed to save to gallery', Icons.error, Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error saving to gallery: $e', Icons.error, Colors.red);
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  // Request storage permission based on Android version
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      try {
        // Try to use photos permission first (Android 13+)
        final photosPermission = await Permission.photos.request();
        if (photosPermission == PermissionStatus.granted) {
          return true;
        }

        // Fallback to storage permission (Android 12 and below)
        final storagePermission = await Permission.storage.request();
        return storagePermission == PermissionStatus.granted;

      } catch (e) {
        // If photos permission not available, try storage permission
        try {
          final storagePermission = await Permission.storage.request();
          return storagePermission == PermissionStatus.granted;
        } catch (e2) {
          print('Permission request failed: $e2');
          return false;
        }
      }
    } else if (Platform.isIOS) {
      try {
        final photosPermission = await Permission.photos.request();
        return photosPermission == PermissionStatus.granted;
      } catch (e) {
        print('iOS photos permission failed: $e');
        return false;
      }
    }

    return false;
  }

  // Save QR code to app's local folder
  Future<void> _saveToAppFolder() async {
    setState(() {
      isSaving = true;
    });

    try {
      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final qrFolder = Directory('${directory.path}/qr_codes');

      // Create folder if it doesn't exist
      if (!await qrFolder.exists()) {
        await qrFolder.create(recursive: true);
      }

      // Capture QR code as image
      final imageBytes = await _captureQRImage();
      if (imageBytes == null) {
        _showSnackBar('Failed to capture QR code', Icons.error, Colors.red);
        return;
      }

      // Create filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'QR_${widget.productId}_$timestamp.png';
      final file = File('${qrFolder.path}/$filename');

      // Write image to file
      await file.writeAsBytes(imageBytes);

      _showSnackBar('QR code saved to app folder: $filename', Icons.folder, Colors.blue);
    } catch (e) {
      _showSnackBar('Error saving to app folder: $e', Icons.error, Colors.red);
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  // Capture QR code widget as image
  Future<Uint8List?> _captureQRImage() async {
    try {
      final RenderRepaintBoundary boundary =
      _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error capturing QR image: $e');
      return null;
    }
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}