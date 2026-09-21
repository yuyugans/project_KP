class StockReceipt {
  final int? id;
  final int productId;
  final String productName;
  final String invoiceNumber;
  final String supplier;
  final int quantity;
  final double buyPrice;
  final double total;
  final String paymentStatus;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final String notes;

  const StockReceipt({
    this.id,
    required this.productId,
    required this.productName,
    required this.invoiceNumber,
    required this.supplier,
    required this.quantity,
    required this.buyPrice,
    required this.total,
    required this.paymentStatus,
    required this.invoiceDate,
    this.dueDate,
    required this.notes,
  });

  factory StockReceipt.fromMap(Map<String, dynamic> map) {
    return StockReceipt(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      invoiceNumber: map['invoice_number'] as String,
      supplier: map['supplier'] as String,
      quantity: map['quantity'] as int,
      buyPrice: (map['buy_price'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      paymentStatus: map['payment_status'] as String,
      invoiceDate: DateTime.parse(map['invoice_date'] as String),
      dueDate: map['due_date'] == null
          ? null
          : DateTime.parse(map['due_date'] as String),
      notes: map['notes'] as String,
    );
  }
}
