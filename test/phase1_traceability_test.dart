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
import 'package:lacak_saji/core/network/bmkg_weather_service.dart';
import 'package:lacak_saji/core/network/connectivity_provider.dart';
import 'package:lacak_saji/core/notifications/local_notification_service.dart';
import 'package:lacak_saji/core/theme/app_theme.dart';
import 'package:lacak_saji/core/theme/text_scale_provider.dart';
import 'package:lacak_saji/features/alerts/domain/cluster_alert_models.dart';
import 'package:lacak_saji/features/auth/domain/auth_models.dart';
import 'package:lacak_saji/features/auth/presentation/auth_controller.dart';
import 'package:lacak_saji/features/school/data/school_repository.dart';
import 'package:lacak_saji/features/school/domain/school_models.dart';
import 'package:lacak_saji/features/settings/data/team_security_repository.dart';
import 'package:lacak_saji/features/settings/domain/team_security_models.dart';
import 'package:lacak_saji/features/settings/presentation/settings_screen.dart';
import 'package:lacak_saji/features/settings/presentation/team_security_providers.dart';
import 'package:lacak_saji/features/settings/presentation/team_security_screen.dart';

class _MemoryKeyStore implements SecureKeyStore {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }
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
      temperatureC: 28.0,
      source: BmkgSource.fallbackOffline,
      observedAtUtc: DateTime.utc(2026, 11, 24, 5, 0),
    );
  }
}

class _NoopNotifications implements LocalNotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> cancelSampleVaultReminder(String sampleId) async {}

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

class _FixedAuthController extends AuthController {
  _FixedAuthController(this._fixedState);

  final AuthState _fixedState;

  @override
  AuthState build() => _fixedState;
}

class _InMemoryTeamSecurityRepo implements TeamSecurityRepository {
  _InMemoryTeamSecurityRepo({
    required this.institutionType,
    required this.institutionId,
    required this.institutionName,
    required this.canManageKeys,
    required List<InstitutionMemberItem> initialMembers,
    required List<SigningKeyItem> initialKeys,
  }) : _members = List.of(initialMembers),
       _keys = List.of(initialKeys);

  final InstitutionType institutionType;
  final String institutionId;
  final String institutionName;
  final bool canManageKeys;
  final List<InstitutionMemberItem> _members;
  final List<SigningKeyItem> _keys;

  @override
  Future<TeamSecurityOverview> fetchOverview({
    required AuthState authState,
    required bool isOffline,
  }) async {
    return TeamSecurityOverview(
      institutionType: institutionType,
      institutionId: institutionId,
      institutionName: institutionName,
      canManageKeys: canManageKeys,
      members: List.unmodifiable(_members),
      signingKeys: List.unmodifiable(_keys),
    );
  }

  @override
  Future<InstitutionMemberItem> addMember({
    required AuthState authState,
    required String memberName,
    required String memberEmail,
    required InstitutionMemberRole role,
    required bool isOffline,
  }) async {
    final added = InstitutionMemberItem(
      id: 'mem-${_members.length + 1}',
      institutionType: institutionType,
      institutionId: institutionId,
      memberName: memberName,
      memberEmail: memberEmail,
      role: role,
      isActive: true,
      createdAtUtc: DateTime.utc(2026, 11, 24, 6, 0),
    );
    _members.add(added);
    return added;
  }

  @override
  Future<void> setMemberActive({
    required AuthState authState,
    required InstitutionMemberItem member,
    required bool isActive,
    required bool isOffline,
  }) async {
    final idx = _members.indexWhere((m) => m.id == member.id);
    if (idx >= 0) {
      final old = _members[idx];
      _members[idx] = InstitutionMemberItem(
        id: old.id,
        institutionType: old.institutionType,
        institutionId: old.institutionId,
        userId: old.userId,
        memberName: old.memberName,
        memberEmail: old.memberEmail,
        role: old.role,
        isActive: isActive,
        createdAtUtc: old.createdAtUtc,
        isOwner: old.isOwner,
      );
    }
  }

