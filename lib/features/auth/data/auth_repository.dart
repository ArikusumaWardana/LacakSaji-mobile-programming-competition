import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/crypto/ed25519_service.dart';
import '../../../core/database/app_database.dart';
import '../domain/auth_error_mapper.dart';
import '../domain/auth_models.dart';

abstract class AuthRepository {
  Future<AuthSessionSnapshot?> restoreSession();

  Future<AuthSessionSnapshot> signInWithPassword({
    required String email,
    required String password,
  });

  Future<WhitelistCheckResult> verifySppgWhitelist({
    required String regNumber,
    required String pin,
  });

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
  });

  Future<SchoolPrecheckResult> precheckSchool({
    required String npsn,
    required String inviteCode,
  });

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
  });

  Future<AuthSessionSnapshot?> refreshSession();

  Future<AuthSessionSnapshot> updateSchoolPartnerCode(String inviteCode);

  Future<AuthSessionSnapshot> updateSchoolOperationalSettings({
    required String puskesmasWa,
    required String adm4Code,
  });

  Future<AuthSessionSnapshot> updateKitchenLocation({
    required double lat,
    required double lng,
    required String adm4Code,
  });

  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({
    required this._client,
    required this._database,
    required this._ed25519Service,
    required this._prefs,
  });

  final SupabaseClient? _client;
  final AppDatabase _database;
  final Ed25519Service _ed25519Service;
  final SharedPreferences? _prefs;

  static const String _pendingOnboardingKey = 'lacak_pending_onboarding_v1';

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const AuthFriendlyException(
        'Konfigurasi server belum tersedia. Periksa berkas .env proyek Anda.',
      );
    }
    return client;
  }

  @override
  Future<AuthSessionSnapshot?> restoreSession() async {
    final client = _client;
    if (client == null) {
      return null;
    }
    final user = client.auth.currentUser;
    if (user == null) {
      return null;
    }
    return _loadOrCompleteSession(client, user);
  }

  @override
  Future<AuthSessionSnapshot> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final client = _requireClient();
    final response = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final user = response.user ?? client.auth.currentUser;
    if (user == null) {
      throw const AuthFriendlyException(
        'Sesi akun tidak ditemukan. Coba masuk kembali.',
      );
    }
    return _loadOrCompleteSession(client, user);
  }

  @override
  Future<WhitelistCheckResult> verifySppgWhitelist({
    required String regNumber,
    required String pin,
  }) async {
    final client = _requireClient();
    final raw = await client.rpc(
      'verify_sppg_whitelist',
      params: {
        'p_reg_number': regNumber.trim().toUpperCase(),
        'p_pin': pin.trim(),
      },
    );
    final data = Map<String, dynamic>.from(raw as Map);
    final ok = (data['ok'] as bool?) ?? false;
    if (!ok) {
      return WhitelistCheckResult(
        ok: false,
        reason: data['reason'] as String?,
      );
    }
    return WhitelistCheckResult(
      ok: true,
      regNumber: data['reg_number'] as String?,
      officialName: data['official_name'] as String?,
      regionName: data['region_name'] as String?,
    );
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
    final client = _requireClient();
    final check = await verifySppgWhitelist(regNumber: regNumber, pin: pin);
    if (!check.ok) {
      throw AuthFriendlyException(AuthErrorMapper.mapRpcReason(check.reason));
    }

    final signUpResponse = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': picName.trim()},
    );

    final user = signUpResponse.user;
    if (user == null) {
      throw const AuthFriendlyException(
        'Pendaftaran akun gagal dibuat. Silakan coba lagi.',
      );
    }

    final publicKeyB64 = await _ed25519Service.generateAndStoreKeyPair(user.id);
    final cleanReg = regNumber.trim().toUpperCase();
    final cleanKitchenName = kitchenName.trim().isNotEmpty
        ? kitchenName.trim()
        : (check.officialName ?? cleanReg);

    if (signUpResponse.session == null) {
      await _prefs?.setString(
        _pendingOnboardingKey,
        jsonEncode({
          'type': 'kitchen',
          'user_id': user.id,
          'reg_number': cleanReg,
          'pin': pin.trim(),
          'pic_name': picName.trim(),
          'kitchen_name': cleanKitchenName,
          'adm4_code': adm4Code.trim(),
          'lat': lat,
          'lng': lng,
          'public_key': publicKeyB64,
        }),
      );
      return KitchenRegistrationResult(
        requiresEmailConfirmation: true,
        inviteCode: '',
        kitchenName: cleanKitchenName,
      );
    }

    final snapshot = await _finalizeKitchenOnboarding(
      client: client,
      user: user,
      regNumber: cleanReg,
      pin: pin.trim(),
      picName: picName.trim(),
      kitchenName: cleanKitchenName,
      adm4Code: adm4Code.trim(),
      lat: lat,
      lng: lng,
      publicKeyB64: publicKeyB64,
    );

    return KitchenRegistrationResult(
      requiresEmailConfirmation: false,
      inviteCode: snapshot.kitchen?.inviteCode ?? '',
      kitchenName: snapshot.kitchen?.name ?? cleanKitchenName,
      session: snapshot,
    );
  }

  @override
  Future<SchoolPrecheckResult> precheckSchool({
    required String npsn,
    required String inviteCode,
  }) async {
    final client = _requireClient();
    final raw = await client.rpc(
      'precheck_school_registration',
      params: {
        'p_npsn': npsn.trim(),
        'p_invite_code': inviteCode.trim().toUpperCase(),
      },
    );
    final data = Map<String, dynamic>.from(raw as Map);
    final ok = (data['ok'] as bool?) ?? false;
    if (!ok) {
      return SchoolPrecheckResult(
        ok: false,
        reason: data['reason'] as String?,
      );
    }
    return SchoolPrecheckResult(
      ok: true,
      sppgId: data['sppg_id'] as String?,
      sppgName: data['sppg_name'] as String?,
      sppgInviteCode: data['sppg_invite_code'] as String?,
      sppgPublicKey: data['sppg_public_key'] as String?,
    );
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
    final client = _requireClient();
    final precheck = await precheckSchool(npsn: npsn, inviteCode: inviteCode);
    if (!precheck.ok || precheck.sppgId == null) {
      throw AuthFriendlyException(
        AuthErrorMapper.mapRpcReason(precheck.reason),
      );
    }

    final signUpResponse = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': picName.trim()},
    );

    final user = signUpResponse.user;
    if (user == null) {
      throw const AuthFriendlyException(
        'Pendaftaran akun sekolah gagal dibuat. Silakan coba lagi.',
      );
    }

    if (signUpResponse.session == null) {
      await _prefs?.setString(
        _pendingOnboardingKey,
        jsonEncode({
          'type': 'school',
          'user_id': user.id,
          'npsn': npsn.trim(),
          'school_name': schoolName.trim(),
          'pic_name': picName.trim(),
          'adm4_code': adm4Code.trim(),
          'puskesmas_wa': puskesmasWa.trim(),
          'sppg_id': precheck.sppgId,
          'lat': lat,
          'lng': lng,
        }),
      );
      return SchoolRegistrationResult(
        requiresEmailConfirmation: true,
        schoolName: schoolName.trim(),
      );
    }

    final snapshot = await _finalizeSchoolOnboarding(
      client: client,
      user: user,
      npsn: npsn.trim(),
      schoolName: schoolName.trim(),
      picName: picName.trim(),
      adm4Code: adm4Code.trim(),
      puskesmasWa: puskesmasWa.trim(),
      sppgId: precheck.sppgId!,
      lat: lat,
      lng: lng,
    );

    return SchoolRegistrationResult(
      requiresEmailConfirmation: false,
      schoolName: snapshot.school?.name ?? schoolName.trim(),
      session: snapshot,
    );
  }

  @override
  Future<AuthSessionSnapshot?> refreshSession() async {
    final client = _requireClient();
    final user = client.auth.currentUser;
    if (user == null) {
      return null;
    }
    return _loadOrCompleteSession(client, user);
  }

  @override
  Future<AuthSessionSnapshot> updateSchoolPartnerCode(String inviteCode) async {
    final client = _requireClient();
    final user = client.auth.currentUser;
    if (user == null) {
      throw const AuthFriendlyException('Sesi berakhir. Silakan masuk ulang.');
    }

    final rows = await client.rpc(
      'lookup_sppg_by_invite_code',
      params: {'p_invite_code': inviteCode.trim().toUpperCase()},
    ) as List<dynamic>;

    if (rows.isEmpty) {
      throw const AuthFriendlyException(
        'Kode Mitra SPPG tidak ditemukan. Pastikan kode sesuai dari dapur mitra Anda.',
      );
    }

    final kitchenRow = Map<String, dynamic>.from(rows.first as Map);
    final sppgId = kitchenRow['id'] as String;

    await client
        .from('schools')
        .update({
          'sppg_id': sppgId,
          'verification_status': 'pending',
        })
        .eq('owner_user_id', user.id);

    return _loadOrCompleteSession(client, user);
  }

  @override
  Future<AuthSessionSnapshot> updateSchoolOperationalSettings({
    required String puskesmasWa,
    required String adm4Code,
  }) async {
    final client = _requireClient();
    final user = client.auth.currentUser;
    if (user == null) {
      throw const AuthFriendlyException('Sesi berakhir. Silakan masuk ulang.');
    }

    await client
        .from('schools')
        .update({
          'puskesmas_wa': puskesmasWa.trim(),
          'adm4_code': adm4Code.trim(),
        })
        .eq('owner_user_id', user.id);

    return _loadOrCompleteSession(client, user);
  }

  @override
  Future<AuthSessionSnapshot> updateKitchenLocation({
    required double lat,
    required double lng,
    required String adm4Code,
  }) async {
    final client = _requireClient();
    final user = client.auth.currentUser;
    if (user == null) {
      throw const AuthFriendlyException('Sesi berakhir. Silakan masuk ulang.');
    }

    await client
        .from('sppg_kitchens')
        .update({
          'lat': lat,
          'lng': lng,
          'adm4_code': adm4Code.trim(),
        })
        .eq('owner_user_id', user.id);

    return _loadOrCompleteSession(client, user);
  }

  @override
  Future<void> signOut() async {
    await _client?.auth.signOut();
  }

  Future<AuthSessionSnapshot> _loadOrCompleteSession(
    SupabaseClient client,
    User user,
  ) async {
    final profileRow = await client
        .from('profiles')
        .select('id, role, full_name')
        .eq('id', user.id)
        .maybeSingle();

    if (profileRow == null) {
      final completed = await _tryCompletePendingOnboarding(client, user);
      if (completed != null) {
        return completed;
      }
      throw const AuthFriendlyException(
        'Profil akun belum lengkap. Silakan daftar ulang atau hubungi admin.',
      );
    }

    final profile = UserProfile(
      id: profileRow['id'] as String,
      email: user.email ?? '',
      role: UserRole.fromDb(profileRow['role'] as String?),
      fullName: (profileRow['full_name'] as String?) ?? '',
    );

    KitchenProfile? kitchen;
    SchoolProfile? school;

    if (profile.role == UserRole.kitchen) {
      final kitchenRow = await client
          .from('sppg_kitchens')
          .select()
          .eq('owner_user_id', user.id)
          .maybeSingle();
      if (kitchenRow != null) {
        final loaded = KitchenProfile.fromMap(kitchenRow);
        var activePublicKey = loaded.publicKey;
        try {
          activePublicKey = await _ed25519Service.ensureKeyPairSynced(
            sppgId: loaded.id,
            remotePublicKeyB64: loaded.publicKey,
            legacyUserId: user.id,
            onSyncRemotePublicKey: (publicKeyB64) async {
              await client
                  .from('sppg_kitchens')
                  .update({'public_key': publicKeyB64})
                  .eq('id', loaded.id)
                  .eq('owner_user_id', user.id);
            },
          );
        } catch (_) {
          // Preserve loaded public key when offline or secure storage fails.
        }
        kitchen = activePublicKey == loaded.publicKey
            ? loaded
            : KitchenProfile(
                id: loaded.id,
                ownerUserId: loaded.ownerUserId,
                regNumber: loaded.regNumber,
                inviteCode: loaded.inviteCode,
                name: loaded.name,
                adm4Code: loaded.adm4Code,
                lat: loaded.lat,
                lng: loaded.lng,
                publicKey: activePublicKey,
                isVerified: loaded.isVerified,
              );
        await _cacheKitchenPublicKey(
          sppgId: kitchen.id,
          sppgName: kitchen.name,
          inviteCode: kitchen.inviteCode,
          publicKeyB64: kitchen.publicKey,
        );
      }
    } else if (profile.role == UserRole.school) {
      final schoolRow = await client
          .from('schools')
          .select()
          .eq('owner_user_id', user.id)
          .maybeSingle();
      if (schoolRow != null) {
        Map<String, dynamic>? partnerRow;
        final sppgId = schoolRow['sppg_id'] as String?;
        if (sppgId != null && sppgId.isNotEmpty) {
          partnerRow = await client
              .from('sppg_kitchens')
              .select('id, name, invite_code, public_key')
              .eq('id', sppgId)
              .maybeSingle();
          if (partnerRow != null) {
            await _cacheKitchenPublicKey(
              sppgId: partnerRow['id'] as String,
              sppgName: partnerRow['name'] as String,
              inviteCode: partnerRow['invite_code'] as String,
              publicKeyB64: partnerRow['public_key'] as String,
            );
          }
        }
        school = SchoolProfile.fromMap(schoolRow, partnerKitchen: partnerRow);
      }
    }

    return AuthSessionSnapshot(
      profile: profile,
      kitchen: kitchen,
      school: school,
    );
  }

  Future<AuthSessionSnapshot?> _tryCompletePendingOnboarding(
    SupabaseClient client,
    User user,
  ) async {
    final raw = _prefs?.getString(_pendingOnboardingKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final map = jsonDecode(raw) as Map<String, dynamic>;
    if (map['user_id'] != user.id) {
      return null;
    }

    final type = map['type'] as String?;
    if (type == 'kitchen') {
      final snapshot = await _finalizeKitchenOnboarding(
        client: client,
        user: user,
        regNumber: map['reg_number'] as String,
        pin: map['pin'] as String,
        picName: map['pic_name'] as String,
        kitchenName: map['kitchen_name'] as String,
        adm4Code: map['adm4_code'] as String,
        lat: (map['lat'] as num).toDouble(),
        lng: (map['lng'] as num).toDouble(),
        publicKeyB64: map['public_key'] as String,
      );
      await _prefs?.remove(_pendingOnboardingKey);
      return snapshot;
    }

    if (type == 'school') {
      final snapshot = await _finalizeSchoolOnboarding(
        client: client,
        user: user,
        npsn: map['npsn'] as String,
        schoolName: map['school_name'] as String,
        picName: map['pic_name'] as String,
        adm4Code: map['adm4_code'] as String,
        puskesmasWa: map['puskesmas_wa'] as String,
        sppgId: map['sppg_id'] as String,
        lat: (map['lat'] as num).toDouble(),
        lng: (map['lng'] as num).toDouble(),
      );
      await _prefs?.remove(_pendingOnboardingKey);
      return snapshot;
    }

    return null;
  }

  Future<AuthSessionSnapshot> _finalizeKitchenOnboarding({
    required SupabaseClient client,
    required User user,
    required String regNumber,
    required String pin,
    required String picName,
    required String kitchenName,
    required String adm4Code,
    required double lat,
    required double lng,
    required String publicKeyB64,
  }) async {
    final claimRaw = await client.rpc(
      'claim_sppg_registration',
      params: {'p_reg_number': regNumber, 'p_pin': pin},
    );
    final claimMap = Map<String, dynamic>.from(claimRaw as Map);
    final ok = (claimMap['ok'] as bool?) ?? false;
    if (!ok) {
      throw AuthFriendlyException(
        AuthErrorMapper.mapRpcReason(claimMap['reason'] as String?),
      );
    }

    final inviteCode = claimMap['invite_code'] as String;

    await client.from('profiles').upsert({
      'id': user.id,
      'role': 'kitchen',
      'full_name': picName,
    });

    await client.from('sppg_kitchens').insert({
      'owner_user_id': user.id,
      'reg_number': regNumber,
      'invite_code': inviteCode,
      'name': kitchenName,
      'adm4_code': adm4Code,
      'lat': lat,
      'lng': lng,
      'public_key': publicKeyB64,
      'is_verified': true,
    });

    await _prefs?.remove(_pendingOnboardingKey);
    return _loadOrCompleteSession(client, user);
  }

  Future<AuthSessionSnapshot> _finalizeSchoolOnboarding({
    required SupabaseClient client,
    required User user,
    required String npsn,
    required String schoolName,
    required String picName,
    required String adm4Code,
    required String puskesmasWa,
    required String sppgId,
    required double lat,
    required double lng,
  }) async {
    await client.from('profiles').upsert({
      'id': user.id,
      'role': 'school',
      'full_name': picName,
    });

    await client.from('schools').insert({
      'owner_user_id': user.id,
      'sppg_id': sppgId,
      'npsn': npsn,
      'name': schoolName,
      'adm4_code': adm4Code,
      'lat': lat,
      'lng': lng,
      'puskesmas_wa': puskesmasWa,
      'verification_status': 'pending',
    });

    await _prefs?.remove(_pendingOnboardingKey);
    return _loadOrCompleteSession(client, user);
  }

  Future<void> _cacheKitchenPublicKey({
    required String sppgId,
    required String sppgName,
    required String inviteCode,
    required String publicKeyB64,
  }) async {
    try {
      await _database.upsertSppgKey(
        LocalSppgKeysCompanion(
          sppgId: Value(sppgId),
          sppgName: Value(sppgName),
          inviteCode: Value(inviteCode),
          publicKeyB64: Value(publicKeyB64),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    } catch (_) {
      // Do not block auth completion if local Drift cache write fails.
    }
  }
}
