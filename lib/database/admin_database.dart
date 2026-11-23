import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/admin_password_hasher.dart';

class AdminDatabase {
  static final AdminDatabase instance = AdminDatabase._();

  final String? _databasePath;
  Database? _database;

  AdminDatabase._({String? databasePath}) : _databasePath = databasePath;

  AdminDatabase.forTesting(String databasePath)
    : this._(databasePath: databasePath);

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final databasePath =
        _databasePath ?? join(await getDatabasesPath(), 'admin_credentials.db');
    _database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE admin_users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE COLLATE NOCASE,
            password_salt TEXT NOT NULL,
            password_hash TEXT NOT NULL
          )
        ''');
      },
    );
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<bool> hasAdminUser() async {
    final db = await database;
    final users = await db.query('admin_users', columns: ['id'], limit: 1);
    return users.isNotEmpty;
  }

  Future<void> createAdminUser({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty) {
      throw ArgumentError.value(username, 'username', 'Username harus diisi');
    }
    if (password.length < 8) {
      throw ArgumentError.value(
        password,
        'password',
        'Password harus minimal 8 karakter',
      );
    }

    final salt = AdminPasswordHasher.generateSalt();
    final passwordHash = await AdminPasswordHasher.hashPassword(password, salt);
    final db = await database;

    await db.insert('admin_users', {
      'username': normalizedUsername,
      'password_salt': salt,
      'password_hash': passwordHash,
    });
  }

  Future<bool> verifyAdminCredentials({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty || password.isEmpty) {
      return false;
    }

    final db = await database;
    final users = await db.query(
      'admin_users',
      where: 'username = ? COLLATE NOCASE',
      whereArgs: [normalizedUsername],
      limit: 1,
    );
    if (users.isEmpty) {
      return false;
    }

    final user = users.first;
    final calculatedHash = await AdminPasswordHasher.hashPassword(
      password,
      user['password_salt'] as String,
    );
    return AdminPasswordHasher.matches(
      user['password_hash'] as String,
      calculatedHash,
    );
  }
}