  @override
  Future<SigningKeyItem> rotateKitchenSigningKey({
    required KitchenProfile kitchen,
    required bool revokePrevious,
    required String deviceLabel,
    required bool isOffline,
  }) async {
    final now = DateTime.utc(2026, 11, 24, 7, 0);
    for (var i = 0; i < _keys.length; i++) {
      final old = _keys[i];
      if (revokePrevious && old.status != SigningKeyStatus.revoked) {
        _keys[i] = SigningKeyItem(
          keyId: old.keyId,
          sppgId: old.sppgId,
          publicKeyB64: old.publicKeyB64,
          status: SigningKeyStatus.revoked,
          deviceLabel: old.deviceLabel,
          createdAtUtc: old.createdAtUtc,
          retiredAtUtc: old.retiredAtUtc,
          revokedAtUtc: now,
        );
      } else if (!revokePrevious && old.status == SigningKeyStatus.active) {
        _keys[i] = SigningKeyItem(
          keyId: old.keyId,
          sppgId: old.sppgId,
          publicKeyB64: old.publicKeyB64,
          status: SigningKeyStatus.retired,
          deviceLabel: old.deviceLabel,
          createdAtUtc: old.createdAtUtc,
          retiredAtUtc: now,
        );
      }
    }
    final nextKey = SigningKeyItem(
      keyId: 'key-rotated-${_keys.length + 1}',
      sppgId: kitchen.id,
      publicKeyB64: 'cHVibGljLWtleS1yb3RhdGVk',
      status: SigningKeyStatus.active,
      deviceLabel: deviceLabel,
      createdAtUtc: now,
    );
    _keys.insert(0, nextKey);
    return nextKey;
  }

  @override
  Future<void> revokeKitchenSigningKey({
    required KitchenProfile kitchen,
    required String keyId,
    required bool isOffline,
  }) async {
    final idx = _keys.indexWhere((k) => k.keyId == keyId);
    if (idx >= 0) {
      final old = _keys[idx];
      _keys[idx] = SigningKeyItem(
        keyId: old.keyId,
        sppgId: old.sppgId,
        publicKeyB64: old.publicKeyB64,
        status: SigningKeyStatus.revoked,
        deviceLabel: old.deviceLabel,
        createdAtUtc: old.createdAtUtc,
        retiredAtUtc: old.retiredAtUtc,
        revokedAtUtc: DateTime.utc(2026, 11, 24, 7, 30),
      );
    }
  }
}

const KitchenProfile _kitchenAdminProfile = KitchenProfile(
  id: 'a1000000-0000-4000-8000-000000000001',
  ownerUserId: '10000000-0000-4000-8000-000000000001',
  regNumber: 'BGN-PWT-2026-001',
  inviteCode: 'SPPG-PWT-01',
  name: 'SPPG Purwokerto Utara',
  adm4Code: '33.02.26.1001',
  lat: -7.4201,
  lng: 109.2345,
  publicKey: 'legacy-pub-key',
  isVerified: true,
);

