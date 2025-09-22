import 'package:assignment/screens/adjustment/lists/return_history_list_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'widgets/main_layout.dart';
import 'database_service.dart';
import 'screens/login.dart';
import 'screens/dashboard.dart';

// ADD: IMPORT FOR INVENTORY ADJUSTMENT MODULE
import 'screens/adjustment/adjustment_hub.dart';
import 'screens/adjustment/receive_stock_screen.dart';
import 'screens/adjustment/return_stock_screen.dart';
import 'screens/adjustment/report_discrepancy_screen.dart';
import 'screens/adjustment/return_stock_screen.dart';
import 'screens/adjustment/lists/received_item_list_screen.dart';
import 'screens/adjustment/lists/discrepancy_report_list_screen.dart';

// ADD: IMPORT FOR PRODUCT MANAGEMENT MODULE
import 'screens/product/product_brand.dart';
import 'screens/product/product_category_management.dart';
import 'screens/product/product_list.dart';
import 'screens/product/product_name.dart';
import 'screens/userList.dart';

// ADD: IMPORT FOR PURCHASE ORDER MODULE
import 'screens/purchase_order/purchase_order_list.dart';

// ADD: IMPORT FOR RECEIVE INVENTORY MODULE
import 'screens/receive_inventory/receive_inventory_screen.dart';
import 'screens/receive_inventory/deduct_qty_screen.dart';

// ADD: IMPORT FOR WAREHOUSE MODULE
import 'screens/warehouse/warehouse_map_screen.dart';
import 'screens/warehouse/warehouse_inventory_screen.dart';

// ADD: IMPORT FOR ISSUE MODULE
import 'screens/issue/partIssues.dart';

