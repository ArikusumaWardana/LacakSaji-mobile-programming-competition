import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';

/// Maximum compressed packaging/sample photo byte budget (120 KB to preserve mold & discoloration detail for AI Vision).
const int kMaxWebpPhotoBytes = 120 * 1024;

class CapturedWebpPhoto {
  const CapturedWebpPhoto({
    required this.filePath,
    required this.bytes,
    required this.sizeBytes,
  });

  final String filePath;
  final Uint8List bytes;
  final int sizeBytes;

  String get formattedSizeKb {
    final kb = (sizeBytes / 1024).clamp(1, 999);
    return '${kb.toStringAsFixed(1)} KB';
  }
}

/// Captures photos strictly from live camera (gallery disabled) and compresses to WebP (< 60 KB).
abstract class LiveCameraWebpService {
  Future<CapturedWebpPhoto?> captureAndCompress();
}

class DeviceLiveCameraWebpService implements LiveCameraWebpService {
  DeviceLiveCameraWebpService({ImagePicker? picker, Uuid? uuid})
      : _picker = picker ?? ImagePicker(),
        _uuid = uuid ?? const Uuid();

  final ImagePicker _picker;
  final Uuid _uuid;

  static const List<({int maxWidth, int quality})> _compressionLadder = [
    (maxWidth: AppConstants.auditPhotoMaxWidthPx, quality: AppConstants.auditPhotoWebpQuality),
    (maxWidth: AppConstants.auditPhotoMaxWidthPx, quality: 55),
    (maxWidth: 800, quality: 50),
    (maxWidth: 640, quality: 45),
    (maxWidth: 512, quality: 40),
    (maxWidth: 480, quality: 30),
    (maxWidth: 384, quality: 25),
  ];

  @override
  Future<CapturedWebpPhoto?> captureAndCompress() async {
    // Anti-backdating rule: gallery selection is strictly disallowed.
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      requestFullMetadata: false,
    );
    if (picked == null) {
      return null;
    }

    Uint8List? selectedBytes;
    for (final step in _compressionLadder) {
      final candidate = await FlutterImageCompress.compressWithFile(
        picked.path,
        minWidth: step.maxWidth,
        minHeight: step.maxWidth,
        quality: step.quality,
        format: CompressFormat.webp,
        keepExif: false,
      );
      if (candidate == null || candidate.isEmpty) {
        continue;
      }
      selectedBytes = candidate;
      if (candidate.length <= kMaxWebpPhotoBytes) {
        break;
      }
    }

    if (selectedBytes == null || selectedBytes.length > kMaxWebpPhotoBytes) {
      throw StateError(
        'Ukuran foto belum berhasil dikompres. Coba potret ulang dengan pencahayaan cukup.',
      );
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final photoDir = Directory(p.join(docsDir.path, 'lacak_batch_photos'));
    if (!photoDir.existsSync()) {
      await photoDir.create(recursive: true);
    }

    final targetPath = p.join(photoDir.path, '${_uuid.v4()}.webp');
    await File(targetPath).writeAsBytes(selectedBytes, flush: true);

    return CapturedWebpPhoto(
      filePath: targetPath,
      bytes: selectedBytes,
      sizeBytes: selectedBytes.length,
    );
  }
}

final liveCameraWebpServiceProvider = Provider<LiveCameraWebpService>((ref) {
  return DeviceLiveCameraWebpService();
});
