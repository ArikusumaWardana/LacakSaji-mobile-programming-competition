import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
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
import 'package:lacak_saji/core/network/bmkg_weather_service.dart';
import 'package:lacak_saji/core/network/connectivity_provider.dart';
import 'package:lacak_saji/core/notifications/local_notification_service.dart';
import 'package:lacak_saji/core/sensors/ble_thermometer_service.dart';
import 'package:lacak_saji/core/theme/app_theme.dart';
import 'package:lacak_saji/core/theme/text_scale_provider.dart';
import 'package:lacak_saji/core/widgets/lacak_cluster_alert_overlay.dart';
import 'package:lacak_saji/features/alerts/data/cluster_alert_repository.dart';
import 'package:lacak_saji/features/alerts/domain/cluster_alert_models.dart';
import 'package:lacak_saji/features/alerts/presentation/cluster_alert_controller.dart';
import 'package:lacak_saji/features/allergens/data/allergen_repository.dart';
import 'package:lacak_saji/features/allergens/domain/allergen_models.dart';
import 'package:lacak_saji/features/allergens/presentation/allergen_providers.dart';
import 'package:lacak_saji/features/allergens/presentation/widgets/school_allergen_profile_sheet.dart';
import 'package:lacak_saji/features/auth/domain/auth_models.dart';
import 'package:lacak_saji/features/auth/presentation/auth_controller.dart';
import 'package:lacak_saji/features/kitchen/domain/kitchen_models.dart';
import 'package:lacak_saji/features/kitchen/presentation/create_batch_screen.dart';
import 'package:lacak_saji/features/school/data/school_repository.dart';
import 'package:lacak_saji/features/school/domain/danger_zone_calculator.dart';
import 'package:lacak_saji/features/school/domain/school_models.dart';
import 'package:lacak_saji/features/school/presentation/danger_zone_gate_screen.dart';
import 'package:lacak_saji/features/settings/presentation/settings_screen.dart';
import 'package:lacak_saji/features/traceability/domain/traceability_models.dart';
import 'package:lacak_saji/features/traceability/presentation/traceability_providers.dart';

class _MemoryKeyStore implements SecureKeyStore {
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

class _FakeBmkgService implements BmkgWeatherService {
  @override
  Future<BmkgWeatherReading> getCurrentWeather({
    required String adm4Code,
    required bool isOffline,
    bool forceRefresh = false,
  }) async {
    return BmkgWeatherReading(
      adm4Code: adm4Code,
      temperatureC: 27.0,
      source: BmkgSource.fallbackOffline,
      observedAtUtc: DateTime.utc(2026, 11, 24, 3, 0),
    );
  }
}

class _FakeNotificationService implements LocalNotificationService {
  @override
  Future<void> cancelSampleVaultReminder(String sampleId) async {}

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
  Future<void> showClusterAlertNotification(ClusterAlertEvent event) async {}
}

class _FakeClusterAlertRepo extends Fake implements ClusterAlertRepository {
  final List<ClusterAlertEvent> resolvedCalls = [];
  final Set<String> acknowledgedIds = {};

  @override
  Future<List<ClusterAlertEvent>> fetchUnacknowledgedAlertsForToday({
    required String sppgId,
    String? currentSchoolId,
  }) async {
    return const [];
  }

  @override
  Stream<ClusterAlertEvent> watchRealtimeAlerts({
    required String sppgId,
    String? excludeSchoolId,
  }) {
    return const Stream<ClusterAlertEvent>.empty();
  }

  @override
  Future<void> acknowledgeAlert({
    required String alertId,
    required String schoolId,
    required bool isOffline,
  }) async {
    acknowledgedIds.add(alertId);
  }

