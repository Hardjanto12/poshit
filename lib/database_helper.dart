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
    return await openDatabase(
      path,
      version: 3, // Increment version for multi-user support
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
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
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        sku TEXT,
        stock_quantity INTEGER DEFAULT 0,
        date_created TEXT NOT NULL,
        date_updated TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        total_amount REAL NOT NULL,
        amount_received REAL NOT NULL,
        change REAL NOT NULL,
        transaction_date TEXT NOT NULL,
        date_created TEXT NOT NULL,
        date_updated TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
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

    await db.execute('''
      CREATE TABLE settings(
        user_id INTEGER NOT NULL,
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        PRIMARY KEY (user_id, key),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE settings(
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      // Add user_id to existing tables for multi-user support
      await db.execute(
        'ALTER TABLE products ADD COLUMN user_id INTEGER DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN user_id INTEGER DEFAULT 1',
      );

      // Create new settings table with user_id
      await db.execute('''
        CREATE TABLE settings_new(
          user_id INTEGER NOT NULL,
          key TEXT NOT NULL,
          value TEXT NOT NULL,
          PRIMARY KEY (user_id, key),
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');

      // Migrate existing settings to new table
      await db.execute('''
        INSERT INTO settings_new (user_id, key, value)
        SELECT 1, key, value FROM settings
      ''');

      // Drop old settings table and rename new one
      await db.execute('DROP TABLE settings');
      await db.execute('ALTER TABLE settings_new RENAME TO settings');

      // Add foreign key constraints
      await db.execute('''
        CREATE INDEX idx_products_user_id ON products(user_id)
      ''');
      await db.execute('''
        CREATE INDEX idx_transactions_user_id ON transactions(user_id)
      ''');
      await db.execute('''
        CREATE INDEX idx_settings_user_id ON settings(user_id)
      ''');
    }
  }

  Future<Map<String, dynamic>> getTodaySummary(int userId) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final List<Map<String, dynamic>> salesResult = await db.rawQuery(
      'SELECT SUM(total_amount) as totalRevenue, COUNT(id) as totalTransactions FROM transactions WHERE user_id = ? AND substr(transaction_date, 1, 10) = ?',
      [userId, today],
    );

    double totalRevenue = salesResult.first['totalRevenue'] ?? 0.0;
    int totalTransactions = salesResult.first['totalTransactions'] ?? 0;
    double averageSaleValue = totalTransactions > 0
        ? totalRevenue / totalTransactions
        : 0.0;

    return {
      'totalRevenue': totalRevenue,
      'totalTransactions': totalTransactions,
      'averageSaleValue': averageSaleValue,
    };
  }

  Future<List<Map<String, dynamic>>> getTopSellingProducts(int userId) async {
    final db = await database;
    final thirtyDaysAgo = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String()
        .substring(0, 10);

    final List<Map<String, dynamic>> topProducts = await db.rawQuery(
      '''
      SELECT
        p.name,
        SUM(ti.quantity) as totalQuantitySold
      FROM transaction_items ti
      JOIN products p ON ti.product_id = p.id
      JOIN transactions t ON ti.transaction_id = t.id
      WHERE p.user_id = ? AND substr(t.transaction_date, 1, 10) >= ?
      GROUP BY p.name
      ORDER BY totalQuantitySold DESC
      LIMIT 5
      ''',
      [userId, thirtyDaysAgo],
    );
    return topProducts;
  }
}
