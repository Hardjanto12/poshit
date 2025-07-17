import 'package:flutter/material.dart';
import 'package:poshit/models/product.dart';
import 'package:poshit/models/transaction.dart';
import 'package:poshit/models/transaction_item.dart';
import 'package:poshit/services/product_service.dart';
import 'package:poshit/services/transaction_service.dart';
import 'package:poshit/services/user_session_service.dart';
import 'package:poshit/utils/currency_formatter.dart';
import 'package:poshit/screens/receipt_preview_screen.dart';
import 'package:poshit/services/settings_service.dart';
// Removed: import 'package:fluttertoast/fluttertoast.dart';

class NewTransactionScreen extends StatefulWidget {
  const NewTransactionScreen({super.key});

  @override
  State<NewTransactionScreen> createState() => _NewTransactionScreenState();
}

class _NewTransactionScreenState extends State<NewTransactionScreen> {
  final ProductService _productService = ProductService();
  final TransactionService _transactionService = TransactionService();
  final SettingsService _settingsService = SettingsService();
  final UserSessionService _userSessionService = UserSessionService();

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  final Map<Product, int> _cart = {};
  final TextEditingController _cashReceivedController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  double _changeAmount = 0.0;

  bool _useInventoryTracking = true;
  bool _useSkuField = true;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndProducts();
    _cashReceivedController.addListener(_onCashReceivedChanged);
    _searchController.addListener(_filterProducts);
  }

  Future<void> _loadSettingsAndProducts() async {
    _useInventoryTracking = await _settingsService.getUseInventoryTracking();
    _useSkuField = await _settingsService.getUseSkuField();
    setState(() {});
    _loadProducts();
  }

  @override
  void dispose() {
    _cashReceivedController.removeListener(_onCashReceivedChanged);
    _cashReceivedController.dispose();
    _searchController.removeListener(_filterProducts);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final products = await _productService.getProducts();
    setState(() {
      _allProducts = products;
      _filterProducts(); // Initialize filtered products
    });
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _allProducts
          .where((product) => product.name.toLowerCase().contains(query))
          .toList();
    });
  }

  void _addToCart(Product product) {
    setState(() {
      _cart.update(product, (value) => value + 1, ifAbsent: () => 1);
      _onCashReceivedChanged();
    });
  }

  void _removeFromCart(Product product, {bool removeAll = false}) {
    setState(() {
      if (_cart.containsKey(product)) {
        if (removeAll || _cart[product]! <= 1) {
          _cart.remove(product);
        } else {
          _cart.update(product, (value) => value - 1);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cart is empty. Add some products.'),
            duration: Duration(milliseconds: 2000),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final userId = _userSessionService.currentUserId;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User session expired. Please login again.'),
            backgroundColor: Colors.red,
            duration: Duration(milliseconds: 2000),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final double totalAmount = _calculateTotal();
    final double amountReceived =
        double.tryParse(_cashReceivedController.text) ?? 0.0;

    if (amountReceived < totalAmount) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cash received is less than total amount.'),
            duration: Duration(milliseconds: 2000),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final transaction = Transaction(
      userId: userId,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction completed successfully!'),
            duration: Duration(milliseconds: 2000),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      // Create a list of TransactionItem objects with product names for the receipt
      final List<TransactionItem> receiptItems = _cart.entries.map((entry) {
        return TransactionItem(
          transactionId: transactionId,
          productId: entry.key.id!,
          quantity: entry.value,
          priceAtTransaction: entry.key.price,
          productName: entry.key.name, // Include product name for receipt
          dateCreated: DateTime.now().toIso8601String(),
          dateUpdated: DateTime.now().toIso8601String(),
        );
      }).toList();

      // Clear cart and navigate to ReceiptPreviewScreen
      setState(() {
        _cart.clear();
        _cashReceivedController.clear();
        _changeAmount = 0.0;
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptPreviewScreen(
              transaction: transaction.copyWith(
                id: transactionId,
              ), // Pass the transaction with its new ID
              transactionItems: receiptItems,
              cashReceived: amountReceived,
              changeGiven: _changeAmount,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(milliseconds: 2000),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Added this line
      appBar: AppBar(title: const Text('New Transaction')),
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isPortrait = orientation == Orientation.portrait;
          if (isPortrait) {
            return Stack(
              children: [
                // Product list takes the whole screen
                Positioned.fill(
                  child: _ProductListPane(
                    isPortrait: isPortrait,
                    searchController: _searchController,
                    filteredProducts: _filteredProducts,
                    addToCart: _addToCart,
                    formatToIDR: formatToIDR,
                    useInventoryTracking: _useInventoryTracking,
                    useSkuField: _useSkuField,
                  ),
                ),
                DraggableScrollableSheet(
                  initialChildSize: 0.12,
                  minChildSize: 0.08,
                  maxChildSize: 0.7,
                  builder: (context, scrollController) {
                    return Material(
                      elevation: 12,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, -2),
                            ),
                          ],
                        ),
                        child: _CartAndTransactionDetailsPane(
                          isPortrait: isPortrait,
                          cart: _cart,
                          clearCart: () {
                            setState(() {
                              _cart.clear();
                              _cashReceivedController.clear();
                              _changeAmount = 0.0;
                            });
                          },
                          removeFromCart: _removeFromCart,
                          addToCart: _addToCart,
                          calculateTotal: _calculateTotal,
                          cashReceivedController: _cashReceivedController,
                          changeAmount: _changeAmount,
                          completeTransaction: _completeTransaction,
                          formatToIDR: formatToIDR,
                          scrollController: scrollController,
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          } else {
            // Landscape: keep side-by-side layout
            return Flex(
              direction: Axis.horizontal,
              children: [
                _ProductListPane(
                  isPortrait: isPortrait,
                  searchController: _searchController,
                  filteredProducts: _filteredProducts,
                  addToCart: _addToCart,
                  formatToIDR: formatToIDR,
                  useInventoryTracking: _useInventoryTracking,
                  useSkuField: _useSkuField,
                ),
                _CartAndTransactionDetailsPane(
                  isPortrait: isPortrait,
                  cart: _cart,
                  clearCart: () {
                    setState(() {
                      _cart.clear();
                      _cashReceivedController.clear();
                      _changeAmount = 0.0;
                    });
                  },
                  removeFromCart: _removeFromCart,
                  addToCart: _addToCart,
                  calculateTotal: _calculateTotal,
                  cashReceivedController: _cashReceivedController,
                  changeAmount: _changeAmount,
                  completeTransaction: _completeTransaction,
                  formatToIDR: formatToIDR,
                ),
              ],
            );
          }
        },
      ),
    );
  }
}

class _ProductListPane extends StatelessWidget {
  const _ProductListPane({
    required this.isPortrait,
    required this.searchController,
    required this.filteredProducts,
    required this.addToCart,
    required this.formatToIDR,
    required this.useInventoryTracking,
    required this.useSkuField,
  });

  final bool isPortrait;
  final TextEditingController searchController;
  final List<Product> filteredProducts;
  final Function(Product) addToCart;
  final Function(double) formatToIDR;
  final bool useInventoryTracking;
  final bool useSkuField;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: isPortrait ? 1 : 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Search Products',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 12.0,
                ),
                labelStyle: TextStyle(fontSize: 14),
              ),
            ),
          ),
          Expanded(
            child: filteredProducts.isEmpty
                ? const Center(child: Text('No products found.'))
                : GridView.builder(
                    padding: const EdgeInsets.all(8.0),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          (MediaQuery.of(context).size.width ~/
                                  (isPortrait ? 150 : 200))
                              .toInt()
                              .clamp(1, 5),
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                      childAspectRatio: isPortrait ? 1.0 : 0.8,
                    ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return Card(
                        elevation: 2.0,
                        child: InkWell(
                          onTap: () => addToCart(product),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.fastfood, size: 48.0),
                                Text(
                                  product.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${formatToIDR(product.price)}${useInventoryTracking ? ' | Stock: ${product.stockQuantity}' : ''}${useSkuField && product.sku != null ? ' | SKU: ${product.sku}' : ''}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CartAndTransactionDetailsPane extends StatelessWidget {
  const _CartAndTransactionDetailsPane({
    required this.isPortrait,
    required this.cart,
    required this.clearCart,
    required this.removeFromCart,
    required this.addToCart,
    required this.calculateTotal,
    required this.cashReceivedController,
    required this.changeAmount,
    required this.completeTransaction,
    required this.formatToIDR,
    this.scrollController,
  });

  final bool isPortrait;
  final Map<Product, int> cart;
  final VoidCallback clearCart;
  final void Function(Product, {bool removeAll}) removeFromCart;
  final Function(Product) addToCart;
  final Function() calculateTotal;
  final TextEditingController cashReceivedController;
  final double changeAmount;
  final VoidCallback completeTransaction;
  final Function(double) formatToIDR;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final cartContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Cart:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: clearCart,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Cart'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        cart.isEmpty
            ? const Center(child: Text('No items in cart'))
            : ListView.builder(
                controller: scrollController,
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: cart.length,
                itemBuilder: (context, index) {
                  final product = cart.keys.elementAt(index);
                  final quantity = cart[product]!;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${formatToIDR(product.price)} x $quantity',
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle,
                                      size: 18,
                                    ),
                                    onPressed: () => removeFromCart(product),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  Text(
                                    '$quantity',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_circle,
                                      size: 18,
                                    ),
                                    onPressed: () => addToCart(product),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 18),
                                    onPressed: () => removeFromCart(
                                      product,
                                      removeAll: true,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        const Divider(),
        Text(
          'Total: ${formatToIDR(calculateTotal())}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: cashReceivedController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Cash Received',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 12.0,
            ),
            labelStyle: TextStyle(fontSize: 14),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Change: ${formatToIDR(changeAmount)}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: completeTransaction,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: const Text(
              'Complete Transaction',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      ],
    );

    if (isPortrait) {
      // In portrait, do NOT wrap in Expanded, and make the whole thing scrollable
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          controller: scrollController,
          child: cartContent,
        ),
      );
    } else {
      // In landscape, keep the old Expanded layout
      return Expanded(
        flex: 2,
        child: Padding(padding: const EdgeInsets.all(8.0), child: cartContent),
      );
    }
  }
}
