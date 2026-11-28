import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lacak_saji/core/database/app_database.dart';
import 'package:lacak_saji/core/database/database_provider.dart';
import 'package:lacak_saji/core/network/connectivity_provider.dart';
import 'package:lacak_saji/core/sync/offline_sync_controller.dart';
import 'package:lacak_saji/core/sync/sync_queue_presenter.dart';
import 'package:lacak_saji/core/theme/app_theme.dart';
import 'package:lacak_saji/core/theme/text_scale_provider.dart';
import 'package:lacak_saji/core/widgets/lacak_offline_bar.dart';
import 'package:lacak_saji/core/widgets/lacak_sync_queue_sheet.dart';
import 'package:lacak_saji/features/alerts/data/cluster_alert_repository.dart';
import 'package:lacak_saji/features/auth/data/auth_repository.dart';
import 'package:lacak_saji/features/auth/domain/auth_models.dart';
import 'package:lacak_saji/features/auth/presentation/auth_controller.dart';
import 'package:lacak_saji/features/kitchen/data/kitchen_repository.dart';
import 'package:lacak_saji/features/kitchen/presentation/kitchen_providers.dart';
import 'package:lacak_saji/features/school/data/school_repository.dart';
import 'package:lacak_saji/features/school/presentation/school_providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAuthRepository extends Fake implements AuthRepository {
  _TestAuthRepository(this.session);
  final AuthSessionSnapshot session;

  @override
  Future<AuthSessionSnapshot?> restoreSession() async => session;

  @override
  Future<AuthSessionSnapshot?> refreshSession() async => session;
}

class _NoopKitchenRepository extends Fake implements KitchenRepository {}

class _NoopClusterAlertRepository extends Fake
    implements ClusterAlertRepository {
  @override
  Future<int> syncPendingAlerts({String? schoolId, String? kitchenId}) async =>
      0;
}

class _StubSchoolRepository extends Fake implements SchoolRepository {
  _StubSchoolRepository(this.onSync);
  final Future<int> Function() onSync;

  @override
  Future<int> syncPendingSchoolQueue({required SchoolProfile school}) =>
      onSync();
}

/// Pure-Dart in-memory AppDatabase stub avoids SQLite isolate deadlocks inside FakeAsync widget tests.
class _FakeQueueDatabase extends Fake implements AppDatabase {
  _FakeQueueDatabase(List<LocalSyncQueueData> initial)
    : _items = List<LocalSyncQueueData>.from(initial);

  final List<LocalSyncQueueData> _items;
  final StreamController<List<LocalSyncQueueData>> _itemsCtrl =
      StreamController<List<LocalSyncQueueData>>.broadcast();

  void _emit() {
    if (!_itemsCtrl.isClosed) {
      _itemsCtrl.add(List<LocalSyncQueueData>.unmodifiable(_items));
    }
  }

  @override
  Future<List<LocalSyncQueueData>> getPendingSyncItems() async =>
      List<LocalSyncQueueData>.unmodifiable(_items);

  @override
  Stream<List<LocalSyncQueueData>> watchPendingSyncItems() async* {
    yield List<LocalSyncQueueData>.unmodifiable(_items);
    yield* _itemsCtrl.stream;
  }

  @override
  Stream<int> watchPendingSyncCount() async* {
    yield _items.length;
    yield* _itemsCtrl.stream.map((list) => list.length);
  }

  @override
  Future<int> deleteSyncItemById(int id) async {
    final before = _items.length;
    _items.removeWhere((item) => item.id == id);
    _emit();
    return before - _items.length;
  }

  @override
  Future<int> deleteSyncItemsByIds(List<int> ids) async {
    final before = _items.length;
    final idSet = ids.toSet();
    _items.removeWhere((item) => idSet.contains(item.id));
    _emit();
    return before - _items.length;
  }

  @override
  Future<int> recoverStuckSyncingItems() async => 0;

  @override
  Future<void> close() async {
    await _itemsCtrl.close();
  }
}

class _BootstrappedHarness extends ConsumerStatefulWidget {
  const _BootstrappedHarness();

