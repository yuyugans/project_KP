import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/transaction_record.dart';
import '../utils/currency_formatter.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionDateGroup {
  final String title;
  final List<TransactionRecord> transactions;

  const _TransactionDateGroup({
    required this.title,
    required this.transactions,
  });
}

class _TransactionScreenState extends State<TransactionScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  List<TransactionRecord> _transactions = [];
  bool _isLoading = true;
  String _selectedRange = 'all';
  DateTime? _selectedDate;

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

  String _getMonthLabel(DateTime date) {
    const monthNames = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final localDate = date.toLocal();
    return '${monthNames[localDate.month - 1]} ${localDate.year}';
  }

  String _selectedRangeLabel() {
    switch (_selectedRange) {
      case 'today':
        return 'Hari ini';
      case 'lastMonth':
        return 'Bulan lalu';
      case 'thisMonth':
        return 'Bulan ini';
      case 'custom':
        return _selectedDate == null ? 'Pilih tanggal' : _formatShortDate(_selectedDate!);
      case 'all':
      default:
        return 'Semua transaksi';
    }
  }

  List<TransactionRecord> _getFilteredTransactions() {
    final now = DateTime.now();

    switch (_selectedRange) {
      case 'today':
        return _transactions
            .where((transaction) => _isSameDay(transaction.createdAt, now))
            .toList();
      case 'lastMonth':
        final lastMonth = _getPreviousMonth(now);
        return _transactions
            .where(
              (transaction) => _isSameMonth(transaction.createdAt, lastMonth),
            )
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

  List<_TransactionDateGroup> _buildDateGroups() {
    final filteredTransactions = _getFilteredTransactions();

    if (_selectedRange != 'all') {
      return [
        _TransactionDateGroup(
          title: _selectedRangeLabel(),
          transactions: filteredTransactions,
        ),
      ];
    }

    final now = DateTime.now();
    final todayTransactions = _transactions
        .where((transaction) => _isSameDay(transaction.createdAt, now))
        .toList();
    final previousMonth = _getPreviousMonth(now);
    final lastMonthTransactions = _transactions
        .where((transaction) => _isSameMonth(transaction.createdAt, previousMonth))
        .toList();
    final thisMonthTransactions = _transactions
        .where(
          (transaction) =>
              _isSameMonth(transaction.createdAt, now) &&
              !_isSameDay(transaction.createdAt, now),
        )
        .toList();

    final groups = <_TransactionDateGroup>[];

    if (todayTransactions.isNotEmpty) {
      groups.add(_TransactionDateGroup(title: 'Hari ini', transactions: todayTransactions));
    }
    if (lastMonthTransactions.isNotEmpty) {
      groups.add(
        _TransactionDateGroup(
          title: 'Bulan lalu - ${_getMonthLabel(previousMonth)}',
          transactions: lastMonthTransactions,
        ),
      );
    }
    if (thisMonthTransactions.isNotEmpty) {
      groups.add(
        _TransactionDateGroup(
          title: 'Bulan ini - ${_getMonthLabel(now)}',
          transactions: thisMonthTransactions,
        ),
      );
    }

    return groups;
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
    final dateGroups = _buildDateGroups();

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
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Filter transaksi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Semua'),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (dateGroups.isEmpty ||
                      dateGroups.every((group) => group.transactions.isEmpty))
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Belum ada transaksi pada filter ini'),
                      ),
                    )
                  else
                    ...dateGroups.map((group) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              group.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...group.transactions.map((transaction) {
                            return _buildTransactionCard(transaction);
                          }),
                        ],
                      );
                    }),
                ],
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
