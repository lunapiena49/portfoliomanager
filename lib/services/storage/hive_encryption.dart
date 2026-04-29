import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// Manages the AES-256 master key used to encrypt every Hive box opened by
/// [LocalStorageService].
///
/// Lifecycle:
///   * First run: a 32-byte cryptographically-random key is generated and
///     stored in [FlutterSecureStorage], which is platform-backed
///     (Keychain on iOS, EncryptedSharedPreferences on Android, DPAPI on
///     Windows, libsecret on Linux). The key never lives in plain Hive.
///   * Subsequent runs: the key is loaded from secure storage and reused.
///   * Web: returns null. Hive uses IndexedDB and there is no place to
///     park the key safely from a JavaScript context, so we keep web
///     boxes plaintext for v1.0. The webapp banner already warns users
///     not to store sensitive data in the browser.
///
/// The cipher used by [HiveAesCipher] is AES-256/CTR with HMAC-SHA256, so
/// a single 256-bit key is sufficient.
class HiveEncryption {
  HiveEncryption._();

  static const String _secureStorageKey = 'hive_master_key_v1';

  // FlutterSecureStorage v10 retired the encryptedSharedPreferences flag
  // (Jetpack Security deprecated upstream). The default backend now wraps
  // the OS keystore directly and migrates legacy entries automatically.
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static HiveAesCipher? _cachedCipher;

  /// Returns the AES cipher to pass to `Hive.openBox(..., encryptionCipher:)`.
  ///
  /// Returns null on web, where encryption is disabled (see class docs).
  static Future<HiveAesCipher?> getCipher() async {
    if (kIsWeb) return null;

    final cached = _cachedCipher;
    if (cached != null) return cached;

    final key = await _readOrCreateKey();
    final cipher = HiveAesCipher(key);
    _cachedCipher = cipher;
    return cipher;
  }

  static Future<List<int>> _readOrCreateKey() async {
    final existing = await _storage.read(key: _secureStorageKey);
    if (existing != null && existing.isNotEmpty) {
      try {
        final decoded = base64Decode(existing);
        if (decoded.length == 32) {
          return decoded;
        }
      } catch (_) {
        // Fall through and regenerate. A corrupted entry is safer to
        // rotate than to keep around.
      }
    }

    final fresh = _generateKey();
    await _storage.write(
      key: _secureStorageKey,
      value: base64Encode(fresh),
    );
    return fresh;
  }

  static Uint8List _generateKey() {
    final rng = Random.secure();
    final bytes = Uint8List(32);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return bytes;
  }

  /// True when an encryption key has been provisioned. Test hook only --
  /// production code calls [getCipher] and lets it lazily create the key.
  @visibleForTesting
  static Future<bool> hasKey() async {
    if (kIsWeb) return false;
    final raw = await _storage.read(key: _secureStorageKey);
    return raw != null && raw.isNotEmpty;
  }

  /// Reset the cipher cache. Tests only.
  @visibleForTesting
  static void resetForTests() {
    _cachedCipher = null;
  }
}
