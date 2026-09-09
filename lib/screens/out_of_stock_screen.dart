import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/product.dart';

const _primaryBlue = Color(0xFF5B9FEF);
const _lightBlue = Color(0xFFEAF4FF);
const _backgroundColor = Color(0xFFF7F9FC);
const _textDark = Color(0xFF1F2937);
const _textGrey = Color(0xFF7B8494);

class OutOfStockScreen extends StatefulWidget {
  const OutOfStockScreen({super.key});

  @override
  State<OutOfStockScreen> createState() => _OutOfStockScreenState();
}

class _OutOfStockScreenState extends State<OutOfStockScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  List<Product> _outOfStockProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _databaseHelper.productChanges.addListener(_loadOutOfStockProducts);
    _loadOutOfStockProducts();
  }

  @override
  void dispose() {
    _databaseHelper.productChanges.removeListener(_loadOutOfStockProducts);
    super.dispose();
  }

  Future<void> _loadOutOfStockProducts() async {
    final products = await _databaseHelper.getProducts();

    if (!mounted) return;

    setState(() {
      _outOfStockProducts = products
          .where((product) => product.stock <= 0)
          .toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Peringatan Stok'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loadOutOfStockProducts,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
          : RefreshIndicator(
              onRefresh: _loadOutOfStockProducts,
              color: _primaryBlue,
              child: _outOfStockProducts.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: const [
                        SizedBox(height: 80),
                        _EmptyStockState(),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: _outOfStockProducts.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _OutOfStockItem(
                          product: _outOfStockProducts[index],
                        );
                      },
                    ),
            ),
    );
  }
}

class _EmptyStockState extends StatelessWidget {
  const _EmptyStockState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            color: _lightBlue,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.inventory_2_rounded,
            color: _primaryBlue,
            size: 42,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Stok aman',
          style: TextStyle(
            color: _textDark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tidak ada barang yang stoknya kosong.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _textGrey, fontSize: 13),
        ),
      ],
    );
  }
}

class _OutOfStockItem extends StatelessWidget {
  const _OutOfStockItem({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Barcode: ${product.barcode}',
                  style: const TextStyle(color: _textGrey, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: _lightBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Stok kosong',
              style: TextStyle(
                color: _primaryBlue,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
