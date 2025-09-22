import 'package:assignment/screens/dashboard.dart';
import 'package:assignment/screens/userList.dart';
import 'package:assignment/widgets/header.dart';
import 'package:assignment/widgets/sidebar.dart';
import 'package:flutter/material.dart';

class MainLayout extends StatefulWidget {
  final Widget child;
  final String title;
  final String currentRoute;
  final bool showSearch;
  final List<Widget>? headerActions;

  const MainLayout({
    Key? key,
    required this.child,
    required this.title,
    required this.currentRoute,
    this.showSearch = false,
    this.headerActions,
  }) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  void _handleNavigation(String route) {
    // Handle navigation based on route
    switch (route) {
      case 'dashboard':
        // Navigate to dashboard
        Navigator.pushReplacementNamed(context, '/dashboard');

        break;

      case 'products':
        // Navigate to products
        Navigator.pushReplacementNamed(context, '/products');
        break;
      case 'orders':
        // Navigate to orders
        Navigator.pushReplacementNamed(context, '/orders');
        break;
      case 'stock_placement':
      // Navigate to orders
        Navigator.pushReplacementNamed(context, '/stock_placement');
        break;
      case 'store_product_list':
      // Navigate to orders
        Navigator.pushReplacementNamed(context, '/store_product_list');
        break;
      case 'part-issues':
        Navigator.pushReplacementNamed(context, '/part-issues');
        break;
      case 'product_master_list':
        // Navigate to orders
        Navigator.pushReplacementNamed(context, '/product_master_list');
        break;
      case 'product_items':
        // Navigate to orders
        Navigator.pushReplacementNamed(context, '/product_items');
        break;
      case 'product':
        // Navigate to orders
        Navigator.pushReplacementNamed(context, '/product');
        break;
      case 'categories':
        // Navigate to orders
        Navigator.pushReplacementNamed(context, '/categories');
        break;
      case 'product_name_management':
        // Navigate to orders
        Navigator.pushReplacementNamed(context, '/product_name_management');
        break;
      case 'product_brand_management':
        // Navigate to orders
        Navigator.pushReplacementNamed(context, '/product_brand_management');
        break;
      case 'deduct-testing' :
        Navigator.pushReplacementNamed(context, '/deduct-testing');
      case 'low-stock':
        // Navigate to low stock
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigating to Low Stock Items')),
        );
        break;
      case 'users':
        // Navigate to users list
        Navigator.pushReplacementNamed(context, '/users');
        break;
      case 'adjustment/hub':
        // Navigate to inventory adjustment hub
        Navigator.pushReplacementNamed(context, '/adjustment/hub');
        break;
      case 'logout':
        // Navigate to users list
        Navigator.pushReplacementNamed(context, '/login');
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Navigating to ${route.toUpperCase()}')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: widget.title,
        // showSearch: widget.showSearch,
        actions: widget.headerActions,
      ),
      drawer: AppSidebar(
        currentRoute: widget.currentRoute,
        onNavigate: _handleNavigation,
      ),
      body: widget.child,
    );
  }
}
