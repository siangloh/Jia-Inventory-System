import 'package:flutter/material.dart';
import '../../../../services/adjustment/pdf_receipt_service.dart';
import '../../../../services/adjustment/snackbar_manager.dart';
import '../../../../services/adjustment/pdf_viewer_screen.dart';
import '../../lists/received_item_list_screen.dart';

class CompleteStep extends StatelessWidget {
  final List<Map<String, dynamic>> selectedPurchaseOrders;
  final Function() onPrintReceipt;
  final Function() onStartNewReceiving;

  const CompleteStep({
    Key? key,
    required this.selectedPurchaseOrders,
    required this.onPrintReceipt,
    required this.onStartNewReceiving,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // this widget is not used directly - main screen calls buildSlivers() static method
    return Container();
  }

  // static method for building completion step widgets
  static List<Widget> buildSlivers({
    required List<Map<String, dynamic>> selectedPurchaseOrders,
    required Function() onPrintReceipt,
    required Function() onStartNewReceiving,
    required BuildContext context,
  }) {
    List<Widget> slivers = [];

    // Header
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Receiving Complete',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Success content with action cards
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Success icon and message
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 48,
                  color: Colors.green[600],
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Receiving completed successfully!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                '${selectedPurchaseOrders.length} purchase order(s) processed',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Action cards section
              _buildActionCards(context, selectedPurchaseOrders, onPrintReceipt,
                  onStartNewReceiving),
            ],
          ),
        ),
      ),
    );

    // Summary section
    slivers.add(
      SliverToBoxAdapter(
        child: _buildSummarySection(selectedPurchaseOrders),
      ),
    );

    return slivers;
  }

  // Build action cards for next steps
  static Widget _buildActionCards(
      BuildContext context,
      List<Map<String, dynamic>> selectedPurchaseOrders,
      Function() onPrintReceipt,
      Function() onStartNewReceiving) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What would you like to do next?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // First row of action cards
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'View Received Items',
                Icons.inventory_2,
                Colors.blue,
                () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReceivedItemsListScreen(),
                    settings:
                        RouteSettings(name: '/adjustment/received-items-list'),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Start New Receiving',
                Icons.add_box,
                Colors.green,
                onStartNewReceiving,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Second row of action cards
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Report Discrepancy',
                Icons.warning,
                Colors.orange,
                () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/adjustment/report-discrepancy',
                  (route) => route.settings.name == '/adjustment',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'View Receipt PDF',
                Icons.picture_as_pdf,
                Colors.purple,
                () => _openPDFViewer(context, selectedPurchaseOrders),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Open PDF viewer with generated receipt
  static Future<void> _openPDFViewer(BuildContext context,
      List<Map<String, dynamic>> selectedPurchaseOrders) async {
    final snackbarManager = SnackbarManager();

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'Generating Receipt PDF...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait while we prepare your document',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Generate PDF bytes
      final pdfBytes = await PDFReceiptService.generateReceivingReceiptBytes(
        purchaseOrders: selectedPurchaseOrders,
        generatedBy: 'Current User', 
        workshopName: 'JiaCar Workshop',
        workshopAddress: 'Default Workshop Address',
      );

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      if (pdfBytes != null) {
        // Navigate to PDF viewer
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PDFViewerScreen(
                pdfBytes: pdfBytes,
                title: 'Receiving Receipt',
              ),
            ),
          );
        }
      } else {
        snackbarManager.showErrorMessage(
          context,
          message: 'Failed to generate PDF receipt',
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) Navigator.pop(context);

      snackbarManager.showErrorMessage(
        context,
        message: 'Error generating PDF: ${e.toString()}',
      );
    }
  }

  // Build individual action card
  static Widget _buildActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Build summary section
  static Widget _buildSummarySection(
      List<Map<String, dynamic>> selectedPurchaseOrders) {
    // Calculate comprehensive stats
    int totalOrders = selectedPurchaseOrders.length;
    int totalLineItems = 0;
    int totalReceived = 0;
    int totalDamaged = 0;
    double totalValue = 0.0;
    Set<String> uniqueProducts = {};
    Set<String> uniqueBrands = {};

    for (var po in selectedPurchaseOrders) {
      List<dynamic> lineItems = po['lineItems'] ?? [];
      totalLineItems += lineItems.length;

      for (var item in lineItems) {
        int received = item['quantityReceived'] ?? 0;
        int damaged = item['quantityDamaged'] ?? 0;
        double unitPrice = (item['unitPrice'] ?? item['price'] ?? 0).toDouble();

        totalReceived += received;
        totalDamaged += damaged;
        totalValue += (received * unitPrice);

        // Track unique products and brands
        String productName =
            item['displayName'] ?? item['productName'] ?? 'Unknown';
        String brandName = item['brandName'] ?? item['brand'] ?? 'Unknown';

        if (productName != 'Unknown' && productName != 'N/A') {
          uniqueProducts.add(productName);
        }
        if (brandName != 'Unknown' && brandName != 'N/A') {
          uniqueBrands.add(brandName);
        }
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50]!, Colors.blue[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16), // Reduced from 20 to 16
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6), // Reduced from 8 to 6
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.summarize,
                      color: Colors.green[700],
                      size: 18), // Reduced from 20 to 18
                ),
                const SizedBox(width: 10), // Reduced from 12 to 10
                Text(
                  'Receiving Summary',
                  style: TextStyle(
                    fontSize: 16, // Reduced from 18 to 16
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12), // Reduced from 16 to 12

            // ENHANCED: Comprehensive statistics grid - FIXED LAYOUT
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio:
                  2.0, // Decrease to make cards taller for better content visibility
              children: [
                _buildSummaryStatCard(
                  'Orders Processed',
                  '$totalOrders',
                  Icons.receipt_long,
                  Colors.blue,
                ),
                _buildSummaryStatCard(
                  'Line Items',
                  '$totalLineItems',
                  Icons.inventory_2,
                  Colors.green,
                ),
                _buildSummaryStatCard(
                  'Items Received',
                  '$totalReceived',
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildSummaryStatCard(
                  'Items Damaged',
                  '$totalDamaged',
                  Icons.warning,
                  totalDamaged > 0 ? Colors.red : Colors.grey,
                ),
                _buildSummaryStatCard(
                  'Unique Products',
                  '${uniqueProducts.length}',
                  Icons.category,
                  Colors.purple,
                ),
                _buildSummaryStatCard(
                  'Total Value',
                  'RM ${totalValue.toStringAsFixed(2)}',
                  Icons.attach_money,
                  Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 12), // Reduced from 16 to 12

            // ENHANCED: Purchase Orders breakdown
            _buildPOBreakdown(selectedPurchaseOrders),
          ],
        ),
      ),
    );
  }

  // ENHANCED: Build individual summary stat card - OPTIMIZED FOR COMPACT LAYOUT
  static Widget _buildSummaryStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8), // Revert to original working padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10), // Slightly smaller radius
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // Added to prevent overflow
        children: [
          Icon(icon, color: color, size: 18), // Revert to original icon size
          const SizedBox(height: 4), // Revert to original spacing
          Flexible(
            // Changed from FittedBox to Flexible for better overflow handling
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16, // Revert to original font size
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4), // Revert to original spacing
          Flexible(
            // Changed from FittedBox to Flexible
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12, // Revert to original label font size
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2, // Allow 2 lines for longer labels
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ENHANCED: Build PO breakdown section
  static Widget _buildPOBreakdown(
      List<Map<String, dynamic>> selectedPurchaseOrders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.list_alt, color: Colors.blue[700], size: 16),
            const SizedBox(width: 8),
            Text(
              'Purchase Orders Breakdown',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8), // Reduced from 12 to 8
        ...selectedPurchaseOrders.map((po) {
          List<dynamic> lineItems = po['lineItems'] ?? [];
          int totalReceived = 0;
          int totalOrdered = 0;
          Set<String> processedProducts = {};

          for (var item in lineItems) {
            totalReceived += (item['quantityReceived'] ?? 0) as int;
            totalOrdered += (item['quantityOrdered'] ?? 0) as int;

            String productName =
                item['displayName'] ?? item['productName'] ?? 'Unknown';
            if (productName != 'Unknown' && productName != 'N/A') {
              processedProducts.add(productName);
            }
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 6), // Reduced from 8 to 6
            padding: const EdgeInsets.all(10), // Reduced from 12 to 10
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt,
                    size: 14, color: Colors.blue[600]), // Reduced from 16 to 14
                const SizedBox(width: 6), // Reduced from 8 to 6
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${po['poNumber'] ?? 'Unknown PO'} - ${po['supplierName'] ?? 'Unknown Supplier'}',
                        style: TextStyle(
                          fontSize: 11, // Reduced from 12 to 11
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 1), // Reduced from 2 to 1
                      Text(
                        '${processedProducts.length} products • $totalReceived/$totalOrdered items',
                        style: TextStyle(
                          fontSize: 9, // Reduced from 10 to 9
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2), // Reduced horizontal from 6 to 5
                  decoration: BoxDecoration(
                    color: totalReceived == totalOrdered
                        ? Colors.green[100]
                        : Colors.orange[100],
                    borderRadius:
                        BorderRadius.circular(6), // Reduced from 8 to 6
                  ),
                  child: Text(
                    totalReceived == totalOrdered ? 'Complete' : 'Partial',
                    style: TextStyle(
                      fontSize: 8, // Reduced from 9 to 8
                      fontWeight: FontWeight.w600,
                      color: totalReceived == totalOrdered
                          ? Colors.green[700]
                          : Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
