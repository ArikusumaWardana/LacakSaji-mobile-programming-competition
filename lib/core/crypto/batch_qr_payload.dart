import 'dart:convert';

/// Canonical Ed25519-signed batch passport payload encoded inside QR Segel Digital.
class BatchQrPayload {
  const BatchQrPayload({
    required this.batchId,
    required this.batchCode,
    required this.sppgId,
    required this.menuName,
    required this.riskCategory,
    required this.sealedAtEpochSec,
    required this.timestampSource,
    required this.signatureB64,
    this.keyId,
    this.allergenTags = const [],
  });

  final String batchId;
  final String batchCode;
  final String sppgId;
  final String menuName;
  final String riskCategory;
  final int sealedAtEpochSec;
  final String timestampSource;
  final String signatureB64;
  final String? keyId;
  final List<String> allergenTags;

  static List<String> normalizeAllergenTags(Iterable<String> raw) {
    final cleaned = <String>{};
    for (final tag in raw) {
      final t = tag.trim().toLowerCase();
      if (t.isNotEmpty) {
        cleaned.add(t);
      }
    }
    final sorted = cleaned.toList()..sort();
    return List<String>.unmodifiable(sorted);
  }

  /// Deterministic string signed and verified offline using Ed25519.
  /// Legacy QRs without `key_id` or `alg` keep exact v1/v2 canonical compatibility.
  String toCanonicalSigningString() {
    return buildCanonicalSigningString(
      batchId: batchId,
      batchCode: batchCode,
      sppgId: sppgId,
      menuName: menuName,
      riskCategory: riskCategory,
      sealedAtEpochSec: sealedAtEpochSec,
      timestampSource: timestampSource,
      keyId: keyId,
      allergenTags: allergenTags,
    );
  }

  static String buildCanonicalSigningString({
    required String batchId,
    required String batchCode,
    required String sppgId,
    required String menuName,
    required String riskCategory,
    required int sealedAtEpochSec,
    required String timestampSource,
    String? keyId,
    List<String> allergenTags = const [],
  }) {
    final base =
        '$batchId|$batchCode|$sppgId|$menuName|$riskCategory|$sealedAtEpochSec|$timestampSource';
    final withKey = (keyId != null && keyId.isNotEmpty) ? '$base|$keyId' : base;
    final normalizedAllergens = normalizeAllergenTags(allergenTags);
    if (normalizedAllergens.isNotEmpty) {
      return '$withKey|alg:${normalizedAllergens.join(',')}';
    }
    return withKey;
  }

  /// Minified JSON stored directly inside QR code (PRD Section 3.2).
  String toMinifiedJson() {
    final normalizedAllergens = normalizeAllergenTags(allergenTags);
    return jsonEncode({
      'batch_id': batchId,
      'batch_code': batchCode,
      'sppg_id': sppgId,
      'menu_name': menuName,
      'risk_category': riskCategory,
      'sealed_at': sealedAtEpochSec,
      'timestamp_source': timestampSource,
      if (keyId != null && keyId!.isNotEmpty) 'key_id': keyId,
      if (normalizedAllergens.isNotEmpty) 'alg': normalizedAllergens,
      'sig': signatureB64,
    });
  }

  static BatchQrPayload? tryParse(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final batchId = decoded['batch_id'];
      final batchCode = decoded['batch_code'];
      final sppgId = decoded['sppg_id'];
      final menuName = decoded['menu_name'];
      final riskCategory = decoded['risk_category'];
      final sealedAt = decoded['sealed_at'];
      final timestampSource = decoded['timestamp_source'];
      final sig = decoded['sig'];
      final keyId = decoded['key_id'];
      final rawAlg = decoded['alg'] ?? decoded['allergens'];

      if (batchId is! String ||
          batchCode is! String ||
          sppgId is! String ||
          menuName is! String ||
          riskCategory is! String ||
          sealedAt is! int ||
          timestampSource is! String ||
          sig is! String ||
          (keyId != null && keyId is! String)) {
        return null;
      }

      var parsedAllergens = const <String>[];
      if (rawAlg is List) {
        parsedAllergens = normalizeAllergenTags(rawAlg.whereType<String>());
      }

      return BatchQrPayload(
        batchId: batchId,
        batchCode: batchCode,
        sppgId: sppgId,
        menuName: menuName,
        riskCategory: riskCategory,
        sealedAtEpochSec: sealedAt,
        timestampSource: timestampSource,
        signatureB64: sig,
        keyId: (keyId is String && keyId.isNotEmpty) ? keyId : null,
        allergenTags: parsedAllergens,
      );
    } catch (_) {
      return null;
    }
  }
}

/// SPPG profile QR payload displayed in D04 so new schools can scan to auto-fill invite code.
class SppgProfileQrPayload {
  const SppgProfileQrPayload({
    required this.sppgId,
    required this.inviteCode,
    required this.name,
    required this.publicKey,
  });

  final String sppgId;
  final String inviteCode;
  final String name;
  final String publicKey;

  String toMinifiedJson() {
    return jsonEncode({
      'type': 'sppg_profile',
      'sppg_id': sppgId,
      'invite_code': inviteCode,
      'name': name,
      'public_key': publicKey,
    });
  }
}
