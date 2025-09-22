// lib/widgets/qr/qr_scanner_dialog.dart
import 'package:assignment/screens/product/product_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:assignment/screens/warehouse/stored_product_detail_screen.dart';
import 'dart:io';

class QRScannerDialog extends StatefulWidget {
  final bool productDetails; // make it final

  const QRScannerDialog({
    super.key,
    this.productDetails = false,
  });

  @override
  State<QRScannerDialog> createState() => _QRScannerDialogState();
}

class _QRScannerDialogState extends State<QRScannerDialog>
    with WidgetsBindingObserver {
  MobileScannerController? cameraController;
  bool isProcessing = false;
  bool isFlashOn = false;
  bool isCameraInitialized = false;
  bool isInitializing = false; // NEW: Prevent multiple initializations
  String? lastScannedCode;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _disposeCamera();
        break;
      case AppLifecycleState.resumed:
      // Only reinitialize if not already initialized
        if (!isCameraInitialized && !isInitializing) {
          _initializeCamera();
        }
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _initializeCamera() async {
    // Prevent multiple simultaneous initializations
    if (isInitializing || isCameraInitialized) {
      return;
    }

    setState(() {
      isInitializing = true;
    });

    try {
      // Dispose existing controller first
      await _disposeCamera();

      // Create new controller
      cameraController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
      );

      // Start camera
      await cameraController!.start();

      if (mounted) {
        setState(() {
          isCameraInitialized = true;
          isInitializing = false;
        });
      }
    } catch (e) {
      print('Camera initialization error: $e');
      if (mounted) {
        setState(() {
          isCameraInitialized = false;
          isInitializing = false;
        });
      }
    }
  }

  Future<void> _disposeCamera() async {
    if (cameraController != null) {
      try {
        await cameraController!.dispose();
      } catch (e) {
        print('Camera disposal error: $e');
      } finally {
        cameraController = null;
        if (mounted) {
          setState(() {
            isCameraInitialized = false;
            isFlashOn = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        height: 600, // Increased from 500 to 600 for more space
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with blue theme
            _buildHeader(),

            // Camera/Content area - Now has more space
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                child: Stack(
                  children: [
                    // Camera view
                    if (isCameraInitialized && cameraController != null)
                      MobileScanner(
                        controller: cameraController!,
                        onDetect: _onQRDetected,
                        errorBuilder: (context, error, child) => _buildErrorWidget(error),
                        placeholderBuilder: (context, child) => _buildLoadingWidget(),
                      )
                    else
                      _buildLoadingWidget(),

                    // Scanning overlay
                    _buildScanningOverlay(),

                    // Bottom controls
                    _buildBottomControls(),

                    // Processing overlay
                    if (isProcessing) _buildProcessingOverlay(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.blue[600]!,
            Colors.blue[700]!,
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.qr_code_scanner,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QR Code Scanner',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Scan or upload QR code image',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: Colors.white, size: 24),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.white.withOpacity(0.95),
              Colors.white.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Position QR code within the frame or upload image',
              style: TextStyle(
                color: Colors.yellow[900],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  icon: Icons.flip_camera_ios,
                  label: 'Flip',
                  onPressed: _flipCamera,
                  color: Colors.blue[600]!,
                ),
                _buildControlButton(
                  icon: isFlashOn ? Icons.flash_on : Icons.flash_off,
                  label: 'Flash',
                  onPressed: _toggleFlash,
                  color: Colors.orange[600]!,
                ),
                _buildControlButton(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onPressed: _pickImageFromGallery,
                  color: Colors.green[600]!,
                ),
                _buildControlButton(
                  icon: Icons.close,
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(context),
                  color: Colors.red[600]!,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 70, // Fixed width for consistency
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24, // Larger icon
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return Positioned.fill(
      child: CustomPaint(
        painter: ScannerOverlayPainter(),
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Colors.blue[600],
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Processing QR Code...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait a moment',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(MobileScannerException error) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red[50],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[600]),
              const SizedBox(height: 16),
              Text(
                'Camera Error',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.errorDetails?.message ?? 'Cannot access camera',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: 16),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[600],
                      side: BorderSide(color: Colors.red[300]!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _initializeCamera,
                    icon: Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Colors.blue[600],
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Initializing Camera...',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please allow camera permission',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Pick image from gallery and scan QR code
  Future<void> _pickImageFromGallery() async {
    try {
      setState(() {
        isProcessing = true;
      });

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (pickedFile != null) {
        await _scanImageFile(File(pickedFile.path));
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  // NEW: Scan QR code from image file
  Future<void> _scanImageFile(File imageFile) async {
    try {
      // Use mobile_scanner to analyze the image
      final BarcodeCapture? result = await cameraController?.analyzeImage(imageFile.path);

      if (result != null && result.barcodes.isNotEmpty) {
        final barcode = result.barcodes.first;
        if (barcode.rawValue != null) {
          await _processQRData(barcode.rawValue!);
        } else {
          _showErrorSnackBar('No QR code found in image');
        }
      } else {
        _showErrorSnackBar('No QR code found in selected image');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to scan image: $e');
    }
  }

  void _onQRDetected(BarcodeCapture capture) {
    if (isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null && barcode.rawValue != lastScannedCode) {
        lastScannedCode = barcode.rawValue!;
        _handleQRScanned(barcode.rawValue!);
        break;
      }
    }
  }

  Future<void> _handleQRScanned(String qrData) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    // Add haptic feedback
    HapticFeedback.mediumImpact();

    try {
      await _processQRData(qrData);
    } catch (e) {
      _showErrorSnackBar('Failed to process QR code: $e');
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  Future<void> _processQRData(String qrData) async {
    print('Processing QR data: $qrData');

    // Add a small delay to show processing state
    await Future.delayed(const Duration(milliseconds: 800));

    // Handle different QR data formats
    String? productId;

    if (qrData.startsWith('WAREHOUSE_PRODUCT:')) {
      productId = qrData.substring('WAREHOUSE_PRODUCT:'.length);
    } else if (qrData.startsWith('warehouse://product/')) {
      productId = qrData.substring('warehouse://product/'.length);
    } else if (qrData.startsWith('https://') && qrData.contains('/product/')) {
      final parts = qrData.split('/product/');
      if (parts.length == 2) {
        productId = parts[1];
      }
    } else {
      // Unknown format - try to treat as product ID
      productId = qrData;
    }

    if (productId != null && productId.isNotEmpty) {
      await _navigateToProduct(productId);
    } else {
      _showErrorSnackBar('Invalid QR code format');
    }
  }

  Future<void> _navigateToProduct(String productId) async {
    try {
      // Close the scanner dialog first
      Navigator.pop(context);

      // Navigate based on productDetails flag
      if (!widget.productDetails) {
        // If true → go to StoredProductDetailScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoredProductDetailScreen(
              productId: productId,
              initialProductName: 'Loading...',
            ),
          ),
        );
      } else {
        // If false → go to StoredProductScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              productId: productId,
              // initialProductName: 'Loading....',
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Product not found: $productId');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _toggleFlash() {
    if (cameraController != null && isCameraInitialized) {
      cameraController!.toggleTorch();
      setState(() {
        isFlashOn = !isFlashOn;
      });
    }
  }

  void _flipCamera() {
    if (cameraController != null && isCameraInitialized) {
      cameraController!.switchCamera();
    }
  }
}

// Enhanced scanner overlay with blue theme
class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = Colors.blue[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final Paint cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Smaller scan area to avoid overlap with text
    final double scanAreaSize = size.width * 0.70;
    final Offset center = Offset(size.width / 2, size.height * 0.31);
    final Rect scanArea = Rect.fromCenter(
      center: center,
      width: scanAreaSize,
      height: scanAreaSize,
    );

    // Draw background with hole
    final Path backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scanArea, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(backgroundPath, backgroundPaint);

    // Draw scan area border
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanArea, const Radius.circular(16)),
      borderPaint,
    );

    // Draw corner indicators
    final double cornerLength = 25;
    final double cornerRadius = 12;

    // Top-left corner
    canvas.drawPath(
      Path()
        ..moveTo(scanArea.left, scanArea.top + cornerLength)
        ..lineTo(scanArea.left, scanArea.top + cornerRadius)
        ..arcToPoint(
          Offset(scanArea.left + cornerRadius, scanArea.top),
          radius: Radius.circular(cornerRadius),
        )
        ..lineTo(scanArea.left + cornerLength, scanArea.top),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawPath(
      Path()
        ..moveTo(scanArea.right - cornerLength, scanArea.top)
        ..lineTo(scanArea.right - cornerRadius, scanArea.top)
        ..arcToPoint(
          Offset(scanArea.right, scanArea.top + cornerRadius),
          radius: Radius.circular(cornerRadius),
        )
        ..lineTo(scanArea.right, scanArea.top + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawPath(
      Path()
        ..moveTo(scanArea.left, scanArea.bottom - cornerLength)
        ..lineTo(scanArea.left, scanArea.bottom - cornerRadius)
        ..arcToPoint(
          Offset(scanArea.left + cornerRadius, scanArea.bottom),
          radius: Radius.circular(cornerRadius),
        )
        ..lineTo(scanArea.left + cornerLength, scanArea.bottom),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawPath(
      Path()
        ..moveTo(scanArea.right - cornerLength, scanArea.bottom)
        ..lineTo(scanArea.right - cornerRadius, scanArea.bottom)
        ..arcToPoint(
          Offset(scanArea.right, scanArea.bottom - cornerRadius),
          radius: Radius.circular(cornerRadius),
        )
        ..lineTo(scanArea.right, scanArea.bottom - cornerLength),
      cornerPaint,
    );

    // Animated scanning line
    final Paint linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.blue[400]!.withOpacity(0.2),
          Colors.blue[400]!,
          Colors.blue[400]!.withOpacity(0.2),
        ],
      ).createShader(Rect.fromLTWH(scanArea.left, center.dy - 1, scanArea.width, 2))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(scanArea.left + 20, center.dy),
      Offset(scanArea.right - 20, center.dy),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}