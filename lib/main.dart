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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userSessionService = UserSessionService();
    final currentUser = userSessionService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome ${currentUser?.name ?? "User"}!'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await userSessionService.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You are logged in!'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProductListScreen(),
                  ),
                );
              },
              child: const Text('Manage Products'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NewTransactionScreen(),
                  ),
                );
              },
              child: const Text('New Transaction'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TransactionListScreen(),
                  ),
                );
              },
              child: const Text('View Transactions'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReportingDashboardScreen(),
                  ),
                );
              },
              child: const Text('Reports'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
              child: const Text('Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
