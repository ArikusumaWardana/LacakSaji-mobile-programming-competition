import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lacak_saji/core/database/app_database.dart';
import 'package:lacak_saji/core/database/database_provider.dart';
import 'package:lacak_saji/core/network/bmkg_weather_service.dart';
import 'package:lacak_saji/core/network/connectivity_provider.dart';
import 'package:lacak_saji/core/theme/app_theme.dart';
import 'package:lacak_saji/core/theme/text_scale_provider.dart';
import 'package:lacak_saji/features/alerts/domain/cluster_alert_models.dart';
import 'package:lacak_saji/features/auth/domain/auth_models.dart';
import 'package:lacak_saji/features/auth/presentation/auth_controller.dart';
import 'package:lacak_saji/features/courier/presentation/courier_dashboard_screen.dart';
import 'package:lacak_saji/features/courier/presentation/courier_scan_screen.dart';
import 'package:lacak_saji/features/kitchen/domain/kitchen_models.dart';
import 'package:lacak_saji/features/kitchen/presentation/batch_qr_detail_screen.dart';
import 'package:lacak_saji/features/kitchen/presentation/ingredient_history_screen.dart';
import 'package:lacak_saji/features/kitchen/presentation/tray_logistics_screen.dart';
import 'package:lacak_saji/features/school/data/klb_pdf_service.dart';
import 'package:lacak_saji/features/school/domain/danger_zone_calculator.dart';
import 'package:lacak_saji/features/school/domain/school_models.dart';
import 'package:lacak_saji/features/school/presentation/danger_zone_gate_screen.dart';
import 'package:lacak_saji/features/school/presentation/plate_waste_screen.dart';
import 'package:lacak_saji/features/school/presentation/school_providers.dart';
import 'package:lacak_saji/features/traceability/data/traceability_repository.dart';
import 'package:lacak_saji/features/traceability/domain/traceability_models.dart';
import 'package:lacak_saji/features/traceability/presentation/traceability_providers.dart';

class _FixedAuthController extends AuthController {
  _FixedAuthController(this._fixedState);

  final AuthState _fixedState;

