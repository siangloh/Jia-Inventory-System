import 'package:assignment/models/user_model.dart';
import 'package:assignment/screens/product/product_item_details.dart';
import 'package:assignment/services/statistics/product_statistics.dart';
import 'package:assignment/services/statistics/product_name_statistic_service.dart';
import 'package:assignment/services/statistics/product_brand_service.dart';
import 'package:assignment/widgets/qr/qr_scanner_dialog.dart';
import 'package:flutter/material.dart';
import '../services/login/load_user_data.dart';
import '../widgets/barcode_scanner.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String selectedPeriod = 'This Month';
  UserModel? user;
  bool isLoading = true;
  String? errorMessage;

  // Statistics services
  final ProductStatisticsService _productStatsService =
      ProductStatisticsService();
  final ProductNameStatisticsService _nameStatsService =
      ProductNameStatisticsService();
  final ProductBrandStatisticsService _brandStatsService =
      ProductBrandStatisticsService();

  // Statistics data
  ProductStatistics? productStats;
  ProductNameStatistics? nameStats;
  ProductBrandStatistics? brandStats;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await Future.wait([
        _loadUserData(),
        _loadStatistics(),
      ]);
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load dashboard data: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      user = await loadCurrentUser();
    } catch (e) {
      print('Failed to load user data: $e');
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final results = await Future.wait([
        _productStatsService.getCurrentStatistics(),
        _nameStatsService.getCurrentStatistics(),
        _brandStatsService.getCurrentStatistics(),
      ]);

      setState(() {
        productStats = results[0] as ProductStatistics;
        nameStats = results[1] as ProductNameStatistics;
        brandStats = results[2] as ProductBrandStatistics;
      });
    } catch (e) {
      print('Failed to load statistics: $e');
      throw e;
    }
  }

  Future<void> _refreshDashboard() async {
    try {
      // Force refresh from server
      await Future.wait([
        _productStatsService.refreshStatistics(),
        _nameStatsService.refreshStatistics(),
        _brandStatsService.refreshStatistics(),
      ]);

      await _loadStatistics();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Text('Dashboard refreshed successfully'),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('Failed to refresh: $e'),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (errorMessage != null) {
      return _buildErrorState();
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Key Metrics Cards
              _buildMetricsGrid(),
              const SizedBox(height: 20),

              // Quick Actions
              _buildQuickActions(),
              const SizedBox(height: 20),

              // Charts Section
              Row(
                children: [
                  Expanded(child: _buildInventoryChart()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildCategoryChart()),
                ],
              ),
              const SizedBox(height: 20),

              // Statistics Summary
              _buildStatisticsSummary(),
              const SizedBox(height: 20),

              // Low Stock Alert (using real data)
              _buildInventoryAlert(),
              const SizedBox(height: 20),

              // Recent Activity
              _buildRecentActivity(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue[600]),
            const SizedBox(height: 16),
            Text(
              'Loading Dashboard...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(
                'Failed to Load Dashboard',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage ?? 'Unknown error occurred',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _initializeDashboard,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Total Items',
          '${productStats?.totalItems ?? 0}',
          Icons.inventory_2_outlined,
          Colors.blue,
          subtitle: '${productStats?.productCount ?? 0} products',
        ),
        _buildMetricCard(
          'Available',
          '${productStats?.availableItems ?? 0}',
          Icons.check_circle_outline,
          Colors.green,
          subtitle: 'Ready to ship',
        ),
        _buildMetricCard(
          'Damaged',
          '${productStats?.damagedItems ?? 0}',
          Icons.warning_outlined,
          Colors.orange,
          subtitle: 'Needs attention',
        ),
        _buildMetricCard(
          'Out of Stock',
          '${productStats?.outOfStockItems ?? 0}',
          Icons.remove_circle_outline,
          Colors.red,
          subtitle: 'Sold items',
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.trending_up, color: color, size: 16),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Scan Barcode',
                Icons.barcode_reader,
                Colors.blue,
                () => _showBarcodeScanner(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Scan QR Code',
                Icons.qr_code_scanner,
                Colors.green,
                () => _showQRScanner(),
              ),
            ),
            const SizedBox(width: 12),
            // Expanded(
            //   child: _buildActionButton(
            //     'Refresh Data',
            //     Icons.refresh,
            //     Colors.purple,
            //         () => _refreshDashboard(),
            //   ),
            // ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryChart() {
    final totalItems = productStats?.totalItems ?? 0;
    final availableItems = productStats?.availableItems ?? 0;
    final percentage = totalItems > 0 ? (availableItems / totalItems) : 0.0;

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inventory Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: percentage,
                      strokeWidth: 12,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percentage >= 0.8
                            ? Colors.green[600]!
                            : percentage >= 0.5
                                ? Colors.orange[600]!
                                : Colors.red[600]!,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(percentage * 100).round()}%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: percentage >= 0.8
                              ? Colors.green[600]
                              : percentage >= 0.5
                                  ? Colors.orange[600]
                                  : Colors.red[600],
                        ),
                      ),
                      Text(
                        'Available',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChart() {
    final categoriesCount = productStats?.categoryStats.length ?? 0;

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Categories',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$categoriesCount',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.purple[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Active Categories',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple[100]!, Colors.purple[50]!],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  Icons.category,
                  size: 40,
                  color: Colors.purple[400],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistics Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Product Names',
                  '${nameStats?.totalProductNames ?? 0}',
                  Icons.label_outline,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Brands',
                  '${brandStats?.totalBrands ?? 0}',
                  Icons.business,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Active Names',
                  '${nameStats?.activeProductNames ?? 0}',
                  Icons.check_circle,
                  Colors.teal,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Active Brands',
                  '${brandStats?.activeBrands ?? 0}',
                  Icons.verified,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryAlert() {
    final damagedItems = productStats?.damagedItems ?? 0;
    final outOfStockItems = productStats?.outOfStockItems ?? 0;

    if (damagedItems == 0 && outOfStockItems == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'All inventory items are in good condition',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.green[700],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.orange[600]),
              const SizedBox(width: 8),
              const Text(
                'Inventory Alerts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (damagedItems > 0)
            _buildAlertItem(
              Icons.warning,
              'Damaged Items',
              '$damagedItems items need attention',
              Colors.orange,
            ),
          if (outOfStockItems > 0) ...[
            if (damagedItems > 0) const SizedBox(height: 12),
            _buildAlertItem(
              Icons.info,
              'Sold Items',
              '$outOfStockItems items have been sold',
              Colors.blue,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertItem(
      IconData icon, String title, String description, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    final activities = _generateRecentActivities();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...activities
              .map((activity) => _buildActivityItem(activity))
              .toList(),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _generateRecentActivities() {
    return [
      {
        'action': 'Statistics Updated',
        'item': 'Dashboard data refreshed',
        'time': 'Just now',
        'icon': Icons.refresh,
        'color': Colors.green,
      },
      {
        'action': 'Total Items',
        'item': '${productStats?.totalItems ?? 0} items tracked',
        'time': 'Current',
        'icon': Icons.inventory_2,
        'color': Colors.blue,
      },
      {
        'action': 'Available Stock',
        'item': '${productStats?.availableItems ?? 0} items ready',
        'time': 'Current',
        'icon': Icons.check_circle,
        'color': Colors.green,
      },
      if ((productStats?.damagedItems ?? 0) > 0)
        {
          'action': 'Attention Needed',
          'item': '${productStats!.damagedItems} damaged items',
          'time': 'Requires action',
          'icon': Icons.warning,
          'color': Colors.orange,
        },
    ];
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: activity['color'].withOpacity(0.1),
            child: Icon(
              activity['icon'],
              size: 16,
              color: activity['color'],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['action'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  activity['item'],
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            activity['time'],
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showBarcodeScanner() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BarcodeScannerDialog(
        productDetails: true,
        title: 'Scan Item Barcode',
        hint: 'Scan to navigate to item details',
        autoNavigate: true,
        // Always enable auto-navigation
        parentContext: context,
        // Pass the parent context for navigation
        onBarcodeScanned: (String barcode) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductItemDetailsScreen(
                productItemId: barcode,
              ),
            ),
          );
          // Optional additional handling
          print('Barcode scanned: $barcode');
        },
      ),
    );
  }

  void _showQRScanner() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const QRScannerDialog(productDetails: true),
    );
  }
}
