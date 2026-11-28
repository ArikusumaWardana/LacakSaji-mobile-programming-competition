import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../alerts/domain/cluster_alert_models.dart';
import '../../auth/domain/auth_models.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../../school/domain/danger_zone_calculator.dart';

abstract class KlbReportPdfService {
  String buildWhatsAppSummaryText({
    required PuskesmasDraftArgs args,
    required SchoolProfile school,
  });

  Future<Uint8List> buildKlbReportPdfBytes({
    required PuskesmasDraftArgs args,
    required SchoolProfile school,
    Uint8List? photoBytesOverride,
  });

  Future<String> generateAndSharePdfToWhatsApp({
    required PuskesmasDraftArgs args,
    required SchoolProfile school,
    Uint8List? photoBytesOverride,
  });

  Future<String> sharePdfToOtherApps({
    required PuskesmasDraftArgs args,
    required SchoolProfile school,
    Uint8List? photoBytesOverride,
  });

  Future<bool> openDirectWhatsAppChat({
    required String puskesmasWa,
    required String summaryText,
  });
}

class DeviceKlbReportPdfService implements KlbReportPdfService {
  static const MethodChannel _whatsAppChannel = MethodChannel(
    'com.example.lacak_saji/whatsapp',
  );

  @override
  String buildWhatsAppSummaryText({
    required PuskesmasDraftArgs args,
    required SchoolProfile school,
  }) {
    final stageLine = args.stage == ClusterAlertStage.postConsumption
        ? 'Tahap 2 Pasca-Konsumsi (${args.symptomCount} siswa bergejala)'
        : 'Tahap 1 Pra-Konsumsi (Temuan Sebelum Makan)';
    final sampleLine = (args.sampleLabelCode != null &&
            args.sampleLabelCode!.trim().isNotEmpty)
        ? args.sampleLabelCode!.trim()
        : 'Belum tersimpan (batch dihentikan sebelum Bank Sampel)';

    final buffer = StringBuffer()
      ..writeln('*BERITA ACARA & LAPORAN DINI KLB LACAKSAJI*')
      ..writeln()
      ..writeln('*Identitas Pelapor & Batch*')
      ..writeln('- Sekolah: ${school.name} (NPSN ${school.npsn})')
      ..writeln('- Dapur SPPG: ${args.sppgName}')
      ..writeln('- Menu: ${args.menuName}')
      ..writeln('- Kode Batch: *${args.batchCode}*')
      ..writeln('- Tahap Laporan: *$stageLine*')
      ..writeln()
      ..writeln('*Kronologi Waktu & Suhu*')
      ..writeln('- Jam Segel Dapur: ${formatWibDateTime(args.sealedAtUtc)}')
      ..writeln('- Jam Terima Sekolah: ${formatWibDateTime(args.scannedAtUtc)}')
      ..writeln(
        '- Durasi Distribusi: ${formatDurationMinutes(args.elapsedMinutes)}',
      )
      ..writeln(
        '- Suhu Wilayah: ${args.bmkgTempC.toStringAsFixed(1)} C (${args.bmkgSource.label}, ${AppConstants.bmkgShortAttribution})',
      );

    final handover = args.transitHandover;
    if (handover != null) {
      final transitMin = handover.transitDurationMinutes;
      buffer.writeln(
        '- Jam Muat Kurir (${handover.courierName}): ${formatWibDateTime(handover.effectiveDepartedAtUtc)}',
      );
      if (handover.arrivedAtUtc != null) {
        buffer.writeln(
          '- Jam Tiba Kurir: ${formatWibDateTime(handover.arrivedAtUtc!)} (Durasi Jalan: ${transitMin != null ? formatDurationMinutes(transitMin) : '-'})',
        );
      }
    }

    if (args.ingredientLogs.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('*Riwayat Hulu Bahan Baku*');
      for (final log in args.ingredientLogs.take(4)) {
        buffer.writeln(
          '- ${log.ingredientName} | ${log.supplierName} | Lot ${log.supplierBatchNo} | Exp ${log.formattedExpiryDate}',
        );
      }
    }

    buffer
      ..writeln()
      ..writeln('*Bank Sampel & Temuan*')
      ..writeln('- Kode Bank Sampel 2x24 Jam: *$sampleLine*')
      ..writeln('- Ringkasan Temuan: ${args.reasonSummary}');

    if (args.notes != null && args.notes!.trim().isNotEmpty) {
      buffer.writeln('- Catatan Lapangan: ${args.notes!.trim()}');
    }
    buffer
      ..writeln()
      ..write(
        '_Dikirim otomatis dari aplikasi LacakSaji untuk tindak lanjut Puskesmas._',
      );

    return sanitizeZeroSlopCopy(buffer.toString());
  }

