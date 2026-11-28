import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lacak_saji/core/constants/app_constants.dart';
import 'package:lacak_saji/core/database/database_provider.dart';
import 'package:lacak_saji/core/media/live_camera_webp_service.dart';
import 'package:lacak_saji/core/network/bmkg_weather_service.dart';
import 'package:lacak_saji/core/network/connectivity_provider.dart';
import 'package:lacak_saji/core/network/supabase_provider.dart';
import 'package:lacak_saji/core/theme/text_scale_provider.dart';
import 'package:lacak_saji/features/alerts/domain/cluster_alert_models.dart';
import 'package:lacak_saji/features/auth/data/auth_repository.dart';
import 'package:lacak_saji/features/auth/domain/auth_error_mapper.dart';
import 'package:lacak_saji/features/auth/domain/auth_models.dart';
import 'package:lacak_saji/features/auth/presentation/auth_controller.dart';
import 'package:lacak_saji/features/kitchen/data/kitchen_repository.dart';
import 'package:lacak_saji/features/kitchen/domain/kitchen_models.dart';
import 'package:lacak_saji/features/kitchen/presentation/kitchen_providers.dart';
import 'package:lacak_saji/features/school/data/hybrid_vision_service.dart';
import 'package:lacak_saji/features/school/data/school_repository.dart';
import 'package:lacak_saji/features/school/domain/danger_zone_calculator.dart';
import 'package:lacak_saji/features/school/domain/school_models.dart';
import 'package:lacak_saji/features/school/presentation/school_providers.dart';
import 'package:lacak_saji/features/supervisor/data/supervisor_repository.dart';
import 'package:lacak_saji/features/supervisor/domain/supervisor_models.dart';
import 'package:lacak_saji/features/supervisor/presentation/supervisor_providers.dart';
import 'package:lacak_saji/main.dart';

const KitchenProfile _kitchenProfile = KitchenProfile(
  id: 'a1000000-0000-4000-8000-000000000001',
  ownerUserId: '10000000-0000-4000-8000-000000000001',
  regNumber: 'BGN-PWT-2026-001',
  inviteCode: 'SPPG-PWT-01',
  name: 'SPPG Purwokerto Utara',
  adm4Code: '33.02.26.1001',
  lat: -7.4126,
  lng: 109.2345,
  publicKey: '8hY2v0M7pQ5wN8tR1xL4kZ9bC3vF6mJ2dS0qW7eU5yI=',
  isVerified: true,
);

const SchoolProfile _schoolProfile = SchoolProfile(
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

const AuthSessionSnapshot _kitchenSession = AuthSessionSnapshot(
  profile: UserProfile(
    id: '10000000-0000-4000-8000-000000000001',
    email: 'dapur.a@lacaksaji.id',
    role: UserRole.kitchen,
    fullName: 'Ibu Ratna (Petugas SPPG Purwokerto Utara)',
  ),
  kitchen: _kitchenProfile,
);

const AuthSessionSnapshot _schoolSession = AuthSessionSnapshot(
  profile: UserProfile(
    id: '20000000-0000-4000-8000-000000000001',
    email: 'sdn1.pwt@lacaksaji.id',
    role: UserRole.school,
    fullName: 'Ibu Siti (PIC SDN 1 Purwokerto)',
  ),
  school: _schoolProfile,
);

const AuthSessionSnapshot _supervisorSession = AuthSessionSnapshot(
  profile: UserProfile(
    id: '30000000-0000-4000-8000-000000000001',
    email: 'pengawas.bgn@lacaksaji.id',
    role: UserRole.supervisor,
    fullName: 'Pengawas BGN Wilayah Banyumas',
  ),
);

class _FakeStage6AuthRepository implements AuthRepository {
  AuthSessionSnapshot? currentSession;

  @override
  Future<AuthSessionSnapshot?> restoreSession() async => currentSession;

  @override
  Future<AuthSessionSnapshot?> refreshSession() async => currentSession;

  @override
  Future<AuthSessionSnapshot> signInWithPassword({
    required String email,
    required String password,
  }) async {
    switch (email) {
      case 'dapur.a@lacaksaji.id':
        currentSession = _kitchenSession;
      case 'sdn1.pwt@lacaksaji.id':
        currentSession = _schoolSession;
      case 'pengawas.bgn@lacaksaji.id':
        currentSession = _supervisorSession;
      default:
        throw const AuthFriendlyException('Email demo tidak dikenali.');
    }
    return currentSession!;
  }

  @override
  Future<void> signOut() async {
    currentSession = null;
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
  }) async => currentSession!;

  @override
  Future<AuthSessionSnapshot> updateSchoolOperationalSettings({
    required String puskesmasWa,
    required String adm4Code,
  }) async => currentSession!;

  @override
  Future<AuthSessionSnapshot> updateSchoolPartnerCode(
    String inviteCode,
  ) async => currentSession!;
}

class _FakeStage6SupervisorRepository implements SupervisorRepository {
  _FakeStage6SupervisorRepository(this.nowUtc);

  final DateTime nowUtc;
  final List<({SupervisorDateFilter dateFilter, String regionFilter})> calls =
      [];