  @override
  Future<ClusterAlertEvent> resolveClusterAlert({
    required ClusterAlertEvent alert,
    required AlertResolutionStatus newStatus,
    required String resolutionNote,
    required String resolverUserId,
    required String resolverName,
    required bool isOffline,
  }) async {
    final updated = alert.copyWith(
      resolutionStatus: newStatus,
      resolutionNote: resolutionNote,
      resolvedByUserId: resolverUserId,
      resolvedByName: resolverName,
      resolvedAtUtc: DateTime.utc(2026, 11, 24, 5, 15),
    );
    resolvedCalls.add(updated);
    return updated;
  }

  @override
  Future<int> syncPendingAlerts({String? schoolId, String? kitchenId}) async =>
      0;
}

class _OfflineBleService implements BleThermometerService {
  @override
  Future<BleThermometerAvailability> checkAvailability() async {
    return const BleThermometerAvailability(
      status: BleSensorStatus.bluetoothOff,
      detail: 'Bluetooth mati di perangkat ini. Gunakan Termometer Manual.',
      canScan: false,
    );
  }

  @override
  Future<BleTemperatureReading?> readContainerTemperature() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  const kitchen = KitchenProfile(
    id: '11111111-1111-1111-1111-111111111111',
    ownerUserId: '22222222-2222-2222-2222-222222222222',
    regNumber: 'BGN-SBX-2026-101',
    inviteCode: 'SPPG-PWT-01',
    name: 'SPPG Purwokerto Utara',
    adm4Code: '33.02.26.1001',
    lat: -7.4126,
    lng: 109.2345,
    publicKey: 'ZmFrZV9wdWJsaWNfa2V5',
    isVerified: true,
  );

  const school = SchoolProfile(
    id: '33333333-3333-3333-3333-333333333333',
    ownerUserId: '44444444-4444-4444-4444-444444444444',
    sppgId: '11111111-1111-1111-1111-111111111111',
    npsn: '20302001',
    name: 'SDN 1 Purwokerto',
    adm4Code: '33.02.26.1001',
    lat: -7.4130,
    lng: 109.2350,
    puskesmasWa: '081234567890',
    verificationStatus: SchoolVerificationStatus.approved,
    partnerKitchenName: 'SPPG Purwokerto Utara',
    partnerInviteCode: 'SPPG-PWT-01',
  );

  const adminUser = UserProfile(
    id: '22222222-2222-2222-2222-222222222222',
    email: 'admin@sppg.id',
    role: UserRole.kitchen,
    fullName: 'Kepala SPPG Purwokerto',
  );

  const staffUser = UserProfile(
    id: '22222222-2222-2222-2222-222222222999',
    email: 'staff@sppg.id',
    role: UserRole.kitchen,
    fullName: 'Staf Dapur',
  );

  const schoolReporterUser = UserProfile(
    id: '44444444-4444-4444-4444-444444444444',
    email: 'sdn1@school.id',
    role: UserRole.school,
    fullName: 'Ibu Guru Rina',
  );

  const peerSchool = SchoolProfile(
    id: '77777777-7777-7777-7777-777777777777',
    ownerUserId: '88888888-8888-8888-8888-888888888888',
    sppgId: '11111111-1111-1111-1111-111111111111',
    npsn: '20302009',
    name: 'SDN 9 Purwokerto',
    adm4Code: '33.02.26.1001',
    lat: -7.4140,
    lng: 109.2360,
    puskesmasWa: '081234567899',
    verificationStatus: SchoolVerificationStatus.approved,
  );

  const peerUser = UserProfile(
    id: '88888888-8888-8888-8888-888888888888',
    email: 'sdn9@school.id',
    role: UserRole.school,
    fullName: 'Pak Budi',
  );

