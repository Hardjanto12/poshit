import 'package:flutter/material.dart';
import 'package:poshit/models/transaction.dart';
import 'package:poshit/models/transaction_item.dart';
import 'package:poshit/models/product.dart';
import 'package:poshit/services/transaction_service.dart';
import 'package:poshit/services/product_service.dart';
import 'package:poshit/utils/currency_formatter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';


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

  Future<void> _generateInvoicePdf(
    Transaction transaction,
    List<TransactionItem> items,
    Map<int, Product> productMap,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PoSHIT - Invoice',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Transaction ID: ${transaction.id}'),
              pw.Text('Date: ${formatDateTime(transaction.transactionDate)}'),
              pw.SizedBox(height: 20),
              pw.Text(
                'Items:',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Product', 'Qty', 'Price', 'Subtotal'],
                data: items.map((item) {
                  final product = productMap[item.productId];
                  return [
                    product?.name ?? 'Unknown Product',
                    item.quantity.toString(),
                    formatToIDR(item.priceAtTransaction),
                    formatToIDR(item.quantity * item.priceAtTransaction),
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Total Amount: ${formatToIDR(transaction.totalAmount)}',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Amount Received: ${formatToIDR(transaction.amountReceived)}',
                      style: const pw.TextStyle(fontSize: 16),
                    ),
                    pw.Text(
                      'Change: ${formatToIDR(transaction.change)}',
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

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  /*
  Future<void> _shareInvoicePdf(
    Transaction transaction,
    List<TransactionItem> items,
    Map<int, Product> productMap,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PoSHIT - Invoice',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Transaction ID: ${transaction.id}'),
              pw.Text('Date: ${formatDateTime(transaction.transactionDate)}'),
              pw.SizedBox(height: 20),
              pw.Text(
                'Items:',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Product', 'Qty', 'Price', 'Subtotal'],
                data: items.map((item) {
                  final product = productMap[item.productId];
                  return [
                    product?.name ?? 'Unknown Product',
                    item.quantity.toString(),
                    formatToIDR(item.priceAtTransaction),
                    formatToIDR(item.quantity * item.priceAtTransaction),
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Total Amount: ${formatToIDR(transaction.totalAmount)}',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Amount Received: ${formatToIDR(transaction.amountReceived)}',
                      style: const pw.TextStyle(fontSize: 16),
                    ),
                    pw.Text(
                      'Change: ${formatToIDR(transaction.change)}',
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
    final fileName = 'invoice_${transaction.id}.pdf';
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(output);

    await Share.share(text: 'Here is your invoice.', files: [filePath]);
  }
  */

  @override
  void initState() {
    super.initState();
    _invoiceDataFuture = _fetchInvoiceData().then((data) {
      _generateInvoicePdf(
        data['transaction'],
        data['items'],
        data['productMap'],
      );
      return data;
    });
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

            return Column(
              children: [
                Expanded(
                  child: Padding(
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
                        Text(
                          'Date: ${formatDateTime(transaction.transactionDate)}',
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Items:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
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
                                  'Quantity: ${item.quantity} x ${formatToIDR(item.priceAtTransaction)}',
                                ),
                                trailing: Text(
                                  formatToIDR(
                                    item.quantity * item.priceAtTransaction,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const Divider(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Total Amount: ${formatToIDR(transaction.totalAmount)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Amount Received: ${formatToIDR(transaction.amountReceived)}',
                                style: const TextStyle(fontSize: 18),
                              ),
                              Text(
                                'Change: ${formatToIDR(transaction.change)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () =>
                            _generateInvoicePdf(transaction, items, productMap),
                        icon: const Icon(Icons.print),
                        label: const Text('Print Invoice'),
                      ),
                      /*
                      ElevatedButton.icon(
                        onPressed: () =>
                            _shareInvoicePdf(transaction, items, productMap),
                        icon: const Icon(Icons.share),
                        label: const Text('Share PDF'),
                      ),
                      */
                    ],
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
