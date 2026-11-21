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
  });

  final String batchId;
  final String batchCode;
  final String sppgId;
  final String menuName;
  final String riskCategory;
  final int sealedAtEpochSec;
  final String timestampSource;
  final String signatureB64;

  /// Deterministic string signed and verified offline using Ed25519.
  String toCanonicalSigningString() {
    return buildCanonicalSigningString(
      batchId: batchId,
      batchCode: batchCode,
      sppgId: sppgId,
      menuName: menuName,
      riskCategory: riskCategory,
      sealedAtEpochSec: sealedAtEpochSec,
      timestampSource: timestampSource,
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
  }) {
    return '$batchId|$batchCode|$sppgId|$menuName|$riskCategory|$sealedAtEpochSec|$timestampSource';
  }

  /// Minified JSON stored directly inside QR code (PRD Section 3.2).
  String toMinifiedJson() {
    return jsonEncode({
      'batch_id': batchId,
      'batch_code': batchCode,
      'sppg_id': sppgId,
      'menu_name': menuName,
      'risk_category': riskCategory,
      'sealed_at': sealedAtEpochSec,
      'timestamp_source': timestampSource,
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

      if (batchId is! String ||
          batchCode is! String ||
          sppgId is! String ||
          menuName is! String ||
          riskCategory is! String ||
          sealedAt is! int ||
          timestampSource is! String ||
          sig is! String) {
        return null;
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
