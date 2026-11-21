import 'package:geolocator/geolocator.dart';

class LocationCaptureResult {
  const LocationCaptureResult({
    required this.success,
    required this.message,
    this.lat,
    this.lng,
  });

  final bool success;
  final String message;
  final double? lat;
  final double? lng;
}

/// Captures current device GPS coordinates with plain-language permission feedback.
Future<LocationCaptureResult> captureDeviceCoordinates() async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationCaptureResult(
        success: false,
        message: 'Layanan lokasi (GPS) HP belum aktif. Nyalakan GPS lalu coba lagi.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const LocationCaptureResult(
        success: false,
        message:
            'Izin lokasi belum diberikan. Aktifkan izin lokasi untuk mengunci titik koordinat.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );

    return LocationCaptureResult(
      success: true,
      message: 'Lokasi GPS berhasil dikunci.',
      lat: position.latitude,
      lng: position.longitude,
    );
  } catch (_) {
    return const LocationCaptureResult(
      success: false,
      message:
          'Koordinat GPS belum berhasil diambil. Anda tetap dapat memakai titik koordinat wilayah kelurahan.',
    );
  }
}

/// Normalizes Indonesian phone numbers into `628...` WhatsApp format.
String normalizeIndonesianWaNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('0')) {
    return '62${digits.substring(1)}';
  }
  if (digits.startsWith('8')) {
    return '62$digits';
  }
  return digits;
}
