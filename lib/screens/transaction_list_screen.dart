import 'package:flutter/material.dart';
import 'package:poshit/models/transaction.dart';
import 'package:poshit/services/transaction_service.dart';

import 'package:poshit/utils/currency_formatter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Import the ReceiptPreviewScreen to fix the error
import 'package:poshit/screens/receipt_preview_screen.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  late Future<List<Transaction>> _transactionsFuture;
  final TransactionService _transactionService = TransactionService();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _transactionsFuture = _transactionService.getTransactions().then(
      (list) => list.cast<Transaction>(),
    );
  }

  Future<void> _refreshTransactions() async {
    setState(() {
      _transactionsFuture = _transactionService
          .getTransactions(startDate: _startDate, endDate: _endDate)
          .then((list) => list.cast<Transaction>());
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
        _refreshTransactions();
      });
    }
  }

  Future<void> _generateTransactionListPdf(
    List<Transaction> transactions,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Transaction History Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              if (_startDate != null && _endDate != null)
                pw.Text(
                  'Date Range: ${formatDate(_startDate!)} - ${formatDate(_endDate!)}',
                ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['ID', 'Total Amount', 'Date'],
                data: transactions.map((transaction) {
                  return [
                    transaction.id.toString(),
                    formatToIDR(transaction.totalAmount),
                    formatDateTime(transaction.transactionDate),
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final transactions = await _transactionsFuture;
              if (transactions.isNotEmpty) {
                _generateTransactionListPdf(transactions);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectDate(context, true),
                    child: Text(
                      _startDate == null
                          ? 'Select Start Date'
                          : 'Start Date: ${formatDate(_startDate!)}',
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectDate(context, false),
                    child: Text(
                      _endDate == null
                          ? 'Select End Date'
                          : 'End Date: ${formatDate(_endDate!)}',
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                      _refreshTransactions();
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Transaction>>(
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
                            'Total: Rp. ${transaction.totalAmount.toStringAsFixed(0)} - Date: ${formatDateTime(transaction.transactionDate)}',
                          ),
                          onTap: () async {
                            final transactionItems = await _transactionService
                                .getTransactionItems(
                                  transaction.id!,
                                ); // Fetch items
                            if (!mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReceiptPreviewScreen(
                                  transaction: transaction,
                                  transactionItems: transactionItems,
                                  cashReceived: transaction.amountReceived,
                                  changeGiven: transaction.change,
                                ),
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
          ),
        ],
      ),
    );
  }
}
