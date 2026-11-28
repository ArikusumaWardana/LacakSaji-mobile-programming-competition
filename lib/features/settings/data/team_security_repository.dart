import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:uuid/uuid.dart';

import '../../../core/crypto/ed25519_service.dart';
import '../../../core/database/app_database.dart';
import '../../auth/domain/auth_models.dart';
import '../domain/team_security_models.dart';

abstract class TeamSecurityRepository {
  Future<TeamSecurityOverview> fetchOverview({
    required AuthState authState,
    required bool isOffline,
  });

  Future<InstitutionMemberItem> addMember({
    required AuthState authState,
    required String memberName,
    required String memberEmail,
    required InstitutionMemberRole role,
    required bool isOffline,
  });

  Future<void> setMemberActive({
    required AuthState authState,
    required InstitutionMemberItem member,
    required bool isActive,
    required bool isOffline,
  });

  Future<SigningKeyItem> rotateKitchenSigningKey({
    required KitchenProfile kitchen,
    required bool revokePrevious,
    required String deviceLabel,
    required bool isOffline,
  });

  Future<void> revokeKitchenSigningKey({
    required KitchenProfile kitchen,
    required String keyId,
    required bool isOffline,
  });
}

class SupabaseTeamSecurityRepository implements TeamSecurityRepository {
  SupabaseTeamSecurityRepository({
    required this._client,
    required this._database,
    required this._ed25519Service,
    Uuid? uuid,
    DateTime Function()? clockUtc,
  }) : _uuid = uuid ?? const Uuid(),
       _clockUtc = clockUtc ?? (() => DateTime.now().toUtc());

  final SupabaseClient? _client;
  final AppDatabase _database;
  final Ed25519Service _ed25519Service;
  final Uuid _uuid;
  final DateTime Function() _clockUtc;

  ({
    InstitutionType type,
    String id,
    String name,
    String ownerUserId,
    bool canManageKeys,
    String? partnerSppgId,
  })
  _resolveScope(AuthState authState) {
    final kitchen = authState.kitchen;
    if (kitchen != null) {
      return (
        type: InstitutionType.sppg,
        id: kitchen.id,
        name: kitchen.name,
        ownerUserId: kitchen.ownerUserId,
        canManageKeys: true,
        partnerSppgId: kitchen.id,
      );
    }
    final school = authState.school;
    if (school != null) {
      return (
        type: InstitutionType.school,
        id: school.id,
        name: school.name,
        ownerUserId: school.ownerUserId,
        canManageKeys: false,
        partnerSppgId: school.sppgId,
      );
    }
    throw StateError('Profil institusi belum tersedia.');
  }

