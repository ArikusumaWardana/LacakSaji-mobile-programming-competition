import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lacak_saji/core/crypto/batch_qr_payload.dart';
import 'package:lacak_saji/core/crypto/ed25519_service.dart';
import 'package:lacak_saji/core/database/app_database.dart';
import 'package:lacak_saji/core/database/database_provider.dart';
import 'package:lacak_saji/core/media/live_camera_webp_service.dart';
import 'package:lacak_saji/core/network/connectivity_provider.dart';
import 'package:lacak_saji/core/network/supabase_provider.dart';
import 'package:lacak_saji/core/theme/text_scale_provider.dart';
import 'package:lacak_saji/features/auth/data/auth_repository.dart';
import 'package:lacak_saji/features/auth/domain/auth_models.dart';
import 'package:lacak_saji/features/auth/presentation/auth_controller.dart';
import 'package:lacak_saji/features/kitchen/data/batch_export_service.dart';
import 'package:lacak_saji/features/kitchen/data/kitchen_repository.dart';
import 'package:lacak_saji/features/kitchen/domain/kitchen_models.dart';
import 'package:lacak_saji/features/kitchen/presentation/kitchen_providers.dart';
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

class _Stage3AuthRepository implements AuthRepository {
  _Stage3AuthRepository(this.session);

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

class _FakeLiveCameraService implements LiveCameraWebpService {
  int captureCalls = 0;

  @override
  Future<CapturedWebpPhoto?> captureAndCompress() async {
    captureCalls++;
    final tempDir = Directory.systemTemp.createTempSync('lacak_cam_test_');
    final file = File('${tempDir.path}/capture_$captureCalls.webp');
    file.writeAsBytesSync(_validTinyWebpBytes);
    return CapturedWebpPhoto(
      filePath: file.path,
      bytes: _validTinyWebpBytes,
      sizeBytes: _validTinyWebpBytes.length,
    );
  }
}

class _FakeBatchExportService implements BatchExportService {
  FoodBatchItem? sharedPngBatch;
  Uint8List? sharedPngBytes;
  FoodBatchItem? exportedPdfBatch;

  @override
  Future<Uint8List> buildPrintableLabelPdfBytes(FoodBatchItem batch) {
    return DeviceBatchExportService().buildPrintableLabelPdfBytes(batch);
  }

  @override
  Future<String> exportAndSharePrintableLabelPdf(FoodBatchItem batch) async {
    exportedPdfBatch = batch;
    return '/tmp/label_${batch.batchCode}.pdf';
  }

