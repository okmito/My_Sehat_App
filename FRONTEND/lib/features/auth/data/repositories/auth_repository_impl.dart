import 'package:uuid/uuid.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthLocalDataSource localDataSource;

  // In a real app, strict remoteDataSource would be here.
  // For now, we simulate remote auth and sync logic here or in a separate RemoteDataSource placeholder.

  AuthRepositoryImpl({
    required this.localDataSource,
  });

  @override
  Future<Result<UserEntity>> login(String phoneNumber, String otp) async {
    // Mock Remote login
    // In real app: call API -> get token -> get profile -> save local
    // Here: create dummy user -> save local

    if (otp != "123456") {
      return const Error(ServerFailure("Invalid OTP (Use 123456)"));
    }

    try {
      final user = UserModel()
        ..userId = const Uuid().v4()
        ..phoneNumber = phoneNumber
        ..name = "John Doe" // Placeholder
        ..age = 30;

      await localDataSource.cacheUser(user);
      return Success(user.toEntity());
    } catch (e) {
      return const Error(CacheFailure());
    }
  }

  @override
  Future<Result<UserEntity?>> getCurrentUser() async {
    try {
      final userModel = await localDataSource.getLastUser();
      if (userModel != null) {
        return Success(userModel.toEntity());
      }
      return const Success(null);
    } catch (e) {
      return const Error(CacheFailure());
    }
  }

  @override
  Future<Result<void>> logout() async {
    try {
      await localDataSource.clearUser();
      return const Success(null);
    } catch (e) {
      return const Error(CacheFailure());
    }
  }

  @override
  Future<Result<UserEntity>> updateProfile(UserEntity user) async {
    try {
      final userModel = UserModel.fromEntity(user);

      // Hive just overwrites with same key "current_user"
      await localDataSource.cacheUser(userModel);
      return Success(user);
    } catch (e) {
      return const Error(CacheFailure());
    }
  }
}
