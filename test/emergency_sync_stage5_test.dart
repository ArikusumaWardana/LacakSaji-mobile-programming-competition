import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lacak_saji/core/constants/app_constants.dart';
import 'package:lacak_saji/core/constants/app_routes.dart';
import 'package:lacak_saji/core/database/app_database.dart';
import 'package:lacak_saji/core/database/database_provider.dart';
import 'package:lacak_saji/core/media/live_camera_webp_service.dart';
import 'package:lacak_saji/core/network/bmkg_weather_service.dart';
import 'package:lacak_saji/core/network/connectivity_provider.dart';
import 'package:lacak_saji/core/network/supabase_provider.dart';
import 'package:lacak_saji/core/notifications/fcm_alert_service.dart';
import 'package:lacak_saji/core/router/app_router.dart';
import 'package:lacak_saji/core/sync/workmanager_sync_dispatcher.dart';
import 'package:lacak_saji/core/theme/text_scale_provider.dart';
import 'package:lacak_saji/features/alerts/data/cluster_alert_repository.dart';
import 'package:lacak_saji/features/alerts/domain/cluster_alert_models.dart';
import 'package:lacak_saji/features/alerts/presentation/cluster_alert_controller.dart';
import 'package:lacak_saji/features/auth/data/auth_repository.dart';
import 'package:lacak_saji/features/auth/domain/auth_models.dart';
import 'package:lacak_saji/features/auth/presentation/auth_controller.dart';
import 'package:lacak_saji/features/kitchen/data/kitchen_repository.dart';
import 'package:lacak_saji/features/kitchen/domain/kitchen_models.dart';
import 'package:lacak_saji/features/kitchen/presentation/kitchen_providers.dart';
import 'package:lacak_saji/features/school/data/klb_pdf_service.dart';
import 'package:lacak_saji/features/school/data/school_repository.dart';
import 'package:lacak_saji/features/school/domain/danger_zone_calculator.dart';
import 'package:lacak_saji/features/school/domain/school_models.dart';
import 'package:lacak_saji/features/school/presentation/school_providers.dart';
import 'package:lacak_saji/main.dart';

final RegExp _emojiRegex = RegExp(
  r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]',
  unicode: true,
);

void _assertZeroSlopText(String text) {
  expect(text.contains('\u2014'), isFalse, reason: 'Em-dash forbidden: $text');
  expect(_emojiRegex.hasMatch(text), isFalse, reason: 'Emoji forbidden: $text');
}

const SchoolProfile _school1 = SchoolProfile(
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

const SchoolProfile _school2 = SchoolProfile(
  id: 'b1000000-0000-4000-8000-000000000002',
  ownerUserId: '20000000-0000-4000-8000-000000000002',
  sppgId: 'a1000000-0000-4000-8000-000000000001',
  npsn: '20301902',
  name: 'SDN 2 Purwokerto',
  adm4Code: '33.02.26.1003',
  lat: -7.4200,
  lng: 109.2400,
  puskesmasWa: '628112800002',
  verificationStatus: SchoolVerificationStatus.approved,
  partnerKitchenName: 'SPPG Purwokerto Utara',
  partnerInviteCode: 'SPPG-PWT-01',
);

const AuthSessionSnapshot _school1Session = AuthSessionSnapshot(
  profile: UserProfile(
    id: '20000000-0000-4000-8000-000000000001',
    email: 'sdn1.pwt@lacaksaji.id',
    role: UserRole.school,
    fullName: 'Ibu Siti (PIC SDN 1 Purwokerto)',
  ),
  school: _school1,
);

const AuthSessionSnapshot _school2Session = AuthSessionSnapshot(
  profile: UserProfile(
    id: '20000000-0000-4000-8000-000000000002',
    email: 'sdn2.pwt@lacaksaji.id',
    role: UserRole.school,
    fullName: 'Pak Budi (PIC SDN 2 Purwokerto)',
  ),
  school: _school2,
);

class _SpyBackgroundSyncScheduler implements BackgroundSyncScheduler {
  int initCount = 0;
  int scheduledCount = 0;

  @override
  Future<void> initialize() async {
    initCount++;
  }

  @override
  Future<void> scheduleImmediateConnectedSync() async {
    scheduledCount++;
  }
}

class _Stage5AuthRepository implements AuthRepository {
  _Stage5AuthRepository(this.session);

  AuthSessionSnapshot? session;

  @override
  Future<AuthSessionSnapshot?> restoreSession() async => session;

  @override
  Future<AuthSessionSnapshot?> refreshSession() async => session;

  @override
  Future<AuthSessionSnapshot> signInWithPassword({
    required String email,
    required String password,
  }) async => session!;

  @override
  Future<void> signOut() async {
    session = null;
  }

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
  }) async => session!;

  @override
  Future<AuthSessionSnapshot> updateSchoolOperationalSettings({
    required String puskesmasWa,
    required String adm4Code,
  }) async => session!;

  @override
  Future<AuthSessionSnapshot> updateSchoolPartnerCode(
    String inviteCode,
  ) async => session!;
}

class _FakeFcmAlertService implements FcmAlertService {
  final StreamController<ClusterAlertEvent> _ctrl =
      StreamController<ClusterAlertEvent>.broadcast();

