// DPDP Consent Provider - Riverpod state management for consent
// Connects Flutter UI to DPDP backend API

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dpdp_api_service.dart';

/// Provider for DPDP API Service singleton
final dpdpApiServiceProvider = Provider<DpdpApiService>((ref) {
  return DpdpApiService();
});

/// State for consent management
class ConsentState {
  final bool isLoading;
  final String? error;
  final List<ConsentRecord> consents;
  final Map<String, ConsentStatus> consentCache;

  const ConsentState({
    this.isLoading = false,
    this.error,
    this.consents = const [],
    this.consentCache = const {},
  });

  ConsentState copyWith({
    bool? isLoading,
    String? error,
    List<ConsentRecord>? consents,
    Map<String, ConsentStatus>? consentCache,
  }) {
    return ConsentState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      consents: consents ?? this.consents,
      consentCache: consentCache ?? this.consentCache,
    );
  }

  /// Check if consent exists for a category-purpose pair
  bool hasConsent(DpdpDataCategory category, DpdpPurpose purpose) {
    final key = '${category.name}_${purpose.name}';
    return consentCache[key]?.isValid ?? false;
  }
}

/// Consent State Notifier - manages consent operations
class ConsentNotifier extends StateNotifier<ConsentState> {
  final DpdpApiService _apiService;
  final String _userId;

  ConsentNotifier(this._apiService, this._userId) : super(const ConsentState());

  /// Load all consents for the current user
  Future<void> loadConsents() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final consents = await _apiService.getMyConsents(_userId);

      // Build cache from loaded consents
      final cache = <String, ConsentStatus>{};
      for (final consent in consents) {
        final key = '${consent.dataCategory}_${consent.purpose}';
        cache[key] = ConsentStatus(
          isValid: consent.isActive,
          consentId: consent.id,
          grantedAt: consent.grantedAt,
          expiresAt: consent.expiresAt,
        );
      }

