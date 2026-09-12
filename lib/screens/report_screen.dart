import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/transaction_record.dart';
import '../utils/currency_formatter.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  List<TransactionRecord> _transactions = [];
  bool _isLoading = true;
  String _selectedRange = 'all';
  DateTime? _selectedDate;

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

  String _formatShortDate(DateTime date) {
    final localDate = date.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    return '$day/$month/${localDate.year}';
  }

  bool _isSameDay(DateTime first, DateTime second) {
    final firstLocal = first.toLocal();
    final secondLocal = second.toLocal();

    return firstLocal.year == secondLocal.year &&
        firstLocal.month == secondLocal.month &&
        firstLocal.day == secondLocal.day;
  }

  bool _isSameMonth(DateTime first, DateTime second) {
    final firstLocal = first.toLocal();
    final secondLocal = second.toLocal();

    return firstLocal.year == secondLocal.year &&
        firstLocal.month == secondLocal.month;
  }

  DateTime _getPreviousMonth(DateTime date) {
    var year = date.year;
    var month = date.month - 1;

    if (month <= 0) {
      month = 12;
      year -= 1;
    }

    return DateTime(year, month, 1);
  }

  String _reportCategory(String categoryName) {
    final normalized = categoryName.toLowerCase();

    if (normalized.contains('material')) {
      return 'Material';
    }

    return 'Pupuk';
  }

  List<TransactionRecord> get _filteredTransactions {
    final now = DateTime.now();

    switch (_selectedRange) {
      case 'today':
        return _transactions
            .where((transaction) => _isSameDay(transaction.createdAt, now))
            .toList();
      case 'lastMonth':
        final lastMonth = _getPreviousMonth(now);
        return _transactions
            .where((transaction) => _isSameMonth(transaction.createdAt, lastMonth))
            .toList();
      case 'thisMonth':
        return _transactions
            .where((transaction) => _isSameMonth(transaction.createdAt, now))
            .toList();
      case 'custom':
        if (_selectedDate == null) {
          return const [];
        }
        return _transactions
            .where((transaction) => _isSameDay(transaction.createdAt, _selectedDate!))
            .toList();
      case 'all':
      default:
        return _transactions;
    }
  }

  Map<String, _CategorySummary> get _summaries {
    final summaries = <String, _CategorySummary>{
      'Pupuk': _CategorySummary(),
      'Material': _CategorySummary(),
    };

    for (final transaction in _filteredTransactions) {
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

  Future<void> _pickCustomDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (pickedDate == null) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _selectedDate = pickedDate;
      _selectedRange = 'custom';
    });
  }

  @override
  Widget build(BuildContext context) {
    final summaries = _summaries;
    final selectedRangeTitle = switch (_selectedRange) {
      'today' => 'Hari ini',
      'lastMonth' => 'Bulan lalu',
      'thisMonth' => 'Bulan ini',
      'custom' => _selectedDate == null ? 'Pilih tanggal' : _formatShortDate(_selectedDate!),
      _ => 'Keseluruhan',
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Laporan Pendapatan',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadReport,
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF374151)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReport,
              color: const Color(0xFF2563EB),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Filter laporan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Keseluruhan'),
                              selected: _selectedRange == 'all',
                              onSelected: (_) {
                                setState(() {
                                  _selectedRange = 'all';
                                  _selectedDate = null;
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Hari ini'),
                              selected: _selectedRange == 'today',
                              onSelected: (_) {
                                setState(() {
                                  _selectedRange = 'today';
                                  _selectedDate = null;
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Bulan ini'),
                              selected: _selectedRange == 'thisMonth',
                              onSelected: (_) {
                                setState(() {
                                  _selectedRange = 'thisMonth';
                                  _selectedDate = null;
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Bulan lalu'),
                              selected: _selectedRange == 'lastMonth',
                              onSelected: (_) {
                                setState(() {
                                  _selectedRange = 'lastMonth';
                                  _selectedDate = null;
                                });
                              },
                            ),
                            ChoiceChip(
                              label: Text(
                                _selectedDate == null
                                    ? 'Pilih tanggal'
                                    : _formatShortDate(_selectedDate!),
                              ),
                              selected: _selectedRange == 'custom',
                              onSelected: (_) => _pickCustomDate(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tampilan saat ini: $selectedRangeTitle',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildSummaryCard(
                    'Pupuk',
                    summaries['Pupuk']!,
                    Icons.eco_rounded,
                  ),

                  _buildSummaryCard(
                    'Material',
                    summaries['Material']!,
                    Icons.construction_rounded,
                  ),

                  const SizedBox(height: 8),

                  _buildInformationCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ringkasan Penjualan',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pantau pendapatan dan penjualan berdasarkan kategori produk.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String category,
    _CategorySummary summary,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 23, color: const Color(0xFF374151)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            _buildRow('Jumlah terjual', '${summary.quantity} barang'),

            _buildRow('Pendapatan kotor', formatCurrency(summary.gross)),

            _buildRow('Modal harga beli', formatCurrency(summary.cost)),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.trending_up_rounded,
                      size: 20,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pendapatan bersih',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          formatCurrency(summary.net),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pendapatan bersih = pendapatan kotor - modal harga beli.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Colors.grey.shade600,
              ),
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
