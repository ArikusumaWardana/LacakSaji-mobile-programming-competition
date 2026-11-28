import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lacak_saji/core/constants/demo_accounts.dart';
import 'package:lacak_saji/core/database/app_database.dart';
import 'package:lacak_saji/core/database/database_provider.dart';
import 'package:lacak_saji/core/network/bmkg_weather_service.dart';
import 'package:lacak_saji/core/network/connectivity_provider.dart';
import 'package:lacak_saji/core/theme/app_theme.dart';
import 'package:lacak_saji/core/theme/text_scale_provider.dart';
import 'package:lacak_saji/core/widgets/editorial_widgets.dart';
import 'package:lacak_saji/core/widgets/lacak_adaptive_shell.dart';
import 'package:lacak_saji/features/alerts/domain/cluster_alert_models.dart';
import 'package:lacak_saji/features/allergens/domain/allergen_models.dart';
import 'package:lacak_saji/features/allergens/presentation/allergen_providers.dart';
import 'package:lacak_saji/features/auth/data/auth_repository.dart';
import 'package:lacak_saji/features/auth/domain/auth_models.dart';
import 'package:lacak_saji/features/auth/presentation/auth_controller.dart';
import 'package:lacak_saji/features/auth/presentation/login_screen.dart';
import 'package:lacak_saji/features/courier/presentation/courier_dashboard_screen.dart';
import 'package:lacak_saji/features/kitchen/data/batch_export_service.dart';
import 'package:lacak_saji/features/kitchen/domain/kitchen_models.dart';
import 'package:lacak_saji/features/school/data/parent_summary_export_service.dart';
import 'package:lacak_saji/features/school/domain/danger_zone_calculator.dart';
import 'package:lacak_saji/features/school/domain/school_models.dart';
import 'package:lacak_saji/features/school/presentation/school_dashboard_screen.dart';
import 'package:lacak_saji/features/school/presentation/school_providers.dart';
import 'package:lacak_saji/features/school/presentation/widgets/parent_daily_summary_card.dart';
import 'package:lacak_saji/features/settings/presentation/settings_screen.dart';
import 'package:lacak_saji/features/supervisor/domain/supervisor_models.dart';
import 'package:lacak_saji/features/supervisor/presentation/supervisor_home_screen.dart';
import 'package:lacak_saji/features/supervisor/presentation/supervisor_providers.dart';
import 'package:lacak_saji/features/traceability/domain/traceability_models.dart';
import 'package:lacak_saji/features/traceability/presentation/traceability_providers.dart';

final RegExp _emojiRegex = RegExp(
  r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]',
  unicode: true,
);

void _assertZeroSlop(String text) {
  expect(text.contains('\u2014'), isFalse, reason: 'Em-dash forbidden: $text');
  expect(_emojiRegex.hasMatch(text), isFalse, reason: 'Emoji forbidden: $text');
}

class _FixedAuthController extends AuthController {
  _FixedAuthController(this._fixedState);

  final AuthState _fixedState;

  @override
  AuthState build() => _fixedState;
}

class _FakeAuthRepo extends Fake implements AuthRepository {
  String? lastSignedInEmail;

  @override
  Future<AuthSessionSnapshot?> restoreSession() async => null;

  @override
  Future<AuthSessionSnapshot> signInWithPassword({
    required String email,
    required String password,
  }) async {
    lastSignedInEmail = email;
    return AuthSessionSnapshot(
      profile: UserProfile(
        id: '40000000-0000-4000-8000-000000000001',
        email: email,
        role: UserRole.courier,
        fullName: 'Bapak Dedi (Kurir SPPG Purwokerto Utara)',
      ),
    );
  }
}

class _FakeParentExportService implements ParentSummaryExportService {
  int shareCalls = 0;