  String? boundSppgId;
  String? excludedSchoolId;

  @override
  Stream<ClusterAlertEvent> get alertStream => _ctrl.stream;

  @override
  Future<void> initializeAndBind({
    required String userId,
    required String sppgId,
    String? excludeSchoolId,
    required SupabaseClient? client,
  }) async {
    boundSppgId = sppgId;
    excludedSchoolId = excludeSchoolId;
  }

  void emitIncoming(ClusterAlertEvent event) {
    _ctrl.add(event);
  }

  @override
  Future<void> clearBinding() async {
    boundSppgId = null;
    excludedSchoolId = null;
  }

  @override
  void dispose() {
    _ctrl.close();
  }
}

class _FakeClusterAlertRepository implements ClusterAlertRepository {
  _FakeClusterAlertRepository({
    this.sampleLabelsByInspection = const {},
    this.onSynced,
  });

  final Map<String, String> sampleLabelsByInspection;
  final VoidCallback? onSynced;
  final StreamController<ClusterAlertEvent> _realtimeCtrl =
      StreamController<ClusterAlertEvent>.broadcast();

  final List<ClusterAlertEvent> submitted = [];
  final List<String> pdfDispatchedIds = [];
  final List<({String alertId, String schoolId})> acknowledged = [];
  int syncCalls = 0;

  void emitRealtimeAlert(ClusterAlertEvent event) {
    _realtimeCtrl.add(event);
  }

  void dispose() {
    _realtimeCtrl.close();
  }

  @override
  Future<String?> findSampleLabelForInspection({
    required String schoolId,
    required String inspectionId,
  }) async {
    return sampleLabelsByInspection[inspectionId];
  }

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
  }) async {
    final created = ClusterAlertEvent(
      id: 'alert-${submitted.length + 1}',
      sppgId: sppgId,
      sppgName: sppgName,
      batchId: batchId,
      batchCode: batchCode,
      menuName: menuName,
      reporterSchoolId: school.id,
      reporterSchoolName: school.name,
      stage: stage,
      symptomCount: stage == ClusterAlertStage.postConsumption ? symptomCount : 0,
      notes: (notes ?? '').isEmpty ? null : notes,
      broadcastEnabled: broadcastEnabled,
      sampleLabelCode: sampleLabelCode ?? sampleLabelsByInspection[inspectionId],
      pdfDispatched: false,
      createdAtUtc: DateTime.now().toUtc(),
      isPendingSync: isOffline,
    );
    submitted.add(created);
    return created;
  }

  @override
  Future<void> markPdfDispatched({
    required String alertId,
    required String reporterSchoolId,
    required bool isOffline,
  }) async {
    pdfDispatchedIds.add(alertId);
  }

  @override
  Future<void> acknowledgeAlert({
    required String alertId,
    required String schoolId,
    required bool isOffline,
  }) async {
    acknowledged.add((alertId: alertId, schoolId: schoolId));
  }

  @override
  Future<List<ClusterAlertEvent>> fetchUnacknowledgedAlertsForToday({
    required String sppgId,
    String? currentSchoolId,
  }) async => const [];

  @override
  Stream<ClusterAlertEvent> watchRealtimeAlerts({
    required String sppgId,
    String? excludeSchoolId,
  }) => _realtimeCtrl.stream;

  @override
  Future<int> syncPendingAlerts({String? schoolId}) async {
    syncCalls++;
    onSynced?.call();
    return 1;
  }
}

class _FakeStage5SchoolRepository implements SchoolRepository {
  _FakeStage5SchoolRepository({
    this.inspections = const [],
    this.vaults = const [],
    this.onSynced,
  });

  final List<SchoolInspectionItem> inspections;
  final List<SampleVaultItem> vaults;
  final VoidCallback? onSynced;
  int syncCalls = 0;

  @override
  Future<SchoolDashboardData> fetchDashboardData({
    required SchoolProfile school,
    required bool isOffline,
  }) async {
    return SchoolDashboardData(
      school: school,
      weather: BmkgWeatherReading(
        adm4Code: school.adm4Code,
        temperatureC: 31.5,
        source: isOffline ? BmkgSource.cached : BmkgSource.live,
        observedAtUtc: DateTime.now().toUtc(),
      ),
      todayInspections: inspections,
      activeSampleCount: vaults.where((v) => v.status == 'active').length,
      nearestSampleExpiryUtc: vaults.isNotEmpty ? vaults.first.expiresAtUtc : null,
      partnerKeyCached: true,
    );
  }

