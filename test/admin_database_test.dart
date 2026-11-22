import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:project_kp/database/admin_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('stores admin credentials and verifies passwords from SQLite', () async {
    final directory = await Directory.systemTemp.createTemp('admin_database_');
    final database = AdminDatabase.forTesting(
      join(directory.path, 'admin_credentials.db'),
    );
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    expect(await database.hasAdminUser(), isFalse);

    await database.createAdminUser(
      username: 'admin',
      password: 'secure-password',
    );

    expect(await database.hasAdminUser(), isTrue);
    expect(
      await database.verifyAdminCredentials(
        username: 'ADMIN',
        password: 'secure-password',
      ),
      isTrue,
    );
    expect(
      await database.verifyAdminCredentials(
        username: 'admin',
        password: 'wrong-password',
      ),
      isFalse,
    );

    final db = await database.database;
    final storedUser = (await db.query('admin_users')).single;
    expect(storedUser['password_hash'], isNot('secure-password'));
    expect(storedUser['password_salt'], isNotEmpty);
    await expectLater(
      database.createAdminUser(
        username: 'another-admin',
        password: 'another-password',
      ),
      throwsA(isA<StateError>()),
    );
  });
}
