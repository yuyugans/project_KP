import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/transaction_record.dart';
import 'out_of_stock_screen.dart';
import '../utils/currency_formatter.dart';
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

        title: const Text(
          'Dashboard',
          style: TextStyle(
            color: textDark,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),

        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const OutOfStockScreen(),
                  ),
                );
              },
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: primaryBlue,
              ),
            ),
          ),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F9CF9), Color(0xFF79BBFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: primaryBlue.withValues(alpha: 0.20),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'TOKO AKBAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Point of Sale & Inventory',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.20),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Icon(
                              Icons.waving_hand_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Selamat datang kembali!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Berikut ringkasan aktivitas toko hari ini.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ringkasan',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: lightBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.today_rounded,
                              size: 15,
                              color: primaryBlue,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Hari ini',
                              style: TextStyle(
                                color: primaryBlue,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Summary cards
                  Row(
                    children: [
                      Expanded(
                        child: SummaryCard(
                          title: 'Penjualan Hari Ini',
                          value: formatCurrency(todaySales),
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
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: lightBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  color: primaryBlue,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Belum ada transaksi',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Transaksi terbaru akan muncul di sini.',
                                style: TextStyle(fontSize: 12, color: textGrey),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
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
            formatCurrency(transaction.total),
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
