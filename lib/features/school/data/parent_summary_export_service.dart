import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../alerts/domain/cluster_alert_models.dart';
import '../../allergens/domain/allergen_models.dart';
import '../../kitchen/data/batch_export_service.dart';
import '../../kitchen/domain/kitchen_models.dart';

typedef ParentSummaryPngCapturer =
    Future<Uint8List> Function(GlobalKey boundaryKey);

final parentSummaryPngCapturerProvider = Provider<ParentSummaryPngCapturer>((
  ref,
) {
  return captureRepaintBoundaryPng;
});

abstract class ParentSummaryExportService {
  Future<String> shareParentSummaryPng({
    required String schoolName,
    required DateTime dateUtc,
    required String menuName,
    required String batchCode,
    required DateTime cookedAtUtc,
    required DateTime arrivedAtUtc,
    required String sampleLabelCode,
    required List<String> allergenTags,
    required Uint8List pngBytes,
  });
}

class DeviceParentSummaryExportService implements ParentSummaryExportService {
  /// Builds a clean plain-text caption for parents/school committee WhatsApp groups.
  /// Strictly excludes phone numbers, reporter names, internal KLB logs, Unicode emoji, and em-dash.
  static String buildParentWhatsAppCaption({
    required String schoolName,
    required DateTime dateUtc,
    required String menuName,
    required String batchCode,
    required DateTime cookedAtUtc,
    required DateTime arrivedAtUtc,
    required String sampleLabelCode,
    required List<String> allergenTags,
  }) {
    final allergenText = allergenTags.isEmpty
        ? 'Tidak ada alergen utama ditandai'
        : allergenTags.map(AllergenTag.displayLabelFor).join(', ');

    final buffer = StringBuffer()
      ..writeln('*RINGKASAN HARIAN MAKANAN SEKOLAH*')
      ..writeln('- Sekolah: $schoolName')
      ..writeln('- Tanggal: ${formatIndonesianDate(dateUtc)}')
      ..writeln('- Menu ($batchCode): $menuName')
      ..writeln('- Jam Masak & Segel: ${formatWibTime(cookedAtUtc)}')
      ..writeln('- Jam Tiba di Sekolah: ${formatWibTime(arrivedAtUtc)}')
      ..writeln(
        '- Status Pemeriksaan: Lulus Cek Visual & Bank Sampel Tersimpan ($sampleLabelCode)',
      )
      ..writeln('- Informasi Alergen Menu: $allergenText')
      ..writeln()
      ..write('Informasi publik resmi untuk Wali Murid dan Komite Sekolah.');
    return sanitizeZeroSlopCopy(buffer.toString());
  }

  @override
  Future<String> shareParentSummaryPng({
    required String schoolName,
    required DateTime dateUtc,
    required String menuName,
    required String batchCode,
    required DateTime cookedAtUtc,
    required DateTime arrivedAtUtc,
    required String sampleLabelCode,
    required List<String> allergenTags,
    required Uint8List pngBytes,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final safeCode = batchCode.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final filePath = p.join(tempDir.path, 'ringkasan_wali_$safeCode.png');
    final file = File(filePath);
    await file.writeAsBytes(pngBytes, flush: true);

    final caption = buildParentWhatsAppCaption(
      schoolName: schoolName,
      dateUtc: dateUtc,
      menuName: menuName,
      batchCode: batchCode,
      cookedAtUtc: cookedAtUtc,
      arrivedAtUtc: arrivedAtUtc,
      sampleLabelCode: sampleLabelCode,
      allergenTags: allergenTags,
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        subject: sanitizeZeroSlopCopy(
          'Ringkasan Harian Makanan $schoolName ($batchCode)',
        ),
        text: caption,
      ),
    );
    return file.path;
  }
}

final parentSummaryExportServiceProvider = Provider<ParentSummaryExportService>(
  (ref) {
    return DeviceParentSummaryExportService();
  },
);
