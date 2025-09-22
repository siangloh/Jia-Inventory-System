import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:assignment/models/request_model.dart';
import 'package:assignment/models/issue_model.dart';

import 'package:assignment/dao/request_dao.dart';
import 'package:assignment/dao/issue_dao.dart';
import 'package:assignment/dao/warehouse_deduction_dao.dart';

import 'package:assignment/services/part_Issues/request_service.dart';

import 'package:assignment/services/login/load_user_data.dart';
import 'package:assignment/models/user_model.dart';

import 'package:intl/intl.dart';

import 'dart:typed_data';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// Main Part Issues Page
class PartIssuesPage extends StatefulWidget {
  const PartIssuesPage({Key? key}) : super(key: key);

  @override
  State<PartIssuesPage> createState() => _PartIssuesPageState();
}

class _PartIssuesPageState extends State<PartIssuesPage> {
  // Controllers for search
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  String selectedDepartmentFilter = 'All';
  String selectedPriorityFilter = 'All';
  bool showFilters = false;


  // Local cache for requests & inventory
  List<PartRequest> allRequests = [];

  StreamSubscription<QuerySnapshot>? _requestsSub;
  StreamSubscription<QuerySnapshot>? _inventorySub;
  StreamSubscription<QuerySnapshot>? _issuesSub;

  DateTime? selectedStartDate;
  DateTime? selectedEndDate;
  String selectedIssuedByFilter = 'All';
  int? minQuantity;
  int? maxQuantity;
  bool showAdvancedFilters = false;

  List<IssueTransaction> recentTransactions = [];
  String selectedTab = 'pending';

  String selectedPartNumberFilter = 'All';
  String selectedDepartmentFilterHistory = 'All';

  String _currentSortType = 'date_desc';

  UserModel? currentUser;

  String selectedGroupBy = 'none';
  bool showGroupedView = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadUser();  // ← Loads the current user
  }

  Future<void> _loadUser() async {
    final user = await loadCurrentUser();  // ← Gets user from service
    setState(() {
      currentUser = user;
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    RequestDao.cancelSubscriptions();
    IssueDao.cancelSubscriptions(); // Cancel IssueDao subscriptions
    _requestsSub?.cancel();
    _inventorySub?.cancel();
    _issuesSub?.cancel();
    super.dispose();
  }

  @override
  void _initializeData() {
    // Subscribe to requests
    _requestsSub = RequestService.subscribeToRequests(
      onData: (requests) {
        setState(() {
          allRequests = requests;
        });
      },
      onError: (e) {
        RequestDao.showErrorSnackBar(context,'Error loading requests: $e');
      },
    );

    // Subscribe to issues collection
    _subscribeToIssues();
  }

  // method to subscribe to the issues collection from Firestore
  void _subscribeToIssues() {
    _issuesSub = IssueDao.subscribeToIssues(
      onData: (transactions) {
        setState(() {
          recentTransactions = transactions;
        });
      },
      onError: (e) {
        RequestDao.showErrorSnackBar(context,'Error loading issues: $e');
      },
      limit: 20, // Limit to recent 100 transactions
    );
  }

  Future<void> _loadRecentTransactions() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('issue')
          .orderBy('createdAt', descending: true) // 🔹 sort by new field
          .limit(20)
          .get();

      setState(() {
        recentTransactions = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return IssueTransaction(
            issueId: data['issueId'] ?? '',
            requestId: data['requestId'] ?? '',
            requestedQuantity: data['requestedQuantity'] ?? 0,
            quantity: data['quantity'] ?? 0,
            issueType: data['issueType'] ?? '',
            notes: data['notes'] ?? '',
            createdBy: data['createdBy'] ?? '',
            createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
          );
        }).toList();
      });
    } catch (e) {
      RequestDao.showErrorSnackBar(context, 'Failed to load transactions: $e');
    }
  }

  /////////////////////////////////////////// FILTERED //////////////////////////////////////////////////

  // Updated filtered lists using RequestDao functions
  List<PartRequest> get filteredPendingRequests {
    var filtered = allRequests.where((request) {
      // Search filter
      bool matchesSearch = searchQuery.isEmpty ||
          request.requestId.toLowerCase().contains(searchQuery.toLowerCase()) ||
          request.partNumber.toLowerCase().contains(searchQuery.toLowerCase()) ||
          request.technician.toLowerCase().contains(searchQuery.toLowerCase()) ||
          request.department.toLowerCase().contains(searchQuery.toLowerCase());

      // Department filter
      bool matchesDepartment = selectedDepartmentFilter == 'All' ||
          request.department == selectedDepartmentFilter;

      // Priority filter
      bool matchesPriority = selectedPriorityFilter == 'All' ||
          request.priority == selectedPriorityFilter;

      // Part number filter
      bool matchesPartNumber = selectedPartNumberFilter == 'All' ||
          request.partNumber == selectedPartNumberFilter;

      // Enhanced date filtering
      bool matchesDateRange = _isRequestInDateRange(request.requestDate);

      return matchesSearch && matchesDepartment && matchesPriority &&
          matchesPartNumber && matchesDateRange;
    }).toList();

    return filtered.where((r) => r.status.toLowerCase() == 'pending').toList();
  }

  List<IssueTransaction> get filteredTransactions {
    var filtered = IssueDao.filterTransactions(
      recentTransactions,
      searchQuery: searchQuery,
      startDate: selectedStartDate,
      endDate: selectedEndDate,
      issuedBy: selectedIssuedByFilter,
      partNumberFilter: selectedPartNumberFilter,
      departmentFilter: selectedDepartmentFilterHistory,
      allRequests: allRequests,
      minQuantity: minQuantity,
      maxQuantity: maxQuantity,
    );

    // Apply additional date filtering if needed
    if (selectedStartDate != null || selectedEndDate != null) {
      filtered = filtered.where((transaction) {
        return _isTransactionInDateRange(transaction.createdAt);
      }).toList();
    }

    // Filter by current user for non-managers - only show transactions issued by current user
    if (currentUser != null && currentUser!.employeeId != null) {
      // Check if user is a manager (case-insensitive)
      bool isManager = currentUser!.role != null &&
          currentUser!.role!.toLowerCase() == 'manager';

      if (!isManager) {
        // Non-managers can only see their own transactions
        filtered = filtered.where((transaction) {
          return transaction.createdBy.toLowerCase() == currentUser!.employeeId!.toLowerCase();
        }).toList();
      } else if (selectedIssuedByFilter != 'All') {
        // Managers can filter by specific users (case-insensitive)
        filtered = filtered.where((transaction) {
          return transaction.createdBy.toLowerCase() == selectedIssuedByFilter.toLowerCase();
        }).toList();
      }
      // If manager and selectedIssuedByFilter is 'All', show all transactions
    }

    // Apply sorting using the DAO method
    return IssueDao.applySorting(filtered, _currentSortType, allRequests);
  }

  /////////////////////////////////////////////////////////////////////////////////////////////

  // Get unique departments and priorities for filters
  List<String> get departments {
    return ['All'] + allRequests.map((r) => r.department).toSet().toList();
  }

  List<String> get priorities {
    return ['All'] + allRequests.map((r) => r.priority).toSet().toList();
  }

  List<String> get issuedByUsers {
    return IssueDao.getUniqueIssuedByUsers(recentTransactions);
  }

  List<String> get uniqueRequestIds {
    return IssueDao.getUniqueRequestIds(recentTransactions);
  }

  List<String> get uniqueDepartmentsFromTransactions {
    return IssueDao.getUniqueDepartments(recentTransactions, allRequests);
  }

  //Refresh
  void _refreshRequests() async {
    try {
      final requests = await RequestDao.refreshRequests();
      setState(() {
        allRequests = requests;
      });

      await _loadRecentTransactions();
      RequestDao.showSuccessSnackBar(context, 'Requests refreshed');
    } catch (e) {
      RequestDao.showErrorSnackBar(context,'Failed to refresh: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildSearchAndFilters(),
          _buildTabBar(),
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
      floatingActionButton: selectedTab == 'pending'
          ? FloatingActionButton(
        onPressed: _refreshRequests,
        child: const Icon(Icons.refresh),
        backgroundColor: Colors.indigo,
      )
          : null,
    );
  }

  /////////////////////////////////////////////////FUnction Button/////////////////////////////////////////
// Search layout with sliding action buttons
  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Sliding action buttons
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildActionButton(
                  icon: Icons.search,
                  label: 'Search',
                  onPressed: () => _showSearchDialog(),
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                _buildActionButton(
                  icon: Icons.filter_list,
                  label: 'Filter',
                  onPressed: () => _showFilterDialog(),
                  color: Colors.green,
                ),
                const SizedBox(width: 12),
                _buildActionButton(
                  icon: Icons.sort,
                  label: 'Sort',
                  onPressed: () => _showSortDialog(),
                  color: Colors.orange,
                ),
                const SizedBox(width: 12),
                // Group button now works for both tabs
                _buildActionButton(
                  icon: Icons.group_work,
                  label: 'Group',
                  onPressed: () => _showGroupingDialog(),
                  color: Colors.purple,
                ),
                const SizedBox(width: 12),
                _buildActionButton(
                  icon: Icons.date_range,
                  label: 'Date Range',
                  onPressed: () => _showDateRangeDialog(),
                  color: Colors.purple,
                ),
                const SizedBox(width: 12),
                _buildActionButton(
                  icon: Icons.analytics,
                  label: 'Statistics',
                  onPressed: () => _showTransactionStatistics(),
                  color: Colors.indigo,
                ),
                const SizedBox(width: 12),
                _buildActionButton(
                  icon: Icons.clear_all,
                  label: 'Clear All',
                  onPressed: () => _clearAllFilters(),
                  color: Colors.red,
                ),
                const SizedBox(width: 12),
                if (selectedTab == 'history') ...[
                  _buildActionButton(
                    icon: Icons.timeline,
                    label: 'Timeline',
                    onPressed: () => _showTransactionTimeline(),
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 12),
                ],
              ],
            ),
          ),

          // Active filters indicator (updated text)
          if (_hasActiveFilters() || selectedGroupBy != 'none') ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                selectedGroupBy != 'none'
                    ? 'Grouped by: ${selectedGroupBy.replaceAll('_', ' ')} ${selectedTab == 'pending' ? '(Requests)' : '(Transactions)'}'
                    : 'Filters active',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