  @override
  Future<String> shareDigitalWaybillPng({
    required FoodBatchItem batch,
    required Uint8List pngBytes,
  }) async {
    sharedPngBatch = batch;
    sharedPngBytes = pngBytes;
    return '/tmp/surat_jalan_${batch.batchCode}.png';
  }
}

class _FakeKitchenRepository implements KitchenRepository {
  _FakeKitchenRepository({required this.nowUtc}) {
    final oneDayAgo = nowUtc.subtract(const Duration(days: 1));
    final twoDaysAgo = nowUtc.subtract(const Duration(days: 2));

    _batches.addAll([
      FoodBatchItem(
        id: 'b-hist-1',
        sppgId: 'a1000000-0000-4000-8000-000000000001',
        sppgName: 'SPPG Purwokerto Utara',
        batchCode: 'BCH-2611-01A',
        menuName: 'Nasi Ayam Goreng & Tumis Buncis',
        portionCount: 160,
        riskCategory: FoodRiskCategory.medium,
        sealedAtUtc: oneDayAgo,
        timestampSource: BatchTimestampSource.serverVerified,
        signatureB64: 'sig-hist-1',
        createdAtUtc: oneDayAgo,
        inspectedSchoolIds: const ['s-1'],
      ),
      FoodBatchItem(
        id: 'b-hist-2',
        sppgId: 'a1000000-0000-4000-8000-000000000001',
        sppgName: 'SPPG Purwokerto Utara',
        batchCode: 'BCH-2611-01B',
        menuName: 'Nasi Soto Ayam Santan & Pisang',
        portionCount: 150,
        riskCategory: FoodRiskCategory.high,
        sealedAtUtc: twoDaysAgo,
        timestampSource: BatchTimestampSource.serverVerified,
        signatureB64: 'sig-hist-2',
        createdAtUtc: twoDaysAgo,
        inspectedSchoolIds: const ['s-2'],
      ),
    ]);

    _schools.addAll([
      PartnerSchoolItem(
        id: 's-pending-1',
        sppgId: 'a1000000-0000-4000-8000-000000000001',
        npsn: '20301904',
        name: 'SDN 4 Purwokerto',
        adm4Code: '33.02.26.1004',
        puskesmasWa: '628112800004',
        verificationStatus: SchoolVerificationStatus.pending,
        dailyStatus: SchoolDailyStatus.notScanned,
        createdAtUtc: oneDayAgo,
      ),
      PartnerSchoolItem(
        id: 's-pending-2',
        sppgId: 'a1000000-0000-4000-8000-000000000001',
        npsn: '20301905',
        name: 'SDN 5 Purwokerto',
        adm4Code: '33.02.26.1001',
        puskesmasWa: '628112800005',
        verificationStatus: SchoolVerificationStatus.pending,
        dailyStatus: SchoolDailyStatus.notScanned,
        createdAtUtc: oneDayAgo,
      ),
      PartnerSchoolItem(
        id: 's-1',
        sppgId: 'a1000000-0000-4000-8000-000000000001',
        npsn: '20301901',
        name: 'SDN 1 Purwokerto',
        adm4Code: '33.02.26.1001',
        puskesmasWa: '628112800001',
        verificationStatus: SchoolVerificationStatus.approved,
        dailyStatus: SchoolDailyStatus.received,
        createdAtUtc: twoDaysAgo,
        lastScannedAtUtc: nowUtc.subtract(const Duration(hours: 1)),
      ),
      PartnerSchoolItem(
        id: 's-2',
        sppgId: 'a1000000-0000-4000-8000-000000000001',
        npsn: '20301902',
        name: 'SDN 2 Purwokerto',
        adm4Code: '33.02.26.1003',
        puskesmasWa: '628112800002',
        verificationStatus: SchoolVerificationStatus.approved,
        dailyStatus: SchoolDailyStatus.notScanned,
        createdAtUtc: twoDaysAgo,
      ),
    ]);

    _wasteLogs.addAll([
      PlateWasteLogItem(
        id: 'w-1',
        batchId: 'b-hist-1',
        batchCode: 'BCH-2611-01A',
        menuName: 'Nasi Ayam Goreng & Tumis Buncis',
        schoolId: 's-1',
        schoolName: 'SDN 1 Purwokerto',
        carbWastePct: 15,
        proteinWastePct: 10,
        vegWastePct: 45,
        aiAssisted: true,
        createdAtUtc: oneDayAgo,
      ),
      PlateWasteLogItem(
        id: 'w-2',
        batchId: 'b-hist-1',
        batchCode: 'BCH-2611-01A',
        menuName: 'Nasi Ayam Goreng & Tumis Buncis',
        schoolId: 's-2',
        schoolName: 'SDN 2 Purwokerto',
        carbWastePct: 20,
        proteinWastePct: 15,
        vegWastePct: 50,
        aiAssisted: true,
        createdAtUtc: oneDayAgo,
      ),
      PlateWasteLogItem(
        id: 'w-3',
        batchId: 'b-hist-2',
        batchCode: 'BCH-2611-01B',
        menuName: 'Nasi Soto Ayam Santan & Pisang',
        schoolId: 's-1',
        schoolName: 'SDN 1 Purwokerto',
        carbWastePct: 10,
        proteinWastePct: 20,
        vegWastePct: 40,
        aiAssisted: true,
        createdAtUtc: twoDaysAgo,
      ),
    ]);
  }

  final DateTime nowUtc;
  final List<FoodBatchItem> _batches = [];
  final List<PartnerSchoolItem> _schools = [];
  final List<PlateWasteLogItem> _wasteLogs = [];

