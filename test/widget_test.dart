import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lacak_saji/core/constants/app_constants.dart';
import 'package:lacak_saji/core/database/app_database.dart';
import 'package:lacak_saji/core/database/database_provider.dart';
import 'package:lacak_saji/core/media/live_camera_webp_service.dart';
import 'package:lacak_saji/core/network/bmkg_weather_service.dart';
import 'package:lacak_saji/core/network/connectivity_provider.dart';
import 'package:lacak_saji/core/network/supabase_provider.dart';
import 'package:lacak_saji/core/theme/app_colors.dart';
import 'package:lacak_saji/core/theme/app_semantic_colors.dart';
import 'package:lacak_saji/core/theme/text_scale_provider.dart';
import 'package:lacak_saji/core/widgets/lacak_text_field.dart';
import 'package:lacak_saji/features/auth/data/auth_repository.dart';
import 'package:lacak_saji/features/auth/domain/auth_error_mapper.dart';
import 'package:lacak_saji/features/auth/domain/auth_models.dart';
import 'package:lacak_saji/features/auth/presentation/auth_controller.dart';
import 'package:lacak_saji/features/kitchen/data/kitchen_repository.dart';
import 'package:lacak_saji/features/kitchen/domain/kitchen_models.dart';
import 'package:lacak_saji/features/kitchen/presentation/kitchen_providers.dart';
import 'package:lacak_saji/features/school/data/school_repository.dart';
import 'package:lacak_saji/features/school/domain/school_models.dart';
import 'package:lacak_saji/features/school/presentation/school_providers.dart';
import 'package:lacak_saji/main.dart';

class _FakeAuthRepository implements AuthRepository {
  AuthSessionSnapshot? currentSession;
  SchoolVerificationStatus schoolStatusOnRefresh =
      SchoolVerificationStatus.approved;

  @override
  Future<AuthSessionSnapshot?> restoreSession() async => currentSession;