  @override
  Future<QrVerificationResult> verifyQrPayloadOffline({
    required String rawQrText,
    required SchoolProfile school,
    required bool isOffline,
  }) async {
    throw UnimplementedError();
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
  }) async => throw UnimplementedError();

  @override
  Future<SampleVaultItem> createSampleVault({
    required SchoolProfile school,
    required String inspectionId,
    required String menuName,
    required String labelCode,
    required bool isOffline,
  }) async => throw UnimplementedError();

  @override
  String generateSampleLabelCode(DateTime nowUtc) => 'SMP-2611-21S5';

  @override
  Future<void> markSampleDisposed({
    required String sampleId,
    required bool isOffline,
  }) async {}

  @override
  Future<void> refreshSampleVaultsFromServer(String schoolId) async {}

  @override
  Future<List<SchoolBatchOption>> fetchSelectableBatchesForWaste({
    required SchoolProfile school,
    required bool isOffline,
  }) async => const [];

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
  }) async => true;

  @override
  Future<int> syncPendingSchoolQueue({required SchoolProfile school}) async {
    syncCalls++;
    onSynced?.call();
    return 1;
  }

  @override
  Stream<List<SampleVaultItem>> watchActiveSamples(String schoolId) =>
      Stream.value(vaults.where((v) => v.status == 'active').toList());

  @override
  Stream<List<SampleVaultItem>> watchHistorySamples(String schoolId) =>
      Stream.value(vaults.where((v) => v.status != 'active').toList());
}

class _FakeStage5KitchenRepository implements KitchenRepository {
  @override
  Future<String?> createSignedPhotoUrl(String storagePath) async => null;

  @override
  Future<FoodBatchItem> createSealedBatch({
    required KitchenProfile kitchen,
    required String menuName,
    required int portionCount,
    required FoodRiskCategory riskCategory,
    required CapturedWebpPhoto photo,
    required bool isOffline,
  }) => throw UnimplementedError();

  @override
  Future<FoodBatchItem?> fetchBatchById({
    required KitchenProfile kitchen,
    required String batchId,
  }) async => null;

  @override
  Future<KitchenDashboardData> fetchDashboard({
    required KitchenProfile kitchen,
  }) async => throw UnimplementedError();

  @override
  Future<KitchenHistoryData> fetchHistoryAndWaste({
    required KitchenProfile kitchen,
    required HistoryTimeRange range,
  }) async => throw UnimplementedError();

  @override
  Future<List<PartnerSchoolItem>> fetchPartnerSchools({
    required String sppgId,
  }) async => const [];

  @override
  Future<void> reviewSchool({
    required String sppgId,
    required String schoolId,
    required SchoolVerificationStatus decision,
  }) async {}

  @override
  Future<int> syncPendingKitchenBatches({
    required KitchenProfile kitchen,
  }) async => 0;
}

class _SpyKlbPdfService implements KlbReportPdfService {
  final DeviceKlbReportPdfService _delegate = DeviceKlbReportPdfService();
  int shareCallCount = 0;
  int waChatLaunchCount = 0;
  String? lastSharedSummaryText;
  String? lastWaLaunchText;

  @override
  String buildWhatsAppSummaryText({
    required PuskesmasDraftArgs args,
    required SchoolProfile school,
  }) {
    final text = _delegate.buildWhatsAppSummaryText(args: args, school: school);
    _assertZeroSlopText(text);
    return text;
  }

  @override
  Future<Uint8List> buildKlbReportPdfBytes({
    required PuskesmasDraftArgs args,
    required SchoolProfile school,
    Uint8List? photoBytesOverride,
  }) => _delegate.buildKlbReportPdfBytes(
    args: args,
    school: school,
    photoBytesOverride: photoBytesOverride,
  );

  @override
  Future<String> generateAndSharePdfToWhatsApp({
    required PuskesmasDraftArgs args,
    required SchoolProfile school,
    Uint8List? photoBytesOverride,
  }) async {
    shareCallCount++;
    lastSharedSummaryText = buildWhatsAppSummaryText(args: args, school: school);
    final bytes = await buildKlbReportPdfBytes(
      args: args,
      school: school,
      photoBytesOverride: photoBytesOverride,
    );
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    return '/tmp/berita_acara_klb_${args.batchCode}.pdf';
  }

