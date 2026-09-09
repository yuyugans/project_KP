import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/cart_item.dart';
import '../models/transaction_record.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  final ValueNotifier<int> transactionChanges = ValueNotifier<int>(0);
  final ValueNotifier<int> productChanges = ValueNotifier<int>(0);

  static Database? _database;

  DatabaseHelper._init();

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
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
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
    productChanges.value++;
    return id;
  }

  Future<List<Product>> getProducts() async {
    final db = await database;

    final result = await db.query('products', orderBy: 'id DESC');

    return result.map((map) {
      return Product.fromMap(map);
    }).toList();
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;

    final updatedRows = await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
    productChanges.value++;
    return updatedRows;
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;

    final deletedRows = await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    productChanges.value++;
    return deletedRows;
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
      await db.insert('categories', {'name': 'Material Bangunan'});

      await db.insert('categories', {'name': 'Obat/Pertanian'});
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
