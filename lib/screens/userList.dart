import 'package:assignment/dao/user_dao.dart';
import 'package:assignment/screens/add_user.dart';
import 'package:assignment/screens/edit_user.dart'; // Import the EditUserScreen
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

import '../models/user_model.dart';
import '../widgets/alert.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen>
    with TickerProviderStateMixin {
  List<UserModel> users = [];
  final ValueNotifier<List<UserModel>> _displayedUsers =
      ValueNotifier([]); // New: ValueNotifier for displayedUsers
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<String> _searchQuery = ValueNotifier('');
  String selectedRole = 'All';
  String selectedStatus = 'All';
  String selectedDepartment = 'All';
  String sortBy = 'name';
  bool isAscending = true;
  bool isGridView = false;
  bool showSuggestions = false;
  bool showActiveOnly = false;
  bool showRecentOnly = false;
  bool showVerifiedOnly = false;
  int currentPage = 0;
  int itemsPerPage = 20;
  bool isLoadingMore = false;
  Set<String> selectedForComparison = {};
  List<String> searchHistory = [];
  Timer? _debounceTimer;
  Timer? _refreshTimer; // Auto-refresh timer
  StreamSubscription? _firestoreSubscription; // Firestore listener
  late AnimationController _animationController;
  late AnimationController _filterAnimationController;
  late AnimationController _searchAnimationController;
  final userDao = UserDao();

  // Auto-refresh configuration
  static const Duration _autoRefreshInterval =
      Duration(minutes: 2); // Refresh every 2 minutes
  static const Duration _realTimeRefreshInterval =
      Duration(seconds: 10); // More frequent for real-time feel

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupScrollListener();
    _setupSearchListener();
    _loadAllUserData();
    _setupAutoRefresh();
    _setupFirestoreListener();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animationController.forward();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreUsers();
      }
    });
  }

  void _setupSearchListener() {
    _searchController.addListener(() {
      final value = _searchController.text;
      _performSearch(value);
    });
  }

  void _setupAutoRefresh() {
    _refreshTimer = Timer.periodic(_realTimeRefreshInterval, (timer) {
      _refreshUserData();
    });
  }

  void _setupFirestoreListener() {
    // This assumes your UserDao has a method to listen to Firestore changes
    _firestoreSubscription = userDao.getUsersStream().listen(
      (updatedUsers) {
        if (mounted) {
          setState(() {
            users = updatedUsers;
            _loadInitialUsers();
          });
          print('Real-time update: ${updatedUsers.length} users');
        }
      },
      onError: (error) {
        print('Firestore listener error: $error');
        // Fallback to periodic refresh if real-time fails
        _setupAutoRefresh();
      },
    );
  }

  Future<void> _refreshUserData() async {
    try {
      final latestUsers = await userDao.getUsers();
      if (mounted && _hasUserDataChanged(latestUsers)) {
        setState(() {
          users = latestUsers;
          _loadInitialUsers();
        });
        print('Auto-refresh: Updated ${users.length} users');

        // Show subtle indicator that data was refreshed
        _showRefreshIndicator();
      }
    } catch (e) {
      print('Auto-refresh error: $e');
    }
  }

  bool _hasUserDataChanged(List<UserModel> newUsers) {
    if (users.length != newUsers.length) return true;

    for (int i = 0; i < users.length; i++) {
      final oldUser = users[i];
      final newUser = newUsers.firstWhere(
        (u) => u.id == oldUser.id,
        orElse: () => UserModel(
            id: '',
            firstName: '',
            lastName: '',
            email: '',
            role: '',
            phoneNum: '',
            status: ''),
      );

      if (newUser.id!.isEmpty ||
          oldUser.firstName != newUser.firstName ||
          oldUser.lastName != newUser.lastName ||
          oldUser.email != newUser.email ||
          oldUser.role != newUser.role ||
          oldUser.status != newUser.status) {
        return true;
      }
    }
    return false;
  }

  void _showRefreshIndicator() {
    // Subtle refresh indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.refresh, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              const Text('Data updated', style: TextStyle(fontSize: 12)),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 100,
            left: 20,
            right: 20,
          ),
        ),
      );
    }
  }

  void _loadAllUserData() async {
    try {
      final allUser = await userDao.getUsers();
      setState(() {
        users = allUser;
        _loadInitialUsers();
      });
      print('Loaded ${users.length} users');
    } catch (e) {
      print('Error loading users: $e');
    }
  }

  void _loadInitialUsers() {
    final filteredUsers = _getFilteredAndSortedUsers();
    _displayedUsers.value =
        filteredUsers.take(itemsPerPage).toList(); // Update ValueNotifier
    currentPage = 1;
  }

  void _loadMoreUsers() {
    if (isLoadingMore) return;
    isLoadingMore = true;
    Future.delayed(const Duration(milliseconds: 500), () {
      final filteredUsers = _getFilteredAndSortedUsers();
      final startIndex = currentPage * itemsPerPage;
      final endIndex =
          math.min(startIndex + itemsPerPage, filteredUsers.length);
      if (startIndex < filteredUsers.length) {
        _displayedUsers.value = [
          ..._displayedUsers.value,
          ...filteredUsers.sublist(startIndex, endIndex)
        ]; // Update ValueNotifier
        currentPage++;
        isLoadingMore = false;
      } else {
        isLoadingMore = false;
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _filterAnimationController.dispose();
    _searchAnimationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _searchQuery.dispose();
    _displayedUsers.dispose(); // Dispose new ValueNotifier
    _debounceTimer?.cancel();
    _refreshTimer?.cancel(); // Cancel auto-refresh timer
    _firestoreSubscription?.cancel(); // Cancel Firestore listener
    super.dispose();
  }

  String _getFullName(UserModel user) =>
      '${user.firstName} ${user.lastName}'.trim();

  String _getInitials(UserModel user) {
    final firstName = user.firstName.isNotEmpty ? user.firstName[0] : '';
    final lastName = user.lastName.isNotEmpty ? user.lastName[0] : '';
    return (firstName + lastName).toUpperCase();
  }

  List<UserModel> _getFilteredAndSortedUsers() {
    List<UserModel> filtered = users.where((user) {
      String fullName = _getFullName(user).toLowerCase();
      bool matchesSearch = _searchQuery.value.isEmpty ||
          fullName.contains(_searchQuery.value.toLowerCase()) ||
          user.email.toLowerCase().contains(_searchQuery.value.toLowerCase());
      bool matchesRole = selectedRole == 'All' ||
          user.role.toLowerCase() == selectedRole.toLowerCase();
      bool matchesStatus =
          selectedStatus == 'All' || _getUserStatus(user) == selectedStatus;
      bool matchesActiveFilter = !showActiveOnly || _isUserActive(user);
      bool matchesRecentFilter = !showRecentOnly || _isRecentUser(user);
      return matchesSearch &&
          matchesRole &&
          matchesStatus &&
          matchesActiveFilter &&
          matchesRecentFilter;
    }).toList();

    filtered.sort((a, b) {
      int comparison;
      switch (sortBy) {
        case 'name':
          comparison = _getFullName(a).compareTo(_getFullName(b));
          break;
        case 'email':
          comparison = a.email.compareTo(b.email);
          break;
        case 'role':
          comparison = a.role.compareTo(b.role);
          break;
        case 'created':
          comparison = (a.createOn ?? DateTime.now())
              .compareTo(b.createOn ?? DateTime.now());
          break;
        case 'activity':
          comparison = _getLastActivity(a).compareTo(_getLastActivity(b));
          break;
        default:
          comparison = _getFullName(a).compareTo(_getFullName(b));
      }
      return isAscending ? comparison : -comparison;
    });

    return filtered;
  }

  bool _isUserActive(UserModel user) => user.status.toUpperCase() != 'INACTIVE';

  bool _isRecentUser(UserModel user) =>
      user.createOn != null &&
      DateTime.now().difference(user.createOn!).inDays <= 30;

  String _getUserStatus(UserModel user) =>
      _isUserActive(user) ? 'ACTIVE' : 'Inactive';

  DateTime _getLastActivity(UserModel user) => user.createOn ?? DateTime.now();

  void _performSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchQuery.value = query;
      _loadInitialUsers(); // Update displayedUsers via ValueNotifier
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.requestFocus(); // Ensure focus is retained
      }
      if (query.isNotEmpty && !searchHistory.contains(query)) {
        setState(() {
          searchHistory.insert(0, query);
          if (searchHistory.length > 10) {
            searchHistory = searchHistory.take(10).toList();
          }
        });
      }
    });
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery.value = '';
      _searchController.clear();
      selectedRole = 'All';
      selectedStatus = 'All';
      selectedDepartment = 'All';
      showActiveOnly = false;
      showRecentOnly = false;
      showVerifiedOnly = false;
      showSuggestions = false;
      _loadInitialUsers();
    });
  }

  // Manual refresh method
  Future<void> _onRefresh() async {
    await _refreshUserData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: Column(
          children: [
            _buildEnhancedSearchSection(theme),
            _buildFilterAndStatsRow(theme),
            Expanded(
              child: ValueListenableBuilder<List<UserModel>>(
                valueListenable: _displayedUsers,
                builder: (context, displayedUsers, child) {
                  return displayedUsers.isEmpty
                      ? _buildEmptyState()
                      : _buildUserDisplay();
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButtons(theme),
    );
  }

  Widget _buildEnhancedSearchSection(ThemeData theme) {
    return ValueListenableBuilder<String>(
      valueListenable: _searchQuery,
      builder: (context, searchQuery, child) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: _searchFocusNode.hasFocus
                            ? Border.all(color: theme.primaryColor, width: 2)
                            : null,
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            decoration: InputDecoration(
                              hintText:
                                  'Search users by name, email, or role...',
                              hintStyle: TextStyle(color: Colors.grey[600]),
                              prefixIcon:
                                  Icon(Icons.search, color: Colors.grey[600]),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Clear search button
                                  if (searchQuery.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 20),
                                      onPressed: () {
                                        _searchController.clear();
                                        _performSearch('');
                                        setState(() {
                                          showSuggestions = false;
                                        });
                                      },
                                    ),
                                ],
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            onTap: () {
                              setState(() {
                                showSuggestions = searchQuery.isEmpty &&
                                    searchHistory.isNotEmpty;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildViewToggle(),
                  _buildSortMenu(),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                        'Active Only', showActiveOnly, Colors.green, () {
                      setState(() {
                        showActiveOnly = !showActiveOnly;
                        _loadInitialUsers();
                      });
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('Recent', showRecentOnly, Colors.blue, () {
                      setState(() {
                        showRecentOnly = !showRecentOnly;
                        _loadInitialUsers();
                      });
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(
      String label, bool isSelected, Color color, VoidCallback onTap) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.transparent,
      selectedColor: color,
      side: BorderSide(color: color),
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildViewToggle() {
    return IconButton(
      icon: Icon(isGridView ? Icons.list : Icons.grid_view, size: 20),
      onPressed: () {
        setState(() {
          isGridView = !isGridView;
        });
      },
      tooltip: isGridView ? 'List View' : 'Grid View',
    );
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort, size: 20),
      color: Colors.white,
      tooltip: 'Sort Options',
      onSelected: (value) {
        setState(() {
          if (sortBy == value) {
            isAscending = !isAscending;
          } else {
            sortBy = value;
            isAscending = true;
          }
          _loadInitialUsers();
        });
      },
      itemBuilder: (context) => [
        _buildSortMenuItem('name', 'Name', Icons.person),
        _buildSortMenuItem('email', 'Email', Icons.email),
        _buildSortMenuItem('role', 'Role', Icons.admin_panel_settings),
        _buildSortMenuItem('created', 'Created Date', Icons.access_time),
        _buildSortMenuItem('activity', 'Last Activity', Icons.schedule),
      ],
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(String value,
      String label,
      IconData icon,) {
    final isSelected = sortBy == value;

    return PopupMenuItem(
      value: value,
      child: SizedBox(
        width: 140,
        child: Row(
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Icon(
                isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.value.isNotEmpty
                  ? 'Try adjusting your search terms or filters'
                  : 'Add your first user to get started',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (_hasActiveFilters()) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _clearAllFilters,
                child: const Text('Clear All Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterAndStatsRow(ThemeData theme) {
    final filteredUsers = _getFilteredAndSortedUsers();
    final filteredCount = filteredUsers.length;
    final activeCount = filteredUsers.where(_isUserActive).length;
    final inactiveCount = filteredUsers.length - activeCount;

    // List of roles for the dropdown
    const List<String> roleItems = ['All', 'Admin', 'Manager', 'Employee'];

    // Ensure selectedRole is a valid, title-cased value from the list
    String currentSelectedRole = selectedRole;
    if (!roleItems.contains(currentSelectedRole)) {
      currentSelectedRole = roleItems.firstWhere(
        (item) => item.toLowerCase() == selectedRole.toLowerCase(),
        orElse: () => 'All',
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Filter by Role',
                  labelStyle: TextStyle(color: Colors.grey[700]),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                value: currentSelectedRole,
                // Use the sanitized value
                dropdownColor: Colors.white,
                items: roleItems
                    .map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(role),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedRole = value!;
                    _loadInitialUsers();
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          _buildStatChip('$filteredCount total', theme.primaryColor),
          const SizedBox(width: 8),
          _buildStatChip('$activeCount active', Colors.green),
          const SizedBox(width: 8),
          _buildStatChip('$inactiveCount inactive', Colors.red[700]!),
        ],
      ),
    );
  }

  Widget _buildStatChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildUserDisplay() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _animationController,
          child: isGridView ? _buildGridView() : _buildListView(),
        );
      },
    );
  }

  Widget _buildListView() {
    return ValueListenableBuilder<List<UserModel>>(
      valueListenable: _displayedUsers,
      builder: (context, displayedUsers, child) {
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: displayedUsers.length + (isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == displayedUsers.length) {
              return _buildLoadingIndicator();
            }
            final user = displayedUsers[index];
            return _buildEnhancedUserCard(user, index);
          },
        );
      },
    );
  }

  Widget _buildGridView() {
    return ValueListenableBuilder<List<UserModel>>(
      valueListenable: _displayedUsers,
      builder: (context, displayedUsers, child) {
        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _getGridCrossAxisCount(),
            childAspectRatio: _getGridAspectRatio(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: displayedUsers.length + (isLoadingMore ? 2 : 0),
          itemBuilder: (context, index) {
            if (index >= displayedUsers.length) {
              return _buildLoadingCard();
            }
            final user = displayedUsers[index];
            return _buildEnhancedUserGridCard(user, index);
          },
        );
      },
    );
  }

  int _getGridCrossAxisCount() {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 600) return 3;
    if (screenWidth > 400) return 2;
    return 1;
  }

  double _getGridAspectRatio() {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 600) return 0.9;
    if (screenWidth > 400) return 1.1;
    return 1.2;
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 16,
              color: Colors.grey[200],
            ),
            const SizedBox(height: 8),
            Container(
              width: 100,
              height: 12,
              color: Colors.grey[200],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedUserCard(UserModel user, int index) {
    final isSelected =
        selectedForComparison.contains(user.email); // Using email as unique ID

    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: isSelected ? 8 : 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color:
                isSelected ? Theme.of(context).primaryColor : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showUserDetails(user),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildEnhancedAvatar(user),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _getFullName(user),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          _buildStatusChip(user),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).primaryColor,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildRoleChip(user.role),
                          const Spacer(),
                          if (user.createOn != null) ...[
                            Icon(Icons.access_time,
                                size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(user.createOn!),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                _buildActionMenu(user),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedUserGridCard(UserModel user, int index) {
    final isSelected = selectedForComparison.contains(user.email);

    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      child: Card(
        elevation: isSelected ? 8 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color:
                isSelected ? Theme.of(context).primaryColor : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showUserDetails(user),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusChip(user),
                    Row(
                      children: [
                        if (isSelected) ...[
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).primaryColor,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                        ],
                        _buildActionMenu(user),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildEnhancedAvatar(user, size: 60),
                const SizedBox(height: 12),
                Text(
                  _getFullName(user),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                _buildRoleChip(user.role),
                if (user.createOn != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(user.createOn!),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedAvatar(UserModel user, {double size = 50}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getAvatarGradient(_getFullName(user)),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _getAvatarGradient(_getFullName(user))[0].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              _getInitials(user),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.4,
              ),
            ),
          ),
          // Activity indicator
          if (_isUserActive(user))
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: size * 0.25,
                height: size * 0.25,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(UserModel user) {
    bool isActive = _isUserActive(user);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? Colors.green[200]! : Colors.red[200]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              color: isActive ? Colors.green[700] : Colors.red[700],
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    final color = _getRoleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActionMenu(UserModel user) {
    return PopupMenuButton<String>(
      color: Colors.white,
      icon: Icon(Icons.more_vert, color: Colors.grey[400]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) => _handleMenuAction(value, user),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(Icons.visibility, size: 18, color: Colors.blue),
              SizedBox(width: 12),
              Text('View Details'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18, color: Colors.orange),
              SizedBox(width: 12),
              Text('Edit'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'toggle',
          child: Row(
            children: [
              Icon(Icons.toggle_on, size: 18, color: Colors.green),
              SizedBox(width: 12),
              Text('Toggle Status'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 18, color: Colors.red),
              SizedBox(width: 12),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButtons(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selectedForComparison.isNotEmpty) ...[
          FloatingActionButton(
            heroTag: "compare_users",
            onPressed: _showUserComparison,
            backgroundColor: Colors.purple,
            child: const Icon(Icons.compare_arrows, color: Colors.white),
          ),
          const SizedBox(height: 16),
        ],
        FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddUserScreen(),
              ),
            );
            if (result == true) {
              _loadAllUserData();
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('Add User'),
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
        ),
      ],
    );
  }

  // Helper methods
  bool _hasActiveFilters() {
    return _searchQuery.value.isNotEmpty || // Fixed: Use _searchQuery.value
        selectedRole != 'All' ||
        selectedStatus != 'All' ||
        selectedDepartment != 'All' ||
        showActiveOnly ||
        showRecentOnly;
  }

  List<Color> _getAvatarGradient(String name) {
    final colors = [
      [Colors.blue[400]!, Colors.blue[600]!],
      [Colors.purple[400]!, Colors.purple[600]!],
      [Colors.green[400]!, Colors.green[600]!],
      [Colors.orange[400]!, Colors.orange[600]!],
      [Colors.pink[400]!, Colors.pink[600]!],
      [Colors.teal[400]!, Colors.teal[600]!],
      [Colors.indigo[400]!, Colors.indigo[600]!],
      [Colors.cyan[400]!, Colors.cyan[600]!],
    ];
    return colors[name.hashCode % colors.length];
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Admin':
        return Colors.red[600]!;
      case 'Manager':
        return Colors.purple[600]!;
      case 'Employee':
        return Colors.blue[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else if (difference < 30) {
      final weeks = (difference / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else {
      final months = (difference / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    }
  }

  void _handleMenuAction(String action, UserModel user) {
    switch (action) {
      case 'view':
        _showUserDetails(user);
        break;
      case 'edit':
        _editUser(user);
        break;
      case 'toggle':
        _toggleUserStatus(user);
        break;
      case 'delete':
        _deleteUser(user);
        break;
    }
  }

  void _editUser(UserModel user) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditUserScreen(user: user),
      ),
    );

    // If edit was successful, refresh the data
    if (result == true) {
      await _refreshUserData();
    }
  }

  void _showUserDetails(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEnhancedAvatar(user, size: 80),
              const SizedBox(height: 16),
              Text(
                _getFullName(user),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user.email,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildRoleChip(user.role),
                  const SizedBox(width: 12),
                  _buildStatusChip(user),
                ],
              ),
              if (user.createOn != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Created ${_formatDate(user.createOn!)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _editUser(user);
                      },
                      child: const Text('Edit'),
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

  void _showUserComparison() {
    final selectedUsers =
        users.where((u) => selectedForComparison.contains(u.email)).toList();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'User Comparison',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Property')),
                      DataColumn(label: Text('User 1')),
                      DataColumn(label: Text('User 2')),
                      DataColumn(label: Text('User 3')),
                      DataColumn(label: Text('User 4')),
                    ],
                    rows: [
                      DataRow(cells: [
                        const DataCell(Text('Name')),
                        ...List.generate(
                            4,
                            (index) => DataCell(Text(
                                index < selectedUsers.length
                                    ? _getFullName(selectedUsers[index])
                                    : '-'))),
                      ]),
                      DataRow(cells: [
                        const DataCell(Text('Email')),
                        ...List.generate(
                            4,
                            (index) => DataCell(Text(
                                index < selectedUsers.length
                                    ? selectedUsers[index].email
                                    : '-'))),
                      ]),
                      DataRow(cells: [
                        const DataCell(Text('Role')),
                        ...List.generate(
                            4,
                            (index) => DataCell(index < selectedUsers.length
                                ? _buildRoleChip(selectedUsers[index].role)
                                : const Text('-'))),
                      ]),
                      DataRow(cells: [
                        const DataCell(Text('Status')),
                        ...List.generate(
                            4,
                            (index) => DataCell(index < selectedUsers.length
                                ? _buildStatusChip(selectedUsers[index])
                                : const Text('-'))),
                      ]),
                      DataRow(cells: [
                        const DataCell(Text('Created')),
                        ...List.generate(
                            4,
                            (index) => DataCell(Text(index <
                                        selectedUsers.length &&
                                    selectedUsers[index].createOn != null
                                ? _formatDate(selectedUsers[index].createOn!)
                                : '-'))),
                      ]),
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

  void _toggleUserStatus(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.info_outline_rounded, color: Colors.red[600]),
            ),
            const SizedBox(width: 12),
            const Text('Change status'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to change the status?'),
            SizedBox(height: 16),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Store the ScaffoldMessenger and Navigator before the async gap.
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);

              navigator.pop(); // Close dialog

              final oldStatus = user.status;
              final newStatus =
                  oldStatus.toLowerCase() == 'active' ? 'Inactive' : 'Active';

              // Get fresh user record from DB
              final userDetails = await userDao.getUserByEmail(user.email);

              if (!mounted)
                return; // Check if widget is still mounted after async operation

              if (userDetails != null && newStatus.isNotEmpty) {
                // Update status in the object
                userDetails.status = newStatus;

                // Update DB
                await userDao.updateUser(userDetails.id!, userDetails);

                if (!mounted) return; // Check again after the second await

                // Update local users list and UI
                setState(() {
                  user.status = newStatus;
                });

                // Show snackbar with undo option
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                        '${_getFullName(user)} status changed to $newStatus'),
                    backgroundColor: Colors.green,
                    action: SnackBarAction(
                      label: 'Undo',
                      textColor: Colors.white,
                      onPressed: () async {
                        // Revert status in DB
                        userDetails.status = oldStatus;

                        await userDao.updateUser(userDetails.id!, userDetails);

                        // Check if widget is still mounted before updating UI
                        if (mounted) {
                          // Update local users list and UI
                          setState(() {
                            user.status = oldStatus;
                            _loadInitialUsers();
                          });
                        }
                      },
                    ),
                  ),
                );
              } else {
                debugPrint("User not found in DB for email: ${user.email}");

                // Check if widget is still mounted before showing error
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Error: User not found'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _deleteUser(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete User'),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: TextStyle(color: Colors.grey[700], fontSize: 16),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(
                text: _getFullName(user),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '? This action cannot be undone.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Store the ScaffoldMessenger and Navigator before the async gap.
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);

              navigator.pop(); // close dialog

              // 1. Delete from Firestore
              user.status = 'DELETED';
              final success = await userDao.updateUser(user.id!, user);

              if (!mounted) return;

              if (success == null) {
                // 2. Remove locally
                setState(() {
                  users.remove(user);
                  _displayedUsers.value = _displayedUsers.value
                      .where((u) => u.id != user.id)
                      .toList();
                });

                // 3. Show SnackBar with Undo option
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('${_getFullName(user)} has been deleted'),
                    backgroundColor: Colors.red,
                    action: SnackBarAction(
                      label: 'Undo',
                      textColor: Colors.white,
                      onPressed: () async {
                        // 4. Reactive the user
                        user.status = 'Active';
                        await userDao.updateUser(user.id!, user);

                        if (!mounted) return;

                        // 5. Update UI
                        setState(() {
                          users.add(user);
                          _displayedUsers.value = [
                            ..._displayedUsers.value,
                            user
                          ];
                        });
                      },
                    ),
                  ),
                );
              } else {
                _showSnackBar(
                  'Failed to delete user',
                  Colors.red,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color backgroundColor,
      {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              backgroundColor == Colors.green ? Icons.check_circle : Icons.info,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: action,
      ),
    );
  }
}
