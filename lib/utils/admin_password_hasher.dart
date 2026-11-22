import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class AdminPasswordHasher {
  static const _iterations = 120000;

  static String generateSalt() {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(salt);
  }

  static Future<String> hashPassword(String password, String salt) {
    return Isolate.run(() => _derivePasswordHash(password, base64Decode(salt)));
  }

  static bool matches(String expectedHash, String actualHash) {
    final expected = base64Decode(expectedHash);
    final actual = base64Decode(actualHash);
    if (expected.length != actual.length) {
      return false;
    }

    var difference = 0;
    for (var index = 0; index < expected.length; index++) {
      difference |= expected[index] ^ actual[index];
    }
    return difference == 0;
  }
}

String _derivePasswordHash(String password, List<int> salt) {
  final hmac = Hmac(sha256, utf8.encode(password));
  final firstBlock = BytesBuilder(copy: false)
    ..add(salt)
    ..add(const [0, 0, 0, 1]);
  var current = hmac.convert(firstBlock.takeBytes()).bytes;
  final result = List<int>.from(current);

  for (
    var iteration = 1;
    iteration < AdminPasswordHasher._iterations;
    iteration++
  ) {
    current = hmac.convert(current).bytes;
    for (var index = 0; index < result.length; index++) {
      result[index] ^= current[index];
    }
  }

  return base64Encode(result);
}
