import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lacak_saji/core/crypto/batch_qr_payload.dart';
import 'package:lacak_saji/core/crypto/ed25519_service.dart';
import 'package:lacak_saji/core/database/app_database.dart';
import 'package:lacak_saji/core/database/database_provider.dart';
import 'package:lacak_saji/core/media/live_camera_webp_service.dart';
import 'package:lacak_saji/core/network/bmkg_weather_service.dart';
import 'package:lacak_saji/core/network/connectivity_provider.dart';
import 'package:lacak_saji/core/notifications/fcm_alert_service.dart';
import 'package:lacak_saji/core/notifications/local_notification_service.dart';
import 'package:lacak_saji/core/sync/offline_sync_controller.dart';
import 'package:lacak_saji/core/theme/app_theme.dart';
import 'package:lacak_saji/core/theme/text_scale_provider.dart';
import 'package:lacak_saji/core/widgets/lacak_cluster_alert_overlay.dart';
import 'package:lacak_saji/features/alerts/data/cluster_alert_repository.dart';
import 'package:lacak_saji/features/alerts/domain/cluster_alert_models.dart';
import 'package:lacak_saji/features/allergens/domain/allergen_models.dart';
import 'package:lacak_saji/features/auth/domain/auth_models.dart';
import 'package:lacak_saji/features/auth/presentation/auth_controller.dart';
import 'package:lacak_saji/features/kitchen/data/kitchen_repository.dart';
import 'package:lacak_saji/features/kitchen/domain/kitchen_models.dart';
import 'package:lacak_saji/features/kitchen/presentation/create_batch_screen.dart';
import 'package:lacak_saji/features/kitchen/presentation/kitchen_providers.dart';
import 'package:lacak_saji/features/school/data/school_repository.dart';
import 'package:lacak_saji/features/school/domain/danger_zone_calculator.dart';
import 'package:lacak_saji/features/school/domain/school_models.dart';
import 'package:lacak_saji/features/school/presentation/anomaly_report_screen.dart';
import 'package:lacak_saji/features/school/presentation/danger_zone_gate_screen.dart';
import 'package:lacak_saji/features/settings/data/team_security_repository.dart';
import 'package:lacak_saji/features/settings/domain/team_security_models.dart';
import 'package:lacak_saji/features/settings/presentation/team_security_providers.dart';
import 'package:lacak_saji/features/traceability/data/traceability_repository.dart';
import 'package:lacak_saji/features/traceability/domain/traceability_models.dart';
import 'package:lacak_saji/features/traceability/presentation/traceability_providers.dart';

class _MemorySecureKeyStore implements SecureKeyStore {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }
}

class _FixedAuthController extends AuthController {
  _FixedAuthController(this._fixedState);

  final AuthState _fixedState;

  @override
  AuthState build() => _fixedState;
}

class _NoopNotificationService implements LocalNotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleSampleVaultReminder({
    required String sampleId,
    required String labelCode,
    required String menuName,
    required DateTime expiresAtUtc,
  }) async {}

  @override
  Future<void> cancelSampleVaultReminder(String sampleId) async {}

  @override
  Future<void> showClusterAlertNotification(ClusterAlertEvent event) async {}
}

class _FakeFcmService implements FcmAlertService {
  final _ctrl = StreamController<ClusterAlertEvent>.broadcast();

  @override
  Stream<ClusterAlertEvent> get alertStream => _ctrl.stream;

  @override
  Future<void> clearBinding() async {}

  @override
  Future<void> initializeAndBind({
    required String userId,
    required String sppgId,
    String? excludeSchoolId,
    required dynamic client,
  }) async {}

  @override
  void dispose() => _ctrl.close();
}

class _FakeClusterAlertRepo implements ClusterAlertRepository {
  _FakeClusterAlertRepo({this.initialToday = const []});

  final List<ClusterAlertEvent> initialToday;
  final _realtimeCtrl = StreamController<ClusterAlertEvent>.broadcast();
  int ackCalls = 0;

  @override
  Future<void> acknowledgeAlert({
    required String alertId,
    required String schoolId,
    required bool isOffline,
  }) async {
    ackCalls++;
  }

  @override
  Future<List<ClusterAlertEvent>> fetchUnacknowledgedAlertsForToday({
    required String sppgId,
    String? currentSchoolId,
  }) async => initialToday;

