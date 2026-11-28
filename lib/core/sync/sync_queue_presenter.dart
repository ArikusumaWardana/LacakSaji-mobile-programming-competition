import 'dart:convert';

import '../../features/auth/domain/auth_models.dart';
import '../../features/kitchen/domain/kitchen_models.dart';
import '../database/app_database.dart';

/// Structured outcome from a manual or automatic sync attempt.
class OfflineSyncRunReport {
  const OfflineSyncRunReport({
    this.syncedCount = 0,
    this.remainingCount = 0,
    this.failedCount = 0,
    this.otherAccountCount = 0,
    this.firstFailureReason,
    this.isOffline = false,
  });

  final int syncedCount;
  final int remainingCount;
  final int failedCount;
  final int otherAccountCount;
  final String? firstFailureReason;
  final bool isOffline;

  bool get hasFailure => failedCount > 0;

  /// Plain Indonesian feedback shown after tapping Kirim.
  String buildFeedbackMessage() {
    if (isOffline) {
      return 'Perangkat sedang tanpa sinyal internet. Data tetap tersimpan aman di HP.';
    }
    if (syncedCount > 0 && remainingCount == 0) {
      return '$syncedCount data berhasil dikirim ke server.';
    }
    if (syncedCount > 0 && remainingCount > 0) {
      if (firstFailureReason != null) {
        return '$syncedCount data terkirim. $remainingCount data belum terkirim: $firstFailureReason';
      }
      if (otherAccountCount == remainingCount) {
        return '$syncedCount data terkirim. $remainingCount data tersisa milik akun atau peran lain.';
      }
      return '$syncedCount data terkirim. Masih ada $remainingCount data tersisa di antrean.';
    }
    if (failedCount > 0) {
      final reason = firstFailureReason ?? 'Koneksi atau server belum merespons.';
      return 'Gagal mengirim $failedCount data: $reason';
    }
    if (otherAccountCount > 0 && otherAccountCount >= remainingCount) {
      return '$otherAccountCount data tersimpan milik akun atau peran lain yang sebelumnya masuk di HP ini.';
    }
    if (remainingCount > 0) {
      return 'Belum ada data yang berhasil dikirim ($remainingCount data masih menunggu di antrean).';
    }
    return 'Semua data sudah terkirim ke server.';
  }
}

/// Human-readable representation of one item in the local upload queue.
class SyncQueueItemSummary {
  const SyncQueueItemSummary({
    required this.id,
    required this.operationType,
    required this.title,
    required this.detailLine,
    required this.status,
    required this.retryCount,
    required this.belongsToCurrentAccount,
    required this.createdAtUtc,
    this.friendlyError,
    this.accountMismatchHint,
  });

  final int id;
  final String operationType;
  final String title;
  final String detailLine;
  final String status;
  final int retryCount;
  final bool belongsToCurrentAccount;
  final DateTime createdAtUtc;
  final String? friendlyError;
  final String? accountMismatchHint;

  bool get isFailed => status == 'failed';
}

/// Maps raw technical sync errors to plain, actionable Indonesian text.
String formatFriendlySyncError(String? rawError) {
  if (rawError == null || rawError.trim().isEmpty) {
    return 'Pengiriman terhenti. Ketuk Kirim Ulang untuk mencoba lagi.';
  }
  final lower = rawError.toLowerCase();

  if (lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection closed')) {
    return 'Tidak dapat menghubungi server. Pastikan internet atau Wi-Fi aktif lalu coba lagi.';
  }
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return 'Koneksi ke server terlalu lambat. Coba kirim ulang saat sinyal lebih stabil.';
  }
  if (lower.contains('row-level security') ||
      lower.contains('permission denied') ||
      lower.contains('42501') ||
      lower.contains('401') ||
      lower.contains('403') ||
      lower.contains('jwt') ||
      lower.contains('unauthorized') ||
      lower.contains('invalid_grant')) {
    return 'Hak akses atau sesi akun tidak cocok dengan data ini. Coba keluar lalu masuk ulang.';
  }
  if (lower.contains('sample_vaults_inspection_id_fkey') ||
      (lower.contains('23503') && lower.contains('inspection_id'))) {
    return 'Data pemeriksaan makanan untuk sampel ini belum tersimpan di server. Kirim ulang pemeriksaan atau hapus data antrean lama.';
  }
  if (lower.contains('23503') ||
      lower.contains('foreign key') ||
      lower.contains('not present in table')) {
    return 'Data rujukan untuk catatan ini belum tercatat di server.';
  }
  if (lower.contains('23505') || lower.contains('duplicate')) {
    return 'Data ini sudah tercatat sebelumnya di server.';
  }
  if (lower.contains('pathnotfoundexception') ||
      lower.contains('no such file') ||
      lower.contains('cannot find the file')) {
    return 'File foto bukti di penyimpanan HP sudah tidak ditemukan.';
  }
  if (lower.contains('500') ||
      lower.contains('502') ||
      lower.contains('503') ||
      lower.contains('504') ||
      lower.contains('server')) {
    return 'Server sedang sibuk atau dalam perbaikan. Coba beberapa saat lagi.';
  }
  return 'Terjadi kendala saat mengirim ke server. Ketuk Kirim Ulang untuk mencoba lagi.';
}