  @override
  Future<AuthSessionSnapshot> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (email == 'dapur.a@lacaksaji.id') {
      currentSession = const AuthSessionSnapshot(
        profile: UserProfile(
          id: 'u-kitchen-1',
          email: 'dapur.a@lacaksaji.id',
          role: UserRole.kitchen,
          fullName: 'Ibu Ratna (Petugas SPPG Purwokerto Utara)',
        ),
        kitchen: KitchenProfile(
          id: 'k-1',
          ownerUserId: 'u-kitchen-1',
          regNumber: 'BGN-PWT-2026-001',
          inviteCode: 'SPPG-PWT-01',
          name: 'SPPG Purwokerto Utara',
          adm4Code: '33.02.26.1001',
          lat: -7.4126,
          lng: 109.2345,
          publicKey: '8hY2v0M7pQ5wN8tR1xL4kZ9bC3vF6mJ2dS0qW7eU5yI=',
          isVerified: true,
        ),
      );
      return currentSession!;
    }
    if (email == 'sdn1.pwt@lacaksaji.id') {
      currentSession = const AuthSessionSnapshot(
        profile: UserProfile(
          id: 'u-school-1',
          email: 'sdn1.pwt@lacaksaji.id',
          role: UserRole.school,
          fullName: 'Ibu Siti (PIC SDN 1 Purwokerto)',
        ),
        school: SchoolProfile(
          id: 's-1',
          ownerUserId: 'u-school-1',
          sppgId: 'k-1',
          npsn: '20301901',
          name: 'SDN 1 Purwokerto',
          adm4Code: '33.02.26.1001',
          lat: -7.4188,
          lng: 109.2351,
          puskesmasWa: '628112800001',
          verificationStatus: SchoolVerificationStatus.approved,
          partnerKitchenName: 'SPPG Purwokerto Utara',
          partnerInviteCode: 'SPPG-PWT-01',
        ),
      );
      return currentSession!;
    }
    if (email == 'pengawas.bgn@lacaksaji.id') {
      currentSession = const AuthSessionSnapshot(
        profile: UserProfile(
          id: '30000000-0000-4000-8000-000000000001',
          email: 'pengawas.bgn@lacaksaji.id',
          role: UserRole.supervisor,
          fullName: 'Pengawas BGN Wilayah Banyumas',
        ),
      );
      return currentSession!;
    }
    throw const AuthFriendlyException(
      'Email atau kata sandi salah. Periksa kembali penulisan lalu coba lagi.',
    );
  }

  @override
  Future<WhitelistCheckResult> verifySppgWhitelist({
    required String regNumber,
    required String pin,
  }) async {
    if (regNumber.trim().toUpperCase() == 'BGN-SBX-2026-101' &&
        pin.trim() == '101010') {
      return const WhitelistCheckResult(
        ok: true,
        regNumber: 'BGN-SBX-2026-101',
        officialName: 'SPPG Banyumas Barat (Sandbox 1)',
        regionName: 'Banyumas, Jawa Tengah',
      );
    }
    return const WhitelistCheckResult(ok: false, reason: 'invalid_pin');
  }

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
  }) async {
    final check = await verifySppgWhitelist(regNumber: regNumber, pin: pin);
    if (!check.ok) {
      throw AuthFriendlyException(AuthErrorMapper.mapRpcReason(check.reason));
    }
    currentSession = AuthSessionSnapshot(
      profile: UserProfile(
        id: 'u-kitchen-new',
        email: email,
        role: UserRole.kitchen,
        fullName: picName,
      ),
      kitchen: KitchenProfile(
        id: 'k-new',
        ownerUserId: 'u-kitchen-new',
        regNumber: regNumber,
        inviteCode: 'SPPG-9A4B',
        name: kitchenName,
        adm4Code: adm4Code,
        lat: lat,
        lng: lng,
        publicKey: '8hY2v0M7pQ5wN8tR1xL4kZ9bC3vF6mJ2dS0qW7eU5yI=',
        isVerified: true,
      ),
    );
    return KitchenRegistrationResult(
      requiresEmailConfirmation: false,
      inviteCode: 'SPPG-9A4B',
      kitchenName: kitchenName,
      session: currentSession,
    );
  }

  @override
  Future<SchoolPrecheckResult> precheckSchool({
    required String npsn,
    required String inviteCode,
  }) async {
    if (npsn == '20301901') {
      return const SchoolPrecheckResult(ok: false, reason: 'npsn_exists');
    }
    if (inviteCode.trim().toUpperCase() == 'SPPG-PWT-01') {
      return const SchoolPrecheckResult(
        ok: true,
        sppgId: 'k-1',
        sppgName: 'SPPG Purwokerto Utara',
        sppgInviteCode: 'SPPG-PWT-01',
      );
    }
    return const SchoolPrecheckResult(ok: false, reason: 'sppg_not_found');
  }

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
  }) async {
    final precheck = await precheckSchool(npsn: npsn, inviteCode: inviteCode);
    if (!precheck.ok) {
      throw AuthFriendlyException(AuthErrorMapper.mapRpcReason(precheck.reason));
    }
    currentSession = AuthSessionSnapshot(
      profile: UserProfile(
        id: 'u-school-new',
        email: email,
        role: UserRole.school,
        fullName: picName,
      ),
      school: SchoolProfile(
        id: 's-new',
        ownerUserId: 'u-school-new',
        sppgId: 'k-1',
        npsn: npsn,
        name: schoolName,
        adm4Code: adm4Code,
        lat: lat,
        lng: lng,
        puskesmasWa: puskesmasWa,
        verificationStatus: SchoolVerificationStatus.pending,
        partnerKitchenName: 'SPPG Purwokerto Utara',
        partnerInviteCode: 'SPPG-PWT-01',
      ),
    );
    return SchoolRegistrationResult(
      requiresEmailConfirmation: false,
      schoolName: schoolName,
      session: currentSession,
    );
  }

  @override
  Future<AuthSessionSnapshot?> refreshSession() async {
    final existing = currentSession;
    if (existing?.school == null) {
      return existing;
    }
    final oldSchool = existing!.school!;
    currentSession = AuthSessionSnapshot(
      profile: existing.profile,
      school: SchoolProfile(
        id: oldSchool.id,
        ownerUserId: oldSchool.ownerUserId,
        sppgId: oldSchool.sppgId,
        npsn: oldSchool.npsn,
        name: oldSchool.name,
        adm4Code: oldSchool.adm4Code,
        lat: oldSchool.lat,
        lng: oldSchool.lng,
        puskesmasWa: oldSchool.puskesmasWa,
        verificationStatus: schoolStatusOnRefresh,
        partnerKitchenName: oldSchool.partnerKitchenName,
        partnerInviteCode: oldSchool.partnerInviteCode,
      ),
    );
    return currentSession;
  }

  @override
  Future<AuthSessionSnapshot> updateSchoolPartnerCode(String inviteCode) async {
    return currentSession!;
  }

  @override
  Future<AuthSessionSnapshot> updateSchoolOperationalSettings({
    required String puskesmasWa,
    required String adm4Code,
  }) async {
    final existing = currentSession!;
    final oldSchool = existing.school!;
    currentSession = AuthSessionSnapshot(
      profile: existing.profile,
      school: SchoolProfile(
        id: oldSchool.id,
        ownerUserId: oldSchool.ownerUserId,
        sppgId: oldSchool.sppgId,
        npsn: oldSchool.npsn,
        name: oldSchool.name,
        adm4Code: adm4Code,
        lat: oldSchool.lat,
        lng: oldSchool.lng,
        puskesmasWa: puskesmasWa,
        verificationStatus: oldSchool.verificationStatus,
        partnerKitchenName: oldSchool.partnerKitchenName,
        partnerInviteCode: oldSchool.partnerInviteCode,
      ),
    );
    return currentSession!;
  }

  @override
  Future<AuthSessionSnapshot> updateKitchenLocation({
    required double lat,
    required double lng,
    required String adm4Code,
  }) async {
    return currentSession!;
  }

  @override
  Future<void> signOut() async {
    currentSession = null;
  }
}

