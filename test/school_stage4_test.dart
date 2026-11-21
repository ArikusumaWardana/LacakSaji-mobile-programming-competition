import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lacak_saji/core/constants/app_constants.dart';
import 'package:lacak_saji/core/crypto/batch_qr_payload.dart';
import 'package:lacak_saji/core/crypto/ed25519_service.dart';
import 'package:lacak_saji/core/database/app_database.dart';
import 'package:lacak_saji/core/database/database_provider.dart';
import 'package:lacak_saji/core/media/live_camera_webp_service.dart';
import 'package:lacak_saji/core/network/bmkg_weather_service.dart';
import 'package:lacak_saji/core/network/connectivity_provider.dart';
import 'package:lacak_saji/core/network/supabase_provider.dart';
import 'package:lacak_saji/core/notifications/local_notification_service.dart';
import 'package:lacak_saji/core/theme/text_scale_provider.dart';
import 'package:lacak_saji/features/alerts/domain/cluster_alert_models.dart';
import 'package:lacak_saji/features/auth/data/auth_repository.dart';
import 'package:lacak_saji/features/auth/domain/auth_models.dart';
import 'package:lacak_saji/features/auth/presentation/auth_controller.dart';
import 'package:lacak_saji/features/kitchen/domain/kitchen_models.dart';
import 'package:lacak_saji/features/school/data/hybrid_vision_service.dart';
import 'package:lacak_saji/features/school/data/school_repository.dart';
import 'package:lacak_saji/features/school/domain/danger_zone_calculator.dart';
import 'package:lacak_saji/features/school/domain/school_models.dart';
import 'package:lacak_saji/features/school/presentation/scan_qr_screen.dart';
import 'package:lacak_saji/features/school/presentation/school_providers.dart';
import 'package:lacak_saji/main.dart';

final Uint8List _validTinyWebpBytes = base64Decode(
  'UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA==',
);

class _InMemorySecureKeyStore implements SecureKeyStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _StubDioAdapter implements HttpClientAdapter {
  _StubDioAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }
}

class _SpyNotificationService implements LocalNotificationService {
  final List<({String sampleId, String labelCode, DateTime expiresAtUtc})>
  scheduled = [];
  final List<String> cancelledIds = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleSampleVaultReminder({
    required String sampleId,
    required String labelCode,
    required String menuName,
    required DateTime expiresAtUtc,
  }) async {
    scheduled.add((
      sampleId: sampleId,
      labelCode: labelCode,
      expiresAtUtc: expiresAtUtc,
    ));
  }

  @override
  Future<void> cancelSampleVaultReminder(String sampleId) async {
    cancelledIds.add(sampleId);
  }

  @override
  Future<void> showClusterAlertNotification(ClusterAlertEvent event) async {}
}

class _StaticBmkgWeatherService implements BmkgWeatherService {
  _StaticBmkgWeatherService(this.reading);

  final BmkgWeatherReading reading;

  @override
  Future<BmkgWeatherReading> getCurrentWeather({
    required String adm4Code,
    required bool isOffline,
    bool forceRefresh = false,
  }) async => reading;
}

class _Stage4AuthRepository implements AuthRepository {
  _Stage4AuthRepository(this.session);

  final AuthSessionSnapshot session;

  @override
  Future<AuthSessionSnapshot?> restoreSession() async => session;

  @override
  Future<AuthSessionSnapshot?> refreshSession() async => session;

  @override
  Future<AuthSessionSnapshot> signInWithPassword({
    required String email,
    required String password,
  }) async => session;

  @override
  Future<void> signOut() async {}

  @override
  Future<WhitelistCheckResult> verifySppgWhitelist({
    required String regNumber,
    required String pin,
  }) async => const WhitelistCheckResult(ok: true);

