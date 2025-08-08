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
import 'package:poshit/services/product_events.dart';
import 'package:poshit/utils/icon_catalog.dart';
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
  final _productsVersion = ProductEvents().version;

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  final Map<Product, int> _cart = {};
  final TextEditingController _cashReceivedController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  double _changeAmount = 0.0;

  bool _useInventoryTracking = true;
  bool _useSkuField = true;
  bool _hideOutOfStock = false;

  // Keep current sort so it re-applies after filtering/searching
  ProductSort _currentSort = ProductSort.none;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndProducts();
    _cashReceivedController.addListener(_onCashReceivedChanged);
    _searchController.addListener(_filterProducts);
    _productsVersion.addListener(_onProductsUpdated);
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
    _productsVersion.removeListener(_onProductsUpdated);
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final products = await _productService.getProducts();
    setState(() {
      _allProducts = products;
      _filterProducts(); // Initialize filtered products
    });
  }

  void _onProductsUpdated() {
    // Refresh product list and update cart references if names/prices changed
    _loadProducts();
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      List<Product> working = _allProducts
          .where((product) => product.name.toLowerCase().contains(query))
          .toList();

      if (_hideOutOfStock) {
        working = working.where((p) => p.stockQuantity > 0).toList();
      }

      // Apply current sort selection
      switch (_currentSort) {
        case ProductSort.name:
          working.sort((a, b) => a.name.compareTo(b.name));
          break;
        case ProductSort.price:
          working.sort((a, b) => a.price.compareTo(b.price));
          break;
        case ProductSort.none:
          break;
      }

      _filteredProducts = working;
    });
  }

  void _onProductListMenuSelected(String value) {
    if (value == 'sort_name') {
      _currentSort = ProductSort.name;
    } else if (value == 'sort_price') {
      _currentSort = ProductSort.price;
    } else if (value == 'filter_stock') {
      _hideOutOfStock = !_hideOutOfStock; // toggle
    }
    _filterProducts();
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
    final double changeGiven = amountReceived - totalAmount;

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
      change: changeGiven,
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
              changeGiven: changeGiven,
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
                    onMenuSelected: _onProductListMenuSelected,
                    hideOutOfStock: _hideOutOfStock,
                    currentSort: _currentSort,
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
                  onMenuSelected: _onProductListMenuSelected,
                  hideOutOfStock: _hideOutOfStock,
                  currentSort: _currentSort,
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

enum ProductSort { none, name, price }

class _ProductListPane extends StatelessWidget {
  const _ProductListPane({
    required this.isPortrait,
    required this.searchController,
    required this.filteredProducts,
    required this.addToCart,
    required this.formatToIDR,
    required this.useInventoryTracking,
    required this.useSkuField,
    required this.onMenuSelected,
    required this.hideOutOfStock,
    required this.currentSort,
  });

  final bool isPortrait;
  final TextEditingController searchController;
  final List<Product> filteredProducts;
  final Function(Product) addToCart;
  final Function(double) formatToIDR;
  final bool useInventoryTracking;
  final bool useSkuField;
  final void Function(String) onMenuSelected;
  final bool hideOutOfStock;
  final ProductSort currentSort;

  @override
  Widget build(BuildContext context) {
    final columnWidget = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search products by name or SKU',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.tune),
                itemBuilder: (context) => [
                  CheckedPopupMenuItem<String>(
                    value: 'sort_name',
                    checked: currentSort == ProductSort.name,
                    child: const Text('Sort by name'),
                  ),
                  CheckedPopupMenuItem<String>(
                    value: 'sort_price',
                    checked: currentSort == ProductSort.price,
                    child: const Text('Sort by price'),
                  ),
                  CheckedPopupMenuItem<String>(
                    value: 'filter_stock',
                    checked: hideOutOfStock,
                    child: const Text('Hide out-of-stock'),
                  ),
                ],
                onSelected: onMenuSelected,
              ),
            ],
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
                                (isPortrait ? 160 : 220))
                            .toInt()
                            .clamp(1, 6),
                    crossAxisSpacing: 10.0,
                    mainAxisSpacing: 10.0,
                    childAspectRatio: isPortrait ? 0.78 : 0.85,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      elevation: 2,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => addToCart(product),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                height: 56,
                                width: 56,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  IconCatalog.iconFor(product.icon),
                                  size: 28,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                product.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    formatToIDR(product.price),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (useInventoryTracking)
                                    _Chip(
                                      text: 'Stock: ${product.stockQuantity}',
                                    ),
                                ],
                              ),
                              if (useSkuField && product.sku != null) ...[
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: _Chip(text: 'SKU: ${product.sku}'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );

    if (isPortrait) {
      return columnWidget;
    } else {
      return Expanded(flex: 3, child: columnWidget);
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
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
    if (isPortrait) {
      // In portrait, use ListView as the direct child of DraggableScrollableSheet
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          controller: scrollController,
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
            if (cart.isEmpty)
              const Center(child: Text('No items in cart'))
            else ...[
              for (final product in cart.keys)
                Card(
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
                                '${formatToIDR(product.price)} x ${cart[product]}',
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
                                  '${cart[product]}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle, size: 18),
                                  onPressed: () => addToCart(product),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18),
                                  onPressed: () =>
                                      removeFromCart(product, removeAll: true),
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
                ),
            ],
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
        ),
      );
    } else {
      // In landscape, keep the old Expanded layout
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
          Expanded(
            child: cart.isEmpty
                ? const Center(child: Text('No items in cart'))
                : ListView.builder(
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
                                        onPressed: () =>
                                            removeFromCart(product),
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
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 18,
                                        ),
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
      return Expanded(
        flex: 2,
        child: Padding(padding: const EdgeInsets.all(8.0), child: cartContent),
      );
    }
  }
}
