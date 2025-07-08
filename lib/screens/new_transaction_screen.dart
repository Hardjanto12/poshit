import 'package:flutter/material.dart';
import 'package:poshit/models/product.dart';
import 'package:poshit/models/transaction.dart';
import 'package:poshit/models/transaction_item.dart';
import 'package:poshit/services/product_service.dart';
import 'package:poshit/services/transaction_service.dart';
import 'package:poshit/utils/currency_formatter.dart';

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
    _availableProducts = await _productService.getProducts();
    setState(() {});
  }

  void _addToCart(Product product) {
    setState(() {
      _cart.update(product, (value) => value + 1, ifAbsent: () => 1);
      _onCashReceivedChanged(); // Recalculate change
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
      _onCashReceivedChanged(); // Recalculate change
    });
  }

  double _calculateTotal() {
    return _cart.entries.fold(
      0.0,
      (sum, entry) => sum + (entry.key.price * entry.value),
    );
  }

  void _onCashReceivedChanged() {
    final double total = _calculateTotal();
    final double cashReceived = double.tryParse(_cashReceivedController.text) ?? 0.0;
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
    final double amountReceived = double.tryParse(_cashReceivedController.text) ?? 0.0;

    if (amountReceived < totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash received is less than total amount.')),
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
        transactionId: 0, // Will be updated after transaction insertion
        productId: entry.key.id!,
        quantity: entry.value,
        priceAtTransaction: entry.key.price,
        dateCreated: DateTime.now().toIso8601String(),
        dateUpdated: DateTime.now().toIso8601String(),
      );
    }).toList();

    try {
      await _transactionService.insertTransaction(transaction, items);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction completed successfully!')),
      );
      setState(() {
        _cart.clear();
        _cashReceivedController.clear();
        _changeAmount = 0.0;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Transaction failed: $e')));
    }
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
                    subtitle: Text(
                      formatToIDR(product.price),
                    ),
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
                            Text(
                              '${entry.key.name} x ${entry.value}',
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => _removeFromCart(entry.key),
                                ),
                                Text(formatToIDR(entry.key.price * entry.value)),
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
