import 'package:sqflite/sqflite.dart';
import 'package:poshit/database_helper.dart';
import 'package:poshit/models/transaction.dart' as poshit_txn;
import 'package:poshit/models/transaction_item.dart';

class TransactionService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

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

  Future<List<poshit_txn.Transaction>> getTransactions() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('transactions');
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
    return List.generate(maps.length, (i) {
      return TransactionItem.fromMap(maps[i]);
    });
  }
}