  @override
  Future<TeamSecurityOverview> fetchOverview({
    required AuthState authState,
    required bool isOffline,
  }) async {
    final scope = _resolveScope(authState);
    final now = _clockUtc();

    final cachedMembers = await _database.getInstitutionMembers(
      institutionType: scope.type.dbValue,
      institutionId: scope.id,
    );
    var members = cachedMembers
        .map((m) => _mapLocalMember(m, scope.ownerUserId))
        .toList();

    List<SigningKeyItem> keys = const [];
    if (scope.partnerSppgId != null && scope.partnerSppgId!.isNotEmpty) {
      final cachedKeys = await _database.getSigningKeysForSppg(
        scope.partnerSppgId!,
      );
      keys = cachedKeys.map(_mapLocalKey).toList();
    }

    final client = _client;
    if (!isOffline && client != null) {
      try {
        final memberRows = List<Map<String, dynamic>>.from(
          await client
                  .from('institution_members')
                  .select()
                  .eq('institution_type', scope.type.dbValue)
                  .eq('institution_id', scope.id)
                  .order('created_at', ascending: true)
              as List,
        );

        final remoteMembers = memberRows
            .map((r) => _mapRemoteMember(r, scope.ownerUserId))
            .toList(growable: false);
        members = _mergeMembersWithPendingLocal(remoteMembers, members);

        await _database.replaceInstitutionMembersForScope(
          institutionType: scope.type.dbValue,
          institutionId: scope.id,
          entries: members
              .map(
                (m) => LocalInstitutionMembersCompanion(
                  id: Value(m.id),
                  institutionType: Value(m.institutionType.dbValue),
                  institutionId: Value(m.institutionId),
                  userId: Value(m.userId),
                  memberName: Value(m.memberName),
                  memberEmail: Value(m.memberEmail),
                  role: Value(m.role.dbValue),
                  isActive: Value(m.isActive),
                  createdAt: Value(m.createdAtUtc),
                  updatedAt: Value(now),
                ),
              )
              .toList(growable: false),
        );
      } catch (_) {
        // Keep local cache when remote schema 008 is unavailable or offline.
      }

      if (scope.partnerSppgId != null && scope.partnerSppgId!.isNotEmpty) {
        try {
          final keyRows = List<Map<String, dynamic>>.from(
            await client
                    .from('signing_keys')
                    .select()
                    .eq('sppg_id', scope.partnerSppgId!)
                    .order('created_at', ascending: false)
                as List,
          );
          final remoteKeys = keyRows
              .map(_mapRemoteKey)
              .toList(growable: false);
          if (remoteKeys.isNotEmpty) {
            keys = remoteKeys;
            await _database.upsertSigningKeys(
              remoteKeys
                  .map(
                    (k) => LocalSigningKeysCompanion(
                      keyId: Value(k.keyId),
                      sppgId: Value(k.sppgId),
                      publicKeyB64: Value(k.publicKeyB64),
                      status: Value(k.status.dbValue),
                      deviceLabel: Value(k.deviceLabel),
                      createdAt: Value(k.createdAtUtc),
                      retiredAt: Value(k.retiredAtUtc),
                      revokedAt: Value(k.revokedAtUtc),
                      updatedAt: Value(now),
                    ),
                  )
                  .toList(growable: false),
            );
          }
        } catch (_) {
          // Keep cached keys.
        }
      }
    }

    if (members.isEmpty) {
      members = [
        InstitutionMemberItem(
          id: 'owner-${scope.id}',
          institutionType: scope.type,
          institutionId: scope.id,
          userId: authState.profile?.id ?? scope.ownerUserId,
          memberName: authState.profile?.fullName ?? scope.name,
          memberEmail: authState.profile?.email ?? '-',
          role: InstitutionMemberRole.admin,
          isActive: true,
          createdAtUtc: now,
          isOwner: true,
        ),
      ];
    }

    if (keys.isEmpty && scope.type == InstitutionType.sppg && authState.kitchen != null) {
      final material = await _ed25519Service.getOrCreateActiveKeyMaterial(
        sppgId: authState.kitchen!.id,
        legacyUserId: authState.kitchen!.ownerUserId,
      );
      final fallbackKey = SigningKeyItem(
        keyId: material.keyId,
        sppgId: authState.kitchen!.id,
        publicKeyB64: material.publicKeyB64,
        status: SigningKeyStatus.active,
        deviceLabel: 'Perangkat Dapur Saat Ini',
        createdAtUtc: now,
      );
      keys = [fallbackKey];
      await _database.upsertSigningKey(
        LocalSigningKeysCompanion(
          keyId: Value(fallbackKey.keyId),
          sppgId: Value(fallbackKey.sppgId),
          publicKeyB64: Value(fallbackKey.publicKeyB64),
          status: const Value('active'),
          deviceLabel: Value(fallbackKey.deviceLabel),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    } else if (keys.isEmpty &&
        authState.school?.partnerPublicKey != null &&
        authState.school!.partnerPublicKey!.isNotEmpty &&
        scope.partnerSppgId != null) {
      final keyId = await Ed25519Service.deriveDeterministicKeyId(
        authState.school!.partnerPublicKey!,
      );
      keys = [
        SigningKeyItem(
          keyId: keyId,
          sppgId: scope.partnerSppgId!,
          publicKeyB64: authState.school!.partnerPublicKey!,
          status: SigningKeyStatus.active,
          deviceLabel: 'Kunci Utama SPPG Mitra',
          createdAtUtc: now,
        ),
      ];
    }

    return TeamSecurityOverview(
      institutionType: scope.type,
      institutionId: scope.id,
      institutionName: scope.name,
      canManageKeys: scope.canManageKeys,
      members: members,
      signingKeys: keys,
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
    final scope = _resolveScope(authState);
    final now = _clockUtc();
    final cleanName = memberName.trim();
    final cleanEmail = memberEmail.trim().toLowerCase();
    final localId = _uuid.v4();

    var remoteId = localId;
    final client = _client;
    var pendingSync = isOffline || client == null;

    if (!isOffline && client != null) {
      try {
        final raw = await client.rpc(
          'add_institution_member',
          params: {
            'p_institution_type': scope.type.dbValue,
            'p_institution_id': scope.id,
            'p_member_name': cleanName,
            'p_member_email': cleanEmail,
            'p_role': role.dbValue,
          },
        );
        if (raw is Map && raw['member_id'] is String) {
          remoteId = raw['member_id'] as String;
        }
      } catch (_) {
        pendingSync = true;
      }
    }

    final item = InstitutionMemberItem(
      id: remoteId,
      institutionType: scope.type,
      institutionId: scope.id,
      memberName: cleanName,
      memberEmail: cleanEmail,
      role: role,
      isActive: true,
      createdAtUtc: now,
      isPendingSync: pendingSync,
    );

    await _database.upsertInstitutionMember(
      LocalInstitutionMembersCompanion(
        id: Value(item.id),
        institutionType: Value(item.institutionType.dbValue),
        institutionId: Value(item.institutionId),
        memberName: Value(item.memberName),
        memberEmail: Value(item.memberEmail),
        role: Value(item.role.dbValue),
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    if (pendingSync) {
      await _database.enqueueSyncItem(
        LocalSyncQueueCompanion.insert(
          operationType: 'upsert_institution_member',
          entityId: item.id,
          payloadJson: jsonEncode({
            'institution_type': scope.type.dbValue,
            'institution_id': scope.id,
            'member_name': cleanName,
            'member_email': cleanEmail,
            'role': role.dbValue,
          }),
          status: const Value('pending'),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    return item;
  }

  @override
  Future<void> setMemberActive({
    required AuthState authState,
    required InstitutionMemberItem member,
    required bool isActive,
    required bool isOffline,
  }) async {
    final now = _clockUtc();
    final client = _client;
    var pendingSync = isOffline || client == null;

    if (!isOffline && client != null) {
      try {
        await client.rpc(
          'set_institution_member_active',
          params: {
            'p_member_id': member.id,
            'p_is_active': isActive,
          },
        );
      } catch (_) {
        pendingSync = true;
      }
    }

    await _database.upsertInstitutionMember(
      LocalInstitutionMembersCompanion(
        id: Value(member.id),
        institutionType: Value(member.institutionType.dbValue),
        institutionId: Value(member.institutionId),
        userId: Value(member.userId),
        memberName: Value(member.memberName),
        memberEmail: Value(member.memberEmail),
        role: Value(member.role.dbValue),
        isActive: Value(isActive),
        createdAt: Value(member.createdAtUtc),
        updatedAt: Value(now),
      ),
    );

    if (pendingSync) {
      await _database.enqueueSyncItem(
        LocalSyncQueueCompanion.insert(
          operationType: 'toggle_institution_member',
          entityId: member.id,
          payloadJson: jsonEncode({
            'institution_type': member.institutionType.dbValue,
            'institution_id': member.institutionId,
            'is_active': isActive,
          }),
          status: const Value('pending'),
          createdAt: now,
          updatedAt: now,
        ),
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
    final now = _clockUtc();
    final existingKeys = await _database.getSigningKeysForSppg(kitchen.id);
    for (final oldKey in existingKeys) {
      if (revokePrevious && oldKey.status != 'revoked') {
        await _database.upsertSigningKey(
          LocalSigningKeysCompanion(
            keyId: Value(oldKey.keyId),
            sppgId: Value(oldKey.sppgId),
            publicKeyB64: Value(oldKey.publicKeyB64),
            status: const Value('revoked'),
            deviceLabel: Value(oldKey.deviceLabel),
            createdAt: Value(oldKey.createdAt),
            retiredAt: Value(oldKey.retiredAt),
            revokedAt: Value(oldKey.revokedAt ?? now),
            updatedAt: Value(now),
          ),
        );
      } else if (!revokePrevious && oldKey.status == 'active') {
        await _database.upsertSigningKey(
          LocalSigningKeysCompanion(
            keyId: Value(oldKey.keyId),
            sppgId: Value(oldKey.sppgId),
            publicKeyB64: Value(oldKey.publicKeyB64),
            status: const Value('retired'),
            deviceLabel: Value(oldKey.deviceLabel),
            createdAt: Value(oldKey.createdAt),
            retiredAt: Value(oldKey.retiredAt ?? now),
            revokedAt: Value(oldKey.revokedAt),
            updatedAt: Value(now),
          ),
        );
      }
    }

    final rotated = await _ed25519Service.rotateKeyPair(sppgId: kitchen.id);
    final cleanLabel = deviceLabel.trim().isNotEmpty
        ? deviceLabel.trim()
        : 'Perangkat Pengganti SPPG';

    final client = _client;
    var pendingSync = isOffline || client == null;
    if (!isOffline && client != null) {
      try {
        await client.rpc(
          'rotate_sppg_signing_key',
          params: {
            'p_sppg_id': kitchen.id,
            'p_new_key_id': rotated.keyId,
            'p_new_public_key': rotated.publicKeyB64,
            'p_revoke_previous': revokePrevious,
            'p_device_label': cleanLabel,
          },
        );
      } catch (_) {
        pendingSync = true;
      }
    }

    await _database.upsertSppgKey(
      LocalSppgKeysCompanion(
        sppgId: Value(kitchen.id),
        sppgName: Value(kitchen.name),
        inviteCode: Value(kitchen.inviteCode),
        publicKeyB64: Value(rotated.publicKeyB64),
        updatedAt: Value(now),
      ),
    );

    await _database.upsertSigningKey(
      LocalSigningKeysCompanion(
        keyId: Value(rotated.keyId),
        sppgId: Value(kitchen.id),
        publicKeyB64: Value(rotated.publicKeyB64),
        status: const Value('active'),
        deviceLabel: Value(cleanLabel),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    if (pendingSync) {
      await _database.enqueueSyncItem(
        LocalSyncQueueCompanion.insert(
          operationType: 'rotate_signing_key',
          entityId: rotated.keyId,
          payloadJson: jsonEncode({
            'sppg_id': kitchen.id,
            'key_id': rotated.keyId,
            'public_key': rotated.publicKeyB64,
            'revoke_previous': revokePrevious,
            'device_label': cleanLabel,
          }),
          status: const Value('pending'),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    return SigningKeyItem(
      keyId: rotated.keyId,
      sppgId: kitchen.id,
      publicKeyB64: rotated.publicKeyB64,
      status: SigningKeyStatus.active,
      deviceLabel: cleanLabel,
      createdAtUtc: now,
      isPendingSync: pendingSync,
    );
  }

  @override
  Future<void> revokeKitchenSigningKey({
    required KitchenProfile kitchen,
    required String keyId,
    required bool isOffline,
  }) async {
    final now = _clockUtc();
    final existing = await _database.getSigningKeyById(keyId);
    final client = _client;
    var pendingSync = isOffline || client == null;

    if (!isOffline && client != null) {
      try {
        await client.rpc(
          'revoke_sppg_signing_key',
          params: {
            'p_sppg_id': kitchen.id,
            'p_key_id': keyId,
          },
        );
      } catch (_) {
        pendingSync = true;
      }
    }

    if (existing != null) {
      await _database.upsertSigningKey(
        LocalSigningKeysCompanion(
          keyId: Value(existing.keyId),
          sppgId: Value(existing.sppgId),
          publicKeyB64: Value(existing.publicKeyB64),
          status: const Value('revoked'),
          deviceLabel: Value(existing.deviceLabel),
          createdAt: Value(existing.createdAt),
          retiredAt: Value(existing.retiredAt),
          revokedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }

    if (pendingSync) {
      await _database.enqueueSyncItem(
        LocalSyncQueueCompanion.insert(
          operationType: 'revoke_signing_key',
          entityId: keyId,
          payloadJson: jsonEncode({
            'sppg_id': kitchen.id,
            'key_id': keyId,
          }),
          status: const Value('pending'),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  List<InstitutionMemberItem> _mergeMembersWithPendingLocal(
    List<InstitutionMemberItem> remote,
    List<InstitutionMemberItem> local,
  ) {
    final byId = <String, InstitutionMemberItem>{
      for (final item in remote) item.id: item,
    };
    for (final item in local) {
      byId.putIfAbsent(item.id, () => item);
    }
    return byId.values.toList(growable: false);
  }

  InstitutionMemberItem _mapLocalMember(
    LocalInstitutionMember row,
    String ownerUserId,
  ) {
    final role =
        InstitutionMemberRole.fromDb(row.role) ?? InstitutionMemberRole.staff;
    return InstitutionMemberItem(
      id: row.id,
      institutionType: InstitutionType.fromDb(row.institutionType),
      institutionId: row.institutionId,
      userId: row.userId,
      memberName: row.memberName,
      memberEmail: row.memberEmail,
      role: role,
      isActive: row.isActive,
      createdAtUtc: row.createdAt.toUtc(),
      isOwner: row.userId != null && row.userId == ownerUserId,
    );
  }

  InstitutionMemberItem _mapRemoteMember(
    Map<String, dynamic> row,
    String ownerUserId,
  ) {
    final role =
        InstitutionMemberRole.fromDb(row['role'] as String?) ??
        InstitutionMemberRole.staff;
    final userId = row['user_id'] as String?;
    return InstitutionMemberItem(
      id: row['id'] as String,
      institutionType: InstitutionType.fromDb(row['institution_type'] as String?),
      institutionId: row['institution_id'] as String,
      userId: userId,
      memberName: (row['member_name'] as String?) ?? '-',
      memberEmail: (row['member_email'] as String?) ?? '-',
      role: role,
      isActive: (row['is_active'] as bool?) ?? true,
      createdAtUtc:
          DateTime.tryParse('${row['created_at'] ?? ''}')?.toUtc() ??
          _clockUtc(),
      isOwner: userId != null && userId == ownerUserId,
    );
  }

  SigningKeyItem _mapLocalKey(LocalSigningKey row) {
    return SigningKeyItem(
      keyId: row.keyId,
      sppgId: row.sppgId,
      publicKeyB64: row.publicKeyB64,
      status: SigningKeyStatus.fromDb(row.status),
      deviceLabel: row.deviceLabel,
      createdAtUtc: row.createdAt.toUtc(),
      retiredAtUtc: row.retiredAt?.toUtc(),
      revokedAtUtc: row.revokedAt?.toUtc(),
    );
  }

  SigningKeyItem _mapRemoteKey(Map<String, dynamic> row) {
    return SigningKeyItem(
      keyId: row['key_id'] as String,
      sppgId: row['sppg_id'] as String,
      publicKeyB64: (row['public_key'] as String?) ?? '',
      status: SigningKeyStatus.fromDb(row['status'] as String?),
      deviceLabel: row['device_label'] as String?,
      createdAtUtc:
          DateTime.tryParse('${row['created_at'] ?? ''}')?.toUtc() ??
          _clockUtc(),
      retiredAtUtc: DateTime.tryParse('${row['retired_at'] ?? ''}')?.toUtc(),
      revokedAtUtc: DateTime.tryParse('${row['revoked_at'] ?? ''}')?.toUtc(),
    );
  }
}