  @override
  Future<KitchenDashboardData> fetchDashboard({
    required KitchenProfile kitchen,
  }) async {
    final todayBatches = _batches
        .where((b) => isSameWibCalendarDay(b.sealedAtUtc, nowUtc))
        .toList(growable: false);
    final approvedCount = _schools
        .where((s) => s.verificationStatus == SchoolVerificationStatus.approved)
        .length;
    final pendingCount = _schools
        .where((s) => s.verificationStatus == SchoolVerificationStatus.pending)
        .length;

    return KitchenDashboardData(
      kitchen: kitchen,
      todayBatches: todayBatches,
      todayReceivedSchoolsCount: 1,
      approvedSchoolsCount: approvedCount,
      pendingSchoolsCount: pendingCount,
      activeAlertsToday: const [],
      weeklyWasteSummary: PlateWasteSummary.fromLogs(_wasteLogs),
    );
  }

  @override
  Future<List<PartnerSchoolItem>> fetchPartnerSchools({
    required String sppgId,
  }) async => List.unmodifiable(_schools);

  @override
  Future<void> reviewSchool({
    required String sppgId,
    required String schoolId,
    required SchoolVerificationStatus decision,
  }) async {
    final index = _schools.indexWhere((s) => s.id == schoolId);
    if (index == -1) {
      throw StateError('School not found');
    }
    final old = _schools[index];
    _schools[index] = PartnerSchoolItem(
      id: old.id,
      sppgId: old.sppgId,
      npsn: old.npsn,
      name: old.name,
      adm4Code: old.adm4Code,
      puskesmasWa: old.puskesmasWa,
      verificationStatus: decision,
      dailyStatus: old.dailyStatus,
      createdAtUtc: old.createdAtUtc,
      lastScannedAtUtc: old.lastScannedAtUtc,
    );
  }

  @override
  Future<KitchenHistoryData> fetchHistoryAndWaste({
    required KitchenProfile kitchen,
    required HistoryTimeRange range,
  }) async {
    final cutoff = range == HistoryTimeRange.today
        ? nowUtc.subtract(const Duration(hours: 6))
        : nowUtc.subtract(Duration(days: range.days));
    final filteredBatches = _batches
        .where((b) => !b.sealedAtUtc.isBefore(cutoff))
        .toList(growable: false);
    final filteredLogs = _wasteLogs
        .where((w) => !w.createdAtUtc.isBefore(cutoff))
        .toList(growable: false);

    return KitchenHistoryData(
      range: range,
      batches: filteredBatches,
      wasteLogs: filteredLogs,
      wasteSummary: PlateWasteSummary.fromLogs(filteredLogs),
    );
  }

  @override
  Future<FoodBatchItem?> fetchBatchById({
    required KitchenProfile kitchen,
    required String batchId,
  }) async {
    for (final b in _batches) {
      if (b.id == batchId) {
        return b;
      }
    }
    return null;
  }

  @override
  Future<FoodBatchItem> createSealedBatch({
    required KitchenProfile kitchen,
    required String menuName,
    required int portionCount,
    required FoodRiskCategory riskCategory,
    required CapturedWebpPhoto photo,
    required bool isOffline,
  }) async {
    final created = FoodBatchItem(
      id: 'b-created-${_batches.length + 1}',
      sppgId: kitchen.id,
      sppgName: kitchen.name,
      batchCode: 'BCH-2611-21T${_batches.length + 1}',
      menuName: menuName,
      portionCount: portionCount,
      riskCategory: riskCategory,
      sealedAtUtc: nowUtc,
      timestampSource: isOffline
          ? BatchTimestampSource.offlineUnverified
          : BatchTimestampSource.serverVerified,
      packagingPhotoUrl: 'batches/${kitchen.id}/created.webp',
      localPhotoPath: photo.filePath,
      signatureB64: 'signed-ed25519-test',
      createdAtUtc: nowUtc,
      isPendingSync: isOffline,
    );
    _batches.insert(0, created);
    return created;
  }

  @override
  Future<int> syncPendingKitchenBatches({
    required KitchenProfile kitchen,
  }) async => 0;

