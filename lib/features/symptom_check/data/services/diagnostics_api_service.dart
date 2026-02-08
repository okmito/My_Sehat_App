import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/triage_models.dart';
import '../../../../core/config/api_config.dart';

class DiagnosticsApiService {
  // Use centralized API config for Render compatibility
  static String get _baseUrl => '${ApiConfig.diagnosticsUrl}/api/v1';

  static const String _userIdKey = 'diagnostics_user_id';

  // Singleton pattern or Provider injection is typically used,
  // but here we'll use a simple instance for the provider to consume.

  Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString(_userIdKey);
    if (userId == null) {
      userId = const Uuid().v4();
      await prefs.setString(_userIdKey, userId);
    }
    return userId;
  }

  Future<Map<String, String>> _getHeaders() async {
    final userId = await getUserId();
    return {
      'Content-Type': 'application/json',
      'X-User-Id': userId,
    };
  }

  Future<TriageResponse> sendInitialSymptoms(String symptoms,
      {int? age, String? duration, String? severity}) async {
    final url = Uri.parse('$_baseUrl/triage/text');
    final headers = await _getHeaders();

    final payload = {
      'symptoms': symptoms,
      if (age != null) 'age': age,
      if (duration != null) 'duration': duration,
      if (severity != null) 'severity': severity,
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(payload),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to send symptoms: $e');
    }
  }

  Future<TriageResponse> sendAnswer(String sessionId, String answer) async {
    final url = Uri.parse('$_baseUrl/triage/text');
    final headers = await _getHeaders();

    final payload = {
      'session_id': sessionId,
      'answer': answer,
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(payload),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to send answer: $e');
    }
  }

  Future<TriageResponse> sendImage(XFile imageFile, {String? sessionId}) async {
    final url = Uri.parse('$_baseUrl/triage/image');
    final userId = await getUserId(); // Headers are different for multipart

    final request = http.MultipartRequest('POST', url);
    request.headers['X-User-Id'] = userId;

    if (sessionId != null) {
      request.fields['session_id'] = sessionId;
    }

    // Add file
    final fileBytes = await imageFile.readAsBytes();
    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: imageFile.name,
      contentType: MediaType('image',
          'jpeg'), // Adjust based on actual type if needed, strict check might be needed
    );
    request.files.add(multipartFile);

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  TriageResponse _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      return TriageResponse.fromJson(data);
    } else {
      throw Exception('API Error: ${response.statusCode} ${response.body}');
    }
  }
}
