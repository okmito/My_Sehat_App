import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class MedicineApiService {
  late final Dio _dio;

  MedicineApiService() {
    // Use centralized API config for Render compatibility
    final baseUrl = ApiConfig.medicineUrl;

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {
        'X-User-Id': '1', // Hardcoded as per instructions
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    // Optional: Add logger for debugging
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
    }
  }

  // 1. Create Medication
  Future<Map<String, dynamic>> createMedication(
      Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/medications/', data: data);
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  // 2. Get All Medications
  Future<List<dynamic>> getMedications() async {
    try {
      final response = await _dio.get('/medications/');
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  // 3. Update Medication
  Future<Map<String, dynamic>> updateMedication(
      String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/medications/$id', data: data);
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  // 4. Delete Medication
  Future<void> deleteMedication(String id) async {
    try {
      await _dio.delete('/medications/$id');
    } catch (e) {
      throw _handleError(e);
    }
  }

  // 5. Create or Update Schedule
  Future<void> createSchedule(String medId, Map<String, dynamic> data) async {
    try {
      await _dio.post('/medications/$medId/schedule', data: data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateSchedule(String medId, Map<String, dynamic> data) async {
    try {
      await _dio.put('/medications/$medId/schedule', data: data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // 6. Generate Reminders
  Future<void> generateReminders(int days) async {
    try {
      await _dio.post('/reminders/generate', queryParameters: {'days': days});
    } catch (e) {
      throw _handleError(e);
    }
  }

  // 7. Get Today's Reminders
  Future<List<dynamic>> getTodayReminders() async {
    try {
      final response = await _dio.get('/reminders/today');
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  // 8. Mark Reminder
  Future<void> markReminder(String id, String status) async {
    try {
      await _dio.post(
        '/dose-events/$id/mark',
        data: {'status': status, 'note': null},
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic error) {
    if (error is DioException) {
      return Exception(
          'API Error: ${error.response?.statusCode} ${error.response?.statusMessage}');
    }
    return Exception('Unknown Error: $error');
  }
}
