import 'package:assignment/screens/profile.dart';
import 'package:assignment/services/login/load_user_data.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../dao/user_dao.dart';
import '../models/user_model.dart';
import '../services/login/user_data_service.dart';

class AppHeader extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onProfilePressed;

  const AppHeader({
    Key? key,
    required this.title,
    this.actions,
    this.onMenuPressed,
    this.onProfilePressed,
  }) : super(key: key);

  @override
  State<AppHeader> createState() => _AppHeaderState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);
}

class _AppHeaderState extends State<AppHeader> with TickerProviderStateMixin {
  AnimationController? _titleController;
  Animation<double>? _titleAnimation;

  UserModel? user;
  final userDao = UserDao();
  StreamSubscription<UserModel?>? _userSubscription;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupRealtimeUserData();
  }

  void _setupAnimations() {
    _titleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _titleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _titleController!,
      curve: Curves.easeInOut,
    ));

    _titleController!.forward();
  }

  void _setupRealtimeUserData() {
    // Initial load
    _loadUserData();

    // Set up real-time updates - refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadUserData();
    });

    // Listen to authentication state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.tokenRefreshed) {
        _loadUserData();
      } else if (data.event == AuthChangeEvent.signedOut) {
        setState(() {
          user = null;
        });
      }
    });
  }

  Future<void> _loadUserData() async {
    try {
      final currentUser = await loadCurrentUser();
      if (mounted && currentUser != user) {
        setState(() {
          user = currentUser;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      // Only clear user if we're sure they're signed out
      if (e.toString().contains('not authenticated')) {
        setState(() {
          user = null;
        });
      }
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

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }

  @override
  void dispose() {
    _titleController?.dispose();
    _userSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[800]!,
            Colors.blue[700]!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: AppBar(
        title: Row(
          children: [
            // Animated title icon - with null safety check
            if (_titleAnimation != null)
              AnimatedBuilder(
                animation: _titleAnimation!,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _titleAnimation!.value,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        _getTitleIcon(),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  );
                },
              )
            else
              // Fallback when animation is not ready
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  _getTitleIcon(),
                  color: Colors.white,
                  size: 20,
                ),
              ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            onPressed:
                widget.onMenuPressed ?? () => Scaffold.of(context).openDrawer(),
            padding: EdgeInsets.zero,
          ),
        ),
        actions: [
          // Profile Avatar - Direct navigation to profile page
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: widget.onProfilePressed ?? _navigateToProfile,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.3),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: StreamBuilder<UserModel?>(
                  stream: Stream.periodic(const Duration(seconds: 5))
                      .asyncMap((_) => loadCurrentUser()),
                  initialData: user,
                  builder: (context, snapshot) {
                    final currentUser = snapshot.data ?? user;

                    return FutureBuilder<String?>(
                      future: _getSignedUrl(currentUser?.profilePhotoUrl),
                      builder: (context, urlSnapshot) {
                        final signedUrl = urlSnapshot.data;

                        return CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          backgroundImage:
                              (signedUrl != null && signedUrl.isNotEmpty)
                                  ? NetworkImage(signedUrl)
                              : null,
                          child: (signedUrl == null || signedUrl.isEmpty)
                              ? const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 22,
                                )
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),

          if (widget.actions != null) ...widget.actions!,
        ],
      ),
    );
  }

  IconData _getTitleIcon() {
    switch (widget.title.toLowerCase()) {
      case 'dashboard':
        return Icons.dashboard_rounded;
      case 'products':
      case 'inventory':
        return Icons.inventory_2_rounded;
      case 'orders':
        return Icons.shopping_cart_rounded;
      case 'suppliers':
        return Icons.business_rounded;
      case 'analytics':
        return Icons.analytics_rounded;
      case 'users':
        return Icons.people_rounded;
      case 'settings':
        return Icons.settings_rounded;
      case 'help & support':
        return Icons.help_rounded;
      case 'product names':
        return Icons.label_rounded;
      case 'product brands':
        return Icons.branding_watermark_rounded;
      case 'categories':
        return Icons.category_rounded;
      default:
        return Icons.apps_rounded;
    }
  }
}