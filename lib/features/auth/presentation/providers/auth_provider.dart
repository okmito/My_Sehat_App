import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../services/auth_api_service.dart';
import '../../data/datasources/auth_local_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/user_entity.dart';
import '../../../../core/usecases/usecase.dart';

// Service Providers

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return AuthLocalDataSourceImpl(ref.watch(localStorageServiceProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
      localDataSource: ref.watch(authLocalDataSourceProvider));
});

// State Providers
final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserEntity?>>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<UserEntity?>> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AsyncValue.loading()) {
    checkAuthStatus();
  }

  /// Check if user has a valid session (persistent login)
  Future<void> checkAuthStatus() async {
    // Try to validate stored session token with API
    final apiResult = await AuthApiService.validateSession();

    if (apiResult.success && apiResult.user != null) {
      // Valid session - update state with API user data
      final userEntity = UserEntity(
        id: apiResult.user!.id.toString(),
        phoneNumber: apiResult.user!.phoneNumber,
        name: apiResult.user!.name,
        age: apiResult.user!.age,
        gender: apiResult.user!.gender,
        bloodGroup: apiResult.user!.bloodGroup,
        allergies: apiResult.user!.allergies,
        conditions: apiResult.user!.conditions,
      );
      state = AsyncValue.data(userEntity);
      return;
    }

    // No valid API session - user must login
    // Clear any stale local cache
    await _repository.logout();
    state = const AsyncValue.data(null);
  }

  /// Login with phone number via API
  Future<void> login(String phoneNumber, String otp) async {
    state = const AsyncValue.loading();

    // Try API login first
    final apiResult = await AuthApiService.login(
      phoneNumber: phoneNumber,
      otp: otp,
    );

    if (apiResult.success && apiResult.user != null) {
      final userEntity = UserEntity(
        id: apiResult.user!.id.toString(),
        phoneNumber: apiResult.user!.phoneNumber,
        name: apiResult.user!.name,
        age: apiResult.user!.age,
        gender: apiResult.user!.gender,
        bloodGroup: apiResult.user!.bloodGroup,
        allergies: apiResult.user!.allergies,
        conditions: apiResult.user!.conditions,
      );

      // Also cache locally for offline access
      await _repository.login(phoneNumber, otp);

      state = AsyncValue.data(userEntity);
      return;
    }

    // Fall back to local mock if API fails
    final result = await _repository.login(phoneNumber, otp);

    if (result is Success<UserEntity>) {
      state = AsyncValue.data(result.data);
    } else if (result is Error<UserEntity>) {
      state = AsyncValue.error(result.failure.message, StackTrace.current);
    }
  }

  /// Set authenticated user from API response (used by signup)
  void setAuthenticatedUser(UserData userData) {
    final userEntity = UserEntity(
      id: userData.id.toString(),
      phoneNumber: userData.phoneNumber,
      name: userData.name,
      age: userData.age,
      gender: userData.gender,
      bloodGroup: userData.bloodGroup,
      allergies: userData.allergies,
      conditions: userData.conditions,
    );
    state = AsyncValue.data(userEntity);
  }

  Future<void> logout() async {
    // Logout from API
    await AuthApiService.logout();

    // Clear local cache
    await _repository.logout();

    state = const AsyncValue.data(null);
  }

  Future<void> updateProfile(UserEntity user) async {
    state = const AsyncValue.loading();
    final result = await _repository.updateProfile(user);
    if (result is Success<UserEntity>) {
      state = AsyncValue.data(result.data);
    } else if (result is Error<UserEntity>) {
      state = AsyncValue.error(result.failure.message, StackTrace.current);
    }
  }
}
