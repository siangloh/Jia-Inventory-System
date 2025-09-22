import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class PDFReceiptService {
  // Generate PDF bytes for embedded viewing
  static Future<Uint8List?> generateReceivingReceiptBytes({
    required List<Map<String, dynamic>> purchaseOrders,
    required String generatedBy,
    required String workshopName,
    required String workshopAddress,
  }) async {
    try {
      debugPrint('Generating PDF receipt bytes for ${purchaseOrders.length} purchase orders');
      
      // Create PDF document
      final pdf = pw.Document();
      
      // Add cover page
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return [
              _buildHeader(workshopName, workshopAddress),
              pw.SizedBox(height: 20),
              _buildSummarySection(purchaseOrders),
              pw.SizedBox(height: 20),
              _buildPurchaseOrdersTable(purchaseOrders),
              pw.SizedBox(height: 30),
              _buildFooter(generatedBy),
            ];
          },
        ),
      );
      
      // Return PDF bytes
      final Uint8List pdfBytes = await pdf.save();
      debugPrint('PDF receipt bytes generated successfully');
      return pdfBytes;
      
    } catch (e) {
      debugPrint('Error generating PDF receipt bytes: $e');
      return null;
    }
  }

  // Save PDF bytes to PUBLIC Documents folder with date organization
  static Future<String?> savePDFToPublicDocuments(
    Uint8List pdfBytes, {
    String? customFileName,
    bool createDateFolder = true,
  }) async {
    try {
      // Request storage permission for Android
      if (Platform.isAndroid) {
        // Check if we need to request permission
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            debugPrint('Storage permission denied');
            return null;
          }
        }
      }

      // Get external storage directory (public storage)
      Directory? externalDir;
      
      if (Platform.isAndroid) {
        // For Android - use external storage Documents folder
        externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Navigate to public Documents folder
          // /storage/emulated/0/Documents
          String documentsPath = '/storage/emulated/0/Documents';
          externalDir = Directory(documentsPath);
        }
      } else if (Platform.isIOS) {
        // For iOS - use documents directory
        externalDir = await getApplicationDocumentsDirectory();
      }

      if (externalDir == null) {
        debugPrint('Could not access external storage');
        return null;
      }

      // Create base Documents directory if it doesn't exist
      if (!await externalDir.exists()) {
        await externalDir.create(recursive: true);
        debugPrint('Created Documents directory: ${externalDir.path}');
      }

      String finalPath = externalDir.path;
      
      // Create date-based folder if requested
      if (createDateFolder) {
        final now = DateTime.now();
        final dateFolder = '${now.day}_${now.month}'; // Format: 7_9 for Sept 7
        final dateFolderPath = '$finalPath/$dateFolder';
        final dateFolderDir = Directory(dateFolderPath);
        
        if (!await dateFolderDir.exists()) {
          await dateFolderDir.create(recursive: true);
          debugPrint('Created date folder: $dateFolderPath');
        }
        
        finalPath = dateFolderPath;
      }

      // Generate filename
      final fileName = customFileName ?? 
          'Receiving_Receipt_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      
      final filePath = '$finalPath/$fileName';
      
      // Write file
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);
      
      debugPrint('PDF saved to public Documents: $filePath');
      return filePath;
      
    } catch (e) {
      debugPrint('Error saving PDF to public Documents: $e');
      return null;
    }
  }

  // Alternative method using MediaStore for Android 10+ (Scoped Storage)
  static Future<String?> savePDFWithMediaStore(
    Uint8List pdfBytes, {
    String? customFileName,
  }) async {
    try {
      if (!Platform.isAndroid) {
        // Fallback to regular method for non-Android
        return await savePDFToPublicDocuments(pdfBytes, customFileName: customFileName);
      }

      // For Android 10+ using MediaStore approach
      final fileName = customFileName ?? 
          'Receiving_Receipt_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      
      // Create date folder name
      final now = DateTime.now();
      final dateFolder = '${now.day}_${now.month}';
      
      // Use Downloads folder as it's more accessible
      final directory = await getExternalStorageDirectory();
      if (directory == null) return null;
      
      // Navigate to Downloads for easier access
      final downloadsPath = '/storage/emulated/0/Download';
      final downloadsDir = Directory(downloadsPath);
      
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      
      // Create date subfolder in Downloads
      final dateFolderPath = '$downloadsPath/$dateFolder';
      final dateFolderDir = Directory(dateFolderPath);
      
      if (!await dateFolderDir.exists()) {
        await dateFolderDir.create(recursive: true);
      }
      
      final filePath = '$dateFolderPath/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);
      
      debugPrint('PDF saved to Downloads with date folder: $filePath');
      return filePath;
      
    } catch (e) {
      debugPrint('Error saving PDF with MediaStore: $e');
      return null;
    }
  }

  // Build header section
  static pw.Widget _buildHeader(String workshopName, String workshopAddress) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    workshopName,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    workshopAddress,
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Mobile: +60 12-345 6789',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Email: info@workshop.com',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'RECEIVING RECEIPT',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Date: ${DateFormat('dd MMM yyyy, h:mm a').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Receipt #: RC-${DateFormat('yyyyMMddHHmmss').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Build summary section
  static pw.Widget _buildSummarySection(List<Map<String, dynamic>> purchaseOrders) {
    int totalOrders = purchaseOrders.length;
    int totalLineItems = 0;
    int totalReceivedQty = 0;
    int totalDamagedQty = 0;
    double totalValue = 0.0;
    
    for (var po in purchaseOrders) {
      List<dynamic> lineItems = po['lineItems'] ?? [];
      totalLineItems += lineItems.length;
      
      for (var item in lineItems) {
        int received = item['quantityReceived'] ?? 0;
        int damaged = item['quantityDamaged'] ?? 0;
        double unitPrice = (item['unitPrice'] ?? 0).toDouble();
        
        totalReceivedQty += received;
        totalDamagedQty += damaged;
        totalValue += (received * unitPrice);
      }
    }
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Orders', totalOrders.toString(), PdfColors.blue),
          _buildSummaryItem('Line Items', totalLineItems.toString(), PdfColors.green),
          _buildSummaryItem('Received', totalReceivedQty.toString(), PdfColors.green),
          _buildSummaryItem('Damaged', totalDamagedQty.toString(), PdfColors.red),
          _buildSummaryItem('Total Value', 'RM ${totalValue.toStringAsFixed(2)}', PdfColors.orange),
        ],
      ),
    );
  }
  
  // Build summary item
  static pw.Widget _buildSummaryItem(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
      ],
    );
  }
  
  // Build purchase orders table with improved layout
    static pw.Widget _buildPurchaseOrdersTable(List<Map<String, dynamic>> purchaseOrders) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Purchase Orders Details',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FixedColumnWidth(45),   // PO #
            1: const pw.FlexColumnWidth(4),     // Product Info (more space)
            2: const pw.FixedColumnWidth(35),   // Qty Ord
            3: const pw.FixedColumnWidth(35),   // Qty Rec  
            4: const pw.FixedColumnWidth(35),   // Damaged
            5: const pw.FixedColumnWidth(55),   // Unit Price
            6: const pw.FixedColumnWidth(55),   // Total
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blue100),
              children: [
                _buildTableCell('PO #', isHeader: true),
                _buildTableCell('Product Details', isHeader: true),
                _buildTableCell('Ord', isHeader: true),
                _buildTableCell('Rec', isHeader: true),
                _buildTableCell('Dmg', isHeader: true),
                _buildTableCell('Unit Price', isHeader: true),
                _buildTableCell('Total', isHeader: true),
              ],
            ),
            // Data rows with enhanced product information
            ...purchaseOrders.expand((po) {
              List<dynamic> lineItems = po['lineItems'] ?? [];
              return lineItems.map((item) {
                int ordered = item['quantityOrdered'] ?? 0;
                int received = item['quantityReceived'] ?? 0;
                int damaged = item['quantityDamaged'] ?? 0;
                double unitPrice = (item['unitPrice'] ?? item['price'] ?? 0).toDouble();
                double total = received * unitPrice;
                
                // ENHANCED: Get properly resolved product information
                String productName = item['displayName'] ?? item['productName'] ?? 'Unknown Product';
                String brandName = item['brandName'] ?? item['brand'] ?? '';
                String sku = item['sku'] ?? '';
                String partNumber = item['partNumber'] ?? '';
                String categoryName = item['categoryName'] ?? '';
                
                // REDESIGNED: Create better formatted product display with proper spacing
                String productDisplay = productName;
                List<String> productDetails = [];
                
                if (brandName.isNotEmpty && brandName != 'N/A' && brandName != 'Unknown Brand') {
                  productDetails.add('Brand: $brandName');
                }
                if (sku.isNotEmpty && sku != 'N/A') {
                  productDetails.add('SKU: $sku');
                }
                if (partNumber.isNotEmpty && partNumber != 'N/A') {
                  productDetails.add('Part: $partNumber');
                }
                if (categoryName.isNotEmpty && categoryName != 'N/A') {
                  productDetails.add('Cat: $categoryName');
                }
                
                // Use line breaks instead of bullet points for better readability
                if (productDetails.isNotEmpty) {
                  productDisplay += '\n${productDetails.join('\n')}';
                }
                
                return pw.TableRow(
                  children: [
                    _buildTableCell(po['poNumber'] ?? 'N/A', fontSize: 9),
                    _buildTableCell(productDisplay, fontSize: 8), // Increased from 7 to 8
                    _buildTableCell(ordered.toString(), fontSize: 9),
                    _buildTableCell(received.toString(), color: PdfColors.green, fontSize: 9),
                    _buildTableCell(damaged.toString(), color: damaged > 0 ? PdfColors.red : PdfColors.grey, fontSize: 9),
                    _buildTableCell('RM ${unitPrice.toStringAsFixed(2)}', fontSize: 8),
                    _buildTableCell('RM ${total.toStringAsFixed(2)}', color: PdfColors.blue, fontSize: 8),
                  ],
                );
              });
            }),
          ],
        ),
      ],
    );
  }

  
  // Build table cell with better sizing and spacing
  static pw.Widget _buildTableCell(String text, {bool isHeader = false, PdfColor? color, double? fontSize}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10), // Increased vertical padding
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize ?? (isHeader ? 10 : 9),
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? (isHeader ? PdfColors.blue900 : PdfColors.black),
          lineSpacing: 1.2, // Add line spacing for better readability
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left, // Left align product details for better readability
        maxLines: isHeader ? 2 : 5, // Allow more lines for product details
      ),
    );
  }
  
  // Build footer section
  static pw.Widget _buildFooter(String generatedBy) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Generated by: $generatedBy',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Date: ${DateFormat('dd MMM yyyy, h:mm a').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Greenstem Business Software',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    'Inventory Management System',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'This receipt is generated automatically by the system and serves as proof of inventory receiving. All quantities have been verified and recorded in the system.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Additional utility methods remain the same...
  static Future<Map<String, String>> getAvailableStoragePaths() async {
    Map<String, String> paths = {};
    
    try {
      // App Documents (private)
      final appDocs = await getApplicationDocumentsDirectory();
      paths['App Documents'] = appDocs.path;
      
      // External Storage (if available)
      final external = await getExternalStorageDirectory();
      if (external != null) {
        paths['External Storage'] = external.path;
        
        // Public Documents
        paths['Public Documents'] = '/storage/emulated/0/Documents';
        
        // Public Downloads  
        paths['Public Downloads'] = '/storage/emulated/0/Download';
      }
      
    } catch (e) {
      debugPrint('Error getting storage paths: $e');
    }
    
    return paths;
  }

  static Future<String?> createDateFolderStructure({
    required String basePath,
    String? customDateFormat,
  }) async {
    try {
      final now = DateTime.now();
      final dateFormat = customDateFormat ?? '${now.day}_${now.month}';
      final dateFolderPath = '$basePath/$dateFormat';
      
      final dateFolder = Directory(dateFolderPath);
      if (!await dateFolder.exists()) {
        await dateFolder.create(recursive: true);
        debugPrint('Created date folder: $dateFolderPath');
      }
      
      return dateFolderPath;
    } catch (e) {
      debugPrint('Error creating date folder: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> getFileInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return {'exists': false};
      }
      
      final stat = await file.stat();
      final fileName = filePath.split('/').last;
      
      return {
        'exists': true,
        'fileName': fileName,
        'size': stat.size,
        'sizeFormatted': _formatFileSize(stat.size),
        'modified': stat.modified,
        'path': filePath,
      };
    } catch (e) {
      debugPrint('Error getting file info: $e');
      return {'exists': false, 'error': e.toString()};
    }
  }
  
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}