  @override
  Future<bool> openDirectWhatsAppChat({
    required String puskesmasWa,
    required String summaryText,
  }) async {
    waChatLaunchCount++;
    _assertZeroSlopText(summaryText);
    lastWaLaunchText = summaryText;
    return true;
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Stage 5 Emergency, PDF Hygiene & Drift Offline Queue Logic', () {
    test(
      'DeviceKlbReportPdfService builds 1-page PDF with sample image and zero-emoji/em-dash WA summary',
      () async {
        final service = DeviceKlbReportPdfService();
        final sampleImg = img.Image(width: 24, height: 24);
        img.fill(sampleImg, color: img.ColorRgb8(45, 110, 72));
        final samplePng = Uint8List.fromList(img.encodePng(sampleImg));

        final nowUtc = DateTime.utc(2026, 11, 21, 5, 30);
        final args = PuskesmasDraftArgs(
          alertId: 'alert-pdf-1',
          batchId: 'batch-pdf-1',
          batchCode: 'BCH-2611-21KLB',
          menuName: 'Nasi Ayam Suwir \u2014 Paket',
          sppgId: _school1.sppgId!,
          sppgName: 'SPPG Purwokerto Utara',
          sealedAtUtc: nowUtc.subtract(const Duration(minutes: 95)),
          scannedAtUtc: nowUtc,
          elapsedMinutes: 95,
          bmkgTempC: 32.8,
          bmkgSource: BmkgSource.live,
          dangerStatus: DangerZoneStatus.yellow,
          stage: ClusterAlertStage.postConsumption,
          symptomCount: 4,
          notes: 'Siswa kelas 4 mengalami mual\u2014pusing',
          reasonSummary: 'Dugaan keracunan ringan pasca makan siang',
          sampleLabelCode: 'SMP-2611-21K1',
          broadcastEnabled: true,
          reportedAtUtc: nowUtc,
        );

        final waText = service.buildWhatsAppSummaryText(
          args: args,
          school: _school1,
        );
        _assertZeroSlopText(waText);
        expect(waText, contains('SMP-2611-21K1'));
        expect(waText, contains(AppConstants.bmkgShortAttribution));
        expect(waText, contains('4 siswa bergejala'));
        expect(waText, contains('32.8 C'));

        final pdfBytes = await service.buildKlbReportPdfBytes(
          args: args,
          school: _school1,
          photoBytesOverride: samplePng,
        );
        expect(pdfBytes.length, greaterThan(1200));
        expect(ascii.decode(pdfBytes.take(5).toList()), '%PDF-');

        final rawPdfBytes = await service.buildKlbReportPdfBytes(
          args: args,
          school: _school1,
          photoBytesOverride: samplePng,
          compress: false,
        );
        final pdfAscii = latin1.decode(rawPdfBytes, allowInvalid: true);
        final pageCount = RegExp(r'/Type\s*/Page\b').allMatches(pdfAscii).length;
        expect(pageCount, 1);
        expect(pdfAscii, contains('/Subtype/Image'));
      },
    );

    test(
      'ClusterAlertController enforces strict sppg_id filter, suppresses self-reports, and deduplicates alerts',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final alertRepo = _FakeClusterAlertRepository();
        final fcmService = _FakeFcmAlertService();
        addTearDown(alertRepo.dispose);

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            isSupabaseReadyProvider.overrideWithValue(false),
            authRepositoryProvider.overrideWithValue(
              _Stage5AuthRepository(_school1Session),
            ),
            clusterAlertRepositoryProvider.overrideWithValue(alertRepo),
            fcmAlertServiceProvider.overrideWithValue(fcmService),
            isOfflineProvider.overrideWith((ref) => Stream.value(false)),
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
          ],
        );
        addTearDown(container.dispose);

        await container.read(authControllerProvider.notifier).bootstrap();
        final sub = container.listen(
          clusterAlertControllerProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);
        await Future<void>.delayed(Duration.zero);

        expect(fcmService.boundSppgId, _school1.sppgId);
        expect(fcmService.excludedSchoolId, _school1.id);

        // Invalid FCM payload rejected cleanly.
        expect(
          ClusterAlertEvent.fromFcmData({'type': 'other'}),
          isNull,
        );

        final validFromFcm = ClusterAlertEvent.fromFcmData({
          'type': 'cluster_alert',
          'alert_id': 'alert-fcm-1',
          'sppg_id': _school1.sppgId!,
          'sppg_name': 'SPPG Purwokerto Utara',
          'batch_id': 'batch-1',
          'batch_code': 'BCH-2611-21A1',
          'menu_name': 'Nasi Ayam Suwir \u2014 Kuah',
          'reporter_school_id': _school2.id,
          'reporter_school_name': _school2.name,
          'stage': 'pre_consumption',
          'symptom_count': '0',
          'sample_label_code': 'SMP-2611-21A9',
        });
        expect(validFromFcm, isNotNull);
        _assertZeroSlopText(validFromFcm!.instructionText);

        final ctrl = container.read(clusterAlertControllerProvider.notifier);

        // 1. Foreign sppg_id must NEVER trigger overlay.
        ctrl.enqueueIncomingAlert(
          ClusterAlertEvent(
            id: 'alert-foreign',
            sppgId: 'a2000000-0000-4000-8000-000000000002',
            sppgName: 'SPPG Lain',
            batchId: 'batch-foreign',
            batchCode: 'BCH-FOREIGN',
            menuName: 'Menu Asing',
            reporterSchoolId: 'b2000000-0000-4000-8000-000000000003',
            reporterSchoolName: 'SDN 1 Sokaraja',
            stage: ClusterAlertStage.preConsumption,
            symptomCount: 0,
            broadcastEnabled: true,
            createdAtUtc: DateTime.now().toUtc(),
          ),
        );
        expect(
          container.read(clusterAlertControllerProvider).activeAlert,
          isNull,
        );

        // 2. Self-report from the same school must NOT display overlay back to reporter.
        ctrl.enqueueIncomingAlert(
          ClusterAlertEvent(
            id: 'alert-self',
            sppgId: _school1.sppgId!,
            sppgName: 'SPPG Purwokerto Utara',
            batchId: 'batch-1',
            batchCode: 'BCH-1',
            menuName: 'Nasi Ayam',
            reporterSchoolId: _school1.id,
            reporterSchoolName: _school1.name,
            stage: ClusterAlertStage.preConsumption,
            symptomCount: 0,
            broadcastEnabled: true,
            createdAtUtc: DateTime.now().toUtc(),
          ),
        );
        expect(
          container.read(clusterAlertControllerProvider).activeAlert,
          isNull,
        );

