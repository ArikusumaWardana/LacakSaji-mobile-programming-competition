import 'package:lacak_saji/core/constants/app_routes.dart';

enum UserRole {
  kitchen('kitchen', 'Petugas Dapur SPPG'),
  courier('courier', 'Kurir / Pengantar'),
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

enum InstitutionMemberRole {
  admin('admin', 'Admin Institusi'),
  staff('staff', 'Staf Pelaksana'),
  courier('courier', 'Kurir Pengantar');

  const InstitutionMemberRole(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static InstitutionMemberRole? fromDb(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final role in InstitutionMemberRole.values) {
      if (role.dbValue == value) {
        return role;
      }
    }
    return null;
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
    this.institutionRole,
  });

  final UserProfile profile;
  final KitchenProfile? kitchen;
  final SchoolProfile? school;
  final InstitutionMemberRole? institutionRole;
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

enum AuthBusyAction {
  signIn,
  signInDemo,
  registerKitchen,
  registerSchool,
  refreshStatus,
  updatePartnerCode,
  updateSchoolSettings,
  updateKitchenLocation,
  signOut,
}

class AuthState {
  const AuthState({
    required this.status,
    this.profile,
    this.kitchen,
    this.school,
    this.institutionRole,
    this.busyAction,
    this.errorMessage,
    this.pendingConfirmationEmail,
    this.holdKitchenActivationSummary = false,
  });

  const AuthState.initializing()
      : status = AuthStatus.initializing,
        profile = null,
        kitchen = null,
        school = null,
        institutionRole = null,
        busyAction = null,
        errorMessage = null,
        pendingConfirmationEmail = null,
        holdKitchenActivationSummary = false;

  final AuthStatus status;
  final UserProfile? profile;
  final KitchenProfile? kitchen;
  final SchoolProfile? school;
  final InstitutionMemberRole? institutionRole;
  final AuthBusyAction? busyAction;
  final String? errorMessage;
  final String? pendingConfirmationEmail;
  final bool holdKitchenActivationSummary;

  bool get isBusy => busyAction != null;

  bool get isInstitutionAdmin {
    final currentProfile = profile;
    if (status != AuthStatus.authenticated || currentProfile == null) {
      return false;
    }
    if (currentProfile.role != UserRole.kitchen &&
        currentProfile.role != UserRole.school) {
      return false;
    }
    if (institutionRole != null) {
      return institutionRole == InstitutionMemberRole.admin;
    }
    if (currentProfile.role == UserRole.kitchen && kitchen != null) {
      return kitchen!.ownerUserId == currentProfile.id;
    }
    if (currentProfile.role == UserRole.school && school != null) {
      return school!.ownerUserId == currentProfile.id;
    }
    return false;
  }

  String get landingRoute {
    if (status != AuthStatus.authenticated || profile == null) {
      return AppRoutes.login;
    }
    switch (profile!.role) {
      case UserRole.kitchen:
        return AppRoutes.kitchenHome;
      case UserRole.courier:
        return AppRoutes.courierHome;
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
    InstitutionMemberRole? institutionRole,
    AuthBusyAction? busyAction,
    String? errorMessage,
    String? pendingConfirmationEmail,
    bool? holdKitchenActivationSummary,
    bool clearBusy = false,
    bool clearError = false,
    bool clearEntities = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      profile: clearEntities ? null : (profile ?? this.profile),
      kitchen: clearEntities ? null : (kitchen ?? this.kitchen),
      school: clearEntities ? null : (school ?? this.school),
      institutionRole: clearEntities
          ? null
          : (institutionRole ?? this.institutionRole),
      busyAction: clearBusy ? null : (busyAction ?? this.busyAction),
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

enum AuthFeedbackType {
  loggedIn,
  loggedOut,
}

/// Transient notification emitted after explicit sign-in or sign-out transitions.
class AuthFeedbackNotice {
  const AuthFeedbackNotice({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
  });

  final int id;
  final AuthFeedbackType type;
  final String title;
  final String message;
}

/// Resolves a clean actor display name without duplicating role parentheses.
String? resolveAuthActorName({
  required UserProfile? profile,
  required KitchenProfile? kitchen,
  required SchoolProfile? school,
}) {
  if (profile?.role == UserRole.courier) {
    final fullName = profile?.fullName.trim();
    if (fullName != null && fullName.isNotEmpty) {
      final cleaned = fullName.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
      return cleaned.isNotEmpty ? cleaned : fullName;
    }
  }
  final kitchenName = kitchen?.name.trim();
  if (kitchenName != null && kitchenName.isNotEmpty) {
    return kitchenName;
  }
  final schoolName = school?.name.trim();
  if (schoolName != null && schoolName.isNotEmpty) {
    return schoolName;
  }
  final fullName = profile?.fullName.trim();
  if (fullName != null && fullName.isNotEmpty) {
    final cleaned = fullName.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
    return cleaned.isNotEmpty ? cleaned : fullName;
  }
  return null;
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
