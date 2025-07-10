import 'package:flutter/material.dart';
import 'package:poshit/models/product.dart';
import 'package:poshit/services/product_service.dart';
import 'package:poshit/services/settings_service.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? product;

  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _stockQuantityController =
      TextEditingController();

  final ProductService _productService = ProductService();
  bool _useInventoryTracking = true;
  bool _useSkuField = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _priceController.text = widget.product!.price.toString();
      _skuController.text = widget.product!.sku ?? '';
      _stockQuantityController.text = widget.product!.stockQuantity.toString();
    }
  }

  Future<void> _loadSettings() async {
    _useInventoryTracking = await SettingsService().getUseInventoryTracking();
    _useSkuField = await SettingsService().getUseSkuField();
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _skuController.dispose();
    _stockQuantityController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      final String name = _nameController.text;
      final double price = double.parse(_priceController.text);
      final String? sku = _useSkuField && _skuController.text.isNotEmpty
          ? _skuController.text
          : null;
      final int stockQuantity = _useInventoryTracking
          ? int.parse(_stockQuantityController.text)
          : 0;

      if (widget.product == null) {
        // Add new product
        final newProduct = Product(
          name: name,
          price: price,
          sku: sku,
          stockQuantity: stockQuantity,
          dateCreated: DateTime.now().toIso8601String(),
          dateUpdated: DateTime.now().toIso8601String(),
        );
        await _productService.insertProduct(newProduct);
      } else {
        // Update existing product
        final updatedProduct = Product(
          id: widget.product!.id,
          name: name,
          price: price,
          sku: sku,
          stockQuantity: stockQuantity,
          dateCreated: widget.product!.dateCreated,
          dateUpdated: DateTime.now().toIso8601String(),
        );
        await _productService.updateProduct(updatedProduct);
      }
      if (!mounted) return;
      Navigator.pop(context, true); // Pop with true to indicate success
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Added this line
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add Product' : 'Edit Product'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Product Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a product name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              if (_useSkuField)
                TextFormField(
                  controller: _skuController,
                  decoration: const InputDecoration(labelText: 'SKU'),
                  validator: (value) {
                    return null;
                  },
                ),
              if (_useSkuField) const SizedBox(height: 16.0),
              if (_useInventoryTracking)
                TextFormField(
                  controller: _stockQuantityController,
                  decoration: const InputDecoration(
                    labelText: 'Stock Quantity',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter stock quantity';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Please enter a valid integer';
                    }
                    return null;
                  },
                ),
              if (_useInventoryTracking) const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _saveProduct,
                child: const Text('Save Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
