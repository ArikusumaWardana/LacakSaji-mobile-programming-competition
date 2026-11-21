import 'package:lacak_saji/core/constants/app_routes.dart';

enum UserRole {
  kitchen('kitchen', 'Petugas Dapur SPPG'),
  school('school', 'Guru / PIC Sekolah'),
  supervisor('supervisor', 'Pengawas BGN / Dinkes');

  const UserRole(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static UserRole fromDb(String? value) {
    for (final role in UserRole.values) {
      if (role.dbValue == value) {
        return role;
      }
    }
    return UserRole.school;
  }
}

enum SchoolVerificationStatus {
  pending('pending', 'Menunggu Persetujuan SPPG'),
  approved('approved', 'Terverifikasi'),
  rejected('rejected', 'Ditolak SPPG');

  const SchoolVerificationStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static SchoolVerificationStatus fromDb(String? value) {
    for (final status in SchoolVerificationStatus.values) {
      if (status.dbValue == value) {
        return status;
      }
    }
    return SchoolVerificationStatus.pending;
  }
}

enum AuthStatus {
  initializing,
  unauthenticated,
  authenticated,
  awaitingEmailConfirmation,
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.role,
    required this.fullName,
  });

  final String id;
  final String email;
  final UserRole role;
  final String fullName;
}

class KitchenProfile {
  const KitchenProfile({
    required this.id,
    required this.ownerUserId,
    required this.regNumber,
    required this.inviteCode,
    required this.name,
    required this.adm4Code,
    required this.lat,
    required this.lng,
    required this.publicKey,
    required this.isVerified,
  });

  final String id;
  final String ownerUserId;
  final String regNumber;
  final String inviteCode;
  final String name;
  final String adm4Code;
  final double lat;
  final double lng;
  final String publicKey;
  final bool isVerified;

  factory KitchenProfile.fromMap(Map<String, dynamic> map) {
    return KitchenProfile(
      id: map['id'] as String,
      ownerUserId: map['owner_user_id'] as String,
      regNumber: map['reg_number'] as String,
      inviteCode: map['invite_code'] as String,
      name: map['name'] as String,
      adm4Code: map['adm4_code'] as String,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      publicKey: map['public_key'] as String,
      isVerified: (map['is_verified'] as bool?) ?? true,
    );
  }
}

class SchoolProfile {
  const SchoolProfile({
    required this.id,
    required this.ownerUserId,
    required this.sppgId,
    required this.npsn,
    required this.name,
    required this.adm4Code,
    required this.lat,
    required this.lng,
    required this.puskesmasWa,
    required this.verificationStatus,
    this.partnerKitchenName,
    this.partnerInviteCode,
    this.partnerPublicKey,
  });

  final String id;
  final String ownerUserId;
  final String? sppgId;
  final String npsn;
  final String name;
  final String adm4Code;
  final double lat;
  final double lng;
  final String puskesmasWa;
  final SchoolVerificationStatus verificationStatus;
  final String? partnerKitchenName;
  final String? partnerInviteCode;
  final String? partnerPublicKey;

  String get formattedPuskesmasWa => formatIndonesianWaDisplay(puskesmasWa);

  factory SchoolProfile.fromMap(
    Map<String, dynamic> map, {
    Map<String, dynamic>? partnerKitchen,
  }) {
    return SchoolProfile(
      id: map['id'] as String,
      ownerUserId: map['owner_user_id'] as String,
      sppgId: map['sppg_id'] as String?,
      npsn: map['npsn'] as String,
      name: map['name'] as String,
      adm4Code: map['adm4_code'] as String,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      puskesmasWa: map['puskesmas_wa'] as String,
      verificationStatus: SchoolVerificationStatus.fromDb(
        map['verification_status'] as String?,
      ),
      partnerKitchenName: partnerKitchen?['name'] as String?,
      partnerInviteCode: partnerKitchen?['invite_code'] as String?,
      partnerPublicKey: partnerKitchen?['public_key'] as String?,
    );
  }
}