  @override
  AuthState build() => _fixedState;
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
    partnerPublicKey: 'ZmFrZV9wdWJsaWNfa2V5',
  );

  const courierProfile = UserProfile(
    id: '55555555-5555-5555-5555-555555555555',
    email: 'kurir.a@lacaksaji.id',
    role: UserRole.courier,
    fullName: 'Budi Santoso',
  );

  const kitchenAdminProfile = UserProfile(
    id: '22222222-2222-2222-2222-222222222222',
    email: 'dapur.a@lacaksaji.id',
    role: UserRole.kitchen,
    fullName: 'Ibu Sari',
  );

  const schoolPicProfile = UserProfile(
    id: '44444444-4444-4444-4444-444444444444',
    email: 'sdn1.pwt@lacaksaji.id',
    role: UserRole.school,
    fullName: 'Pak Ahmad',
  );

  FoodBatchItem sampleBatch() => FoodBatchItem(
    id: '66666666-6666-6666-6666-666666666666',
    sppgId: kitchen.id,
    sppgName: kitchen.name,
    batchCode: 'BCH-2611-CUR1',
    menuName: 'Nasi Ayam Goreng & Sayur Bening',
    portionCount: 150,
    riskCategory: FoodRiskCategory.medium,
    sealedAtUtc: DateTime.utc(2026, 11, 24, 2, 0),
    timestampSource: BatchTimestampSource.serverVerified,
    signingKeyId: 'k-01',
    signatureB64: 'ZmFrZV9zaWc=',
    createdAtUtc: DateTime.utc(2026, 11, 24, 2, 0),
  );

  Future<AppDatabase> openMemoryDb() async {
    return AppDatabase(NativeDatabase.memory());
  }

  test(
    'TraceabilityRepository persists ingredient, courier transit, and tray sanitation offline in Drift',
    () async {
      final db = await openMemoryDb();
      addTearDown(db.close);

      final repo = SupabaseTraceabilityRepository(client: null, database: db);
      final batch = sampleBatch();

      // 1. Save upstream ingredient log offline
      final savedIngredients = await repo.saveIngredientLogsForBatch(
        kitchen: kitchen,
        batch: batch,
        drafts: [
          IngredientLogDraft(
            ingredientName: 'Ayam Fillet Segar',
            supplierName: 'CV Berkah Unggas',
            supplierBatchNo: 'LOT-AYM-09',
            expiryDate: DateTime(2026, 11, 26),
          ),
        ],
        isOffline: true,
        createdByUserId: kitchenAdminProfile.id,
      );
      expect(savedIngredients, hasLength(1));
      expect(savedIngredients.first.isPendingSync, isTrue);

      final fetchedIngredients = await repo.fetchIngredientLogsByBatch(
        sppgId: kitchen.id,
        batchId: batch.id,
      );
      expect(fetchedIngredients, hasLength(1));
      expect(fetchedIngredients.first.supplierName, 'CV Berkah Unggas');

      // 2. Record courier load and arrival scans offline
      final loaded = await repo.recordCourierScan(
        kitchen: kitchen,
        actor: courierProfile,
        qrPayload: batch.qrPayload,
        mode: CourierScanMode.loadAtKitchen,
        isOffline: true,
        lat: -7.4126,
        lng: 109.2345,
      );
      expect(loaded.status, TransitHandoverDbStatus.inTransit);
      expect(loaded.isPendingSync, isTrue);

      final arrived = await repo.recordCourierScan(
        kitchen: kitchen,
        actor: courierProfile,
        qrPayload: batch.qrPayload,
        mode: CourierScanMode.arriveAtSchool,
        isOffline: true,
        schoolId: school.id,
        schoolName: school.name,
        lat: -7.4130,
        lng: 109.2350,
      );
      expect(arrived.status, TransitHandoverDbStatus.arrived);
      expect(arrived.arrivedAtUtc, isNotNull);

      final timeline = await repo.fetchSupplyChainTimeline(
        sppgId: kitchen.id,
        batchId: batch.id,
        sealedAtUtc: batch.sealedAtUtc,
      );
      expect(timeline.loadedAtUtc, isNotNull);
      expect(timeline.arrivedAtUtc, isNotNull);
      expect(timeline.kitchenWaitMinutes, isNotNull);
      expect(timeline.courierTransitMinutes, isNotNull);

      // 3. School submits tray return + Kitchen verifies 3-point sanitation
      final trayReturn = await repo.submitSchoolTrayReturn(
        school: school,
        batchId: batch.id,
        batchCode: batch.batchCode,
        menuName: batch.menuName,
        traysSent: 150,
        traysReturned: 148,
        isOffline: true,
        notes: '2 ompreng masih di ruang UKS',
      );
      expect(trayReturn.missingTrays, 2);
      expect(trayReturn.returnStatus, TrayReturnStatus.inReturnTransit);

      final verified = await repo.verifyKitchenTrayReturnAndSanitation(
        sppgId: kitchen.id,
        item: trayReturn,
        verifiedReturnedCount: 149,
        checklist: const TraySanitationChecklist(
          foodGradeSoapWash: true,
          hotRunningRinse: true,
          coveredDrying: true,
        ),
        isOffline: true,
        verifierUserId: kitchenAdminProfile.id,
      );
      expect(verified.missingTrays, 1);
      expect(verified.returnStatus, TrayReturnStatus.sanitized);
      expect(
        verified.sanitizationStatus,
        TraySanitizationStatus.sanitizedVerified,
      );

      final pendingQueue = await db.getPendingSyncItems();
      expect(
        pendingQueue.map((e) => e.operationType),
        containsAll([
          'create_ingredient_log',
          'upsert_transit_handover',
          'create_tray_return',
          'update_tray_return_sanitation',
        ]),
      );
    },
  );

  test(
    'KLB PDF and WA summary include upstream ingredient suppliers and courier transit without emoji or em-dash',
    () async {
      final service = DeviceKlbReportPdfService();
      final handover = TransitHandoverItem(
        id: 'hand-1',
        batchId: 'batch-1',
        sppgId: kitchen.id,
        courierName: 'Budi Santoso',
        loadedAtUtc: DateTime.utc(2026, 11, 24, 2, 30),
        departedAtUtc: DateTime.utc(2026, 11, 24, 2, 30),
        arrivedAtUtc: DateTime.utc(2026, 11, 24, 3, 15),
        status: TransitHandoverDbStatus.arrived,
        createdAtUtc: DateTime.utc(2026, 11, 24, 2, 30),
      );
      final ingredient = IngredientLogItem(
        id: 'ing-1',
        batchId: 'batch-1',
        sppgId: kitchen.id,
        ingredientName: 'Ayam Fillet Dada',
        supplierName: 'CV Unggas Jaya',
        supplierBatchNo: 'LOT-AYM-881',
        expiryDate: DateTime(2026, 11, 26),
        receivedAtUtc: DateTime.utc(2026, 11, 23, 21, 0),
        createdAtUtc: DateTime.utc(2026, 11, 23, 21, 0),
      );

      final args = PuskesmasDraftArgs(
        alertId: 'alert-001',
        batchId: 'batch-1',
        batchCode: 'BCH-2611-KLB1',
        menuName: 'Nasi Ayam Goreng',
        sppgId: kitchen.id,
        sppgName: kitchen.name,
        sealedAtUtc: DateTime.utc(2026, 11, 24, 2, 0),
        scannedAtUtc: DateTime.utc(2026, 11, 24, 3, 20),
        elapsedMinutes: 80,
        bmkgTempC: 32.5,
        bmkgSource: BmkgSource.live,
        dangerStatus: DangerZoneStatus.red,
        stage: ClusterAlertStage.preConsumption,
        symptomCount: 0,
        reasonSummary: 'Ditemukan perubahan warna pada lauk.',
        broadcastEnabled: true,
        reportedAtUtc: DateTime.utc(2026, 11, 24, 3, 25),
        sampleLabelCode: 'SPL-2611-001',
        ingredientLogs: [ingredient],
        transitHandover: handover,
      );

      final waText = service.buildWhatsAppSummaryText(
        args: args,
        school: school,
      );
      expect(waText, contains('CV Unggas Jaya'));
      expect(waText, contains('LOT-AYM-881'));
      expect(waText, contains('Budi Santoso'));
      expect(waText, isNot(contains('\u2014')));

      final pdfBytes = await service.buildKlbReportPdfBytes(
        args: args,
        school: school,
        photoBytesOverride: Uint8List(0),
        compress: false,
      );
      final pdfRaw = latin1.decode(pdfBytes, allowInvalid: true);
      expect(pdfRaw, contains('/Count 1>>'));
      expect(pdfRaw, contains('Unggas'));
      expect(pdfRaw, contains('Jaya'));
      expect(pdfRaw, contains('LOT-AYM-881'));
      expect(pdfRaw, contains('Budi'));
      expect(pdfRaw, contains('Santoso'));
      expect(pdfRaw, contains('Transit'));
      expect(pdfRaw, isNot(contains('\u2014')));
    },
  );

  testWidgets(
    'K01 CourierDashboardScreen renders filter chips and tiles cleanly at 320dp Ekstra Besar',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = await openMemoryDb();
      addTearDown(db.close);

      final batch1 = sampleBatch();
      final batch2 = FoodBatchItem(
        id: '77777777-7777-7777-7777-777777777777',
        sppgId: kitchen.id,
        sppgName: kitchen.name,
        batchCode: 'BCH-2611-CUR2',
        menuName: 'Nasi Rendang Sapi',
        portionCount: 120,
        riskCategory: FoodRiskCategory.high,
        sealedAtUtc: DateTime.utc(2026, 11, 24, 1, 30),
        timestampSource: BatchTimestampSource.serverVerified,
        signingKeyId: 'k-01',
        signatureB64: 'ZmFrZV9zaWc=',
        createdAtUtc: DateTime.utc(2026, 11, 24, 1, 30),
      );

      final auth = AuthState(
        status: AuthStatus.authenticated,
        profile: courierProfile,
        kitchen: kitchen,
        institutionRole: InstitutionMemberRole.courier,
      );

      tester.view.physicalSize = const Size(320, 680);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            isOfflineProvider.overrideWith((ref) => Stream.value(false)),
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
            authControllerProvider.overrideWith(
              () => _FixedAuthController(auth),
            ),
            courierDeliveriesProvider.overrideWith(
              (ref) async => [
                CourierBatchDeliveryItem(batch: batch1),
                CourierBatchDeliveryItem(
                  batch: batch2,
                  handover: TransitHandoverItem(
                    id: 'h2',
                    batchId: batch2.id,
                    sppgId: kitchen.id,
                    courierName: courierProfile.fullName,
                    loadedAtUtc: DateTime.utc(2026, 11, 24, 1, 45),
                    departedAtUtc: DateTime.utc(2026, 11, 24, 1, 45),
                    status: TransitHandoverDbStatus.inTransit,
                    createdAtUtc: DateTime.utc(2026, 11, 24, 1, 45),
                  ),
                ),
              ],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.30)),
              child: child!,
            ),
            home: const CourierDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Nasi Ayam Goreng & Sayur Bening'), findsOneWidget);

      await tester.ensureVisible(find.text('Dalam Perjalanan'));
      await tester.tap(find.text('Dalam Perjalanan'));
      await tester.pumpAndSettle();
      expect(find.text('Nasi Rendang Sapi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'K02 CourierScanScreen records load scan using injectable scanner builder',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = await openMemoryDb();
      addTearDown(db.close);

      final batch = sampleBatch();
      final auth = AuthState(
        status: AuthStatus.authenticated,
        profile: courierProfile,
        kitchen: kitchen,
        institutionRole: InstitutionMemberRole.courier,
      );

      late void Function(String rawQr) triggerDetect;

      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            isOfflineProvider.overrideWith((ref) => Stream.value(true)),
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
            authControllerProvider.overrideWith(
              () => _FixedAuthController(auth),
            ),
            courierQrScannerViewBuilderProvider.overrideWithValue((
              context,
              torchEnabled,
              onDetected,
            ) {
              triggerDetect = onDetected;
              return const ColoredBox(color: Colors.black);
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const CourierScanScreen(
              initialMode: CourierScanMode.loadAtKitchen,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      triggerDetect(batch.qrPayloadJson);
      await tester.pumpAndSettle();

      expect(find.text('Muat Batch Berhasil Dicatat'), findsOneWidget);

      final drafts = await db.getTraceabilityDrafts(
        recordType: 'transit_handover',
        batchId: batch.id,
      );
      expect(drafts, hasLength(1));
    },
  );

  testWidgets(
    'D06 IngredientHistoryScreen and TrayLogisticsScreen work at 320dp Ekstra Besar',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = await openMemoryDb();
      addTearDown(db.close);

      final repo = SupabaseTraceabilityRepository(client: null, database: db);
      final batch = sampleBatch();
      await repo.saveIngredientLogsForBatch(
        kitchen: kitchen,
        batch: batch,
        drafts: [
          IngredientLogDraft(
            ingredientName: 'Susu UHT',
            supplierName: 'PT Susu Segar',
            supplierBatchNo: 'UHT-112',
            expiryDate: DateTime(2026, 11, 25),
          ),
        ],
        isOffline: true,
      );
      final trayLog = await repo.submitSchoolTrayReturn(
        school: school,
        batchId: batch.id,
        batchCode: batch.batchCode,
        menuName: batch.menuName,
        traysSent: 150,
        traysReturned: 148,
        isOffline: true,
      );

      final auth = AuthState(
        status: AuthStatus.authenticated,
        profile: kitchenAdminProfile,
        kitchen: kitchen,
        institutionRole: InstitutionMemberRole.admin,
      );

      tester.view.physicalSize = const Size(320, 680);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 1. D06 IngredientHistoryScreen
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            isOfflineProvider.overrideWith((ref) => Stream.value(true)),
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
            authControllerProvider.overrideWith(
              () => _FixedAuthController(auth),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.30)),
              child: child!,
            ),
            home: const IngredientHistoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('PT Susu Segar'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 2. TrayLogisticsScreen + 3-point sanitation sheet
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            isOfflineProvider.overrideWith((ref) => Stream.value(true)),
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
            authControllerProvider.overrideWith(
              () => _FixedAuthController(auth),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.30)),
              child: child!,
            ),
            home: const TrayLogisticsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('SDN 1 Purwokerto'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.textContaining('SDN 1 Purwokerto'));
      await tester.pumpAndSettle();

      for (final label in const [
        'Cuci dengan sabun food-grade',
        'Bilas air panas atau mengalir',
        'Tiris di rak tertutup dan higienis',
      ]) {
        final itemFinder = find.text(label);
        await tester.ensureVisible(itemFinder);
        await tester.tap(itemFinder);
        await tester.pumpAndSettle();
      }

      await tester.ensureVisible(
        find.text('Simpan Verifikasi & Sanitasi'),
      );
      await tester.tap(find.text('Simpan Verifikasi & Sanitasi'));
      await tester.pumpAndSettle();

      final updatedList = await repo.fetchKitchenTrayReturns(
        sppgId: kitchen.id,
      );
      final updated = updatedList.firstWhere((e) => e.id == trayLog.id);
      expect(
        updated.sanitizationStatus,
        TraySanitizationStatus.sanitizedVerified,
      );
      expect(updated.checklist.isAllCompleted, isTrue);
    },
  );

  testWidgets(
    'D03, G03 render SupplyChainTimeline and PlateWasteScreen records empty tray return',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = await openMemoryDb();
      addTearDown(db.close);

      final batch = sampleBatch();
      final repo = SupabaseTraceabilityRepository(client: null, database: db);
      await repo.recordCourierScan(
        kitchen: kitchen,
        actor: courierProfile,
        qrPayload: batch.qrPayload,
        mode: CourierScanMode.loadAtKitchen,
        isOffline: true,
      );

      final kitchenAuth = AuthState(
        status: AuthStatus.authenticated,
        profile: kitchenAdminProfile,
        kitchen: kitchen,
        institutionRole: InstitutionMemberRole.admin,
      );

      // 1. D03 BatchQrDetailScreen shows timeline + ingredients section
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            isOfflineProvider.overrideWith((ref) => Stream.value(true)),
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
            authControllerProvider.overrideWith(
              () => _FixedAuthController(kitchenAuth),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: BatchQrDetailScreen(batchId: batch.id, initialBatch: batch),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lini Masa Rantai Pasok'), findsOneWidget);
      expect(find.text('Dimasak & Disegel Dapur'), findsOneWidget);
      expect(find.text('Dimuat Kurir'), findsOneWidget);
      expect(find.text('Hulu Bahan Baku Tertaut'), findsOneWidget);

      // 2. G03 DangerZoneGateScreen shows timeline
      final schoolAuth = AuthState(
        status: AuthStatus.authenticated,
        profile: schoolPicProfile,
        school: school,
        institutionRole: InstitutionMemberRole.admin,
      );
      final scanContext = VerifiedBatchScanContext(
        payload: batch.qrPayload,
        riskCategory: FoodRiskCategory.medium,
        timestampSource: BatchTimestampSource.serverVerified,
        sealedAtUtc: batch.sealedAtUtc,
        scannedAtUtc: DateTime.utc(2026, 11, 24, 3, 10),
        sppgName: kitchen.name,
        sppgPublicKeyB64: kitchen.publicKey,
        weather: BmkgWeatherReading(
          adm4Code: school.adm4Code,
          temperatureC: 27.0,
          source: BmkgSource.live,
          observedAtUtc: DateTime.utc(2026, 11, 24, 3, 0),
        ),
        dangerEvaluation: const DangerZoneEvaluation(
          status: DangerZoneStatus.green,
          elapsedMinutes: 70,
          safeLimitMinutes: 180,
          stopLimitMinutes: 240,
          isHotWeather: false,
          explanation: 'Kondisi aman dalam batas waktu.',
        ),
        gpsWithinRadius: true,
        distanceMeters: 15,
      );

      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            isOfflineProvider.overrideWith((ref) => Stream.value(true)),
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
            authControllerProvider.overrideWith(
              () => _FixedAuthController(schoolAuth),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: DangerZoneGateScreen(scanContext: scanContext),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lini Masa Rantai Pasok'), findsOneWidget);
      expect(find.text('Tiba di Sekolah'), findsOneWidget);

      // 3. PlateWasteScreen empty tray handover section
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            isOfflineProvider.overrideWith((ref) => Stream.value(true)),
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
            authControllerProvider.overrideWith(
              () => _FixedAuthController(schoolAuth),
            ),
            selectableWasteBatchesProvider.overrideWith(
              (ref) async => [
                SchoolBatchOption(
                  batchId: batch.id,
                  batchCode: batch.batchCode,
                  menuName: batch.menuName,
                  sealedAtUtc: batch.sealedAtUtc,
                ),
              ],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PlateWasteScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final saveTrayBtn = find.text('Simpan Serah Terima Ompreng');
      await tester.ensureVisible(saveTrayBtn);
      await tester.tap(saveTrayBtn);
      await tester.pumpAndSettle();

      final schoolReturns = await repo.fetchSchoolTrayReturns(
        schoolId: school.id,
      );
      expect(schoolReturns, isNotEmpty);
    },
  );
}
