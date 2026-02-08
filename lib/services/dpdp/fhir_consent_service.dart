// FHIR Consent Service for Hospital Sharing
// Implements DPDP-compliant consent management for HL7 FHIR R4 data sharing
//
// This service allows patients to:
// - Grant time-limited consent for hospitals to access their FHIR data
// - Instantly revoke consent at any time
// - View which hospitals have active access
// - See audit logs of FHIR data access

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// FHIR DATA CATEGORIES (DPDP Act aligned)
// ============================================================================

enum FhirResourceCategory {
  patient('Patient Demographics', 'Patient'),
  observation('Observations & Vitals', 'Observation'),
  condition('Conditions & Diagnoses', 'Condition'),
  medication('Medications', 'MedicationRequest'),
  diagnostic('Diagnostic Reports', 'DiagnosticReport'),
  document('Health Documents', 'DocumentReference'),
  allergy('Allergies', 'AllergyIntolerance'),
  encounter('Encounters', 'Encounter'),
  emergencyBundle('Emergency Profile', 'Bundle');

  final String displayName;
  final String fhirResource;
  const FhirResourceCategory(this.displayName, this.fhirResource);
}

// ============================================================================
// HOSPITAL CONSENT RECORD
// ============================================================================

class HospitalFhirConsent {
  final String id;
  final String hospitalId;
  final String hospitalName;
  final List<FhirResourceCategory> grantedResources;
  final DateTime grantedAt;
  final DateTime? expiresAt;
  final bool isActive;
  final String? revokedAt;
  final String? sosEventId; // For emergency SOS auto-expiry consent
  final String consentHash; // DPDP audit reference