const SchoolProfile _schoolAdminProfile = SchoolProfile(
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
  partnerPublicKey: 'legacy-pub-key',
);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 1 Drift v1 -> v2 Migration', () {
    test(
      'upgrades v1 SQLite database to v2 preserving local_sppg_keys and backfilling local_signing_keys',
      () async {
        final executor = NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('''
              CREATE TABLE local_sppg_keys (
                sppg_id TEXT NOT NULL PRIMARY KEY,
                sppg_name TEXT NOT NULL,
                invite_code TEXT NOT NULL,
                public_key_b64 TEXT NOT NULL,
                updated_at INTEGER NOT NULL
              );
              CREATE TABLE local_bmkg_cache (
                cache_key TEXT NOT NULL PRIMARY KEY,
                adm4_code TEXT NOT NULL,
                forecast_time_utc INTEGER NOT NULL,
                temperature_c REAL NOT NULL,
                humidity_pct INTEGER,
                weather_desc TEXT,
                fetched_at INTEGER NOT NULL,
                expires_at INTEGER NOT NULL
              );
              CREATE TABLE local_sync_queue (
                id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                operation_type TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                local_photo_paths_json TEXT NOT NULL DEFAULT '[]',
                status TEXT NOT NULL DEFAULT 'pending',
                retry_count INTEGER NOT NULL DEFAULT 0,
                last_error TEXT,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
              );
              CREATE TABLE local_sample_vaults (
                id TEXT NOT NULL PRIMARY KEY,
                inspection_id TEXT NOT NULL,
                school_id TEXT NOT NULL,
                menu_name TEXT NOT NULL,
                label_code TEXT NOT NULL UNIQUE,
                stored_at INTEGER NOT NULL,
                expires_at INTEGER NOT NULL,
                status TEXT NOT NULL DEFAULT 'active',
                is_synced INTEGER NOT NULL DEFAULT 0
              );
              INSERT INTO local_sppg_keys (sppg_id, sppg_name, invite_code, public_key_b64, updated_at)
              VALUES ('a1000000-0000-4000-8000-000000000001', 'SPPG Lama', 'SPPG-OLD', 'pk-v1-abc', 1795500000);
              PRAGMA user_version = 1;
            ''');
          },
        );

        final db = AppDatabase(executor);
        addTearDown(db.close);

        // Old local_sppg_keys row remains intact after migration to v2.
        final legacyRow = await db.getSppgKey(
          'a1000000-0000-4000-8000-000000000001',
        );
        expect(legacyRow, isNotNull);
        expect(legacyRow!.publicKeyB64, equals('pk-v1-abc'));

        // Backfilled into local_signing_keys automatically.
        final keys = await db.getSigningKeysForSppg(
          'a1000000-0000-4000-8000-000000000001',
        );
        expect(keys.length, 1);
        expect(keys.first.keyId, equals('legacy-a1000000'));
        expect(keys.first.publicKeyB64, equals('pk-v1-abc'));
        expect(keys.first.status, equals('active'));

        // CRUD works on all new v2 Drift tables.
        final now = DateTime.utc(2026, 11, 24, 8, 0);
        await db.upsertInstitutionMember(
          LocalInstitutionMembersCompanion.insert(
            id: 'mem-test-1',
            institutionType: 'sppg',
            institutionId: 'a1000000-0000-4000-8000-000000000001',
            memberName: 'Staf Uji',
            memberEmail: 'staf@sppg.id',
            role: 'staff',
            createdAt: now,
            updatedAt: now,
          ),
        );
        final members = await db.getInstitutionMembers(
          institutionType: 'sppg',
          institutionId: 'a1000000-0000-4000-8000-000000000001',
        );
        expect(members.length, 1);
        expect(members.first.memberName, equals('Staf Uji'));

        await db.upsertSchoolAllergen(
          LocalSchoolAllergensCompanion.insert(
            id: 'alg-1',
            schoolId: _schoolAdminProfile.id,
            allergenTag: 'kacang',
            studentCount: const Value(3),
            updatedAt: now,
          ),
        );
        final allergens = await db.getSchoolAllergens(_schoolAdminProfile.id);
        expect(allergens.length, 1);
        expect(allergens.first.allergenTag, equals('kacang'));

        await db.upsertTraceabilityDraft(
          LocalTraceabilityDraftsCompanion.insert(
            id: 'draft-1',
            recordType: 'ingredient_log',
            institutionId: _kitchenAdminProfile.id,
            payloadJson: '{"supplier":"PT Pangan"}',
            createdAt: now,
            updatedAt: now,
          ),
        );
        final drafts = await db.getUnsyncedTraceabilityDrafts(
          _kitchenAdminProfile.id,
        );
        expect(drafts.length, 1);
        expect(drafts.first.recordType, equals('ingredient_log'));
      },
    );
  });

  group('Phase 1 Ed25519 key_id rotation & revocation offline verification', () {
    test(
      'verifies active, retired, before-revocation, after-revocation, tampered, and legacy v1 QRs offline',
      () async {
        final keyStore = _MemoryKeyStore();
        final ed25519 = Ed25519Service(secureStore: keyStore);
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final t0 = DateTime.utc(2026, 11, 24, 4, 0);
        final repo = SupabaseSchoolRepository(
          client: null,
          database: db,
          ed25519Service: ed25519,
          bmkgService: _FakeBmkgService(),
          notificationService: _NoopNotifications(),
          locationReader: () async => (lat: -7.4188, lng: 109.2351),
          clockUtc: () => DateTime.utc(2026, 11, 24, 5, 30),
        );

        // Key A (old), then rotated to Key B (active).
        final matA = await ed25519.getOrCreateActiveKeyMaterial(
          sppgId: _kitchenAdminProfile.id,
        );
        final sigOld = await ed25519.signBatchWithKeyId(
          sppgId: _kitchenAdminProfile.id,
          buildCanonicalForKeyId: (kid) =>
              BatchQrPayload.buildCanonicalSigningString(
                batchId: 'batch-old',
                batchCode: 'BCH-OLD',
                sppgId: _kitchenAdminProfile.id,
                menuName: 'Nasi Ayam Goreng',
                riskCategory: 'MEDIUM',
                sealedAtEpochSec: t0.millisecondsSinceEpoch ~/ 1000,
                timestampSource: 'server_verified',
                keyId: kid,
              ),
        );
        final oldQr = BatchQrPayload(
          batchId: 'batch-old',
          batchCode: 'BCH-OLD',
          sppgId: _kitchenAdminProfile.id,
          menuName: 'Nasi Ayam Goreng',
          riskCategory: 'MEDIUM',
          sealedAtEpochSec: t0.millisecondsSinceEpoch ~/ 1000,
          timestampSource: 'server_verified',
          signatureB64: sigOld.signatureB64,
          keyId: sigOld.keyId,
        ).toMinifiedJson();

        // Rotate to Key B while marking Key A as retired.
        final matB = await ed25519.rotateKeyPair(
          sppgId: _kitchenAdminProfile.id,
        );
        expect(matB.keyId, isNot(equals(matA.keyId)));

        final sigNew = await ed25519.signBatchWithKeyId(
          sppgId: _kitchenAdminProfile.id,
          buildCanonicalForKeyId: (kid) =>
              BatchQrPayload.buildCanonicalSigningString(
                batchId: 'batch-new',
                batchCode: 'BCH-NEW',
                sppgId: _kitchenAdminProfile.id,
                menuName: 'Nasi Ikan Kembung',
                riskCategory: 'HIGH',
                sealedAtEpochSec: t0.add(const Duration(minutes: 20)).millisecondsSinceEpoch ~/ 1000,
                timestampSource: 'server_verified',
                keyId: kid,
              ),
        );
        final newQr = BatchQrPayload(
          batchId: 'batch-new',
          batchCode: 'BCH-NEW',
          sppgId: _kitchenAdminProfile.id,
          menuName: 'Nasi Ikan Kembung',
          riskCategory: 'HIGH',
          sealedAtEpochSec: t0.add(const Duration(minutes: 20)).millisecondsSinceEpoch ~/ 1000,
          timestampSource: 'server_verified',
          signatureB64: sigNew.signatureB64,
          keyId: sigNew.keyId,
        ).toMinifiedJson();

        // Cache Key A (retired) and Key B (active) in school Drift DB.
        await db.upsertSppgKey(
          LocalSppgKeysCompanion.insert(
            sppgId: _kitchenAdminProfile.id,
            sppgName: _kitchenAdminProfile.name,
            inviteCode: _kitchenAdminProfile.inviteCode,
            publicKeyB64: matB.publicKeyB64,
            updatedAt: t0,
          ),
        );
        await db.upsertSigningKeys([
          LocalSigningKeysCompanion(
            keyId: Value(matA.keyId),
            sppgId: Value(_kitchenAdminProfile.id),
            publicKeyB64: Value(matA.publicKeyB64),
            status: const Value('retired'),
            retiredAt: Value(t0.add(const Duration(minutes: 10))),
            createdAt: Value(t0),
            updatedAt: Value(t0),
          ),
          LocalSigningKeysCompanion(
            keyId: Value(matB.keyId),
            sppgId: Value(_kitchenAdminProfile.id),
            publicKeyB64: Value(matB.publicKeyB64),
            status: const Value('active'),
            createdAt: Value(t0.add(const Duration(minutes: 10))),
            updatedAt: Value(t0),
          ),
        ]);

        // 1. Active key with key_id -> valid
        final activeRes = await repo.verifyQrPayloadOffline(
          rawQrText: newQr,
          school: _schoolAdminProfile,
          isOffline: true,
        );
        expect(activeRes.outcome, QrVerificationOutcome.valid);

        // 2. Retired key -> older QR signed with retired key_id remains valid!
        final retiredRes = await repo.verifyQrPayloadOffline(
          rawQrText: oldQr,
          school: _schoolAdminProfile,
          isOffline: true,
        );
        expect(retiredRes.outcome, QrVerificationOutcome.valid);

        // 3. Revoked AFTER oldQr seal time (t0 + 10m > t0) -> historical QR stays valid
        await db.upsertSigningKey(
          LocalSigningKeysCompanion(
            keyId: Value(matA.keyId),
            sppgId: Value(_kitchenAdminProfile.id),
            publicKeyB64: Value(matA.publicKeyB64),
            status: const Value('revoked'),
            revokedAt: Value(t0.add(const Duration(minutes: 10))),
            createdAt: Value(t0),
            updatedAt: Value(t0),
          ),
        );
        final beforeRevokeRes = await repo.verifyQrPayloadOffline(
          rawQrText: oldQr,
          school: _schoolAdminProfile,
          isOffline: true,
        );
        expect(beforeRevokeRes.outcome, QrVerificationOutcome.valid);

        // 4. Revoked BEFORE or AT seal time (t0 - 5m <= t0) -> rejected with revokedKey!
        await db.upsertSigningKey(
          LocalSigningKeysCompanion(
            keyId: Value(matA.keyId),
            sppgId: Value(_kitchenAdminProfile.id),
            publicKeyB64: Value(matA.publicKeyB64),
            status: const Value('revoked'),
            revokedAt: Value(t0.subtract(const Duration(minutes: 5))),
            createdAt: Value(t0.subtract(const Duration(hours: 1))),
            updatedAt: Value(t0),
          ),
        );
        final revokedRes = await repo.verifyQrPayloadOffline(
          rawQrText: oldQr,
          school: _schoolAdminProfile,
          isOffline: true,
        );
        expect(revokedRes.outcome, QrVerificationOutcome.revokedKey);

        // 5. Tampered menu_name with active key_id -> rejected with invalidSignature
        final tamperedJson = newQr.replaceAll(
          'Nasi Ikan Kembung',
          'Nasi Palsu',
        );
        final tamperedRes = await repo.verifyQrPayloadOffline(
          rawQrText: tamperedJson,
          school: _schoolAdminProfile,
          isOffline: true,
        );
        expect(tamperedRes.outcome, QrVerificationOutcome.invalidSignature);

        // 6. Legacy v1 QR without key_id signed by Key B -> remains valid
        final legacyCanonical = BatchQrPayload.buildCanonicalSigningString(
          batchId: 'batch-v1',
          batchCode: 'BCH-V1',
          sppgId: _kitchenAdminProfile.id,
          menuName: 'Menu V1',
          riskCategory: 'LOW',
          sealedAtEpochSec: t0.millisecondsSinceEpoch ~/ 1000,
          timestampSource: 'server_verified',
        );
        final legacySig = await ed25519.signCanonicalPayload(
          sppgId: _kitchenAdminProfile.id,
          canonicalData: legacyCanonical,
        );
        final legacyQr = BatchQrPayload(
          batchId: 'batch-v1',
          batchCode: 'BCH-V1',
          sppgId: _kitchenAdminProfile.id,
          menuName: 'Menu V1',
          riskCategory: 'LOW',
          sealedAtEpochSec: t0.millisecondsSinceEpoch ~/ 1000,
          timestampSource: 'server_verified',
          signatureB64: legacySig,
        ).toMinifiedJson();
        final legacyRes = await repo.verifyQrPayloadOffline(
          rawQrText: legacyQr,
          school: _schoolAdminProfile,
          isOffline: true,
        );
        expect(legacyRes.outcome, QrVerificationOutcome.valid);
      },
    );
  });

  group('Phase 1 C01 & C02 Multi-PIC and Key Security UI', () {
    testWidgets(
      'C01 exposes Kelola Tim & Keamanan Kunci only to Admin SPPG / Admin Sekolah',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        Future<void> pumpC01WithState(AuthState authState) async {
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                sharedPreferencesProvider.overrideWithValue(prefs),
                appDatabaseProvider.overrideWithValue(db),
                isOfflineProvider.overrideWith((ref) => Stream.value(false)),
                pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
                authControllerProvider.overrideWith(
                  () => _FixedAuthController(authState),
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: const SettingsScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        // 1. Kitchen Admin -> visible
        await pumpC01WithState(
          const AuthState(
            status: AuthStatus.authenticated,
            profile: UserProfile(
              id: '10000000-0000-4000-8000-000000000001',
              email: 'admin@sppg.id',
              role: UserRole.kitchen,
              fullName: 'Pak Admin SPPG',
            ),
            kitchen: _kitchenAdminProfile,
            institutionRole: InstitutionMemberRole.admin,
          ),
        );
        expect(find.text('Kelola Tim & Keamanan Kunci'), findsOneWidget);

        // 2. School Admin -> visible
        await pumpC01WithState(
          const AuthState(
            status: AuthStatus.authenticated,
            profile: UserProfile(
              id: '20000000-0000-4000-8000-000000000001',
              email: 'admin@sdn1.id',
              role: UserRole.school,
              fullName: 'Ibu Admin Sekolah',
            ),
            school: _schoolAdminProfile,
            institutionRole: InstitutionMemberRole.admin,
          ),
        );
        expect(find.text('Kelola Tim & Keamanan Kunci'), findsOneWidget);

        // 3. Non-admin Staff -> hidden
        await pumpC01WithState(
          const AuthState(
            status: AuthStatus.authenticated,
            profile: UserProfile(
              id: '99999999-0000-4000-8000-000000000001',
              email: 'staf@sdn1.id',
              role: UserRole.school,
              fullName: 'Pak Staf Sekolah',
            ),
            school: _schoolAdminProfile,
            institutionRole: InstitutionMemberRole.staff,
          ),
        );
        expect(find.text('Kelola Tim & Keamanan Kunci'), findsNothing);

        // 4. Supervisor -> hidden
        await pumpC01WithState(
          const AuthState(
            status: AuthStatus.authenticated,
            profile: UserProfile(
              id: '30000000-0000-4000-8000-000000000001',
              email: 'bgn@gov.id',
              role: UserRole.supervisor,
              fullName: 'Pengawas BGN',
            ),
          ),
        );
        expect(find.text('Kelola Tim & Keamanan Kunci'), findsNothing);
      },
    );

    testWidgets(
      'C02 manages Multi-PIC members and rotates SPPG Ed25519 keys with zero overflow at 320dp 1.30x and 768dp tablet',
      (tester) async {
        final fakeRepo = _InMemoryTeamSecurityRepo(
          institutionType: InstitutionType.sppg,
          institutionId: _kitchenAdminProfile.id,
          institutionName: _kitchenAdminProfile.name,
          canManageKeys: true,
          initialMembers: [
            InstitutionMemberItem(
              id: 'mem-owner',
              institutionType: InstitutionType.sppg,
              institutionId: _kitchenAdminProfile.id,
              userId: _kitchenAdminProfile.ownerUserId,
              memberName: 'Pak Budi SPPG',
              memberEmail: 'dapur@sppg.id',
              role: InstitutionMemberRole.admin,
              isActive: true,
              createdAtUtc: DateTime.utc(2026, 11, 20),
              isOwner: true,
            ),
          ],
          initialKeys: [
            SigningKeyItem(
              keyId: 'key-initial-01',
              sppgId: _kitchenAdminProfile.id,
              publicKeyB64: 'pk-init',
              status: SigningKeyStatus.active,
              deviceLabel: 'Perangkat Utama',
              createdAtUtc: DateTime.utc(2026, 11, 20),
            ),
          ],
        );

        const kitchenAuth = AuthState(
          status: AuthStatus.authenticated,
          profile: UserProfile(
            id: '10000000-0000-4000-8000-000000000001',
            email: 'dapur@sppg.id',
            role: UserRole.kitchen,
            fullName: 'Pak Budi SPPG',
          ),
          kitchen: _kitchenAdminProfile,
          institutionRole: InstitutionMemberRole.admin,
        );

        // Compact 320dp + Ekstra Besar 1.30x
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              isOfflineProvider.overrideWith((ref) => Stream.value(false)),
              authControllerProvider.overrideWith(
                () => _FixedAuthController(kitchenAuth),
              ),
              teamSecurityRepositoryProvider.overrideWithValue(fakeRepo),
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
              home: const TeamSecurityScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Kelola Tim & Keamanan Kunci'), findsOneWidget);
        expect(find.text('key-initial-01'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Add Multi-PIC staff via StickyBottomActionBar CTA
        await tester.tap(find.text('Tambah Staf'));
        await tester.pumpAndSettle();

        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.at(0), 'Kurir Andi');
        await tester.enterText(textFields.at(1), 'andi.kurir@sppg.id');
        await tester.ensureVisible(find.text('Kurir Pengantar'));
        await tester.tap(find.text('Kurir Pengantar'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Simpan Anggota Tim'));
        await tester.tap(find.text('Simpan Anggota Tim'));
        await tester.pumpAndSettle();

        expect(find.text('Kurir Andi'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Rotate Ed25519 key
        await tester.ensureVisible(find.text('Rotasi Kunci Perangkat'));
        await tester.tap(find.text('Rotasi Kunci Perangkat'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Lanjutkan Rotasi Kunci'));
        await tester.tap(find.text('Lanjutkan Rotasi Kunci'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ya, Terbitkan Kunci Baru'));
        await tester.pumpAndSettle();

        expect(find.text('key-rotated-2'), findsOneWidget);
        expect(find.text('PENSIUN AMAN'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Tablet 768x1024 layout renders two-column without overflow
        tester.view.physicalSize = const Size(768, 1024);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
