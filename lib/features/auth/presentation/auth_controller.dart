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
        );
      }
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
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
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: AuthErrorMapper.mapException(error),
      );
      return false;
    }
  }

  Future<bool> signInDemo(DemoAccountPreset preset) {
    return signIn(email: preset.email, password: preset.password);
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
    state = state.copyWith(isBusy: true, clearError: true);
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
          holdKitchenActivationSummary: true,
        );
      }
      return result;
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
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
    state = state.copyWith(isBusy: true, clearError: true);
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
        );
      }
      return result;
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: AuthErrorMapper.mapException(error),
      );
      return null;
    }
  }

  Future<bool> refreshStatus() async {
    state = state.copyWith(isBusy: true, clearError: true);
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
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: AuthErrorMapper.mapException(error),
      );
      return false;
    }
  }

  Future<bool> updateSchoolPartnerCode(String inviteCode) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final snapshot = await _repo.updateSchoolPartnerCode(inviteCode);
      state = AuthState(
        status: AuthStatus.authenticated,
        profile: snapshot.profile,
        kitchen: snapshot.kitchen,
        school: snapshot.school,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: AuthErrorMapper.mapException(error),
      );
      return false;
    }
  }

  Future<bool> updateSchoolSettings({
    required String puskesmasWa,
    required String adm4Code,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
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
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
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
    state = state.copyWith(isBusy: true, clearError: true);
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
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: AuthErrorMapper.mapException(error),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _repo.signOut();
    } finally {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }
}