  @override
  Future<Uint8List> buildKlbReportPdfBytes({
    required PuskesmasDraftArgs args,
    required SchoolProfile school,
    Uint8List? photoBytesOverride,
    bool compress = true,
  }) async {
    final doc = pw.Document(
      title: sanitizeZeroSlopCopy('Berita Acara KLB ${args.batchCode}'),
      author: 'LacakSaji',
      compress: compress,
    );

    final embeddedPhotoJpg = await _loadAndTranscodeJpeg(
      localPhotoPath: args.localPhotoPath,
      photoBytesOverride: photoBytesOverride,
    );

    final sampleCode = (args.sampleLabelCode != null &&
            args.sampleLabelCode!.trim().isNotEmpty)
        ? sanitizeZeroSlopCopy(args.sampleLabelCode!)
        : 'TIDAK ADA (DITAHAN SEBELUM SIMPAN SAMPEL)';

    final stageSummary = args.stage == ClusterAlertStage.postConsumption
        ? 'Tahap 2: Pasca-Konsumsi (${args.symptomCount} siswa bergejala)'
        : 'Tahap 1: Pra-Konsumsi (Makanan ditahan sebelum makan)';

    final handover = args.transitHandover;
    final kitchenHoldMinutes = handover?.effectiveDepartedAtUtc
        .toUtc()
        .difference(args.sealedAtUtc.toUtc())
        .inMinutes
        .clamp(0, 1440);
    final courierTransitMinutes = handover == null
        ? null
        : (handover.transitDurationMinutes ??
              args.scannedAtUtc
                  .toUtc()
                  .difference(handover.effectiveDepartedAtUtc.toUtc())
                  .inMinutes
                  .clamp(0, 1440));
    final hasIngredients = args.ingredientLogs.isNotEmpty;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFFBECEC),
                  border: pw.Border.all(
                    color: PdfColor.fromInt(0xFFDFB0B0),
                    width: 1,
                  ),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'LACAKSAJI : KEAMANAN PANGAN MAKAN BERGIZI GRATIS',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF8E2424),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'BERITA ACARA & LAPORAN DINI KLB',
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF181E1B),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      sanitizeZeroSlopCopy(
                        'Tanggal Laporan: ${formatWibDateTime(args.reportedAtUtc)}',
                      ),
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(9),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 1),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle('1. IDENTITAS PELAPOR & BATCH'),
                    _kvRow('Sekolah Pelapor', '${school.name} (NPSN ${school.npsn})'),
                    _kvRow('WA Puskesmas Tujuan', school.formattedPuskesmasWa),
                    _kvRow('Dapur Penyedia (SPPG)', args.sppgName),
                    _kvRow('Menu Makanan', args.menuName),
                    _kvRow('Kode Batch Segel', args.batchCode),
                    _kvRow('Tahap Pelaporan', stageSummary),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(9),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 1),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle('2. KRONOLOGI WAKTU-SUHU & TRANSIT KURIR'),
                    _kvRow('Jam Segel Dapur SPPG', formatWibDateTime(args.sealedAtUtc)),
                    if (handover != null) ...[
                      _kvRow(
                        'Jam Muat Kurir (${handover.courierName})',
                        formatWibDateTime(handover.effectiveDepartedAtUtc),
                      ),
                      if (handover.arrivedAtUtc != null)
                        _kvRow(
                          'Jam Tiba Gerbang Sekolah',
                          formatWibDateTime(handover.arrivedAtUtc!),
                        ),
                      if (kitchenHoldMinutes != null)
                        _kvRow(
                          'Jeda Tunggu di Dapur',
                          formatDurationMinutes(kitchenHoldMinutes),
                        ),
                      if (courierTransitMinutes != null)
                        _kvRow(
                          'Durasi Transit Jalan Kurir',
                          formatDurationMinutes(courierTransitMinutes),
                        ),
                    ] else
                      _kvRow(
                        'Log Transit Kurir',
                        'Belum ada pindai kurir (langsung dipindai sekolah)',
                      ),
                    _kvRow('Jam Scan & Terima Sekolah', formatWibDateTime(args.scannedAtUtc)),
                    _kvRow('Total Durasi Sejak Segel', formatDurationMinutes(args.elapsedMinutes)),
                    _kvRow(
                      'Suhu Lokal Wilayah',
                      '${args.bmkgTempC.toStringAsFixed(1)} C (${args.bmkgSource.label})',
                    ),
                    _kvRow('Sumber Cuaca Resmi', AppConstants.bmkgShortAttribution),
                    _kvRow('Keputusan Danger-Zone', args.dangerStatus.bannerTitle),
                    _kvRow('Ringkasan Temuan', args.reasonSummary),
                    if (args.notes != null && args.notes!.trim().isNotEmpty)
                      _kvRow('Catatan Guru / PIC', args.notes!.trim()),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(9),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 1),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle('3. RIWAYAT HULU BAHAN BAKU & PEMASOK'),
                    if (!hasIngredients)
                      pw.Text(
                        'Tidak ada log bahan baku tertaut pada batch ini saat laporan dibuat.',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      )
                    else
                      for (final log in args.ingredientLogs.take(4))
                        _kvRow(
                          log.ingredientName,
                          '${log.supplierName} | Lot ${log.supplierBatchNo} | Exp ${log.formattedExpiryDate}',
                        ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(9),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFEBF4EF),
                  border: pw.Border.all(
                    color: PdfColor.fromInt(0xFFBCD8CA),
                    width: 1,
                  ),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('4. KODE LABEL BANK SAMPEL 2x24 JAM (UJI LAB)'),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      sampleCode,
                      style: pw.TextStyle(
                        fontSize: 13.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF19533B),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Simpan sampel arsip pada suhu < 5 C untuk diserahkan kepada petugas Puskesmas / laboratorium sesuai Perbagi No. 4 Tahun 2026.',
                      style: const pw.TextStyle(
                        fontSize: 8.5,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(9),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 1),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('5. BUKTI FOTO SAMPEL LAPANGAN'),
                    pw.SizedBox(height: 4),
                    if (embeddedPhotoJpg != null)
                      pw.Center(
                        child: pw.Image(
                          pw.MemoryImage(embeddedPhotoJpg),
                          height: hasIngredients ? 88 : 112,
                          fit: pw.BoxFit.contain,
                        ),
                      )
                    else
                      pw.Text(
                        'Tidak ada foto sampel terlampir pada laporan ini (dihentikan langsung pada tahap waktu-suhu atau belum difoto).',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey400, thickness: 1),
              pw.SizedBox(height: 4),
              pw.Text(
                sanitizeZeroSlopCopy(
                  'Dokumen ini dibuat otomatis oleh aplikasi LacakSaji tanpa menyimpan identitas pribadi siswa. ID Laporan: ${args.alertId}',
                ),
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
        sanitizeZeroSlopCopy(title),
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromInt(0xFF181E1B),
        ),
      ),
    );
  }

  pw.Widget _kvRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              sanitizeZeroSlopCopy(label),
              style: const pw.TextStyle(
                fontSize: 9.5,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              sanitizeZeroSlopCopy(value),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List?> _loadAndTranscodeJpeg({
    required String? localPhotoPath,
    required Uint8List? photoBytesOverride,
  }) async {
    try {
      Uint8List? rawBytes = photoBytesOverride;
      if (rawBytes == null &&
          localPhotoPath != null &&
          localPhotoPath.trim().isNotEmpty) {
        final file = File(localPhotoPath);
        if (file.existsSync()) {
          rawBytes = await file.readAsBytes();
        }
      }
      if (rawBytes == null || rawBytes.isEmpty) {
        return null;
      }

      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) {
        return null;
      }
      final resized = decoded.width > 420
          ? img.copyResize(decoded, width: 420)
          : decoded;
      return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
    } catch (_) {
      return null;
    }
  }

  Future<({File archiveFile, File shareFile})> _writePdfFiles({
    required PuskesmasDraftArgs args,
    required Uint8List pdfBytes,
  }) async {
    final safeBatch = args.batchCode.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final fileName = 'berita_acara_klb_$safeBatch.pdf';

    final docsDir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory(p.join(docsDir.path, 'lacak_klb_reports'));
    if (!reportsDir.existsSync()) {
      await reportsDir.create(recursive: true);
    }
    final archiveFile = File(p.join(reportsDir.path, fileName));
    await archiveFile.writeAsBytes(pdfBytes, flush: true);

    final tempDir = await getTemporaryDirectory();
    final tempReportsDir = Directory(p.join(tempDir.path, 'lacak_klb_reports'));
    if (!tempReportsDir.existsSync()) {
      await tempReportsDir.create(recursive: true);
    }
    final shareFile = File(p.join(tempReportsDir.path, fileName));
    await shareFile.writeAsBytes(pdfBytes, flush: true);

    return (archiveFile: archiveFile, shareFile: shareFile);
  }

  @override
  Future<String> generateAndSharePdfToWhatsApp({
    required PuskesmasDraftArgs args,
    required SchoolProfile school,
    Uint8List? photoBytesOverride,
  }) async {
    final pdfBytes = await buildKlbReportPdfBytes(
      args: args,
      school: school,
      photoBytesOverride: photoBytesOverride,
    );
    final summaryText = buildWhatsAppSummaryText(args: args, school: school);
    final written = await _writePdfFiles(args: args, pdfBytes: pdfBytes);

    if (Platform.isAndroid) {
      final phoneDigits = _normalizeWaDigits(school.puskesmasWa);
      try {
        final status = await _whatsAppChannel.invokeMethod<String>(
          'sendPdfToWhatsApp',
          <String, dynamic>{
            'filePath': written.shareFile.path,
            'phoneDigits': phoneDigits,
            'caption': summaryText,
          },
        );
        if (status == 'sent_whatsapp') {
          return written.archiveFile.path;
        }
      } on MissingPluginException {
        // Fallback to SharePlus below on environments without Android channel.
      } on PlatformException {
        // Fallback to SharePlus below if native WhatsApp launch fails.
      }
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(written.shareFile.path, mimeType: 'application/pdf')],
        subject: sanitizeZeroSlopCopy('Berita Acara KLB ${args.batchCode}'),
        text: summaryText,
      ),
    );
    return written.archiveFile.path;
  }

  @override
  Future<String> sharePdfToOtherApps({
    required PuskesmasDraftArgs args,
    required SchoolProfile school,
    Uint8List? photoBytesOverride,
  }) async {
    final pdfBytes = await buildKlbReportPdfBytes(
      args: args,
      school: school,
      photoBytesOverride: photoBytesOverride,
    );
    final summaryText = buildWhatsAppSummaryText(args: args, school: school);
    final written = await _writePdfFiles(args: args, pdfBytes: pdfBytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(written.shareFile.path, mimeType: 'application/pdf')],
        subject: sanitizeZeroSlopCopy('Berita Acara KLB ${args.batchCode}'),
        text: summaryText,
      ),
    );
    return written.archiveFile.path;
  }

  @override
  Future<bool> openDirectWhatsAppChat({
    required String puskesmasWa,
    required String summaryText,
  }) async {
    final normalized = _normalizeWaDigits(puskesmasWa);
    if (normalized.isEmpty) {
      return false;
    }
    final cleanText = sanitizeZeroSlopCopy(summaryText);
    final uri = Uri.https(
      'wa.me',
      '/$normalized',
      {'text': cleanText},
    );
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static String _normalizeWaDigits(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return '';
    }
    if (digits.startsWith('0')) {
      return '62${digits.substring(1)}';
    }
    return digits;
  }
}

final klbReportPdfServiceProvider = Provider<KlbReportPdfService>((ref) {
  return DeviceKlbReportPdfService();
});