        // 3. Peer school alert displays, duplicates are dropped, queue promotes on ack.
        ctrl.enqueueIncomingAlert(validFromFcm);
        ctrl.enqueueIncomingAlert(validFromFcm);
        expect(
          container.read(clusterAlertControllerProvider).activeAlert?.id,
          'alert-fcm-1',
        );
        expect(
          container.read(clusterAlertControllerProvider).pendingQueue,
          isEmpty,
        );

        ctrl.enqueueIncomingAlert(
          ClusterAlertEvent(
            id: 'alert-peer-2',
            sppgId: _school1.sppgId!,
            sppgName: 'SPPG Purwokerto Utara',
            batchId: 'batch-2',
            batchCode: 'BCH-2',
            menuName: 'Sayur Lodeh',
            reporterSchoolId: _school2.id,
            reporterSchoolName: _school2.name,
            stage: ClusterAlertStage.postConsumption,
            symptomCount: 3,
            broadcastEnabled: true,
            createdAtUtc: DateTime.now().toUtc(),
          ),
        );
        expect(
          container.read(clusterAlertControllerProvider).pendingQueue.length,
          1,
        );

        await ctrl.acknowledgeActiveAlert();
        expect(
          container.read(clusterAlertControllerProvider).activeAlert?.id,
          'alert-peer-2',
        );
        await ctrl.acknowledgeActiveAlert();
        expect(
          container.read(clusterAlertControllerProvider).activeAlert,
          isNull,
        );
        expect(alertRepo.acknowledged.length, 2);
      },
    );

    test(
      'SupabaseClusterAlertRepository queues alerts offline in Drift, marks sample lab_submitted, and schedules WorkManager',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final scheduler = _SpyBackgroundSyncScheduler();
        final repo = SupabaseClusterAlertRepository(
          client: null,
          database: db,
          backgroundSyncScheduler: scheduler,
        );

        final nowUtc = DateTime.now().toUtc();
        await db.upsertSampleVault(
          LocalSampleVaultsCompanion.insert(
            id: 'vault-501',
            inspectionId: 'insp-501',
            schoolId: _school1.id,
            menuName: 'Nasi Rendang',
            labelCode: 'SMP-2611-21LAB',
            storedAt: nowUtc,
            expiresAt: nowUtc.add(const Duration(hours: 48)),
            status: const Value('active'),
            createdAt: nowUtc,
          ),
        );

        final foundLabel = await repo.findSampleLabelForInspection(
          schoolId: _school1.id,
          inspectionId: 'insp-501',
        );
        expect(foundLabel, 'SMP-2611-21LAB');

        final alert = await repo.submitClusterAlert(
          school: _school1,
          sppgId: _school1.sppgId!,
          sppgName: 'SPPG Purwokerto Utara',
          batchId: 'batch-501',
          batchCode: 'BCH-2611-21K5',
          menuName: 'Nasi Rendang',
          inspectionId: 'insp-501',
          stage: ClusterAlertStage.postConsumption,
          symptomCount: 2,
          broadcastEnabled: true,
          isOffline: true,
          notes: 'Dua siswa mual',
          sampleLabelCode: foundLabel,
        );
        expect(alert.isPendingSync, isTrue);

        await repo.markPdfDispatched(
          alertId: alert.id,
          reporterSchoolId: _school1.id,
          isOffline: true,
        );
        await repo.acknowledgeAlert(
          alertId: 'alert-peer-9',
          schoolId: _school2.id,
          isOffline: true,
        );

        final updatedVault = await db.getSampleVaultByInspection('insp-501');
        expect(updatedVault?.status, 'lab_submitted');

        final queue = await db.getPendingSyncItems();
        final opTypes = queue.map((e) => e.operationType).toList();
        expect(opTypes, contains('update_sample_status'));
        expect(opTypes, contains('create_alert'));
        expect(opTypes, contains('update_alert_pdf_dispatched'));
        expect(opTypes, contains('ack_alert'));
        expect(scheduler.scheduledCount, greaterThanOrEqualTo(3));
      },
    );
  });

  group('Stage 5 UI Flows (G06, Puskesmas Draft PDF/WA, O01, O02)', () {
    Future<
      ({
        _FakeClusterAlertRepository alertRepo,
        _FakeStage5SchoolRepository schoolRepo,
        _SpyKlbPdfService pdfService,
        _FakeFcmAlertService fcmService,
        void Function(bool offline) setOffline,
        void Function(int count) setPendingCount,
      })
    >
    pumpStage5App(
      WidgetTester tester, {
      AuthSessionSnapshot session = _school1Session,
      List<SchoolInspectionItem> inspections = const [],
      List<SampleVaultItem> vaults = const [],
      Map<String, String> sampleLabels = const {},
      bool initialOffline = true,
      int initialPendingCount = 0,
      Size screenSize = const Size(390, 844),
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      var currentOffline = initialOffline;
      var currentPending = initialPendingCount;
      final offlineCtrl = StreamController<bool>.broadcast();
      final pendingCtrl = StreamController<int>.broadcast();
      addTearDown(offlineCtrl.close);
      addTearDown(pendingCtrl.close);

      void setOffline(bool next) {
        currentOffline = next;
        if (!offlineCtrl.isClosed) {
          offlineCtrl.add(next);
        }
      }

      void setPendingCount(int next) {
        currentPending = next;
        if (!pendingCtrl.isClosed) {
          pendingCtrl.add(next);
        }
      }

      final fcmService = _FakeFcmAlertService();
      final pdfService = _SpyKlbPdfService();
      late final _FakeClusterAlertRepository alertRepo;
      late final _FakeStage5SchoolRepository schoolRepo;

      alertRepo = _FakeClusterAlertRepository(
        sampleLabelsByInspection: sampleLabels,
        onSynced: () => setPendingCount(0),
      );
      schoolRepo = _FakeStage5SchoolRepository(
        inspections: inspections,
        vaults: vaults,
        onSynced: () => setPendingCount(0),
      );
      addTearDown(alertRepo.dispose);

      tester.view.physicalSize = screenSize;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            isSupabaseReadyProvider.overrideWithValue(true),
            authRepositoryProvider.overrideWithValue(
              _Stage5AuthRepository(session),
            ),
            schoolRepositoryProvider.overrideWithValue(schoolRepo),
            kitchenRepositoryProvider.overrideWithValue(
              _FakeStage5KitchenRepository(),
            ),
            clusterAlertRepositoryProvider.overrideWithValue(alertRepo),
            klbReportPdfServiceProvider.overrideWithValue(pdfService),
            fcmAlertServiceProvider.overrideWithValue(fcmService),
            backgroundSyncSchedulerProvider.overrideWithValue(
              _SpyBackgroundSyncScheduler(),
            ),
            isOfflineProvider.overrideWith((ref) async* {
              yield currentOffline;
              yield* offlineCtrl.stream;
            }),
            pendingSyncCountProvider.overrideWith((ref) async* {
              yield currentPending;
              yield* pendingCtrl.stream;
            }),
          ],
          child: const LacakSajiApp(),
        ),
      );
      await tester.pumpAndSettle();

      return (
        alertRepo: alertRepo,
        schoolRepo: schoolRepo,
        pdfService: pdfService,
        fcmService: fcmService,
        setOffline: setOffline,
        setPendingCount: setPendingCount,
      );
    }

    testWidgets(
      'Anti-hoaks blocks unverified /school/report, then G01 today batch -> G06 Tahap 2 Stepper -> Puskesmas Draft 1-tap PDF & WA',
      (tester) async {
        final nowUtc = DateTime.now().toUtc();
        final todayInspection = SchoolInspectionItem(
          id: 'insp-today-1',
          batchId: 'batch-today-1',
          batchCode: 'BCH-2611-21S5',
          menuName: 'Nasi Ayam Suwir & Tumis Kacang',
          schoolId: _school1.id,
          scannedAtUtc: nowUtc.subtract(const Duration(hours: 1)),
          sealedAtUtc: nowUtc.subtract(const Duration(hours: 2)),
          elapsedMinutes: 60,
          bmkgTempC: 31.5,
          bmkgSource: BmkgSource.live,
          dangerStatus: DangerZoneStatus.green,
          gpsWithinRadius: true,
          manualSmellOk: true,
          manualVisualOk: true,
          manualPackOk: true,
          finalDecision: 'APPROVED',
          sampleLabelCode: 'SMP-2611-21X9',
        );

        final ctx = await pumpStage5App(
          tester,
          inspections: [todayInspection],
          sampleLabels: const {'insp-today-1': 'SMP-2611-21X9'},
        );

        // Verify direct route /school/report without extra (and with stale batch) is blocked (anti-hoaks).
        final hostElem = tester.element(find.byType(Navigator).first);
        final container = ProviderScope.containerOf(hostElem);
        container.read(goRouterProvider).go(AppRoutes.schoolReportAlert);
        await tester.pumpAndSettle();
        expect(find.text('Akses Pelaporan Terkunci'), findsOneWidget);

        final yesterdayArgs = AnomalyHandoffArgs(
          batchId: 'batch-old',
          batchCode: 'BCH-OLD',
          menuName: 'Menu Kemarin',
          sppgId: _school1.sppgId,
          sppgName: 'SPPG Purwokerto Utara',
          sealedAtUtc: nowUtc.subtract(const Duration(days: 1, hours: 2)),
          scannedAtUtc: nowUtc.subtract(const Duration(days: 1)),
          elapsedMinutes: 40,
          bmkgTempC: 30.0,
          inspectionId: 'insp-old',
          reasonSummary: 'Stale test',
        );
        container
            .read(goRouterProvider)
            .go(AppRoutes.schoolReportAlert, extra: yesterdayArgs);
        await tester.pumpAndSettle();
        expect(find.text('Akses Pelaporan Terkunci'), findsOneWidget);

        await tester.tap(find.text('Kembali ke Beranda Sekolah'));
        await tester.pumpAndSettle();
        expect(find.text('Beranda Sekolah'), findsOneWidget);

        // Open today's verified batch on G01 -> enter G06 in post_consumption stage.
        await tester.ensureVisible(find.text('Nasi Ayam Suwir & Tumis Kacang'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nasi Ayam Suwir & Tumis Kacang'));
        await tester.pumpAndSettle();

        expect(find.text('Laporkan Anomali / Siswa Bergejala'), findsOneWidget);
        await tester.ensureVisible(
          find.text('Laporkan Anomali / Siswa Bergejala'),
        );
        await tester.tap(find.text('Laporkan Anomali / Siswa Bergejala'));
        await tester.pumpAndSettle();

        expect(find.text('LAPORAN DUGAAN KLB PASCA-KONSUMSI'), findsOneWidget);
        expect(find.text('SMP-2611-21X9'), findsOneWidget);

        // Increment symptom stepper to 3 students.
        final plusFinder = find.byIcon(Icons.add_rounded);
        await tester.ensureVisible(plusFinder);
        await tester.tap(plusFinder);
        await tester.pumpAndSettle();
        await tester.tap(plusFinder);
        await tester.pumpAndSettle();
        expect(find.text('3'), findsOneWidget);

        await tester.ensureVisible(
          find.text('Kirim Peringatan & Siapkan PDF Puskesmas'),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text('Kirim Peringatan & Siapkan PDF Puskesmas'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Kirim Peringatan & Siapkan PDF?'), findsOneWidget);
        await tester.tap(find.text('Ya, Kirim & Siapkan PDF'));
        await tester.pumpAndSettle();

        expect(ctx.alertRepo.submitted.length, 1);
        expect(ctx.alertRepo.submitted.first.symptomCount, 3);
        expect(
          ctx.alertRepo.submitted.first.stage,
          ClusterAlertStage.postConsumption,
        );

        // Puskesmas Instant Draft screen (1-page PDF & 1-tap WA).
        expect(find.text('Draf Laporan Puskesmas'), findsOneWidget);
        expect(find.text('SMP-2611-21X9'), findsOneWidget);

        await tester.ensureVisible(
          find.text('Kirim PDF & Ringkasan ke WhatsApp Puskesmas'),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text('Kirim PDF & Ringkasan ke WhatsApp Puskesmas'),
        );
        await tester.pumpAndSettle();

        expect(ctx.pdfService.shareCallCount, 1);
        expect(ctx.alertRepo.pdfDispatchedIds, contains('alert-1'));
        _assertZeroSlopText(ctx.pdfService.lastSharedSummaryText ?? '');

        await tester.ensureVisible(
          find.text('Buka Chat WA Puskesmas (628112800001)'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Buka Chat WA Puskesmas (628112800001)'));
        await tester.pumpAndSettle();
        expect(ctx.pdfService.waChatLaunchCount, 1);
        _assertZeroSlopText(ctx.pdfService.lastWaLaunchText ?? '');

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'Global Overlay O01 filters sppg_id, displays emergency modal over app, records acknowledgement, and jumps to Bank Sampel',
      (tester) async {
        final ctx = await pumpStage5App(
          tester,
          session: _school2Session,
          initialOffline: false,
          vaults: [
            SampleVaultItem(
              id: 'vault-s2-1',
              inspectionId: 'insp-s2-1',
              schoolId: _school2.id,
              menuName: 'Nasi Soto Ayam',
              labelCode: 'SMP-2611-21B2',
              storedAtUtc: DateTime.now().toUtc(),
              expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 48)),
              status: 'active',
              isSynced: true,
            ),
          ],
        );

        // Foreign SPPG alert must be ignored silently.
        ctx.fcmService.emitIncoming(
          ClusterAlertEvent(
            id: 'alert-foreign-sppg',
            sppgId: 'a2000000-0000-4000-8000-000000000002',
            sppgName: 'SPPG Sokaraja',
            batchId: 'b-foreign',
            batchCode: 'BCH-F',
            menuName: 'Menu Sokaraja',
            reporterSchoolId: 'b2000000-0000-4000-8000-000000000003',
            reporterSchoolName: 'SDN 1 Sokaraja',
            stage: ClusterAlertStage.preConsumption,
            symptomCount: 0,
            broadcastEnabled: true,
            createdAtUtc: DateTime.now().toUtc(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('PERINGATAN DARURAT MAKANAN'), findsNothing);

        // Same-SPPG Realtime alert shows full-screen O01.
        ctx.alertRepo.emitRealtimeAlert(
          ClusterAlertEvent(
            id: 'alert-realtime-1',
            sppgId: _school2.sppgId!,
            sppgName: 'SPPG Purwokerto Utara',
            batchId: 'b-same-1',
            batchCode: 'BCH-2611-21RT',
            menuName: 'Nasi Ayam Suwir',
            reporterSchoolId: _school1.id,
            reporterSchoolName: _school1.name,
            stage: ClusterAlertStage.preConsumption,
            symptomCount: 0,
            broadcastEnabled: true,
            createdAtUtc: DateTime.now().toUtc(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('PERINGATAN DARURAT MAKANAN'), findsOneWidget);
        expect(find.text('SDN 1 Purwokerto'), findsOneWidget);

        await tester.ensureVisible(
          find.text('Saya Mengerti & Tahan Distribusi'),
        );
        await tester.tap(find.text('Saya Mengerti & Tahan Distribusi'));
        await tester.pumpAndSettle();
        expect(find.text('PERINGATAN DARURAT MAKANAN'), findsNothing);
        expect(ctx.alertRepo.acknowledged.length, 1);

        // Stage 2 alert via FCM + jump to Bank Sampel Saya.
        ctx.fcmService.emitIncoming(
          ClusterAlertEvent(
            id: 'alert-fcm-2',
            sppgId: _school2.sppgId!,
            sppgName: 'SPPG Purwokerto Utara',
            batchId: 'b-same-2',
            batchCode: 'BCH-2611-21FC',
            menuName: 'Nasi Soto Ayam',
            reporterSchoolId: _school1.id,
            reporterSchoolName: _school1.name,
            stage: ClusterAlertStage.postConsumption,
            symptomCount: 5,
            sampleLabelCode: 'SMP-2611-21K1',
            broadcastEnabled: true,
            createdAtUtc: DateTime.now().toUtc(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('PERINGATAN DARURAT MAKANAN'), findsOneWidget);
        expect(find.text('5 siswa'), findsOneWidget);

        await tester.ensureVisible(find.text('Lihat Bank Sampel Saya'));
        await tester.tap(find.text('Lihat Bank Sampel Saya'));
        await tester.pumpAndSettle();
        expect(find.text('PERINGATAN DARURAT MAKANAN'), findsNothing);
        expect(find.text('Bank Sampel 48 Jam'), findsOneWidget);
        expect(ctx.alertRepo.acknowledged.length, 2);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'Global Overlay O02 updates on offline -> online transition and triggers auto-sync automatically',
      (tester) async {
        final ctx = await pumpStage5App(
          tester,
          initialOffline: true,
          initialPendingCount: 2,
        );

        expect(
          find.text('Mode Tanpa Sinyal. 2 data tersimpan aman di HP.'),
          findsOneWidget,
        );

        // Simulate connection returning -> OfflineSyncController triggers automatically.
        ctx.setOffline(false);
        await tester.pumpAndSettle();

        expect(ctx.schoolRepo.syncCalls, greaterThanOrEqualTo(1));
        expect(ctx.alertRepo.syncCalls, greaterThanOrEqualTo(1));
        expect(
          find.text('Mode Tanpa Sinyal. 2 data tersimpan aman di HP.'),
          findsNothing,
        );

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'Compact 320dp viewport at Ekstra Besar scale renders G06, Puskesmas Draft, and O01 with zero overflow',
      (tester) async {
        final nowUtc = DateTime.now().toUtc();
        final todayInspection = SchoolInspectionItem(
          id: 'insp-320-1',
          batchId: 'batch-320-1',
          batchCode: 'BCH-2611-320',
          menuName: 'Nasi Ayam Suwir & Tumis Buncis',
          schoolId: _school1.id,
          scannedAtUtc: nowUtc,
          sealedAtUtc: nowUtc.subtract(const Duration(minutes: 50)),
          elapsedMinutes: 50,
          bmkgTempC: 32.4,
          bmkgSource: BmkgSource.live,
          dangerStatus: DangerZoneStatus.yellow,
          gpsWithinRadius: true,
          manualSmellOk: true,
          manualVisualOk: true,
          manualPackOk: true,
          finalDecision: 'APPROVED',
          sampleLabelCode: 'SMP-2611-320A',
        );

        final ctx = await pumpStage5App(
          tester,
          inspections: [todayInspection],
          sampleLabels: const {'insp-320-1': 'SMP-2611-320A'},
          initialOffline: true,
          initialPendingCount: 1,
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

        await tester.ensureVisible(find.text('Nasi Ayam Suwir & Tumis Buncis'));
        await tester.tap(find.text('Nasi Ayam Suwir & Tumis Buncis'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.text('Laporkan Anomali / Siswa Bergejala'),
        );
        await tester.tap(find.text('Laporkan Anomali / Siswa Bergejala'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(
          find.text('Kirim Peringatan & Siapkan PDF Puskesmas'),
        );
        await tester.tap(
          find.text('Kirim Peringatan & Siapkan PDF Puskesmas'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ya, Kirim & Siapkan PDF'));
        await tester.pumpAndSettle();
        expect(find.text('Draf Laporan Puskesmas'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Also check O01 modal at 320dp + Ekstra Besar scale.
        ctx.alertRepo.emitRealtimeAlert(
          ClusterAlertEvent(
            id: 'alert-320-o01',
            sppgId: _school1.sppgId!,
            sppgName: 'SPPG Purwokerto Utara',
            batchId: 'b-320',
            batchCode: 'BCH-320',
            menuName: 'Nasi Ayam Suwir',
            reporterSchoolId: _school2.id,
            reporterSchoolName: _school2.name,
            stage: ClusterAlertStage.postConsumption,
            symptomCount: 2,
            sampleLabelCode: 'SMP-2611-320A',
            broadcastEnabled: true,
            createdAtUtc: nowUtc,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('PERINGATAN DARURAT MAKANAN'), findsOneWidget);
        expect(tester.takeException(), isNull);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );
  });
}
