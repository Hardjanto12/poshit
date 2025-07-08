import 'package:flutter/material.dart';
import 'package:poshit/database_helper.dart';
import 'package:poshit/utils/currency_formatter.dart';
import 'package:poshit/screens/transaction_list_screen.dart';

class ReportingDashboardScreen extends StatefulWidget {
  const ReportingDashboardScreen({super.key});

  @override
  State<ReportingDashboardScreen> createState() =>
      _ReportingDashboardScreenState();
}

class _ReportingDashboardScreenState extends State<ReportingDashboardScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<Map<String, dynamic>> _todaySummaryFuture;
  late Future<List<Map<String, dynamic>>> _topProductsFuture;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  void _loadReportData() {
    _todaySummaryFuture = _dbHelper.getTodaySummary();
    _topProductsFuture = _dbHelper.getTopSellingProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reporting Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's Summary",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            FutureBuilder<Map<String, dynamic>>(
              future: _todaySummaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData) {
                  return const Center(child: Text('No data available.'));
                } else {
                  final summary = snapshot.data!;
                  return Column(
                    children: [
                      Card(
                        child: ListTile(
                          title: const Text('Total Revenue Today'),
                          trailing: Text(formatToIDR(summary['totalRevenue'])),
                        ),
                      ),
                      Card(
                        child: ListTile(
                          title: const Text('Total Transactions Today'),
                          trailing: Text(
                            summary['totalTransactions'].toString(),
                          ),
                        ),
                      ),
                      Card(
                        child: ListTile(
                          title: const Text('Average Sale Value'),
                          trailing: Text(
                            formatToIDR(summary['averageSaleValue']),
                          ),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Top 5 Selling Products (Last 30 Days)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _topProductsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No top products found.'));
                } else {
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final product = snapshot.data![index];
                      return Card(
                        child: ListTile(
                          title: Text(product['name']),
                          trailing: Text(
                            'Sold: ${product['totalQuantitySold']}',
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Sales History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TransactionListScreen(),
                  ),
                );
              },
              child: const Text('View All Transactions'),
            ),
          ],
        ),
      ),
    );
  }
}