// ADD: IMPORT FOR FIREBASE AUTH
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('Firebase initialized successfully');
    } else {
      print(
          'Firebase already initialized (${Firebase.apps.length} apps found)');
    }
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      print('Firebase already initialized, continuing...');
    } else {
      print('Firebase initialization error: ${e.message}');
      rethrow;
    }
  } catch (e) {
    print('Unexpected Firebase error: $e');
  }

  // 🔥 SUPABASE INITIALIZATION
  await Supabase.initialize(
    url: 'https://mrhmlqbicioflyiycmuq.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1yaG1scWJpY2lvZmx5aXljbXVxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1Nzk0Njk0MywiZXhwIjoyMDczNTIyOTQzfQ.eGtfc6j93EP4P8q86JzNPxOx-mQNr2sLw4n3ysohnL4',
  );

  // 🔥 DATABASE SERVICE INITIALIZATION
  final dbService = DatabaseService();
  final db = await dbService.database;
  print('=== DATABASE PATH ===');
  print(db.path);
  print('====================');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory Management',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LoginScreen(), // Use LoginScreen as the home page
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const MainLayout(
              title: 'Dashboard',
              currentRoute: 'dashboard',
              showSearch: true,
              // child: const Center(child: Text('Dashboard Content')),
              child: DashboardScreen(),
            ),
        '/categories': (context) => const MainLayout(
              title: 'Categories',
              currentRoute: 'categories',
              showSearch: true,
              child: CategoryManagementScreen(),
            ),
        '/product_name_management': (context) => const MainLayout(
              title: 'Product Name Management',
              currentRoute: 'product_name_management',
              showSearch: true,
              child: ProductNameManagementScreen(),
            ),
        '/product_brand_management': (context) => const MainLayout(
              title: 'Product Brand Management',
              currentRoute: 'product_brand_management',
              showSearch: true,
              child: ProductBrandManagementScreen(),
            ),
        '/stock-levels': (context) => const MainLayout(
              title: 'Stock Levels',
              currentRoute: 'stock-levels',
              showSearch: true,
              child: const Center(child: Text('Stock Levels Content')),
            ),
        '/low-stock': (context) => const MainLayout(
              title: 'Low Stock',
              currentRoute: 'low-stock',
              showSearch: true,
              child: const Center(child: Text('Low Stock Content')),
            ),
        '/deduct-testing': (context) => const MainLayout(
              title: 'Deduct Testing',
              currentRoute: 'deduct-testing',
              showSearch: true,
              child: DeductQtyScreen(),
            ),
        '/orders': (context) => const MainLayout(
              title: 'Orders',
              currentRoute: 'orders',
              showSearch: true,
              child: PurchaseOrderListScreen(),
            ),
        '/stock_placement': (context) => const MainLayout(
              title: 'Stock Placement',
              currentRoute: 'stock_placement',
              showSearch: true,
              child: ReceiveInventoryScreenWithAllocation(),
            ),
        '/store_product_list': (context) => const MainLayout(
              title: 'Warehouse Inventory',
              currentRoute: 'store_product_list',
              showSearch: true,
              child: WarehouseInventoryScreen(),
            ),
        '/product_master_list': (context) => const MainLayout(
              title: 'Product',
              currentRoute: 'product_master_list',
              showSearch: true,
              child: ProductListScreen(),
            ),
        '/test_warehouse': (context) => const MainLayout(
              title: 'Warehouse',
              currentRoute: 'warehouse',
              showSearch: true,
              child: const Center(child: Text('WarehouseMapScreen')),
            ),
        '/suppliers': (context) => const MainLayout(
              title: 'Suppliers',
              currentRoute: 'suppliers',
              showSearch: true,
              child: const Center(child: Text('Suppliers Content')),
            ),
        '/sales-reports': (context) => const MainLayout(
              title: 'Sales Reports',
              currentRoute: 'sales-reports',
              showSearch: false,
              child: const Center(child: Text('Sales Reports Content')),
            ),
        '/inventory-reports': (context) => const MainLayout(
              title: 'Inventory Reports',
              currentRoute: 'inventory-reports',
              showSearch: false,
              child: Center(child: Text('Inventory Reports Content')),
            ),
        '/financial-reports': (context) => const MainLayout(
              title: 'Financial Reports',
              currentRoute: 'financial-reports',
              showSearch: false,
              child: Center(child: Text('Financial Reports Content')),
            ),
        '/users': (context) => const MainLayout(
              title: 'Users',
              currentRoute: 'users',
              showSearch: true,
              child: UserListScreen(),
            ),
        // ADD: ROUTES FOR INVENTORY ADJUSTMENT MODULE
        '/adjustment/hub': (context) => const MainLayout(
              title: 'Inventory Adjustment',
              currentRoute: 'adjustment/hub',
              showSearch: false,
              child: AdjustmentHubScreen(),
            ),
        '/adjustment/receive-stock': (context) => const MainLayout(
              title: 'Receive Stock',
              currentRoute: 'adjustment',
              showSearch: false,
              child: ReceiveStockScreen(),
            ),
        '/adjustment/report-discrepancy': (context) => const MainLayout(
              title: 'Report Discrepancy',
              currentRoute: 'adjustment',
              showSearch: false,
              child: ReportDiscrepancyScreen(),
            ),
        '/adjustment/return-stock': (context) => const MainLayout(
              title: 'Return Stock',
              currentRoute: 'adjustment',
              showSearch: false,
              child: ReturnStockScreen(),
            ),
        '/adjustment/return-history': (context) => const MainLayout(
              title: 'Return History',
              currentRoute: 'adjustment',
              showSearch: false,
              child: ReturnHistoryListScreen(),
            ),
        '/adjustment/received-items-list': (context) => const MainLayout(
              title: 'Received Items List',
              currentRoute: 'adjustment',
              showSearch: false,
              child: ReceivedItemsListScreen(),
            ),
        '/adjustment/discrepancy-reports-list': (context) => const MainLayout(
              title: 'Discrepancy Reports List',
              currentRoute: 'adjustment',
              showSearch: false,
              child: DiscrepancyReportsListScreen(),
            ),
        '/adjustment/history': (context) => const MainLayout(
              title: 'Adjustment History',
              currentRoute: 'adjustment',
              showSearch: false,
              child: Center(
                  child: Text('Adjustment History Screen - Coming Soon')),
            ),
        '/adjustment/reports': (context) => const MainLayout(
              title: 'Reports Dashboard',
              currentRoute: 'adjustment',
              showSearch: false,
              child:
                  Center(child: Text('Reports Dashboard Screen - Coming Soon')),
            ),
        '/settings': (context) => const MainLayout(
              title: 'Settings',
              currentRoute: 'settings',
              showSearch: false,
              child: Center(child: Text('Settings Content')),
            ),
        '/part-issues': (context) => const MainLayout(
              title: 'Part Issues',
              currentRoute: 'part-issues',
              showSearch: true,
              child: PartIssuesPage(),
            ),
        '/help': (context) => const MainLayout(
              title: 'Help & Support',
              currentRoute: 'help',
              showSearch: false,
              child: const Center(child: Text('Help & Support Content')),
            ),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
