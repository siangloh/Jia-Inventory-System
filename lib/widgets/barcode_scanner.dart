import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:assignment/screens/product/product_item_details.dart';

class BarcodeScannerDialog extends StatefulWidget {
  final bool productDetails;
  final Function(String)? onBarcodeScanned;
  final String? title;
  final String? hint;
  final bool autoNavigate;
  final BuildContext? parentContext;

  const BarcodeScannerDialog({
    super.key,
    this.productDetails = false,
    this.onBarcodeScanned,
    this.title,
    this.hint,
    this.autoNavigate = false,
    this.parentContext,
  });

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> {
  MobileScannerController? controller;
  bool isScanning = false;
  bool hasPermission = false;
  bool flashOn = false;
  String? errorMessage;
  String? scannedBarcode;
  StreamSubscription<BarcodeCapture>? _subscription;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeScanner() async {
    try {
      // Request camera permission
      final permission = await Permission.camera.request();

      if (permission == PermissionStatus.granted) {
        setState(() {
          hasPermission = true;
        });

        // Initialize the scanner controller
        controller =
            MobileScannerController(); // Uncomment when using mobile_scanner

        _startScanning();
      } else {
        setState(() {
          hasPermission = false;
          errorMessage =
          'Camera permission denied. Please enable camera access in settings.';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to initialize scanner: $e';
      });
    }
  }

  void _startScanning() {
    setState(() {
      isScanning = true;
      errorMessage = null;
    });

    // Listen to barcode detection
    _subscription = controller?.barcodes.listen(
          (BarcodeCapture barcodeCapture) {
        if (barcodeCapture.barcodes.isNotEmpty) {
          final barcode = barcodeCapture.barcodes.first;
          if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
            _handleBarcodeDetected(barcode.rawValue!);
          }
        }
      },
      onError: (error) {
        setState(() {
          errorMessage = 'Scanner error: $error';
          isScanning = false;
        });
      },
    );
  }

  void _stopScanning() {
    _subscription?.cancel();
    setState(() {
      isScanning = false;
    });
  }

  Future<void> _toggleFlash() async {
    try {
      await controller?.toggleTorch();
      setState(() {
        flashOn = !flashOn;
      });
    } catch (e) {
      print('Error toggling flash: $e');
    }
  }

  void _handleBarcodeDetected(String barcode) {
    if (scannedBarcode == barcode) return; // Prevent duplicate scans

    setState(() {
      scannedBarcode = barcode;
      isScanning = false;
    });

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Call the callback function
    if (widget.onBarcodeScanned != null) {
      widget.onBarcodeScanned!(barcode);
    }

    // Show success and close dialog
    _showSuccessAndClose(barcode);
  }

  void _showSuccessAndClose(String barcode) {
    // For non-auto-navigate mode (search mode), show the success dialog
    if (!widget.autoNavigate) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600], size: 24),
              const SizedBox(width: 8),
              const Text('Barcode Scanned'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.barcode_reader, color: Colors.green[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        barcode,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: barcode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Barcode copied to clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: 'Copy to clipboard',
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close success dialog
                Navigator.pop(context); // Close scanner dialog
              },
              child: const Text('Done'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close success dialog
                setState(() {
                  scannedBarcode = null;
                });
                _startScanning(); // Resume scanning
              },
              child: const Text('Scan Another'),
            ),
          ],
        ),
      );
    }
    // For auto-navigate mode, navigation is handled in _handleBarcodeDetected
  }

  void _handleManualInput() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Enter Barcode Manually'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Barcode',
                hintText: 'Enter barcode number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final barcode = controller.text.trim();
              if (barcode.isNotEmpty) {
                Navigator.pop(context);
                _handleBarcodeDetected(barcode);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[600],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.barcode_reader,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title ?? 'Scan Barcode',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.hint ?? 'Position barcode within the frame',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Scanner Area
            Expanded(
              child: _buildScannerContent(),
            ),

            // Controls
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  // Flash and Camera controls
                  if (hasPermission) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: _toggleFlash,
                          icon: Icon(
                            flashOn ? Icons.flash_on : Icons.flash_off,
                            color:
                            flashOn ? Colors.yellow[700] : Colors.grey[600],
                          ),
                          tooltip: flashOn ? 'Turn off flash' : 'Turn on flash',
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isScanning
                                ? Colors.green[100]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color:
                                  isScanning ? Colors.green : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isScanning ? 'Scanning...' : 'Ready',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isScanning
                                      ? Colors.green[700]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            try {
                              await controller?.switchCamera();
                            } catch (e) {
                              print('Error switching camera: $e');
                            }
                          },
                          icon: Icon(Icons.flip_camera_ios,
                              color: Colors.grey[600]),
                          tooltip: 'Switch camera',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Main control buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handleManualInput,
                          icon: const Icon(Icons.keyboard, size: 16),
                          label: const Text('Manual Input'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: hasPermission && !isScanning
                              ? _startScanning
                              : _stopScanning,
                          icon: Icon(
                            isScanning ? Icons.stop : Icons.play_arrow,
                            size: 16,
                          ),
                          label: Text(isScanning ? 'Stop Scan' : 'Start Scan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isScanning
                                ? Colors.red[600]
                                : Colors.green[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerContent() {
    if (errorMessage != null) {
      return _buildErrorState();
    }

    if (!hasPermission) {
      return _buildPermissionDeniedState();
    }

    return _buildRealScannerState();
  }

  Widget _buildRealScannerState() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Real camera scanner
            MobileScanner(
              controller: controller,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    _handleBarcodeDetected(barcode.rawValue!);
                    break;
                  }
                }
              },
            ),

            // Scanner overlay with animation
            _buildScannerOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Stack(
      children: [
        // Semi-transparent overlay to darken areas outside the scanner frame
        Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black.withOpacity(0.5),
        ),

        // Clear scanning area
        Center(
          child: Container(
            width: 280,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
        ),

        // Scanner frame and animation
        Center(
          child: Container(
            width: 280,
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(
                color: isScanning ? Colors.green : Colors.white,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                // Corner indicators
                ...List.generate(4, (index) {
                  return Positioned(
                    top: index < 2 ? -3 : null,
                    bottom: index >= 2 ? -3 : null,
                    left: index % 2 == 0 ? -3 : null,
                    right: index % 2 == 1 ? -3 : null,
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        color: isScanning ? Colors.green : Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          border: Border(
                            top: index < 2
                                ? BorderSide(
                                color: isScanning
                                    ? Colors.green
                                    : Colors.white,
                                width: 3)
                                : BorderSide.none,
                            bottom: index >= 2
                                ? BorderSide(
                                color: isScanning
                                    ? Colors.green
                                    : Colors.white,
                                width: 3)
                                : BorderSide.none,
                            left: index % 2 == 0
                                ? BorderSide(
                                color: isScanning
                                    ? Colors.green
                                    : Colors.white,
                                width: 3)
                                : BorderSide.none,
                            right: index % 2 == 1
                                ? BorderSide(
                                color: isScanning
                                    ? Colors.green
                                    : Colors.white,
                                width: 3)
                                : BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                // Scanning line animation
                if (isScanning)
                  Positioned.fill(
                    child: _buildAnimatedScanningLine(),
                  ),

                // Status text overlay
                if (!isScanning)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.barcode_reader,
                              size: 32,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ready to scan',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Instructions text
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isScanning
                    ? 'Scanning for barcodes...'
                    : 'Tap "Start Scan" to begin',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedScanningLine() {
    return TweenAnimationBuilder<double>(
      key: ValueKey(isScanning ? 'scanning' : 'idle'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 2000),
      builder: (context, value, child) {
        return Positioned(
          top: value * 174, // 180 (container height) - 6 (padding)
          left: 3,
          right: 3,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.green,
                  Colors.green.withOpacity(0.8),
                  Colors.green,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
              ),
              borderRadius: BorderRadius.circular(1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.6),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
      onEnd: () {
        if (isScanning && mounted) {
          // Restart the animation by rebuilding the widget
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && isScanning) {
              setState(() {});
            }
          });
        }
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Scanner Error',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeScanner,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined,
                size: 64, color: Colors.orange[400]),
            const SizedBox(height: 16),
            Text(
              'Camera Permission Required',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'To scan barcodes, please allow camera access in your device settings.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await openAppSettings();
              },
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockScannerState() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Mock camera preview
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: isScanning ? _buildScanningOverlay() : _buildIdleOverlay(),
          ),

          // Scanner frame overlay
          Center(
            child: Container(
              width: 250,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isScanning ? Colors.green : Colors.white,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  // Corner indicators
                  ...List.generate(4, (index) {
                    return Positioned(
                      top: index < 2 ? 0 : null,
                      bottom: index >= 2 ? 0 : null,
                      left: index % 2 == 0 ? 0 : null,
                      right: index % 2 == 1 ? 0 : null,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          border: Border(
                            top: index < 2
                                ? BorderSide(
                                color: isScanning
                                    ? Colors.green
                                    : Colors.white,
                                width: 3)
                                : BorderSide.none,
                            bottom: index >= 2
                                ? BorderSide(
                                color: isScanning
                                    ? Colors.green
                                    : Colors.white,
                                width: 3)
                                : BorderSide.none,
                            left: index % 2 == 0
                                ? BorderSide(
                                color: isScanning
                                    ? Colors.green
                                    : Colors.white,
                                width: 3)
                                : BorderSide.none,
                            right: index % 2 == 1
                                ? BorderSide(
                                color: isScanning
                                    ? Colors.green
                                    : Colors.white,
                                width: 3)
                                : BorderSide.none,
                          ),
                        ),
                      ),
                    );
                  }),

                  // Scanning line animation
                  if (isScanning)
                    Positioned.fill(
                      child: _buildScanningLine(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // TODO: Replace the above mock implementation with actual camera scanner:
    /*
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              _handleBarcodeDetected(barcode.rawValue!);
              break;
            }
          }
        },
      ),
    );
    */
  }

  Widget _buildScanningOverlay() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Icon(
          Icons.barcode_reader,
          size: 48,
          color: Colors.white.withOpacity(0.8),
        ),
        const SizedBox(height: 16),
        Text(
          'Scanning for barcodes...',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Position barcode within the frame',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
        const Spacer(),
        // Mock scan button for testing
        Padding(
          padding: const EdgeInsets.all(24),
          child: ElevatedButton(
            onPressed: () => _handleBarcodeDetected('1234567890123'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Simulate Scan (Testing)'),
          ),
        ),
      ],
    );
  }

  Widget _buildIdleOverlay() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.barcode_reader,
          size: 48,
          color: Colors.white.withOpacity(0.5),
        ),
        const SizedBox(height: 16),
        Text(
          'Ready to scan',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap "Start Scan" to begin',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildScanningLine() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return Positioned(
          top: value * 150,
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            color: Colors.green,
            // boxShadow: [
            //   BoxShadow(
            //     color: Colors.green.withOpacity(0.5),
            //     blurRadius: 4,
            //   ),
            // ],
          ),
        );
      },
      onEnd: () {
        if (isScanning && mounted) {
          setState(() {}); // Restart animation
        }
      },
    );
  }
}