  @override
  Future<String?> createSignedPhotoUrl(String storagePath) async => null;
}

const KitchenProfile _demoKitchen = KitchenProfile(
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

const AuthSessionSnapshot _kitchenSession = AuthSessionSnapshot(
  profile: UserProfile(
    id: '10000000-0000-4000-8000-000000000001',
    email: 'dapur.a@lacaksaji.id',
    role: UserRole.kitchen,
    fullName: 'Ibu Ratna (Petugas SPPG Purwokerto Utara)',
  ),
  kitchen: _demoKitchen,
);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Stage 3 Cryptography, Export & Analytics Logic', () {
    test(
      'Ed25519Service generates keypair, signs payload, verifies offline, and detects tampering',
      () async {
        final store = _InMemorySecureKeyStore();
        final service = Ed25519Service(secureStore: store);

        String? syncedKey;
        final publicKey = await service.ensureKeyPairSynced(
          sppgId: 'sppg-001',
          remotePublicKeyB64: 'stale-demo-key',
          onSyncRemotePublicKey: (key) async {
            syncedKey = key;
          },
        );
        expect(syncedKey, publicKey);

        // Calling again when remote matches must not rewrite remote public key.
        var syncTriggered = false;
        await service.ensureKeyPairSynced(
          sppgId: 'sppg-001',
          remotePublicKeyB64: publicKey,
          onSyncRemotePublicKey: (_) async {
            syncTriggered = true;
          },
        );
        expect(syncTriggered, isFalse);

        final canonical = BatchQrPayload.buildCanonicalSigningString(
          batchId: 'batch-1',
          batchCode: 'BCH-2611-21A1',
          sppgId: 'sppg-001',
          menuName: 'Nasi Ayam Suwir',
          riskCategory: 'HIGH',
          sealedAtEpochSec: 1795238400,
          timestampSource: 'server_verified',
        );
        final signature = await service.signCanonicalPayload(
          sppgId: 'sppg-001',
          canonicalData: canonical,
        );

        final payloadJson = BatchQrPayload(
          batchId: 'batch-1',
          batchCode: 'BCH-2611-21A1',
          sppgId: 'sppg-001',
          menuName: 'Nasi Ayam Suwir',
          riskCategory: 'HIGH',
          sealedAtEpochSec: 1795238400,
          timestampSource: 'server_verified',
          signatureB64: signature,
        ).toMinifiedJson();

        final parsed = BatchQrPayload.tryParse(payloadJson);
        expect(parsed, isNotNull);

        expect(
          await service.verifyCanonicalPayload(
            canonicalData: parsed!.toCanonicalSigningString(),
            signatureB64: parsed.signatureB64,
            publicKeyB64: publicKey,
          ),
          isTrue,
        );

        final tampered = BatchQrPayload(
          batchId: parsed.batchId,
          batchCode: parsed.batchCode,
          sppgId: parsed.sppgId,
          menuName: parsed.menuName,
          riskCategory: 'LOW',
          sealedAtEpochSec: parsed.sealedAtEpochSec,
          timestampSource: parsed.timestampSource,
          signatureB64: parsed.signatureB64,
        );
        expect(
          await service.verifyCanonicalPayload(
            canonicalData: tampered.toCanonicalSigningString(),
            signatureB64: tampered.signatureB64,
            publicKeyB64: publicKey,
          ),
          isFalse,
        );
      },
    );

    test(
      'Offline batch creation writes Ed25519 signature and offlineUnverified entry to Drift sync queue',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final store = _InMemorySecureKeyStore();
        final crypto = Ed25519Service(secureStore: store);
        final repo = SupabaseKitchenRepository(
          client: null,
          database: db,
          ed25519Service: crypto,
        );

        final tempFile = File(
          '${Directory.systemTemp.createTempSync('lacak_offline_').path}/sample.webp',
        )..writeAsBytesSync(_validTinyWebpBytes);

        final batch = await repo.createSealedBatch(
          kitchen: _demoKitchen,
          menuName: 'Nasi Tumis Buncis',
          portionCount: 120,
          riskCategory: FoodRiskCategory.medium,
          photo: CapturedWebpPhoto(
            filePath: tempFile.path,
            bytes: _validTinyWebpBytes,
            sizeBytes: _validTinyWebpBytes.length,
          ),
          isOffline: true,
        );

        expect(batch.isPendingSync, isTrue);
        expect(batch.timestampSource, BatchTimestampSource.offlineUnverified);
        expect(
          await db.watchPendingSyncCount().first,
          1,
        );

        final pubKey = await crypto.getOrCreatePublicKeyB64(
          sppgId: _demoKitchen.id,
          legacyUserId: _demoKitchen.ownerUserId,
        );
        final parsed = BatchQrPayload.tryParse(batch.qrPayloadJson)!;
        expect(
          await crypto.verifyCanonicalPayload(
            canonicalData: parsed.toCanonicalSigningString(),
            signatureB64: parsed.signatureB64,
            publicKeyB64: pubKey,
          ),
          isTrue,
        );

        final history = await repo.fetchHistoryAndWaste(
          kitchen: _demoKitchen,
          range: HistoryTimeRange.today,
        );
        expect(history.batches.length, 1);
        expect(history.batches.first.batchCode, batch.batchCode);
      },
    );

