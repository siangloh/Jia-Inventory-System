import 'package:flutter/material.dart';
import '../../services/adjustment/debouncer_service.dart';
import '../../services/adjustment/snackbar_manager.dart';

abstract class BaseListWidget<T> extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  
  const BaseListWidget({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
  }) : super(key: key);
}

abstract class BaseListState<T, W extends BaseListWidget<T>> extends State<W> 
    with TickerProviderStateMixin {
  // Controllers
  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final FocusNode searchFocusNode = FocusNode();
  final Debouncer debouncer = Debouncer(delay: Duration(milliseconds: 300));
  
  // Animation controllers
  late AnimationController animationController;
  late AnimationController filterAnimationController;
  late AnimationController expandController;
  
  // Data
  List<T> allItems = [];
  List<T> filteredItems = [];
  List<T> displayedItems = [];
  
  // State
  String searchQuery = '';
  String selectedTimeFilter = 'all';
  String sortBy = 'date';
  bool sortAscending = false;
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMoreItems = true;
  
  // Pagination
  int currentPage = 0;
  final int itemsPerPage = 15;
  
  // Expanded cards
  Set<String> expandedCards = {};
  
  // Statistics
  Map<String, dynamic> stats = {};
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupScrollListener();
    loadData();
  }
  
  void _initializeAnimations() {
    animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    expandController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    animationController.forward();
  }
  
  void _setupScrollListener() {
    scrollController.addListener(() {
      if (scrollController.position.pixels >= 
          scrollController.position.maxScrollExtent - 200) {
        _loadMoreItems();
      }
    });
  }
  
  // Abstract methods to be implemented by subclasses
  Future<void> loadData();
  List<T> applyCustomFilters(List<T> items);
  Map<String, dynamic> calculateStats(List<T> items);
  Widget buildCard(T item);
  Widget buildExpandedDetails(T item);
  Widget buildQuickFilters();
  List<String> getSortOptions();
  int compareItems(T a, T b, String sortBy);
  String getItemId(T item);
  
  // Common filtering and sorting logic
  void applyFiltersAndSort() {
    
    List<T> filtered = List.from(allItems);
    
    // Apply search
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((item) => 
        matchesSearch(item, searchQuery)).toList();
    }
    
    // Apply time filter
    filtered = _applyTimeFilter(filtered);
    
    // Apply custom filters from subclass
    filtered = applyCustomFilters(filtered);
    
    // Sort
    filtered.sort((a, b) {
      int comparison = compareItems(a, b, sortBy);
      return sortAscending ? comparison : -comparison;
    });
    
    
    if (mounted) {
      setState(() {
        filteredItems = filtered;
        stats = calculateStats(filtered);
        currentPage = 0;
        displayedItems = [];
        hasMoreItems = true;
      });
    }
    
    
    _loadInitialPage();
  }
  
  List<T> _applyTimeFilter(List<T> items) {
    if (selectedTimeFilter == 'all') return items;
    
    final now = DateTime.now();
    Duration duration;
    
    switch (selectedTimeFilter) {
      case 'today':
        duration = Duration(days: 1);
        break;
      case 'week':
        duration = Duration(days: 7);
        break;
      case 'month':
        duration = Duration(days: 30);
        break;
      default:
        return items;
    }
    
    final cutoff = now.subtract(duration);
    return items.where((item) => 
      getItemDate(item).isAfter(cutoff)).toList();
  }
  
  void _loadInitialPage() {
    final endIndex = (itemsPerPage < filteredItems.length) 
        ? itemsPerPage 
        : filteredItems.length;
    
    if (mounted) {
      setState(() {
        displayedItems = filteredItems.sublist(0, endIndex);
        currentPage = 1;
        hasMoreItems = filteredItems.length > itemsPerPage;
      });
    }
  }
  
  void _loadMoreItems() {
    if (isLoadingMore || !hasMoreItems) return;
    
    if (mounted) {
      setState(() => isLoadingMore = true);
    }
    
    Future.delayed(Duration(milliseconds: 300), () {
      if (!mounted) return; // Exit if widget is disposed
      
      final startIndex = currentPage * itemsPerPage;
      final endIndex = ((startIndex + itemsPerPage) < filteredItems.length)
          ? (startIndex + itemsPerPage)
          : filteredItems.length;
      
      if (startIndex < filteredItems.length) {
        if (mounted) {
          setState(() {
            displayedItems.addAll(filteredItems.sublist(startIndex, endIndex));
            currentPage++;
            hasMoreItems = endIndex < filteredItems.length;
            isLoadingMore = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            hasMoreItems = false;
            isLoadingMore = false;
          });
        }
      }
    });
  }
  
  void onSearchChanged(String value) {
    debouncer.run(() {
      if (mounted) {
        setState(() => searchQuery = value);
        applyFiltersAndSort();
      }
    });
  }
  
  void toggleCardExpansion(String id) {
    setState(() {
      if (expandedCards.contains(id)) {
        expandedCards.remove(id);
      } else {
        expandedCards.add(id);
      }
    });
  }
  
  void clearAllFilters() {
    setState(() {
      searchController.clear();
      searchQuery = '';
      selectedTimeFilter = 'all';
      sortBy = 'date';
      sortAscending = false;
    });
    applyFiltersAndSort();
  }
  
  // Abstract helper methods
  bool matchesSearch(T item, String query);
  DateTime getItemDate(T item);
  
  @override
  void dispose() {
    searchController.dispose();
    scrollController.dispose();
    searchFocusNode.dispose();
    debouncer.cancel();
    animationController.dispose();
    filterAnimationController.dispose();
    expandController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        color: Colors.grey[50],
        child: Column(
          children: [
            _buildHeader(),
            _buildStatsBar(),
            _buildFilterSection(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await loadData();
                    SnackbarManager().showSuccessMessage(
                      context,
                      message: 'Data refreshed successfully',
                    );
                  },
                  icon: Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Enhanced search bar
            TextField(
              controller: searchController,
              focusNode: searchFocusNode,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search, size: 20),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 20),
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: _buildStatItems(),
      ),
    );
  }
  
  List<Widget> _buildStatItems() {
    return stats.entries.map((entry) {
      return Expanded(
        child: _buildStatItem(
          label: entry.key,
          value: entry.value.toString(),
        ),
      );
    }).toList();
  }
  
  Widget _buildStatItem({
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Time filter chips
                ..._buildTimeFilterChips(),
                const SizedBox(width: 12),
                // Sort button
                _buildSortButton(),
                const SizedBox(width: 8),
                // Clear filters
                if (searchQuery.isNotEmpty || selectedTimeFilter != 'all')
                  TextButton.icon(
                    onPressed: clearAllFilters,
                    icon: Icon(Icons.clear, size: 16),
                    label: Text('Clear'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Custom quick filters from subclass
          buildQuickFilters(),
        ],
      ),
    );
  }
  
  List<Widget> _buildTimeFilterChips() {
    final filters = [
      {'label': 'All', 'value': 'all'},
      {'label': 'Today', 'value': 'today'},
      {'label': 'This Week', 'value': 'week'},
      {'label': 'This Month', 'value': 'month'},
    ];
    
    return filters.map((filter) {
      final isSelected = selectedTimeFilter == filter['value'];
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(filter['label']!),
          selected: isSelected,
          onSelected: (selected) {
            setState(() => selectedTimeFilter = filter['value']!);
            applyFiltersAndSort();
          },
          selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
          checkmarkColor: Theme.of(context).primaryColor,
        ),
      );
    }).toList();
  }
  
  Widget _buildSortButton() {
    return PopupMenuButton<String>(
      offset: Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.sort, size: 18),
            SizedBox(width: 6),
            Text('Sort', style: TextStyle(fontSize: 13)),
            Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
      itemBuilder: (context) => getSortOptions().map((option) => 
        PopupMenuItem(
          value: option,
          child: Row(
            children: [
              Text(option),
              if (sortBy == option)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
            ],
          ),
        )
      ).toList(),
      onSelected: (value) {
        setState(() {
          if (sortBy == value) {
            sortAscending = !sortAscending;
          } else {
            sortBy = value;
            sortAscending = false;
          }
        });
        applyFiltersAndSort();
      },
    );
  }
  
  Widget _buildContent() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (filteredItems.isEmpty) {
      return _buildEmptyState();
    }
    
    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: displayedItems.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == displayedItems.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          return AnimatedBuilder(
            animation: animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: animationController,
                  curve: Interval(
                    (index / 20).clamp(0.0, 1.0),
                    1.0,
                    curve: Curves.easeOut,
                  ),
                ),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animationController,
                    curve: Interval(
                      (index / 20).clamp(0.0, 1.0),
                      1.0,
                      curve: Curves.easeOut,
                    ),
                  )),
                  child: buildCard(displayedItems[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.icon,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No items found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            searchQuery.isNotEmpty 
                ? 'Try adjusting your search or filters'
                : 'No data available',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: clearAllFilters,
            icon: Icon(Icons.refresh, color: Colors.white),
            label: Text(
              'Clear Filters',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}