  test(
    'QR v1/v2/v3 compatibility + Ed25519 allergen tamper rejection + offline Drift match',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final ed25519 = Ed25519Service(secureStore: _MemoryKeyStore());
      final sealedAt = DateTime.utc(2026, 11, 24, 1, 0);
      final sealedEpoch = sealedAt.millisecondsSinceEpoch ~/ 1000;

      // 1. Legacy v1 payload (no key_id, no alg) remains valid.
      final v1Canonical = BatchQrPayload.buildCanonicalSigningString(
        batchId: 'batch-v1',
        batchCode: 'BCH-V1',
        sppgId: kitchen.id,
        menuName: 'Nasi Ayam',
        riskCategory: 'MEDIUM',
        sealedAtEpochSec: sealedEpoch,
        timestampSource: 'server_verified',
      );
      final pubKey = await ed25519.getOrCreatePublicKeyB64(sppgId: kitchen.id);
      final v1Sig = await ed25519.signCanonicalPayload(
        sppgId: kitchen.id,
        canonicalData: v1Canonical,
      );
      final v1Json = jsonEncode({
        'batch_id': 'batch-v1',
        'batch_code': 'BCH-V1',
        'sppg_id': kitchen.id,
        'menu_name': 'Nasi Ayam',
        'risk_category': 'MEDIUM',
        'sealed_at': sealedEpoch,
        'timestamp_source': 'server_verified',
        'sig': v1Sig,
      });
      final parsedV1 = BatchQrPayload.tryParse(v1Json);
      expect(parsedV1, isNotNull);
      expect(parsedV1!.keyId, isNull);
      expect(parsedV1.allergenTags, isEmpty);
      expect(
        await ed25519.verifyCanonicalPayload(
          canonicalData: parsedV1.toCanonicalSigningString(),
          signatureB64: parsedV1.signatureB64,
          publicKeyB64: pubKey,
        ),
        isTrue,
      );

      // 2. v3 payload (with key_id + allergen tags) signs & verifies offline, detects tamper.
      final signedV3 = await ed25519.signBatchWithKeyId(
        sppgId: kitchen.id,
        buildCanonicalForKeyId: (kid) => BatchQrPayload.buildCanonicalSigningString(
          batchId: 'batch-v3',
          batchCode: 'BCH-V3',
          sppgId: kitchen.id,
          menuName: 'Telur Balado & Tempe',
          riskCategory: 'HIGH',
          sealedAtEpochSec: sealedEpoch,
          timestampSource: 'server_verified',
          keyId: kid,
          allergenTags: const ['kedelai', 'telur'],
        ),
      );
      final v3Payload = BatchQrPayload(
        batchId: 'batch-v3',
        batchCode: 'BCH-V3',
        sppgId: kitchen.id,
        menuName: 'Telur Balado & Tempe',
        riskCategory: 'HIGH',
        sealedAtEpochSec: sealedEpoch,
        timestampSource: 'server_verified',
        keyId: signedV3.keyId,
        allergenTags: const ['telur', 'kedelai'],
        signatureB64: signedV3.signatureB64,
      );
      final v3Json = v3Payload.toMinifiedJson();
      final decodedV3 = Map<String, dynamic>.from(jsonDecode(v3Json) as Map);
      // Deterministically sorted canonical tags.
      expect(decodedV3['alg'], ['kedelai', 'telur']);
      decodedV3['alg'] = ['kacang'];
      final tamperedV3 = BatchQrPayload.tryParse(jsonEncode(decodedV3))!;
      expect(
        await ed25519.verifyCanonicalPayload(
          canonicalData: tamperedV3.toCanonicalSigningString(),
          signatureB64: tamperedV3.signatureB64,
          publicKeyB64: signedV3.publicKeyB64,
        ),
        isFalse,
      );

      // 3. Offline verification matches Drift LocalSchoolAllergens (zero PII).
      await db.upsertSppgKey(
        LocalSppgKeysCompanion(
          sppgId: Value(kitchen.id),
          sppgName: Value(kitchen.name),
          inviteCode: Value(kitchen.inviteCode),
          publicKeyB64: Value(signedV3.publicKeyB64),
          updatedAt: Value(DateTime.utc(2026, 11, 24)),
        ),
      );
      await db.replaceSchoolAllergens(
        schoolId: school.id,
        entries: [
          LocalSchoolAllergensCompanion(
            id: const Value('alg-1'),
            schoolId: Value(school.id),
            allergenTag: const Value('telur'),
            studentCount: const Value(4),
            severityLevel: const Value('severe'),
            handlingNote: const Value('Siapkan menu substitusi ayam.'),
            updatedAt: Value(DateTime.utc(2026, 11, 24)),
          ),
          LocalSchoolAllergensCompanion(
            id: const Value('alg-2'),
            schoolId: Value(school.id),
            allergenTag: const Value('kacang'),
            studentCount: const Value(2),
            severityLevel: const Value('moderate'),
            updatedAt: Value(DateTime.utc(2026, 11, 24)),
          ),
        ],
      );

      final schoolRepo = SupabaseSchoolRepository(
        client: null,
        database: db,
        ed25519Service: ed25519,
        bmkgService: _FakeBmkgService(),
        notificationService: _FakeNotificationService(),
        locationReader: () async => (lat: school.lat, lng: school.lng),
        clockUtc: () => sealedAt.add(const Duration(minutes: 45)),
      );
      final verifyRes = await schoolRepo.verifyQrPayloadOffline(
        rawQrText: v3Json,
        school: school,
        isOffline: true,
      );
      expect(verifyRes.isValid, isTrue);
      expect(verifyRes.context!.payload.allergenTags, ['kedelai', 'telur']);
      expect(verifyRes.context!.matchedAllergens.length, 1);
      expect(
        verifyRes.context!.matchedAllergens.first.allergen,
        AllergenTag.telur,
      );
      expect(verifyRes.context!.matchedAllergens.first.studentCount, 4);
    },
  );