    test(
      'PlateWasteSummary computes component averages and triggers >= 40% advice',
      () {
        final now = DateTime.now().toUtc();
        final summaryHighVeg = PlateWasteSummary.fromLogs([
          PlateWasteLogItem(
            id: '1',
            batchId: 'b1',
            batchCode: 'B1',
            menuName: 'Menu 1',
            schoolId: 's1',
            schoolName: 'SD 1',
            carbWastePct: 15,
            proteinWastePct: 10,
            vegWastePct: 45,
            aiAssisted: true,
            createdAtUtc: now,
          ),
          PlateWasteLogItem(
            id: '2',
            batchId: 'b1',
            batchCode: 'B1',
            menuName: 'Menu 1',
            schoolId: 's2',
            schoolName: 'SD 2',
            carbWastePct: 25,
            proteinWastePct: 20,
            vegWastePct: 55,
            aiAssisted: true,
            createdAtUtc: now,
          ),
        ]);
        expect(summaryHighVeg.avgCarbPct, 20);
        expect(summaryHighVeg.avgProteinPct, 15);
        expect(summaryHighVeg.avgVegPct, 50);
        expect(summaryHighVeg.hasHighWasteAlert, isTrue);
        expect(
          summaryHighVeg.recommendations.first,
          contains('sayuran mencapai 50%'),
        );

        final summaryBalanced = PlateWasteSummary.fromLogs([
          PlateWasteLogItem(
            id: '3',
            batchId: 'b2',
            batchCode: 'B2',
            menuName: 'Menu 2',
            schoolId: 's1',
            schoolName: 'SD 1',
            carbWastePct: 10,
            proteinWastePct: 5,
            vegWastePct: 20,
            aiAssisted: false,
            createdAtUtc: now,
          ),
        ]);
        expect(summaryBalanced.hasHighWasteAlert, isFalse);
      },
    );