// Build individual action button
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: 70,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: color.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
/////////////////////////////////////////////////FUnction Button/////////////////////////////////////////


  /////////////////////////////////////////////////TimeLine Button/////////////////////////////////////////
  void _showTransactionTimeline() {
    // Group transactions by date for better time-based display
    final Map<String, List<IssueTransaction>> transactionsByDate = {};

    for (final transaction in filteredTransactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(transaction.createdAt);
      transactionsByDate.putIfAbsent(dateKey, () => []).add(transaction);
    }

    // Sort dates in descending order (newest first)
    final sortedDates = transactionsByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.timeline, color: Colors.purple),
            const SizedBox(width: 8),
            const Text('Timeline'),
            const Spacer(),
            // Add timeline view toggle
            ToggleButtons(
              isSelected: [_timelineViewMode == 'daily', _timelineViewMode == 'hourly'],
              onPressed: (index) {
                setState(() {
                  _timelineViewMode = index == 0 ? 'daily' : 'hourly';
                });
                Navigator.pop(context);
                _showTransactionTimeline(); // Refresh dialog
              },
              borderRadius: BorderRadius.circular(4),
              constraints: const BoxConstraints(minHeight: 32, minWidth: 60),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Daily', style: TextStyle(fontSize: 12)),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Hourly', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: 500,
          child: filteredTransactions.isEmpty
              ? _buildEmptyTimelineState()
              : _timelineViewMode == 'daily'
              ? _buildDailyTimelineView(transactionsByDate, sortedDates)
              : _buildHourlyTimelineView(),
        ),
      ),
    );
  }

  String _timelineViewMode = 'daily';

  Widget _buildEmptyTimelineState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timeline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No transactions to display',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Transactions will appear here when available',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTimelineView(Map<String, List<IssueTransaction>> transactionsByDate, List<String> sortedDates) {
    return ListView.builder(
      itemCount: sortedDates.length,
      itemBuilder: (context, dayIndex) {
        final dateKey = sortedDates[dayIndex];
        final dayTransactions = transactionsByDate[dateKey]!;
        final date = DateTime.parse(dateKey);
        final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateKey;
        final isYesterday = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1))) == dateKey;

        String dayLabel;
        if (isToday) {
          dayLabel = 'Today';
        } else if (isYesterday) {
          dayLabel = 'Yesterday';
        } else {
          dayLabel = DateFormat('EEEE, MMM dd, yyyy').format(date);
        }

        // Sort transactions within the day by time (newest first)
        dayTransactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isToday ? Colors.blue[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isToday ? Colors.blue[200]! : Colors.grey[300]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isToday ? Icons.today : Icons.calendar_today,
                    size: 18,
                    color: isToday ? Colors.blue[700] : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dayLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isToday ? Colors.blue[700] : Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isToday ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${dayTransactions.length} ${dayTransactions.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isToday ? Colors.blue[700] : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Transactions for this day
            ...dayTransactions.asMap().entries.map((entry) {
              final transactionIndex = entry.key;
              final transaction = entry.value;
              final isLastInDay = transactionIndex == dayTransactions.length - 1;
              final isLastOverall = dayIndex == sortedDates.length - 1 && isLastInDay;

              return _buildTimelineTransaction(transaction, isLastOverall);
            }).toList(),

            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildHourlyTimelineView() {
    // Group by hour for more detailed view
    final Map<String, List<IssueTransaction>> transactionsByHour = {};

    for (final transaction in filteredTransactions) {
      final hourKey = DateFormat('yyyy-MM-dd HH:00').format(transaction.createdAt);
      transactionsByHour.putIfAbsent(hourKey, () => []).add(transaction);
    }

    final sortedHours = transactionsByHour.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      itemCount: sortedHours.length,
      itemBuilder: (context, hourIndex) {
        final hourKey = sortedHours[hourIndex];
        final hourTransactions = transactionsByHour[hourKey]!;
        final hourDateTime = DateTime.parse(hourKey.replaceAll(' ', 'T') + ':00');

        // Sort transactions within the hour by time (newest first)
        hourTransactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final now = DateTime.now();
        final isCurrentHour = DateFormat('yyyy-MM-dd HH:00').format(now) == hourKey;
        final hoursDifference = now.difference(hourDateTime).inHours;

        String timeLabel;
        if (isCurrentHour) {
          timeLabel = 'This Hour';
        } else if (hoursDifference < 24) {
          if (hoursDifference == 1) {
            timeLabel = '1 hour ago';
          } else {
            timeLabel = '$hoursDifference hours ago';
          }
        } else {
          timeLabel = DateFormat('MMM dd, yyyy - HH:mm').format(hourDateTime);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hour header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isCurrentHour ? Colors.green[50] : Colors.grey[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isCurrentHour ? Colors.green[200]! : Colors.grey[200]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: isCurrentHour ? Colors.green[700] : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isCurrentHour ? Colors.green[700] : Colors.grey[700],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${hourTransactions.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isCurrentHour ? Colors.green[600] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),

            // Transactions for this hour
            ...hourTransactions.asMap().entries.map((entry) {
              final transactionIndex = entry.key;
              final transaction = entry.value;
              final isLastInHour = transactionIndex == hourTransactions.length - 1;
              final isLastOverall = hourIndex == sortedHours.length - 1 && isLastInHour;

              return _buildTimelineTransaction(transaction, isLastOverall, showTime: true);
            }).toList(),

            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildTimelineTransaction(IssueTransaction transaction, bool isLast, {bool showTime = false}) {
    final issueTypeInfo = IssueDao.getIssueTypeInfo(transaction.issueType);

    // Find related request for additional context
    PartRequest? relatedRequest;
    try {
      relatedRequest = allRequests.firstWhere(
            (request) => request.requestId == transaction.requestId,
      );
    } catch (e) {
      relatedRequest = null;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator column
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: issueTypeInfo['statusColor'],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    issueTypeInfo['icon'],
                    size: 8,
                    color: Colors.white,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey[300],
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Transaction content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: issueTypeInfo['statusColor'].withOpacity(0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with issue type and time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: issueTypeInfo['statusColor'],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          transaction.issueType,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        showTime
                            ? DateFormat('HH:mm').format(transaction.createdAt)
                            : RequestDao.formatDateTime(transaction.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Transaction details
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Issue ID: ${transaction.issueId}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Request: ${transaction.requestId}',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                              ),
                            ),
                            if (relatedRequest != null) ...[
                              Text(
                                'Part: ${relatedRequest.partNumber}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Dept: ${relatedRequest.department}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Qty: ${transaction.quantity}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'By: ${transaction.createdBy}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Notes if available
                  if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.note_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              transaction.notes!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /////////////////////////////////////////////////Timeline Button/////////////////////////////////////////


////////////////////////////////////////////////////THIS IS SEARCH///////////////////////////////////////
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Search'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: TextField(
              controller: searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: selectedTab == 'pending'
                    ? 'Search by request ID, part number, technician...'
                    : 'Search by transaction ID, request ID, issued by...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) => setState(() => searchQuery = value),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                searchController.clear();
                setState(() => searchQuery = '');
                Navigator.of(context).pop();
              },
              child: const Text('Clear'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  ////////////////////////////////////////////////////////////////////////////////////////////////////////


  /////////////////////////////////THIS IS FILTER//////////////////////////////////////////////////////////
// Show filter dialog
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filters'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selectedTab == 'pending') ...[
                      // Part Number filter for pending requests
                      DropdownButtonFormField<String>(
                        value: selectedPartNumberFilter,
                        decoration: const InputDecoration(
                          labelText: 'Part Number',
                          border: OutlineInputBorder(),
                        ),
                        items: partNumbers.map((partNumber) =>
                            DropdownMenuItem(value: partNumber, child: Text(partNumber))
                        ).toList(),
                        onChanged: (value) => setDialogState(() =>
                        selectedPartNumberFilter = value ?? 'All'),
                      ),
                      const SizedBox(height: 16),
                      // Department filter
                      DropdownButtonFormField<String>(
                        value: selectedDepartmentFilter,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                        ),
                        items: departments.map((dept) =>
                            DropdownMenuItem(value: dept, child: Text(dept))
                        ).toList(),
                        onChanged: (value) => setDialogState(() =>
                        selectedDepartmentFilter = value ?? 'All'),
                      ),
                      const SizedBox(height: 16),
                      // Priority filter
                      DropdownButtonFormField<String>(
                        value: selectedPriorityFilter,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          border: OutlineInputBorder(),
                        ),
                        items: priorities.map((priority) =>
                            DropdownMenuItem(value: priority, child: Text(priority))
                        ).toList(),
                        onChanged: (value) => setDialogState(() =>
                        selectedPriorityFilter = value ?? 'All'),
                      ),
                    ] else ...[
                      // Part Number filter for history (from transactions)
                      DropdownButtonFormField<String>(
                        value: selectedPartNumberFilter,
                        decoration: const InputDecoration(
                          labelText: 'Part Number',
                          border: OutlineInputBorder(),
                        ),
                        items: uniquePartNumbersFromTransactions.map((partNumber) =>
                            DropdownMenuItem(value: partNumber, child: Text(partNumber))
                        ).toList(),
                        onChanged: (value) => setDialogState(() =>
                        selectedPartNumberFilter = value ?? 'All'),
                      ),
                      const SizedBox(height: 16),
                      // Department filter for history (from transactions)
                      DropdownButtonFormField<String>(
                        value: selectedDepartmentFilterHistory,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                        ),
                        items: uniqueDepartmentsFromTransactions.map((dept) =>
                            DropdownMenuItem(value: dept, child: Text(dept))
                        ).toList(),
                        onChanged: (value) => setDialogState(() =>
                        selectedDepartmentFilterHistory = value ?? 'All'),
                      ),
                      const SizedBox(height: 16),
                      // Issued by filter for history - ONLY show for managers
                      if (currentUser != null &&
                          currentUser!.role != null &&
                          currentUser!.role!.toLowerCase() == 'manager') ...[
                        DropdownButtonFormField<String>(
                          value: selectedIssuedByFilter,
                          decoration: const InputDecoration(
                            labelText: 'Issued By',
                            border: OutlineInputBorder(),
                          ),
                          items: issuedByUsers.map((user) =>
                              DropdownMenuItem(value: user, child: Text(user))
                          ).toList(),
                          onChanged: (value) => setDialogState(() =>
                          selectedIssuedByFilter = value ?? 'All'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      selectedPartNumberFilter = 'All';
                      selectedDepartmentFilter = 'All';
                      selectedDepartmentFilterHistory = 'All';
                      selectedPriorityFilter = 'All';
                      // Only reset issued by filter if user is a manager
                      if (currentUser != null &&
                          currentUser!.role != null &&
                          currentUser!.role!.toLowerCase() == 'manager') {
                        selectedIssuedByFilter = 'All';
                      }
                    });
                  },
                  child: const Text('Reset'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Update main widget
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Clear all filters
  void _clearAllFilters() {
    setState(() {
      searchQuery = '';
      searchController.clear();
      selectedDepartmentFilter = 'All';
      selectedDepartmentFilterHistory = 'All';
      selectedPriorityFilter = 'All';
      selectedPartNumberFilter = 'All';
      selectedIssuedByFilter = 'All';
      selectedStartDate = null;
      selectedEndDate = null;
      minQuantity = null;
      maxQuantity = null;
      // Clear grouping
      selectedGroupBy = 'none';
      showGroupedView = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All filters and grouping cleared')),
    );
  }

  // Check if there are active filters
  bool _hasActiveFilters() =>
      searchQuery.isNotEmpty ||
          selectedDepartmentFilter != 'All' ||
          selectedDepartmentFilterHistory != 'All' ||
          selectedPriorityFilter != 'All' ||
          selectedPartNumberFilter != 'All' ||
          selectedIssuedByFilter != 'All' ||
          selectedStartDate != null ||
          selectedEndDate != null ||
          minQuantity != null ||
          maxQuantity != null;

  List<String> get partNumbers {
    return ['All'] + allRequests.map((r) => r.partNumber).toSet().toList();
  }

  List<String> get uniquePartNumbersFromTransactions {
    return IssueDao.getUniquePartNumbers(recentTransactions, allRequests);
  }

  /////////////////////////////////////////////////////////////////////////////////////////////////////////


  /////////////////////////////////THIS IS SORT//////////////////////////////////////////////////////////
// Show sort dialog
  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.sort, color: Colors.orange),
              const SizedBox(width: 8),
              Text('Sort ${selectedTab == 'pending' ? 'Requests' : 'Transactions'}'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Common sort options
                _buildSortOption(
                  Icons.access_time,
                  'Date (Newest First)',
                  'date_desc',
                ),
                _buildSortOption(
                  Icons.access_time_filled,
                  'Date (Oldest First)',
                  'date_asc',
                ),

                if (selectedTab == 'pending') ...[
                  // Pending requests specific options
                  _buildSortOption(
                    Icons.priority_high,
                    'Priority (High to Low)',
                    'priority',
                  ),
                  _buildSortOption(
                    Icons.trending_up,
                    'Quantity (High to Low)',
                    'quantity_desc',
                  ),
                  _buildSortOption(
                    Icons.trending_down,
                    'Quantity (Low to High)',
                    'quantity_asc',
                  ),
                  _buildSortOption(
                    Icons.tag,
                    'Request ID',
                    'request_id',
                  ),
                ] else ...[
                  // Transaction history specific options
                  _buildSortOption(
                    Icons.trending_up,
                    'Quantity (High to Low)',
                    'quantity_desc',
                  ),
                  _buildSortOption(
                    Icons.trending_down,
                    'Quantity (Low to High)',
                    'quantity_asc',
                  ),
                  _buildSortOption(
                    Icons.person,
                    'Issued By (A-Z)',
                    'issued_by',
                  ),
                  _buildSortOption(
                    Icons.category,
                    'Issue Type',
                    'issue_type',
                  ),
                  _buildSortOption(
                    Icons.tag,
                    'Request ID',
                    'request_id',
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            if (_currentSortType != 'date_desc')
              TextButton(
                onPressed: () {
                  _applySorting('date_desc');
                  Navigator.of(context).pop();
                },
                child: const Text('Reset to Default'),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSortOption(IconData icon, String title, String sortType) {
    bool isSelected = _currentSortType == sortType;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.orange : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.orange : null,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.orange)
          : null,
      onTap: () {
        _applySorting(sortType);
        Navigator.of(context).pop();
      },
    );
  }

// Apply sorting
  void _applySorting(String sortType) {
    setState(() {
      _currentSortType = sortType;

      if (selectedTab == 'pending') {
        _sortPendingRequests(sortType);
      } else if (selectedTab == 'history') {
        _sortTransactions(sortType);
      }
    });

    // Show feedback to user
    String sortDescription = _getSortDescription(sortType);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sorted by $sortDescription'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _sortPendingRequests(String sortType) {
    switch (sortType) {
      case 'date_desc':
        allRequests.sort((a, b) => b.requestDate.compareTo(a.requestDate));
        break;
      case 'date_asc':
        allRequests.sort((a, b) => a.requestDate.compareTo(b.requestDate));
        break;
      case 'priority':
        allRequests.sort((a, b) {
          final priorityOrder = {'high': 1, 'urgent': 1, 'medium': 2, 'low': 3, 'normal': 4};
          final aPriority = priorityOrder[a.priority.toLowerCase()] ?? 5;
          final bPriority = priorityOrder[b.priority.toLowerCase()] ?? 5;

          if (aPriority != bPriority) {
            return aPriority.compareTo(bPriority);
          }
          // If same priority, sort by date (newest first)
          return b.requestDate.compareTo(a.requestDate);
        });
        break;
      case 'quantity_asc':
        allRequests.sort((a, b) {
          int qtyComparison = a.requestedQuantity.compareTo(b.requestedQuantity);
          if (qtyComparison != 0) return qtyComparison;
          return b.requestDate.compareTo(a.requestDate);
        });
        break;
      case 'quantity_desc':
        allRequests.sort((a, b) {
          int qtyComparison = b.requestedQuantity.compareTo(a.requestedQuantity);
          if (qtyComparison != 0) return qtyComparison;
          return b.requestDate.compareTo(a.requestDate);
        });
        break;
      case 'request_id':
        allRequests.sort((a, b) => a.requestId.compareTo(b.requestId));
        break;
    }
  }

  void _sortTransactions(String sortType) {
    switch (sortType) {
      case 'date_desc':
        recentTransactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'date_asc':
        recentTransactions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'quantity_desc':
        recentTransactions.sort((a, b) {
          // Fixed: Properly handle zero quantities
          int qtyComparison = b.quantity.compareTo(a.quantity);
          if (qtyComparison != 0) return qtyComparison;
          // Secondary sort by date (newest first)
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case 'quantity_asc':
        recentTransactions.sort((a, b) {
          // Fixed: Properly handle zero quantities - zeros will come first
          int qtyComparison = a.quantity.compareTo(b.quantity);
          if (qtyComparison != 0) return qtyComparison;
          // Secondary sort by date (newest first)
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case 'issued_by':
        recentTransactions.sort((a, b) {
          int userComparison = a.createdBy.compareTo(b.createdBy);
          if (userComparison != 0) return userComparison;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case 'issue_type':
        recentTransactions.sort((a, b) {
          // Priority order: Full Issue > Partial Issue > Backorder > Rejected
          final typeOrder = {
            'full issue': 1,
            'partial issue': 2,
            'backorder': 3,
            'rejected': 4
          };
          final aType = typeOrder[a.issueType.toLowerCase()] ?? 5;
          final bType = typeOrder[b.issueType.toLowerCase()] ?? 5;

          if (aType != bType) return aType.compareTo(bType);
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case 'request_id':
        recentTransactions.sort((a, b) {
          int requestComparison = a.requestId.compareTo(b.requestId);
          if (requestComparison != 0) return requestComparison;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case 'priority':
      // For transactions, get priority from related requests
        recentTransactions.sort((a, b) {
          String aPriority = 'normal';
          String bPriority = 'normal';

          try {
            final aRequest = allRequests.firstWhere((req) => req.requestId == a.requestId);
            aPriority = aRequest.priority;
          } catch (e) {
            // Request not found
          }

          try {
            final bRequest = allRequests.firstWhere((req) => req.requestId == b.requestId);
            bPriority = bRequest.priority;
          } catch (e) {
            // Request not found
          }

          final priorityOrder = {'high': 1, 'urgent': 1, 'medium': 2, 'low': 3, 'normal': 4};
          final aPriorityVal = priorityOrder[aPriority.toLowerCase()] ?? 5;
          final bPriorityVal = priorityOrder[bPriority.toLowerCase()] ?? 5;

          if (aPriorityVal != bPriorityVal) return aPriorityVal.compareTo(bPriorityVal);
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
    }
  }

  String _getSortDescription(String sortType) {
    switch (sortType) {
      case 'date_desc':
        return 'Date (Newest First)';
      case 'date_asc':
        return 'Date (Oldest First)';
      case 'priority':
        return 'Priority (High to Low)';
      case 'quantity_asc':
        return 'Quantity (Low to High, including zeros)';
      case 'quantity_desc':
        return 'Quantity (High to Low, including zeros)';
      case 'request_id':
        return 'Request ID';
      case 'issued_by':
        return 'Issued By (A-Z)';
      case 'issue_type':
        return 'Issue Type (Full → Partial → Backorder → Rejected)';
      default:
        return sortType;
    }
  }

/////////////////////////////////////////////////////////////////////////////////////////////////////////

/////////////////////////////////THIS IS DATE//////////////////////////////////////////////////////////
// Show date range dialog
  void _showDateRangeDialog() {
    showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: selectedStartDate != null && selectedEndDate != null
          ? DateTimeRange(start: selectedStartDate!, end: selectedEndDate!)
          : null,
      helpText: 'Select Date Range',
      cancelText: 'Clear',
      confirmText: 'Apply',
      saveText: 'Apply Filter',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Colors.purple,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.purple,
              ),
            ),
          ),
          child: child!,
        );
      },
    ).then((picked) {
      if (picked != null) {
        setState(() {
          selectedStartDate = picked.start;
          selectedEndDate = picked.end;
        });

        String tabName = selectedTab == 'pending' ? 'requests' : 'transactions';
        int filteredCount = selectedTab == 'pending'
            ? filteredPendingRequests.length
            : filteredTransactions.length;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.date_range, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Date range applied: ${_formatDateRange(picked.start, picked.end)}\nShowing $filteredCount $tabName',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.purple,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Clear',
              textColor: Colors.white,
              onPressed: () => _clearDateRange(),
            ),
          ),
        );
      } else {
        // User pressed cancel/clear
        _clearDateRange();
      }
    });
  }

  // Clear date range filters
  void _clearDateRange() {
    setState(() {
      selectedStartDate = null;
      selectedEndDate = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.clear, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Date range filter cleared'),
          ],
        ),
        backgroundColor: Colors.grey,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Enhanced date range formatting
  String _formatDateRange(DateTime start, DateTime end) {
    return '${_formatShortDate(start)} - ${_formatShortDate(end)}';
  }

  String _formatShortDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isTransactionInDateRange(DateTime transactionDate) {
    if (selectedStartDate == null && selectedEndDate == null) return true;

    // Normalize dates to start of day for comparison
    final transactionDay = DateTime(transactionDate.year, transactionDate.month, transactionDate.day);

    if (selectedStartDate != null) {
      final startDay = DateTime(selectedStartDate!.year, selectedStartDate!.month, selectedStartDate!.day);
      if (transactionDay.isBefore(startDay)) return false;
    }

    if (selectedEndDate != null) {
      final endDay = DateTime(selectedEndDate!.year, selectedEndDate!.month, selectedEndDate!.day);
      if (transactionDay.isAfter(endDay)) return false;
    }

    return true;
  }

  bool _isRequestInDateRange(DateTime requestDate) {
    if (selectedStartDate == null && selectedEndDate == null) return true;

    // Normalize dates to start of day for comparison
    final requestDay = DateTime(requestDate.year, requestDate.month, requestDate.day);

    if (selectedStartDate != null) {
      final startDay = DateTime(selectedStartDate!.year, selectedStartDate!.month, selectedStartDate!.day);
      if (requestDay.isBefore(startDay)) return false;
    }

    if (selectedEndDate != null) {
      final endDay = DateTime(selectedEndDate!.year, selectedEndDate!.month, selectedEndDate!.day);
      if (requestDay.isAfter(endDay)) return false;
    }

    return true;
  }

  /////////////////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////THIS IS TABBAR ////////////////////////////////////////////////////
  Widget _buildTabBar() {
    return Container(
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: _buildTab('pending', 'Pending Requests', Icons.pending_actions),
          ),
          Expanded(
            child: _buildTab('history', 'Issue History', Icons.history),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String tabId, String title, IconData icon) {
    bool isSelected = selectedTab == tabId;
    int count = tabId == 'pending' ? filteredPendingRequests.length : filteredTransactions.length;

    return GestureDetector(
      onTap: () => setState(() => selectedTab = tabId),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.indigo : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.indigo : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.indigo : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.indigo : Colors.grey,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (selectedTab) {
      case 'pending':
        return _buildPendingRequests();
      case 'history':
        return _buildIssueHistory();
      default:
        return _buildPendingRequests();
    }
  }
/////////////////////////////////////////////////////////////////////////////////////////////////////////


  ///////////////////////////////////////////////////NOTHING FOUNDED////////////////////////////////////////////////
  Widget _buildPendingRequests() {
    return StreamBuilder<List<PartRequest>>(
      stream: RequestDao.getRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && allRequests.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        // Use the filteredPendingRequests getter instead of manual filtering
        final requests = filteredPendingRequests
            .where((r) => r.status.toLowerCase() == 'pending')
            .toList();

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  (searchQuery.isNotEmpty || selectedStartDate != null ||
                      selectedEndDate != null || selectedDepartmentFilter != 'All' ||
                      selectedPriorityFilter != 'All' || selectedPartNumberFilter != 'All')
                      ? 'No pending requests found'
                      : 'No pending requests yet',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  (searchQuery.isNotEmpty || selectedStartDate != null ||
                      selectedEndDate != null || selectedDepartmentFilter != 'All' ||
                      selectedPriorityFilter != 'All' || selectedPartNumberFilter != 'All')
                      ? 'Try adjusting your search or filter criteria'
                      : 'Pending part requests will appear here',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // Check if we should show grouped view for requests
        if (selectedGroupBy != 'none' && showGroupedView) {
          return _buildGroupedPendingRequestsView();
        } else {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              return _buildRequestCard(requests[index]);
            },
          );
        }
      },
    );
  }

  Widget _buildIssueHistory() {
    // Check if current user is a manager (case-insensitive)
    bool isManager = currentUser != null &&
        currentUser!.role != null &&
        currentUser!.role!.toLowerCase() == 'manager';

    // Use the cached recentTransactions instead of StreamBuilder
    if (recentTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
                isManager
                    ? 'Transaction history will appear here'
                    : 'Your issue history will appear here',
                style: const TextStyle(color: Colors.grey)
            ),
          ],
        ),
      );
    }

    // Use the filtered and sorted transactions from your getter
    final filteredTxns = filteredTransactions;

    if (filteredTxns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              isManager
                  ? (selectedIssuedByFilter != 'All'
                  ? 'No transactions found for $selectedIssuedByFilter'
                  : 'No transactions found matching your filters')
                  : (searchQuery.isNotEmpty || selectedStartDate != null ||
                  selectedEndDate != null || selectedPartNumberFilter != 'All' ||
                  selectedDepartmentFilterHistory != 'All')
                  ? 'No transactions found matching your filters'
                  : 'You haven\'t issued any parts yet',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              isManager
                  ? 'Try adjusting your search or filter criteria'
                  : (searchQuery.isNotEmpty || selectedStartDate != null ||
                  selectedEndDate != null || selectedPartNumberFilter != 'All' ||
                  selectedDepartmentFilterHistory != 'All')
                  ? 'Try adjusting your search or filter criteria'
                  : 'Transactions you issue will appear here',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // NEW: Check if we should show grouped view
    if (selectedGroupBy != 'none' && showGroupedView) {
      return _buildGroupedTransactionView();
    } else {
      return _buildRegularTransactionView();
    }
  }
  /////////////////////////////////////////////////////////////////////////////////////////////////////////


  ///////////////////////////////////////////////////BUILD CARD////////////////////////////////////////////////
  Widget _buildRequestCard(PartRequest request) {
    final priorityInfo = RequestDao.getPriorityInfo(request.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with priority indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: priorityInfo['headerColor'],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 16,
                      color: Colors.grey[700],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Request #${request.requestId}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityInfo['statusColor'],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 4),
                      Text(
                        priorityInfo['label'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main content
          Container(
            padding: const EdgeInsets.all(20),
            child: FutureBuilder<Map<String, dynamic>>(
              future: WarehouseDeductionDao.getProductDetailsForPartNumber(
                partNumber: request.partNumber,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                } else if (snapshot.hasError) {
                  return _buildErrorState();
                } else if (!snapshot.hasData || snapshot.data!['success'] == false) {
                  return _buildNotFoundState(request);
                } else {
                  return _buildContentState(request, snapshot.data!, priorityInfo);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(PartRequest request, dynamic product, int totalQuantity, Map<String, dynamic> stockStatus) {
    return Row(
      children: [
        // Details button
        Expanded(
          child: OutlinedButton(
            onPressed: () => RequestDao.showRequestDetails(context, request),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              side: BorderSide(color: Colors.grey[400]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              'Details',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Issue button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: totalQuantity > 0
                ? () => _handleIssueButtonPressed(request, product, totalQuantity)
                : null,
            icon: Icon(
              totalQuantity > 0 ? Icons.inventory_outlined : Icons.block_outlined,
              size: 16,
            ),
            label: Text(
              totalQuantity > 0 ? 'Issue Parts' : 'Out of Stock',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: totalQuantity > 0 ? stockStatus['color'] : Colors.grey[400],
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Reject button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => RequestDao.showRejectDialog(request, context, currentUser!.employeeId!),
            icon: const Icon(Icons.cancel_outlined, size: 16),
            label: const Text(
              'Reject',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }


  //TRANSACTIONS
  Widget _buildTransactionCard(IssueTransaction transaction) {
    final issueTypeInfo = IssueDao.getIssueTypeInfo(transaction.issueType);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with issue type indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: issueTypeInfo['headerColor'],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: issueTypeInfo['statusColor'],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    issueTypeInfo['label'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(
                      issueTypeInfo['icon'],
                      size: 16,
                      color: issueTypeInfo['statusColor'],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ID: ${transaction.issueId}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main content
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Transaction details section
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transaction Details',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          RequestDao.buildDetailRow('Request ID:', transaction.requestId),
                          RequestDao.buildDetailRow('Issued By:', transaction.createdBy),
                          RequestDao.buildDetailRow(
                            'Issue Date:',
                            RequestDao.formatDateTime(transaction.createdAt),
                          ),

                        ],
                      ),
                    ),

                    const SizedBox(width: 24),

                    // Right column - Quantity section
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quantity',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildQuantitySection(transaction, issueTypeInfo),
                        ],
                      ),
                    ),
                  ],
                ),

                // Notes section (if available)
                if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          transaction.notes!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Footer with actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showTransactionDetails(transaction),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[400]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _printIssueSlip(transaction),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Print Slip',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Formal quantity section
  Widget _buildQuantitySection(IssueTransaction transaction, Map<String, dynamic> typeInfo) {
    final requestedQty = transaction.requestedQuantity ?? 0;
    final issuedQty = transaction.quantity;
    final hasPartialInfo = requestedQty > 0 && requestedQty != issuedQty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Issued:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$issuedQty',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'Requested:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$requestedQty',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Progress indicator
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fulfillment',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${((issuedQty / requestedQty) * 100).round()}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: typeInfo['statusColor'],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                widthFactor: (issuedQty / requestedQty).clamp(0.0, 1.0),
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: typeInfo['statusColor'],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showTransactionDetails(IssueTransaction transaction) async {
    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Find the related request by matching requestId
      PartRequest? relatedRequest;
      try {
        relatedRequest = allRequests.firstWhere(
              (request) => request.requestId == transaction.requestId,
        );
      } catch (e) {
        // No matching request found
        relatedRequest = null;
      }
      // Close loading dialog
      Navigator.pop(context);

      // Show transaction details dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.receipt_long, color: Colors.green),
              const SizedBox(width: 8),
              const Text('Transaction Details'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSectionHeader('Transaction Information'),
                RequestDao.buildDetailRow('Transaction ID:', transaction.requestId),
                RequestDao.buildDetailRow(
                  'Issue Date:',
                  RequestDao.formatDateTime(transaction.createdAt),
                ),

                RequestDao.buildDetailRow('Issued By:', transaction.createdBy),
                RequestDao.buildDetailRow('Issued Quantity:', '${transaction.quantity}'),
                RequestDao.buildDetailRow('Notes:', transaction.notes),

                const SizedBox(height: 16),
                _buildSectionHeader('Related Request'),
                RequestDao.buildDetailRow('Request ID:', transaction.requestId),
                if (relatedRequest != null) ...[
                  RequestDao.buildDetailRow('Part Number:', relatedRequest.partNumber),
                  RequestDao.buildDetailRow('Department:', relatedRequest.department),
                  RequestDao.buildDetailRow('Technician:', relatedRequest.technician),
                  RequestDao.buildDetailRow('Original Qty:', '${relatedRequest.requestedQuantity}'),
                  RequestDao.buildDetailRow('Priority:', relatedRequest.priority),
                  RequestDao.buildDetailRow(
                    'Issue Date:',
                    RequestDao.formatDateTime(relatedRequest.requestDate),
                  ),
                  RequestDao.buildDetailRow('Status:', relatedRequest.status),
                ] else ...[
                  RequestDao.buildDetailRow('Request Status:', 'Not found or archived'),
                ],

                const SizedBox(height: 16),
                _buildSectionHeader('Transaction Summary'),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Transaction Completed',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Successfully issued ${transaction.quantity} units to ${relatedRequest?.technician ?? 'Unknown'}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _printIssueSlip(transaction);
              },
              icon: const Icon(Icons.print, size: 18),
              label: const Text('Print Slip'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      Navigator.pop(context);
      RequestDao.showErrorSnackBar(context,'Failed to load transaction details: $e');
    }
  }

  void _handleIssueButtonPressed(PartRequest request, AvailableProduct product, int availableStock) async {
    // Double-check stock availability
    if (availableStock <= 0) {
      RequestDao.showErrorSnackBar(context,'No stock available for this part');
      return;
    }

    // Check if requested quantity exceeds available stock
    if (request.requestedQuantity > availableStock) {
      // Show confirmation dialog for partial issue
      bool? shouldProceed = await _showStockWarningDialog(
          request.requestedQuantity,
          availableStock
      );

      if (shouldProceed != true) return;
    }

    // Show issue dialog
    showDialog(
      context: context,
      builder: (context) => IssueDialog(
        request: request,
        product: product,
        availableStock: availableStock,
        onIssue: (issuedQuantity, notes) {
          _completeIssue(request, issuedQuantity, notes);
        },
      ),
    );
  }
  /////////////////////////////////////////////////////////////////////////////////////////////////////////


  /////////////////////////////////////////////////// THIS IS STATE ////////////////////////////////////////////////
// Loading state
  Widget _buildLoadingState() {
    return Column(
      children: [
        Container(
          height: 3,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(1.5),
          ),
          child: LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
            minHeight: 3,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Loading product details...',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

// Error state
  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[600], size: 20),
          const SizedBox(width: 8),
          Text(
            'Error loading product details',
            style: TextStyle(
              fontSize: 13,
              color: Colors.red[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

// Not found state
  Widget _buildNotFoundState(PartRequest request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RequestDao.buildDetailRow('Part Number', request.partNumber),
        RequestDao.buildDetailRow('Department', request.department),
        RequestDao.buildDetailRow('Technician', request.technician),
        RequestDao.buildDetailRow('Requested Qty', '${request.requestedQuantity}'),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: Colors.orange[600], size: 18),
              const SizedBox(width: 8),
              Text(
                'Product not found in inventory',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

// Main content state
  Widget _buildContentState(PartRequest request, Map<String, dynamic> data, Map<String, dynamic> priorityInfo) {
    final product = data['product'];
    final totalQuantity = data['totalQuantity'] ?? product.totalQuantity;

    // Use RequestDao method instead of local method
    final stockStatus = RequestDao.getStockStatus(totalQuantity, request.requestedQuantity);

    return Column(
      children: [
        // Request and Product Information
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column - Request Details
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Request Information',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RequestDao.buildDetailRow('Part Number', request.partNumber),
                  RequestDao.buildDetailRow('Department', request.department),
                  RequestDao.buildDetailRow('Technician', request.technician),
                  RequestDao.buildDetailRow('Product Name', product.productName),
                  RequestDao.buildDetailRow('Requested', '${request.requestedQuantity}', Colors.grey[700]!),
                  RequestDao.buildDetailRow('Available', '$totalQuantity', stockStatus['color'])
                ],
              ),
            ),
          ],
        ),
        // Stock status indicator
        _buildStockStatusIndicator(stockStatus, request.requestedQuantity, totalQuantity),

        const SizedBox(height: 10),

        // Action buttons
        _buildActionButtons(request, product, totalQuantity, stockStatus),
      ],
    );
  }

// Stock status indicator
  Widget _buildStockStatusIndicator(Map<String, dynamic> status, int requested, int available) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: status['backgroundColor'],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: status['color'].withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            RequestDao.getStockStatusIcon(status['status']), // Use DAO method
            color: status['color'],
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            status['label'],
            style: TextStyle(
              fontSize: 12,
              color: status['color'],
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          if (status['status'] == 'insufficient') ...[
            const Spacer(),
            Text(
              'Can fulfill: ${status['fulfillableQuantity']} of $requested',
              style: TextStyle(
                fontSize: 12,
                color: status['color'],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /////////////////////////////////////////////////////////////////////////////////////////////////////////

// Insufficient Stock
  Future<bool?> _showStockWarningDialog(int requestedQty, int availableStock) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Insufficient Stock'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Requested quantity: $requestedQty'),
            Text('Available stock: $availableStock'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stock Warning',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('You can only issue a partial quantity or place the remainder on backorder.'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Proceed with Partial Issue'),
          ),
        ],
      ),
    );
  }


  Future<void> _completeIssue(PartRequest request, int issuedQuantity, String notes) async {

    try {
      await RequestService.completeIssue(
          request: request,
          issuedQuantity: issuedQuantity,
          notes: notes
      );

    } catch (e) {
      RequestDao.showErrorSnackBar(context,'Failed to issue parts: $e');
    }
  }

  //////////////////////////////////////_showTransactionStatistics///////////////////////////////////////////////////////////
  void _showTransactionStatistics() {
    final stats = IssueDao.getTransactionStatistics(
      filteredTransactions,
      startDate: selectedStartDate,
      endDate: selectedEndDate,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.analytics, color: Colors.indigo),
            const SizedBox(width: 8),
            const Text('Transaction Statistics'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              IssueDao.buildStatRow('Total Transactions:', '${stats['totalTransactions']}'),
              IssueDao.buildStatRow('Total Quantity Issued:', '${stats['totalQuantityIssued']}'),
              IssueDao.buildStatRow('Average per Transaction:', '${stats['averageQuantityPerTransaction'].toStringAsFixed(1)}'),

              if ((stats['transactionsByUser'] as Map).isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Transactions by User:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...((stats['transactionsByUser'] as Map<String, int>).entries.map(
                      (entry) => IssueDao.buildStatRow('${entry.key}:', '${entry.value}'),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  //////////////////////////////////////_showTransactionStatistics///////////////////////////////////////////////////////////
  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.indigo,
      ),
    ),
  );

// Replace your existing _printIssueSlip method with this simple version:

  //////////////////////////////////////Download PDF///////////////////////////////////////////////////////////
  void _printIssueSlip(IssueTransaction transaction) async {
    // Find the related request
    PartRequest? relatedRequest;
    try {
      relatedRequest = allRequests.firstWhere(
            (request) => request.requestId == transaction.requestId,
      );
    } catch (e) {
      relatedRequest = null;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Issue Slip'),
          ],
        ),
        content: SingleChildScrollView(
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'PARTS ISSUE SLIP',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ID: ${transaction.issueId}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        'Date: ${RequestDao.formatDateTime(transaction.createdAt)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 20),

                // Transaction Info
                const Text(
                  'Transaction Details:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Request ID: ${transaction.requestId}'),
                Text('Issue Type: ${transaction.issueType}'),
                Text('Issued By: ${transaction.createdBy}'),
                Text('Quantity: ${transaction.quantity}'),

                if (relatedRequest != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Request Details:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Part Number: ${relatedRequest.partNumber}'),
                  Text('Department: ${relatedRequest.department}'),
                  Text('Technician: ${relatedRequest.technician}'),
                  Text('Requested Qty: ${relatedRequest.requestedQuantity}'),
                ],

                if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Notes:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(transaction.notes!),
                ],

                const Divider(height: 20),

                // Signature section
                const Text(
                  'Signatures:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 80,
                          height: 1,
                          color: Colors.black,
                        ),
                        const Text('Issued By', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                    Column(
                      children: [
                        Container(
                          width: 80,
                          height: 1,
                          color: Colors.black,
                        ),
                        const Text('Received By', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              // Close the dialog first
              Navigator.pop(context);
              // Then call the download function
              await _downloadPdf(transaction, relatedRequest);
            },
            icon: const Icon(Icons.download),
            label: const Text('Download PDF'),
          ),
        ],
      ),
    );
  }

// The fixed download PDF function
  Future<void> _downloadPdf(IssueTransaction transaction, PartRequest? relatedRequest) async {
    try {
      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Generating PDF...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Generate PDF first
      final pdfBytes = await _generatePdf(transaction, relatedRequest, PdfPageFormat.a4);

      // Request permissions for Android
      if (Platform.isAndroid) {
        // Try requesting multiple permissions to handle different Android versions
        bool permissionGranted = false;

        // First try storage permission (for older Android versions)
        var storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted) {
          permissionGranted = true;
        } else {
          storageStatus = await Permission.storage.request();
          if (storageStatus.isGranted) {
            permissionGranted = true;
          }
        }

        // If storage permission failed, try manage external storage (Android 11+)
        if (!permissionGranted) {
          var manageStorageStatus = await Permission.manageExternalStorage.status;
          if (manageStorageStatus.isGranted) {
            permissionGranted = true;
          } else {
            manageStorageStatus = await Permission.manageExternalStorage.request();
            if (manageStorageStatus.isGranted) {
              permissionGranted = true;
            }
          }
        }

        // If still no permission, try photos permission (Android 13+)
        if (!permissionGranted) {
          var photosStatus = await Permission.photos.status;
          if (photosStatus.isGranted) {
            permissionGranted = true;
          } else {
            photosStatus = await Permission.photos.request();
            if (photosStatus.isGranted) {
              permissionGranted = true;
            }
          }
        }

        // If no permissions granted, throw exception
        if (!permissionGranted) {
          throw Exception('Storage permission denied. Please grant file access permission.');
        }
      }

      // Get the appropriate directory
      Directory? directory;
      String directoryName = "Downloads";

      if (Platform.isAndroid) {
        // Try multiple paths for Android
        List<String> possiblePaths = [
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Documents',
          '/sdcard/Download',
          '/sdcard/Documents',
        ];

        for (String path in possiblePaths) {
          Directory testDir = Directory(path);
          if (await testDir.exists()) {
            directory = testDir;
            directoryName = path.split('/').last;
            break;
          }
        }

        // Fallback to external storage directory
        if (directory == null) {
          directory = await getExternalStorageDirectory();
          directoryName = "App Documents";
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
        directoryName = "Documents";
      } else {
        directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      // Ensure directory exists
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Create filename with timestamp to avoid conflicts
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'Issue_Slip_${transaction.issueId}_$timestamp.pdf';
      final file = File('${directory.path}/$fileName');

      // Write PDF to file
      await file.writeAsBytes(pdfBytes);

      // Verify file was created successfully
      if (!await file.exists()) {
        throw Exception('Failed to create PDF file');
      }

      // Success message with file info
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('PDF Downloaded Successfully!'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Saved to $directoryName: $fileName',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Open Folder',
              textColor: Colors.white,
              onPressed: () => _openFileLocation(directory!.path),
            ),
          ),
        );
      }

    } catch (e) {
      // Handle download error with more specific error messages
      print('Download error: $e'); // Debug print
      String errorMessage = 'Download failed: ';

      if (e.toString().contains('permission')) {
        errorMessage += 'Permission denied. Please grant storage access.';
      } else if (e.toString().contains('storage')) {
        errorMessage += 'Storage access failed. Try again.';
      } else {
        errorMessage += e.toString();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(errorMessage),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _downloadPdf(transaction, relatedRequest),
            ),
          ),
        );
      }
    }
  }

// Function to open file location (improved)
  Future<void> _openFileLocation(String dirPath) async {
    try {
      // You can use open_file package to open the directory
      // await OpenFile.open(dirPath);

      // For now, show the directory path
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.folder_open),
                SizedBox(width: 8),
                Text('File Location'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your PDF has been saved to:'),
                const SizedBox(height: 8),
                SelectableText(
                  dirPath,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tip: You can find this file in your file manager app.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Error showing file location: $e');
    }
  }

// Generate PDF document (enhanced with error handling)
  Future<Uint8List> _generatePdf(IssueTransaction transaction, PartRequest? relatedRequest, PdfPageFormat format) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'PARTS ISSUE SLIP',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'ID: ${transaction.issueId ?? 'N/A'}',
                        style: const pw.TextStyle(fontSize: 14),
                      ),
                      pw.Text(
                        'Date: ${RequestDao.formatDateTime(transaction.createdAt)}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 20),

                // Transaction Details
                pw.Text(
                  'Transaction Details:',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                _buildDetailRow('Request ID:', transaction.requestId ?? 'N/A'),
                _buildDetailRow('Issue Type:', transaction.issueType ?? 'N/A'),
                _buildDetailRow('Issued By:', transaction.createdBy ?? 'N/A'),
                _buildDetailRow('Quantity:', transaction.quantity?.toString() ?? 'N/A'),

                // Request Details if available
                if (relatedRequest != null) ...[
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'Request Details:',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _buildDetailRow('Part Number:', relatedRequest.partNumber ?? 'N/A'),
                  _buildDetailRow('Department:', relatedRequest.department ?? 'N/A'),
                  _buildDetailRow('Technician:', relatedRequest.technician ?? 'N/A'),
                  _buildDetailRow('Requested Qty:', relatedRequest.requestedQuantity?.toString() ?? 'N/A'),
                ],

                // Notes if available
                if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'Notes:',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(transaction.notes!),
                ],

                pw.Spacer(),

                // Signature section
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 40),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Signatures:',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 40),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            children: [
                              pw.Container(
                                width: 150,
                                height: 1,
                                color: PdfColors.black,
                              ),
                              pw.SizedBox(height: 5),
                              pw.Text('Issued By', style: const pw.TextStyle(fontSize: 10)),
                            ],
                          ),
                          pw.Column(
                            children: [
                              pw.Container(
                                width: 150,
                                height: 1,
                                color: PdfColors.black,
                              ),
                              pw.SizedBox(height: 5),
                              pw.Text('Received By', style: const pw.TextStyle(fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      return await pdf.save();
    } catch (e) {
      throw Exception('Failed to generate PDF: $e');
    }
  }

// Helper function to build detail rows in PDF
  pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }
//////////////////////////////////////Download PDF///////////////////////////////////////////////////////////

  void _showGroupingDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.group_work, color: Colors.purple),
                  const SizedBox(width: 8),
                  Text('Group ${selectedTab == 'pending' ? 'Requests' : 'Transactions'}'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedGroupBy,
                    decoration: const InputDecoration(
                      labelText: 'Group By',
                      border: OutlineInputBorder(),
                    ),
                    items: _getGroupingOptions(),
                    onChanged: (value) => setDialogState(() =>
                    selectedGroupBy = value ?? 'none'),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Grouped View'),
                    subtitle: Text(selectedTab == 'pending'
                        ? 'Display requests in collapsible groups'
                        : 'Display transactions in collapsible groups'),
                    value: showGroupedView,
                    onChanged: (value) => setDialogState(() =>
                    showGroupedView = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      selectedGroupBy = 'none';
                      showGroupedView = false;
                    });
                  },
                  child: const Text('Reset'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Update main widget
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Map<String, List<IssueTransaction>> get groupedTransactions {
    if (selectedGroupBy == 'none') {
      return {'All': filteredTransactions};
    }

    final Map<String, List<IssueTransaction>> groups = {};

    for (final transaction in filteredTransactions) {
      String groupKey = _getGroupKey(transaction, selectedGroupBy);
      groups.putIfAbsent(groupKey, () => []).add(transaction);
    }

    // Sort groups by key
    final sortedGroups = <String, List<IssueTransaction>>{};
    final sortedKeys = groups.keys.toList()..sort();

    for (final key in sortedKeys) {
      sortedGroups[key] = groups[key]!;
    }

    return sortedGroups;
  }

  List<DropdownMenuItem<String>> _getGroupingOptions() {
    if (selectedTab == 'pending') {
      return [
        const DropdownMenuItem(value: 'none', child: Text('No Grouping')),
        const DropdownMenuItem(value: 'department', child: Text('Department')),
        const DropdownMenuItem(value: 'priority', child: Text('Priority')),
        const DropdownMenuItem(value: 'part_number', child: Text('Part Number')),
        const DropdownMenuItem(value: 'technician', child: Text('Technician')),
        const DropdownMenuItem(value: 'date', child: Text('Request Date')),
      ];
    } else {
      return [
        const DropdownMenuItem(value: 'none', child: Text('No Grouping')),
        const DropdownMenuItem(value: 'part_number', child: Text('Part Number')),
        const DropdownMenuItem(value: 'department', child: Text('Department')),
        const DropdownMenuItem(value: 'date', child: Text('Date')),
        const DropdownMenuItem(value: 'issued_by', child: Text('Issued By')),
        const DropdownMenuItem(value: 'issue_type', child: Text('Issue Type')),
      ];
    }
  }

  Map<String, List<PartRequest>> get groupedPendingRequests {
    if (selectedGroupBy == 'none') {
      return {'All': filteredPendingRequests};
    }

    final Map<String, List<PartRequest>> groups = {};

    for (final request in filteredPendingRequests) {
      String groupKey = _getRequestGroupKey(request, selectedGroupBy);
      groups.putIfAbsent(groupKey, () => []).add(request);
    }

    // Sort groups by key
    final sortedGroups = <String, List<PartRequest>>{};
    final sortedKeys = groups.keys.toList()..sort();

    for (final key in sortedKeys) {
      sortedGroups[key] = groups[key]!;
    }

    return sortedGroups;
  }

// Helper method to get group key for requests
  String _getRequestGroupKey(PartRequest request, String groupBy) {
    switch (groupBy) {
      case 'department':
        return request.department;
      case 'priority':
        return request.priority;
      case 'part_number':
        return request.partNumber;
      case 'technician':
        return request.technician;
      case 'date':
        return DateFormat('yyyy-MM-dd').format(request.requestDate);
      default:
        return 'All';
    }
  }

  Widget _buildGroupedPendingRequestsView() {
    final groups = groupedPendingRequests;

    if (groups.isEmpty) {
      return const Center(child: Text('No requests found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final groupKey = groups.keys.elementAt(index);
        final groupRequests = groups[groupKey]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            title: Row(
              children: [
                Icon(_getRequestGroupIcon(selectedGroupBy), size: 20),
                const SizedBox(width: 8),
                Text(
                  groupKey,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${groupRequests.length}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            children: groupRequests.map((request) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildRequestCard(request),
              );
            }).toList(),
          ),
        );
      },
    );
  }

// Get group icon for requests
  IconData _getRequestGroupIcon(String groupBy) {
    switch (groupBy) {
      case 'department':
        return Icons.business;
      case 'priority':
        return Icons.priority_high;
      case 'part_number':
        return Icons.inventory_2;
      case 'technician':
        return Icons.person;
      case 'date':
        return Icons.calendar_today;
      default:
        return Icons.group_work;
    }
  }

  String _getGroupKey(IssueTransaction transaction, String groupBy) {
    switch (groupBy) {
      case 'part_number':
        return _getTransactionPartNumber(transaction);
      case 'department':
        return _getTransactionDepartment(transaction);
      case 'date':
        return DateFormat('yyyy-MM-dd').format(transaction.createdAt);
      case 'issued_by':
        return transaction.createdBy;
      case 'issue_type':
        return transaction.issueType;
      default:
        return 'All';
    }
  }

  String _getTransactionDepartment(IssueTransaction transaction) {
    try {
      final request = allRequests.firstWhere((r) => r.requestId == transaction.requestId);
      return request.department;
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getTransactionPartNumber(IssueTransaction transaction) {
    try {
      final request = allRequests.firstWhere((r) => r.requestId == transaction.requestId);
      return request.partNumber;
    } catch (e) {
      return 'Unknown';
    }
  }

  IconData _getGroupIcon(String groupBy) {
    if (selectedTab == 'pending') {
      return _getRequestGroupIcon(groupBy);
    } else {
      switch (groupBy) {
        case 'part_number':
          return Icons.inventory_2;
        case 'department':
          return Icons.business;
        case 'date':
          return Icons.calendar_today;
        case 'issued_by':
          return Icons.person;
        case 'issue_type':
          return Icons.category;
        default:
          return Icons.group_work;
      }
    }
  }

  Widget _buildGroupedTransactionView() {
    final groups = groupedTransactions;

    if (groups.isEmpty) {
      return const Center(child: Text('No transactions found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final groupKey = groups.keys.elementAt(index);
        final groupTransactions = groups[groupKey]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            title: Row(
              children: [
                Icon(_getGroupIcon(selectedGroupBy), size: 20),
                const SizedBox(width: 8),
                Text(
                  groupKey,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${groupTransactions.length}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            children: groupTransactions.map((transaction) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildTransactionCard(transaction), // Use your existing method
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildRegularTransactionView() {
    final filteredTxns = filteredTransactions;
    bool isManager = currentUser != null &&
        currentUser!.role != null &&
        currentUser!.role!.toLowerCase() == 'manager';

    return Column(
      children: [
        if (searchQuery.isNotEmpty || selectedStartDate != null ||
            selectedEndDate != null || selectedPartNumberFilter != 'All' ||
            selectedDepartmentFilterHistory != 'All' ||
            (isManager && selectedIssuedByFilter != 'All'))
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isManager
                        ? (selectedIssuedByFilter != 'All'
                        ? 'Showing ${filteredTxns.length} transactions issued by $selectedIssuedByFilter'
                        : 'Showing ${filteredTxns.length} of ${recentTransactions.length} total transactions')
                        : 'Showing ${filteredTxns.length} of your transactions',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ),
                // Add role indicator for managers
                if (isManager) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange[300]!),
                    ),
                    child: Text(
                      'Manager View',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredTxns.length,
            itemBuilder: (context, index) {
              return _buildTransactionCard(filteredTxns[index]); // Use your existing method
            },
          ),
        ),
      ],
    );
  }
}


// Issue Dialog for confirming part issue
class IssueDialog extends StatefulWidget {
  final PartRequest request;
  final AvailableProduct product;
  final int availableStock;
  final void Function(int, String) onIssue;

  const IssueDialog({
    Key? key,
    required this.request,
    required this.product,
    required this.availableStock,
    required this.onIssue,
  }) : super(key: key);

  @override
  State<IssueDialog> createState() => _IssueDialogState();
}

class _IssueDialogState extends State<IssueDialog> {
  late TextEditingController quantityController;
  TextEditingController notesController = TextEditingController();
  bool isLoading = false;

  // field for dropdown
  late String selectedIssueType;

  UserModel? currentUser;

  // Check if stock is sufficient for full issue
  bool get hasEnoughStock => widget.availableStock >= widget.request.requestedQuantity;



  @override
  void initState() {
    super.initState();
    quantityController = TextEditingController();

    // Set default issue type based on stock availability
    selectedIssueType = hasEnoughStock ? 'Full Issue' : 'Partial Issue';

    // adjust quantity based on available stock on open (using IssueDao)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      quantityController.text = IssueDao.autoAdjustQuantity(
        issueType: selectedIssueType,
        availableStock: widget.availableStock,
        requestedQuantity: widget.request.requestedQuantity,
        hasEnoughStock: hasEnoughStock,
      );
    });

    quantityController.addListener(() {
      setState(() {
        selectedIssueType = IssueDao.handleQuantityChanged(
          currentIssueType: selectedIssueType,
          inputText: quantityController.text,
          requestedQuantity: widget.request.requestedQuantity,
          hasEnoughStock: hasEnoughStock,
        );
      });
    });
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await loadCurrentUser();
    setState(() {
      currentUser = user;  // ← Now this will work
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Issue Parts'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stock status warning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasEnoughStock ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasEnoughStock ? Colors.green[200]! : Colors.orange[200]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        hasEnoughStock ? Icons.check_circle : Icons.warning,
                        color: hasEnoughStock ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hasEnoughStock ? 'Sufficient Stock' : 'Insufficient Stock',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: hasEnoughStock ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Requested: ${widget.request.requestedQuantity}'),
                  Text('Available: ${widget.availableStock}'),
                  if (!hasEnoughStock) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Only partial issue or backorder is available.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Dropdown for issue type - conditional items
            DropdownButtonFormField<String>(
              value: selectedIssueType,
              items: IssueDao.getAvailableIssueTypes(hasEnoughStock),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedIssueType = value;
                    // 🔹 Use DAO to auto adjust qty when type changes
                    quantityController.text = IssueDao.autoAdjustQuantity(
                      issueType: selectedIssueType,
                      availableStock: widget.availableStock,
                      requestedQuantity: widget.request.requestedQuantity,
                      hasEnoughStock: hasEnoughStock,
                    );
                  });
                }
              },
              decoration: const InputDecoration(
                labelText: 'Issue Type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: quantityController,
              decoration: InputDecoration(
                labelText: 'Issue Quantity',
                border: const OutlineInputBorder(),
                helperText: selectedIssueType == 'Backorder'
                    ? 'Backorder: No parts issued now'
                    : 'Max available: ${widget.availableStock}',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
            const SizedBox(height: 16),

            // Notes field with suggestions for backorder
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: selectedIssueType == 'Backorder'
                        ? 'Backorder Notes (Required)'
                        : 'Notes (Optional)',
                    border: const OutlineInputBorder(),
                    helperText: selectedIssueType == 'Backorder'
                        ? 'Explain when stock will be available'
                        : null,
                  ),
                  maxLines: 3,
                ),

                // Show suggested notes for backorder
                if (selectedIssueType == 'Backorder') ...[
                  const SizedBox(height: 8),
                  Text(
                    'Suggested notes:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: IssueDao.getBackorderSuggestions().map((suggestion) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            notesController.text = suggestion;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Text(
                            suggestion.length > 40
                                ? '${suggestion.substring(0, 37)}...'
                                : suggestion,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap a suggestion to use it, or write your own',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isLoading
              ? null
              : () async {
            final result = IssueDao.handleIssue(
              issueType: selectedIssueType,
              notes: notesController.text,
              inputText: quantityController.text,
              availableStock: widget.availableStock,
              requestedQuantity: widget.request.requestedQuantity,
              hasEnoughStock: hasEnoughStock,
            );

            if (!(result["success"] as bool)) {
              _showError(result["error"]);
              return;
            }

            setState(() => isLoading = true);

            try {
              // 🔹 Call parent callback
              widget.onIssue(result["quantity"], result["notes"]);

              // 🔹 Insert into Firebase
              await IssueDao.insertIssue(
                requestId: widget.request.requestId, // assumes request has `id`
                issueType: selectedIssueType,
                quantity: result["quantity"],
                notes: result["notes"],
                requestedQuantity: widget.request.requestedQuantity,
                createdAt: DateTime.now(),
                createdBy: currentUser!.employeeId!,
              );

              // 🔹 Deduct stock only if it's not backorder
              if (selectedIssueType != "Backorder") {
                final warehouseDao = WarehouseDeductionDao();
                final deductionResult =
                await warehouseDao.processQuantityDeduction(
                  product: widget.product,
                  quantityToDeduct: result["quantity"],
                  reason: "Issued for Request ${widget.request.requestId}",
                );

                if (!deductionResult.success) {
                  _showError("Issue saved, but stock deduction failed: ${deductionResult.message}");
                }
              }

            } catch (e) {
              _showError('Failed to issue: $e');
            } finally {
              if (mounted) {
                setState(() => isLoading = false);
              }
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor:
            selectedIssueType == 'Backorder' ? Colors.orange : null,
          ),
          child: isLoading
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : Text(selectedIssueType == 'Backorder'
              ? 'Create Backorder'
              : 'Issue Parts'),
        ),
      ],
    );
  }


  void _showError(String message) {
    if (message.isEmpty) {
      return; // Guard against empty messages
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F), // Material Design error color
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    quantityController.dispose();
    notesController.dispose();
    super.dispose();
  }

}