  test(
    'Danger-Zone priority (Actual Temp vs BMKG) + BleThermometerService safe defaults',
    () async {
      final sealedAt = DateTime.utc(2026, 11, 24, 1, 0);
      final scanAt = sealedAt.add(const Duration(minutes: 100));

      // Default BMKG at 27.0 C for HIGH risk @ 100 min -> GREEN (safeLimit 120m).
      final bmkgEval = DangerZoneCalculator.evaluate(
        riskCategory: FoodRiskCategory.high,
        sealedAtUtc: sealedAt,
        scanAtUtc: scanAt,
        temperatureC: 27.0,
      );
      expect(bmkgEval.tempSource, FoodTemperatureSource.bmkgEstimate);
      expect(bmkgEval.status, DangerZoneStatus.green);
      expect(bmkgEval.isHotWeather, isFalse);

      // Manual thermometer at 34.0 C overrides cool BMKG (27.0 C) -> tightens to hot matrix (90/120m) -> YELLOW!
      final lukewarmOverride = DangerZoneCalculator.evaluate(
        riskCategory: FoodRiskCategory.high,
        sealedAtUtc: sealedAt,
        scanAtUtc: scanAt,
        temperatureC: 27.0,
        actualTempC: 34.0,
        tempSource: FoodTemperatureSource.manualThermometer,
      );
      expect(
        lukewarmOverride.tempSource,
        FoodTemperatureSource.manualThermometer,
      );
      expect(lukewarmOverride.isHotWeather, isTrue);
      expect(lukewarmOverride.status, DangerZoneStatus.yellow);

      // Hot holding at >= 60.0 C overrides high temperature -> controlled holding GREEN!
      final hotHolding = DangerZoneCalculator.evaluate(
        riskCategory: FoodRiskCategory.high,
        sealedAtUtc: sealedAt,
        scanAtUtc: scanAt,
        temperatureC: 34.0,
        actualTempC: 63.5,
        tempSource: FoodTemperatureSource.bleSensor,
      );
      expect(hotHolding.tempSource, FoodTemperatureSource.bleSensor);
      expect(hotHolding.isControlledHoldingTemp, isTrue);
      expect(hotHolding.status, DangerZoneStatus.green);

      // ReadyState & Offline BLE services never crash.
      final readyBle = ReadyStateBleThermometerService();
      final readyInfo = await readyBle.checkAvailability();
      expect(readyInfo.status, BleSensorStatus.ready);
      expect(await readyBle.readContainerTemperature(), isNull);

      final offBle = _OfflineBleService();
      final offInfo = await offBle.checkAvailability();
      expect(offInfo.status, BleSensorStatus.bluetoothOff);
      expect(offInfo.canScan, isFalse);
      expect(await offBle.readContainerTemperature(), isNull);
    },
  );

