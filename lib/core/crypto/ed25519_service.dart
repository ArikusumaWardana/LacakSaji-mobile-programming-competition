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

/// Public key metadata paired with a deterministic key identifier (`key_id`).
class SppgSigningKeyMaterial {
  const SppgSigningKeyMaterial({
    required this.keyId,
    required this.publicKeyB64,
  });

  final String keyId;
  final String publicKeyB64;
}

/// Manages per-SPPG Ed25519 asymmetric keypairs, key rotation, signing, and offline verification.
class Ed25519Service {
  Ed25519Service({SecureKeyStore? secureStore})
      : _secureStore = secureStore ?? FlutterSecureKeyStore();

  final SecureKeyStore _secureStore;
  final Ed25519 _algorithm = Ed25519();
  static final Sha256 _sha256 = Sha256();

  static String _sppgStorageKey(String sppgId) => 'lacak_ed25519_priv_sppg_$sppgId';

  static String _sppgKeyIdStorageKey(String sppgId) =>
      'lacak_ed25519_kid_sppg_$sppgId';

  static String _seedByKeyIdStorageKey(String keyId) =>
      'lacak_ed25519_priv_kid_$keyId';

  static String _legacyUserStorageKey(String userId) =>
      'lacak_ed25519_priv_$userId';

  /// Derives a compact, deterministic `key_id` from an Ed25519 public key.
  static Future<String> deriveDeterministicKeyId(String publicKeyB64) async {
    final digest = await _sha256.hash(utf8.encode(publicKeyB64));
    final prefixHex = digest.bytes
        .take(6)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'key-$prefixHex';
  }

  /// Checks whether a key marked [status] must reject a QR sealed at [sealedAtUtc].
  /// Retired keys remain valid for older QRs; revoked keys always reject offline_unverified
  /// QRs (preventing offline clock-rollback spoofing) and reject QRs sealed at or
  /// after [revokedAtUtc] (or all QRs if revocation timestamp is absent).
  static bool isRevokedForSealTime({
    required String status,
    required DateTime? revokedAtUtc,
    required DateTime sealedAtUtc,
    String? timestampSource,
  }) {
    if (status != 'revoked') {
      return false;
    }
    if (timestampSource == 'offline_unverified') {
      return true;
    }
    if (revokedAtUtc == null) {
      return true;
    }
    return !sealedAtUtc.toUtc().isBefore(revokedAtUtc.toUtc());
  }

  /// Used during initial registration before an `sppg_kitchens.id` exists.
  Future<String> generateAndStoreKeyPair(String userId) async {
    final keyPair = await _algorithm.newKeyPair();
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    final pubB64 = base64Encode(publicKey.bytes);
    final seedB64 = base64Encode(privateBytes);

    await _secureStore.write(_legacyUserStorageKey(userId), seedB64);
    final keyId = await deriveDeterministicKeyId(pubB64);
    await _secureStore.write(_seedByKeyIdStorageKey(keyId), seedB64);
    return pubB64;
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

  /// Returns active key material (`key_id` + public key) for [sppgId], ensuring
  /// the private seed is persisted both by `sppgId` and by `keyId`.
  Future<SppgSigningKeyMaterial> getOrCreateActiveKeyMaterial({
    required String sppgId,
    String? legacyUserId,
  }) async {
    final keyPair = await _loadOrCreateSppgKeyPair(
      sppgId: sppgId,
      legacyUserId: legacyUserId,
    );
    final publicKey = await keyPair.extractPublicKey();
    final pubB64 = base64Encode(publicKey.bytes);
    final seedBytes = await keyPair.extractPrivateKeyBytes();
    final seedB64 = base64Encode(seedBytes);

    final storedKeyId = await _secureStore.read(_sppgKeyIdStorageKey(sppgId));
    final derivedKeyId = (storedKeyId != null && storedKeyId.isNotEmpty)
        ? storedKeyId
        : await deriveDeterministicKeyId(pubB64);

    if (storedKeyId == null || storedKeyId.isEmpty) {
      await _secureStore.write(_sppgKeyIdStorageKey(sppgId), derivedKeyId);
    }
    await _secureStore.write(_seedByKeyIdStorageKey(derivedKeyId), seedB64);

    return SppgSigningKeyMaterial(
      keyId: derivedKeyId,
      publicKeyB64: pubB64,
    );
  }

  /// Rotates the active Ed25519 keypair for [sppgId] on this device and returns the new key material.
  Future<SppgSigningKeyMaterial> rotateKeyPair({
    required String sppgId,
  }) async {
    final generated = await _algorithm.newKeyPair();
    final seedBytes = await generated.extractPrivateKeyBytes();
    final publicKey = await generated.extractPublicKey();
    final pubB64 = base64Encode(publicKey.bytes);
    final seedB64 = base64Encode(seedBytes);
    final keyId = await deriveDeterministicKeyId(pubB64);

    await _secureStore.write(_sppgStorageKey(sppgId), seedB64);
    await _secureStore.write(_sppgKeyIdStorageKey(sppgId), keyId);
    await _secureStore.write(_seedByKeyIdStorageKey(keyId), seedB64);

    return SppgSigningKeyMaterial(
      keyId: keyId,
      publicKeyB64: pubB64,
    );
  }

  /// Signs a canonical batch string generated from the active `key_id`.
  Future<({String keyId, String publicKeyB64, String signatureB64})>
  signBatchWithKeyId({
    required String sppgId,
    required String Function(String keyId) buildCanonicalForKeyId,
    String? legacyUserId,
  }) async {
    final material = await getOrCreateActiveKeyMaterial(
      sppgId: sppgId,
      legacyUserId: legacyUserId,
    );
    final seedByKey = await _secureStore.read(
      _seedByKeyIdStorageKey(material.keyId),
    );
    final SimpleKeyPair keyPair;
    if (seedByKey != null && seedByKey.isNotEmpty) {
      keyPair = await _algorithm.newKeyPairFromSeed(base64Decode(seedByKey));
    } else {
      keyPair = await _loadOrCreateSppgKeyPair(
        sppgId: sppgId,
        legacyUserId: legacyUserId,
      );
    }

    final canonicalData = buildCanonicalForKeyId(material.keyId);
    final signature = await _algorithm.sign(
      utf8.encode(canonicalData),
      keyPair: keyPair,
    );
    return (
      keyId: material.keyId,
      publicKeyB64: material.publicKeyB64,
      signatureB64: base64Encode(signature.bytes),
    );
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
