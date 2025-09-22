import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/adjustment/inventory_service.dart';
import '../../services/adjustment/return_service.dart';
import 'lists/received_item_list_screen.dart';
import 'lists/discrepancy_report_list_screen.dart';
import 'lists/return_history_list_screen.dart';

class AdjustmentHubScreen extends StatefulWidget {
  const AdjustmentHubScreen({Key? key}) : super(key: key);

  @override
  State<AdjustmentHubScreen> createState() => _AdjustmentHubScreenState();
}

class _AdjustmentHubScreenState extends State<AdjustmentHubScreen> {
  final InventoryService _inventoryService = InventoryService();
  final ReturnService _returnService = ReturnService();
  
  bool _isLoading = true;
  int _totalItemsReceived = 0;
  int _totalItemsFlagged = 0;
  int _totalItemsReturned = 0;

  StreamSubscription<int>? _itemsReceivedSubscription;
  StreamSubscription<int>? _itemsFlaggedSubscription;
  StreamSubscription<int>? _itemsReturnedSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardStatistics();
      _setupRealTimeUpdates();
    });
  }

  @override
  void dispose() {
    _itemsReceivedSubscription?.cancel();
    _itemsFlaggedSubscription?.cancel();
    _itemsReturnedSubscription?.cancel();
    super.dispose();
  }


  void _navigateToReceiveStock() async {
    await Navigator.pushNamed(context, '/adjustment/receive-stock');
    _loadDashboardStatistics();
  }

  void _navigateToReportDiscrepancy() async {
    await Navigator.pushNamed(context, '/adjustment/report-discrepancy');
    _loadDashboardStatistics();
  }

  void _navigateToProcessReturn() async {
    await         Navigator.pushNamed(context, '/adjustment/return-stock');
    _loadDashboardStatistics();
  }

  void _navigateToReceivedItemsList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReceivedItemsListScreen(),
      ),
    );
    _loadDashboardStatistics();
  }

  void _navigateToDiscrepancyReportsList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DiscrepancyReportsListScreen(),
      ),
    );
    _loadDashboardStatistics();
  }

  void _navigateToReturnHistoryList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReturnHistoryListScreen(),
      ),
    );
    _loadDashboardStatistics();
  }

  void _setupRealTimeUpdates() {
    _itemsReceivedSubscription = _inventoryService.getTotalItemsReceivedStream().listen((count) {
      if (mounted) {
        setState(() {
          _totalItemsReceived = count;
        });
      }
    });

    _itemsFlaggedSubscription = _inventoryService.getTotalDiscrepancyReportsStream().listen((count) {
      if (mounted) {
        setState(() {
          _totalItemsFlagged = count;
        });
      }
    });

    _itemsReturnedSubscription = _returnService.getTotalReturnsStream().listen((count) {
      if (mounted) {
        setState(() {
          _totalItemsReturned = count;
        });
      }
    });
  }

  Future<void> _loadDashboardStatistics() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

     try {
       final totalReceived = await _inventoryService.getTotalItemsReceived();
       final totalFlagged = await _inventoryService.getTotalDiscrepancyReports();
       final totalReturns = await _returnService.getTotalReturns();

       if (mounted) {
         setState(() {
           _totalItemsReceived = totalReceived;
           _totalItemsFlagged = totalFlagged;
           _totalItemsReturned = totalReturns;
           _isLoading = false;
         });
       }
     } catch (e) {
       if (mounted) {
         setState(() {
           _totalItemsReceived = 0;
           _totalItemsFlagged = 0;
           _totalItemsReturned = 0;
           _isLoading = false;
         });
       }
     }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildQuickStats(),
                const SizedBox(height: 32),
                _buildMainActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inventory Adjustment',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            Text(
              'Manage stock levels and track adjustments',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: _isLoading ? null : _loadDashboardStatistics,
          icon: _isLoading 
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                  ),
                )
              : Icon(
                  Icons.refresh_outlined,
                  color: Colors.blue[600],
                ),
          tooltip: 'Refresh Stats',
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Text(
           'Overview',
           style: Theme.of(context).textTheme.titleMedium?.copyWith(
             fontWeight: FontWeight.w600,
             color: Colors.grey[800],
           ),
         ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
               child: _buildStatCard(
                 'Items Received',
                 _isLoading ? '...' : _totalItemsReceived.toString(),
                 Icons.inventory_2_outlined,
                 Colors.green,
                 onTap: _navigateToReceivedItemsList,
                 isLoading: _isLoading,
               ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Items Flagged',
                _isLoading ? '...' : _totalItemsFlagged.toString(),
                Icons.warning_amber_outlined,
                Colors.orange,
                onTap: _navigateToDiscrepancyReportsList,
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
               child: _buildStatCard(
                 'Total Returns',
                 _isLoading ? '...' : _totalItemsReturned.toString(),
                 Icons.assignment_return_outlined,
                 Colors.blue,
                 onTap: _navigateToReturnHistoryList,
                 isLoading: _isLoading,
               ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title, 
    String value, 
    IconData icon, 
    Color color, {
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onTap != null && !isLoading)
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey[400],
                    size: 14,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isLoading ? '---' : value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isLoading ? Colors.grey[400] : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Receive Stock',
                Icons.add_box_outlined,
                Colors.green,
                _navigateToReceiveStock,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Report Discrepancy',
                Icons.report_problem_outlined,
                Colors.orange,
                _navigateToReportDiscrepancy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          'Process Return',
          Icons.assignment_return_outlined,
          Colors.blue,
          _navigateToProcessReturn,
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Container(
      width: double.infinity,
      height: 80,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

}