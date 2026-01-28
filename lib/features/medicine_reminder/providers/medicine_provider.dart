import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/local_storage_service.dart';

import '../models/medicine_model.dart';

final medicineProvider =
    StateNotifierProvider<MedicineNotifier, List<MedicineModel>>((ref) {
  final localStorage = ref.watch(localStorageServiceProvider);
  return MedicineNotifier(localStorage);
});

class MedicineNotifier extends StateNotifier<List<MedicineModel>> {
  final LocalStorageService _localStorage;

  MedicineNotifier(this._localStorage) : super([]) {
    _loadMedicines();
  }

  void _loadMedicines() {
    state = _localStorage.medicineBox.values.toList();
  }

  Future<void> addMedicine(MedicineModel medicine) async {
    await _localStorage.medicineBox.put(medicine.id, medicine);
    _loadMedicines();
  }

  Future<void> updateMedicine(MedicineModel medicine) async {
    await _localStorage.medicineBox.put(medicine.id, medicine);
    _loadMedicines();
  }

  Future<void> endMedicine(String id) async {
    final medicine = _localStorage.medicineBox.get(id);
    if (medicine != null) {
      final updatedMedicine = medicine.copyWith(endDate: DateTime.now());
      await _localStorage.medicineBox.put(id, updatedMedicine);
      _loadMedicines();
    }
  }

  Future<void> deleteMedicine(String id) async {
    await _localStorage.medicineBox.delete(id);
    _loadMedicines();
  }

  Future<void> toggleStatusByKey(String id, String key, String? status) async {
    final medicine = _localStorage.medicineBox.get(id);
    if (medicine != null) {
      final newHistory = Map<String, String>.from(medicine.history);
      if (status == null) {
        newHistory.remove(key);
      } else {
        newHistory[key] = status;
      }

      final updatedMedicine = medicine.copyWith(history: newHistory);
      await _localStorage.medicineBox.put(id, updatedMedicine);
      _loadMedicines();
    }
  }
}
