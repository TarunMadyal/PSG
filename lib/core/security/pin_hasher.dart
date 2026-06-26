import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hashes and verifies PINs / passwords using **PBKDF2-HMAC-SHA256** with a
/// per-credential random salt.
///
/// We never store a raw PIN. The stored format is self-describing so the
/// iteration count and salt travel with the hash:
///
/// `pbkdf2_sha256$<iterations>$<saltB64>$<hashB64>`
///
/// PBKDF2 (key stretching) makes brute-forcing a short numeric PIN far slower
/// than a plain hash, while remaining pure-Dart (no native deps) so it runs the
/// same on every device.
class PinHasher {
  const PinHasher({this.iterations = 12000, this.keyLength = 32});

  final int iterations;
  final int keyLength;

  static const String _algo = 'pbkdf2_sha256';

  /// Produces a storable hash string for [secret].
  String hash(String secret, {Random? random}) {
    final salt = _randomBytes(16, random);
    final key = _pbkdf2(utf8.encode(secret), salt, iterations, keyLength);
    return '$_algo\$$iterations\$${base64.encode(salt)}\$${base64.encode(key)}';
  }

  /// Returns true if [secret] matches a previously [hash]ed value [stored].
  bool verify(String secret, String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != _algo) return false;

    final iters = int.tryParse(parts[1]);
    if (iters == null) return false;

    final salt = base64.decode(parts[2]);
    final expected = base64.decode(parts[3]);
    final actual = _pbkdf2(utf8.encode(secret), salt, iters, expected.length);

    return _constantTimeEquals(actual, expected);
  }

  // ---------------------------------------------------------------------------

  static Uint8List _randomBytes(int length, Random? random) {
    final rng = random ?? Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return bytes;
  }

  /// PBKDF2 with HMAC-SHA256 as the pseudo-random function.
  static Uint8List _pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations,
    int keyLength,
  ) {
    final hmac = Hmac(sha256, password);
    const hLen = 32; // SHA-256 output size
    final blocks = (keyLength / hLen).ceil();
    final output = BytesBuilder();

    for (var block = 1; block <= blocks; block++) {
      // INT_32_BE(block)
      final blockIndex = Uint8List(4)
        ..[0] = (block >> 24) & 0xff
        ..[1] = (block >> 16) & 0xff
        ..[2] = (block >> 8) & 0xff
        ..[3] = block & 0xff;

      var u = hmac.convert([...salt, ...blockIndex]).bytes;
      final t = Uint8List.fromList(u);

      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      output.add(t);
    }

    return output.toBytes().sublist(0, keyLength);
  }

  /// Constant-time comparison to avoid timing side-channels.
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