class _FakeStage2KitchenRepository implements KitchenRepository {
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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<FoodBatchItem?> fetchBatchById({
    required KitchenProfile kitchen,
    required String batchId,
  }) async => null;

  @override
  Future<KitchenDashboardData> fetchDashboard({
    required KitchenProfile kitchen,
  }) async {
    return KitchenDashboardData(
      kitchen: kitchen,
      todayBatches: const [],
      todayReceivedSchoolsCount: 0,
      approvedSchoolsCount: 2,
      pendingSchoolsCount: 0,
      activeAlertsToday: const [],
      weeklyWasteSummary: PlateWasteSummary.empty,
    );
  }

  @override
  Future<KitchenHistoryData> fetchHistoryAndWaste({
    required KitchenProfile kitchen,
    required HistoryTimeRange range,
  }) async {
    return KitchenHistoryData(
      range: range,
      batches: const [],
      wasteLogs: const [],
      wasteSummary: PlateWasteSummary.empty,
    );
  }

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

class _FakeStage2SchoolRepository implements SchoolRepository {
  @override
  Future<SampleVaultItem> createSampleVault({
    required SchoolProfile school,
    required String inspectionId,
    required String menuName,
    required String labelCode,
    required bool isOffline,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SchoolDashboardData> fetchDashboardData({
    required SchoolProfile school,
    required bool isOffline,
  }) async {
    return SchoolDashboardData(
      school: school,
      weather: BmkgWeatherReading(
        adm4Code: school.adm4Code,
        temperatureC: 31.2,
        source: BmkgSource.live,
        observedAtUtc: DateTime.utc(2026, 11, 21, 5, 0),
      ),
      todayInspections: const [],
      activeSampleCount: 0,
      partnerKeyCached: true,
    );
  }

  @override
  Future<List<SchoolBatchOption>> fetchSelectableBatchesForWaste({
    required SchoolProfile school,
    required bool isOffline,
  }) async => const [];

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
  }) {
    throw UnimplementedError();
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
  }) async => true;

  @override
  Future<int> syncPendingSchoolQueue({required SchoolProfile school}) async => 0;