      state = state.copyWith(
        isLoading: false,
        consents: consents,
        consentCache: cache,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Grant consent for a specific category and purpose
  Future<bool> grantConsent({
    required DpdpDataCategory category,
    required DpdpPurpose purpose,
    required DpdpGrantedTo grantedTo,
    String? consentText,
    Duration? expiresAfter,
  }) async {
    try {
      final result = await _apiService.grantConsent(
        userId: _userId,
        dataCategory: category,
        purpose: purpose,
        grantedTo: grantedTo,
        consentText: consentText,
        expiresAfter: expiresAfter,
      );

      if (result.isValid) {
        // Update cache
        final key = '${category.name}_${purpose.name}';
        final newCache = Map<String, ConsentStatus>.from(state.consentCache);
        newCache[key] = result;
        state = state.copyWith(consentCache: newCache);

        // Reload full list
        await loadConsents();
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Revoke consent for a specific category and purpose
  Future<bool> revokeConsent({
    required DpdpDataCategory category,
    required DpdpPurpose purpose,
    DpdpGrantedTo? grantedTo,
  }) async {
    try {
      final success = await _apiService.revokeConsent(
        userId: _userId,
        dataCategory: category,
        purpose: purpose,
        grantedTo: grantedTo,
      );

      if (success) {
        // Update cache
        final key = '${category.name}_${purpose.name}';
        final newCache = Map<String, ConsentStatus>.from(state.consentCache);
        newCache.remove(key);
        state = state.copyWith(consentCache: newCache);

        // Reload full list
        await loadConsents();
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Check consent for a specific category and purpose
  Future<ConsentStatus> checkConsent({
    required DpdpDataCategory category,
    required DpdpPurpose purpose,
    DpdpGrantedTo? grantedTo,
  }) async {
    final key = '${category.name}_${purpose.name}';

    // Return cached if available
    if (state.consentCache.containsKey(key)) {
      return state.consentCache[key]!;
    }

    try {
      final result = await _apiService.checkConsent(
        userId: _userId,
        dataCategory: category,
        purpose: purpose,
        grantedTo: grantedTo,
      );

      // Cache result
      final newCache = Map<String, ConsentStatus>.from(state.consentCache);
      newCache[key] = result;
      state = state.copyWith(consentCache: newCache);

      return result;
    } catch (e) {
      return ConsentStatus(isValid: false, reason: e.toString());
    }
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for consent state notifier - requires user ID
final consentNotifierProvider =
    StateNotifierProvider.family<ConsentNotifier, ConsentState, String>(
  (ref, userId) {
    final apiService = ref.watch(dpdpApiServiceProvider);
    return ConsentNotifier(apiService, userId);
  },
);

/// State for user data operations
class UserDataState {
  final bool isLoading;
  final String? error;
  final UserDataExport? exportedData;
  final List<AuditLogEntry> auditLogs;

  const UserDataState({
    this.isLoading = false,
    this.error,
    this.exportedData,
    this.auditLogs = const [],
  });

  UserDataState copyWith({
    bool? isLoading,
    String? error,
    UserDataExport? exportedData,
    List<AuditLogEntry>? auditLogs,
  }) {
    return UserDataState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      exportedData: exportedData ?? this.exportedData,
      auditLogs: auditLogs ?? this.auditLogs,
    );
  }
}

/// User Data Notifier - manages user rights operations
class UserDataNotifier extends StateNotifier<UserDataState> {
  final DpdpApiService _apiService;
  final String _userId;

  UserDataNotifier(this._apiService, this._userId)
      : super(const UserDataState());

  /// Export all user data (Right to Access)
  Future<UserDataExport?> exportData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _apiService.exportMyData(_userId);
      state = state.copyWith(isLoading: false, exportedData: data);
      return data;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Delete all user data (Right to Erasure)
  Future<bool> deleteData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final success = await _apiService.deleteMyData(_userId);
      state = state.copyWith(isLoading: false);
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Request data correction (Right to Correction)
  Future<bool> requestCorrection({
    required String fieldName,
    required String currentValue,
    required String correctedValue,
    String? reason,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final success = await _apiService.requestDataCorrection(
        userId: _userId,
        fieldName: fieldName,
        currentValue: currentValue,
        correctedValue: correctedValue,
        reason: reason,
      );
      state = state.copyWith(isLoading: false);
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Load audit log
  Future<void> loadAuditLog({int limit = 100, String? actionFilter}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final logs = await _apiService.getMyAuditLog(
        _userId,
        limit: limit,
        actionFilter: actionFilter,
      );
      state = state.copyWith(isLoading: false, auditLogs: logs);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for user data notifier - requires user ID
final userDataNotifierProvider =
    StateNotifierProvider.family<UserDataNotifier, UserDataState, String>(
  (ref, userId) {
    final apiService = ref.watch(dpdpApiServiceProvider);
    return UserDataNotifier(apiService, userId);
  },
);

// ============================================================================
// CONVENIENCE PROVIDERS
// ============================================================================

/// Quick check if SOS consent is granted
final sosConsentProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  final notifier = ref.watch(consentNotifierProvider(userId).notifier);
  final result = await notifier.checkConsent(
    category: DpdpDataCategory.location,
    purpose: DpdpPurpose.emergency,
  );
  return result.isValid;
});

/// Quick check if Symptom Checker consent is granted
final symptomCheckerConsentProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  final notifier = ref.watch(consentNotifierProvider(userId).notifier);
  final result = await notifier.checkConsent(
    category: DpdpDataCategory.health,
    purpose: DpdpPurpose.aiProcessing,
  );
  return result.isValid;
});

/// Quick check if Mental Health consent is granted
final mentalHealthConsentProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  final notifier = ref.watch(consentNotifierProvider(userId).notifier);
  final result = await notifier.checkConsent(
    category: DpdpDataCategory.mentalHealth,
    purpose: DpdpPurpose.aiProcessing,
  );
  return result.isValid;
});

/// Quick check if Medicine Reminder consent is granted
final medicineConsentProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  final notifier = ref.watch(consentNotifierProvider(userId).notifier);
  final result = await notifier.checkConsent(
    category: DpdpDataCategory.medication,
    purpose: DpdpPurpose.storage,
  );
  return result.isValid;
});

/// Quick check if Health Records consent is granted
final healthRecordsConsentProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  final notifier = ref.watch(consentNotifierProvider(userId).notifier);
  final result = await notifier.checkConsent(
    category: DpdpDataCategory.healthRecords,
    purpose: DpdpPurpose.storage,
  );
  return result.isValid;
});