  @override
  Future<SupervisorNationalOverview> fetchNationalOverview({
    required SupervisorDateFilter dateFilter,
    String regionFilter = 'Semua Wilayah',
  }) async {
    calls.add((dateFilter: dateFilter, regionFilter: regionFilter));

    final pwtSummary = const SupervisorSppgSummary(
      sppgId: 'a1000000-0000-4000-8000-000000000001',
      sppgName: 'SPPG Purwokerto Utara',
      inviteCode: 'SPPG-PWT-01',
      adm4Code: '33.02.26.1001',
      regionName: 'Purwokerto Utara',
      approvedSchoolCount: 3,
      totalBatches: 12,
      safeBatches: 11,
      problemBatches: 1,
      activeAlertsCount: 1,
      avgCarbWastePct: 18,
      avgProteinWastePct: 14,
      avgVegWastePct: 46,
      avgOverallWastePct: 26,
      wasteLogCount: 6,
    );
    final sokarajaSummary = const SupervisorSppgSummary(
      sppgId: 'a2000000-0000-4000-8000-000000000002',
      sppgName: 'SPPG Sokaraja',
      inviteCode: 'SPPG-PWT-02',
      adm4Code: '33.02.18.2005',
      regionName: 'Sokaraja',
      approvedSchoolCount: 1,
      totalBatches: 6,
      safeBatches: 6,
      problemBatches: 0,
      activeAlertsCount: 0,
      avgCarbWastePct: 12,
      avgProteinWastePct: 10,
      avgVegWastePct: 24,
      avgOverallWastePct: 15,
      wasteLogCount: 3,
    );

    final allSummaries = [pwtSummary, sokarajaSummary];
    final filtered = regionFilter == 'Semua Wilayah'
        ? allSummaries
        : allSummaries
              .where((s) => s.regionName == regionFilter)
              .toList(growable: false);

    final pwtAlert = SupervisorAlertBrief(
      id: 'alert-stage6-1',
      sppgId: pwtSummary.sppgId,
      sppgName: pwtSummary.sppgName,
      menuName: 'Nasi Soto Ayam Santan & Pisang',
      batchCode: 'BCH-2611-21A',
      stage: ClusterAlertStage.postConsumption,
      symptomCount: 4,
      createdAtUtc: nowUtc.subtract(const Duration(minutes: 25)),
    );

    final alerts = (regionFilter == 'Semua Wilayah' ||
            regionFilter == 'Purwokerto Utara') &&
        dateFilter != SupervisorDateFilter.today
        ? [pwtAlert]
        : (dateFilter == SupervisorDateFilter.today &&
              (regionFilter == 'Semua Wilayah' ||
                  regionFilter == 'Purwokerto Utara')
          ? [pwtAlert]
          : <SupervisorAlertBrief>[]);

    final safeTotal = filtered.fold<int>(0, (sum, item) => sum + item.safeBatches);
    final problemTotal = filtered.fold<int>(
      0,
      (sum, item) => sum + item.problemBatches,
    );
    final schoolsTotal = filtered.fold<int>(
      0,
      (sum, item) => sum + item.approvedSchoolCount,
    );
    final wasteAvg = filtered.isEmpty
        ? 0
        : (filtered.fold<int>(0, (sum, item) => sum + item.avgOverallWastePct) /
                  filtered.length)
              .round();

    return SupervisorNationalOverview(
      dateFilter: dateFilter,
      regionFilter: regionFilter,
      availableRegions: const [
        'Semua Wilayah',
        'Purwokerto Utara',
        'Sokaraja',
      ],
      totalSppgCount: filtered.length,
      totalApprovedSchoolsCount: schoolsTotal,
      totalBatches: safeTotal + problemTotal,
      safeBatches: dateFilter == SupervisorDateFilter.today ? 2 : safeTotal,
      problemBatches: problemTotal,
      activeAlertsCount: alerts.length,
      avgWastePct: wasteAvg,
      activeAlerts: alerts,
      sppgSummaries: filtered,
      generatedAtUtc: nowUtc,
    );
  }
}

class _RichKitchenRepository implements KitchenRepository {
  _RichKitchenRepository(this.nowUtc);

