import 'package:hive_flutter/hive_flutter.dart';
import '../../features/auth/data/models/user_model.dart';
// import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(UserModelAdapter());
    await Hive.openBox<UserModel>('users');
  }

  Box<UserModel> get userBox => Hive.box<UserModel>('users');
}
