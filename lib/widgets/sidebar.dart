import 'package:assignment/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../dao/user_dao.dart';
import '../services/login/load_user_data.dart';
import '../services/login/remember_me_service.dart';

class AppSidebar extends StatefulWidget {
  final String currentRoute;
  final Function(String)? onNavigate;

  const AppSidebar({
    Key? key,
    required this.currentRoute,
    this.onNavigate,
  }) : super(key: key);

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Track expanded sections
  final Map<String, bool> _expandedSections = {};

  UserModel? user;
  final userDao = UserDao();

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();

    _loadUserData();
    _initializeExpandedSections();
  }

  void _initializeExpandedSections() {
    // Auto-expand sections that contain the current route
    final currentRoute = widget.currentRoute;
    if (_isRouteInSection(currentRoute, 'warehouse')) {
      _expandedSections['warehouse'] = true;
    }
    if (_isRouteInSection(currentRoute, 'products')) {
      _expandedSections['products'] = true;
    }
  }

  bool _isRouteInSection(String route, String section) {
    final warehouseRoutes = ['store_product_list', 'stock_placement', 'adjustment/hub'];
    final productRoutes = ['product_master_list', 'categories', 'product_name_management', 'product_brand_management'];

    return switch (section) {
      'warehouse' => warehouseRoutes.contains(route),
      'products' => productRoutes.contains(route),
      _ => false,
    };
  }

  Future<void> _loadUserData() async {
    try {
      final loadedUser = await loadCurrentUser();
      setState(() {
        user = loadedUser;
      });
      print('Track success');
      if (user == null) {
        print("Data no Exist");
      } else {
        print('Data Exist');
      }
    } catch (e) {
      print('Please try later...');
    }
  }

  Future<String?> _getSignedUrl(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return null;

    try {
      return await Supabase.instance.client.storage
          .from('profile_photos')
          .createSignedUrl(filePath, 3600);
    } catch (e) {
      print("Error generating signed URL: $e");
      return null;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      elevation: 16,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey[50]!,
              Colors.white,
              Colors.grey[50]!,
            ],
          ),
        ),
        child: Column(
          children: [
            // Enhanced Sidebar Header
            _buildEnhancedHeader(context),

            // Navigation Items
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      // Dashboard
                      _buildNavItem(
                        context,
                        'Dashboard',
                        Icons.dashboard_rounded,
                        'dashboard',
                        gradient: LinearGradient(
                          colors: [Colors.blue[400]!, Colors.blue[600]!],
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Warehouse Management
                      _buildExpandableSection(
                        'Warehouse',
                        Icons.warehouse,
                        [
                          _NavSubItem('Warehouse Inventory', Icons.inventory,
                              'store_product_list'),
                          _NavSubItem('Stock Placement', Icons.place,
                              'stock_placement'),
                          _NavSubItem('Inventory Adjustment',
                              Icons.edit_note_rounded, 'adjustment/hub'),
                        ],
                        Colors.purple,
                        'warehouse',
                      ),

                      // Product Management
                      _buildExpandableSection(
                        'Products',
                        Icons.style,
                        [
                          _NavSubItem(
                              'Product', Icons.apps, 'product_master_list'),
                          _NavSubItem(
                              'Categories', Icons.category, 'categories'),
                          _NavSubItem('Product Name', Icons.label,
                              'product_name_management'),
                          _NavSubItem('Product Brand', Icons.branding_watermark,
                              'product_brand_management'),
                        ],
                        Colors.teal,
                        'products',
                      ),

                      // Orders
                      _buildNavItem(
                        context,
                        'Orders',
                        Icons.shopping_cart_rounded,
                        'orders',
                        gradient: LinearGradient(
                          colors: [Colors.green[400]!, Colors.green[600]!],
                        ),
                      ),

                      _buildNavItem(
                        context,
                        'Part Issues',
                        Icons.report_problem,
                        'part-issues',
                        gradient: LinearGradient(
                          colors: [Colors.orange[400]!, Colors.orange[600]!],
                        ),
                      ),

                      // Users Management
                      _buildNavItem(
                        context,
                        'Users',
                        Icons.people_rounded,
                        'users',
                        gradient: LinearGradient(
                          colors: [Colors.indigo[400]!, Colors.indigo[600]!],
                        ),
                      ),

                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.grey[300]!,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Enhanced Sidebar Footer
            _buildEnhancedFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedHeader(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                color: Colors.grey[200]!,
                width: 1.0,
              ))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Animated Icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[400]!, Colors.blue[600]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.car_repair,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 16),

          // Animated Text
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1200),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: const Text(
                    'JiaCar',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      BuildContext context,
      String title,
      IconData icon,
      String route, {
        String? badge,
        required LinearGradient gradient,
      }) {
    final isSelected = widget.currentRoute == route;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pop(context);
            widget.onNavigate?.call(route);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: isSelected ? gradient : null,
              color: isSelected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? null
                  : Border.all(color: Colors.grey[200]!, width: 1),
              boxShadow: isSelected
                  ? [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : gradient.colors.first.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : gradient.colors.first,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[800],
                      fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (badge != null) _buildBadge(badge),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSection(
      String title,
      IconData icon,
      List<_NavSubItem> items,
      MaterialColor color,
      String sectionKey,
      ) {
    final isSectionActive = _isRouteInSection(widget.currentRoute, sectionKey);
    final isExpanded = _expandedSections[sectionKey] ?? false;

    // Auto-expand when section becomes active
    if (isSectionActive && !isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _expandedSections[sectionKey] = true;
          });
        }
      });
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: isSectionActive
            ? Border.all(color: color.shade200, width: 1.5)
            : Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: isSectionActive ? [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (expanded) {
            setState(() {
              _expandedSections[sectionKey] = expanded;
            });
          },
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: isSectionActive
                  ? LinearGradient(
                colors: [color.shade400, color.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : LinearGradient(
                colors: [color.shade100, color.shade200],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSectionActive ? [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: Icon(
                icon,
                color: isSectionActive ? Colors.white : color[700],
                size: 20
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isSectionActive ? color[800] : Colors.grey[800],
              fontWeight: isSectionActive ? FontWeight.w700 : FontWeight.w500,
              fontSize: 15,
            ),
          ),
          iconColor: isSectionActive ? color[700] : color[600],
          collapsedIconColor: isSectionActive ? color[700] : Colors.grey[600],
          initiallyExpanded: isExpanded,
          childrenPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
          children: items
              .map((item) => _buildSubNavItem(context, item, color, sectionKey))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildSubNavItem(
      BuildContext context, _NavSubItem item, MaterialColor color, String sectionKey) {
    final isSelected = widget.currentRoute == item.route;
    final isSectionActive = _isRouteInSection(widget.currentRoute, sectionKey);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pop(context);
            widget.onNavigate?.call(item.route);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: isSelected ? LinearGradient(
                colors: [color.shade100, color.shade50],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ) : null,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: color.shade300, width: 1.5)
                  : null,
              boxShadow: isSelected ? [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                      colors: [color.shade400, color.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : null,
                    color: isSelected ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  child: Icon(
                    item.icon,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : (isSectionActive ? color[600] : Colors.grey[600]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      color: isSelected
                          ? color[800]
                          : (isSectionActive ? color[600] : Colors.grey[700]),
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : (isSectionActive ? FontWeight.w600 : FontWeight.w500),
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.shade600, color.shade800],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[400]!, Colors.red[600]!],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEnhancedFooter(BuildContext context) {
    if (user == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.grey[200]!,
              width: 1.0,
            ),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Loading user data...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 45,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<UserModel?>(
      stream: getUserStream(user!.id.toString()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.grey[200]!,
                  width: 1.0,
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 16,
                            width: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 20,
                            width: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.grey[200]!,
                  width: 1.0,
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.red[600],
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Error loading user data',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _handleLogout(context),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[50],
                      foregroundColor: Colors.red[600],
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red[200]!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final UserModel? streamUser = snapshot.data;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.grey[200]!,
                width: 1.0,
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: FutureBuilder<String?>(
                      future: _getSignedUrl(streamUser?.profilePhotoUrl),
                      builder: (context, imgSnapshot) {
                        final signedUrl = imgSnapshot.data;

                        return CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white,
                          backgroundImage:
                          (signedUrl != null && signedUrl.isNotEmpty)
                              ? NetworkImage(signedUrl)
                              : null,
                          child: (signedUrl == null || signedUrl.isEmpty)
                              ? Icon(
                            Icons.person_rounded,
                            color: Colors.blue[600],
                            size: 24,
                          )
                              : null,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          streamUser == null
                              ? 'Default User'
                              : '${streamUser.firstName} ${streamUser.lastName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            streamUser?.role ?? 'No Role',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (streamUser != null)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _handleLogout(context),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red[600],
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.red[200]!),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.logout_rounded, color: Colors.red[600]),
            ),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to logout?'),
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
              Navigator.pop(context);
              await RememberMeService.clearAutoLogin();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                    (Route<dynamic> route) => false,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logged out successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _NavSubItem {
  final String title;
  final IconData icon;
  final String route;

  _NavSubItem(this.title, this.icon, this.route);
}