import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/transaction_record.dart';
import '../widgets/summary_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  List<Product> _products = [];
  List<TransactionRecord> _transactions = [];
  bool _isLoading = true;

  static const Color primaryBlue = Color(0xFF5B9FEF);
  static const Color lightBlue = Color(0xFFEAF4FF);
  static const Color backgroundColor = Color(0xFFF7F9FC);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textGrey = Color(0xFF7B8494);

  @override
  void initState() {
    super.initState();
    _databaseHelper.transactionChanges.addListener(_loadDashboard);
    _databaseHelper.productChanges.addListener(_loadDashboard);
    _loadDashboard();
  }

  @override
  void dispose() {
    _databaseHelper.transactionChanges.removeListener(_loadDashboard);
    _databaseHelper.productChanges.removeListener(_loadDashboard);
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    final products = await _databaseHelper.getProducts();
    final transactions = await _databaseHelper.getTransactions();

    if (!mounted) return;

    setState(() {
      _products = products;
      _transactions = transactions;
      _isLoading = false;
    });
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    final localDate = date.toLocal();
    return localDate.year == now.year &&
        localDate.month == now.month &&
        localDate.day == now.day;
  }

  String _formatCurrency(double value) => 'Rp ${value.toStringAsFixed(0)}';

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');
    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final todayTransactions = _transactions.where(
      (transaction) => _isToday(transaction.createdAt),
    );
    final todaySales = todayTransactions.fold<double>(
      0,
      (total, transaction) => total + transaction.total,
    );
    final lowStockCount = _products
        .where((product) => product.stock <= product.minStock)
        .length;
    final recentTransactions = _transactions.take(5).toList();

    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,

        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Dashboard',
              style: TextStyle(
                color: textDark,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'TOKO AKBAR',
              style: TextStyle(
                color: textGrey,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),

        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: lightBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: primaryBlue,
              ),
            ),
          ),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6AA9F5), Color(0xFF8BC5FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: primaryBlue.withOpacity(0.18),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),

                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Selamat datang 👋',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),

                              const SizedBox(height: 6),

                              Text(
                                'Berikut ringkasan toko hari ini.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Summary title
                  const Text(
                    'Ringkasan',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Summary cards
                  Row(
                    children: [
                      Expanded(
                        child: SummaryCard(
                          title: 'Penjualan Hari Ini',
                          value: _formatCurrency(todaySales),
                          icon: Icons.payments_rounded,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: SummaryCard(
                          title: 'Transaksi Hari Ini',
                          value: '${todayTransactions.length}',
                          icon: Icons.receipt_long_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: SummaryCard(
                          title: 'Total Produk',
                          value: '${_products.length}',
                          icon: Icons.inventory_2_rounded,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: SummaryCard(
                          title: 'Stok Menipis',
                          value: '$lowStockCount',
                          icon: Icons.warning_amber_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Recent sales header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Penjualan Terbaru',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                      ),

                      TextButton(
                        onPressed: _loadDashboard,
                        child: const Text(
                          'Muat ulang',
                          style: TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Recent sales
                  recentTransactions.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('Belum ada transaksi')),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              for (
                                var index = 0;
                                index < recentTransactions.length;
                                index++
                              ) ...[
                                _saleItem(
                                  transaction: recentTransactions[index],
                                ),
                                if (index < recentTransactions.length - 1)
                                  _divider(),
                              ],
                            ],
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _saleItem({required TransactionRecord transaction}) {
    final quantity = transaction.items.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,

            decoration: BoxDecoration(
              color: lightBlue,
              borderRadius: BorderRadius.circular(12),
            ),

            child: const Icon(
              Icons.receipt_long_rounded,
              color: primaryBlue,
              size: 22,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transaksi #${transaction.id}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '${transaction.items.length} jenis produk • $quantity barang\n'
                  '${_formatDate(transaction.createdAt)}',
                  style: const TextStyle(fontSize: 13, color: textGrey),
                ),
              ],
            ),
          ),

          Text(
            _formatCurrency(transaction.total),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(
      height: 1,
      indent: 72,
      endIndent: 16,
      color: Color(0xFFEFF1F5),
    );
  }
}
