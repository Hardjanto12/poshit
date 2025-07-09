import 'package:sqflite/sqflite.dart';
import 'package:poshit/database_helper.dart';
import 'package:poshit/models/transaction.dart' as poshit_txn;
import 'package:poshit/models/transaction_item.dart';
import 'package:poshit/models/product.dart'; // Import Product model
import 'package:poshit/services/product_service.dart'; // Import ProductService

class TransactionService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ProductService _productService = ProductService(); // Instantiate ProductService

  Future<int> insertTransaction(
    poshit_txn.Transaction transaction,
    List<TransactionItem> items,
  ) async {
    final db = await _dbHelper.database;
    int transactionId = await db.insert('transactions', transaction.toMap());

    for (var item in items) {
      item.transactionId = transactionId;
      await db.insert('transaction_items', item.toMap());
    }
    return transactionId;
  }

  Future<List<poshit_txn.Transaction>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;
    List<Map<String, dynamic>> maps;
    if (startDate != null && endDate != null) {
      maps = await db.query(
        'transactions',
        where: 'transaction_date BETWEEN ? AND ?',
        whereArgs: [
          startDate.toIso8601String(),
          endDate.toIso8601String(),
        ],
        orderBy: 'transaction_date DESC',
      );
    } else {
      maps = await db.query('transactions', orderBy: 'transaction_date DESC');
    }
    return List.generate(maps.length, (i) {
      return poshit_txn.Transaction.fromMap(maps[i]);
    });
  }

  Future<List<TransactionItem>> getTransactionItems(int transactionId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transaction_items',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );

    List<TransactionItem> transactionItems = [];
    for (var map in maps) {
      TransactionItem item = TransactionItem.fromMap(map);
      Product? product = await _productService.getProductById(item.productId);
      if (product != null) {
        item.productName = product.name;
      }
      transactionItems.add(item);
    }
    return transactionItems;
  }
}
