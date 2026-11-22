import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../alerts/domain/cluster_alert_models.dart';
import '../domain/kitchen_models.dart';

typedef WaybillPngCapturer = Future<Uint8List> Function(GlobalKey boundaryKey);

Future<Uint8List> captureRepaintBoundaryPng(GlobalKey boundaryKey) async {
  await Future<void>.delayed(Duration.zero);
  final renderObject = boundaryKey.currentContext?.findRenderObject();
  if (renderObject is! RenderRepaintBoundary) {
    throw StateError('Kartu Surat Jalan Digital belum siap ditangkap.');
  }
  final image = await renderObject.toImage(pixelRatio: 3.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    throw StateError('Gagal membuat gambar PNG Surat Jalan Digital.');
  }
  return byteData.buffer.asUint8List();
}

final waybillPngCapturerProvider = Provider<WaybillPngCapturer>((ref) {
  return captureRepaintBoundaryPng;
});

abstract class BatchExportService {
  Future<String> shareDigitalWaybillPng({
    required FoodBatchItem batch,
    required Uint8List pngBytes,
  });

  Future<Uint8List> buildPrintableLabelPdfBytes(FoodBatchItem batch);

  Future<String> exportAndSharePrintableLabelPdf(FoodBatchItem batch);
}

class DeviceBatchExportService implements BatchExportService {
  /// Builds a structured, bolded, scannable WhatsApp caption for courier QR handoff.
  static String buildCourierWhatsAppText(FoodBatchItem batch) {
    final buffer = StringBuffer()
      ..writeln('*SURAT JALAN DIGITAL LACAKSAJI*')
      ..writeln()
      ..writeln('*Detail Pengiriman Batch*')
      ..writeln('- Dapur SPPG: ${batch.sppgName}')
      ..writeln('- Kode Batch: *${batch.batchCode}*')
      ..writeln('- Menu: ${batch.menuName}')
      ..writeln('- Risiko Pangan: ${batch.riskCategory.label}')
      ..writeln('- Jumlah Porsi: *${batch.portionCount} porsi*')
      ..writeln('- Jam Segel Dapur: ${formatWibDateTime(batch.sealedAtUtc)}')
      ..writeln()
      ..writeln('*Instruksi Kurir*')
      ..writeln(
        'Tunjukkan gambar QR pada pesan ini kepada Guru atau PIC Sekolah saat makanan tiba.',
      )
      ..writeln()
      ..write(
        '_Dikirim otomatis dari aplikasi LacakSaji untuk distribusi MBG._',
      );
    return sanitizeZeroSlopCopy(buffer.toString());
  }

  @override
  Future<String> shareDigitalWaybillPng({
    required FoodBatchItem batch,
    required Uint8List pngBytes,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final safeCode = batch.batchCode.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final filePath = p.join(tempDir.path, 'surat_jalan_$safeCode.png');
    final file = File(filePath);
    await file.writeAsBytes(pngBytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        subject: sanitizeZeroSlopCopy('Surat Jalan Digital ${batch.batchCode}'),
        text: buildCourierWhatsAppText(batch),
      ),
    );
    return file.path;
  }

  @override
  Future<Uint8List> buildPrintableLabelPdfBytes(FoodBatchItem batch) async {
    final doc = pw.Document(
      title: 'Label Segel Batch ${batch.batchCode}',
      author: 'LacakSaji',
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey700, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'LACAKSAJI : LABEL SEGEL DIGITAL',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  batch.sppgName,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Kode Batch: ${batch.batchCode}',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(14),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: PdfColors.grey400, width: 1),
                    ),
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: batch.qrPayloadJson,
                      width: 170,
                      height: 170,
                      drawText: false,
                      color: PdfColors.black,
                    ),
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Divider(color: PdfColors.grey400, thickness: 1),
                _pdfRow('Menu Makanan', batch.menuName),
                _pdfRow('Kategori Risiko', batch.riskCategory.label),
                _pdfRow('Jumlah Porsi', '${batch.portionCount} porsi'),
                _pdfRow('Jam Segel', formatWibDateTime(batch.sealedAtUtc)),
                _pdfRow('Status Waktu', batch.timestampSource.label),
                _pdfRow('Keamanan Segel', 'Segel Digital Asli'),
                pw.Spacer(),
                pw.Divider(color: PdfColors.grey400, thickness: 1),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Tempelkan label ini pada wadah utama atau tunjukkan QR ke Guru / PIC Sekolah saat serah terima untuk pemeriksaan waktu dan suhu.',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Future<String> exportAndSharePrintableLabelPdf(FoodBatchItem batch) async {
    final pdfBytes = await buildPrintableLabelPdfBytes(batch);
    final docsDir = await getApplicationDocumentsDirectory();
    final labelsDir = Directory(p.join(docsDir.path, 'lacak_labels'));
    if (!labelsDir.existsSync()) {
      await labelsDir.create(recursive: true);
    }
    final safeCode = batch.batchCode.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final filePath = p.join(labelsDir.path, 'label_$safeCode.pdf');
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Label Cetak Batch ${batch.batchCode}',
        text: 'Label Siap Cetak QR Segel Batch ${batch.batchCode} (${batch.menuName})',
      ),
    );
    return file.path;
  }
}

final batchExportServiceProvider = Provider<BatchExportService>((ref) {
  return DeviceBatchExportService();
});
