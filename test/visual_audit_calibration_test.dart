import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'package:lacak_saji/core/crypto/batch_qr_payload.dart';
import 'package:lacak_saji/core/media/live_camera_webp_service.dart';
import 'package:lacak_saji/core/network/bmkg_weather_service.dart';
import 'package:lacak_saji/core/network/connectivity_provider.dart';
import 'package:lacak_saji/core/theme/app_theme.dart';
import 'package:lacak_saji/features/auth/domain/auth_models.dart';
import 'package:lacak_saji/features/auth/presentation/auth_controller.dart';
import 'package:lacak_saji/features/kitchen/domain/kitchen_models.dart';
import 'package:lacak_saji/features/school/data/hybrid_vision_service.dart';
import 'package:lacak_saji/features/school/domain/danger_zone_calculator.dart';
import 'package:lacak_saji/features/school/domain/school_models.dart';
import 'package:lacak_saji/features/school/presentation/visual_audit_screen.dart';
import 'package:lacak_saji/features/school/presentation/widgets/audit_detail_sections.dart';

class _StubSchoolAuthController extends AuthController {
  @override
  AuthState build() {
    return const AuthState(
      status: AuthStatus.authenticated,
      profile: UserProfile(
        id: '20000000-0000-4000-8000-000000000001',
        email: 'sdn1.pwt@lacaksaji.id',
        role: UserRole.school,
        fullName: 'Ibu Siti',
      ),
      school: SchoolProfile(
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
      ),
    );
  }
}

class _FakeCameraService implements LiveCameraWebpService {
  _FakeCameraService(this.photoBytes);

  final Uint8List photoBytes;

  @override
  Future<CapturedWebpPhoto?> captureAndCompress() async {
    return CapturedWebpPhoto(
      filePath: 'test/fixtures/normal_mbg_tray.jpg',
      bytes: photoBytes,
      sizeBytes: photoBytes.length,
    );
  }
}

class _ConfigurableHybridVisionService implements HybridVisionService {
  _ConfigurableHybridVisionService({
    required this.onDeviceResult,
    required this.cloudResult,
  });

  final OnDeviceVisualResult onDeviceResult;
  final CloudVisionResult cloudResult;

  @override
  Future<OnDeviceVisualResult> analyzeOnDevice(Uint8List photoBytes) async {
    return onDeviceResult;
  }

  @override
  Future<CloudVisionResult> analyzeCloudOrganoleptic({
    required Uint8List photoBytes,
    required String menuName,
    required bool isOffline,
    OnDeviceVisualResult? localScreening,
  }) async {
    return cloudResult;
  }

  @override
  Future<OnDeviceVisualResult> estimatePlateWasteOnDevice(
    List<Uint8List> photoBytesList,
  ) async {
    return onDeviceResult;
  }

  @override
  Future<CloudVisionResult> analyzeCloudPlateWaste({
    required List<Uint8List> photoBytesList,
    required String menuName,
    required bool isOffline,
  }) async {
    return cloudResult;
  }
}

VerifiedBatchScanContext _buildScanContext({
  String menuName = 'Nasi Ayam Goreng',
}) {
  final now = DateTime.utc(2026, 11, 24, 5, 0);
  return VerifiedBatchScanContext(
    payload: BatchQrPayload(
      batchId: 'batch-cal-001',
      batchCode: 'BCH-2611-24C1',
      sppgId: 'a1000000-0000-4000-8000-000000000001',
      menuName: menuName,
      riskCategory: 'HIGH',
      sealedAtEpochSec:
          now.subtract(const Duration(minutes: 15)).millisecondsSinceEpoch ~/
          1000,
      timestampSource: 'server_verified',
      signatureB64: 'sig-cal-001',
    ),
    riskCategory: FoodRiskCategory.high,
    timestampSource: BatchTimestampSource.serverVerified,
    sealedAtUtc: now.subtract(const Duration(minutes: 15)),
    scannedAtUtc: now,
    sppgName: 'SPPG Purwokerto Utara',
    sppgPublicKeyB64: 'pk-cal-001',
    weather: BmkgWeatherReading(
      adm4Code: '33.02.26.1001',
      temperatureC: 26.5,
      source: BmkgSource.live,
      observedAtUtc: now,
    ),
    dangerEvaluation: const DangerZoneEvaluation(
      status: DangerZoneStatus.green,
      elapsedMinutes: 15,
      safeLimitMinutes: 90,
      stopLimitMinutes: 180,
      isHotWeather: false,
      explanation: 'Durasi pengiriman masih dalam batas aman.',
    ),
    gpsWithinRadius: true,
    distanceMeters: 420,
  );
}

