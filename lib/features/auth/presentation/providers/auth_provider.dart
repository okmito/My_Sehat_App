import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/local_storage_service.dart';
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

  Future<void> checkAuthStatus() async {
    final result = await _repository.getCurrentUser();

    if (result is Success<UserEntity?>) {
      state = AsyncValue.data(result.data);
    } else if (result is Error<UserEntity?>) {
      state = AsyncValue.error(result.failure, StackTrace.current);
    }
  }

  Future<void> login(String phoneNumber, String otp) async {
    state = const AsyncValue.loading();
    final result = await _repository.login(phoneNumber, otp);

    if (result is Success<UserEntity>) {
      state = AsyncValue.data(result.data);
    } else if (result is Error<UserEntity>) {
      state = AsyncValue.error(result.failure.message, StackTrace.current);
    }
  }

  Future<void> logout() async {
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