  @override
  Future<String?> findSampleLabelForInspection({
    required String schoolId,
    required String inspectionId,
  }) async => null;

  @override
  Future<void> markPdfDispatched({
    required String alertId,
    required String reporterSchoolId,
    required bool isOffline,
  }) async {}

  @override
  Future<ClusterAlertEvent> resolveClusterAlert({
    required ClusterAlertEvent alert,
    required AlertResolutionStatus newStatus,
    required String resolutionNote,
    required String resolverUserId,
    required String resolverName,
    required bool isOffline,
  }) async => alert.copyWith(resolutionStatus: newStatus);

  @override
  Future<ClusterAlertEvent> submitClusterAlert({
    required SchoolProfile school,
    required String sppgId,
    required String sppgName,
    required String batchId,
    required String batchCode,
    required String menuName,
    required String inspectionId,
    required ClusterAlertStage stage,
    required int symptomCount,
    required bool broadcastEnabled,
    required bool isOffline,
    String? notes,
    String? sampleLabelCode,
  }) async => throw UnimplementedError();

  @override
  Future<int> syncPendingAlerts({String? schoolId, String? kitchenId}) async =>
      0;

  @override
  Stream<ClusterAlertEvent> watchRealtimeAlerts({
    required String sppgId,
    String? excludeSchoolId,
  }) => _realtimeCtrl.stream;

  void emitRealtime(ClusterAlertEvent event) => _realtimeCtrl.add(event);

  void dispose() => _realtimeCtrl.close();
}

class _SpyKitchenRepo implements KitchenRepository {
  int syncCalls = 0;

