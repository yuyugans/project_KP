import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/transaction_record.dart';
import '../utils/currency_formatter.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  List<TransactionRecord> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final transactions = await _databaseHelper.getTransactions();

    if (!mounted) return;

    setState(() {
      _transactions = transactions;
      _isLoading = false;
    });
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');

    return '$day/$month/${localDate.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        actions: [
          IconButton(
            onPressed: _loadTransactions,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
          IconButton(
            onPressed: _transactions.isEmpty ? null : _confirmDeleteAll,
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Hapus semua riwayat',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
          ? const Center(child: Text('Belum ada transaksi'))
          : RefreshIndicator(
              onRefresh: _loadTransactions,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  return _buildTransactionCard(_transactions[index]);
                },
              ),
            ),
    );
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus semua riwayat?'),
          content: const Text(
            'Semua riwayat transaksi akan dihapus dan tidak dapat dipulihkan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _databaseHelper.deleteAllTransactions();

    if (!mounted) return;

    setState(() {
      _transactions = [];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Riwayat transaksi berhasil dihapus')),
    );
  }

  Widget _buildTransactionCard(TransactionRecord transaction) {
    final groupedItems = transaction.itemsByCategory;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text('Transaksi #${transaction.id}'),
        subtitle: Text(
          '${_formatDate(transaction.createdAt)}\n'
          'Total: ${formatCurrency(transaction.total)}',
        ),
        children: [
          for (final entry in groupedItems.entries)
            _buildCategorySection(entry.key, entry.value),
          const Divider(),
          ListTile(
            dense: true,
            title: const Text('Pembayaran'),
            trailing: Text(formatCurrency(transaction.payment)),
          ),
          ListTile(
            dense: true,
            title: const Text('Kembalian'),
            trailing: Text(formatCurrency(transaction.change)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    String categoryName,
    List<TransactionItemRecord> items,
  ) {
    final categoryTotal = items.fold<double>(
      0,
      (total, item) => total + item.subtotal,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          title: Text(
            categoryName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          trailing: Text(formatCurrency(categoryTotal)),
        ),
        for (final item in items)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 32, right: 16),
            title: Text(item.productName),
            subtitle: Text(
              '${item.quantity} x ${formatCurrency(item.unitPrice)}',
            ),
            trailing: Text(formatCurrency(item.subtotal)),
          ),
      ],
    );
  }
}
