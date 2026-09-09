import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/transaction_record.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  List<TransactionRecord> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _databaseHelper.transactionChanges.addListener(_onTransactionsChanged);
    _loadReport();
  }

  void _onTransactionsChanged() {
    _loadReport();
  }

  @override
  void dispose() {
    _databaseHelper.transactionChanges.removeListener(_onTransactionsChanged);
    super.dispose();
  }

  Future<void> _loadReport() async {
    final transactions = await _databaseHelper.getTransactions();

    if (!mounted) return;

    setState(() {
      _transactions = transactions;
      _isLoading = false;
    });
  }

  String _formatCurrency(double value) => 'Rp ${value.toStringAsFixed(0)}';

  String _reportCategory(String categoryName) {
    final normalized = categoryName.toLowerCase();
    if (normalized.contains('material')) {
      return 'Material';
    }
    return 'Pupuk';
  }

  Map<String, _CategorySummary> get _summaries {
    final summaries = <String, _CategorySummary>{
      'Pupuk': _CategorySummary(),
      'Material': _CategorySummary(),
    };

    for (final transaction in _transactions) {
      for (final item in transaction.items) {
        final category = _reportCategory(item.categoryName);
        final summary = summaries[category]!;
        summary.gross += item.subtotal;
        summary.cost += item.totalCost;
        summary.quantity += item.quantity;
      }
    }

    return summaries;
  }

  @override
  Widget build(BuildContext context) {
    final summaries = _summaries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Pendapatan'),
        actions: [
          IconButton(
            onPressed: _loadReport,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryCard('Pupuk', summaries['Pupuk']!),
                  _buildSummaryCard('Material', summaries['Material']!),
                  const SizedBox(height: 16),
                  const Text(
                    'Keterangan: pendapatan bersih = pendapatan kotor - modal harga beli.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String category, _CategorySummary summary) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildRow('Jumlah terjual', '${summary.quantity} barang'),
            _buildRow('Pendapatan kotor', _formatCurrency(summary.gross)),
            _buildRow('Modal harga beli', _formatCurrency(summary.cost)),
            const Divider(),
            _buildRow(
              'Pendapatan bersih',
              _formatCurrency(summary.net),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: emphasize ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySummary {
  double gross = 0;
  double cost = 0;
  int quantity = 0;

  double get net => gross - cost;
}