  @override
  Future<KitchenRegistrationResult> registerKitchen({
    required String regNumber,
    required String pin,
    required String picName,
    required String kitchenName,
    required String adm4Code,
    required double lat,
    required double lng,
    required String email,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<SchoolPrecheckResult> precheckSchool({
    required String npsn,
    required String inviteCode,
  }) async => throw UnimplementedError();

  @override
  Future<SchoolRegistrationResult> registerSchool({
    required String npsn,
    required String schoolName,
    required String picName,
    required String adm4Code,
    required String puskesmasWa,
    required String inviteCode,
    required double lat,
    required double lng,
    required String email,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<AuthSessionSnapshot> updateKitchenLocation({
    required double lat,
    required double lng,
    required String adm4Code,
  }) async => session;

  @override
  Future<AuthSessionSnapshot> updateSchoolOperationalSettings({
    required String puskesmasWa,
    required String adm4Code,
  }) async => session;

  @override
  Future<AuthSessionSnapshot> updateSchoolPartnerCode(
    String inviteCode,
  ) async => session;
}

class _FakeLiveCameraService implements LiveCameraWebpService {
  int count = 0;

  @override
  Future<CapturedWebpPhoto?> captureAndCompress() async {
    count++;
    final dir = Directory.systemTemp.createTempSync('lacak_school_cam_');
    final file = File('${dir.path}/sample_$count.webp');
    file.writeAsBytesSync(_validTinyWebpBytes);
    return CapturedWebpPhoto(
      filePath: file.path,
      bytes: _validTinyWebpBytes,
      sizeBytes: _validTinyWebpBytes.length,
    );
  }
}

class _OfflineFallbackHybridVisionService implements HybridVisionService {
  @override
  Future<OnDeviceVisualResult> analyzeOnDevice(Uint8List photoBytes) async {
    return const OnDeviceVisualResult(
      label: OnDeviceVisualLabel.freshLikely,
      confidence: 0.84,
      summaryText:
          'Tampilan visual makanan tampak wajar. Tetap lengkapi 3 cek manual di bawah.',
      usedTfliteModel: false,
    );
  }

  @override
  Future<CloudVisionResult> analyzeCloudOrganoleptic({
    required Uint8List photoBytes,
    required String menuName,
    required bool isOffline,
    OnDeviceVisualResult? localScreening,
  }) async {
    return const CloudVisionResult(
      ok: false,
      provider: 'offline_mode',
      fallbackRequired: true,
      summaryText:
          'Mode Tanpa Sinyal. Foto disimpan dan lanjutkan dengan cek manual di bawah.',
    );
  }

  @override
  Future<OnDeviceVisualResult> estimatePlateWasteOnDevice(
    List<Uint8List> photoBytesList,
  ) async {
    return const OnDeviceVisualResult(
      label: OnDeviceVisualLabel.freshLikely,
      confidence: 0.72,
      summaryText: 'Estimasi cepat di HP selesai (mode offline).',
      usedTfliteModel: false,
      estimatedCarbWastePct: 25,
      estimatedProteinWastePct: 0,
      estimatedVegWastePct: 50,
    );
  }

  @override
  Future<CloudVisionResult> analyzeCloudPlateWaste({
    required List<Uint8List> photoBytesList,
    required String menuName,
    required bool isOffline,
  }) async {
    return const CloudVisionResult(
      ok: false,
      provider: 'offline_mode',
      fallbackRequired: true,
      summaryText: 'Gunakan hasil cek cepat perangkat atau pilih manual.',
    );
  }
}

const SchoolProfile _demoSchool = SchoolProfile(
  id: 'b1000000-0000-4000-8000-000000000001',
  ownerUserId: '20000000-0000-4000-8000-000000000001',
  sppgId: 'a1000000-0000-4000-8000-000000000001',
  npsn: '20301901',
  name: 'SDN 1 Purwokerto',
  adm4Code: '33.02.26.1001',
  lat: -7.4188,
  lng: 109.2351,
  puskesmasWa: '628112800001',
  verificationStatus: SchoolVerificationStatus.approved,
  partnerKitchenName: 'SPPG Purwokerto Utara',
  partnerInviteCode: 'SPPG-PWT-01',
);

const AuthSessionSnapshot _schoolSession = AuthSessionSnapshot(
  profile: UserProfile(
    id: '20000000-0000-4000-8000-000000000001',
    email: 'sdn1.pwt@lacaksaji.id',
    role: UserRole.school,
    fullName: 'Ibu Siti (PIC SDN 1 Purwokerto)',
  ),
  school: _demoSchool,
);

Future<({String validQrJson, String publicKeyB64, String fakeQrJson})>
_prepareSignedQrFixtures(DateTime sealedAtUtc) async {
  final store = _InMemorySecureKeyStore();
  final ed25519 = Ed25519Service(secureStore: store);
  const sppgId = 'a1000000-0000-4000-8000-000000000001';
  final publicKey = await ed25519.getOrCreatePublicKeyB64(sppgId: sppgId);
  final epochSec = sealedAtUtc.toUtc().millisecondsSinceEpoch ~/ 1000;

  final canonical = BatchQrPayload.buildCanonicalSigningString(
    batchId: 'batch-stage4-001',
    batchCode: 'BCH-2611-21S4',
    sppgId: sppgId,
    menuName: 'Nasi Ayam Suwir & Tumis Kacang',
    riskCategory: 'HIGH',
    sealedAtEpochSec: epochSec,
    timestampSource: 'server_verified',
  );
  final sig = await ed25519.signCanonicalPayload(
    sppgId: sppgId,
    canonicalData: canonical,
  );

  final validPayload = BatchQrPayload(
    batchId: 'batch-stage4-001',
    batchCode: 'BCH-2611-21S4',
    sppgId: sppgId,
    menuName: 'Nasi Ayam Suwir & Tumis Kacang',
    riskCategory: 'HIGH',
    sealedAtEpochSec: epochSec,
    timestampSource: 'server_verified',
    signatureB64: sig,
  );

  final forgedPayload = BatchQrPayload(
    batchId: 'batch-stage4-001',
    batchCode: 'BCH-2611-21S4',
    sppgId: sppgId,
    menuName: 'Menu Dipalsukan',
    riskCategory: 'LOW',
    sealedAtEpochSec: epochSec,
    timestampSource: 'server_verified',
    signatureB64: sig,
  );

  return (
    validQrJson: validPayload.toMinifiedJson(),
    publicKeyB64: publicKey,
    fakeQrJson: forgedPayload.toMinifiedJson(),
  );
}

class _InMemoryStage4SchoolRepository implements SchoolRepository {
  _InMemoryStage4SchoolRepository({
    required this.publicKeyB64,
    required this.weather,
    required this.notificationService,
  });

  final String publicKeyB64;
  final BmkgWeatherReading weather;
  final _SpyNotificationService notificationService;
  final Ed25519Service _ed25519 = Ed25519Service(
    secureStore: _InMemorySecureKeyStore(),
  );

  final List<SchoolInspectionItem> _inspections = [];
  final List<SampleVaultItem> _vaults = [];
  final List<SchoolBatchOption> extraWasteBatches = [];
  final StreamController<void> _vaultChangeCtrl =
      StreamController<void>.broadcast();

  void dispose() {
    _vaultChangeCtrl.close();
  }

  List<SampleVaultItem> _activeList() => _vaults
      .where((v) => v.status == 'active')
      .toList(growable: false);

  List<SampleVaultItem> _historyList() => _vaults
      .where((v) => v.status != 'active')
      .toList(growable: false);

  @override
  String generateSampleLabelCode(DateTime nowUtc) => 'SMP-2611-21T1';

  @override
  Future<SchoolDashboardData> fetchDashboardData({
    required SchoolProfile school,
    required bool isOffline,
  }) async {
    final active = _activeList();
    return SchoolDashboardData(
      school: school,
      weather: weather,
      todayInspections: List.unmodifiable(_inspections),
      activeSampleCount: active.length,
      nearestSampleExpiryUtc: active.isNotEmpty
          ? active.first.expiresAtUtc
          : null,
      partnerKeyCached: true,
    );
  }

  @override
  Future<QrVerificationResult> verifyQrPayloadOffline({
    required String rawQrText,
    required SchoolProfile school,
    required bool isOffline,
  }) async {
    final payload = BatchQrPayload.tryParse(rawQrText.trim());
    if (payload == null) {
      return const QrVerificationResult(
        outcome: QrVerificationOutcome.invalidFormat,
        errorTitle: 'Kode QR Tidak Dikenali',
        errorMessage: 'Kode QR tidak valid.',
      );
    }
    final validSig = await _ed25519.verifyCanonicalPayload(
      canonicalData: payload.toCanonicalSigningString(),
      signatureB64: payload.signatureB64,
      publicKeyB64: publicKeyB64,
    );
    if (!validSig) {
      return const QrVerificationResult(
        outcome: QrVerificationOutcome.invalidSignature,
        errorTitle: 'Segel Digital Tidak Valid',
        errorMessage: 'Tanda tangan kriptografi QR tidak cocok.',
      );
    }
    final scanAtUtc = DateTime.now().toUtc();
    final sealedAtUtc = DateTime.fromMillisecondsSinceEpoch(
      payload.sealedAtEpochSec * 1000,
      isUtc: true,
    );
    final risk = FoodRiskCategory.fromDb(payload.riskCategory);
    final danger = DangerZoneCalculator.evaluate(
      riskCategory: risk,
      sealedAtUtc: sealedAtUtc,
      scanAtUtc: scanAtUtc,
      temperatureC: weather.temperatureC,
    );
    return QrVerificationResult(
      outcome: QrVerificationOutcome.valid,
      context: VerifiedBatchScanContext(
        payload: payload,
        riskCategory: risk,
        timestampSource: BatchTimestampSource.fromDb(payload.timestampSource),
        sealedAtUtc: sealedAtUtc,
        scannedAtUtc: scanAtUtc,
        sppgName: school.partnerKitchenName ?? 'SPPG Mitra',
        sppgPublicKeyB64: publicKeyB64,
        weather: weather,
        dangerEvaluation: danger,
        gpsWithinRadius: true,
        distanceMeters: 25,
      ),
    );
  }

  @override
  Future<SchoolInspectionItem> saveInspection({
    required SchoolProfile school,
    required VerifiedBatchScanContext scanContext,
    required CapturedWebpPhoto? samplePhoto,
    required OnDeviceVisualResult? onDeviceResult,
    required CloudVisionResult? cloudResult,
    required bool manualSmellOk,
    required bool manualVisualOk,
    required bool manualPackOk,
    required bool approved,
    required bool isOffline,
  }) async {
    final item = SchoolInspectionItem(
      id: 'insp-${_inspections.length + 1}',
      batchId: scanContext.payload.batchId,
      batchCode: scanContext.payload.batchCode,
      menuName: scanContext.payload.menuName,
      schoolId: school.id,
      scannedAtUtc: scanContext.scannedAtUtc,
      elapsedMinutes: scanContext.dangerEvaluation.elapsedMinutes,
      bmkgTempC: scanContext.weather.temperatureC,
      bmkgSource: scanContext.weather.source,
      dangerStatus: scanContext.dangerEvaluation.status,
      gpsWithinRadius: scanContext.gpsWithinRadius,
      localPhotoPath: samplePhoto?.filePath,
      tfliteLabel: onDeviceResult?.label.dbValue,
      tfliteConfidence: onDeviceResult?.confidence,
      geminiSummaryJson: cloudResult?.toJsonMap(),
      manualSmellOk: manualSmellOk,
      manualVisualOk: manualVisualOk,
      manualPackOk: manualPackOk,
      finalDecision: approved ? 'APPROVED' : 'REJECTED',
      isPendingSync: isOffline,
    );
    _inspections.insert(0, item);
    return item;
  }

  @override
  Future<SampleVaultItem> createSampleVault({
    required SchoolProfile school,
    required String inspectionId,
    required String menuName,
    required String labelCode,
    required bool isOffline,
  }) async {
    final now = DateTime.now().toUtc();
    final expires = now.add(AppConstants.sampleVaultRetention);
    final vault = SampleVaultItem(
      id: 'sv-${_vaults.length + 1}',
      inspectionId: inspectionId,
      schoolId: school.id,
      menuName: menuName,
      labelCode: labelCode,
      storedAtUtc: now,
      expiresAtUtc: expires,
      status: 'active',
      isSynced: !isOffline,
    );
    _vaults.insert(0, vault);
    _vaultChangeCtrl.add(null);
    await notificationService.scheduleSampleVaultReminder(
      sampleId: vault.id,
      labelCode: vault.labelCode,
      menuName: vault.menuName,
      expiresAtUtc: expires,
    );
    return vault;
  }

  @override
  Stream<List<SampleVaultItem>> watchActiveSamples(String schoolId) async* {
    yield _activeList();
    await for (final _ in _vaultChangeCtrl.stream) {
      yield _activeList();
    }
  }

  @override
  Stream<List<SampleVaultItem>> watchHistorySamples(String schoolId) async* {
    yield _historyList();
    await for (final _ in _vaultChangeCtrl.stream) {
      yield _historyList();
    }
  }

  @override
  Future<void> refreshSampleVaultsFromServer(String schoolId) async {}

  @override
  Future<void> markSampleDisposed({
    required String sampleId,
    required bool isOffline,
  }) async {
    final idx = _vaults.indexWhere((v) => v.id == sampleId);
    if (idx != -1) {
      final old = _vaults[idx];
      _vaults[idx] = SampleVaultItem(
        id: old.id,
        inspectionId: old.inspectionId,
        schoolId: old.schoolId,
        menuName: old.menuName,
        labelCode: old.labelCode,
        storedAtUtc: old.storedAtUtc,
        expiresAtUtc: old.expiresAtUtc,
        status: 'disposed',
        isSynced: !isOffline,
      );
      _vaultChangeCtrl.add(null);
    }
    await notificationService.cancelSampleVaultReminder(sampleId);
  }

  @override
  Future<List<SchoolBatchOption>> fetchSelectableBatchesForWaste({
    required SchoolProfile school,
    required bool isOffline,
  }) async {
    return [
      ..._inspections.map(
        (i) => SchoolBatchOption(
          batchId: i.batchId,
          batchCode: i.batchCode,
          menuName: i.menuName,
          sealedAtUtc: i.scannedAtUtc,
        ),
      ),
      ...extraWasteBatches,
    ];
  }

  @override
  Future<bool> submitPlateWasteLog({
    required SchoolProfile school,
    required String batchId,
    required int carbWastePct,
    required int proteinWastePct,
    required int vegWastePct,
    required List<CapturedWebpPhoto> photos,
    required bool aiAssisted,
    required bool isOffline,
  }) async {
    return !isOffline;
  }

  @override
  Future<int> syncPendingSchoolQueue({required SchoolProfile school}) async => 0;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Stage 4 Logic: Danger-Zone Clock, BMKG Cache, TFLite Isolate & Offline QR', () {
    test('DangerZoneCalculator enforces PRD Section 3.3 risk x temperature thresholds', () {
      final sealed = DateTime.utc(2026, 11, 21, 0, 0);

      // HIGH risk + hot (>= 32 C): Green <= 90m, Yellow <= 120m, Red > 120m.
      expect(
        DangerZoneCalculator.evaluate(
          riskCategory: FoodRiskCategory.high,
          sealedAtUtc: sealed,
          scanAtUtc: sealed.add(const Duration(minutes: 90)),
          temperatureC: 32.5,
        ).status,
        DangerZoneStatus.green,
      );
      expect(
        DangerZoneCalculator.evaluate(
          riskCategory: FoodRiskCategory.high,
          sealedAtUtc: sealed,
          scanAtUtc: sealed.add(const Duration(minutes: 105)),
          temperatureC: 32.5,
        ).status,
        DangerZoneStatus.yellow,
      );
      expect(
        DangerZoneCalculator.evaluate(
          riskCategory: FoodRiskCategory.high,
          sealedAtUtc: sealed,
          scanAtUtc: sealed.add(const Duration(minutes: 125)),
          temperatureC: 32.5,
        ).status,
        DangerZoneStatus.red,
      );

      // HIGH risk + normal (< 32 C): Green <= 120m, Yellow <= 180m, Red > 180m.
      expect(
        DangerZoneCalculator.evaluate(
          riskCategory: FoodRiskCategory.high,
          sealedAtUtc: sealed,
          scanAtUtc: sealed.add(const Duration(minutes: 110)),
          temperatureC: 29.0,
        ).status,
        DangerZoneStatus.green,
      );
      expect(
        DangerZoneCalculator.evaluate(
          riskCategory: FoodRiskCategory.high,
          sealedAtUtc: sealed,
          scanAtUtc: sealed.add(const Duration(minutes: 150)),
          temperatureC: 29.0,
        ).status,
        DangerZoneStatus.yellow,
      );
      expect(
        DangerZoneCalculator.evaluate(
          riskCategory: FoodRiskCategory.high,
          sealedAtUtc: sealed,
          scanAtUtc: sealed.add(const Duration(minutes: 185)),
          temperatureC: 29.0,
        ).status,
        DangerZoneStatus.red,
      );

      // MEDIUM hot vs LOW.
      expect(
        DangerZoneCalculator.evaluate(
          riskCategory: FoodRiskCategory.medium,
          sealedAtUtc: sealed,
          scanAtUtc: sealed.add(const Duration(minutes: 210)),
          temperatureC: 33.0,
        ).status,
        DangerZoneStatus.yellow,
      );
      expect(
        DangerZoneCalculator.evaluate(
          riskCategory: FoodRiskCategory.low,
          sealedAtUtc: sealed,
          scanAtUtc: sealed.add(const Duration(minutes: 490)),
          temperatureC: 35.0,
        ).status,
        DangerZoneStatus.red,
      );
    });

    test('BmkgWeatherService caches 72h forecast in Drift and falls back to 31 C without cache', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      var nowUtc = DateTime.utc(2026, 11, 21, 5, 0);
      final dio = Dio()
        ..httpClientAdapter = _StubDioAdapter((options) {
          final adm4 = options.queryParameters['adm4'] as String?;
          if (adm4 == '33.02.26.1001') {
            return ResponseBody.fromString(
              jsonEncode({
                'data': [
                  {
                    'lokasi': {'adm4': '33.02.26.1001'},
                    'cuaca': [
                      [
                        {
                          'utc_datetime': '2026-11-21 06:00:00',
                          't': 33.4,
                          'hu': 68,
                          'weather_desc': 'Cerah Berawan',
                        },
                      ],
                    ],
                  },
                ],
              }),
              200,
              headers: {
                'content-type': ['application/json'],
              },
            );
          }
          return ResponseBody.fromString(
            jsonEncode({'data': [{'lokasi': {}, 'cuaca': []}]}),
            200,
            headers: {
              'content-type': ['application/json'],
            },
          );
        });

      final service = DioBmkgWeatherService(
        database: db,
        dio: dio,
        clockUtc: () => nowUtc,
      );

      // 1. Live fetch populates Drift cache.
      final liveReading = await service.getCurrentWeather(
        adm4Code: '33.02.26.1001',
        isOffline: false,
      );
      expect(liveReading.source, BmkgSource.live);
      expect(liveReading.temperatureC, closeTo(33.4, 0.01));
      expect(liveReading.isHot, isTrue);

      // 2. Advance 5 hours (beyond 3h refresh window, inside 72h TTL) and go offline -> cached reading!
      nowUtc = nowUtc.add(const Duration(hours: 5));
      final cachedOffline = await service.getCurrentWeather(
        adm4Code: '33.02.26.1001',
        isOffline: true,
      );
      expect(cachedOffline.source, BmkgSource.cached);
      expect(cachedOffline.temperatureC, closeTo(33.4, 0.01));

      // 3. Village with empty BMKG cuaca returns 31.0 C fallback safely.
      final emptyFallback = await service.getCurrentWeather(
        adm4Code: '33.02.26.1099',
        isOffline: false,
      );
      expect(emptyFallback.source, BmkgSource.fallbackOffline);
      expect(emptyFallback.temperatureC, AppConstants.bmkgOfflineFallbackTempC);
    });

    test('OnDevice Isolate vision analyzer runs safely without `.tflite` asset and handles offline cloud fallback', () async {
      final vision = DeviceHybridVisionService(
        client: null,
        modelAssetPath: 'assets/models/missing_fallback_model.tflite',
      );
      final localResult = await vision.analyzeOnDevice(_validTinyWebpBytes);
      expect(localResult.usedTfliteModel, isFalse);
      expect(localResult.summaryText, isNotEmpty);

      final wasteResult = await vision.estimatePlateWasteOnDevice([
        _validTinyWebpBytes,
      ]);
      expect(wasteResult.estimatedCarbWastePct, isIn([0, 25, 50, 75]));

      final cloudResult = await vision.analyzeCloudOrganoleptic(
        photoBytes: _validTinyWebpBytes,
        menuName: 'Nasi Ayam Suwir',
        isOffline: true,
      );
      expect(cloudResult.ok, isFalse);
      expect(cloudResult.fallbackRequired, isTrue);
    });

    test('SupabaseSchoolRepository verifies Ed25519 QR offline, schedules 48h Bank Sampel reminder, and queues plate waste', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final nowUtc = DateTime.utc(2026, 11, 21, 5, 30);
      final fixtures = await _prepareSignedQrFixtures(
        nowUtc.subtract(const Duration(minutes: 40)),
      );
      final spyNotif = _SpyNotificationService();
      final repo = SupabaseSchoolRepository(
        client: null,
        database: db,
        ed25519Service: Ed25519Service(secureStore: _InMemorySecureKeyStore()),
        bmkgService: _StaticBmkgWeatherService(
          BmkgWeatherReading(
            adm4Code: _demoSchool.adm4Code,
            temperatureC: 30.5,
            source: BmkgSource.cached,
            observedAtUtc: nowUtc,
          ),
        ),
        notificationService: spyNotif,
        locationReader: () async => (lat: _demoSchool.lat, lng: _demoSchool.lng),
        clockUtc: () => nowUtc,
      );

      // Seed cached SPPG public key in Drift (as happens at login).
      await db.upsertSppgKey(
        LocalSppgKeysCompanion.insert(
          sppgId: _demoSchool.sppgId!,
          sppgName: _demoSchool.partnerKitchenName!,
          inviteCode: _demoSchool.partnerInviteCode!,
          publicKeyB64: fixtures.publicKeyB64,
          updatedAt: nowUtc,
        ),
      );

      // Valid QR passes 100% offline.
      final validRes = await repo.verifyQrPayloadOffline(
        rawQrText: fixtures.validQrJson,
        school: _demoSchool,
        isOffline: true,
      );
      expect(validRes.isValid, isTrue);
      expect(validRes.context!.dangerEvaluation.status, DangerZoneStatus.green);
      expect(validRes.context!.gpsWithinRadius, isTrue);

      // Tampered QR fails with invalidSignature.
      final forgedRes = await repo.verifyQrPayloadOffline(
        rawQrText: fixtures.fakeQrJson,
        school: _demoSchool,
        isOffline: true,
      );
      expect(forgedRes.isValid, isFalse);
      expect(forgedRes.outcome, QrVerificationOutcome.invalidSignature);

      // Save inspection offline + create 48h Bank Sampel.
      final inspection = await repo.saveInspection(
        school: _demoSchool,
        scanContext: validRes.context!,
        samplePhoto: null,
        onDeviceResult: null,
        cloudResult: null,
        manualSmellOk: true,
        manualVisualOk: true,
        manualPackOk: true,
        approved: true,
        isOffline: true,
      );
      expect(inspection.isPendingSync, isTrue);

      final labelCode = repo.generateSampleLabelCode(nowUtc);
      expect(labelCode.startsWith('SMP-'), isTrue);

      final vault = await repo.createSampleVault(
        school: _demoSchool,
        inspectionId: inspection.id,
        menuName: 'Nasi Ayam Suwir & Tumis Kacang',
        labelCode: labelCode,
        isOffline: true,
      );
      expect(spyNotif.scheduled.length, 1);
      expect(
        spyNotif.scheduled.first.expiresAtUtc.difference(nowUtc),
        const Duration(hours: 48),
      );
      expect((await repo.watchActiveSamples(_demoSchool.id).first).length, 1);

      // Submit plate waste offline.
      final wasteSynced = await repo.submitPlateWasteLog(
        school: _demoSchool,
        batchId: validRes.context!.payload.batchId,
        carbWastePct: 25,
        proteinWastePct: 0,
        vegWastePct: 50,
        photos: const [],
        aiAssisted: false,
        isOffline: true,
      );
      expect(wasteSynced, isFalse);

      // Mark sample disposed -> cancels local reminder and moves to history.
      await repo.markSampleDisposed(sampleId: vault.id, isOffline: true);
      expect(spyNotif.cancelledIds, contains(vault.id));
      expect((await repo.watchActiveSamples(_demoSchool.id).first), isEmpty);
      expect((await repo.watchHistorySamples(_demoSchool.id).first).length, 1);
    });
  });

