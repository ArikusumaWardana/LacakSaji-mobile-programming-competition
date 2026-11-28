import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/demo_accounts.dart';
import '../../../core/crypto/ed25519_service.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/supabase_provider.dart';
import '../../../core/theme/text_scale_provider.dart';
import '../data/auth_repository.dart';
import '../domain/auth_error_mapper.dart';
import '../domain/auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(
    client: ref.watch(supabaseClientProvider),
    database: ref.watch(appDatabaseProvider),
    ed25519Service: ref.watch(ed25519ServiceProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

final authFeedbackProvider =
    NotifierProvider<AuthFeedbackNotifier, AuthFeedbackNotice?>(
      AuthFeedbackNotifier.new,
    );

class AuthFeedbackNotifier extends Notifier<AuthFeedbackNotice?> {
  int _nextId = 0;

  @override
  AuthFeedbackNotice? build() => null;

  void showLoginSuccess(AuthSessionSnapshot snapshot) {
    final actorName =
        resolveAuthActorName(
          profile: snapshot.profile,
          kitchen: snapshot.kitchen,
          school: snapshot.school,
        ) ??
        snapshot.profile.role.label;
    final roleNote = _resolveLoginRoleDetail(snapshot);
    state = AuthFeedbackNotice(
      id: ++_nextId,
      type: AuthFeedbackType.loggedIn,
      title: 'Berhasil Masuk',
      message: 'Masuk sebagai $actorName ($roleNote).',
    );
  }

  void showLogoutSuccess(String? previousActorName) {
    final cleanName = previousActorName?.trim();
    state = AuthFeedbackNotice(
      id: ++_nextId,
      type: AuthFeedbackType.loggedOut,
      title: 'Berhasil Keluar',
      message: cleanName != null && cleanName.isNotEmpty
          ? 'Anda telah keluar dari akun $cleanName.'
          : 'Anda telah keluar dari akun.',
    );
  }

  void dismiss() {
    if (state != null) {
      state = null;
    }
  }

  String _resolveLoginRoleDetail(AuthSessionSnapshot snapshot) {
    if (snapshot.profile.role == UserRole.school && snapshot.school != null) {
      switch (snapshot.school!.verificationStatus) {
        case SchoolVerificationStatus.pending:
          return 'Menunggu persetujuan SPPG';
        case SchoolVerificationStatus.rejected:
          return 'Tautan SPPG ditolak';
        case SchoolVerificationStatus.approved:
          return snapshot.profile.role.label;
      }
    }
    return snapshot.profile.role.label;
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  bool _bootstrapped = false;

  @override
  AuthState build() => const AuthState.initializing();

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  Future<void> bootstrap() async {
    if (_bootstrapped) {
      return;
    }
    _bootstrapped = true;

    try {
      final snapshot = await _repo.restoreSession();
      if (snapshot == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      } else {
        state = AuthState(
          status: AuthStatus.authenticated,
          profile: snapshot.profile,
          kitchen: snapshot.kitchen,
          school: snapshot.school,
          institutionRole: snapshot.institutionRole,
        );
      }
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) {
    return _performSignIn(
      email: email,
      password: password,
      busyAction: AuthBusyAction.signIn,
    );
  }

  Future<bool> signInDemo(DemoAccountPreset preset) {
    return _performSignIn(
      email: preset.email,
      password: preset.password,
      busyAction: AuthBusyAction.signInDemo,
    );
  }

  Future<bool> _performSignIn({
    required String email,
    required String password,
    required AuthBusyAction busyAction,
  }) async {
    state = state.copyWith(busyAction: busyAction, clearError: true);
    try {
      final snapshot = await _repo.signInWithPassword(
        email: email,
        password: password,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        profile: snapshot.profile,
        kitchen: snapshot.kitchen,
        school: snapshot.school,
        institutionRole: snapshot.institutionRole,
      );
      ref.read(authFeedbackProvider.notifier).showLoginSuccess(snapshot);
      return true;
    } catch (error) {
      state = state.copyWith(
        clearBusy: true,
        errorMessage: AuthErrorMapper.mapException(error),
      );
      return false;
    }
  }

  Future<WhitelistCheckResult> verifySppgWhitelist({
    required String regNumber,
    required String pin,
  }) async {
    try {
      return await _repo.verifySppgWhitelist(regNumber: regNumber, pin: pin);
    } catch (error) {
      throw AuthFriendlyException(AuthErrorMapper.mapException(error));
    }
  }

  Future<KitchenRegistrationResult?> registerKitchen({
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
    state = state.copyWith(
      busyAction: AuthBusyAction.registerKitchen,
      clearError: true,
    );
    try {
      final result = await _repo.registerKitchen(
        regNumber: regNumber,
        pin: pin,
        picName: picName,
        kitchenName: kitchenName,
        adm4Code: adm4Code,
        lat: lat,
        lng: lng,
        email: email,
        password: password,
      );

      if (result.requiresEmailConfirmation) {
        state = AuthState(
          status: AuthStatus.awaitingEmailConfirmation,
          pendingConfirmationEmail: email.trim(),
        );
      } else if (result.session != null) {
        final session = result.session!;
        state = AuthState(
          status: AuthStatus.authenticated,
          profile: session.profile,
          kitchen: session.kitchen,
          school: session.school,
          institutionRole: session.institutionRole,
          holdKitchenActivationSummary: true,
        );
      }
      return result;
    } catch (error) {
      state = state.copyWith(
        clearBusy: true,
        errorMessage: AuthErrorMapper.mapException(error),
      );
      return null;
    }
  }

  void completeKitchenActivationSummary() {
    if (state.holdKitchenActivationSummary) {
      state = state.copyWith(holdKitchenActivationSummary: false);
    }
  }

  Future<SchoolPrecheckResult> precheckSchool({
    required String npsn,
    required String inviteCode,
  }) async {
    try {
      return await _repo.precheckSchool(npsn: npsn, inviteCode: inviteCode);
    } catch (error) {
      throw AuthFriendlyException(AuthErrorMapper.mapException(error));
    }
  }

  Future<SchoolRegistrationResult?> registerSchool({
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
    state = state.copyWith(
      busyAction: AuthBusyAction.registerSchool,
      clearError: true,
    );
    try {
      final result = await _repo.registerSchool(
        npsn: npsn,
        schoolName: schoolName,
        picName: picName,
        adm4Code: adm4Code,
        puskesmasWa: puskesmasWa,
        inviteCode: inviteCode,
        lat: lat,
        lng: lng,
        email: email,
        password: password,
      );

      if (result.requiresEmailConfirmation) {
        state = AuthState(
          status: AuthStatus.awaitingEmailConfirmation,
          pendingConfirmationEmail: email.trim(),
        );
      } else if (result.session != null) {
        final session = result.session!;
        state = AuthState(
          status: AuthStatus.authenticated,
          profile: session.profile,
          kitchen: session.kitchen,
          school: session.school,
          institutionRole: session.institutionRole,
        );
      }
      return result;
    } catch (error) {
      state = state.copyWith(
        clearBusy: true,
        errorMessage: AuthErrorMapper.mapException(error),
      );
      return null;
    }
  }

  Future<bool> refreshStatus() async {
    state = state.copyWith(
      busyAction: AuthBusyAction.refreshStatus,
      clearError: true,
    );
    try {
      final snapshot = await _repo.refreshSession();
      if (snapshot == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return false;
      }
      state = AuthState(
        status: AuthStatus.authenticated,
        profile: snapshot.profile,
        kitchen: snapshot.kitchen,
        school: snapshot.school,
        institutionRole: snapshot.institutionRole,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        clearBusy: true,
        errorMessage: AuthErrorMapper.mapException(error),
      );
      return false;
    }
  }

  Future<bool> updateSchoolPartnerCode(String inviteCode) async {
    state = state.copyWith(
      busyAction: AuthBusyAction.updatePartnerCode,
      clearError: true,
    );
    try {
      final snapshot = await _repo.updateSchoolPartnerCode(inviteCode);
      state = AuthState(
        status: AuthStatus.authenticated,
        profile: snapshot.profile,
        kitchen: snapshot.kitchen,
        school: snapshot.school,
        institutionRole: snapshot.institutionRole,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        clearBusy: true,
        errorMessage: AuthErrorMapper.mapException(error),
      );
      return false;
    }
  }

  Future<bool> updateSchoolSettings({
    required String puskesmasWa,
    required String adm4Code,
  }) async {
    state = state.copyWith(
      busyAction: AuthBusyAction.updateSchoolSettings,
      clearError: true,
    );
    try {
      final snapshot = await _repo.updateSchoolOperationalSettings(
        puskesmasWa: puskesmasWa,
        adm4Code: adm4Code,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        profile: snapshot.profile,
        kitchen: snapshot.kitchen,
        school: snapshot.school,
        institutionRole: snapshot.institutionRole,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        clearBusy: true,
        errorMessage: AuthErrorMapper.mapException(error),
      );
      return false;
    }
  }

  Future<bool> updateKitchenLocation({
    required double lat,
    required double lng,
    required String adm4Code,
  }) async {
    state = state.copyWith(
      busyAction: AuthBusyAction.updateKitchenLocation,
      clearError: true,
    );
    try {
      final snapshot = await _repo.updateKitchenLocation(
        lat: lat,
        lng: lng,
        adm4Code: adm4Code,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        profile: snapshot.profile,
        kitchen: snapshot.kitchen,
        school: snapshot.school,
        institutionRole: snapshot.institutionRole,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        clearBusy: true,
        errorMessage: AuthErrorMapper.mapException(error),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    final previousActorName = resolveAuthActorName(
      profile: state.profile,
      kitchen: state.kitchen,
      school: state.school,
    );
    state = state.copyWith(
      busyAction: AuthBusyAction.signOut,
      clearError: true,
    );
    try {
      await _repo.signOut();
    } finally {
      state = const AuthState(status: AuthStatus.unauthenticated);
      ref
          .read(authFeedbackProvider.notifier)
          .showLogoutSuccess(previousActorName);
    }
  }
}
