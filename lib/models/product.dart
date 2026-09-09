  class Product {
    final int? id;
    final int categoryId;
    final String name;
    final String barcode;
    final double buyPrice;
    final double sellPrice;
    final int stock;
    final int minStock;

    Product({
      this.id,
      required this.categoryId,
      required this.name,
      required this.barcode,
      required this.buyPrice,
      required this.sellPrice,
      required this.stock,
      required this.minStock,
    });

    Map<String, dynamic> toMap() {
      return {
        'id': id,
        'category_id': categoryId,
        'name': name,
        'barcode': barcode,
        'buy_price': buyPrice,
        'sell_price': sellPrice,
        'stock': stock,
        'min_stock': minStock,
      };
    }

    factory Product.fromMap(Map<String, dynamic> map) {
      return Product(
        id: map['id'],
        categoryId: map['category_id'],
        name: map['name'],
        barcode: map['barcode'],
        buyPrice: map['buy_price'],
        sellPrice: map['sell_price'],
        stock: map['stock'],
        minStock: map['min_stock'],
      );
    }
  }