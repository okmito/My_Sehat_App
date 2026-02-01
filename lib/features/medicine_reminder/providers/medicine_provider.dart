import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/medicine_api_service.dart';
import '../models/medication.dart';
import '../models/reminder.dart';

final medicineApiServiceProvider = Provider((ref) => MedicineApiService());

final medicineProvider =
    StateNotifierProvider<MedicineNotifier, List<Medication>>((ref) {
  final api = ref.watch(medicineApiServiceProvider);
  return MedicineNotifier(api, ref);
});

final todayRemindersProvider =
    FutureProvider.autoDispose<List<Reminder>>((ref) async {
  final api = ref.watch(medicineApiServiceProvider);
  final data = await api.getTodayReminders();
  return data.map((e) => Reminder.fromJson(e)).toList();
});

class MedicineNotifier extends StateNotifier<List<Medication>> {
  final MedicineApiService _api;
  final Ref _ref;

  MedicineNotifier(this._api, this._ref) : super([]) {
    loadMedicines();
  }

  Future<void> loadMedicines() async {
    try {
      final data = await _api.getMedications();
      state = data.map((e) => Medication.fromJson(e)).toList();
    } catch (e) {
      // Handle error or populate with empty state
      print("Error loading medicines: $e");
    }
  }

  Future<void> addMedicine({
    required Medication medication,
    required Map<String, dynamic> scheduleData,
  }) async {
    try {
      // 1. Create Medication
      final createdMed = await _api.createMedication(medication.toJson());
      final medId = createdMed['id'].toString();

      // 2. Create Schedule
      await _api.createSchedule(medId, scheduleData);

      // 3. Generate Reminders
      await _api.generateReminders(7);

      // 4. Refresh List
      await loadMedicines();

      // 5. Refresh Reminders
      _refreshReminders();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateMedicine({
    required String id,
    required Medication medication,
    required Map<String, dynamic> scheduleData,
  }) async {
    try {
      // 1. Update Medication
      await _api.updateMedication(id, medication.toJson());

      // 2. Update Schedule
      await _api.updateSchedule(id, scheduleData);

      // 3. Regenerate Reminders (Optional but good to sync)
      await _api.generateReminders(7);

      await loadMedicines();
      _refreshReminders();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteMedicine(String id) async {
    try {
      await _api.deleteMedication(id);
      await loadMedicines();
      _refreshReminders();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> endMedicine(String id) async {
    try {
      // "End Course -> update schedule end_date = today"
      final today = DateTime.now().toIso8601String().split('T').first;
      // We need to know current schedule type/times to update it,
      // or maybe backend allows partial update?
      // User instructions: "update schedule end_date = today"
      // If backend requires full body for PUT /schedule, we might need to fetch it first.
      // But `GET /medications` might not have schedule.
      // We will try to find the medication in current state.
      final med = state.firstWhere((element) => element.id == id);
      if (med.schedule != null) {
        final scheduleData = med.schedule!.toJson();
        scheduleData['end_date'] = today;
        await _api.updateSchedule(id, scheduleData);
        await loadMedicines();
        _refreshReminders();
      }
    } catch (e) {
      print("Error ending medicine: $e");
      rethrow;
    }
  }

  Future<void> toggleStatus(String reminderId, String status) async {
    try {
      await _api.markReminder(reminderId, status);
      _refreshReminders();
    } catch (e) {
      print("Error marking reminder: $e");
      rethrow;
    }
  }

  void _refreshReminders() {
    _ref.invalidate(todayRemindersProvider);
  }
}
