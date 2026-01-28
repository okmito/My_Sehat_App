import 'package:hive_flutter/hive_flutter.dart';
import '../../features/auth/data/models/user_model.dart';
import '../../features/daily_journal/models/journal_entry_model.dart';
import '../../features/medicine_reminder/models/medicine_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:path_provider/path_provider.dart';

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError("Initialize this in main");
});

class LocalStorageService {
  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(UserModelAdapter());
    Hive.registerAdapter(JournalEntryAdapter());
    Hive.registerAdapter(JournalSegmentAdapter());
    Hive.registerAdapter(JournalStickerAdapter());
    Hive.registerAdapter(JournalDrawingAdapter());
    Hive.registerAdapter(OffsetDataAdapter());
    Hive.registerAdapter(MedicineModelAdapter());

    await Hive.openBox<UserModel>('users');
    await Hive.openBox<Map<dynamic, dynamic>>('emergency_contacts');
    await Hive.openBox<dynamic>('settings');
    await Hive.openBox<JournalEntry>('journal_entries');
    await Hive.openBox<MedicineModel>('medicines');
  }

  Box<UserModel> get userBox => Hive.box<UserModel>('users');
  Box<Map<dynamic, dynamic>> get emergencyContactsBox =>
      Hive.box<Map<dynamic, dynamic>>('emergency_contacts');
  Box<dynamic> get settingsBox => Hive.box<dynamic>('settings');
  Box<JournalEntry> get journalBox => Hive.box<JournalEntry>('journal_entries');
  Box<MedicineModel> get medicineBox => Hive.box<MedicineModel>('medicines');
}
