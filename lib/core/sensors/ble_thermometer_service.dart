import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BleSensorStatus {
  ready('Siap Dihubungkan'),
  bluetoothOff('Bluetooth Mati'),
  unsupported('Perangkat Tidak Mendukung BLE'),
  scanning('Mencari Sensor Kontainer...'),
  connected('Terhubung ke Termometer BLE'),
  error('Sensor Tidak Merespons');

  const BleSensorStatus(this.label);

  final String label;
}

class BleThermometerAvailability {
  const BleThermometerAvailability({
    required this.status,
    required this.detail,
    required this.canScan,
  });

  final BleSensorStatus status;
  final String detail;
  final bool canScan;
}

class BleTemperatureReading {
  const BleTemperatureReading({
    required this.temperatureC,
    required this.deviceName,
    required this.deviceId,
    required this.measuredAtUtc,
    this.isSimulated = false,
  });

  final double temperatureC;
  final String deviceName;
  final String deviceId;
  final DateTime measuredAtUtc;
  final bool isSimulated;
}

/// Hardware-agnostic abstraction for future Bluetooth Low Energy food probe integration.
/// Never crashes or blocks inspection when device Bluetooth is disabled or absent.
abstract class BleThermometerService {
  Future<BleThermometerAvailability> checkAvailability();

  Future<BleTemperatureReading?> readContainerTemperature();
}

/// Safe default BLE readiness implementation while waiting for physical BLE probe pairing.
class ReadyStateBleThermometerService implements BleThermometerService {
  @override
  Future<BleThermometerAvailability> checkAvailability() async {
    return const BleThermometerAvailability(
      status: BleSensorStatus.ready,
      detail:
          'Mode Siap BLE aktif. Hubungkan sensor kontainer jika tersedia, atau gunakan Termometer Manual tanpa mengganggu inspeksi.',
      canScan: true,
    );
  }

  @override
  Future<BleTemperatureReading?> readContainerTemperature() async {
    return null;
  }
}

final bleThermometerServiceProvider = Provider<BleThermometerService>((ref) {
  return ReadyStateBleThermometerService();
});