  @override
  Future<String> shareParentSummaryPng({
    required String schoolName,
    required DateTime dateUtc,
    required String menuName,
    required String batchCode,
    required DateTime cookedAtUtc,
    required DateTime arrivedAtUtc,
    required String sampleLabelCode,
    required List<String> allergenTags,
    required Uint8List pngBytes,
  }) async {
    shareCalls++;
    return '/tmp/ringkasan_wali_$batchCode.png';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  const kitchen = KitchenProfile(
    id: 'a1000000-0000-4000-8000-000000000001',
    ownerUserId: '10000000-0000-4000-8000-000000000001',
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
    partnerPublicKey: 'ZmFrZV9wdWJsaWNfa2V5',
  );

  const courierUser = UserProfile(
    id: '40000000-0000-4000-8000-000000000001',
    email: 'kurir.a@lacaksaji.id',
    role: UserRole.courier,
    fullName: 'Bapak Dedi (Kurir SPPG Purwokerto Utara)',
  );

  const schoolUser = UserProfile(
    id: '20000000-0000-4000-8000-000000000001',
    email: 'sdn1.pwt@lacaksaji.id',
    role: UserRole.school,
    fullName: 'Ibu Siti (PIC SDN 1 Purwokerto)',
  );

  const supervisorUser = UserProfile(
    id: '30000000-0000-4000-8000-000000000001',
    email: 'pengawas.bgn@lacaksaji.id',
    role: UserRole.supervisor,
    fullName: 'Pengawas BGN Wilayah Banyumas',
  );

  test('Parent summary WhatsApp caption excludes sensitive info and slop', () {
    final cooked = DateTime.utc(2026, 11, 24, 0, 15);
    final arrived = DateTime.utc(2026, 11, 24, 1, 30);

    final caption = DeviceParentSummaryExportService.buildParentWhatsAppCaption(
      schoolName: school.name,
      dateUtc: arrived,
      menuName: 'Telur Balado & Tempe',
      batchCode: 'BCH-WALI-01',
      cookedAtUtc: cooked,
      arrivedAtUtc: arrived,
      sampleLabelCode: 'SMP-2611-W01',
      allergenTags: const ['telur', 'kedelai'],
    );

    _assertZeroSlop(caption);
    expect(caption, contains('SDN 1 Purwokerto'));
    expect(caption, contains('Telur Balado & Tempe'));
    expect(caption, contains('07:15 WIB'));
    expect(caption, contains('08:30 WIB'));
    expect(caption, contains('Lulus Cek Visual & Bank Sampel Tersimpan'));
    expect(caption, contains('SMP-2611-W01'));
    expect(caption, contains('Telur'));
    expect(caption, contains('Kedelai / Tahu-Tempe'));
    expect(caption, isNot(contains('628112800001')));
    expect(caption, isNot(contains('Ibu Siti')));
    expect(caption, isNot(contains('KLB')));
    expect(caption, isNot(contains('Puskesmas')));
  });

  testWidgets(
    'ParentDailySummaryCard captures crisp PNG via RepaintBoundary cleanly',
    (tester) async {
      final boundaryKey = GlobalKey();
      final cooked = DateTime.utc(2026, 11, 24, 0, 15);
      final arrived = DateTime.utc(2026, 11, 24, 1, 30);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RepaintBoundary(
                key: boundaryKey,
                child: ParentDailySummaryCard(
                  schoolName: school.name,
                  dateUtc: arrived,
                  menuName: 'Telur Balado & Tempe',
                  batchCode: 'BCH-WALI-01',
                  cookedAtUtc: cooked,
                  arrivedAtUtc: arrived,
                  sampleLabelCode: 'SMP-2611-W01',
                  allergenTags: const ['telur', 'kedelai'],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RINGKASAN HARIAN MAKANAN SEKOLAH'), findsOneWidget);
      expect(find.text('SDN 1 Purwokerto'), findsOneWidget);
      expect(find.text('LULUS CEK VISUAL'), findsOneWidget);
      expect(find.text('Tersimpan (SMP-2611-W01)'), findsOneWidget);
      expect(find.textContaining('Kedelai / Tahu-Tempe'), findsOneWidget);

      final pngBytes = await tester.runAsync(
        () => captureRepaintBoundaryPng(boundaryKey),
      );
      expect(pngBytes, isNotNull);
      expect(pngBytes!.length, greaterThan(1000));
      // Valid PNG magic header bytes.
      expect(pngBytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    },
  );

  testWidgets(
    'G01 detail sheet exposes Bagikan Ringkasan ke Wali Murid only when approved + Bank Sampel exists',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final fakeExport = _FakeParentExportService();
      final nowUtc = DateTime.utc(2026, 11, 24, 2, 0);
      final approvedItem = SchoolInspectionItem(
        id: 'insp-ok-1',
        batchId: 'batch-ok-1',
        batchCode: 'BCH-OK-01',
        menuName: 'Nasi Ayam Goreng & Tumis Buncis',
        schoolId: school.id,
        scannedAtUtc: nowUtc,
        sealedAtUtc: nowUtc.subtract(const Duration(minutes: 40)),
        elapsedMinutes: 40,
        bmkgTempC: 28.0,
        bmkgSource: BmkgSource.live,
        dangerStatus: DangerZoneStatus.green,
        gpsWithinRadius: true,
        manualSmellOk: true,
        manualVisualOk: true,
        manualPackOk: true,
        finalDecision: 'APPROVED',
        sampleLabelCode: 'SMP-2611-OK1',
        allergenTags: const ['telur'],
      );
      final rejectedItem = SchoolInspectionItem(
        id: 'insp-rej-1',
        batchId: 'batch-rej-1',
        batchCode: 'BCH-REJ-01',
        menuName: 'Santan Ayam Basah',
        schoolId: school.id,
        scannedAtUtc: nowUtc,
        sealedAtUtc: nowUtc.subtract(const Duration(minutes: 200)),
        elapsedMinutes: 200,
        bmkgTempC: 33.5,
        bmkgSource: BmkgSource.live,
        dangerStatus: DangerZoneStatus.red,
        gpsWithinRadius: true,
        manualSmellOk: false,
        manualVisualOk: false,
        manualPackOk: true,
        finalDecision: 'REJECTED',
      );

      final dashData = SchoolDashboardData(
        school: school,
        weather: BmkgWeatherReading(
          adm4Code: school.adm4Code,
          temperatureC: 28.0,
          source: BmkgSource.live,
          observedAtUtc: nowUtc,
        ),
        todayInspections: [approvedItem, rejectedItem],
        activeSampleCount: 1,
        partnerKeyCached: true,
      );

      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final g01Router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SchoolDashboardScreen(),
          ),
        ],
      );
      addTearDown(g01Router.dispose);

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
                const AuthState(
                  status: AuthStatus.authenticated,
                  profile: schoolUser,
                  school: school,
                ),
              ),
            ),
            schoolDashboardProvider.overrideWith((ref) async => dashData),
            activeSampleVaultsProvider.overrideWith(
              (ref) => Stream.value(const <SampleVaultItem>[]),
            ),
            historySampleVaultsProvider.overrideWith(
              (ref) => Stream.value(const <SampleVaultItem>[]),
            ),
            parentSummaryExportServiceProvider.overrideWithValue(fakeExport),
            parentSummaryPngCapturerProvider.overrideWithValue(
              (_) async => Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: g01Router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final approvedTile = find.text('Nasi Ayam Goreng & Tumis Buncis');
      await tester.ensureVisible(approvedTile);
      await tester.tap(approvedTile);
      await tester.pumpAndSettle();

      final shareBtn = find.text('Bagikan Ringkasan ke Wali Murid');
      await tester.ensureVisible(shareBtn);
      expect(shareBtn, findsOneWidget);
      await tester.tap(shareBtn);
      await tester.pumpAndSettle();

      expect(find.text('Pratinjau Kartu Wali Murid'), findsOneWidget);
      final sharePngBtn = find.text('Bagikan PNG ke Wali Murid');
      await tester.ensureVisible(sharePngBtn);
      await tester.tap(sharePngBtn);
      await tester.pumpAndSettle();
      expect(fakeExport.shareCalls, 1);

      await tester.tap(
        find.byWidgetPredicate((w) => w is IconButton && w.tooltip == 'Tutup'),
      );
      await tester.pumpAndSettle();

      final rejectedTile = find.text('Santan Ayam Basah');
      await tester.ensureVisible(rejectedTile);
      await tester.tap(rejectedTile);
      await tester.pumpAndSettle();
      expect(find.text('Bagikan Ringkasan ke Wali Murid'), findsNothing);
    },
  );

  testWidgets(
    'S02 LoginScreen exposes Masuk Cepat - Kurir Demo and signs in kurir.a@lacaksaji.id',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final fakeAuthRepo = _FakeAuthRepo();

      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
            isOfflineProvider.overrideWith((ref) => Stream.value(false)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final courierDemoBtn = find.text('Masuk Cepat - Kurir Demo');
      await tester.ensureVisible(courierDemoBtn);
      expect(courierDemoBtn, findsOneWidget);
      await tester.tap(courierDemoBtn);
      await tester.pumpAndSettle();

      expect(fakeAuthRepo.lastSignedInEmail, 'kurir.a@lacaksaji.id');
      expect(
        kDemoAccounts.any((p) => p.isCourier && p.email == 'kurir.a@lacaksaji.id'),
        isTrue,
      );
    },
  );

  testWidgets(
    'AppShell adapts Zoom Drawer (<600dp) and permanent sidebar (>=600dp) for all 4 roles including Pengawas BGN',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      GoRouter buildShellRouter(List<LacakNavDestination> destinations) {
        return GoRouter(
          initialLocation: '/home',
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (context, state, shell) => LacakAdaptiveShell(
                navigationShell: shell,
                destinations: destinations,
              ),
              branches: [
                for (var i = 0; i < destinations.length; i++)
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: i == 0 ? '/home' : '/tab-$i',
                        builder: (context, state) => const Scaffold(
                          body: MinimalTopHeader(
                            contextLabel: 'Panel Uji',
                            title: 'Konten Utama',
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        );
      }

      // Mobile (<600dp) Zoom Drawer for Supervisor
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mobileRouter = buildShellRouter(LacakShellDestinations.supervisor);
      addTearDown(mobileRouter.dispose);

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
                const AuthState(
                  status: AuthStatus.authenticated,
                  profile: supervisorUser,
                ),
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: mobileRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Konten Utama'), findsOneWidget);
      final menuIcon = find.byIcon(Icons.menu_rounded);
      expect(menuIcon, findsOneWidget);
      await tester.tap(menuIcon);
      await tester.pumpAndSettle();
      expect(find.text('Pengawas BGN'), findsOneWidget);
      expect(find.text('Ringkasan Wilayah'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
      expect(find.text('Keluar Akun'), findsOneWidget);

      // Tablet (>=600dp) permanent sidebar checks all 4 role destination sets
      tester.view.physicalSize = const Size(768, 1024);
      for (final entry in <(List<LacakNavDestination>, String, String)>[
        (LacakShellDestinations.kitchen, 'Dapur SPPG', 'Logistik Wadah'),
        (LacakShellDestinations.courier, 'Kurir Pengantar', 'Pengiriman'),
        (LacakShellDestinations.school, 'Sekolah Binaan', 'Sisa Makan'),
        (LacakShellDestinations.supervisor, 'Pengawas BGN', 'Ringkasan Wilayah'),
      ]) {
        final tabletRouter = buildShellRouter(entry.$1);
        addTearDown(tabletRouter.dispose);
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              appDatabaseProvider.overrideWithValue(db),
              pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
              isOfflineProvider.overrideWith((ref) => Stream.value(false)),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: tabletRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(entry.$2), findsOneWidget);
        expect(find.text(entry.$3), findsOneWidget);
      }
    },
  );

  testWidgets(
    '4-breakpoint responsive audit (<360dp, 360-411dp, 412-599dp, >=600dp) at 1.30x Ekstra Besar with zero overflow',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final errors = <FlutterErrorDetails>[];
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        oldOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldOnError);

      final nowUtc = DateTime.utc(2026, 11, 24, 3, 0);
      final supervisorOverview = SupervisorNationalOverview(
        dateFilter: SupervisorDateFilter.last30Days,
        regionFilter: 'Semua Wilayah',
        availableRegions: const ['Semua Wilayah', 'Purwokerto Utara'],
        totalSppgCount: 1,
        totalApprovedSchoolsCount: 2,
        totalBatches: 10,
        safeBatches: 9,
        problemBatches: 1,
        activeAlertsCount: 0,
        avgWastePct: 14,
        avgTransitMinutes: 28,
        trayReturnRatePct: 96,
        resolvedAlertsCount: 1,
        activeAlerts: const [],
        alertResolutionHistory: [
          SupervisorAlertResolutionBrief(
            id: 'res-1',
            alertId: 'alert-1',
            sppgId: kitchen.id,
            sppgName: kitchen.name,
            batchCode: 'BCH-2611-24A',
            menuName: 'Nasi Ayam & Buncis',
            previousStatus: AlertResolutionStatus.active,
            newStatus: AlertResolutionStatus.clarifiedSafe,
            resolutionNote: 'Hanya 1 wadah tumpah di mobil boks, batch utama aman.',
            actorName: 'Ibu Ratna (Admin SPPG)',
            createdAtUtc: nowUtc.subtract(const Duration(minutes: 15)),
          ),
        ],
        sppgSummaries: [
          SupervisorSppgSummary(
            sppgId: kitchen.id,
            sppgName: kitchen.name,
            inviteCode: kitchen.inviteCode,
            adm4Code: kitchen.adm4Code,
            regionName: 'Purwokerto Utara',
            approvedSchoolCount: 2,
            totalBatches: 10,
            safeBatches: 9,
            problemBatches: 1,
            activeAlertsCount: 0,
            avgCarbWastePct: 12,
            avgProteinWastePct: 10,
            avgVegWastePct: 20,
            avgOverallWastePct: 14,
            wasteLogCount: 5,
            avgTransitMinutes: 28,
            trayReturnRatePct: 96,
          ),
        ],
        generatedAtUtc: nowUtc,
      );

      final schoolDash = SchoolDashboardData(
        school: school,
        weather: BmkgWeatherReading(
          adm4Code: school.adm4Code,
          temperatureC: 28.0,
          source: BmkgSource.live,
          observedAtUtc: nowUtc,
        ),
        todayInspections: const [],
        activeSampleCount: 0,
        partnerKeyCached: true,
      );

      const breakpoints = [
        Size(320, 760), // < 360dp
        Size(390, 844), // 360 - 411dp
        Size(480, 854), // 412 - 599dp
        Size(768, 1024), // >= 600dp
      ];

      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final size in breakpoints) {
        await tester.binding.setSurfaceSize(size);

        Widget wrapScaled(Widget child, List overrides) {
          return ProviderScope(
            key: UniqueKey(),
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              appDatabaseProvider.overrideWithValue(db),
              pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
              isOfflineProvider.overrideWith((ref) => Stream.value(false)),
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

        // LoginScreen (S02)
        await tester.pumpWidget(wrapScaled(const LoginScreen(), const []));
        await tester.pumpAndSettle();

        // SchoolDashboardScreen (G01)
        await tester.pumpWidget(
          wrapScaled(const SchoolDashboardScreen(), [
            authControllerProvider.overrideWith(
              () => _FixedAuthController(
                const AuthState(
                  status: AuthStatus.authenticated,
                  profile: schoolUser,
                  school: school,
                ),
              ),
            ),
            schoolDashboardProvider.overrideWith((ref) async => schoolDash),
            activeSampleVaultsProvider.overrideWith(
              (ref) => Stream.value(const <SampleVaultItem>[]),
            ),
            historySampleVaultsProvider.overrideWith(
              (ref) => Stream.value(const <SampleVaultItem>[]),
            ),
          ]),
        );
        await tester.pumpAndSettle();

        // CourierDashboardScreen (K01)
        await tester.pumpWidget(
          wrapScaled(const CourierDashboardScreen(), [
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
            courierDeliveriesProvider.overrideWith(
              (ref) async => const <CourierBatchDeliveryItem>[],
            ),
          ]),
        );
        await tester.pumpAndSettle();

        // SupervisorHomeScreen (B01)
        await tester.pumpWidget(
          wrapScaled(const SupervisorHomeScreen(), [
            authControllerProvider.overrideWith(
              () => _FixedAuthController(
                const AuthState(
                  status: AuthStatus.authenticated,
                  profile: supervisorUser,
                ),
              ),
            ),
            supervisorOverviewProvider.overrideWith(
              (ref) async => supervisorOverview,
            ),
          ]),
        );
        await tester.pumpAndSettle();

        expect(find.text('Rata Transit Kurir'), findsOneWidget);
        expect(find.text('28 mnt'), findsOneWidget);
        expect(find.text('Retur Ompreng'), findsOneWidget);
        expect(find.text('96%'), findsOneWidget);
        expect(
          find.text('Riwayat Klarifikasi & Resolusi Alarm (1)'),
          findsOneWidget,
        );

        // SettingsScreen (C01)
        await tester.pumpWidget(
          wrapScaled(const SettingsScreen(), [
            authControllerProvider.overrideWith(
              () => _FixedAuthController(
                const AuthState(
                  status: AuthStatus.authenticated,
                  profile: schoolUser,
                  school: school,
                ),
              ),
            ),
            schoolAllergensProvider.overrideWith(
              (ref) async => const <SchoolAllergenEntry>[],
            ),
          ]),
        );
        await tester.pumpAndSettle();
      }

      expect(errors, isEmpty, reason: 'Responsive audit errors: $errors');
    },
  );
}