  group('Stage 4 School UI Flows (G01 - G05 & G07)', () {
    Future<
      ({
        _InMemoryStage4SchoolRepository repo,
        _SpyNotificationService spyNotif,
        _FakeLiveCameraService camera,
      })
    >
    pumpSchoolApp(
      WidgetTester tester, {
      required BmkgWeatherReading weather,
      required String validQrJson,
      required String fakeQrJson,
      required String publicKeyB64,
      Size screenSize = const Size(390, 844),
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final spyNotif = _SpyNotificationService();
      final camera = _FakeLiveCameraService();
      final repo = _InMemoryStage4SchoolRepository(
        publicKeyB64: publicKeyB64,
        weather: weather,
        notificationService: spyNotif,
      );
      addTearDown(repo.dispose);

      tester.view.physicalSize = screenSize;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            isSupabaseReadyProvider.overrideWithValue(true),
            authRepositoryProvider.overrideWithValue(
              _Stage4AuthRepository(_schoolSession),
            ),
            schoolRepositoryProvider.overrideWithValue(repo),
            liveCameraWebpServiceProvider.overrideWithValue(camera),
            hybridVisionServiceProvider.overrideWithValue(
              _OfflineFallbackHybridVisionService(),
            ),
            qrScannerViewBuilderProvider.overrideWithValue(
              (context, torch, onDetected) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => onDetected(fakeQrJson),
                    child: const Text('Simulasi QR Palsu'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => onDetected(validQrJson),
                    child: const Text('Simulasi QR Valid'),
                  ),
                ],
              ),
            ),
            isOfflineProvider.overrideWith((ref) => Stream.value(true)),
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
          ],
          child: const LacakSajiApp(),
        ),
      );
      await tester.pumpAndSettle();
      return (repo: repo, spyNotif: spyNotif, camera: camera);
    }

    testWidgets(
      'G01 -> G02 -> G03 -> G04 -> G05 offline flow verifies Ed25519 QR, BMKG weather, 3-tap manual audit, and 48h Bank Sampel',
      (tester) async {
        final nowUtc = DateTime.now().toUtc();
        final fixtures = await _prepareSignedQrFixtures(
          nowUtc.subtract(const Duration(minutes: 45)),
        );
        final ctx = await pumpSchoolApp(
          tester,
          weather: BmkgWeatherReading(
            adm4Code: _demoSchool.adm4Code,
            temperatureC: 31.4,
            source: BmkgSource.cached,
            observedAtUtc: nowUtc,
          ),
          validQrJson: fixtures.validQrJson,
          fakeQrJson: fixtures.fakeQrJson,
          publicKeyB64: fixtures.publicKeyB64,
        );

        // G01 Dashboard checks.
        expect(find.text('Beranda Sekolah'), findsOneWidget);
        expect(find.text('SDN 1 Purwokerto'), findsOneWidget);
        expect(find.text('31.4 C'), findsOneWidget);
        expect(find.text(AppConstants.bmkgShortAttribution), findsOneWidget);
        expect(find.textContaining('Siap verifikasi QR 100% offline'), findsOneWidget);

        await tester.ensureVisible(find.text('Pindai QR Makanan Masuk'));
        await tester.tap(find.text('Pindai QR Makanan Masuk'));
        await tester.pumpAndSettle();

        // G02: Tampered QR shows high-contrast error sheet.
        expect(find.text('Pindai QR Segel Batch'), findsOneWidget);
        await tester.tap(find.text('Simulasi QR Palsu'));
        await tester.pumpAndSettle();
        expect(find.text('Segel Digital Tidak Valid'), findsOneWidget);
        await tester.tap(find.text('Pindai Ulang QR'));
        await tester.pumpAndSettle();

        // G02: Valid QR enters G03 Danger-Zone Gate.
        await tester.tap(find.text('Simulasi QR Valid'));
        await tester.pumpAndSettle();

        expect(find.text('Langkah 1 dari 3: Cek Waktu & Suhu'), findsOneWidget);
        expect(find.text('WAKTU PENGIRIMAN AMAN'), findsOneWidget);
        expect(find.textContaining('Segel Digital Asli'), findsOneWidget);
        expect(find.textContaining(AppConstants.bmkgShortAttribution), findsOneWidget);

        await tester.tap(find.text('Lanjut: Foto Sampel Makanan'));
        await tester.pumpAndSettle();

        // G04: Live photo + offline fallback analysis + 3-tap manual checklist (zero sparkle icon).
        expect(find.text('Langkah 2 dari 3: Cek Kondisi Makanan'), findsOneWidget);
        expect(find.byIcon(Icons.auto_awesome), findsNothing);

        await tester.tap(find.text('Ambil Foto Sampel'));
        await tester.pumpAndSettle();
        expect(ctx.camera.count, 1);
        expect(find.text('Hasil Pemeriksaan Foto'), findsOneWidget);
        expect(find.text('TAMPAK WAJAR SECARA VISUAL'), findsOneWidget);
        expect(find.textContaining('TFLite'), findsNothing);

        await tester.ensureVisible(find.text('Bau Normal'));
        await tester.tap(find.text('Bau Normal'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Tampak Segar'));
        await tester.tap(find.text('Tampak Segar'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Kemasan Utuh'));
        await tester.tap(find.text('Kemasan Utuh'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Makanan Aman, Lanjut Simpan Sampel'));
        await tester.pumpAndSettle();

        // G05 Step 3: Bank Sampel 2x24h onboarding & 48h reminder scheduling.
        expect(find.text('Langkah 3 dari 3: Simpan 1 Porsi Sampel'), findsOneWidget);
        expect(find.textContaining('SMP-'), findsOneWidget);
        await tester.ensureVisible(find.text('Sampel Sudah di Kulkas, Selesai'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sampel Sudah di Kulkas, Selesai'));
        await tester.pumpAndSettle();

        expect(ctx.spyNotif.scheduled.length, 1);
        expect(find.text('Beranda Sekolah'), findsOneWidget);
        expect(find.text('Bank Sampel 48 Jam (1 aktif)'), findsOneWidget);
        // Allow the confirmation SnackBar to dismiss naturally before tapping near the bottom fold.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // Open Sampel tab and mark sample disposed.
        await tester.tap(find.text('Sampel'));
        await tester.pumpAndSettle();
        expect(find.text('Tandai Sudah Dimusnahkan'), findsOneWidget);
        await tester.ensureVisible(find.text('Tandai Sudah Dimusnahkan'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tandai Sudah Dimusnahkan'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ya, Tandai Dimusnahkan'));
        await tester.pumpAndSettle();

        expect(ctx.spyNotif.cancelledIds.length, 1);
        expect(find.text('Belum ada sampel aktif di kulkas'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'G03 Red Stop transitions cleanly to /school/report handoff and G07 submits plate waste',
      (tester) async {
        final nowUtc = DateTime.now().toUtc();
        // Sealed 4 hours ago -> RED danger status for HIGH risk menu.
        final fixtures = await _prepareSignedQrFixtures(
          nowUtc.subtract(const Duration(hours: 4)),
        );
        await pumpSchoolApp(
          tester,
          weather: BmkgWeatherReading(
            adm4Code: _demoSchool.adm4Code,
            temperatureC: 33.2,
            source: BmkgSource.live,
            observedAtUtc: nowUtc,
          ),
          validQrJson: fixtures.validQrJson,
          fakeQrJson: fixtures.fakeQrJson,
          publicKeyB64: fixtures.publicKeyB64,
        );

        await tester.tap(find.text('Pindai QR Makanan Masuk'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Simulasi QR Valid'));
        await tester.pumpAndSettle();

        expect(find.text('STOP: JANGAN DIBAGIKAN'), findsOneWidget);
        await tester.tap(find.text('Hentikan Distribusi & Buat Laporan'));
        await tester.pumpAndSettle();

        expect(find.text('DISTRIBUSI DIHENTIKAN: JANGAN DIBAGIKAN'), findsOneWidget);
        await tester.ensureVisible(find.text('Kembali ke Beranda Sekolah'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kembali ke Beranda Sekolah'));
        await tester.pumpAndSettle();
        expect(find.text('Beranda Sekolah'), findsOneWidget);

        // Now navigate to G07 Plate-Waste tab (batch is available from local inspection).
        await tester.tap(find.text('Sisa Makan'));
        await tester.pumpAndSettle();
        expect(find.text('Sisa Makanan Siswa'), findsOneWidget);
        // Verify nothing is pre-selected before user picks or uploads a photo.
        expect(find.text('Belum dipilih'), findsNWidgets(3));
        await tester.ensureVisible(find.text('Tambah Foto Ompreng (0/5)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tambah Foto Ompreng (0/5)'));
        await tester.pumpAndSettle();
        expect(find.text('1 / 5 foto'), findsOneWidget);
        expect(find.text('Hasil Estimasi (1 Foto)'), findsOneWidget);
        expect(find.text('Terisi Otomatis'), findsOneWidget);

        await tester.ensureVisible(find.text('Sedikit (25%)').last);
        await tester.tap(find.text('Sedikit (25%)').last);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Kirim Evaluasi ke Dapur SPPG'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kirim Evaluasi ke Dapur SPPG'));
        await tester.pumpAndSettle();
        expect(find.text('0 / 5 foto'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'Compact 320dp viewport at Ekstra Besar scale renders G01, G05, G07 with zero overflow',
      (tester) async {
        final nowUtc = DateTime.now().toUtc();
        final fixtures = await _prepareSignedQrFixtures(nowUtc);
        await pumpSchoolApp(
          tester,
          weather: BmkgWeatherReading(
            adm4Code: _demoSchool.adm4Code,
            temperatureC: 31.0,
            source: BmkgSource.fallbackOffline,
            observedAtUtc: nowUtc,
          ),
          validQrJson: fixtures.validQrJson,
          fakeQrJson: fixtures.fakeQrJson,
          publicKeyB64: fixtures.publicKeyB64,
          screenSize: const Size(320, 700),
        );

        await tester.tap(find.text('Profil'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Ekstra Besar'));
        await tester.tap(find.text('Ekstra Besar'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Beranda'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Sampel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Sisa Makan'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'G07 batch picker opens scrollable popup on 320dp Ekstra Besar viewport and updates selected batch',
      (tester) async {
        final nowUtc = DateTime.now().toUtc();
        final fixtures = await _prepareSignedQrFixtures(nowUtc);
        final ctx = await pumpSchoolApp(
          tester,
          weather: BmkgWeatherReading(
            adm4Code: _demoSchool.adm4Code,
            temperatureC: 31.0,
            source: BmkgSource.fallbackOffline,
            observedAtUtc: nowUtc,
          ),
          validQrJson: fixtures.validQrJson,
          fakeQrJson: fixtures.fakeQrJson,
          publicKeyB64: fixtures.publicKeyB64,
          screenSize: const Size(320, 700),
        );

        ctx.repo.extraWasteBatches.addAll(
          List.generate(
            10,
            (i) => SchoolBatchOption(
              batchId: 'batch-pick-$i',
              batchCode: 'BCH-2611-P${i.toString().padLeft(2, '0')}',
              menuName: i == 0
                  ? 'Nasi Ayam Panggang Kecap & Tumis Kangkung'
                  : 'Menu Pilihan Panjang Nomor ${i + 1} Dengan Sayur Segar',
              sealedAtUtc: nowUtc.subtract(Duration(hours: i * 4)),
            ),
          ),
        );

        await tester.tap(find.text('Profil'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Ekstra Besar'));
        await tester.tap(find.text('Ekstra Besar'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sisa Makan'));
        await tester.pumpAndSettle();
        expect(
          find.text('Nasi Ayam Panggang Kecap & Tumis Kangkung'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        // Open scrollable batch picker popup.
        await tester.tap(
          find.text('Nasi Ayam Panggang Kecap & Tumis Kangkung'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pilih Batch Makanan'), findsOneWidget);
        expect(
          find.text('10 batch tersedia. Gulir untuk memilih.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        // Scroll inside the popup to the 10th item and select it.
        final targetText = find.text(
          'Menu Pilihan Panjang Nomor 10 Dengan Sayur Segar',
        );
        await tester.scrollUntilVisible(
          targetText,
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(targetText);
        await tester.pumpAndSettle();

        // Popup closes and screen reflects newly chosen batch.
        expect(find.text('Pilih Batch Makanan'), findsNothing);
        expect(targetText, findsOneWidget);
        expect(tester.takeException(), isNull);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );
  });
}
