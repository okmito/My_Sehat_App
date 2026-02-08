import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../../core/config/health_record_config.dart';
import '../models/health_record_model.dart';

class HealthRecordRemoteDataSource {
  HealthRecordRemoteDataSource(this._dio);

  final Dio _dio;

  /// Analyze a document without saving
  Future<DocumentAnalysisResult> analyzeDocument({
    required File file,
    required String userId,
  }) async {
    final fileName = file.path.split('/').last.split('\\').last;
    final extension = fileName.split('.').last.toLowerCase();

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
        contentType: _getMediaType(extension),
      ),
      'user_id': userId,
    });

    final response = await _dio.post(
      '/health-records/analyze',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    return DocumentAnalysisResult.fromJson(
        response.data as Map<String, dynamic>);
  }

  /// Save a health record after verification
  Future<HealthRecordModel> saveHealthRecord({
    required File file,
    required String userId,
    required DocumentType documentType,
    String? documentDate,
    String? doctorName,
    String? hospitalName,
    String? patientName,
    String? diagnosis,
    String? notes,
    StorageType storageType = StorageType.permanent,
    bool consentGiven = true,
    bool shareInEmergency = true,
    List<CriticalInfoModel>? criticalInfo,
  }) async {
    final fileName = file.path.split('/').last.split('\\').last;
    final extension = fileName.split('.').last.toLowerCase();

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
        contentType: _getMediaType(extension),
      ),
      'user_id': userId,
      'document_type': documentType.apiValue,
      if (documentDate != null) 'document_date': documentDate,
      if (doctorName != null) 'doctor_name': doctorName,
      if (hospitalName != null) 'hospital_name': hospitalName,
      if (patientName != null) 'patient_name': patientName,
      if (diagnosis != null) 'diagnosis': diagnosis,
      if (notes != null) 'notes': notes,
      'storage_type': storageType.apiValue,
      'consent_given': consentGiven,
      'share_in_emergency': shareInEmergency,
      if (criticalInfo != null && criticalInfo.isNotEmpty)
        'critical_info':
            jsonEncode(criticalInfo.map((e) => e.toJson()).toList()),
    });

    final response = await _dio.post(
      '/health-records/save',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    return HealthRecordModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get all health records for a user
  Future<List<HealthRecordModel>> getHealthRecords({
    required String userId,
    int skip = 0,
    int limit = 50,
  }) async {
    final response = await _dio.get(
      '/health-records/list',
      queryParameters: {
        'user_id': userId,
        'skip': skip,
        'limit': limit,
      },
    );

    final data = response.data as List<dynamic>;
    return data
        .whereType<Map<String, dynamic>>()
        .map(HealthRecordModel.fromJson)
        .toList();
  }

  /// Get a specific health record
  Future<HealthRecordModel> getHealthRecord({
    required int recordId,
    required String userId,
  }) async {
    final response = await _dio.get(
      '/health-records/$recordId',
      queryParameters: {'user_id': userId},
    );

    return HealthRecordModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get timeline view
  Future<List<TimelineEntryModel>> getTimeline({
    required String userId,
  }) async {
    final response = await _dio.get(
      '/health-records/timeline',
      queryParameters: {'user_id': userId},
    );

    final data = response.data as Map<String, dynamic>;
    final entries = data['entries'] as List<dynamic>? ?? [];
    return entries
        .whereType<Map<String, dynamic>>()
        .map(TimelineEntryModel.fromJson)
        .toList();
  }

  /// Delete a health record
  Future<void> deleteHealthRecord({
    required int recordId,
    required String userId,
  }) async {
    await _dio.delete(
      '/health-records/$recordId',
      queryParameters: {'user_id': userId},
    );
  }

  /// Set emergency access for a record
  Future<void> setEmergencyAccess({
    required int recordId,
    required String userId,
    required bool accessible,
  }) async {
    await _dio.post(
      '/health-records/$recordId/emergency-access',
      queryParameters: {
        'user_id': userId,
        'accessible': accessible,
      },
    );
  }

  MediaType _getMediaType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'pdf':
        return MediaType('application', 'pdf');
      default:
        return MediaType('application', 'octet-stream');
    }
  }
}

final healthRecordDioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(healthRecordBaseUrlProvider);
  // ignore: avoid_print
  print('[HealthRecord] Base URL => $baseUrl');
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  // Add logging interceptor for debugging
  dio.interceptors.add(LogInterceptor(
    requestHeader: true,
    requestBody: true,
    responseHeader: true,
    responseBody: true,
    error: true,
    logPrint: (object) => print('[HealthRecord API] $object'),
  ));

  return dio;
});

final healthRecordRemoteDataSourceProvider =
    Provider<HealthRecordRemoteDataSource>((ref) {
  return HealthRecordRemoteDataSource(ref.watch(healthRecordDioProvider));
});