  @override
  ConsumerState<_BootstrappedHarness> createState() =>
      _BootstrappedHarnessState();
}

class _BootstrappedHarnessState extends ConsumerState<_BootstrappedHarness> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(authControllerProvider.notifier).bootstrap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(isOfflineProvider).value ?? false;
    final pendingCount = ref.watch(pendingSyncCountProvider).value ?? 0;
    final syncState = ref.watch(offlineSyncControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LacakOfflineBar(
              isOffline: isOffline,
              pendingSyncCount: pendingCount,
              isSyncing: syncState.isSyncing,
              statusErrorMessage: syncState.lastError,
              onSyncTap: () => runInteractiveSyncWithFeedback(context, ref),
              onInspectTap: () => showPendingSyncQueueSheet(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const schoolA = SchoolProfile(
    id: 'school-a',
    ownerUserId: 'user-a',
    sppgId: 'sppg-a',
    npsn: '20300001',
    name: 'SDN 1 Purwokerto',
    adm4Code: '33.02.01.1001',
    lat: -7.42,
    lng: 109.23,
    puskesmasWa: '6281234567890',
    verificationStatus: SchoolVerificationStatus.approved,
  );

  const authSchoolA = AuthSessionSnapshot(
    profile: UserProfile(
      id: 'user-a',
      email: 'pic@sdn1.sch.id',
      role: UserRole.school,
      fullName: 'Ibu Sari',
    ),
    school: schoolA,
  );

  test(
    'formatFriendlySyncError, summarizePendingSyncItems, and AppDatabase queue deletion helpers work cleanly',
    () async {
      expect(
        formatFriendlySyncError('SocketException: Failed host lookup'),
        contains('internet atau Wi-Fi'),
      );
      expect(
        formatFriendlySyncError(
          'PostgrestException(message: new row violates row-level security policy, code: 42501)',
        ),
        contains('Hak akses atau sesi akun'),
      );
      expect(
        formatFriendlySyncError(
          'PostgrestException(message: insert or update on table "sample_vaults" violates foreign key constraint "sample_vaults_inspection_id_fkey", code: 23503)',
        ),
        contains('Data pemeriksaan makanan untuk sampel ini belum tersimpan'),
      );
      expect(
        formatFriendlySyncError('foreign key constraint 23503'),
        contains('Data rujukan untuk catatan ini belum tercatat'),
      );

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 11, 21, 5, 0);

      final id1 = await db.enqueueSyncItem(
        LocalSyncQueueCompanion.insert(
          operationType: 'create_waste_log',
          entityId: 'w-1',
          payloadJson: jsonEncode({
            'id': 'w-1',
            'school_id': 'school-a',
            'menu_name': 'Nasi Ayam Suwir',
            'batch_code': 'BCH-2611-A1',
            'rice_waste_pct': 25,
            'protein_waste_pct': 0,
            'veg_waste_pct': 50,
          }),
          status: const Value('failed'),
          retryCount: const Value(2),
          lastError: const Value('ClientException: SocketException: Connection refused'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      final id2 = await db.enqueueSyncItem(
        LocalSyncQueueCompanion.insert(
          operationType: 'create_batch',
          entityId: 'b-9',
          payloadJson: jsonEncode({
            'id': 'b-9',
            'sppg_id': 'sppg-demo',
            'menu_name': 'Menu Dapur',
            'batch_code': 'BCH-2611-K9',
          }),
          status: const Value('pending'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final rows = await db.getPendingSyncItems();
      final summaries = summarizePendingSyncItems(rows, school: schoolA);
      expect(summaries, hasLength(2));
      expect(summaries[0].title, 'Laporan Sisa Makanan Siswa');
      expect(summaries[0].belongsToCurrentAccount, isTrue);
      expect(summaries[0].isFailed, isTrue);
      expect(
        summaries[0].friendlyError,
        contains('Tidak dapat menghubungi server'),
      );
      expect(summaries[1].title, 'Pengiriman Makanan Dapur');
      expect(summaries[1].belongsToCurrentAccount, isFalse);
      expect(summaries[1].accountMismatchHint, contains('Dapur SPPG'));

      expect(await db.deleteSyncItemById(id1), 1);
      expect(await db.getPendingSyncItems(), hasLength(1));
      expect(await db.deleteSyncItemsByIds([id2]), 1);
      expect(await db.getPendingSyncItems(), isEmpty);

      final stuckId = await db.enqueueSyncItem(
        LocalSyncQueueCompanion.insert(
          operationType: 'create_inspection',
          entityId: 'insp-stuck',
          payloadJson: jsonEncode({'id': 'insp-stuck', 'school_id': 'school-a'}),
          status: const Value('syncing'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(await db.getPendingSyncItems(), isEmpty);
      expect(await db.recoverStuckSyncingItems(), 1);
      final recovered = await db.getPendingSyncItems();
      expect(recovered, hasLength(1));
      expect(recovered.first.id, stuckId);
      expect(recovered.first.status, 'pending');
    },
  );

  testWidgets(
    'LacakOfflineBar never says Menunggu Sinyal online, shows feedback SnackBar on Kirim failure, and opens detail sheet',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.utc(2026, 11, 21, 5, 30);
      final fakeDb = _FakeQueueDatabase([
        LocalSyncQueueData(
          id: 1,
          operationType: 'create_waste_log',
          entityId: 'w-fail',
          payloadJson: jsonEncode({
            'id': 'w-fail',
            'school_id': schoolA.id,
            'menu_name': 'Nasi Ayam Goreng',
            'batch_code': 'BCH-2611-F1',
          }),
          localPhotoPathsJson: '[]',
          status: 'failed',
          retryCount: 1,
          lastError: 'SocketException: Connection timed out',
          createdAt: now,
          updatedAt: now,
        ),
        LocalSyncQueueData(
          id: 2,
          operationType: 'create_batch',
          entityId: 'b-other',
          payloadJson: jsonEncode({
            'id': 'b-other',
            'sppg_id': 'sppg-other',
            'menu_name': 'Menu Dapur Lama',
            'batch_code': 'BCH-2611-OLD',
          }),
          localPhotoPathsJson: '[]',
          status: 'pending',
          retryCount: 0,
          lastError: null,
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      addTearDown(fakeDb.close);

      final schoolRepo = _StubSchoolRepository(() async => 0);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(fakeDb),
            isOfflineProvider.overrideWith((ref) => Stream.value(false)),
            authRepositoryProvider.overrideWithValue(
              _TestAuthRepository(authSchoolA),
            ),
            schoolRepositoryProvider.overrideWithValue(schoolRepo),
            kitchenRepositoryProvider.overrideWithValue(
              _NoopKitchenRepository(),
            ),
            clusterAlertRepositoryProvider.overrideWithValue(
              _NoopClusterAlertRepository(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const _BootstrappedHarness(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Misleading "(Menunggu Sinyal)" copy must not appear when online.
      expect(find.textContaining('Menunggu Sinyal'), findsNothing);
      expect(
        find.text('2 data belum terkirim ke server. Ketuk untuk lihat.'),
        findsOneWidget,
      );
      expect(find.text('Kirim'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tapping Kirim must produce clear SnackBar feedback instead of silent no-op.
      await tester.tap(find.text('Kirim'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Gagal mengirim 1 data'), findsOneWidget);
      expect(find.text('Lihat Rincian'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tapping Lihat Rincian opens the queue detail sheet.
      await tester.tap(find.text('Lihat Rincian'));
      await tester.pumpAndSettle();

      expect(find.text('2 Data Tersimpan di HP'), findsOneWidget);
      expect(find.text('Laporan Sisa Makanan Siswa'), findsOneWidget);
      expect(find.text('Pengiriman Makanan Dapur'), findsOneWidget);
      expect(find.text('Hapus Data Akun Lain'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Removing cross-account item updates the count live to 1.
      await tester.ensureVisible(find.text('Hapus Data Akun Lain'));
      await tester.tap(find.text('Hapus Data Akun Lain'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus Semua'));
      await tester.pumpAndSettle();

      expect(find.text('1 Data Tersimpan di HP'), findsOneWidget);
      expect(find.text('Pengiriman Makanan Dapur'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
