import '../../../../core/usecases/usecase.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Result<UserEntity>> login(String phoneNumber, String otp);
  Future<Result<UserEntity>> updateProfile(UserEntity user);
  Future<Result<UserEntity?>> getCurrentUser();
  Future<Result<void>> logout();
}