  @override
  Future<QrVerificationResult> verifyQrPayloadOffline({
    required String rawQrText,
    required SchoolProfile school,
    required bool isOffline,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<List<SampleVaultItem>> watchActiveSamples(String schoolId) =>
      Stream.value(const []);

  @override
  Stream<List<SampleVaultItem>> watchHistorySamples(String schoolId) =>
      Stream.value(const []);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  Widget buildTestApp({
    required SharedPreferences prefs,
    required _FakeAuthRepository fakeRepo,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isSupabaseReadyProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(fakeRepo),
        kitchenRepositoryProvider.overrideWithValue(
          _FakeStage2KitchenRepository(),
        ),
        schoolRepositoryProvider.overrideWithValue(
          _FakeStage2SchoolRepository(),
        ),
        isOfflineProvider.overrideWith((ref) => Stream.value(false)),
        pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
      ],
      child: const LacakSajiApp(),
    );
  }

  group('Stage 2 Auth, Onboarding, Settings & Adaptive Shells', () {
    testWidgets(
      'S01 -> S02 -> Demo Kitchen enters adaptive Kitchen shell (NavigationBar & NavigationRail)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final fakeRepo = _FakeAuthRepository();

        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(buildTestApp(prefs: prefs, fakeRepo: fakeRepo));
        await tester.pumpAndSettle();

        expect(find.text('Masuk LacakSaji'), findsOneWidget);
        final theme = Theme.of(tester.element(find.text('Masuk LacakSaji')));
        expect(theme.scaffoldBackgroundColor, AppColors.bgCanvas);
        expect(theme.extension<LacakSemanticColors>()?.safeFg, AppColors.safeFg);

        await tester.ensureVisible(find.text('Masuk Cepat (Akun Demo)'));
        await tester.tap(find.text('Masuk Cepat (Akun Demo)'));
        await tester.pumpAndSettle();

        expect(find.text('Dapur SPPG A (SPPG-PWT-01)'), findsOneWidget);
        await tester.tap(find.text('Dapur SPPG A (SPPG-PWT-01)'));
        await tester.pumpAndSettle();

        expect(find.text('Beranda Dapur SPPG'), findsOneWidget);
        expect(find.text('SPPG Purwokerto Utara'), findsOneWidget);
        expect(find.text('Berhasil Masuk'), findsOneWidget);
        expect(
          find.text('Masuk sebagai SPPG Purwokerto Utara (Petugas Dapur SPPG).'),
          findsOneWidget,
        );
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.text('Sekolah'), findsOneWidget);
        expect(find.text('Riwayat'), findsOneWidget);

        // Dismisses cleanly when tapping close button.
        await tester.tap(
          find.byKey(const ValueKey<String>('auth_feedback_close_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Berhasil Masuk'), findsNothing);

        // Verify responsive switch to NavigationRail on >= 600dp width.
        tester.view.physicalSize = const Size(720, 900);
        await tester.pumpAndSettle();
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'Demo School enters School shell, changes Ukuran Teks Nyaman in C01 across breakpoints, and signs out',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final fakeRepo = _FakeAuthRepository();

        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(buildTestApp(prefs: prefs, fakeRepo: fakeRepo));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Masuk Cepat (Akun Demo)'));
        await tester.tap(find.text('Masuk Cepat (Akun Demo)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sekolah 1: SDN 1 Purwokerto'));
        await tester.pumpAndSettle();

        expect(find.text('Beranda Sekolah'), findsOneWidget);
        expect(find.text('Sampel'), findsOneWidget);
        expect(find.text('Sisa Makan'), findsOneWidget);

        await tester.tap(find.text('Profil'));
        await tester.pumpAndSettle();
        expect(find.text('Profil & Pengaturan'), findsOneWidget);
        expect(find.text(AppConstants.bmkgFullAttribution), findsOneWidget);

        // Verify live MediaQuery textScaler updates when switching Standar -> Besar -> Ekstra Besar.
        final previewFinder = find.textContaining('Pratinjau: Pastikan suhu');
        final initialHeight = tester.getSize(previewFinder).height;

        await tester.ensureVisible(find.text('Besar'));
        await tester.tap(find.text('Besar'));
        await tester.pumpAndSettle();
        expect(prefs.getString(AppConstants.textScalePrefKey), 'large');
        final largeScaler = MediaQuery.textScalerOf(tester.element(previewFinder));
        expect(largeScaler.scale(16.0), closeTo(18.4, 0.05));

        await tester.ensureVisible(find.text('Ekstra Besar'));
        await tester.tap(find.text('Ekstra Besar'));
        await tester.pumpAndSettle();
        expect(prefs.getString(AppConstants.textScalePrefKey), 'extraLarge');
        final extraLargeScaler = MediaQuery.textScalerOf(
          tester.element(previewFinder),
        );
        expect(extraLargeScaler.scale(16.0), closeTo(20.8, 0.05));
        expect(
          tester.getSize(previewFinder).height,
          greaterThan(initialHeight),
        );

        // Verify zero overflow on compact 320dp screen at Ekstra Besar scale.
        tester.view.physicalSize = const Size(320, 720);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.text('Keluar Akun'));
        await tester.tap(find.text('Keluar Akun'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ya, Keluar Akun'));
        await tester.pumpAndSettle();

        expect(find.text('Masuk LacakSaji'), findsOneWidget);
        expect(find.text('Berhasil Keluar'), findsOneWidget);
        expect(
          find.text('Anda telah keluar dari akun SDN 1 Purwokerto.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        // Auto-dismisses cleanly after 4 seconds.
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(find.text('Berhasil Keluar'), findsNothing);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'C01 Ubah WA Puskesmas & Wilayah handles focus and Batal cleanly without controller or _dependents assertion',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final fakeRepo = _FakeAuthRepository();

        await tester.pumpWidget(buildTestApp(prefs: prefs, fakeRepo: fakeRepo));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Masuk Cepat (Akun Demo)'));
        await tester.tap(find.text('Masuk Cepat (Akun Demo)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sekolah 1: SDN 1 Purwokerto'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Profil'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Ubah WA Puskesmas & Wilayah'));
        await tester.tap(find.text('Ubah WA Puskesmas & Wilayah'));
        await tester.pumpAndSettle();
        expect(find.text('Pengaturan Operasional Sekolah'), findsOneWidget);

        Finder fieldFor(String label) => find.descendant(
          of: find.byWidgetPredicate(
            (widget) => widget is LacakTextField && widget.label == label,
          ),
          matching: find.byType(TextFormField),
        );

        final adm4Field = fieldFor('Kode Wilayah Kelurahan');
        final waField = fieldFor('Nomor WhatsApp Puskesmas');

        await tester.tap(adm4Field);
        await tester.pump();
        await tester.enterText(adm4Field, '33.02.26.1002');
        await tester.tap(waField);
        await tester.pump();
        await tester.enterText(waField, '08112809999');
        await tester.pump();

        // Tap Batal while TextFormField still holds active focus, then advance
        // frames through the DialogRoute exit animation.
        await tester.tap(find.text('Batal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Pengaturan Operasional Sekolah'), findsNothing);

        // Reopen, edit both inputs, and verify saving succeeds cleanly too.
        await tester.tap(find.text('Ubah WA Puskesmas & Wilayah'));
        await tester.pumpAndSettle();

        await tester.tap(adm4Field);
        await tester.pump();
        await tester.enterText(adm4Field, '33.02.26.1002');
        await tester.tap(waField);
        await tester.pump();
        await tester.enterText(waField, '08112809999');
        await tester.pump();

        await tester.tap(find.text('Simpan Perubahan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('33.02.26.1002'), findsOneWidget);
        expect(find.text('+628112809999'), findsOneWidget);
      },
    );

    testWidgets(
      'S03 -> S03a Kitchen Registration rejects invalid PIN and succeeds with Sandbox code',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final fakeRepo = _FakeAuthRepository();

        await tester.pumpWidget(buildTestApp(prefs: prefs, fakeRepo: fakeRepo));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.textContaining('Daftar di Sini'));
        await tester.tap(find.textContaining('Daftar di Sini'));
        await tester.pumpAndSettle();

        expect(find.text('Pilih Peran Anda'), findsOneWidget);
        await tester.tap(find.text('Lanjutkan Pendaftaran'));
        await tester.pumpAndSettle();

        expect(find.text('Aktivasi Dapur SPPG'), findsOneWidget);
        expect(find.text('Langkah 1 dari 3'), findsOneWidget);

        await tester.tap(find.text('Lihat Daftar Kode Uji Coba'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('BGN-SBX-2026-101'));
        await tester.pumpAndSettle();

        // Override PIN with wrong PIN first to verify whitelist rejection on Step 1.
        final pinField = find.widgetWithText(TextFormField, '101010');
        await tester.enterText(pinField, '999999');
        await tester.tap(find.text('Simpan & Lanjut ke Identitas Dapur'));
        await tester.pumpAndSettle();
        expect(find.text('Kode Ditolak'), findsOneWidget);
        expect(find.text('Langkah 1 dari 3'), findsOneWidget);

        // Restore valid sandbox PIN and advance to Step 2 (saving draft locally).
        final wrongPinField = find.widgetWithText(TextFormField, '999999');
        await tester.ensureVisible(wrongPinField);
        await tester.enterText(wrongPinField, '101010');
        await tester.tap(find.text('Simpan & Lanjut ke Identitas Dapur'));
        await tester.pumpAndSettle();

        expect(find.text('Langkah 2 dari 3'), findsOneWidget);
        expect(
          prefs.getString('lacak_draft_register_kitchen_v1'),
          contains('BGN-SBX-2026-101'),
        );

        final picField = find.widgetWithText(
          TextFormField,
          'Nama lengkap penanggung jawab',
        );
        await tester.ensureVisible(picField);
        await tester.enterText(picField, 'Ibu Sari');
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.text('Simpan & Lanjut ke Akun Masuk'),
        );
        await tester.tap(find.text('Simpan & Lanjut ke Akun Masuk'));
        await tester.pumpAndSettle();

        expect(find.text('Langkah 3 dari 3'), findsOneWidget);
        expect(
          prefs.getString('lacak_draft_register_kitchen_v1'),
          contains('Ibu Sari'),
        );

        final emailField = find.widgetWithText(
          TextFormField,
          'dapur@lacaksaji.id',
        );
        await tester.ensureVisible(emailField);
        await tester.enterText(emailField, 'dapur.sbx@lacaksaji.id');

        final passField = find.widgetWithText(
          TextFormField,
          'Minimal 8 karakter',
        );
        await tester.ensureVisible(passField);
        await tester.enterText(passField, 'LacakSaji2026!');
        await tester.pumpAndSettle();

        final submitBtn = find.widgetWithText(
          ElevatedButton,
          'Aktivasi & Daftar Dapur',
        );
        await tester.ensureVisible(submitBtn);
        await tester.pumpAndSettle();
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Draft is cleared upon completion.
        expect(prefs.getString('lacak_draft_register_kitchen_v1'), isNull);
        expect(find.text('Kode Mitra Unik SPPG'), findsOneWidget);
        expect(find.text('SPPG-9A4B'), findsOneWidget);

        await tester.ensureVisible(find.text('Masuk ke Beranda Dapur'));
        await tester.tap(find.text('Masuk ke Beranda Dapur'));
        await tester.pumpAndSettle();
        expect(find.text('Beranda Dapur SPPG'), findsOneWidget);
      },
    );

    testWidgets(
      'S03 -> S03b School Registration lands on S04 Pending and transitions on approval',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final fakeRepo = _FakeAuthRepository();

        await tester.pumpWidget(buildTestApp(prefs: prefs, fakeRepo: fakeRepo));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.textContaining('Daftar di Sini'));
        await tester.tap(find.textContaining('Daftar di Sini'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Guru / PIC Sekolah'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lanjutkan Pendaftaran'));
        await tester.pumpAndSettle();

        expect(find.text('Daftar Akun Sekolah'), findsOneWidget);
        expect(find.text('Langkah 1 dari 3'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Contoh: 20301999'),
          '20309999',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Contoh: SDN 3 Purwokerto'),
          'SDN 3 Purwokerto',
        );
        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            'Nama penanggung jawab MBG di sekolah',
          ),
          'Bapak Budi',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Contoh: 08112800001'),
          '08112809999',
        );
        await tester.ensureVisible(
          find.text('Simpan & Lanjut ke Tautan SPPG'),
        );
        await tester.tap(find.text('Simpan & Lanjut ke Tautan SPPG'));
        await tester.pumpAndSettle();

        expect(find.text('Langkah 2 dari 3'), findsOneWidget);
        expect(
          prefs.getString('lacak_draft_register_school_v1'),
          contains('20309999'),
        );

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Contoh: SPPG-PWT-01'),
          'SPPG-PWT-01',
        );
        await tester.ensureVisible(
          find.text('Verifikasi & Lanjut ke Akun Masuk'),
        );
        await tester.tap(find.text('Verifikasi & Lanjut ke Akun Masuk'));
        await tester.pumpAndSettle();

        expect(find.text('Langkah 3 dari 3'), findsOneWidget);
        expect(
          prefs.getString('lacak_draft_register_school_v1'),
          contains('SPPG-PWT-01'),
        );

        await tester.enterText(
          find.widgetWithText(TextFormField, 'pic@sdn.sch.id'),
          'sdn3.pwt@lacaksaji.id',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Minimal 8 karakter'),
          'LacakSaji2026!',
        );

        await tester.ensureVisible(find.text('Daftar & Ajukan Tautan'));
        await tester.tap(find.text('Daftar & Ajukan Tautan'));
        await tester.pumpAndSettle();

        expect(prefs.getString('lacak_draft_register_school_v1'), isNull);
        expect(find.text('Status Verifikasi Sekolah'), findsOneWidget);
        expect(find.text('Menunggu Persetujuan Dapur SPPG'), findsOneWidget);

        fakeRepo.schoolStatusOnRefresh = SchoolVerificationStatus.approved;
        await tester.ensureVisible(find.text('Periksa Status Sekarang'));
        await tester.tap(find.text('Periksa Status Sekarang'));
        await tester.pumpAndSettle();

        expect(find.text('Beranda Sekolah'), findsOneWidget);
      },
    );
  });

  group('Text Scale & Drift Offline-First Database', () {
    test('effectiveTextScaler clamps combined factor between 1.0 and 1.6', () {
      const normalMq = MediaQueryData(textScaler: TextScaler.linear(1.0));
      expect(
        effectiveTextScaler(normalMq, ComfortableTextScale.standard).scale(16),
        closeTo(16.0, 0.01),
      );
      expect(
        effectiveTextScaler(normalMq, ComfortableTextScale.large).scale(16),
        closeTo(18.4, 0.01),
      );
      expect(
        effectiveTextScaler(
          normalMq,
          ComfortableTextScale.extraLarge,
        ).scale(16),
        closeTo(20.8, 0.01),
      );

      const largeSystemMq = MediaQueryData(textScaler: TextScaler.linear(1.5));
      expect(
        effectiveTextScaler(
          largeSystemMq,
          ComfortableTextScale.extraLarge,
        ).scale(16),
        closeTo(25.6, 0.01),
      );
    });

    test('CRUD works across all 4 offline tables', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 11, 21, 4, 0, 0);

      await db.upsertSppgKey(
        LocalSppgKeysCompanion.insert(
          sppgId: 'a1000000-0000-4000-8000-000000000001',
          sppgName: 'SPPG Purwokerto Utara',
          inviteCode: 'SPPG-PWT-01',
          publicKeyB64: '8hY2v0M7pQ5wN8tR1xL4kZ9bC3vF6mJ2dS0qW7eU5yI=',
          updatedAt: now,
        ),
      );
      final cachedKey = await db.getSppgKey(
        'a1000000-0000-4000-8000-000000000001',
      );
      expect(cachedKey?.inviteCode, 'SPPG-PWT-01');

      await db.upsertBmkgForecasts([
        LocalBmkgCacheCompanion.insert(
          adm4Code: '33.02.26.1001',
          forecastTimeUtc: now.add(const Duration(hours: 2)),
          temperatureC: 32.5,
          humidityPct: const Value(72),
          weatherDesc: const Value('Cerah Berawan'),
          fetchedAt: now,
          expiresAt: now.add(const Duration(hours: 72)),
        ),
      ]);
      final forecast = await db.getNearestBmkgForecast('33.02.26.1001', now);
      expect(forecast?.temperatureC, 32.5);

      final queueId = await db.enqueueSyncItem(
        LocalSyncQueueCompanion.insert(
          operationType: 'create_inspection',
          entityId: 'insp-001',
          payloadJson: jsonEncode({'danger_status': 'GREEN'}),
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(await db.watchPendingSyncCount().first, 1);

      await db.updateSyncItemStatus(id: queueId, status: 'syncing');
      expect(await db.watchPendingSyncCount().first, 0);

      await db.upsertSampleVault(
        LocalSampleVaultsCompanion.insert(
          id: 'sv-001',
          inspectionId: 'insp-001',
          schoolId: 'b1000000-0000-4000-8000-000000000001',
          menuName: 'Nasi Ayam Suwir',
          labelCode: 'SMP-2611-01A',
          storedAt: now,
          expiresAt: now.add(const Duration(hours: 48)),
          createdAt: now,
        ),
      );
      final activeSamples = await db
          .watchActiveSampleVaults('b1000000-0000-4000-8000-000000000001')
          .first;
      expect(activeSamples.length, 1);
      expect(activeSamples.first.labelCode, 'SMP-2611-01A');

      await db.updateSampleVaultStatus(
        id: 'sv-001',
        status: 'disposed',
        isSynced: true,
      );
      final historySamples = await db
          .watchHistorySampleVaults('b1000000-0000-4000-8000-000000000001')
          .first;
      expect(historySamples.length, 1);
      expect(historySamples.first.status, 'disposed');
    });
  });

  group('Auth Floating Notification Coverage', () {
    testWidgets(
      'Email/password form login and S04 Pending Keluar logout show floating feedback',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final fakeRepo = _PendingFormFakeAuthRepository();

        await tester.pumpWidget(buildTestApp(prefs: prefs, fakeRepo: fakeRepo));
        await tester.pumpAndSettle();

        final fields = find.byType(TextFormField);
        await tester.ensureVisible(fields.at(0));
        await tester.enterText(fields.at(0), 'pending.sekolah@lacaksaji.id');
        await tester.enterText(fields.at(1), 'LacakSaji2026!');
        await tester.pump();

        final submitButton = find.byType(ElevatedButton).first;
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(find.text('Berhasil Masuk'), findsOneWidget);
        expect(
          find.text(
            'Masuk sebagai SDN Harapan Menunggu (Menunggu persetujuan SPPG).',
          ),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('auth_feedback_close_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Berhasil Masuk'), findsNothing);

        final logoutControl = find
            .ancestor(
              of: find.textContaining('Keluar'),
              matching: find.bySubtype<ButtonStyleButton>(),
            )
            .last;
        await tester.ensureVisible(logoutControl);
        await tester.tap(logoutControl);
        await tester.pumpAndSettle();
        final confirmLogout = find.textContaining('Ya, Keluar');
        if (confirmLogout.evaluate().isNotEmpty) {
          await tester.tap(confirmLogout.first);
          await tester.pumpAndSettle();
        }

        expect(find.text('Berhasil Keluar'), findsOneWidget);
        expect(
          find.text('Anda telah keluar dari akun SDN Harapan Menunggu.'),
          findsOneWidget,
        );

        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(find.text('Berhasil Keluar'), findsNothing);
      },
    );

    testWidgets(
      'C01 signOut loader only animates Keluar Akun without triggering sync loader',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final fakeRepo = _DelayedSignOutFakeAuthRepository();

        await tester.pumpWidget(buildTestApp(prefs: prefs, fakeRepo: fakeRepo));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Masuk Cepat (Akun Demo)'));
        await tester.tap(find.text('Masuk Cepat (Akun Demo)'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Sekolah 1: SDN 1 Purwokerto'));
        await tester.tap(find.text('Sekolah 1: SDN 1 Purwokerto'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Profil'));
        await tester.pumpAndSettle();

        final logoutButtonFinder = find.text('Keluar Akun');
        await tester.ensureVisible(logoutButtonFinder);
        await tester.tap(logoutButtonFinder);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ya, Keluar Akun'));
        await tester.pump();

        expect(
          find.descendant(
            of: find.ancestor(
              of: find.text('Keluar Akun'),
              matching: find.byType(ElevatedButton),
            ),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.ancestor(
              of: find.text('Sinkronkan & Perbarui Sekarang'),
              matching: find.byType(OutlinedButton),
            ),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.ancestor(
              of: find.text('Ubah WA Puskesmas & Wilayah'),
              matching: find.byType(OutlinedButton),
            ),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );

        fakeRepo.completeSignOut();
        await tester.pumpAndSettle();
        expect(find.text('Berhasil Keluar'), findsOneWidget);
      },
    );

    testWidgets(
      'C01 sync and refreshStatus loader only animates Sinkronkan without GPS or Keluar loaders',
      (tester) async {
        final tempDocsDir = Directory.systemTemp.createTempSync(
          'lacak_c01_sync_',
        );
        const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(pathChannel, (call) async {
              if (call.method == 'getApplicationDocumentsDirectory' ||
                  call.method == 'getTemporaryDirectory') {
                return tempDocsDir.path;
              }
              return null;
            });
        addTearDown(() async {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(pathChannel, null);
          if (tempDocsDir.existsSync()) {
            tempDocsDir.deleteSync(recursive: true);
          }
        });

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final fakeRepo = _DelayedSignOutFakeAuthRepository();

        await tester.pumpWidget(buildTestApp(prefs: prefs, fakeRepo: fakeRepo));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Masuk Cepat (Akun Demo)'));
        await tester.tap(find.text('Masuk Cepat (Akun Demo)'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Dapur SPPG A (SPPG-PWT-01)'));
        await tester.tap(find.text('Dapur SPPG A (SPPG-PWT-01)'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Profil'));
        await tester.pumpAndSettle();

        final syncButton = find.text('Sinkronkan & Perbarui Sekarang');
        await tester.ensureVisible(syncButton);
        await tester.tap(syncButton);
        for (var i = 0; i < 25 && !fakeRepo.refreshStarted; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(fakeRepo.refreshStarted, isTrue);

        expect(
          find.descendant(
            of: find.ancestor(
              of: find.text('Sinkronkan & Perbarui Sekarang'),
              matching: find.byType(OutlinedButton),
            ),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.ancestor(
              of: find.text('Perbarui Lokasi GPS Dapur'),
              matching: find.byType(OutlinedButton),
            ),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.ancestor(
              of: find.text('Keluar Akun'),
              matching: find.byType(ElevatedButton),
            ),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );

        fakeRepo.completeRefresh();
        await tester.pumpAndSettle();
        expect(
          find.text('Status akun dan profil berhasil disinkronkan.'),
          findsOneWidget,
        );
      },
    );
  });
}

class _DelayedSignOutFakeAuthRepository extends _FakeAuthRepository {
  final Completer<void> _signOutCompleter = Completer<void>();
  bool refreshStarted = false;
  final Completer<void> _refreshCompleter = Completer<void>();

  void completeSignOut() {
    if (!_signOutCompleter.isCompleted) {
      _signOutCompleter.complete();
    }
  }

  void completeRefresh() {
    if (!_refreshCompleter.isCompleted) {
      _refreshCompleter.complete();
    }
  }

  @override
  Future<AuthSessionSnapshot?> refreshSession() async {
    refreshStarted = true;
    await _refreshCompleter.future;
    return super.refreshSession();
  }

  @override
  Future<void> signOut() async {
    await _signOutCompleter.future;
    await super.signOut();
  }
}

class _PendingFormFakeAuthRepository extends _FakeAuthRepository {
  @override
  Future<AuthSessionSnapshot> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (email.trim() == 'pending.sekolah@lacaksaji.id') {
      currentSession = const AuthSessionSnapshot(
        profile: UserProfile(
          id: 'u-pending',
          email: 'pending.sekolah@lacaksaji.id',
          role: UserRole.school,
          fullName: 'Ibu Rina',
        ),
        school: SchoolProfile(
          id: 's-pending',
          ownerUserId: 'u-pending',
          sppgId: 'k-1',
          npsn: '20309999',
          name: 'SDN Harapan Menunggu',
          adm4Code: '33.02.26.1001',
          lat: -7.42,
          lng: 109.23,
          puskesmasWa: '628112800001',
          verificationStatus: SchoolVerificationStatus.pending,
          partnerKitchenName: 'SPPG Purwokerto Utara',
          partnerInviteCode: 'SPPG-PWT-01',
        ),
      );
      return currentSession!;
    }
    return super.signInWithPassword(email: email, password: password);
  }
}