  HospitalFhirConsent({
    required this.id,
    required this.hospitalId,
    required this.hospitalName,
    required this.grantedResources,
    required this.grantedAt,
    this.expiresAt,
    this.isActive = true,
    this.revokedAt,
    this.sosEventId,
    required this.consentHash,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isValidAccess => isActive && !isExpired;

  Map<String, dynamic> toJson() => {
        'id': id,
        'hospital_id': hospitalId,
        'hospital_name': hospitalName,
        'granted_resources':
            grantedResources.map((r) => r.fhirResource).toList(),
        'granted_at': grantedAt.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'is_active': isActive,
        'revoked_at': revokedAt,
        'sos_event_id': sosEventId,
        'consent_hash': consentHash,
      };

  factory HospitalFhirConsent.fromJson(Map<String, dynamic> json) {
    return HospitalFhirConsent(
      id: json['id'],
      hospitalId: json['hospital_id'],
      hospitalName: json['hospital_name'],
      grantedResources: (json['granted_resources'] as List)
          .map((r) => FhirResourceCategory.values.firstWhere(
              (e) => e.fhirResource == r,
              orElse: () => FhirResourceCategory.patient))
          .toList(),
      grantedAt: DateTime.parse(json['granted_at']),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
      isActive: json['is_active'] ?? true,
      revokedAt: json['revoked_at'],
      sosEventId: json['sos_event_id'],
      consentHash: json['consent_hash'] ?? '',
    );
  }
}

// ============================================================================
// FHIR CONSENT STATE
// ============================================================================

class FhirConsentState {
  final List<HospitalFhirConsent> hospitalConsents;
  final bool isLoading;
  final String? error;
  final DateTime? lastSynced;

  const FhirConsentState({
    this.hospitalConsents = const [],
    this.isLoading = false,
    this.error,
    this.lastSynced,
  });

  FhirConsentState copyWith({
    List<HospitalFhirConsent>? hospitalConsents,
    bool? isLoading,
    String? error,
    DateTime? lastSynced,
  }) {
    return FhirConsentState(
      hospitalConsents: hospitalConsents ?? this.hospitalConsents,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastSynced: lastSynced ?? this.lastSynced,
    );
  }

  /// Get all active hospital consents
  List<HospitalFhirConsent> get activeConsents =>
      hospitalConsents.where((c) => c.isValidAccess).toList();

  /// Check if a hospital has valid access
  bool hasValidAccess(String hospitalId) {
    return hospitalConsents
        .any((c) => c.hospitalId == hospitalId && c.isValidAccess);
  }

  /// Get resources a hospital can access
  List<FhirResourceCategory> getGrantedResources(String hospitalId) {
    final consent = hospitalConsents.firstWhere(
      (c) => c.hospitalId == hospitalId && c.isValidAccess,
      orElse: () => HospitalFhirConsent(
        id: '',
        hospitalId: hospitalId,
        hospitalName: '',
        grantedResources: [],
        grantedAt: DateTime.now(),
        consentHash: '',
      ),
    );
    return consent.grantedResources;
  }
}

// ============================================================================
// FHIR CONSENT NOTIFIER
// ============================================================================

class FhirConsentNotifier extends StateNotifier<FhirConsentState> {
  final String userId;
  final Dio _dio;
  static const _storageKey = 'fhir_hospital_consents';

  // Android emulator uses 10.0.2.2 to reach host machine's localhost
  static String get _baseUrl {
    // For Android emulator, use 10.0.2.2; for others use localhost
    return 'http://10.0.2.2:8000';
  }

  FhirConsentNotifier(this.userId)
      : _dio = Dio(BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        )),
        super(const FhirConsentState()) {
    _loadFromStorage();
  }

  /// Load consents from local storage
  Future<void> _loadFromStorage() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_storageKey);
      if (json != null) {
        final data = jsonDecode(json) as List;
        final consents =
            data.map((e) => HospitalFhirConsent.fromJson(e)).toList();
        state = state.copyWith(
          hospitalConsents: consents,
          isLoading: false,
          lastSynced: DateTime.now(),
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Save consents to local storage
  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final json =
        jsonEncode(state.hospitalConsents.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, json);
  }

  /// Grant consent to a hospital for specified FHIR resources
  Future<bool> grantHospitalConsent({
    required String hospitalId,
    required String hospitalName,
    required List<FhirResourceCategory> resources,
    Duration? expiresAfter,
    String? sosEventId,
  }) async {
    try {
      // Generate consent hash for audit trail
      final consentHash = _generateConsentHash(hospitalId, resources);
      final now = DateTime.now();

      // Call backend API to register consent
      final response = await _dio.post(
        '/api/v1/consent/grant',
        data: {
          'data_category': 'health_records',
          'purpose': sosEventId != null ? 'emergency' : 'sharing',
          'granted_to': 'hospital',
          'consent_text': 'FHIR Hospital: $hospitalId - Resources: ${resources.map((r) => r.fhirResource).join(", ")}',
          'expires_in_days': expiresAfter != null ? (expiresAfter.inSeconds / 86400).ceil() : null,
        },
        options: Options(headers: {'X-User-ID': userId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final consent = HospitalFhirConsent(
          id: response.data['id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          hospitalId: hospitalId,
          hospitalName: hospitalName,
          grantedResources: resources,
          grantedAt: now,
          expiresAt: expiresAfter != null ? now.add(expiresAfter) : null,
          isActive: true,
          sosEventId: sosEventId,
          consentHash: consentHash,
        );

        // Update state - remove any existing consent for this hospital first
        final updatedConsents = state.hospitalConsents
            .where((c) => c.hospitalId != hospitalId)
            .toList()
          ..add(consent);

        state = state.copyWith(
          hospitalConsents: updatedConsents,
          lastSynced: now,
        );
        await _saveToStorage();
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Failed to grant consent: $e');
      return false;
    }
  }

  /// Revoke consent from a hospital - IMMEDIATE effect
  Future<bool> revokeHospitalConsent(String hospitalId) async {
    try {
      // Check if we have an active consent for this hospital
      final hasConsent = state.hospitalConsents.any(
        (c) => c.hospitalId == hospitalId && c.isActive,
      );
      if (!hasConsent) {
        throw Exception('No active consent found');
      }

      // Call backend API to revoke consent
      final response = await _dio.post(
        '/api/v1/consent/revoke',
        data: {
          'data_category': 'health_records',
          'purpose': 'sharing',
        },
        options: Options(headers: {'X-User-ID': userId}),
      );

      if (response.statusCode == 200) {
        // Update local state immediately
        final updatedConsents = state.hospitalConsents.map((c) {
          if (c.hospitalId == hospitalId && c.isActive) {
            return HospitalFhirConsent(
              id: c.id,
              hospitalId: c.hospitalId,
              hospitalName: c.hospitalName,
              grantedResources: c.grantedResources,
              grantedAt: c.grantedAt,
              expiresAt: c.expiresAt,
              isActive: false,
              revokedAt: DateTime.now().toIso8601String(),
              sosEventId: c.sosEventId,
              consentHash: c.consentHash,
            );
          }
          return c;
        }).toList();

        state = state.copyWith(
          hospitalConsents: updatedConsents,
          lastSynced: DateTime.now(),
        );
        await _saveToStorage();
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Failed to revoke consent: $e');
      return false;
    }
  }

  /// Revoke ALL hospital consents - emergency button
  Future<void> revokeAllConsents() async {
    for (final consent in state.hospitalConsents.where((c) => c.isActive)) {
      await revokeHospitalConsent(consent.hospitalId);
    }
  }

  /// Sync with backend (pull latest consent states)
  Future<void> syncWithBackend() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _dio.get(
        '/api/v1/consent/my',
        options: Options(headers: {'X-User-ID': userId}),
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        final consents =
            data.map((e) => HospitalFhirConsent.fromJson(e)).toList();
        state = state.copyWith(
          hospitalConsents: consents,
          isLoading: false,
          lastSynced: DateTime.now(),
        );
        await _saveToStorage();
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Sync failed: $e',
      );
    }
  }

  String _generateConsentHash(
      String hospitalId, List<FhirResourceCategory> resources) {
    final input =
        '$userId:$hospitalId:${resources.map((r) => r.fhirResource).join(",")}:${DateTime.now().millisecondsSinceEpoch}';
    // Simple hash for demo - in production use crypto hash
    return input.hashCode.toRadixString(16);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider for FHIR consent state - requires user ID
final fhirConsentProvider =
    StateNotifierProvider.family<FhirConsentNotifier, FhirConsentState, String>(
  (ref, userId) => FhirConsentNotifier(userId),
);

/// Provider for checking if a specific hospital has valid FHIR access
final hospitalHasFhirAccessProvider =
    Provider.family<bool, ({String userId, String hospitalId})>((ref, params) {
  final state = ref.watch(fhirConsentProvider(params.userId));
  return state.hasValidAccess(params.hospitalId);
});
