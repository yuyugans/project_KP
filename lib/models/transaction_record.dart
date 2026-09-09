class TransactionRecord {
  final int id;
  final double total;
  final double payment;
  final double change;
  final DateTime createdAt;
  final List<TransactionItemRecord> items;

  const TransactionRecord({
    required this.id,
    required this.total,
    required this.payment,
    required this.change,
    required this.createdAt,
    required this.items,
  });

  Map<String, List<TransactionItemRecord>> get itemsByCategory {
    final groupedItems = <String, List<TransactionItemRecord>>{};

    for (final item in items) {
      groupedItems.putIfAbsent(item.categoryName, () => []).add(item);
    }

    return groupedItems;
  }
}

class TransactionItemRecord {
  final int? productId;
  final String productName;
  final int categoryId;
  final String categoryName;
  final double unitPrice;
  final double buyPrice;
  final int quantity;
  final double subtotal;

  double get totalCost => buyPrice * quantity;

  const TransactionItemRecord({
    required this.productId,
    required this.productName,
    required this.categoryId,
    required this.categoryName,
    required this.unitPrice,
    required this.buyPrice,
    required this.quantity,
    required this.subtotal,
  });
}
