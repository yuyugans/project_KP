import 'package:flutter/material.dart';

import 'database/database_helper.dart';

import 'screens/dashboard_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/login_screen.dart';
import 'screens/pos_screen.dart';
import 'screens/transaction_screen.dart';
import 'screens/report_screen.dart';
import 'screens/stock_receipt_screen.dart';
import 'screens/product_list_screen.dart';
import 'widgets/main_menu_button.dart';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await DatabaseHelper.instance.database;
  await DatabaseHelper.instance.ensureDefaultCategories();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF5B9FEF);
    const lightBlue = Color(0xFFEAF4FF);
    const backgroundColor = Color(0xFFF7F9FC);
    const textDark = Color(0xFF1F2937);
    const textGrey = Color(0xFF7B8494);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Toko Akbar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
          surface: Colors.white,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: backgroundColor,
        fontFamily: 'Arial',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: backgroundColor,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: textDark,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: IconThemeData(color: textDark),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          shadowColor: Colors.black12,
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFEFF1F5),
          thickness: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: textGrey),
          hintStyle: const TextStyle(color: textGrey),
          prefixIconColor: primaryBlue,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE1E7F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE1E7F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primaryBlue, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: primaryBlue,
            backgroundColor: lightBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: lightBlue,
          elevation: 8,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w600),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? primaryBlue
                  : textGrey,
            ),
          ),
        ),
      ),
      home: LoginScreen(destination: const MainScreen()),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;

  final List<Widget> pages = const [
    DashboardScreen(),
    InventoryScreen(),
    ProductListScreen(),
    POSScreen(),
    TransactionScreen(),
    ReportScreen(),
    StockReceiptScreen(),
  ];

  final List<({IconData icon, IconData selectedIcon, String label})>
  navigationItems = const [
    (
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
    (
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      label: 'Persediaan',
    ),
    (
      icon: Icons.list_alt_outlined,
      selectedIcon: Icons.list_alt,
      label: 'Daftar Barang',
    ),
    (
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale,
      label: 'Kasir',
    ),
    (
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: 'Riwayat',
    ),
    (
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: 'Laporan Keuangan',
    ),
    (
      icon: Icons.move_to_inbox_outlined,
      selectedIcon: Icons.move_to_inbox,
      label: 'Pembelian',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: mainNavigationScaffoldKey,
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Text(
                  'Toko Akbar',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: navigationItems.length,
                  itemBuilder: (context, index) {
                    final item = navigationItems[index];
                    final isSelected = currentIndex == index;
                    return ListTile(
                      leading: Icon(isSelected ? item.selectedIcon : item.icon),
                      title: Text(item.label),
                      selected: isSelected,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          currentIndex = index;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: pages[currentIndex],
    );
  }
}
