import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_triage_response.dart';
import '../../../../core/config/api_config.dart';

// Use centralized API config for Render compatibility
String get kAiMentalHealthBaseUrl => ApiConfig.mentalHealthUrl;

final aiTriageServiceProvider = Provider<AiTriageService>((ref) {
  return AiTriageService(Dio(BaseOptions(
    baseUrl: kAiMentalHealthBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  )));
});

class AiTriageService {
  final Dio _dio;

  AiTriageService(this._dio);

  Future<AiTriageResponse> sendMessage({
    required String message,
    required String sessionId,
  }) async {
    try {
      final response = await _dio.post(
        '/chat/message', // Correct endpoint (no prefix)
        data: {
          'message': message,
          'user_id': sessionId, // Backend expects 'user_id'
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return AiTriageResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to load response: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
