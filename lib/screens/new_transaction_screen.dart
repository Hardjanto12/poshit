import 'package:flutter/material.dart';
import 'package:poshit/models/product.dart';
import 'package:poshit/models/transaction.dart';
import 'package:poshit/models/transaction_item.dart';
import 'package:poshit/services/product_service.dart';
import 'package:poshit/services/transaction_service.dart';
import 'package:poshit/utils/currency_formatter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

class NewTransactionScreen extends StatefulWidget {
  const NewTransactionScreen({super.key});

  @override
  State<NewTransactionScreen> createState() => _NewTransactionScreenState();
}

class _NewTransactionScreenState extends State<NewTransactionScreen> {
  final ProductService _productService = ProductService();
  final TransactionService _transactionService = TransactionService();
  List<Product> _availableProducts = [];
  final Map<Product, int> _cart = {};
  final TextEditingController _cashReceivedController = TextEditingController();
  double _changeAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _cashReceivedController.addListener(_onCashReceivedChanged);
  }

  @override
  void dispose() {
    _cashReceivedController.removeListener(_onCashReceivedChanged);
    _cashReceivedController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final products = await _productService.getProducts();
    setState(() {
      _availableProducts = products;
    });
  }

  void _addToCart(Product product) {
    setState(() {
      _cart.update(product, (value) => value + 1, ifAbsent: () => 1);
      _onCashReceivedChanged();
    });
  }

  void _removeFromCart(Product product) {
    setState(() {
      if (_cart.containsKey(product)) {
        if (_cart[product]! > 1) {
          _cart.update(product, (value) => value - 1);
        } else {
          _cart.remove(product);
        }
      }
      _onCashReceivedChanged();
    });
  }

  double _calculateTotal() {
    double total = 0.0;
    for (final entry in _cart.entries) {
      total += entry.key.price * entry.value;
    }
    return total;
  }

  void _onCashReceivedChanged() {
    final double total = _calculateTotal();
    final double cashReceived =
        double.tryParse(_cashReceivedController.text) ?? 0.0;
    setState(() {
      _changeAmount = cashReceived - total;
    });
  }

  Future<void> _completeTransaction() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty. Add some products.')),
      );
      return;
    }

    final double totalAmount = _calculateTotal();
    final double amountReceived =
        double.tryParse(_cashReceivedController.text) ?? 0.0;

    if (amountReceived < totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cash received is less than total amount.'),
        ),
      );
      return;
    }

    final transaction = Transaction(
      totalAmount: totalAmount,
      amountReceived: amountReceived,
      change: _changeAmount,
      transactionDate: DateTime.now().toIso8601String(),
      dateCreated: DateTime.now().toIso8601String(),
      dateUpdated: DateTime.now().toIso8601String(),
    );

    final List<TransactionItem> items = _cart.entries.map((entry) {
      return TransactionItem(
        transactionId: 0,
        productId: entry.key.id!,
        quantity: entry.value,
        priceAtTransaction: entry.key.price,
        dateCreated: DateTime.now().toIso8601String(),
        dateUpdated: DateTime.now().toIso8601String(),
      );
    }).toList();

    try {
      final int transactionId = await _transactionService.insertTransaction(
        transaction,
        items,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction completed successfully!')),
      );
      final Map<Product, int> cartSnapshot = Map<Product, int>.from(_cart);
      setState(() {
        _cart.clear();
        _cashReceivedController.clear();
        _changeAmount = 0.0;
      });
      _showTransactionSummaryDialog(
        transactionId,
        totalAmount,
        amountReceived,
        amountReceived - totalAmount,
        cartSnapshot,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Transaction failed: $e')));
    }
  }

  void _showTransactionSummaryDialog(
    int transactionId,
    double totalAmount,
    double amountReceived,
    double change,
    Map<Product, int> cartSnapshot,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Transaction Summary'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Amount: ${formatToIDR(totalAmount)}'),
              Text('Cash Received: ${formatToIDR(amountReceived)}'),
              Text('Change: ${formatToIDR(change)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _generateAndSharePdf(transactionId, cartSnapshot);
              },
              child: const Text('Generate & Share PDF'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _generateAndSharePdf(
    int transactionId,
    Map<Product, int> cart,
  ) async {
    final transactionData = await _transactionService.getTransactions().then(
      (transactions) => transactions.firstWhere((t) => t.id == transactionId),
    );
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PoSHIT - Receipt',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Transaction ID: ${transactionData.id}'),
              pw.Text('Date: ${transactionData.transactionDate}'),
              pw.SizedBox(height: 20),
              pw.Text(
                'Items:',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              ...cart.entries.map((entry) {
                final product = entry.key;
                final quantity = entry.value;
                return pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${product.name} x $quantity'),
                    pw.Text(formatToIDR(quantity * product.price)),
                  ],
                );
              }),
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Total: ${formatToIDR(transactionData.totalAmount)}',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Cash Received: ${formatToIDR(transactionData.amountReceived)}',
                      style: pw.TextStyle(fontSize: 16),
                    ),
                    pw.Text(
                      'Change: ${formatToIDR(transactionData.change)}',
                      style: pw.TextStyle(fontSize: 16, color: PdfColors.green),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    final output = await pdf.save();
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/receipt_${transactionId}.pdf');
    await file.writeAsBytes(output);

    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Here is your PoSHIT receipt!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Transaction')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _availableProducts.length,
              itemBuilder: (context, index) {
                final product = _availableProducts[index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text(product.name),
                    subtitle: Text(formatToIDR(product.price)),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_shopping_cart),
                      onPressed: () => _addToCart(product),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cart:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_cart.isEmpty)
                  const Text('No items in cart')
                else
                  ..._cart.entries
                      .map(
                        (entry) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${entry.key.name} x ${entry.value}'),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => _removeFromCart(entry.key),
                                ),
                                Text(
                                  formatToIDR(entry.key.price * entry.value),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                      .toList(),
                const Divider(),
                Text(
                  'Total: ${formatToIDR(_calculateTotal())}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _cashReceivedController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cash Received',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Change: ${formatToIDR(_changeAmount)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _completeTransaction,
                  child: const Text('Complete Transaction'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