/// Converts raw queued Drift rows into plain-language summaries for the user.
List<SyncQueueItemSummary> summarizePendingSyncItems(
  List<LocalSyncQueueData> rows, {
  KitchenProfile? kitchen,
  SchoolProfile? school,
  bool isAuthenticated = true,
}) {
  return rows.map((row) {
    final payload = _decodePayloadMap(row.payloadJson);
    final ownership = _evaluateOwnership(
      operationType: row.operationType,
      payload: payload,
      kitchen: kitchen,
      school: school,
      isAuthenticated: isAuthenticated,
    );
    final title = _operationTitle(row.operationType);
    final detail = _buildDetailLine(
      operationType: row.operationType,
      entityId: row.entityId,
      payload: payload,
      createdAtUtc: row.createdAt,
    );
    return SyncQueueItemSummary(
      id: row.id,
      operationType: row.operationType,
      title: title,
      detailLine: detail,
      status: row.status,
      retryCount: row.retryCount,
      belongsToCurrentAccount: ownership.belongsToCurrent,
      createdAtUtc: row.createdAt,
      friendlyError: row.status == 'failed' || (row.lastError?.isNotEmpty ?? false)
          ? formatFriendlySyncError(row.lastError)
          : null,
      accountMismatchHint: ownership.hint,
    );
  }).toList();
}

