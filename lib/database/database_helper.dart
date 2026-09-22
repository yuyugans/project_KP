import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/cart_item.dart';
import '../models/transaction_record.dart';
import '../models/stock_receipt.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  final ValueNotifier<int> transactionChanges = ValueNotifier<int>(0);
  final ValueNotifier<int> productChanges = ValueNotifier<int>(0);

  static Database? _database;

  DatabaseHelper._init();

  void _notifyProductChanges() {
    // Notify listeners after the current database operation has fully
    // completed, so their follow-up queries cannot overlap the transaction.
    Future<void>.delayed(Duration.zero, () {
      productChanges.value++;
    });
  }

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDB('pos_inventory.db');

    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();

    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _seedDefaultCategories(Database db) async {
    final defaultCategories = ['Material Bangunan', 'Obat/Pertanian'];

    for (final categoryName in defaultCategories) {
      await db.insert('categories', {
        'name': categoryName,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        barcode TEXT NOT NULL,
        buy_price REAL NOT NULL,
        sell_price REAL NOT NULL,
        stock INTEGER NOT NULL,
        min_stock INTEGER NOT NULL
      )
    ''');

    await _createTransactionTables(db);
    await _createStockReceiptTable(db);
    await _seedDefaultCategories(db);
  }

  Future<void> _createStockReceiptTable(Database db) async {
    await db.execute('''
      CREATE TABLE stock_receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        invoice_number TEXT NOT NULL,
        supplier TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        buy_price REAL NOT NULL,
        total REAL NOT NULL,
        payment_status TEXT NOT NULL,
        invoice_date TEXT NOT NULL,
        due_date TEXT,
        notes TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createTransactionTables(Database db) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total REAL NOT NULL,
        payment REAL NOT NULL,
        change REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        category_name TEXT NOT NULL,
        unit_price REAL NOT NULL,
        buy_price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id)
      )
    ''');
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;

    final id = await db.insert('products', product.toMap());
    _notifyProductChanges();
    return id;
  }

  Future<List<Product>> getProducts() async {
    final db = await database;

    final result = await db.query('products', orderBy: 'id DESC');

    return result.map((map) {
      return Product.fromMap(map);
    }).toList();
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty) {
      return null;
    }

    final db = await database;
    final result = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [normalizedBarcode],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return Product.fromMap(result.first);
  }

  Future<bool> isBarcodeAvailable(
    String barcode, {
    int? excludingProductId,
  }) async {
    final normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty) {
      return false;
    }

    final db = await database;
    final result = await db.query(
      'products',
      columns: ['id'],
      where: excludingProductId == null
          ? 'barcode = ?'
          : 'barcode = ? AND id != ?',
      whereArgs: excludingProductId == null
          ? [normalizedBarcode]
          : [normalizedBarcode, excludingProductId],
      limit: 1,
    );

    return result.isEmpty;
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;

    final updatedRows = await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
    _notifyProductChanges();
    return updatedRows;
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;

    final deletedRows = await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyProductChanges();
    return deletedRows;
  }

  Future<void> ensureDefaultCategories() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM categories'),
    );

    if (count == null || count == 0) {
      await _seedDefaultCategories(db);
    }
  }

  Future<List<Category>> getCategories() async {
    final db = await database;

    final result = await db.query('categories', orderBy: 'id ASC');

    return result.map((map) {
      return Category.fromMap(map);
    }).toList();
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _seedDefaultCategories(db);
    }

    if (oldVersion < 3) {
      await _createTransactionTables(db);
    }

    if (oldVersion < 4) {
      final columns = await db.rawQuery('PRAGMA table_info(transaction_items)');
      final hasBuyPrice = columns.any(
        (column) => column['name'] == 'buy_price',
      );

      if (!hasBuyPrice) {
        await db.execute(
          'ALTER TABLE transaction_items ADD COLUMN buy_price REAL NOT NULL DEFAULT 0',
        );
      }
    }

    if (oldVersion < 5) {
      await db.execute('''
        UPDATE transaction_items
        SET buy_price = (
          SELECT buy_price
          FROM products
          WHERE products.id = transaction_items.product_id
        )
        WHERE buy_price = 0
          AND product_id IS NOT NULL
          AND EXISTS (
            SELECT 1
            FROM products
            WHERE products.id = transaction_items.product_id
          )
      ''');
    }

    if (oldVersion < 6) {
      await _createStockReceiptTable(db);
    }
  }

  Future<void> insertStockReceipt({
    required StockReceipt receipt,
    required int currentStock,
  }) async {
    await insertStockReceipts([receipt]);
  }

  Future<void> insertStockReceipts(List<StockReceipt> receipts) async {
    if (receipts.isEmpty) {
      throw ArgumentError('Minimal satu produk harus dicatat');
    }
    final db = await database;

    await db.transaction((txn) async {
      for (final receipt in receipts) {
        final updatedRows = await txn.rawUpdate(
          'UPDATE products '
          'SET stock = stock + ?, buy_price = ? '
          'WHERE id = ?',
          [receipt.quantity, receipt.buyPrice, receipt.productId],
        );
        if (updatedRows != 1) {
          throw StateError('Produk ${receipt.productName} tidak ditemukan');
        }

        await txn.insert('stock_receipts', {
          'product_id': receipt.productId,
          'product_name': receipt.productName,
          'invoice_number': receipt.invoiceNumber,
          'supplier': receipt.supplier,
          'quantity': receipt.quantity,
          'buy_price': receipt.buyPrice,
          'total': receipt.total,
          'payment_status': receipt.paymentStatus,
          'invoice_date': receipt.invoiceDate.toIso8601String(),
          'due_date': receipt.dueDate?.toIso8601String(),
          'notes': receipt.notes,
        });
      }
    });

    _notifyProductChanges();
  }

  Future<List<int>> insertStockReceiptsWithNewProducts({
    required List<StockReceipt> receipts,
    required Map<int, Product> newProducts,
  }) async {
    if (receipts.isEmpty) {
      throw ArgumentError('Minimal satu produk harus dicatat');
    }

    final db = await database;
    final createdProductIds = <int>[];

    await db.transaction((txn) async {
      final productIds = <int, int>{};
      for (final entry in newProducts.entries) {
        final productId = await txn.insert('products', entry.value.toMap());
        productIds[entry.key] = productId;
        createdProductIds.add(productId);
      }

      for (final receipt in receipts) {
        final productId = productIds[receipt.productId] ?? receipt.productId;
        final updatedRows = await txn.rawUpdate(
          'UPDATE products SET stock = stock + ?, buy_price = ? WHERE id = ?',
          [receipt.quantity, receipt.buyPrice, productId],
        );
        if (updatedRows != 1) {
          throw StateError('Produk ${receipt.productName} tidak ditemukan');
        }

        await txn.insert('stock_receipts', {
          'product_id': productId,
          'product_name': receipt.productName,
          'invoice_number': receipt.invoiceNumber,
          'supplier': receipt.supplier,
          'quantity': receipt.quantity,
          'buy_price': receipt.buyPrice,
          'total': receipt.total,
          'payment_status': receipt.paymentStatus,
          'invoice_date': receipt.invoiceDate.toIso8601String(),
          'due_date': receipt.dueDate?.toIso8601String(),
          'notes': receipt.notes,
        });
      }
    });

    _notifyProductChanges();
    return createdProductIds;
  }

  Future<List<StockReceipt>> getStockReceipts() async {
    final db = await database;
    final rows = await db.query(
      'stock_receipts',
      orderBy: 'invoice_date DESC, id DESC',
    );
    return rows.map(StockReceipt.fromMap).toList();
  }

  Future<int> insertTransaction({
    required List<CartItem> items,
    required Map<int, String> categoryNames,
    required double total,
    required double payment,
    required double change,
  }) async {
    final db = await database;

    final transactionId = await db.transaction((txn) async {
      final transactionId = await txn.insert('transactions', {
        'total': total,
        'payment': payment,
        'change': change,
        'created_at': DateTime.now().toIso8601String(),
      });

      for (final item in items) {
        final productId = item.product.id;
        if (productId == null) {
          throw StateError('Produk tidak memiliki ID yang valid');
        }

        final updatedRows = await txn.update(
          'products',
          {'stock': item.product.stock - item.quantity},
          where: 'id = ? AND stock >= ?',
          whereArgs: [productId, item.quantity],
        );

        if (updatedRows != 1) {
          throw StateError('Stok produk ${item.product.name} tidak mencukupi');
        }

        await txn.insert('transaction_items', {
          'transaction_id': transactionId,
          'product_id': productId,
          'product_name': item.product.name,
          'category_id': item.product.categoryId,
          'category_name':
              categoryNames[item.product.categoryId] ?? 'Tidak diketahui',
          'unit_price': item.product.sellPrice,
          'buy_price': item.product.buyPrice,
          'quantity': item.quantity,
          'subtotal': item.subtotal,
        });
      }

      return transactionId;
    });

    transactionChanges.value++;
    return transactionId;
  }

  Future<List<TransactionRecord>> getTransactions() async {
    final db = await database;
    final transactionRows = await db.query(
      'transactions',
      orderBy: 'created_at DESC, id DESC',
    );
    final itemRows = await db.query('transaction_items');

    return transactionRows.map((transaction) {
      final transactionId = transaction['id'] as int;
      final items = itemRows
          .where((item) => item['transaction_id'] == transactionId)
          .map(
            (item) => TransactionItemRecord(
              productId: item['product_id'] as int?,
              productName: item['product_name'] as String,
              categoryId: item['category_id'] as int,
              categoryName: item['category_name'] as String,
              unitPrice: (item['unit_price'] as num).toDouble(),
              buyPrice: (item['buy_price'] as num).toDouble(),
              quantity: item['quantity'] as int,
              subtotal: (item['subtotal'] as num).toDouble(),
            ),
          )
          .toList();

      return TransactionRecord(
        id: transactionId,
        total: (transaction['total'] as num).toDouble(),
        payment: (transaction['payment'] as num).toDouble(),
        change: (transaction['change'] as num).toDouble(),
        createdAt: DateTime.parse(transaction['created_at'] as String),
        items: items,
      );
    }).toList();
  }

  Future<void> deleteAllTransactions() async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('transaction_items');
      await txn.delete('transactions');
    });

    transactionChanges.value++;
  }
}
