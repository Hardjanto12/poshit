import 'package:flutter/material.dart';
import 'package:poshit/models/transaction.dart';
import 'package:poshit/models/transaction_item.dart';
import 'package:poshit/models/product.dart';
import 'package:poshit/services/transaction_service.dart';
import 'package:poshit/services/product_service.dart';

class InvoiceScreen extends StatefulWidget {
  final int transactionId;

  const InvoiceScreen({super.key, required this.transactionId});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  late Future<Map<String, dynamic>> _invoiceDataFuture;
  final TransactionService _transactionService = TransactionService();
  final ProductService _productService = ProductService();

  @override
  void initState() {
    super.initState();
    _invoiceDataFuture = _fetchInvoiceData();
  }

  Future<Map<String, dynamic>> _fetchInvoiceData() async {
    final transaction = await _transactionService.getTransactions().then(
      (transactions) =>
          transactions.firstWhere((t) => t.id == widget.transactionId),
    );
    final items = await _transactionService.getTransactionItems(
      widget.transactionId,
    );
    final products = await _productService.getProducts();

    // Map product IDs to product objects for easy lookup
    final Map<int, Product> productMap = {for (var p in products) p.id!: p};

    return {
      'transaction': transaction,
      'items': items,
      'productMap': productMap,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _invoiceDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No invoice data found.'));
          } else {
            final Transaction transaction = snapshot.data!['transaction'];
            final List<TransactionItem> items = snapshot.data!['items'];
            final Map<int, Product> productMap = snapshot.data!['productMap'];

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice for Transaction ID: ${transaction.id}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Date: ${transaction.transactionDate}'),
                  const SizedBox(height: 20),
                  const Text(
                    'Items:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final product = productMap[item.productId];
                        return ListTile(
                          title: Text(product?.name ?? 'Unknown Product'),
                          subtitle: Text(
                            'Quantity: ${item.quantity} x Rp. ${item.priceAtTransaction.toStringAsFixed(2)}',
                          ),
                          trailing: Text(
                            'Rp. ${(item.quantity * item.priceAtTransaction).toStringAsFixed(2)}',
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Total Amount: Rp. ${transaction.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
