import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'poshit.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        sku TEXT UNIQUE,
        stock_quantity INTEGER DEFAULT 0,
        date_created TEXT NOT NULL,
        date_updated TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        date_created TEXT NOT NULL,
        date_updated TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total_amount REAL NOT NULL,
        amount_received REAL NOT NULL,
        change REAL NOT NULL,
        transaction_date TEXT NOT NULL,
        date_created TEXT NOT NULL,
        date_updated TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transaction_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        price_at_transaction REAL NOT NULL,
        date_created TEXT NOT NULL,
        date_updated TEXT NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<Map<String, dynamic>> getTodaySummary() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final List<Map<String, dynamic>> salesResult = await db.rawQuery(
      'SELECT SUM(total_amount) as totalRevenue, COUNT(id) as totalTransactions FROM transactions WHERE substr(transaction_date, 1, 10) = ?',
      [today],
    );

    double totalRevenue = salesResult.first['totalRevenue'] ?? 0.0;
    int totalTransactions = salesResult.first['totalTransactions'] ?? 0;
    double averageSaleValue = totalTransactions > 0 ? totalRevenue / totalTransactions : 0.0;

    return {
      'totalRevenue': totalRevenue,
      'totalTransactions': totalTransactions,
      'averageSaleValue': averageSaleValue,
    };
  }

  Future<List<Map<String, dynamic>>> getTopSellingProducts() async {
    final db = await database;
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String().substring(0, 10);

    final List<Map<String, dynamic>> topProducts = await db.rawQuery(
      '''
      SELECT
        p.name,
        SUM(ti.quantity) as totalQuantitySold
      FROM transaction_items ti
      JOIN products p ON ti.product_id = p.id
      JOIN transactions t ON ti.transaction_id = t.id
      WHERE substr(t.transaction_date, 1, 10) >= ?
      GROUP BY p.name
      ORDER BY totalQuantitySold DESC
      LIMIT 5
      ''',
      [thirtyDaysAgo],
    );
    return topProducts;
  }
}
