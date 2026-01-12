import '../../../../core/services/local_storage_service.dart';
import '../models/user_model.dart';
// import '../../domain/entities/user_entity.dart';

abstract class AuthLocalDataSource {
  Future<void> cacheUser(UserModel user);
  Future<UserModel?> getLastUser();
  Future<void> clearUser();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final LocalStorageService localStorageService;

  AuthLocalDataSourceImpl(this.localStorageService);

  @override
  Future<void> cacheUser(UserModel user) async {
    // We assume single user for now or use user.userId as key
    await localStorageService.userBox.put('current_user', user);
  }

  @override
  Future<UserModel?> getLastUser() async {
    return localStorageService.userBox.get('current_user');
  }

  @override
  Future<void> clearUser() async {
    await localStorageService.userBox.delete('current_user');
  }
}