  @override
  Future<int> syncPendingKitchenBatches({
    required KitchenProfile kitchen,
  }) async {
    syncCalls++;
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SpyTeamSecurityRepo implements TeamSecurityRepository {
  int syncCalls = 0;

  @override
  Future<int> syncPendingTeamAndKeyQueue({
    String? kitchenId,
    String? schoolId,
  }) async {
    syncCalls++;
    return 1;
  }

  @override
  Future<InstitutionMemberItem> addMember({
    required AuthState authState,
    required String memberName,
    required String memberEmail,
    required InstitutionMemberRole role,
    required bool isOffline,
  }) => throw UnimplementedError();

  @override
  Future<TeamSecurityOverview> fetchOverview({
    required AuthState authState,
    required bool isOffline,
  }) => throw UnimplementedError();

  @override
  Future<void> revokeKitchenSigningKey({
    required KitchenProfile kitchen,
    required String keyId,
    required bool isOffline,
  }) => throw UnimplementedError();

  @override
  Future<SigningKeyItem> rotateKitchenSigningKey({
    required KitchenProfile kitchen,
    required bool revokePrevious,
    required String deviceLabel,
    required bool isOffline,
  }) => throw UnimplementedError();

  @override
  Future<void> setMemberActive({
    required AuthState authState,
    required InstitutionMemberItem member,
    required bool isActive,
    required bool isOffline,
  }) => throw UnimplementedError();
}

class _SpyTraceabilityRepo implements TraceabilityRepository {
  Set<String>? lastSyncedOpTypes;
  int syncCalls = 0;

  @override
  Future<int> syncPendingTraceabilityQueue({
    String? sppgId,
    String? schoolId,
    Set<String>? operationTypes,
  }) async {
    syncCalls++;
    lastSyncedOpTypes = operationTypes;
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  const sppgId = 'a1000000-0000-4000-8000-000000000001';
  const sdn1Id = 'b1000000-0000-4000-8000-000000000001';
  const sdn2Id = 'b1000000-0000-4000-8000-000000000002';

  const courierUser = UserProfile(
    id: '40000000-0000-4000-8000-000000000001',
    email: 'kurir.a@lacaksaji.id',
    role: UserRole.courier,
    fullName: 'Bapak Dedi (Kurir SPPG)',
  );

  const kitchenAdmin = UserProfile(
    id: '10000000-0000-4000-8000-000000000001',
    email: 'dapur.a@lacaksaji.id',
    role: UserRole.kitchen,
    fullName: 'Ibu Ratna',
  );

  const schoolUser = UserProfile(
    id: '20000000-0000-4000-8000-000000000001',
    email: 'sdn1.pwt@lacaksaji.id',
    role: UserRole.school,
    fullName: 'Ibu Siti',
  );

  test(
    'Bug #1 & #10a: Multi-school courier handovers keep SDN 1 & SDN 2 intact, guard double-load, and verify Ed25519 QR signatures',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final ed25519 = Ed25519Service(secureStore: _MemorySecureKeyStore());
      final mat = await ed25519.getOrCreateActiveKeyMaterial(sppgId: sppgId);

      final kitchen = KitchenProfile(
        id: sppgId,
        ownerUserId: kitchenAdmin.id,
        regNumber: 'BGN-PWT-2026-001',
        inviteCode: 'SPPG-PWT-01',
        name: 'SPPG Purwokerto Utara',
        adm4Code: '33.02.26.1001',
        lat: -7.4126,
        lng: 109.2345,
        publicKey: mat.publicKeyB64,
        isVerified: true,
      );

      final sealedAt = DateTime.utc(2026, 11, 28, 1, 0);
      final sealedEpoch = sealedAt.millisecondsSinceEpoch ~/ 1000;
      const batchId = 'c9000000-0000-4000-8000-000000000001';
      final signed = await ed25519.signBatchWithKeyId(
        sppgId: sppgId,
        buildCanonicalForKeyId: (kid) =>
            BatchQrPayload.buildCanonicalSigningString(
              batchId: batchId,
              batchCode: 'BCH-2611-MS1',
              sppgId: sppgId,
              menuName: 'Nasi Ayam Goreng & Tahu',
              riskCategory: 'MEDIUM',
              sealedAtEpochSec: sealedEpoch,
              timestampSource: 'server_verified',
              keyId: kid,
              allergenTags: const ['kedelai'],
            ),
      );

      final validQr = BatchQrPayload(
        batchId: batchId,
        batchCode: 'BCH-2611-MS1',
        sppgId: sppgId,
        menuName: 'Nasi Ayam Goreng & Tahu',
        riskCategory: 'MEDIUM',
        sealedAtEpochSec: sealedEpoch,
        timestampSource: 'server_verified',
        signatureB64: signed.signatureB64,
        keyId: signed.keyId,
        allergenTags: const ['kedelai'],
      );

      final tamperedQr = BatchQrPayload(
        batchId: batchId,
        batchCode: 'BCH-2611-MS1',
        sppgId: sppgId,
        menuName: 'Menu Diubah Palsu',
        riskCategory: 'MEDIUM',
        sealedAtEpochSec: sealedEpoch,
        timestampSource: 'server_verified',
        signatureB64: signed.signatureB64,
        keyId: signed.keyId,
        allergenTags: const ['kedelai'],
      );

      final repo = SupabaseTraceabilityRepository(
        client: null,
        database: db,
        ed25519Service: ed25519,
      );

      // Tampered QR must be rejected on courier scan.
      await expectLater(
        () => repo.recordCourierScan(
          kitchen: kitchen,
          actor: courierUser,
          qrPayload: tamperedQr,
          mode: CourierScanMode.loadAtKitchen,
          isOffline: true,
        ),
        throwsA(isA<FormatException>()),
      );

      // 1. Load at kitchen
      final loaded = await repo.recordCourierScan(
        kitchen: kitchen,
        actor: courierUser,
        qrPayload: validQr,
        mode: CourierScanMode.loadAtKitchen,
        isOffline: true,
        lat: -7.4126,
        lng: 109.2345,
      );
      expect(loaded.status, TransitHandoverDbStatus.inTransit);
      expect(loaded.schoolId, isNull);

      // 2. Arrive at SDN 1 (claims open load record)
      final sdn1Arrived = await repo.recordCourierScan(
        kitchen: kitchen,
        actor: courierUser,
        qrPayload: validQr,
        mode: CourierScanMode.arriveAtSchool,
        isOffline: true,
        schoolId: sdn1Id,
        schoolName: 'SDN 1 Purwokerto',
        lat: -7.4188,
        lng: 109.2351,
      );
      expect(sdn1Arrived.id, loaded.id);
      expect(sdn1Arrived.schoolId, sdn1Id);
      expect(sdn1Arrived.status, TransitHandoverDbStatus.arrived);

      // 3. Arrive at SDN 2 (creates SEPARATE handover inheriting load metadata)
      final sdn2Arrived = await repo.recordCourierScan(
        kitchen: kitchen,
        actor: courierUser,
        qrPayload: validQr,
        mode: CourierScanMode.arriveAtSchool,
        isOffline: true,
        schoolId: sdn2Id,
        schoolName: 'SDN 2 Purwokerto',
        lat: -7.4215,
        lng: 109.2402,
      );
      expect(sdn2Arrived.id, isNot(sdn1Arrived.id));
      expect(sdn2Arrived.schoolId, sdn2Id);
      expect(sdn2Arrived.loadedAtUtc, loaded.loadedAtUtc);
      expect(sdn2Arrived.loadLat, loaded.loadLat);

      // 4. Both SDN 1 and SDN 2 handovers remain intact in deliveries & school-scoped timelines!
      final deliveries = await repo.fetchCourierDeliveries(kitchen: kitchen);
      final arrivedSchoolIds = deliveries
          .map((d) => d.handover?.schoolId)
          .whereType<String>()
          .toSet();
      expect(arrivedSchoolIds, containsAll([sdn1Id, sdn2Id]));

      final t1 = await repo.fetchSupplyChainTimeline(
        sppgId: sppgId,
        batchId: batchId,
        sealedAtUtc: sealedAt,
        schoolId: sdn1Id,
      );
      final t2 = await repo.fetchSupplyChainTimeline(
        sppgId: sppgId,
        batchId: batchId,
        sealedAtUtc: sealedAt,
        schoolId: sdn2Id,
      );
      expect(t1.handover?.schoolId, sdn1Id);
      expect(t2.handover?.schoolId, sdn2Id);

      // 5. Revoked key in Drift must reject courier scan too!
      await db.upsertSigningKey(
        LocalSigningKeysCompanion(
          keyId: Value(signed.keyId),
          sppgId: const Value(sppgId),
          publicKeyB64: Value(mat.publicKeyB64),
          status: const Value('revoked'),
          createdAt: Value(sealedAt.subtract(const Duration(hours: 2))),
          revokedAt: Value(sealedAt.subtract(const Duration(minutes: 10))),
          updatedAt: Value(sealedAt),
        ),
      );
      await expectLater(
        () => repo.recordCourierScan(
          kitchen: kitchen,
          actor: courierUser,
          qrPayload: validQr,
          mode: CourierScanMode.loadAtKitchen,
          isOffline: true,
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'Edge Cases #2 & #3: Revoked key rejects offline_unverified clock spoofing & unknown rotated key offline returns missingPublicKey',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final revokedAt = DateTime.utc(2026, 11, 28, 3, 0);
      final backdatedSeal = DateTime.utc(2026, 11, 28, 2, 0);

      // Offline_unverified from a revoked key MUST be rejected even if backdated before revokedAt!
      expect(
        Ed25519Service.isRevokedForSealTime(
          status: 'revoked',
          revokedAtUtc: revokedAt,
          sealedAtUtc: backdatedSeal,
          timestampSource: 'offline_unverified',
        ),
        isTrue,
      );
      // Server_verified sealed legitimately before revocation stays valid.
      expect(
        Ed25519Service.isRevokedForSealTime(
          status: 'revoked',
          revokedAtUtc: revokedAt,
          sealedAtUtc: backdatedSeal,
          timestampSource: 'server_verified',
        ),
        isFalse,
      );

      // School has old key_v1 cached, Kitchen rotates to key_v2 while school is offline.
      final ed25519 = Ed25519Service(secureStore: _MemorySecureKeyStore());
      final v1 = await ed25519.getOrCreateActiveKeyMaterial(sppgId: sppgId);
      final v2 = await ed25519.rotateKeyPair(sppgId: sppgId);

      await db.upsertSppgKey(
        LocalSppgKeysCompanion(
          sppgId: const Value(sppgId),
          sppgName: const Value('SPPG Purwokerto Utara'),
          inviteCode: const Value('SPPG-PWT-01'),
          publicKeyB64: Value(v1.publicKeyB64),
          updatedAt: Value(DateTime.utc(2026, 11, 28, 1, 0)),
        ),
      );
      await db.upsertSigningKey(
        LocalSigningKeysCompanion(
          keyId: Value(v1.keyId),
          sppgId: const Value(sppgId),
          publicKeyB64: Value(v1.publicKeyB64),
          status: const Value('active'),
          createdAt: Value(DateTime.utc(2026, 11, 28, 1, 0)),
          updatedAt: Value(DateTime.utc(2026, 11, 28, 1, 0)),
        ),
      );

      final sealedAt = DateTime.utc(2026, 11, 28, 2, 0);
      final sealedEpoch = sealedAt.millisecondsSinceEpoch ~/ 1000;
      final signedV2 = await ed25519.signBatchWithKeyId(
        sppgId: sppgId,
        buildCanonicalForKeyId: (kid) =>
            BatchQrPayload.buildCanonicalSigningString(
              batchId: 'batch-rot-2',
              batchCode: 'BCH-ROT-02',
              sppgId: sppgId,
              menuName: 'Nasi Soto Ayam',
              riskCategory: 'HIGH',
              sealedAtEpochSec: sealedEpoch,
              timestampSource: 'server_verified',
              keyId: kid,
            ),
      );
      expect(signedV2.keyId, v2.keyId);

      final qrV2 = BatchQrPayload(
        batchId: 'batch-rot-2',
        batchCode: 'BCH-ROT-02',
        sppgId: sppgId,
        menuName: 'Nasi Soto Ayam',
        riskCategory: 'HIGH',
        sealedAtEpochSec: sealedEpoch,
        timestampSource: 'server_verified',
        signatureB64: signedV2.signatureB64,
        keyId: signedV2.keyId,
      );

      final schoolRepo = SupabaseSchoolRepository(
        client: null,
        database: db,
        ed25519Service: ed25519,
        bmkgService: DioBmkgWeatherService(database: db),
        notificationService: _NoopNotificationService(),
      );
      final school = SchoolProfile(
        id: sdn1Id,
        ownerUserId: schoolUser.id,
        sppgId: sppgId,
        npsn: '20301901',
        name: 'SDN 1 Purwokerto',
        adm4Code: '33.02.26.1001',
        lat: -7.4188,
        lng: 109.2351,
        puskesmasWa: '628112800001',
        verificationStatus: SchoolVerificationStatus.approved,
        partnerKitchenName: 'SPPG Purwokerto Utara',
        partnerPublicKey: v1.publicKeyB64,
      );

      final res = await schoolRepo.verifyQrPayloadOffline(
        rawQrText: qrV2.toMinifiedJson(),
        school: school,
        isOffline: true,
      );
      expect(res.outcome, QrVerificationOutcome.missingPublicKey);
      expect(res.errorTitle, contains('Perlu Diperbarui'));
    },
  );

  testWidgets(
    'Edge Case #4: School clock skew (>5m behind kitchen) sets hasClockSkew and renders warning banner on G02',
    (tester) async {
      final sealedAt = DateTime.utc(2026, 11, 28, 4, 0);
      final skewedScanAt = DateTime.utc(2026, 11, 28, 3, 35); // 25m behind
      final eval = DangerZoneCalculator.evaluate(
        riskCategory: FoodRiskCategory.high,
        sealedAtUtc: sealedAt,
        scanAtUtc: skewedScanAt,
        temperatureC: 29.0,
      );
      expect(eval.hasClockSkew, isTrue);
      expect(eval.rawElapsedMinutes, -25);
      expect(eval.elapsedMinutes, 0);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final scanCtx = VerifiedBatchScanContext(
        payload: BatchQrPayload(
          batchId: 'batch-skew-1',
          batchCode: 'BCH-SKW-01',
          sppgId: sppgId,
          menuName: 'Nasi Ayam Kuah Santan',
          riskCategory: 'HIGH',
          sealedAtEpochSec: sealedAt.millisecondsSinceEpoch ~/ 1000,
          timestampSource: 'server_verified',
          signatureB64: 'sig',
        ),
        riskCategory: FoodRiskCategory.high,
        timestampSource: BatchTimestampSource.serverVerified,
        sealedAtUtc: sealedAt,
        scannedAtUtc: skewedScanAt,
        sppgName: 'SPPG Purwokerto Utara',
        sppgPublicKeyB64: 'pub',
        weather: BmkgWeatherReading(
          adm4Code: '33.02.26.1001',
          temperatureC: 29.0,
          source: BmkgSource.live,
          observedAtUtc: skewedScanAt,
        ),
        dangerEvaluation: eval,
        gpsWithinRadius: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
            isOfflineProvider.overrideWith((ref) => Stream.value(false)),
            batchSupplyChainTimelineProvider.overrideWith(
              (ref, arg) async => SupplyChainTimelineData(
                batchId: arg.batchId,
                sealedAtUtc: arg.sealedAtUtc,
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.30),
              ),
              child: child!,
            ),
            home: DangerZoneGateScreen(scanContext: scanCtx),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Jam HP Tidak Sinkron dengan Waktu Dapur'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Bug #2: AnomalyReportScreen allows 6-48h post-consumption KLB (across midnight WIB) and blocks >48h batches',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final school = SchoolProfile(
        id: sdn1Id,
        ownerUserId: schoolUser.id,
        sppgId: sppgId,
        npsn: '20301901',
        name: 'SDN 1 Purwokerto',
        adm4Code: '33.02.26.1001',
        lat: -7.4188,
        lng: 109.2351,
        puskesmasWa: '628112800001',
        verificationStatus: SchoolVerificationStatus.approved,
        partnerKitchenName: 'SPPG Purwokerto Utara',
      );

      final nowUtc = DateTime.now().toUtc();
      final args22hAgo = AnomalyHandoffArgs(
        batchId: 'batch-22h',
        batchCode: 'BCH-22H-01',
        menuName: 'Nasi Soto Ayam Santan',
        inspectionId: 'insp-22h',
        sppgId: sppgId,
        sppgName: 'SPPG Purwokerto Utara',
        sealedAtUtc: nowUtc.subtract(const Duration(hours: 23)),
        scannedAtUtc: nowUtc.subtract(const Duration(hours: 22)),
        dangerStatus: DangerZoneStatus.green,
        elapsedMinutes: 60,
        bmkgTempC: 30.0,
        reasonSummary: 'Gejala mual muncul keesokan pagi.',
        initialStage: ClusterAlertStage.postConsumption,
        sampleLabelCode: 'SMP-22H-01',
      );

      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
            isOfflineProvider.overrideWith((ref) => Stream.value(false)),
            authControllerProvider.overrideWith(
              () => _FixedAuthController(
                AuthState(
                  status: AuthStatus.authenticated,
                  profile: schoolUser,
                  school: school,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: AnomalyReportScreen(args: args22hAgo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Akses Pelaporan Terkunci'), findsNothing);
      expect(
        find.text('LAPORAN DUGAAN KLB PASCA-KONSUMSI'),
        findsOneWidget,
      );

      // Batch > 48 hours old MUST still be blocked.
      final args55hAgo = AnomalyHandoffArgs(
        batchId: 'batch-55h',
        batchCode: 'BCH-55H-01',
        menuName: 'Nasi Lama',
        inspectionId: 'insp-55h',
        sppgId: sppgId,
        sppgName: 'SPPG Purwokerto Utara',
        sealedAtUtc: nowUtc.subtract(const Duration(hours: 56)),
        scannedAtUtc: nowUtc.subtract(const Duration(hours: 55)),
        dangerStatus: DangerZoneStatus.green,
        elapsedMinutes: 60,
        bmkgTempC: 30.0,
        reasonSummary: 'Batch lama.',
      );

      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
            isOfflineProvider.overrideWith((ref) => Stream.value(false)),
            authControllerProvider.overrideWith(
              () => _FixedAuthController(
                AuthState(
                  status: AuthStatus.authenticated,
                  profile: schoolUser,
                  school: school,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: AnomalyReportScreen(args: args55hAgo),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Akses Pelaporan Terkunci'), findsOneWidget);
    },
  );

  testWidgets(
    'Edge Case #8: CreateBatchScreen suggests missing allergen tags from menu name and applies them in 1 tap',
    (tester) async {
      final inferred = AllergenTag.inferLikelyTagsFromMenuName(
        'Nasi Telur Balado, Tahu Bacem & Susu UHT',
      );
      expect(
        inferred,
        containsAll([
          AllergenTag.telur,
          AllergenTag.kedelai,
          AllergenTag.susuLaktosa,
        ]),
      );

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      tester.view.physicalSize = const Size(360, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const kitchen = KitchenProfile(
        id: sppgId,
        ownerUserId: '10000000-0000-4000-8000-000000000001',
        regNumber: 'BGN-PWT-2026-001',
        inviteCode: 'SPPG-PWT-01',
        name: 'SPPG Purwokerto Utara',
        adm4Code: '33.02.26.1001',
        lat: -7.4126,
        lng: 109.2345,
        publicKey: 'pub',
        isVerified: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
            isOfflineProvider.overrideWith((ref) => Stream.value(false)),
            authControllerProvider.overrideWith(
              () => _FixedAuthController(
                const AuthState(
                  status: AuthStatus.authenticated,
                  profile: kitchenAdmin,
                  kitchen: kitchen,
                  institutionRole: InstitutionMemberRole.admin,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const CreateBatchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'Nasi Telur Dadar & Ikan Goreng',
      );
      await tester.pumpAndSettle();

      final applyBtn = find.text('Terapkan Tag Disarankan');
      await tester.ensureVisible(applyBtn);
      expect(find.text('Saran Tag Alergen dari Nama Menu'), findsOneWidget);
      await tester.tap(applyBtn);
      await tester.pumpAndSettle();

      expect(find.text('Saran Tag Alergen dari Nama Menu'), findsNothing);
    },
  );

  testWidgets(
    'Bug #5 & #10b: Courier receives O01 alerts & offline-missed clarifiedSafe shows once then persists seen state',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      const kitchen = KitchenProfile(
        id: sppgId,
        ownerUserId: '10000000-0000-4000-8000-000000000001',
        regNumber: 'BGN-PWT-2026-001',
        inviteCode: 'SPPG-PWT-01',
        name: 'SPPG Purwokerto Utara',
        adm4Code: '33.02.26.1001',
        lat: -7.4126,
        lng: 109.2345,
        publicKey: 'pub',
        isVerified: true,
      );

      final clarifiedEvent = ClusterAlertEvent(
        id: 'alert-clar-1',
        sppgId: sppgId,
        sppgName: kitchen.name,
        batchId: 'batch-clar-1',
        batchCode: 'BCH-CLR-01',
        menuName: 'Nasi Ayam Kecap',
        reporterSchoolId: sdn1Id,
        reporterSchoolName: 'SDN 1 Purwokerto',
        stage: ClusterAlertStage.preConsumption,
        symptomCount: 0,
        broadcastEnabled: true,
        pdfDispatched: true,
        createdAtUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 30)),
        resolutionStatus: AlertResolutionStatus.clarifiedSafe,
        resolutionNote: 'Hanya 1 ompreng tumpah di kontainer, batch lain aman.',
        resolvedByName: 'Ibu Ratna (Admin SPPG)',
        resolvedAtUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      );

      final fakeAlertRepo = _FakeClusterAlertRepo(
        initialToday: [clarifiedEvent],
      );
      final fakeFcm = _FakeFcmService();
      addTearDown(fakeAlertRepo.dispose);
      addTearDown(fakeFcm.dispose);

      // 1st session: Courier reopens app after offline clarification -> sees O01 + Courier button!
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
            isOfflineProvider.overrideWith((ref) => Stream.value(false)),
            clusterAlertRepositoryProvider.overrideWithValue(fakeAlertRepo),
            fcmAlertServiceProvider.overrideWithValue(fakeFcm),
            authControllerProvider.overrideWith(
              () => _FixedAuthController(
                const AuthState(
                  status: AuthStatus.authenticated,
                  profile: courierUser,
                  kitchen: kitchen,
                  institutionRole: InstitutionMemberRole.courier,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const GlobalEmergencySyncHost(
              child: Scaffold(body: Center(child: Text('Beranda Uji'))),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PEMBARUAN STATUS DARURAT'), findsOneWidget);
      expect(find.text('Buka Daftar Pengantaran'), findsOneWidget);

      final okBtn = find.text('Saya Mengerti & Lanjutkan Distribusi');
      await tester.ensureVisible(okBtn);
      await tester.tap(okBtn);
      await tester.pumpAndSettle();
      expect(find.text('PEMBARUAN STATUS DARURAT'), findsNothing);

      // 2nd session: Re-opening app with same prefs does NOT nag with already-seen clarification!
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
            isOfflineProvider.overrideWith((ref) => Stream.value(false)),
            clusterAlertRepositoryProvider.overrideWithValue(fakeAlertRepo),
            fcmAlertServiceProvider.overrideWithValue(fakeFcm),
            authControllerProvider.overrideWith(
              () => _FixedAuthController(
                const AuthState(
                  status: AuthStatus.authenticated,
                  profile: courierUser,
                  kitchen: kitchen,
                  institutionRole: InstitutionMemberRole.courier,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const GlobalEmergencySyncHost(
              child: Scaffold(body: Center(child: Text('Beranda Uji'))),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PEMBARUAN STATUS DARURAT'), findsNothing);
    },
  );

  test(
    'Bug #6 & #9: OfflineSyncController replays team_security for Kitchen Admin, isolates Courier sync, and Kitchen preserves allergenTags offline',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      const kitchen = KitchenProfile(
        id: sppgId,
        ownerUserId: '10000000-0000-4000-8000-000000000001',
        regNumber: 'BGN-PWT-2026-001',
        inviteCode: 'SPPG-PWT-01',
        name: 'SPPG Purwokerto Utara',
        adm4Code: '33.02.26.1001',
        lat: -7.4126,
        lng: 109.2345,
        publicKey: 'pub',
        isVerified: true,
      );

      // A. Kitchen Admin sync replays teamSecurityRepositoryProvider!
      final spyKitchen1 = _SpyKitchenRepo();
      final spyTeam1 = _SpyTeamSecurityRepo();
      final spyTrace1 = _SpyTraceabilityRepo();
      final spyAlert1 = _FakeClusterAlertRepo();
      addTearDown(spyAlert1.dispose);

      final containerAdmin = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
          pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
          isOfflineProvider.overrideWith((ref) => Stream.value(false)),
          kitchenRepositoryProvider.overrideWithValue(spyKitchen1),
          teamSecurityRepositoryProvider.overrideWithValue(spyTeam1),
          traceabilityRepositoryProvider.overrideWithValue(spyTrace1),
          clusterAlertRepositoryProvider.overrideWithValue(spyAlert1),
          authControllerProvider.overrideWith(
            () => _FixedAuthController(
              const AuthState(
                status: AuthStatus.authenticated,
                profile: kitchenAdmin,
                kitchen: kitchen,
                institutionRole: InstitutionMemberRole.admin,
              ),
            ),
          ),
        ],
      );
      addTearDown(containerAdmin.dispose);

      await containerAdmin
          .read(offlineSyncControllerProvider.notifier)
          .syncNowWithReport();
      expect(spyKitchen1.syncCalls, 1);
      expect(spyTeam1.syncCalls, 1);
      expect(spyTrace1.syncCalls, 1);
      expect(spyTrace1.lastSyncedOpTypes, isNull);

      // B. Courier sync ONLY replays upsert_transit_handover (never kitchen batches or team keys!).
      final spyKitchen2 = _SpyKitchenRepo();
      final spyTeam2 = _SpyTeamSecurityRepo();
      final spyTrace2 = _SpyTraceabilityRepo();
      final containerCourier = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
          pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
          isOfflineProvider.overrideWith((ref) => Stream.value(false)),
          kitchenRepositoryProvider.overrideWithValue(spyKitchen2),
          teamSecurityRepositoryProvider.overrideWithValue(spyTeam2),
          traceabilityRepositoryProvider.overrideWithValue(spyTrace2),
          clusterAlertRepositoryProvider.overrideWithValue(spyAlert1),
          authControllerProvider.overrideWith(
            () => _FixedAuthController(
              const AuthState(
                status: AuthStatus.authenticated,
                profile: courierUser,
                kitchen: kitchen,
                institutionRole: InstitutionMemberRole.courier,
              ),
            ),
          ),
        ],
      );
      addTearDown(containerCourier.dispose);

      await containerCourier
          .read(offlineSyncControllerProvider.notifier)
          .syncNowWithReport();
      expect(spyKitchen2.syncCalls, 0);
      expect(spyTeam2.syncCalls, 0);
      expect(spyTrace2.syncCalls, 1);
      expect(spyTrace2.lastSyncedOpTypes, const {'upsert_transit_handover'});

      // C. Kitchen offline createBatch preserves allergenTags cleanly!
      final ed25519 = Ed25519Service(secureStore: _MemorySecureKeyStore());
      final kitchenRepo = SupabaseKitchenRepository(
        client: null,
        database: db,
        ed25519Service: ed25519,
      );
      final created = await kitchenRepo.createSealedBatch(
        kitchen: kitchen,
        menuName: 'Nasi Telur & Tahu',
        portionCount: 120,
        riskCategory: FoodRiskCategory.medium,
        allergenTags: const ['telur', 'kedelai'],
        photo: CapturedWebpPhoto(
          filePath: 'dummy.webp',
          bytes: Uint8List.fromList([1, 2, 3]),
          sizeBytes: 3,
        ),
        isOffline: true,
      );
      expect(created.allergenTags, const ['kedelai', 'telur']);
      expect(created.qrPayload.allergenTags, const ['kedelai', 'telur']);
    },
  );
}
