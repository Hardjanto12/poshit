import 'package:flutter/material.dart';
import 'package:poshit/database_helper.dart';
import 'package:poshit/models/user.dart';
import 'package:poshit/screens/product_list_screen.dart';
import 'package:poshit/screens/transaction_list_screen.dart';
import 'package:poshit/screens/new_transaction_screen.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:poshit/screens/product_list_screen.dart';
import 'package:poshit/screens/transaction_list_screen.dart';
import 'package:poshit/screens/new_transaction_screen.dart';
import 'package:poshit/screens/reporting_dashboard_screen.dart';
// Remove the FFI import and initialization, as it causes errors if the package is not available.
// The default sqflite package works on mobile and web, and FFI is only needed for desktop with extra setup.
// If you want to support desktop, add sqflite_common_ffi to your dependencies and uncomment the following lines:

// import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Uncomment this block if you add sqflite_common_ffi to your dependencies for desktop support.
  /*
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  */
  await DatabaseHelper().database; // Initialize the database
  print("Database initialized successfully.");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PoSHIT',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> _register() async {
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text.trim();
    final String name =
        username; // For simplicity, using username as name for now

    if (username.isEmpty || password.isEmpty) {
      _showMessage('Username and password cannot be empty.');
      return;
    }

    final User newUser = User(
      name: name,
      username: username,
      password: password, // In a real app, hash this password!
      dateCreated: DateTime.now().toIso8601String(),
      dateUpdated: DateTime.now().toIso8601String(),
    );

    try {
      final db = await _dbHelper.database;
      await db.insert('users', newUser.toMap());
      _showMessage('Registration successful!');
    } catch (e) {
      _showMessage('Registration failed: User might already exist.');
    }
  }

  Future<void> _login() async {
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showMessage('Username and password cannot be empty.');
      return;
    }

    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> users = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password], // Again, hash comparison in real app
    );

    if (users.isNotEmpty) {
      _showMessage('Login successful!');
      // Navigate to home screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      _showMessage('Invalid username or password.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PoSHIT Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24.0),
            ElevatedButton(onPressed: _login, child: const Text('Login')),
            const SizedBox(height: 16.0),
            TextButton(onPressed: _register, child: const Text('Register')),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to PoSHIT!')),
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
              child: const Text('View Reports'),
            ),
          ],
        ),
      ),
    );
  }
}
