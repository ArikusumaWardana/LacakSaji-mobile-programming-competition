import '../../auth/domain/auth_models.dart';

enum InstitutionType {
  sppg('sppg', 'Dapur SPPG'),
  school('school', 'Sekolah');

  const InstitutionType(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static InstitutionType fromDb(String? value) {
    return value == 'school' ? InstitutionType.school : InstitutionType.sppg;
  }
}

enum SigningKeyStatus {
  active('active', 'AKTIF'),
  retired('retired', 'PENSIUN AMAN'),
  revoked('revoked', 'DICABUT');

  const SigningKeyStatus(this.dbValue, this.badgeLabel);

  final String dbValue;
  final String badgeLabel;

  static SigningKeyStatus fromDb(String? value) {
    for (final status in SigningKeyStatus.values) {
      if (status.dbValue == value) {
        return status;
      }
    }
    return SigningKeyStatus.active;
  }
}

class InstitutionMemberItem {
  const InstitutionMemberItem({
    required this.id,
    required this.institutionType,
    required this.institutionId,
    required this.memberName,
    required this.memberEmail,
    required this.role,
    required this.isActive,
    required this.createdAtUtc,
    this.userId,
    this.isOwner = false,
    this.isPendingSync = false,
  });

  final String id;
  final InstitutionType institutionType;
  final String institutionId;
  final String? userId;
  final String memberName;
  final String memberEmail;
  final InstitutionMemberRole role;
  final bool isActive;
  final DateTime createdAtUtc;
  final bool isOwner;
  final bool isPendingSync;
}

class SigningKeyItem {
  const SigningKeyItem({
    required this.keyId,
    required this.sppgId,
    required this.publicKeyB64,
    required this.status,
    required this.createdAtUtc,
    this.deviceLabel,
    this.retiredAtUtc,
    this.revokedAtUtc,
    this.isPendingSync = false,
  });

  final String keyId;
  final String sppgId;
  final String publicKeyB64;
  final SigningKeyStatus status;
  final String? deviceLabel;
  final DateTime createdAtUtc;
  final DateTime? retiredAtUtc;
  final DateTime? revokedAtUtc;
  final bool isPendingSync;
}

class TeamSecurityOverview {
  const TeamSecurityOverview({
    required this.institutionType,
    required this.institutionId,
    required this.institutionName,
    required this.canManageKeys,
    required this.members,
    required this.signingKeys,
  });

  final InstitutionType institutionType;
  final String institutionId;
  final String institutionName;
  final bool canManageKeys;
  final List<InstitutionMemberItem> members;
  final List<SigningKeyItem> signingKeys;

  int get activeMemberCount => members.where((m) => m.isActive).length;
}
