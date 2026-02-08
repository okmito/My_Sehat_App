import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/diagnostics/triage_models.dart';

class DiagnosticsApiService {
  late final Dio _dio;

  DiagnosticsApiService() {
    // Diagnostics backend runs on port 8001
    // Use 10.0.2.2 for Android emulator, localhost for others
    final baseUrl = (!kIsWeb && Platform.isAndroid)
        ? 'http://10.0.2.2:8001'
        : 'http://127.0.0.1:8001';

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        validateStatus: (status) => status! < 500, // Handle 400s manually
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    // Add logging in debug mode
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (object) => debugPrint('[Diagnostics API] $object'),
      ));
    }
  }

  Future<TriageResponse> startTextTriage({
    required String userId,
    required String symptoms,
    required int age,
    required String duration,
    required String severity,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/triage/text',
        options: Options(headers: {'X-User-Id': userId}),
        data: {
          'symptoms': symptoms,
          'age': age,
          'duration': duration,
          'severity': severity,
        },
      );

      if (response.statusCode == 200) {
        return TriageResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to start triage: ${response.statusMessage}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<TriageResponse> sendAnswer({
    required String userId,
    required String sessionId,
    required String answer,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/triage/session/$sessionId/answer',
        options: Options(headers: {'X-User-Id': userId}),
        data: {'answer': answer},
      );

      if (response.statusCode == 200) {
        return TriageResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to send answer: ${response.statusMessage}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<TriageResponse> sendSessionText({
    required String userId,
    required String sessionId,
    required String symptoms,
    required int age,
    required String duration,
    required String severity,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/triage/session/$sessionId/text',
        options: Options(headers: {'X-User-Id': userId}),
        data: {
          'symptoms': symptoms,
          'age': age,
          'duration': duration,
          'severity': severity,
        },
      );

      if (response.statusCode == 200) {
        return TriageResponse.fromJson(response.data);
      } else {
        throw Exception(
            'Failed to send session text: ${response.statusMessage}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<TriageResponse> sendImage({
    required String userId,
    required XFile imageFile,
    String? sessionId,
  }) async {
    // Check file size (5MB limit)
    final fileSize = await imageFile.length();
    if (fileSize > 5 * 1024 * 1024) {
      throw Exception('Image size exceeds 5MB limit.');
    }

    try {
      final bytes = await imageFile.readAsBytes();

      FormData formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: imageFile.name,
        ),
        if (sessionId != null) 'session_id': sessionId,
      });

      final response = await _dio.post(
        '/api/v1/triage/image',
        options: Options(headers: {'X-User-Id': userId}),
        data: formData,
      );

      if (response.statusCode == 200) {
        return TriageResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to send image: ${response.statusMessage}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
