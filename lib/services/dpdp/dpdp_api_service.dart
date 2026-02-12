// DPDP Act 2023 Compliance API Service
// Connects Flutter app to backend consent management endpoints

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/config/api_config.dart';

/// Data categories as defined by DPDP Act 2023
enum DpdpDataCategory {
  health,
  location,
  personalIdentity,
  mentalHealth,
  medication,
  healthRecords,
  biometric,
}

/// Purpose of data processing
enum DpdpPurpose {
  treatment,
  aiProcessing,
  analytics,
  research,
  emergency,
  sharing,
  storage,
}

/// Who the consent is granted to
enum DpdpGrantedTo {
  selfApp,
  aiService,
  doctor,
  hospital,
  emergencyService,
  thirdParty,
}

/// Consent status response from API
class ConsentStatus {
  final bool isValid;
  final int? consentId;
  final DateTime? grantedAt;
  final DateTime? expiresAt;
  final String? reason;

  ConsentStatus({
    required this.isValid,
    this.consentId,
    this.grantedAt,
    this.expiresAt,
    this.reason,
  });

  factory ConsentStatus.fromJson(Map<String, dynamic> json) {
    return ConsentStatus(
      isValid: json['is_valid'] ?? false,
      consentId: json['consent_id'],
      grantedAt: json['granted_at'] != null
          ? DateTime.parse(json['granted_at'])
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
      reason: json['reason'],
    );
  }
}

/// Single consent record
class ConsentRecord {
  final int id;
  final String userId;
  final String dataCategory;
  final String purpose;
  final String grantedTo;
  final DateTime grantedAt;
  final DateTime? expiresAt;
  final bool isActive;
  final String? consentText;

  ConsentRecord({
    required this.id,
    required this.userId,
    required this.dataCategory,
    required this.purpose,
    required this.grantedTo,
    required this.grantedAt,
    this.expiresAt,
    required this.isActive,
    this.consentText,
  });

  factory ConsentRecord.fromJson(Map<String, dynamic> json) {
    return ConsentRecord(
      id: json['id'],
      userId: json['user_id'],
      dataCategory: json['data_category'],
      purpose: json['purpose'],
      grantedTo: json['granted_to'],
      grantedAt: DateTime.parse(json['granted_at']),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
      isActive: json['is_active'] ?? true,
      consentText: json['consent_text'],
    );
  }
}

/// Audit log entry
class AuditLogEntry {
  final int id;
  final String userId;
  final String action;
  final String? resourceType;
  final String? resourceId;
  final String? purpose;
  final DateTime timestamp;
  final Map<String, dynamic>? details;

  AuditLogEntry({
    required this.id,
    required this.userId,
    required this.action,
    this.resourceType,
    this.resourceId,
    this.purpose,
    required this.timestamp,
    this.details,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'],
      userId: json['user_id'],
      action: json['action'],
      resourceType: json['resource_type'],
      resourceId: json['resource_id'],
      purpose: json['purpose'],
      timestamp: DateTime.parse(json['timestamp']),
      details: json['details'] is Map
          ? Map<String, dynamic>.from(json['details'])
          : null,
    );
  }
}

/// User data export response
class UserDataExport {
  final String userId;
  final DateTime exportedAt;
  final Map<String, dynamic> data;

  UserDataExport({
    required this.userId,
    required this.exportedAt,
    required this.data,
  });

  factory UserDataExport.fromJson(Map<String, dynamic> json) {
    return UserDataExport(
      userId: json['user_id'],
      exportedAt: DateTime.parse(json['exported_at']),
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }
}

/// DPDP API Service - Manages consent and user rights
class DpdpApiService {
  late final Dio _dio;