    test(
      'DeviceBatchExportService generates valid printable PDF bytes',
      () async {
        final now = DateTime.utc(2026, 11, 21, 5, 0);
        final batch = FoodBatchItem(
          id: 'b-pdf-1',
          sppgId: _demoKitchen.id,
          sppgName: _demoKitchen.name,
          batchCode: 'BCH-2611-21PDF',
          menuName: 'Nasi Ayam Goreng & Tumis Buncis',
          portionCount: 160,
          riskCategory: FoodRiskCategory.medium,
          sealedAtUtc: now,
          timestampSource: BatchTimestampSource.serverVerified,
          signatureB64: 'test_sig_b64',
          createdAtUtc: now,
        );

        final pdfBytes =
            await DeviceBatchExportService().buildPrintableLabelPdfBytes(batch);
        expect(pdfBytes.length, greaterThan(500));
        expect(ascii.decode(pdfBytes.take(5).toList()), '%PDF-');
      },
    );
  });

  group('Stage 3 Kitchen UI Flows (D01 - D05)', () {
    Future<void> pumpKitchenApp(
      WidgetTester tester, {
      required _FakeKitchenRepository repo,
      required _FakeLiveCameraService camera,
      required _FakeBatchExportService exportService,
      Size screenSize = const Size(390, 844),
      bool isOffline = false,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      tester.view.physicalSize = screenSize;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            isSupabaseReadyProvider.overrideWithValue(true),
            authRepositoryProvider.overrideWithValue(
              _Stage3AuthRepository(_kitchenSession),
            ),
            kitchenRepositoryProvider.overrideWithValue(repo),
            liveCameraWebpServiceProvider.overrideWithValue(camera),
            batchExportServiceProvider.overrideWithValue(exportService),
            waybillPngCapturerProvider.overrideWithValue(
              (_) async => Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
            ),
            isOfflineProvider.overrideWith((ref) => Stream.value(isOffline)),
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
          ],
          child: const LacakSajiApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'D01 -> D02 -> D03 creates live-camera WebP batch, displays QR seal, and exports PNG & PDF',
      (tester) async {
        final repo = _FakeKitchenRepository(nowUtc: DateTime.now().toUtc());
        final camera = _FakeLiveCameraService();
        final exporter = _FakeBatchExportService();

        await pumpKitchenApp(
          tester,
          repo: repo,
          camera: camera,
          exportService: exporter,
        );

        expect(find.text('Beranda Dapur SPPG'), findsOneWidget);
        expect(find.text('2 Sekolah Menunggu Persetujuan'), findsOneWidget);
        expect(find.text('Belum ada batch hari ini'), findsOneWidget);

        await tester.ensureVisible(find.text('Buat QR Segel Batch Baru'));
        await tester.tap(find.text('Buat QR Segel Batch Baru'));
        await tester.pumpAndSettle();

        expect(find.text('Buat Batch & Segel QR'), findsOneWidget);
        expect(find.text('Langkah 1 dari 2'), findsOneWidget);

        // Verify Step 1 blocks advancing before menu name is valid.
        await tester.tap(find.text('Simpan & Lanjut ke Foto Pengemasan'));
        await tester.pumpAndSettle();
        expect(
          find.text('Masukkan nama menu minimal 3 karakter.'),
          findsOneWidget,
        );

        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            'Contoh: Nasi Ayam Goreng & Sayur Bening',
          ),
          'Nasi Opor Ayam Santan',
        );
        await tester.tap(find.byTooltip('Tambah 10 porsi'));
        await tester.pumpAndSettle();
        expect(find.text('160'), findsOneWidget);

        await tester.ensureVisible(find.text('Risiko Tinggi'));
        await tester.tap(find.text('Risiko Tinggi'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Simpan & Lanjut ke Foto Pengemasan'));
        await tester.pumpAndSettle();
        expect(find.text('Langkah 2 dari 2'), findsOneWidget);

        // Verify Step 2 blocks sealing before live camera photo is captured.
        await tester.tap(find.text('Kunci & Buat QR Segel'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Foto pengemasan wajib diambil langsung'),
          findsOneWidget,
        );

        await tester.ensureVisible(find.text('Ambil Foto Pengemasan'));
        await tester.tap(find.text('Ambil Foto Pengemasan'));
        await tester.pumpAndSettle();
        expect(camera.captureCalls, 1);
        expect(find.textContaining('Foto pengemasan siap'), findsOneWidget);

        await tester.tap(find.text('Kunci & Buat QR Segel'));
        await tester.pumpAndSettle();

        expect(find.text('Kartu QR Segel & Surat Jalan'), findsOneWidget);
        expect(find.text('Nasi Opor Ayam Santan'), findsOneWidget);
        expect(find.text('Segel Digital Asli'), findsOneWidget);
        expect(find.text('Waktu Resmi Server'), findsOneWidget);
        expect(find.byType(QrImageView), findsOneWidget);

        await tester.ensureVisible(
          find.text('Bagikan ke WhatsApp Kurir (Gambar)'),
        );
        await tester.tap(find.text('Bagikan ke WhatsApp Kurir (Gambar)'));
        await tester.pumpAndSettle();
        expect(exporter.sharedPngBatch?.menuName, 'Nasi Opor Ayam Santan');
        expect(exporter.sharedPngBytes, isNotEmpty);

        await tester.ensureVisible(find.text('Simpan Label Siap Cetak (PDF)'));
        await tester.tap(find.text('Simpan Label Siap Cetak (PDF)'));
        await tester.pumpAndSettle();
        expect(exporter.exportedPdfBatch?.menuName, 'Nasi Opor Ayam Santan');

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'D04 manages SPPG invite code QR and approves or rejects pending schools',
      (tester) async {
        final repo = _FakeKitchenRepository(nowUtc: DateTime.now().toUtc());
        await pumpKitchenApp(
          tester,
          repo: repo,
          camera: _FakeLiveCameraService(),
          exportService: _FakeBatchExportService(),
        );

        await tester.tap(find.text('Sekolah'));
        await tester.pumpAndSettle();

        expect(find.text('Sekolah Binaan'), findsOneWidget);
        expect(find.text('SPPG-PWT-01'), findsOneWidget);
        expect(find.text('Menunggu Persetujuan (2)'), findsOneWidget);
        expect(find.text('SDN 4 Purwokerto'), findsOneWidget);
        expect(find.text('SDN 5 Purwokerto'), findsOneWidget);

        // Open Profile QR modal.
        await tester.tap(find.text('Tampilkan QR Profil'));
        await tester.pumpAndSettle();
        expect(find.text('QR Profil Mitra SPPG'), findsOneWidget);
        await tester.tap(find.text('Tutup'));
        await tester.pumpAndSettle();

        // Approve the first pending school (SDN 4 Purwokerto).
        await tester.ensureVisible(find.text('Setujui').first);
        await tester.tap(find.text('Setujui').first);
        await tester.pumpAndSettle();
        expect(find.text('Menunggu Persetujuan (1)'), findsOneWidget);
        expect(find.text('Sekolah Binaan Aktif (3)'), findsOneWidget);

        // Reject the remaining pending school with confirmation dialog.
        await tester.ensureVisible(find.text('Tolak').first);
        await tester.tap(find.text('Tolak').first);
        await tester.pumpAndSettle();
        expect(find.text('Tolak Permintaan Sekolah?'), findsOneWidget);
        await tester.tap(find.text('Ya, Tolak Sekolah'));
        await tester.pumpAndSettle();

        expect(find.text('Menunggu Persetujuan (0)'), findsOneWidget);
        expect(find.text('Ditolak (1)'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'D05 displays plate-waste analytics, filters time range, and navigates to D03',
      (tester) async {
        final repo = _FakeKitchenRepository(nowUtc: DateTime.now().toUtc());
        await pumpKitchenApp(
          tester,
          repo: repo,
          camera: _FakeLiveCameraService(),
          exportService: _FakeBatchExportService(),
        );

        await tester.tap(find.text('Riwayat'));
        await tester.pumpAndSettle();

        expect(find.text('Riwayat & Sisa Pangan'), findsOneWidget);
        expect(find.text('Analitik Sisa Makanan (7 Hari)'), findsOneWidget);
        expect(find.text('Nasi / Karbohidrat'), findsOneWidget);
        expect(find.text('Lauk / Protein'), findsOneWidget);
        expect(find.text('Sayuran'), findsOneWidget);
        expect(find.text('45%'), findsOneWidget);
        expect(find.textContaining('sayuran mencapai 45%'), findsOneWidget);

        // Switch filter to Hari Ini (no historical batches from yesterday).
        await tester.tap(find.text('Hari Ini'));
        await tester.pumpAndSettle();
        expect(
          find.text('Belum ada batch pada rentang waktu ini'),
          findsOneWidget,
        );

        // Switch to 30 Hari and tap first batch row to open D03.
        await tester.tap(find.text('30 Hari'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.text('Nasi Ayam Goreng & Tumis Buncis').last,
        );
        await tester.tap(find.text('Nasi Ayam Goreng & Tumis Buncis').last);
        await tester.pumpAndSettle();
        expect(find.text('Kartu QR Segel & Surat Jalan'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'Compact 320dp viewport at Ekstra Besar scale has zero RenderFlex overflow on D01, D04, D05',
      (tester) async {
        final repo = _FakeKitchenRepository(nowUtc: DateTime.now().toUtc());
        await pumpKitchenApp(
          tester,
          repo: repo,
          camera: _FakeLiveCameraService(),
          exportService: _FakeBatchExportService(),
          screenSize: const Size(320, 700),
          isOffline: true,
        );

        // Increase in-app scale to Ekstra Besar via Settings (C01) then inspect D01, D04, D05.
        await tester.tap(find.text('Profil'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Ekstra Besar'));
        await tester.tap(find.text('Ekstra Besar'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Beranda'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Sekolah'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Riwayat'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );
  });
}
