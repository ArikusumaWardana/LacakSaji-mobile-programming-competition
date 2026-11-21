import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstraction around Android Keystore / Keychain for deterministic testing.
abstract class SecureKeyStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class FlutterSecureKeyStore implements SecureKeyStore {
  FlutterSecureKeyStore({FlutterSecureStorage? storage})
      : _storage =
            storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

/// Manages per-SPPG Ed25519 asymmetric keypairs, signing, and offline verification.
class Ed25519Service {
  Ed25519Service({SecureKeyStore? secureStore})
      : _secureStore = secureStore ?? FlutterSecureKeyStore();

  final SecureKeyStore _secureStore;
  final Ed25519 _algorithm = Ed25519();

  static String _sppgStorageKey(String sppgId) => 'lacak_ed25519_priv_sppg_$sppgId';

  static String _legacyUserStorageKey(String userId) =>
      'lacak_ed25519_priv_$userId';

  /// Used during initial registration before an `sppg_kitchens.id` exists.
  Future<String> generateAndStoreKeyPair(String userId) async {
    final keyPair = await _algorithm.newKeyPair();
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();

    await _secureStore.write(
      _legacyUserStorageKey(userId),
      base64Encode(privateBytes),
    );
    return base64Encode(publicKey.bytes);
  }

  Future<String?> readStoredPrivateKeyB64(String userId) {
    return _secureStore.read(_legacyUserStorageKey(userId));
  }

  Future<SimpleKeyPair> _loadOrCreateSppgKeyPair({
    required String sppgId,
    String? legacyUserId,
  }) async {
    final sppgKey = _sppgStorageKey(sppgId);
    final existingSppgB64 = await _secureStore.read(sppgKey);
    if (existingSppgB64 != null && existingSppgB64.isNotEmpty) {
      return _algorithm.newKeyPairFromSeed(base64Decode(existingSppgB64));
    }

    if (legacyUserId != null && legacyUserId.isNotEmpty) {
      final legacyB64 = await _secureStore.read(_legacyUserStorageKey(legacyUserId));
      if (legacyB64 != null && legacyB64.isNotEmpty) {
        await _secureStore.write(sppgKey, legacyB64);
        return _algorithm.newKeyPairFromSeed(base64Decode(legacyB64));
      }
    }

    final generated = await _algorithm.newKeyPair();
    final seedBytes = await generated.extractPrivateKeyBytes();
    await _secureStore.write(sppgKey, base64Encode(seedBytes));
    return generated;
  }

  Future<String> getOrCreatePublicKeyB64({
    required String sppgId,
    String? legacyUserId,
  }) async {
    final keyPair = await _loadOrCreateSppgKeyPair(
      sppgId: sppgId,
      legacyUserId: legacyUserId,
    );
    final publicKey = await keyPair.extractPublicKey();
    return base64Encode(publicKey.bytes);
  }

  /// Ensures the device holds a valid private key for [sppgId] and syncs its public key
  /// to Supabase whenever a fresh or rotated device key differs from [remotePublicKeyB64].
  Future<String> ensureKeyPairSynced({
    required String sppgId,
    required String? remotePublicKeyB64,
    String? legacyUserId,
    required Future<void> Function(String publicKeyB64) onSyncRemotePublicKey,
  }) async {
    final localPublicKeyB64 = await getOrCreatePublicKeyB64(
      sppgId: sppgId,
      legacyUserId: legacyUserId,
    );
    if (remotePublicKeyB64 == null || remotePublicKeyB64 != localPublicKeyB64) {
      await onSyncRemotePublicKey(localPublicKeyB64);
    }
    return localPublicKeyB64;
  }

  Future<String> signCanonicalPayload({
    required String sppgId,
    required String canonicalData,
    String? legacyUserId,
  }) async {
    final keyPair = await _loadOrCreateSppgKeyPair(
      sppgId: sppgId,
      legacyUserId: legacyUserId,
    );
    final signature = await _algorithm.sign(
      utf8.encode(canonicalData),
      keyPair: keyPair,
    );
    return base64Encode(signature.bytes);
  }

  Future<bool> verifyCanonicalPayload({
    required String canonicalData,
    required String signatureB64,
    required String publicKeyB64,
  }) async {
    try {
      final signatureBytes = base64Decode(signatureB64);
      final publicKeyBytes = base64Decode(publicKeyB64);
      if (signatureBytes.length != 64 || publicKeyBytes.length != 32) {
        return false;
      }
      final publicKey = SimplePublicKey(
        publicKeyBytes,
        type: KeyPairType.ed25519,
      );
      return await _algorithm.verify(
        utf8.encode(canonicalData),
        signature: Signature(signatureBytes, publicKey: publicKey),
      );
    } catch (_) {
      return false;
    }
  }
}

final ed25519ServiceProvider = Provider<Ed25519Service>((ref) {
  return Ed25519Service();
});