  final DateTime nowUtc;

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
    List<String> allergenTags = const [],
  }) => throw UnimplementedError();

  @override
  Future<FoodBatchItem?> fetchBatchById({
    required KitchenProfile kitchen,
    required String batchId,
  }) async => null;

  @override
  Future<KitchenDashboardData> fetchDashboard({
    required KitchenProfile kitchen,
  }) async {
    final batch = FoodBatchItem(
      id: 'b-rich-1',
      sppgId: kitchen.id,
      sppgName: kitchen.name,
      batchCode: 'BCH-2611-21A',
      menuName: 'Nasi Ayam Suwir Kemangi & Sayur Bening Bayam Jagung',
      portionCount: 165,
      riskCategory: FoodRiskCategory.high,
      sealedAtUtc: nowUtc.subtract(const Duration(hours: 2)),
      timestampSource: BatchTimestampSource.serverVerified,
      signatureB64: 'sig-rich-1',
      createdAtUtc: nowUtc.subtract(const Duration(hours: 2)),
      inspectedSchoolIds: const ['s-1', 's-2'],
    );
    return KitchenDashboardData(
      kitchen: kitchen,
      todayBatches: [batch],
      todayReceivedSchoolsCount: 2,
      approvedSchoolsCount: 3,
      pendingSchoolsCount: 1,
      activeAlertsToday: [
        ActiveClusterAlertItem(
          id: 'ca-kitchen-1',
          batchId: 'b-rich-1',
          batchCode: 'BCH-2611-21A',
          menuName: 'Nasi Ayam Suwir Kemangi & Sayur Bening Bayam Jagung',
          stage: 'post_consumption',
          symptomCount: 3,
          createdAtUtc: nowUtc.subtract(const Duration(minutes: 20)),
          reporterSchoolName: 'SDN 2 Purwokerto Utara',
        ),
      ],
      weeklyWasteSummary: const PlateWasteSummary(
        avgCarbPct: 18,
        avgProteinPct: 14,
        avgVegPct: 45,
        sampleCount: 4,
        recommendations: [
          'Rata-rata sisa sayuran mencapai 45%. Pertimbangkan potongan sayur lebih kecil.',
        ],
      ),
    );
  }

  @override
  Future<KitchenHistoryData> fetchHistoryAndWaste({
    required KitchenProfile kitchen,
    required HistoryTimeRange range,
  }) async {
    return KitchenHistoryData(
      range: range,
      batches: [
        FoodBatchItem(
          id: 'b-rich-1',
          sppgId: kitchen.id,
          sppgName: kitchen.name,
          batchCode: 'BCH-2611-21A',
          menuName: 'Nasi Ayam Suwir Kemangi & Sayur Bening Bayam Jagung',
          portionCount: 165,
          riskCategory: FoodRiskCategory.high,
          sealedAtUtc: nowUtc.subtract(const Duration(hours: 2)),
          timestampSource: BatchTimestampSource.serverVerified,
          signatureB64: 'sig-rich-1',
          createdAtUtc: nowUtc.subtract(const Duration(hours: 2)),
          inspectedSchoolIds: const ['s-1'],
        ),
      ],
      wasteLogs: [
        PlateWasteLogItem(
          id: 'pw-rich-1',
          batchId: 'b-rich-1',
          batchCode: 'BCH-2611-21A',
          menuName: 'Nasi Ayam Suwir Kemangi & Sayur Bening Bayam Jagung',
          schoolId: 's-1',
          schoolName: 'SDN 1 Purwokerto',
          carbWastePct: 15,
          proteinWastePct: 10,
          vegWastePct: 48,
          aiAssisted: true,
          createdAtUtc: nowUtc.subtract(const Duration(hours: 1)),
        ),
      ],
      wasteSummary: const PlateWasteSummary(
        avgCarbPct: 15,
        avgProteinPct: 10,
        avgVegPct: 48,
        sampleCount: 1,
        recommendations: [
          'Rata-rata sisa sayuran mencapai 48%. Pertimbangkan potongan sayur lebih kecil.',
        ],
      ),
    );
  }

  @override
  Future<List<PartnerSchoolItem>> fetchPartnerSchools({
    required String sppgId,
  }) async {
    return [
      PartnerSchoolItem(
        id: 's-pend-1',
        sppgId: sppgId,
        npsn: '20301999',
        name: 'SDN 4 Purwokerto Utara Raya',
        adm4Code: '33.02.26.1004',
        puskesmasWa: '628112800004',
        verificationStatus: SchoolVerificationStatus.pending,
        dailyStatus: SchoolDailyStatus.notScanned,
        createdAtUtc: nowUtc.subtract(const Duration(days: 1)),
      ),
      PartnerSchoolItem(
        id: 's-1',
        sppgId: sppgId,
        npsn: '20301901',
        name: 'SDN 1 Purwokerto',
        adm4Code: '33.02.26.1001',
        puskesmasWa: '628112800001',
        verificationStatus: SchoolVerificationStatus.approved,
        dailyStatus: SchoolDailyStatus.received,
        createdAtUtc: nowUtc.subtract(const Duration(days: 5)),
        lastScannedAtUtc: nowUtc.subtract(const Duration(minutes: 40)),
      ),
    ];
  }

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

class _RichSchoolRepository implements SchoolRepository {
  _RichSchoolRepository(this.nowUtc);

  final DateTime nowUtc;

  @override
  Future<SampleVaultItem> createSampleVault({
    required SchoolProfile school,
    required String inspectionId,
    required String menuName,
    required String labelCode,
    required bool isOffline,
  }) => throw UnimplementedError();

  @override
  Future<SchoolDashboardData> fetchDashboardData({
    required SchoolProfile school,
    required bool isOffline,
  }) async {
    return SchoolDashboardData(
      school: school,
      weather: BmkgWeatherReading(
        adm4Code: school.adm4Code,
        temperatureC: 31.8,
        source: BmkgSource.live,
        observedAtUtc: nowUtc.subtract(const Duration(minutes: 15)),
        weatherDesc: 'Cerah Berawan',
      ),
      todayInspections: [
        SchoolInspectionItem(
          id: 'insp-rich-1',
          batchId: 'b-rich-1',
          batchCode: 'BCH-2611-21A',
          menuName: 'Nasi Ayam Suwir Kemangi & Sayur Bening Bayam Jagung',
          schoolId: school.id,
          scannedAtUtc: nowUtc.subtract(const Duration(minutes: 50)),
          elapsedMinutes: 95,
          bmkgTempC: 31.8,
          bmkgSource: BmkgSource.live,
          dangerStatus: DangerZoneStatus.yellow,
          gpsWithinRadius: true,
          manualSmellOk: true,
          manualVisualOk: true,
          manualPackOk: true,
          finalDecision: 'APPROVED',
        ),
      ],
      activeSampleCount: 1,
      nearestSampleExpiryUtc: nowUtc.add(const Duration(hours: 44)),
      partnerKeyCached: true,
    );
  }

  @override
  Future<List<SchoolBatchOption>> fetchSelectableBatchesForWaste({
    required SchoolProfile school,
    required bool isOffline,
  }) async {
    return [
      SchoolBatchOption(
        batchId: 'b-rich-1',
        batchCode: 'BCH-2611-21A',
        menuName: 'Nasi Ayam Suwir Kemangi',
        sealedAtUtc: nowUtc.subtract(const Duration(hours: 3)),
      ),
    ];
  }

