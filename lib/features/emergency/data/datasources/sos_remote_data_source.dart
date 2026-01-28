import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/sos_config.dart';
import '../models/hospital_model.dart';
import '../models/sos_event_model.dart';

class SOSRemoteDataSource {
  SOSRemoteDataSource(this._dio);

  final Dio _dio;

  Future<SOSEventModel> createSOS({
    required String userId,
    required double latitude,
    required double longitude,
    String emergencyType = 'Medical',
  }) async {
    final response = await _dio.post('/sos/', data: {
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      'emergency_type': emergencyType,
    });
    return SOSEventModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SOSEventModel> getSOSStatus(int sosId) async {
    final response = await _dio.get('/sos/$sosId');
    return SOSEventModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<HospitalModel>> getNearbyHospitals({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _dio.get('/hospitals/nearby', queryParameters: {
      'lat': latitude,
      'lon': longitude,
    });

    final data = response.data as List<dynamic>;
    return data
        .whereType<Map<String, dynamic>>()
        .map(HospitalModel.fromJson)
        .toList();
  }
}

final sosDioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(sosBaseUrlProvider);
  // Simple debug log to verify base URL at runtime
  // ignore: avoid_print
  print('[SOS] Base URL => $baseUrl');
  return Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );
});

final sosRemoteDataSourceProvider = Provider<SOSRemoteDataSource>((ref) {
  return SOSRemoteDataSource(ref.watch(sosDioProvider));
});