void main() {
  late Uint8List trayPhotoBytes;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    trayPhotoBytes = File('test/fixtures/normal_mbg_tray.jpg').readAsBytesSync();
  });

  group('VisualAuditScreen calibration & menu mismatch checks', () {
    test('MenuMatchStatus.fromDb & CloudVisionResult.toJsonMap round-trip', () {
      expect(MenuMatchStatus.fromDb('match'), MenuMatchStatus.match);
      expect(MenuMatchStatus.fromDb('partial'), MenuMatchStatus.partial);
      expect(MenuMatchStatus.fromDb('mismatch'), MenuMatchStatus.mismatch);
      expect(MenuMatchStatus.fromDb('unknown'), MenuMatchStatus.unknown);
      expect(MenuMatchStatus.fromDb('invalid'), isNull);
      expect(MenuMatchStatus.fromDb(null), isNull);

      const mismatchResult = CloudVisionResult(
        ok: true,
        provider: 'gemini_flash',
        fallbackRequired: false,
        summaryText: 'Semua komponen tampak segar.',
        freshnessStatus: OnDeviceVisualLabel.freshLikely,
        menuMatch: MenuMatchStatus.mismatch,
        menuMatchNote: 'Lauk ayam diganti tempe goreng.',
      );
      expect(mismatchResult.hasMenuMismatch, isTrue);
      final json = mismatchResult.toJsonMap();
      expect(json['menu_match'], equals('mismatch'));
      expect(json['menu_match_note'], equals('Lauk ayam diganti tempe goreng.'));

      const noMismatchResult = CloudVisionResult(
        ok: true,
        provider: 'gemini_flash',
        fallbackRequired: false,
        summaryText: 'Semua komponen tampak segar.',
      );
      expect(noMismatchResult.hasMenuMismatch, isFalse);
      final bareJson = noMismatchResult.toJsonMap();
      expect(bareJson.containsKey('menu_match'), isFalse);
      expect(bareJson.containsKey('menu_match_note'), isFalse);
    });

    testWidgets(
      'Cloud freshLikely overrides noisy local hint & shows WAJAR without menu warning when matched',
      (tester) async {
        final fakeVision = _ConfigurableHybridVisionService(
          onDeviceResult: const OnDeviceVisualResult(
            label: OnDeviceVisualLabel.suspiciousDiscoloration,
            confidence: 0.84,
            summaryText: 'Terdeteksi bagian gosong menghitam pada lauk.',
            usedTfliteModel: true,
            localHints: ['Terdeteksi bagian gelap pada lauk'],
          ),
          cloudResult: const CloudVisionResult(
            ok: true,
            provider: 'gemini_flash',
            fallbackRequired: false,
            summaryText: 'Nasi putih, ayam goreng, sayur, dan buah tampak segar.',
            freshnessStatus: OnDeviceVisualLabel.freshLikely,
            slimeOrDiscolorationDetected: false,
            packagingIssueDetected: false,
            menuMatch: MenuMatchStatus.match,
            menuMatchNote: '',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(
                _StubSchoolAuthController.new,
              ),
              liveCameraWebpServiceProvider.overrideWithValue(
                _FakeCameraService(trayPhotoBytes),
              ),
              hybridVisionServiceProvider.overrideWithValue(fakeVision),
              isOfflineProvider.overrideWith((ref) => Stream.value(false)),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: VisualAuditScreen(scanContext: _buildScanContext()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ambil Foto Sampel'));
        await tester.pumpAndSettle();

        expect(find.text('TAMPAK WAJAR SECARA VISUAL'), findsOneWidget);
        expect(find.text('WAJAR'), findsOneWidget);
        expect(find.text('TERINDIKASI TIDAK LAYAK'), findsNothing);
        expect(find.text('Isi Tidak Sesuai Menu'), findsNothing);
        expect(find.text('Sebagian Menu Tidak Sesuai'), findsNothing);
      },
    );

    testWidgets(
      'Cloud freshLikely with mismatch shows safety WAJAR plus amber menu warning banner and WA note',
      (tester) async {
        const mismatchNote =
            'Menu tertulis Nasi Ayam Goreng, namun lauk yang terlihat pada foto adalah tempe goreng.';
        final fakeVision = _ConfigurableHybridVisionService(
          onDeviceResult: const OnDeviceVisualResult(
            label: OnDeviceVisualLabel.freshLikely,
            confidence: 0.88,
            summaryText: 'Tampilan visual makanan tampak wajar.',
            usedTfliteModel: true,
          ),
          cloudResult: const CloudVisionResult(
            ok: true,
            provider: 'gemini_flash',
            fallbackRequired: false,
            summaryText: 'Makanan tampak segar, namun lauk berbeda dari label QR.',
            freshnessStatus: OnDeviceVisualLabel.freshLikely,
            slimeOrDiscolorationDetected: false,
            packagingIssueDetected: false,
            menuMatch: MenuMatchStatus.mismatch,
            menuMatchNote: mismatchNote,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(
                _StubSchoolAuthController.new,
              ),
              liveCameraWebpServiceProvider.overrideWithValue(
                _FakeCameraService(trayPhotoBytes),
              ),
              hybridVisionServiceProvider.overrideWithValue(fakeVision),
              isOfflineProvider.overrideWith((ref) => Stream.value(false)),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: VisualAuditScreen(scanContext: _buildScanContext()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ambil Foto Sampel'));
        await tester.pumpAndSettle();

        expect(find.text('TAMPAK WAJAR SECARA VISUAL'), findsOneWidget);
        expect(find.text('Isi Tidak Sesuai Menu'), findsOneWidget);
        expect(find.text(mismatchNote), findsOneWidget);

        final partnerRow = tester.widget<PartnerContactRow>(
          find.byType(PartnerContactRow),
        );
        expect(partnerRow.waPrefillMessage, contains(mismatchNote));
      },
    );

    testWidgets(
      'Cloud freshLikely with partial shows Sebagian Menu Tidak Sesuai banner',
      (tester) async {
        const partialNote =
            'Lauk ayam sesuai, namun sayur bayam diganti tumis buncis dan wortel.';
        final fakeVision = _ConfigurableHybridVisionService(
          onDeviceResult: const OnDeviceVisualResult(
            label: OnDeviceVisualLabel.freshLikely,
            confidence: 0.87,
            summaryText: 'Tampilan visual makanan tampak wajar.',
            usedTfliteModel: true,
          ),
          cloudResult: const CloudVisionResult(
            ok: true,
            provider: 'gemini_flash',
            fallbackRequired: false,
            summaryText: 'Makanan tampak segar dengan variasi komponen sayur.',
            freshnessStatus: OnDeviceVisualLabel.freshLikely,
            slimeOrDiscolorationDetected: false,
            packagingIssueDetected: false,
            menuMatch: MenuMatchStatus.partial,
            menuMatchNote: partialNote,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(
                _StubSchoolAuthController.new,
              ),
              liveCameraWebpServiceProvider.overrideWithValue(
                _FakeCameraService(trayPhotoBytes),
              ),
              hybridVisionServiceProvider.overrideWithValue(fakeVision),
              isOfflineProvider.overrideWith((ref) => Stream.value(false)),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: VisualAuditScreen(scanContext: _buildScanContext()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ambil Foto Sampel'));
        await tester.pumpAndSettle();

        expect(find.text('TAMPAK WAJAR SECARA VISUAL'), findsOneWidget);
        expect(find.text('Sebagian Menu Tidak Sesuai'), findsOneWidget);
        expect(find.text(partialNote), findsOneWidget);
      },
    );

    testWidgets(
      'Compact 320dp viewport at 1.30x text scale renders menu mismatch banner with zero overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeVision = _ConfigurableHybridVisionService(
          onDeviceResult: const OnDeviceVisualResult(
            label: OnDeviceVisualLabel.freshLikely,
            confidence: 0.89,
            summaryText: 'Tampilan visual makanan tampak wajar.',
            usedTfliteModel: true,
          ),
          cloudResult: const CloudVisionResult(
            ok: true,
            provider: 'gemini_flash',
            fallbackRequired: false,
            summaryText: 'Makanan segar, tetapi lauk utama berbeda dari label.',
            freshnessStatus: OnDeviceVisualLabel.freshLikely,
            slimeOrDiscolorationDetected: false,
            packagingIssueDetected: false,
            menuMatch: MenuMatchStatus.mismatch,
            menuMatchNote:
                'Tertulis Nasi Ikan Kembung, tetapi yang terlihat adalah ayam goreng.',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(
                _StubSchoolAuthController.new,
              ),
              liveCameraWebpServiceProvider.overrideWithValue(
                _FakeCameraService(trayPhotoBytes),
              ),
              hybridVisionServiceProvider.overrideWithValue(fakeVision),
              isOfflineProvider.overrideWith((ref) => Stream.value(false)),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              builder: (context, child) {
                final data = MediaQuery.of(context);
                return MediaQuery(
                  data: data.copyWith(
                    textScaler: const TextScaler.linear(1.30),
                  ),
                  child: child!,
                );
              },
              home: VisualAuditScreen(scanContext: _buildScanContext()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ambil Foto Sampel'));
        await tester.pumpAndSettle();

        expect(find.text('Isi Tidak Sesuai Menu'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
