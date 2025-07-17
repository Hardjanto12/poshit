import 'package:flutter/material.dart';
import 'package:poshit/database_helper.dart';
import 'package:poshit/models/user.dart';
import 'package:poshit/screens/product_list_screen.dart';
import 'package:poshit/screens/transaction_list_screen.dart';
import 'package:poshit/screens/new_transaction_screen.dart';
import 'dart:io' show Platform;
import 'package:poshit/screens/reporting_dashboard_screen.dart';
import 'package:poshit/screens/settings_screen.dart';
import 'package:poshit/screens/login_screen.dart';
import 'package:poshit/services/user_session_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // THIS IS THE CRITICAL PART FOR WINDOWS
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Initialize FFI
    sqfliteFfiInit();
    // Change the default factory for sqflite to the FFI version
    databaseFactory = databaseFactoryFfi;
  }

  await DatabaseHelper().database; // Initialize the database

  // Initialize user session service
  final userSessionService = UserSessionService();
  final isLoggedIn = await userSessionService.initialize();

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PoSHIT',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final userSessionService = UserSessionService();

  static const List<Widget> _pages = <Widget>[
    NewTransactionScreen(), // left
    ProductListScreen(), // center
    TransactionListScreen(), // right
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = userSessionService.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text('Welcome ${currentUser?.name ?? "User"}!')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.account_circle, size: 48, color: Colors.white),
                  SizedBox(height: 8),
                  Text(
                    currentUser?.name ?? "User",
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.group),
              title: Text('User Management'),
              onTap: () {
                // TODO: Implement User Management screen navigation
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('User Management not implemented.')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () async {
                await userSessionService.logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.help_outline),
              title: Text('About/Help'),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'PoSHIT',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© 2024 PoSHIT',
                  children: [Text('A simple POS system.')],
                );
              },
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.add_shopping_cart),
            label: 'New Transaction',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        onTap: _onItemTapped,
      ),
    );
  }
}