class WhitelistCheckResult {
  const WhitelistCheckResult({
    required this.ok,
    this.reason,
    this.regNumber,
    this.officialName,
    this.regionName,
  });

  final bool ok;
  final String? reason;
  final String? regNumber;
  final String? officialName;
  final String? regionName;
}

class SchoolPrecheckResult {
  const SchoolPrecheckResult({
    required this.ok,
    this.reason,
    this.sppgId,
    this.sppgName,
    this.sppgInviteCode,
    this.sppgPublicKey,
  });

  final bool ok;
  final String? reason;
  final String? sppgId;
  final String? sppgName;
  final String? sppgInviteCode;
  final String? sppgPublicKey;
}

class AuthSessionSnapshot {
  const AuthSessionSnapshot({
    required this.profile,
    this.kitchen,
    this.school,
  });

  final UserProfile profile;
  final KitchenProfile? kitchen;
  final SchoolProfile? school;
}

class KitchenRegistrationResult {
  const KitchenRegistrationResult({
    required this.requiresEmailConfirmation,
    required this.inviteCode,
    required this.kitchenName,
    this.session,
  });

  final bool requiresEmailConfirmation;
  final String inviteCode;
  final String kitchenName;
  final AuthSessionSnapshot? session;
}

class SchoolRegistrationResult {
  const SchoolRegistrationResult({
    required this.requiresEmailConfirmation,
    required this.schoolName,
    this.session,
  });

  final bool requiresEmailConfirmation;
  final String schoolName;
  final AuthSessionSnapshot? session;
}

class AuthState {
  const AuthState({
    required this.status,
    this.profile,
    this.kitchen,
    this.school,
    this.isBusy = false,
    this.errorMessage,
    this.pendingConfirmationEmail,
    this.holdKitchenActivationSummary = false,
  });

  const AuthState.initializing()
      : status = AuthStatus.initializing,
        profile = null,
        kitchen = null,
        school = null,
        isBusy = false,
        errorMessage = null,
        pendingConfirmationEmail = null,
        holdKitchenActivationSummary = false;

  final AuthStatus status;
  final UserProfile? profile;
  final KitchenProfile? kitchen;
  final SchoolProfile? school;
  final bool isBusy;
  final String? errorMessage;
  final String? pendingConfirmationEmail;
  final bool holdKitchenActivationSummary;

  String get landingRoute {
    if (status != AuthStatus.authenticated || profile == null) {
      return AppRoutes.login;
    }
    switch (profile!.role) {
      case UserRole.kitchen:
        return AppRoutes.kitchenHome;
      case UserRole.supervisor:
        return AppRoutes.supervisor;
      case UserRole.school:
        final schoolStatus = school?.verificationStatus;
        if (schoolStatus == SchoolVerificationStatus.approved) {
          return AppRoutes.schoolHome;
        }
        return AppRoutes.pendingVerification;
    }
  }

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? profile,
    KitchenProfile? kitchen,
    SchoolProfile? school,
    bool? isBusy,
    String? errorMessage,
    String? pendingConfirmationEmail,
    bool? holdKitchenActivationSummary,
    bool clearError = false,
    bool clearEntities = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      profile: clearEntities ? null : (profile ?? this.profile),
      kitchen: clearEntities ? null : (kitchen ?? this.kitchen),
      school: clearEntities ? null : (school ?? this.school),
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pendingConfirmationEmail: clearEntities
          ? null
          : (pendingConfirmationEmail ?? this.pendingConfirmationEmail),
      holdKitchenActivationSummary: clearEntities
          ? false
          : (holdKitchenActivationSummary ?? this.holdKitchenActivationSummary),
    );
  }
}

/// Formats Indonesian WhatsApp numbers with a leading `+62` prefix for display.
String formatIndonesianWaDisplay(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) {
    return '-';
  }
  if (digits.startsWith('0')) {
    return '+62${digits.substring(1)}';
  }
  if (digits.startsWith('8')) {
    return '+62$digits';
  }
  return '+$digits';
}