  DpdpApiService() {
    // Use centralized API config for Render compatibility
    final baseUrl = ApiConfig.dpdpUrl;

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        validateStatus: (status) => status! < 500,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (object) => debugPrint('[DPDP API] $object'),
      ));
    }
  }

  // ============================================================================
  // CONSENT MANAGEMENT
  // ============================================================================

  /// Grant consent for a specific data category and purpose
  Future<ConsentStatus> grantConsent({
    required String userId,
    required DpdpDataCategory dataCategory,
    required DpdpPurpose purpose,
    required DpdpGrantedTo grantedTo,
    String? consentText,
    Duration? expiresAfter,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/consent/grant',
        data: {
          'user_id': userId,
          'data_category': _categoryToString(dataCategory),
          'purpose': _purposeToString(purpose),
          'granted_to': _grantedToToString(grantedTo),
          'consent_text': consentText,
          'expires_in_days': expiresAfter?.inDays,
        },
      );

      if (response.statusCode == 200) {
        return ConsentStatus.fromJson(response.data);
      } else {
        throw DpdpApiException(
          'Failed to grant consent',
          response.statusCode,
          response.data['detail'],
        );
      }
    } on DioException catch (e) {
      throw DpdpApiException(
        'Network error granting consent',
        e.response?.statusCode,
        e.message,
      );
    }
  }

  /// Revoke consent for a specific data category and purpose
  Future<bool> revokeConsent({
    required String userId,
    required DpdpDataCategory dataCategory,
    required DpdpPurpose purpose,
    DpdpGrantedTo? grantedTo,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/consent/revoke',
        data: {
          'user_id': userId,
          'data_category': _categoryToString(dataCategory),
          'purpose': _purposeToString(purpose),
          'granted_to':
              grantedTo != null ? _grantedToToString(grantedTo) : null,
        },
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      throw DpdpApiException(
        'Network error revoking consent',
        e.response?.statusCode,
        e.message,
      );
    }
  }

  /// Check if consent exists for specific data category and purpose
  Future<ConsentStatus> checkConsent({
    required String userId,
    required DpdpDataCategory dataCategory,
    required DpdpPurpose purpose,
    DpdpGrantedTo? grantedTo,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/consent/check',
        data: {
          'user_id': userId,
          'data_category': _categoryToString(dataCategory),
          'purpose': _purposeToString(purpose),
          'granted_to':
              grantedTo != null ? _grantedToToString(grantedTo) : null,
        },
      );

      if (response.statusCode == 200) {
        return ConsentStatus.fromJson(response.data);
      } else {
        return ConsentStatus(isValid: false, reason: 'No consent found');
      }
    } on DioException catch (e) {
      // If 404, no consent exists
      if (e.response?.statusCode == 404) {
        return ConsentStatus(isValid: false, reason: 'No consent found');
      }
      throw DpdpApiException(
        'Network error checking consent',
        e.response?.statusCode,
        e.message,
      );
    }
  }

  /// Get all consents for a user
  Future<List<ConsentRecord>> getMyConsents(String userId) async {
    try {
      final response = await _dio.get(
        '/api/v1/consent/my',
        queryParameters: {'user_id': userId},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['consents'] ?? [];
        return data.map((json) => ConsentRecord.fromJson(json)).toList();
      } else {
        return [];
      }
    } on DioException catch (e) {
      throw DpdpApiException(
        'Network error fetching consents',
        e.response?.statusCode,
        e.message,
      );
    }
  }

  // ============================================================================
  // USER RIGHTS (DPDP Chapter III)
  // ============================================================================

  /// Right to Access - Export all user data (DPDP Section 11)
  Future<UserDataExport> exportMyData(String userId) async {
    try {
      final response = await _dio.get(
        '/api/v1/my-data',
        queryParameters: {'user_id': userId},
      );

      if (response.statusCode == 200) {
        return UserDataExport.fromJson(response.data);
      } else {
        throw DpdpApiException(
          'Failed to export data',
          response.statusCode,
          response.data['detail'],
        );
      }
    } on DioException catch (e) {
      throw DpdpApiException(
        'Network error exporting data',
        e.response?.statusCode,
        e.message,
      );
    }
  }

  /// Right to Erasure - Delete all user data (DPDP Section 12)
  Future<bool> deleteMyData(String userId) async {
    try {
      final response = await _dio.delete(
        '/api/v1/my-data',
        queryParameters: {'user_id': userId},
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      throw DpdpApiException(
        'Network error deleting data',
        e.response?.statusCode,
        e.message,
      );
    }
  }

  /// Right to Correction - Request data correction (DPDP Section 11(3))
  Future<bool> requestDataCorrection({
    required String userId,
    required String fieldName,
    required String currentValue,
    required String correctedValue,
    String? reason,
  }) async {
    try {
      final response = await _dio.patch(
        '/api/v1/my-data',
        queryParameters: {'user_id': userId},
        data: {
          'field': fieldName,
          'current_value': currentValue,
          'corrected_value': correctedValue,
          'reason': reason,
        },
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      throw DpdpApiException(
        'Network error requesting correction',
        e.response?.statusCode,
        e.message,
      );
    }
  }

  // ============================================================================
  // AUDIT TRAIL
  // ============================================================================

  /// Get user's audit log showing all data access and processing
  Future<List<AuditLogEntry>> getMyAuditLog(
    String userId, {
    int limit = 100,
    String? actionFilter,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/audit/my',
        queryParameters: {
          'user_id': userId,
          'limit': limit,
          if (actionFilter != null) 'action_filter': actionFilter,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['logs'] ?? [];
        return data.map((json) => AuditLogEntry.fromJson(json)).toList();
      } else {
        return [];
      }
    } on DioException catch (e) {
      throw DpdpApiException(
        'Network error fetching audit log',
        e.response?.statusCode,
        e.message,
      );
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  String _categoryToString(DpdpDataCategory category) {
    switch (category) {
      case DpdpDataCategory.health:
        return 'health';
      case DpdpDataCategory.location:
        return 'location';
      case DpdpDataCategory.personalIdentity:
        return 'personal_identity';
      case DpdpDataCategory.mentalHealth:
        return 'mental_health';
      case DpdpDataCategory.medication:
        return 'medication';
      case DpdpDataCategory.healthRecords:
        return 'health_records';
      case DpdpDataCategory.biometric:
        return 'biometric';
    }
  }

  String _purposeToString(DpdpPurpose purpose) {
    switch (purpose) {
      case DpdpPurpose.treatment:
        return 'treatment';
      case DpdpPurpose.aiProcessing:
        return 'ai_processing';
      case DpdpPurpose.analytics:
        return 'analytics';
      case DpdpPurpose.research:
        return 'research';
      case DpdpPurpose.emergency:
        return 'emergency';
      case DpdpPurpose.sharing:
        return 'sharing';
      case DpdpPurpose.storage:
        return 'storage';
    }
  }

  String _grantedToToString(DpdpGrantedTo grantedTo) {
    switch (grantedTo) {
      case DpdpGrantedTo.selfApp:
        return 'self_app';
      case DpdpGrantedTo.aiService:
        return 'ai_service';
      case DpdpGrantedTo.doctor:
        return 'doctor';
      case DpdpGrantedTo.hospital:
        return 'hospital';
      case DpdpGrantedTo.emergencyService:
        return 'emergency_service';
      case DpdpGrantedTo.thirdParty:
        return 'third_party';
    }
  }
}

/// Custom exception for DPDP API errors
class DpdpApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? details;

  DpdpApiException(this.message, this.statusCode, this.details);

  @override
  String toString() {
    return 'DpdpApiException: $message (status: $statusCode, details: $details)';
  }

  /// Check if this is a consent-required error (403)
  bool get isConsentRequired => statusCode == 403;

  /// Check if this is a not found error (404)
  bool get isNotFound => statusCode == 404;
}