  @override
  String generateSampleLabelCode(DateTime nowUtc) => 'SMP-2611-21A';

  @override
  Future<void> markSampleDisposed({
    required String sampleId,
    required bool isOffline,
  }) async {}

  @override
  Future<void> refreshSampleVaultsFromServer(String schoolId) async {}

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
  }) => throw UnimplementedError();

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
  Future<int> syncPendingSchoolQueue({
    required SchoolProfile school,
  }) async => 0;

  @override
  Future<QrVerificationResult> verifyQrPayloadOffline({
    required String rawQrText,
    required SchoolProfile school,
    required bool isOffline,
  }) => throw UnimplementedError();

  @override
  Stream<List<SampleVaultItem>> watchActiveSamples(String schoolId) {
    return Stream.value([
      SampleVaultItem(
        id: 'sv-rich-1',
        inspectionId: 'insp-rich-1',
        schoolId: schoolId,
        menuName: 'Nasi Ayam Suwir Kemangi & Sayur Bening Bayam Jagung',
        labelCode: 'SMP-2611-21A',
        storedAtUtc: nowUtc.subtract(const Duration(hours: 4)),
        expiresAtUtc: nowUtc.add(const Duration(hours: 44)),
        status: 'active',
        isSynced: true,
      ),
    ]);
  }

  @override
  Stream<List<SampleVaultItem>> watchHistorySamples(String schoolId) =>
      Stream.value(const []);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  Widget buildStage6App({
    required SharedPreferences prefs,
    required _FakeStage6AuthRepository authRepo,
    required _FakeStage6SupervisorRepository supervisorRepo,
    required _RichKitchenRepository kitchenRepo,
    required _RichSchoolRepository schoolRepo,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isSupabaseReadyProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(authRepo),
        supervisorRepositoryProvider.overrideWithValue(supervisorRepo),
        kitchenRepositoryProvider.overrideWithValue(kitchenRepo),
        schoolRepositoryProvider.overrideWithValue(schoolRepo),
        isOfflineProvider.overrideWith((ref) => Stream.value(false)),
        pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
      ],
      child: const LacakSajiApp(),
    );
  }

  group('Stage 6 B01 Supervisor Read-Only & 320dp Ekstra Besar Overflow Audit', () {
    testWidgets(
      'S02 Quick Demo -> B01 Mode Pengawas BGN displays national metrics, filters date/region read-only, and opens C01',
      (tester) async {
        final nowUtc = DateTime.utc(2026, 11, 21, 9, 30);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final authRepo = _FakeStage6AuthRepository();
        final supervisorRepo = _FakeStage6SupervisorRepository(nowUtc);

        await tester.pumpWidget(
          buildStage6App(
            prefs: prefs,
            authRepo: authRepo,
            supervisorRepo: supervisorRepo,
            kitchenRepo: _RichKitchenRepository(nowUtc),
            schoolRepo: _RichSchoolRepository(nowUtc),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Masuk Cepat (Akun Demo)'));
        await tester.tap(find.text('Masuk Cepat (Akun Demo)'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Mode Pengawas BGN (Hanya Baca)'));
        await tester.tap(find.text('Mode Pengawas BGN (Hanya Baca)'));
        await tester.pumpAndSettle();

        expect(find.text('Pemantauan Wilayah (Hanya Baca)'), findsOneWidget);
        expect(find.text('HANYA BACA'), findsOneWidget);
        expect(find.text('Ringkasan Nasional'), findsOneWidget);
        expect(find.text('Batch Aman'), findsOneWidget);
        expect(find.text('Batch Bermasalah'), findsOneWidget);
        expect(find.text('Alarm Aktif'), findsOneWidget);
        expect(find.text('Rata Sisa Makan'), findsOneWidget);
        expect(find.text('1 Alarm Anomali / KLB Aktif Terdeteksi'), findsOneWidget);
        expect(find.text('SPPG Purwokerto Utara'), findsAtLeastNWidgets(1));
        expect(find.text('SPPG Sokaraja'), findsOneWidget);
        expect(find.text('Nasi / Karbohidrat'), findsAtLeastNWidgets(1));

        // Verify strictly read-only: no kitchen batch creation or school approval mutation CTAs.
        expect(find.text('Buat QR Segel Batch Baru'), findsNothing);
        expect(find.text('Setujui'), findsNothing);
        expect(find.text('Tolak'), findsNothing);

        // Filter by region Sokaraja (safe only).
        await tester.ensureVisible(find.text('Sokaraja'));
        await tester.tap(find.text('Sokaraja'));
        await tester.pumpAndSettle();

        expect(find.text('Tidak Ada Alarm Anomali Aktif'), findsOneWidget);
        expect(find.text('SPPG Sokaraja'), findsOneWidget);
        expect(find.text('SPPG Purwokerto Utara'), findsNothing);

        // Switch date filter to Hari Ini on Semua Wilayah.
        await tester.ensureVisible(find.text('Semua Wilayah'));
        await tester.tap(find.text('Semua Wilayah'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Hari Ini'));
        await tester.tap(find.text('Hari Ini'));
        await tester.pumpAndSettle();

        expect(
          supervisorRepo.calls.last.dateFilter,
          SupervisorDateFilter.today,
        );

        // Open C01 Settings from B01 AppBar action.
        await tester.tap(find.byTooltip('Pengaturan & Keluar'));
        await tester.pumpAndSettle();
        expect(find.text('Profil & Pengaturan'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'All core screens render without RenderFlex overflow on 320dp Compact viewport at Ekstra Besar (1.30x) scale',
      (tester) async {
        final nowUtc = DateTime.utc(2026, 11, 21, 9, 30);
        SharedPreferences.setMockInitialValues({
          AppConstants.textScalePrefKey: ComfortableTextScale.extraLarge.name,
        });
        final prefs = await SharedPreferences.getInstance();
        final authRepo = _FakeStage6AuthRepository();

        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          buildStage6App(
            prefs: prefs,
            authRepo: authRepo,
            supervisorRepo: _FakeStage6SupervisorRepository(nowUtc),
            kitchenRepo: _RichKitchenRepository(nowUtc),
            schoolRepo: _RichSchoolRepository(nowUtc),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'S02 overflow');

        // 1) B01 Supervisor
        await tester.ensureVisible(find.text('Masuk Cepat (Akun Demo)'));
        await tester.tap(find.text('Masuk Cepat (Akun Demo)'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Mode Pengawas BGN (Hanya Baca)'));
        await tester.tap(find.text('Mode Pengawas BGN (Hanya Baca)'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'B01 overflow');

        await tester.tap(find.byTooltip('Pengaturan & Keluar'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Keluar Akun'));
        await tester.tap(find.text('Keluar Akun'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ya, Keluar Akun'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'C01 logout overflow');

        // 2) Kitchen D01 -> D04 -> D05
        await tester.ensureVisible(find.text('Masuk Cepat (Akun Demo)'));
        await tester.tap(find.text('Masuk Cepat (Akun Demo)'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Dapur SPPG A (SPPG-PWT-01)'));
        await tester.tap(find.text('Dapur SPPG A (SPPG-PWT-01)'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'D01 overflow');

        await tester.tap(find.text('Sekolah'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'D04 overflow');

        await tester.tap(find.text('Riwayat'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'D05 overflow');

        await tester.tap(find.text('Profil'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'C01 kitchen overflow');
        await tester.ensureVisible(find.text('Keluar Akun'));
        await tester.tap(find.text('Keluar Akun'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ya, Keluar Akun'));
        await tester.pumpAndSettle();

        // 3) School G01 -> G05 -> G07 -> C01
        await tester.ensureVisible(find.text('Masuk Cepat (Akun Demo)'));
        await tester.tap(find.text('Masuk Cepat (Akun Demo)'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Sekolah 1: SDN 1 Purwokerto'));
        await tester.tap(find.text('Sekolah 1: SDN 1 Purwokerto'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'G01 overflow');

        await tester.tap(find.text('Sampel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'G05 overflow');

        await tester.tap(find.text('Sisa Makan'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'G07 overflow');

        await tester.tap(find.text('Profil'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'C01 school overflow');
      },
    );

    testWidgets(
      'Portrait Android Tablet (768x1024) renders adaptive NavigationRail and all core screens cleanly with zero overflow',
      (tester) async {
        final nowUtc = DateTime.utc(2026, 11, 21, 9, 30);
        SharedPreferences.setMockInitialValues({
          AppConstants.textScalePrefKey: ComfortableTextScale.large.name,
        });
        final prefs = await SharedPreferences.getInstance();
        final authRepo = _FakeStage6AuthRepository();

        tester.view.physicalSize = const Size(768, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          buildStage6App(
            prefs: prefs,
            authRepo: authRepo,
            supervisorRepo: _FakeStage6SupervisorRepository(nowUtc),
            kitchenRepo: _RichKitchenRepository(nowUtc),
            schoolRepo: _RichSchoolRepository(nowUtc),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'S02 tablet overflow');

        // 1) Kitchen tablet shell (NavigationRail >= 600dp)
        await tester.ensureVisible(find.text('Masuk Cepat (Akun Demo)'));
        await tester.tap(find.text('Masuk Cepat (Akun Demo)'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Dapur SPPG A (SPPG-PWT-01)'));
        await tester.tap(find.text('Dapur SPPG A (SPPG-PWT-01)'));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'D01 tablet overflow');

        // Open D02 Create Batch on tablet
        await tester.ensureVisible(find.text('Buat QR Segel Batch Baru'));
        await tester.tap(find.text('Buat QR Segel Batch Baru'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'D02 tablet overflow');
        await tester.tap(find.byTooltip('Kembali'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sekolah'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'D04 tablet overflow');

        await tester.tap(find.text('Riwayat'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'D05 tablet overflow');

        await tester.tap(find.text('Profil'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'C01 tablet overflow');
        await tester.ensureVisible(find.text('Keluar Akun'));
        await tester.tap(find.text('Keluar Akun'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ya, Keluar Akun'));
        await tester.pumpAndSettle();

        // 2) School tablet shell (NavigationRail >= 600dp)
        await tester.ensureVisible(find.text('Masuk Cepat (Akun Demo)'));
        await tester.tap(find.text('Masuk Cepat (Akun Demo)'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Sekolah 1: SDN 1 Purwokerto'));
        await tester.tap(find.text('Sekolah 1: SDN 1 Purwokerto'));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'G01 tablet overflow');

        await tester.tap(find.text('Sampel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'G05 tablet overflow');

        await tester.tap(find.text('Sisa Makan'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'G07 tablet overflow');
      },
    );

    test(
      'Bundled food_freshness_int8.tflite model & low-quality blurry camera pipeline classify fresh vs spoiled food accurately',
      () async {
        final modelFile = File('assets/models/food_freshness_int8.tflite');
        expect(modelFile.existsSync(), isTrue);
        final modelBytes = modelFile.readAsBytesSync();
        expect(modelBytes.length, greaterThan(4000000));
        // Verify FlatBuffer TFL3 identifier at byte offset 4..8.
        expect(
          String.fromCharCodes(modelBytes.sublist(4, 8)),
          equals('TFL3'),
        );

        final service = DeviceHybridVisionService(client: null);

        // 1) Blurry, warm-yellow-cast, noisy camera photo of fresh food
        //    (warm rice + chicken + green vegetables with simulated lens haze & noise).
        final blurryFresh = img.Image(width: 160, height: 160);
        for (var y = 0; y < 160; y++) {
          for (var x = 0; x < 160; x++) {
            final grain = ((x * 17 + y * 31) % 19) - 9;
            if (y < 80) {
              // Warm rice under yellow bulb cast
              blurryFresh.setPixelRgb(
                x,
                y,
                (215 + grain).clamp(0, 255),
                (198 + grain).clamp(0, 255),
                (152 + grain).clamp(0, 255),
              );
            } else if (x < 80) {
              // Golden fried chicken protein
              blurryFresh.setPixelRgb(
                x,
                y,
                (182 + grain).clamp(0, 255),
                (136 + grain).clamp(0, 255),
                (76 + grain).clamp(0, 255),
              );
            } else {
              // Fresh green vegetables
              blurryFresh.setPixelRgb(
                x,
                y,
                (82 + grain).clamp(0, 255),
                (158 + grain).clamp(0, 255),
                (74 + grain).clamp(0, 255),
              );
            }
          }
        }
        final freshPng = Uint8List.fromList(img.encodePng(blurryFresh));
        final freshRes = await service.analyzeOnDevice(freshPng);
        expect(freshRes.usedTfliteModel, isTrue);
        expect(freshRes.label, OnDeviceVisualLabel.freshLikely);
        expect(freshRes.confidence, greaterThanOrEqualTo(0.70));
        expect(freshRes.summaryText, isNot(contains('TFLite')));

        // 1b) White rice with localized patchy yellowish discoloration (nasi kekuningan).
        final yellowedRice = img.Image(width: 160, height: 160);
        for (var y = 0; y < 160; y++) {
          for (var x = 0; x < 160; x++) {
            final inCenterPatch = x >= 45 && x < 115 && y >= 55 && y < 120;
            if (inCenterPatch) {
              // Pale-yellowish spoiled rice clump
              yellowedRice.setPixelRgb(x, y, 222, 206, 152);
            } else {
              // Clean neutral white rice / tray perimeter
              yellowedRice.setPixelRgb(x, y, 214, 212, 204);
            }
          }
        }
        final yellowPng = Uint8List.fromList(img.encodePng(yellowedRice));
        final yellowRes = await service.analyzeOnDevice(yellowPng);
        expect(yellowRes.label, OnDeviceVisualLabel.suspiciousDiscoloration);
        expect(yellowRes.summaryText, contains('kekuningan'));
        expect(yellowRes.summaryText, isNot(contains('TFLite')));

        // 1c) Papaya pieces with fuzzy white mold spots & charred spots on fried tofu.
        final moldyPapayaCharredTofu = img.Image(width: 160, height: 160);
        for (var y = 0; y < 160; y++) {
          for (var x = 0; x < 160; x++) {
            if (x < 80) {
              // Orange-coral papaya cubes with crisp white mold colonies
              final isWhiteMold = x >= 28 && x < 46 && y >= 50 && y < 74;
              if (isWhiteMold) {
                moldyPapayaCharredTofu.setPixelRgb(x, y, 224, 222, 218);
              } else {
                moldyPapayaCharredTofu.setPixelRgb(x, y, 206, 98, 56);
              }
            } else {
              // Warm golden-brown fried tofu with blackened charred patch
              final isCharredPatch = x >= 104 && x < 126 && y >= 52 && y < 76;
              if (isCharredPatch) {
                moldyPapayaCharredTofu.setPixelRgb(x, y, 22, 20, 18);
              } else {
                moldyPapayaCharredTofu.setPixelRgb(x, y, 168, 114, 58);
              }
            }
          }
        }
        final defectPng = Uint8List.fromList(
          img.encodePng(moldyPapayaCharredTofu),
        );
        final defectRes = await service.analyzeOnDevice(defectPng);
        expect(defectRes.label, OnDeviceVisualLabel.suspiciousDiscoloration);
        expect(defectRes.summaryText, contains('jamur'));
        expect(defectRes.summaryText, contains('gosong'));

        // 2) Blurry camera photo of spoiled/slimy food (dark dull oxidation + wet slime glare clusters).
        final blurrySpoiled = img.Image(width: 160, height: 160);
        for (var y = 0; y < 160; y++) {
          for (var x = 0; x < 160; x++) {
            final isSlimeSpot = ((x ~/ 8) + (y ~/ 8)) % 4 == 0;
            if (isSlimeSpot) {
              blurrySpoiled.setPixelRgb(x, y, 246, 248, 245);
            } else {
              blurrySpoiled.setPixelRgb(x, y, 38, 42, 36);
            }
          }
        }
        final spoiledPng = Uint8List.fromList(img.encodePng(blurrySpoiled));
        final spoiledRes = await service.analyzeOnDevice(spoiledPng);
        expect(spoiledRes.usedTfliteModel, isTrue);
        expect(spoiledRes.label, OnDeviceVisualLabel.suspiciousDiscoloration);

        // 3) Blurry tray photo plate-waste estimation (empty stainless tray rim + leftover veg).
        final blurryTray = img.Image(width: 160, height: 160);
        for (var y = 0; y < 160; y++) {
          for (var x = 0; x < 160; x++) {
            if (x > 55 && x < 125 && y > 55 && y < 125) {
              // Leftover green vegetable patch
              blurryTray.setPixelRgb(x, y, 70, 148, 68);
            } else {
              // Warm-tinted stainless steel tray background
              blurryTray.setPixelRgb(x, y, 168, 164, 154);
            }
          }
        }
        final trayPng = Uint8List.fromList(img.encodePng(blurryTray));
        final wasteRes = await service.estimatePlateWasteOnDevice([trayPng]);
        expect(wasteRes.estimatedVegWastePct, greaterThan(0));
        expect(wasteRes.estimatedCarbWastePct, equals(0));

        // 4) Realistic multi-compartment ompreng with lots of leftover rice, chicken, and green-bean/carrot veggies.
        final fullLeftoverOmpreng = img.Image(width: 160, height: 160);
        for (var y = 0; y < 160; y++) {
          for (var x = 0; x < 160; x++) {
            final grain = ((x + y) % 2 == 0) ? 14 : -14;
            if (x < 22 || x >= 138 || y < 22 || y >= 138) {
              // Brown wooden school desk border
              fullLeftoverOmpreng.setPixelRgb(x, y, 148, 102, 68);
            } else if (x >= 28 && x < 64 && y >= 28 && y < 68) {
              // Top-left protein compartment (fried chicken)
              fullLeftoverOmpreng.setPixelRgb(x, y, 138, 84, 42);
            } else if (x >= 68 && x < 104 && y >= 28 && y < 68) {
              // Top-center vegetable compartment (green beans & carrots)
              if ((x + y) % 5 == 0) {
                fullLeftoverOmpreng.setPixelRgb(x, y, 198, 96, 36);
              } else {
                fullLeftoverOmpreng.setPixelRgb(x, y, 54, 108, 46);
              }
            } else if (x >= 66 && x < 132 && y >= 76 && y < 132) {
              // Bottom-right white rice compartment (textured ivory rice grains)
              fullLeftoverOmpreng.setPixelRgb(
                x,
                y,
                (214 + grain).clamp(0, 255),
                (208 + grain).clamp(0, 255),
                (192 + grain).clamp(0, 255),
              );
            } else {
              // Clean stainless steel tray separator/empty corner
              fullLeftoverOmpreng.setPixelRgb(x, y, 168, 168, 168);
            }
          }
        }
        final omprengPng = Uint8List.fromList(img.encodePng(fullLeftoverOmpreng));
        final omprengWaste = await service.estimatePlateWasteOnDevice([omprengPng]);
        expect(omprengWaste.estimatedVegWastePct, greaterThanOrEqualTo(50));
        expect(omprengWaste.estimatedProteinWastePct, greaterThanOrEqualTo(25));
        expect(omprengWaste.estimatedCarbWastePct, greaterThanOrEqualTo(50));

        // 5) Realistic clean fried-chicken ompreng with natural compartment shadows
        //    (must NOT false-alarm as gosong menghitam or mold).
        final normalFriedChickenTray = img.Image(width: 160, height: 160);
        for (var y = 0; y < 160; y++) {
          for (var x = 0; x < 160; x++) {
            if (x < 22 || x >= 138 || y < 22 || y >= 138) {
              normalFriedChickenTray.setPixelRgb(x, y, 146, 98, 62);
            } else if (x >= 28 && x < 64 && y >= 28 && y < 68) {
              // Fried chicken inside deep stainless compartment with rim shadow (luma ~34..42)
              final inRimShadow = x < 34 || y < 34;
              if (inRimShadow) {
                normalFriedChickenTray.setPixelRgb(x, y, 42, 34, 28);
              } else {
                normalFriedChickenTray.setPixelRgb(x, y, 142, 82, 38);
              }
            } else if (x >= 68 && x < 104 && y >= 28 && y < 68) {
              // Stir-fried green beans & carrot slices
              if ((x + y) % 6 == 0) {
                normalFriedChickenTray.setPixelRgb(x, y, 204, 102, 42);
              } else {
                normalFriedChickenTray.setPixelRgb(x, y, 58, 118, 48);
              }
            } else if (x >= 66 && x < 132 && y >= 76 && y < 132) {
              normalFriedChickenTray.setPixelRgb(x, y, 224, 222, 218);
            } else {
              normalFriedChickenTray.setPixelRgb(x, y, 172, 174, 176);
            }
          }
        }
        final normalTrayPng = Uint8List.fromList(
          img.encodePng(normalFriedChickenTray),
        );
        final normalTrayRes = await service.analyzeOnDevice(normalTrayPng);
        expect(normalTrayRes.label, OnDeviceVisualLabel.freshLikely);
        expect(normalTrayRes.localHints, isEmpty);

        // 6) Real photo of a normal MBG tray (fried chicken, green beans and
        //    carrots, banana, rice, milk carton on a wooden desk). Reported
        //    false alarm: "bagian gosong menghitam pada lauk".
        final realTrayBytes = File(
          'test/fixtures/normal_mbg_tray.jpg',
        ).readAsBytesSync();
        final realTrayRes = await service.analyzeOnDevice(realTrayBytes);
        expect(realTrayRes.label, OnDeviceVisualLabel.freshLikely);
        expect(realTrayRes.localHints, isEmpty);
        expect(realTrayRes.summaryText, isNot(contains('gosong')));

        // 7) Telur dadar & tahu kuning + nasi putih + sayur bayam
        final omeletteTray = img.Image(width: 160, height: 160);
        for (var y = 0; y < 160; y++) {
          for (var x = 0; x < 160; x++) {
            if (x < 22 || x >= 138 || y < 22 || y >= 138) {
              omeletteTray.setPixelRgb(x, y, 146, 98, 62);
            } else if (x >= 28 && x < 64 && y >= 28 && y < 68) {
              omeletteTray.setPixelRgb(x, y, 216, 194, 128);
            } else if (x >= 68 && x < 104 && y >= 28 && y < 68) {
              omeletteTray.setPixelRgb(x, y, 54, 114, 48);
            } else if (x >= 66 && x < 132 && y >= 76 && y < 132) {
              omeletteTray.setPixelRgb(x, y, 224, 222, 218);
            } else {
              omeletteTray.setPixelRgb(x, y, 170, 172, 174);
            }
          }
        }
        final omeletteRes = await service.analyzeOnDevice(
          Uint8List.fromList(img.encodePng(omeletteTray)),
        );
        expect(omeletteRes.label, OnDeviceVisualLabel.freshLikely);
        expect(omeletteRes.localHints, isEmpty);

        // 8) Ikan kembung perak/goreng dengan kilap kulit + nasi putih + sayur
        final fishTray = img.Image(width: 160, height: 160);
        for (var y = 0; y < 160; y++) {
          for (var x = 0; x < 160; x++) {
            if (x < 22 || x >= 138 || y < 22 || y >= 138) {
              fishTray.setPixelRgb(x, y, 146, 98, 62);
            } else if (x >= 28 && x < 64 && y >= 28 && y < 68) {
              if (y < 36) {
                fishTray.setPixelRgb(x, y, 44, 48, 54);
              } else if ((x + y) % 11 == 0) {
                fishTray.setPixelRgb(x, y, 240, 242, 244);
              } else {
                fishTray.setPixelRgb(x, y, 126, 130, 134);
              }
            } else if (x >= 68 && x < 104 && y >= 28 && y < 68) {
              fishTray.setPixelRgb(x, y, 58, 118, 48);
            } else if (x >= 66 && x < 132 && y >= 76 && y < 132) {
              fishTray.setPixelRgb(x, y, 224, 222, 218);
            } else {
              fishTray.setPixelRgb(x, y, 170, 172, 174);
            }
          }
        }
        final fishRes = await service.analyzeOnDevice(
          Uint8List.fromList(img.encodePng(fishTray)),
        );
        expect(fishRes.label, OnDeviceVisualLabel.freshLikely);
        expect(fishRes.localHints, isEmpty);

        // 9) Sayur lodeh / bobor bayam bersantan + tahu putih + tempe goreng + nasi putih
        final lodehTray = img.Image(width: 160, height: 160);
        for (var y = 0; y < 160; y++) {
          for (var x = 0; x < 160; x++) {
            if (x < 22 || x >= 138 || y < 22 || y >= 138) {
              lodehTray.setPixelRgb(x, y, 146, 98, 62);
            } else if (x >= 28 && x < 64 && y >= 28 && y < 68) {
              lodehTray.setPixelRgb(x, y, 154, 98, 48);
            } else if (x >= 68 && x < 104 && y >= 28 && y < 68) {
              if ((x + y) % 5 == 0) {
                lodehTray.setPixelRgb(x, y, 52, 112, 46);
              } else if ((x + y) % 7 == 0) {
                lodehTray.setPixelRgb(x, y, 228, 226, 218);
              } else {
                lodehTray.setPixelRgb(x, y, 218, 210, 174);
              }
            } else if (x >= 66 && x < 132 && y >= 76 && y < 132) {
              lodehTray.setPixelRgb(x, y, 224, 222, 218);
            } else {
              lodehTray.setPixelRgb(x, y, 170, 172, 174);
            }
          }
        }
        final lodehRes = await service.analyzeOnDevice(
          Uint8List.fromList(img.encodePng(lodehTray)),
        );
        expect(lodehRes.label, OnDeviceVisualLabel.freshLikely);
        expect(lodehRes.localHints, isEmpty);

        // 10) Telur rebus belah + opor ayam kuah santan + nasi putih
        final oporEggTray = img.Image(width: 160, height: 160);
        for (var y = 0; y < 160; y++) {
          for (var x = 0; x < 160; x++) {
            if (x < 22 || x >= 138 || y < 22 || y >= 138) {
              oporEggTray.setPixelRgb(x, y, 146, 98, 62);
            } else if (x >= 28 && x < 64 && y >= 28 && y < 68) {
              final inYolk = x >= 40 && x < 52 && y >= 42 && y < 54;
              if (inYolk) {
                oporEggTray.setPixelRgb(x, y, 230, 190, 72);
              } else {
                oporEggTray.setPixelRgb(x, y, 234, 232, 224);
              }
            } else if (x >= 68 && x < 104 && y >= 28 && y < 68) {
              if ((x + y) % 4 == 0) {
                oporEggTray.setPixelRgb(x, y, 168, 118, 66);
              } else {
                oporEggTray.setPixelRgb(x, y, 220, 206, 156);
              }
            } else if (x >= 66 && x < 132 && y >= 76 && y < 132) {
              oporEggTray.setPixelRgb(x, y, 224, 222, 218);
            } else {
              oporEggTray.setPixelRgb(x, y, 170, 172, 174);
            }
          }
        }
        final oporEggRes = await service.analyzeOnDevice(
          Uint8List.fromList(img.encodePng(oporEggTray)),
        );
        expect(oporEggRes.label, OnDeviceVisualLabel.freshLikely);
        expect(oporEggRes.localHints, isEmpty);
      },
    );
  });
}
