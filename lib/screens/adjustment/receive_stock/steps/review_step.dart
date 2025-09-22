import 'package:flutter/material.dart';

class ReviewStep extends StatelessWidget {
  final List<Map<String, dynamic>> selectedPurchaseOrders;
  final Function() onBack;
  final Function() onProceedToComplete;

  const ReviewStep({
    Key? key,
    required this.selectedPurchaseOrders,
    required this.onBack,
    required this.onProceedToComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // this widget is not used directly - main screen calls buildChecklistSlivers() static method
    return Container();
  }

  // checklist view with pagination and swipe gestures
  static List<Widget> buildChecklistSlivers({
    required List<Map<String, dynamic>> selectedPurchaseOrders,
    required Function() onBack,
    required Function() onProceedToSummary,
    required BuildContext context,
  }) {
    if (selectedPurchaseOrders.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Text('No purchase orders selected'),
          ),
        ),
      ];
    }

    List<Widget> slivers = [];

    // Header
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.checklist, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review Items',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Verify each processed item before finalizing',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // pageview with pagination for step 3 checklist
    slivers.add(
      SliverToBoxAdapter(
        child: StatefulBuilder(
          builder: (context, setState) {
            int currentPage = 0;
            final int totalPages = selectedPurchaseOrders.length;
            PageController pageController = PageController();

            return Column(
              children: [
                // Page indicator
                if (totalPages > 1)
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(
                          'Purchase Order ${currentPage + 1} of $totalPages',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const Spacer(),
                        // Page dots
                        Row(
                          children: List.generate(totalPages, (index) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: index == currentPage
                                    ? Color(0xFF3B82F6)
                                    : Colors.grey[300],
                                shape: BoxShape.circle,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),

                // PageView for checklist items
                Container(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: PageView.builder(
                    controller: pageController,
                    itemCount: totalPages,
                    onPageChanged: (page) {
                      setState(() {
                        currentPage = page;
                      });
                    },
                    itemBuilder: (context, pageIndex) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildPurchaseOrderChecklistCard(
                            selectedPurchaseOrders[pageIndex]),
                      );
                    },
                  ),
                ),

                // Navigation buttons
                if (totalPages > 1)
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: currentPage > 0
                              ? () {
                                  pageController.previousPage(
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              : null,
                          icon: Icon(Icons.chevron_left),
                          label: Text('Previous'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            foregroundColor: Colors.grey[800],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: currentPage < totalPages - 1
                              ? () {
                                  pageController.nextPage(
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              : null,
                          icon: Icon(Icons.chevron_right),
                          label: Text('Next'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            foregroundColor: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );

    return slivers;
  }

  // summary view with overflow fixes and pagination
  static List<Widget> buildSummarySlivers({
    required List<Map<String, dynamic>> selectedPurchaseOrders,
    required Function() onBack,
    required Function() onProceedToComplete,
    required BuildContext context,
  }) {
    if (selectedPurchaseOrders.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Text('No purchase orders selected'),
          ),
        ),
      ];
    }

    final stats = _calculateSummaryStats(selectedPurchaseOrders);
    List<Widget> slivers = [];

    // Header
    slivers.add(
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF047857)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.dashboard, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Final Summary',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete overview and finalize the receiving process',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // summary content with proper overflow handling
    slivers.add(
      SliverToBoxAdapter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Receiving Summary',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Overview of all processed items and their values',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),

              // responsive stats grid with overflow protection
              LayoutBuilder(
                builder: (context, constraints) {
                  // Determine if we should use 2 columns or single column
                  bool useCompactLayout = constraints.maxWidth < 600;

                  return useCompactLayout
                      ? _buildCompactStatsLayout(stats)
                      : _buildRegularStatsLayout(stats);
                },
              ),

              const SizedBox(height: 20),

              // total value card with responsive design
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20), // Reduced padding
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF047857)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF059669).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  // Changed to Column for better mobile layout
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12), // Smaller container
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.attach_money,
                        color: Colors.white,
                        size: 28, // Smaller icon
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Total Received Value',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14, // Smaller font
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      // Ensure text fits
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'RM ${stats['totalReceivedValue'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24, // Smaller font
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on ${stats['totalReceivedQty']} received items',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12, // Smaller font
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Purchase orders details with pagination
    slivers.add(
      SliverToBoxAdapter(
        child: StatefulBuilder(
          builder: (context, setState) {
            int currentPage = 0;
            final int totalPages = selectedPurchaseOrders.length;
            PageController pageController = PageController();

            return Column(
              children: [
                // Section header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        'Purchase Orders Details',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Text(
                          '${totalPages} POs',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Page indicator for PO details
                if (totalPages > 1)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          'Purchase Order ${currentPage + 1} of $totalPages',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const Spacer(),
                        // Page dots
                        Row(
                          children: List.generate(totalPages, (index) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: index == currentPage
                                    ? Color(0xFF10B981)
                                    : Colors.grey[300],
                                shape: BoxShape.circle,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),

                // PageView for PO details
                Container(
                  height:
                      230, // Much more aggressive reduction to prevent overflow
                  child: PageView.builder(
                    controller: pageController,
                    itemCount: totalPages,
                    onPageChanged: (page) {
                      setState(() {
                        currentPage = page;
                      });
                    },
                    itemBuilder: (context, pageIndex) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: _buildPurchaseOrderCard(
                            selectedPurchaseOrders[pageIndex]),
                      );
                    },
                  ),
                ),

                // Navigation buttons for PO details
                if (totalPages > 1)
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: currentPage > 0
                              ? () {
                                  pageController.previousPage(
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              : null,
                          icon: Icon(Icons.chevron_left),
                          label: Text('Previous'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            foregroundColor: Colors.grey[800],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: currentPage < totalPages - 1
                              ? () {
                                  pageController.nextPage(
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              : null,
                          icon: Icon(Icons.chevron_right),
                          label: Text('Next'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            foregroundColor: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );

    return slivers;
  }

  // compact stats layout for smaller screens
  static Widget _buildCompactStatsLayout(Map<String, dynamic> stats) {
    return Column(
      children: [
        // Row 1: Main stats
        Row(
          children: [
            Expanded(
              child: _buildCompactStatCard(
                title: 'Purchase Orders',
                value: '${stats['totalOrders']}',
                subtitle: _buildOrdersSubtitle(stats),
                icon: Icons.receipt_long,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCompactStatCard(
                title: 'Line Items',
                value:
                    '${stats['processedLineItems']}/${stats['totalLineItems']}',
                subtitle: 'Processed',
                icon: Icons.inventory_2,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 2: Quantity stats
        Row(
          children: [
            Expanded(
              child: _buildCompactStatCard(
                title: 'Received',
                value: '${stats['totalReceivedQty']}',
                subtitle: 'Items received',
                icon: Icons.check_circle,
                color: Color(0xFF059669),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCompactStatCard(
                title: 'Damaged',
                value: '${stats['totalDamagedQty']}',
                subtitle: stats['totalDamagedQty'] > 0
                    ? 'Need attention'
                    : 'No damage',
                icon: Icons.warning_amber,
                color: stats['totalDamagedQty'] > 0
                    ? Color(0xFFDC2626)
                    : Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // regular stats layout for larger screens
  static Widget _buildRegularStatsLayout(Map<String, dynamic> stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1, // Slightly taller cards
      children: [
        _buildStatCard(
          title: 'Purchase Orders',
          value: '${stats['totalOrders']}',
          subtitle: _buildOrdersSubtitle(stats),
          icon: Icons.receipt_long,
          color: Color(0xFF3B82F6),
          trend: stats['fullyCompletedOrders'] > 0 ? 'up' : 'neutral',
        ),
        _buildStatCard(
          title: 'Line Items',
          value: '${stats['processedLineItems']}/${stats['totalLineItems']}',
          subtitle: 'Items processed',
          icon: Icons.inventory_2,
          color: Color(0xFF10B981),
          trend: stats['processedLineItems'] > 0 ? 'up' : 'neutral',
        ),
        _buildStatCard(
          title: 'Received Quantity',
          value: '${stats['totalReceivedQty']}',
          subtitle: 'Items successfully received',
          icon: Icons.check_circle,
          color: Color(0xFF059669),
          trend: stats['totalReceivedQty'] > 0 ? 'up' : 'neutral',
        ),
        _buildStatCard(
          title: 'Damaged Items',
          value: '${stats['totalDamagedQty']}',
          subtitle: stats['totalDamagedQty'] > 0
              ? 'Require attention'
              : 'No damage reported',
          icon: Icons.warning_amber,
          color: stats['totalDamagedQty'] > 0
              ? Color(0xFFDC2626)
              : Color(0xFF6B7280),
          trend: stats['totalDamagedQty'] > 0 ? 'down' : 'neutral',
        ),
      ],
    );
  }

  // compact stat card for small screens
  static Widget _buildCompactStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12), // Smaller padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6), // Smaller icon container
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18), // Smaller icon
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            // Ensure value text fits
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18, // Smaller font
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13, // Smaller font
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11, // Smaller font
              color: Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Other helper methods remain the same but with updated names...
  static Map<String, dynamic> _calculateSummaryStats(
      List<Map<String, dynamic>> selectedPurchaseOrders) {
    int totalOrders = selectedPurchaseOrders.length;
    int totalLineItems = 0;
    int processedLineItems = 0;
    int totalReceivedQty = 0;
    int totalDamagedQty = 0;
    double totalReceivedValue = 0.0;
    int fullyCompletedOrders = 0;
    int partiallyCompletedOrders = 0;
    int pendingOrders = 0;

    for (var po in selectedPurchaseOrders) {
      List<dynamic> lineItems = po['lineItems'] ?? [];
      bool hasProcessedItems = false;
      bool allItemsCompleted = true;

      for (var item in lineItems) {
        totalLineItems++;
        int ordered = item['quantityOrdered'] ?? 0;
        int received = item['quantityReceived'] ?? 0;
        int damaged = item['quantityDamaged'] ?? 0;
        double unitPrice = (item['unitPrice'] ?? 0).toDouble();

        totalReceivedQty += received;
        totalDamagedQty += damaged;
        totalReceivedValue += (received * unitPrice);

        if (received > 0 || damaged > 0) {
          hasProcessedItems = true;
          processedLineItems++;
        }

        if (received + damaged < ordered) {
          allItemsCompleted = false;
        }
      }

      if (allItemsCompleted && hasProcessedItems && lineItems.isNotEmpty) {
        fullyCompletedOrders++;
      } else if (hasProcessedItems) {
        partiallyCompletedOrders++;
      } else {
        pendingOrders++;
      }
    }

    return {
      'totalOrders': totalOrders,
      'totalLineItems': totalLineItems,
      'processedLineItems': processedLineItems,
      'totalReceivedQty': totalReceivedQty,
      'totalDamagedQty': totalDamagedQty,
      'totalReceivedValue': totalReceivedValue,
      'fullyCompletedOrders': fullyCompletedOrders,
      'partiallyCompletedOrders': partiallyCompletedOrders,
      'pendingOrders': pendingOrders,
    };
  }

  static String _buildOrdersSubtitle(Map<String, dynamic> stats) {
    int completed = stats['fullyCompletedOrders'];
    int partial = stats['partiallyCompletedOrders'];

    if (completed > 0 && partial > 0) {
      return '$completed complete, $partial partial';
    } else if (completed > 0) {
      return '$completed completed';
    } else if (partial > 0) {
      return '$partial partial';
    } else {
      return 'Ready to process';
    }
  }

  // Rest of the methods remain similar with minor adjustments for overflow protection...
  static Widget _buildPurchaseOrderChecklistCard(Map<String, dynamic> po) {
    List<dynamic> lineItems = po['lineItems'] ?? [];
    String poNumber = po['poNumber'] ?? 'N/A';
    String supplierName = po['supplierName'] ?? 'Unknown Supplier';

    int processedItems = 0;
    int totalReceived = 0;
    int totalDamaged = 0;

    for (var item in lineItems) {
      int received = item['quantityReceived'] ?? 0;
      int damaged = item['quantityDamaged'] ?? 0;

      if (received > 0 || damaged > 0) {
        processedItems++;
      }

      totalReceived += received;
      totalDamaged += damaged;
    }

    Color statusColor =
        processedItems == lineItems.length && lineItems.isNotEmpty
            ? Colors.green
            : processedItems > 0
                ? Colors.orange
                : Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // PO Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        poNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Flexible(
                      // use flexible to prevent overflow
                      child: Text(
                        supplierName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatusSummary('Items',
                        '$processedItems/${lineItems.length}', Colors.white),
                    const SizedBox(width: 16),
                    _buildStatusSummary(
                        'Received', '$totalReceived', Colors.white),
                    const SizedBox(width: 16),
                    _buildStatusSummary('Damaged', '$totalDamaged',
                        totalDamaged > 0 ? Colors.red[200]! : Colors.white),
                  ],
                ),
              ],
            ),
          ),

          // Line Items List - scrollable for overflow
          Container(
            height: 280, // Reduced height to prevent overflow
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: lineItems
                    .map((item) => _buildChecklistLineItem(item))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildStatusSummary(
      String label, String value, Color textColor) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            // prevent text overflow
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: textColor.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildChecklistLineItem(Map<String, dynamic> item) {
    // ENHANCED: Get properly resolved product information
    String productName =
        item['displayName'] ?? item['productName'] ?? 'Unknown Product';
    String brandName = item['brandName'] ?? item['brand'] ?? 'Unknown Brand';
    String categoryName = item['categoryName'] ?? 'N/A';
    String productId = item['productId'] ?? 'N/A';
    String sku = item['sku'] ?? 'N/A';
    String partNumber = item['partNumber'] ?? 'N/A';

    int ordered = item['quantityOrdered'] ?? 0;
    int received = item['quantityReceived'] ?? 0;
    int damaged = item['quantityDamaged'] ?? 0;
    int remaining = ordered - received - damaged;
    double unitPrice = (item['unitPrice'] ?? item['price'] ?? 0).toDouble();

    bool isProcessed = received > 0 || damaged > 0;
    bool isCompleted = remaining == 0 && ordered > 0 && isProcessed;
    bool hasIssues = damaged > 0;

    Color statusColor = isCompleted
        ? Colors.green
        : hasIssues
            ? Colors.red
            : isProcessed
                ? Colors.orange
                : Colors.grey;

    String statusText = isCompleted
        ? 'COMPLETE'
        : hasIssues
            ? 'HAS DAMAGE'
            : isProcessed
                ? 'PARTIAL'
                : 'PENDING';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCompleted
                    ? Icons.check_circle
                    : hasIssues
                        ? Icons.warning
                        : isProcessed
                            ? Icons.schedule
                            : Icons.radio_button_unchecked,
                color: statusColor,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // ENHANCED: Comprehensive product information display
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (brandName != 'N/A' && brandName != 'Unknown Brand')
                          _buildProductInfoChip(
                              'Brand', brandName, Colors.blue),
                        if (categoryName != 'N/A')
                          _buildProductInfoChip(
                              'Category', categoryName, Colors.green),
                        if (sku != 'N/A')
                          _buildProductInfoChip('SKU', sku, Colors.purple),
                        if (partNumber != 'N/A')
                          _buildProductInfoChip(
                              'Part', partNumber, Colors.orange),
                        if (productId != 'N/A')
                          _buildProductInfoChip('ID', productId, Colors.teal),
                        _buildProductInfoChip('Price',
                            'RM ${unitPrice.toStringAsFixed(2)}', Colors.green),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ENHANCED: Quantity display with better formatting
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuantityBadge('Ordered', ordered, Colors.blue),
                const SizedBox(width: 12),
                if (received > 0) ...[
                  _buildQuantityBadge('Received', received, Colors.green),
                  const SizedBox(width: 12),
                ],
                if (damaged > 0) ...[
                  _buildQuantityBadge('Damaged', damaged, Colors.red),
                  const SizedBox(width: 12),
                ],
                if (remaining > 0 && isProcessed) ...[
                  _buildQuantityBadge('Remaining', remaining, Colors.orange),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ENHANCED: Product info chip for better display
  static Widget _buildProductInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String trend,
  }) {
    return Container(
      padding: const EdgeInsets.all(16), // Reduced padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8), // Smaller padding
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20), // Smaller icon
              ),
              const Spacer(),
              if (trend == 'up')
                Icon(Icons.trending_up,
                    color: Colors.green, size: 18) // Smaller icon
              else if (trend == 'down')
                Icon(Icons.trending_down, color: Colors.red, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            // prevent overflow
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20, // Smaller font
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14, // Smaller font
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11, // Smaller font
              color: Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  static Widget _buildPurchaseOrderCard(Map<String, dynamic> po) {
    List<dynamic> lineItems = po['lineItems'] ?? [];
    int totalItems = lineItems.length;
    int processedItems = 0;
    int totalReceivedQty = 0;
    int totalDamagedQty = 0;
    int totalOrderedQty = 0;
    double poValue = 0.0;

    for (var item in lineItems) {
      int ordered = item['quantityOrdered'] ?? 0;
      int received = item['quantityReceived'] ?? 0;
      int damaged = item['quantityDamaged'] ?? 0;
      double unitPrice = (item['unitPrice'] ?? 0).toDouble();

      totalOrderedQty += ordered;
      totalReceivedQty += received;
      totalDamagedQty += damaged;
      poValue += (received * unitPrice);

      if (received > 0 || damaged > 0) {
        processedItems++;
      }
    }

    String statusText = processedItems == totalItems && totalItems > 0
        ? 'COMPLETED'
        : processedItems > 0
            ? 'PARTIAL'
            : 'PENDING';
    Color statusColor = processedItems == totalItems && totalItems > 0
        ? Colors.green
        : processedItems > 0
            ? Colors.orange
            : Colors.grey;
    double progressPercent =
        totalOrderedQty > 0 ? (totalReceivedQty / totalOrderedQty) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Allow card to shrink
        children: [
          // PO Header - Compact design
          Container(
            padding: const EdgeInsets.all(12), // Reduced padding
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.all(6), // Smaller icon container
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.receipt_long,
                          color: Colors.white, size: 16), // Smaller icon
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        po['poNumber'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14, // Smaller font
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2), // Smaller padding
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9, // Smaller font
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8), // Reduced spacing
                Row(
                  children: [
                    Expanded(
                      child: _buildPOInfoItem(
                          'Supplier', po['supplierName'] ?? ''),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPOInfoItem(
                          'Value', 'RM ${poValue.toStringAsFixed(2)}'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // PO Content - More compact
          Padding(
            padding: const EdgeInsets.all(12), // Reduced padding
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress Section - More compact
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Progress: $totalReceivedQty/$totalOrderedQty',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12, // Smaller font
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${(progressPercent * 100).toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        fontSize: 12, // Smaller font
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6), // Reduced spacing
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    minHeight: 4, // Thinner progress bar
                  ),
                ),

                const SizedBox(height: 8), // Reduced spacing

                // Quantity Summary - More compact
                Row(
                  children: [
                    Expanded(
                      child: _buildQuantitySummary(
                          'Received', totalReceivedQty, Colors.green),
                    ),
                    const SizedBox(width: 8), // Reduced spacing
                    Expanded(
                      child: _buildQuantitySummary(
                          'Damaged', totalDamagedQty, Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildPOInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 10, // Smaller font
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2), // Reduced spacing
        FittedBox(
          // prevent overflow
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12, // Smaller font
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  static Widget _buildQuantitySummary(String label, int quantity, Color color) {
    return Container(
      padding: const EdgeInsets.all(6), // Even smaller padding
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            // prevent overflow
            fit: BoxFit.scaleDown,
            child: Text(
              quantity.toString(),
              style: TextStyle(
                fontSize: 14, // Even smaller font
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 1), // Minimal spacing
          Text(
            label,
            style: TextStyle(
              fontSize: 9, // Even smaller font
              fontWeight: FontWeight.w600,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  static Widget _buildQuantityBadge(String label, int quantity, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $quantity',
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