  test(
    'Alert resolution state machine, RBAC, and ClusterAlertController peer transformation',
    () async {
      // State machine transitions.
      expect(
        AlertResolutionStatus.active.canTransitionTo(
          AlertResolutionStatus.clarifiedSafe,
        ),
        isTrue,
      );
      expect(
        AlertResolutionStatus.active.canTransitionTo(
          AlertResolutionStatus.confirmedKlb,
        ),
        isTrue,
      );
      expect(
        AlertResolutionStatus.clarifiedSafe.canTransitionTo(
          AlertResolutionStatus.confirmedKlb,
        ),
        isTrue,
      );
      expect(
        AlertResolutionStatus.clarifiedSafe.canTransitionTo(
          AlertResolutionStatus.active,
        ),
        isFalse,
      );
      expect(
        AlertResolutionStatus.confirmedKlb.canTransitionTo(
          AlertResolutionStatus.clarifiedSafe,
        ),
        isFalse,
      );

      // RBAC checks: Admin SPPG allowed, non-admin staff denied, Reporter School allowed, Peer School denied.
      const adminAuth = AuthState(
        status: AuthStatus.authenticated,
        profile: adminUser,
        kitchen: kitchen,
        institutionRole: InstitutionMemberRole.admin,
      );
      const staffAuth = AuthState(
        status: AuthStatus.authenticated,
        profile: staffUser,
        kitchen: kitchen,
        institutionRole: InstitutionMemberRole.staff,
      );
      const reporterAuth = AuthState(
        status: AuthStatus.authenticated,
        profile: schoolReporterUser,
        school: school,
      );
      const peerAuth = AuthState(
        status: AuthStatus.authenticated,
        profile: peerUser,
        school: peerSchool,
      );

      expect(
        canResolveClusterAlert(
          auth: adminAuth,
          sppgId: kitchen.id,
          reporterSchoolId: school.id,
        ),
        isTrue,
      );
      expect(
        canResolveClusterAlert(
          auth: staffAuth,
          sppgId: kitchen.id,
          reporterSchoolId: school.id,
        ),
        isFalse,
      );
      expect(
        canResolveClusterAlert(
          auth: reporterAuth,
          sppgId: kitchen.id,
          reporterSchoolId: school.id,
        ),
        isTrue,
      );
      expect(
        canResolveClusterAlert(
          auth: peerAuth,
          sppgId: kitchen.id,
          reporterSchoolId: school.id,
        ),
        isFalse,
      );

      // Peer school controller receives active alarm -> acknowledges -> receives clarified_safe Realtime UPDATE -> re-surfaces immediately!
      final fakeRepo = _FakeClusterAlertRepo();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FixedAuthController(peerAuth),
          ),
          clusterAlertRepositoryProvider.overrideWithValue(fakeRepo),
          isOfflineProvider.overrideWith((ref) => Stream.value(false)),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(clusterAlertControllerProvider.notifier);
      final activeAlert = ClusterAlertEvent(
        id: 'alert-001',
        sppgId: kitchen.id,
        sppgName: kitchen.name,
        batchId: 'batch-1',
        batchCode: 'BCH-01',
        menuName: 'Nasi Ayam',
        reporterSchoolId: school.id,
        reporterSchoolName: school.name,
        stage: ClusterAlertStage.preConsumption,
        symptomCount: 0,
        broadcastEnabled: true,
        createdAtUtc: DateTime.utc(2026, 11, 24, 4, 0),
      );
      controller.enqueueIncomingAlert(activeAlert);
      expect(container.read(clusterAlertControllerProvider).activeAlert?.id, 'alert-001');

      await controller.acknowledgeActiveAlert();
      expect(container.read(clusterAlertControllerProvider).activeAlert, isNull);

      final clarifiedRealtime = activeAlert.copyWith(
        resolutionStatus: AlertResolutionStatus.clarifiedSafe,
        resolutionNote: 'Hanya 1 ompreng jatuh di pintu mobil, ompreng lain tersegel aman.',
        resolvedByName: 'Kepala SPPG Purwokerto',
        resolvedAtUtc: DateTime.utc(2026, 11, 24, 4, 20),
      );
      controller.enqueueIncomingAlert(clarifiedRealtime);
      final stateAfterUpdate = container.read(clusterAlertControllerProvider);
      expect(
        stateAfterUpdate.activeAlert?.resolutionStatus,
        AlertResolutionStatus.clarifiedSafe,
      );
      expect(
        stateAfterUpdate.activeAlert?.resolvedByName,
        'Kepala SPPG Purwokerto',
      );
    },
  );

  testWidgets(
    'Phase 3 UI responsiveness at 320dp + 1.30x Ekstra Besar text scale across D02, C01, G03, and O01',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.binding.setSurfaceSize(const Size(320, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final errors = <FlutterErrorDetails>[];
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        oldOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldOnError);

      Widget wrapMobileScreen(
        Widget child, {
        required List overrides,
        Key? scopeKey,
      }) {
        return ProviderScope(
          key: scopeKey ?? UniqueKey(),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
            ...overrides.cast(),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, home) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.30),
              ),
              child: home!,
            ),
            home: child,
          ),
        );
      }

      // 1. D02 CreateBatchScreen: 6 allergen chips + toggle selection.
      const kitchenAuth = AuthState(
        status: AuthStatus.authenticated,
        profile: adminUser,
        kitchen: kitchen,
        institutionRole: InstitutionMemberRole.admin,
      );
      await tester.pumpWidget(
        wrapMobileScreen(
          const CreateBatchScreen(),
          overrides: [
            authControllerProvider.overrideWith(
              () => _FixedAuthController(kitchenAuth),
            ),
            isOfflineProvider.overrideWith((ref) => Stream.value(true)),
            recentKitchenBatchesForLogProvider.overrideWith(
              (ref) async => const <FoodBatchItem>[],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      for (final tag in AllergenTag.values) {
        expect(find.text(tag.label), findsOneWidget);
      }
      final telurFinder = find.text('Telur');
      await tester.ensureVisible(telurFinder);
      await tester.tap(telurFinder);
      await tester.pump();

      // 2. C01 SettingsScreen (School) + SchoolAllergenProfileSheet.
      const schoolAuth = AuthState(
        status: AuthStatus.authenticated,
        profile: schoolReporterUser,
        school: school,
      );
      final allergenRepo = SupabaseAllergenRepository(
        client: null,
        database: db,
      );
      await tester.pumpWidget(
        wrapMobileScreen(
          const SettingsScreen(),
          overrides: [
            authControllerProvider.overrideWith(
              () => _FixedAuthController(schoolAuth),
            ),
            allergenRepositoryProvider.overrideWithValue(allergenRepo),
            schoolAllergensProvider.overrideWith(
              (ref) async => [
                const SchoolAllergenEntry(
                  id: 'alg-1',
                  schoolId: '33333333-3333-3333-3333-333333333333',
                  allergen: AllergenTag.telur,
                  studentCount: 3,
                  severity: AllergenSeverity.severe,
                ),
              ],
            ),
            isOfflineProvider.overrideWith((ref) => Stream.value(true)),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final allergenSettingFinder = find.text('Profil Alergen Siswa (Tanpa Nama)');
      await tester.ensureVisible(allergenSettingFinder);
      expect(allergenSettingFinder, findsOneWidget);

      await tester.pumpWidget(
        wrapMobileScreen(
          const Scaffold(
            body: SchoolAllergenProfileSheet(
              schoolId: '33333333-3333-3333-3333-333333333333',
              initialEntries: [],
            ),
          ),
          overrides: [
            authControllerProvider.overrideWith(
              () => _FixedAuthController(schoolAuth),
            ),
            allergenRepositoryProvider.overrideWithValue(allergenRepo),
            isOfflineProvider.overrideWith((ref) => Stream.value(true)),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Simpan Profil Alergen'), findsOneWidget);

      // 3. G03 DangerZoneGateScreen: Allergen banner below hero + manual temp live update + BLE ready mode.
      final sealedAt = DateTime.utc(2026, 11, 24, 1, 0);
      final scanAt = sealedAt.add(const Duration(minutes: 100));
      final scanContext = VerifiedBatchScanContext(
        payload: BatchQrPayload(
          batchId: 'batch-3',
          batchCode: 'BCH-003',
          sppgId: kitchen.id,
          menuName: 'Telur Balado & Tempe',
          riskCategory: 'HIGH',
          sealedAtEpochSec: sealedAt.millisecondsSinceEpoch ~/ 1000,
          timestampSource: 'server_verified',
          allergenTags: const ['telur', 'kedelai'],
          signatureB64: 'c2ln',
        ),
        riskCategory: FoodRiskCategory.high,
        timestampSource: BatchTimestampSource.serverVerified,
        sealedAtUtc: sealedAt,
        scannedAtUtc: scanAt,
        sppgName: kitchen.name,
        sppgPublicKeyB64: kitchen.publicKey,
        weather: BmkgWeatherReading(
          adm4Code: school.adm4Code,
          temperatureC: 27.0,
          source: BmkgSource.fallbackOffline,
          observedAtUtc: scanAt,
        ),
        dangerEvaluation: DangerZoneCalculator.evaluate(
          riskCategory: FoodRiskCategory.high,
          sealedAtUtc: sealedAt,
          scanAtUtc: scanAt,
          temperatureC: 27.0,
        ),
        gpsWithinRadius: true,
        matchedAllergens: const [
          SchoolAllergenEntry(
            id: 'alg-1',
            schoolId: '33333333-3333-3333-3333-333333333333',
            allergen: AllergenTag.telur,
            studentCount: 3,
            severity: AllergenSeverity.severe,
          ),
        ],
      );

      await tester.pumpWidget(
        wrapMobileScreen(
          DangerZoneGateScreen(scanContext: scanContext),
          overrides: [
            authControllerProvider.overrideWith(
              () => _FixedAuthController(schoolAuth),
            ),
            bleThermometerServiceProvider.overrideWithValue(
              _OfflineBleService(),
            ),
            batchSupplyChainTimelineProvider((
              sppgId: kitchen.id,
              batchId: 'batch-3',
              sealedAtUtc: sealedAt,
              schoolScannedAtUtc: scanAt,
            )).overrideWith(
              (ref) async => SupplyChainTimelineData(
                batchId: 'batch-3',
                sealedAtUtc: sealedAt,
                schoolScannedAtUtc: scanAt,
              ),
            ),
            schoolAllergensProvider.overrideWith(
              (ref) async => scanContext.matchedAllergens,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('PERINGATAN ALERGEN SISWA (3 SISWA TERDAMPAK)'),
        findsOneWidget,
      );
      expect(find.textContaining('Telur'), findsWidgets);
      expect(find.textContaining('WAKTU PENGIRIMAN AMAN'), findsOneWidget);

      final manualField = find.byType(TextField).first;
      await tester.ensureVisible(manualField);
      await tester.enterText(manualField, '35.0');
      await tester.pump();

      final applyTempButton = find.text('Terapkan Suhu Aktual');
      await tester.ensureVisible(applyTempButton);
      await tester.tap(applyTempButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('WASPADA: PERIKSA LEBIH KETAT'), findsOneWidget);
      expect(find.textContaining('Termometer Manual'), findsWidgets);

      final bleChip = find.text('Sensor BLE');
      await tester.ensureVisible(bleChip);
      await tester.tap(bleChip);
      await tester.pumpAndSettle();
      expect(find.text('Bluetooth Mati'), findsOneWidget);

      // 4. O01 LacakClusterAlertOverlay: active with resolution button + clarifiedSafe update UI.
      final fakeAlertRepo = _FakeClusterAlertRepo();
      final activeEvent = ClusterAlertEvent(
        id: 'alert-ui-1',
        sppgId: kitchen.id,
        sppgName: kitchen.name,
        batchId: 'batch-3',
        batchCode: 'BCH-003',
        menuName: 'Telur Balado',
        reporterSchoolId: school.id,
        reporterSchoolName: school.name,
        stage: ClusterAlertStage.preConsumption,
        symptomCount: 0,
        broadcastEnabled: true,
        createdAtUtc: DateTime.utc(2026, 11, 24, 4, 0),
      );
      await tester.pumpWidget(
        wrapMobileScreen(
          LacakClusterAlertOverlay(
            event: activeEvent,
            isAcknowledging: false,
          ),
          overrides: [
            authControllerProvider.overrideWith(
              () => _FixedAuthController(kitchenAuth),
            ),
            clusterAlertRepositoryProvider.overrideWithValue(fakeAlertRepo),
            isOfflineProvider.overrideWith((ref) => Stream.value(false)),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final resolveBtn = find.text('Klarifikasi / Ubah Status Darurat');
      await tester.ensureVisible(resolveBtn);
      expect(resolveBtn, findsOneWidget);
      await tester.tap(resolveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Langkah 1 dari 2 · Verifikasi Audit'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).last,
        'Hanya 1 wadah tumpah saat transit, seluruh wadah lainnya utuh dan aman.',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Lanjut ke Konfirmasi Akhir'));
      await tester.tap(find.text('Lanjut ke Konfirmasi Akhir'));
      await tester.pumpAndSettle();
      expect(find.text('Langkah 2 dari 2 · Verifikasi Audit'), findsOneWidget);

      // Render clarifiedSafe overlay directly as seen across peer schools on Realtime UPDATE.
      final clarifiedEvent = activeEvent.copyWith(
        resolutionStatus: AlertResolutionStatus.clarifiedSafe,
        resolutionNote: 'Hanya 1 wadah tumpah saat transit, seluruh wadah lainnya utuh.',
        resolvedByName: 'Kepala SPPG Purwokerto',
        resolvedAtUtc: DateTime.utc(2026, 11, 24, 4, 25),
      );
      await tester.pumpWidget(
        wrapMobileScreen(
          LacakClusterAlertOverlay(
            event: clarifiedEvent,
            isAcknowledging: false,
          ),
          overrides: [
            authControllerProvider.overrideWith(
              () => _FixedAuthController(schoolAuth),
            ),
            clusterAlertRepositoryProvider.overrideWithValue(fakeAlertRepo),
            isOfflineProvider.overrideWith((ref) => Stream.value(false)),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PEMBARUAN STATUS DARURAT'), findsOneWidget);
      expect(find.text('Distribusi Aman Dilanjutkan'), findsOneWidget);
      expect(find.text('Kepala SPPG Purwokerto'), findsOneWidget);

      expect(errors, isEmpty, reason: 'Unexpected Flutter errors/overflows: $errors');
    },
  );
}