Map<String, dynamic> _decodePayloadMap(String payloadJson) {
  try {
    final decoded = jsonDecode(payloadJson);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {}
  return const {};
}

String _operationTitle(String operationType) {
  return switch (operationType) {
    'create_batch' => 'Pengiriman Makanan Dapur',
    'create_inspection' => 'Verifikasi & Kondisi Makanan',
    'create_sample' => 'Simpan Sampel 48 Jam',
    'update_sample_status' => 'Pembaruan Status Sampel',
    'create_waste_log' => 'Laporan Sisa Makanan Siswa',
    'create_alert' => 'Laporan Darurat Makanan',
    'resolve_cluster_alert' => 'Klarifikasi Status Darurat',
    'update_alert_pdf_dispatched' => 'Status Kirim PDF Puskesmas',
    'ack_alert' => 'Konfirmasi Peringatan Darurat',
    'sync_school_allergens' => 'Profil Alergen Siswa',
    'rotate_signing_key' => 'Rotasi Kunci Keamanan QR',
    'revoke_signing_key' => 'Pencabutan Kunci QR',
    'upsert_institution_member' => 'Penambahan Anggota Tim',
    'toggle_institution_member' => 'Pembaruan Status Anggota Tim',
    'create_ingredient_log' => 'Catatan Hulu Bahan Baku',
    'upsert_transit_handover' => 'Pindai Transit Kurir',
    'create_tray_return' => 'Serah Terima Ompreng Kosong',
    'update_tray_return_sanitation' => 'Verifikasi & Sanitasi Ompreng',
    _ => 'Data Pemeriksaan Tersimpan',
  };
}

String _buildDetailLine({
  required String operationType,
  required String entityId,
  required Map<String, dynamic> payload,
  required DateTime createdAtUtc,
}) {
  final timeLabel = formatWibDateTime(createdAtUtc);
  final menuName = _cleanStr(payload['menu_name']);
  final batchCode = _cleanStr(payload['batch_code']);
  final labelCode = _cleanStr(payload['label_code']);
  final ingredientName = _cleanStr(payload['ingredient_name']);
  final supplierName = _cleanStr(payload['supplier_name']);

  final subjectParts = <String>[];
  if (ingredientName != null) {
    subjectParts.add(
      supplierName != null ? '$ingredientName ($supplierName)' : ingredientName,
    );
  } else if (menuName != null) {
    subjectParts.add(menuName);
  }
  if (batchCode != null) {
    subjectParts.add(batchCode);
  } else if (labelCode != null) {
    subjectParts.add(labelCode);
  } else if (operationType == 'create_waste_log') {
    final rice = payload['rice_waste_pct'];
    final protein = payload['protein_waste_pct'];
    final veg = payload['veg_waste_pct'];
    if (rice != null && protein != null && veg != null) {
      subjectParts.add('Sisa Nasi $rice%, Lauk $protein%, Sayur $veg%');
    }
  } else if (subjectParts.isEmpty && entityId.isNotEmpty) {
    final shortId = entityId.length > 8 ? entityId.substring(0, 8) : entityId;
    subjectParts.add('ID $shortId');
  }

  subjectParts.add(timeLabel);
  return subjectParts.join(' · ');
}

String? _cleanStr(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

({bool belongsToCurrent, String? hint}) _evaluateOwnership({
  required String operationType,
  required Map<String, dynamic> payload,
  KitchenProfile? kitchen,
  SchoolProfile? school,
  bool isAuthenticated = true,
}) {
  if (!isAuthenticated) {
    return (belongsToCurrent: true, hint: null);
  }

  if (operationType == 'create_batch' ||
      operationType == 'rotate_signing_key' ||
      operationType == 'revoke_signing_key' ||
      operationType == 'create_ingredient_log' ||
      operationType == 'upsert_transit_handover' ||
      operationType == 'update_tray_return_sanitation') {
    if (kitchen == null) {
      return (
        belongsToCurrent: false,
        hint: 'Data ini dibuat dengan akun Dapur SPPG atau Kurir SPPG. Masuk dengan akun SPPG terkait untuk mengirim.',
      );
    }
    final payloadSppgId = _cleanStr(payload['sppg_id']);
    if (payloadSppgId != null && payloadSppgId != kitchen.id) {
      return (
        belongsToCurrent: false,
        hint: 'Data ini milik Dapur SPPG lain yang sebelumnya masuk di HP ini.',
      );
    }
    return (belongsToCurrent: true, hint: null);
  }

  if (operationType == 'upsert_institution_member' ||
      operationType == 'toggle_institution_member') {
    final instType = _cleanStr(payload['institution_type']);
    final instId = _cleanStr(payload['institution_id']);
    if (instType == 'sppg') {
      final matches = kitchen != null && (instId == null || instId == kitchen.id);
      return (
        belongsToCurrent: matches,
        hint: matches
            ? null
            : 'Data tim ini milik akun Dapur SPPG lain yang sebelumnya masuk di HP ini.',
      );
    }
    if (instType == 'school') {
      final matches = school != null && (instId == null || instId == school.id);
      return (
        belongsToCurrent: matches,
        hint: matches
            ? null
            : 'Data tim ini milik akun Sekolah lain yang sebelumnya masuk di HP ini.',
      );
    }
  }

  if (operationType == 'resolve_cluster_alert') {
    final payloadSppgId = _cleanStr(payload['sppg_id']);
    final payloadSchoolId = _cleanStr(payload['reporter_school_id']);
    if (kitchen != null &&
        (payloadSppgId == null || payloadSppgId == kitchen.id)) {
      return (belongsToCurrent: true, hint: null);
    }
    if (school != null &&
        (payloadSchoolId == null || payloadSchoolId == school.id)) {
      return (belongsToCurrent: true, hint: null);
    }
    return (
      belongsToCurrent: false,
      hint: 'Klarifikasi status darurat ini milik institusi lain yang sebelumnya masuk di HP ini.',
    );
  }

  // Remaining operations belong to a school account.
  if (school == null) {
    return (
      belongsToCurrent: false,
      hint: 'Data ini dibuat dengan akun Sekolah. Masuk sebagai Sekolah untuk mengirim, atau hapus jika hanya data uji coba.',
    );
  }

  final payloadSchoolId =
      _cleanStr(payload['school_id']) ?? _cleanStr(payload['reporter_school_id']);
  if (payloadSchoolId != null && payloadSchoolId != school.id) {
    return (
      belongsToCurrent: false,
      hint: 'Data ini milik akun Sekolah lain yang sebelumnya masuk di HP ini.',
    );
  }

  return (belongsToCurrent: true, hint: null);
}
