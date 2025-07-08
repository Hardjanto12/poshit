import 'package:flutter/material.dart';
import 'package:poshit/models/transaction.dart';
import 'package:poshit/services/transaction_service.dart';
import 'package:poshit/screens/invoice_screen.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  late Future<List<Transaction>> _transactionsFuture;
  final TransactionService _transactionService = TransactionService();

  @override
  void initState() {
    super.initState();
    _transactionsFuture = _transactionService.getTransactions().then(
      (list) => list.cast<Transaction>(),
    );
  }

  Future<void> _refreshTransactions() async {
    setState(() {
      _transactionsFuture = _transactionService.getTransactions().then(
        (list) => list.cast<Transaction>(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History')),
      body: FutureBuilder<List<Transaction>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No transactions found.'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final transaction = snapshot.data![index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text('Transaction ID: ${transaction.id}'),
                    subtitle: Text(
                      'Total: Rp. ${transaction.totalAmount.toStringAsFixed(0)} - Date: ${transaction.transactionDate}',
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              InvoiceScreen(transactionId: transaction.id!),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
