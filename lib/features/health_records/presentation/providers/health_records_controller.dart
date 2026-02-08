import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/health_record_remote_data_source.dart';
import '../../data/models/health_record_model.dart';

/// State for the health records feature
class HealthRecordsState {
  final bool isLoading;
  final bool isAnalyzing;
  final bool isSaving;
  final List<HealthRecordModel> records;
  final List<TimelineEntryModel> timelineEntries;
  final DocumentAnalysisResult? analysisResult;
  final HealthRecordModel? selectedRecord;
  final String? errorMessage;

  const HealthRecordsState({
    this.isLoading = false,
    this.isAnalyzing = false,
    this.isSaving = false,
    this.records = const [],
    this.timelineEntries = const [],
    this.analysisResult,
    this.selectedRecord,
    this.errorMessage,
  });

  HealthRecordsState copyWith({
    bool? isLoading,
    bool? isAnalyzing,
    bool? isSaving,
    List<HealthRecordModel>? records,
    List<TimelineEntryModel>? timelineEntries,
    DocumentAnalysisResult? analysisResult,
    HealthRecordModel? selectedRecord,
    String? errorMessage,
  }) {
    return HealthRecordsState(
      isLoading: isLoading ?? this.isLoading,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      isSaving: isSaving ?? this.isSaving,
      records: records ?? this.records,
      timelineEntries: timelineEntries ?? this.timelineEntries,
      analysisResult: analysisResult ?? this.analysisResult,
      selectedRecord: selectedRecord ?? this.selectedRecord,
      errorMessage: errorMessage,
    );
  }

  HealthRecordsState clearAnalysis() {
    return HealthRecordsState(
      isLoading: isLoading,
      isAnalyzing: false,
      isSaving: false,
      records: records,
      timelineEntries: timelineEntries,
      analysisResult: null,
      selectedRecord: selectedRecord,
      errorMessage: null,
    );
  }
}

/// Controller for health records operations
class HealthRecordsController extends StateNotifier<HealthRecordsState> {
  HealthRecordsController(this._ref, this._remote)
      : super(const HealthRecordsState());

  final Ref _ref;
  final HealthRecordRemoteDataSource _remote;

  String get _userId {
    final user = _ref.read(authStateProvider).value;
    return user?.id ?? user?.phoneNumber ?? 'guest-user';
  }

  /// Load all health records
  Future<void> loadRecords() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final records = await _remote.getHealthRecords(userId: _userId);

      state = state.copyWith(
        isLoading: false,
        records: records,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Load timeline view
  Future<void> loadTimeline() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final entries = await _remote.getTimeline(userId: _userId);

      state = state.copyWith(
        isLoading: false,
        timelineEntries: entries,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Analyze a document
  Future<DocumentAnalysisResult?> analyzeDocument(File file) async {
    try {
      state = state.copyWith(isAnalyzing: true, errorMessage: null);

      final result = await _remote.analyzeDocument(
        file: file,
        userId: _userId,
      );

      state = state.copyWith(
        isAnalyzing: false,
        analysisResult: result,
      );

      return result;
    } catch (e) {
      state = state.copyWith(
        isAnalyzing: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Save a health record
  Future<HealthRecordModel?> saveRecord({
    required File file,
    required DocumentType documentType,
    String? documentDate,
    String? doctorName,
    String? hospitalName,
    String? patientName,
    String? diagnosis,
    String? notes,
    StorageType storageType = StorageType.permanent,
    bool shareInEmergency = true,
    List<CriticalInfoModel>? criticalInfo,
  }) async {
    try {
      state = state.copyWith(isSaving: true, errorMessage: null);

      final record = await _remote.saveHealthRecord(
        file: file,
        userId: _userId,
        documentType: documentType,
        documentDate: documentDate,
        doctorName: doctorName,
        hospitalName: hospitalName,
        patientName: patientName,
        diagnosis: diagnosis,
        notes: notes,
        storageType: storageType,
        consentGiven: true,
        shareInEmergency: shareInEmergency,
        criticalInfo: criticalInfo,
      );

      // Add to records list
      state = state.copyWith(
        isSaving: false,
        records: [record, ...state.records],
      );

      return record;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Get a specific record
  Future<HealthRecordModel?> getRecord(int recordId) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final record = await _remote.getHealthRecord(
        recordId: recordId,
        userId: _userId,
      );

      state = state.copyWith(
        isLoading: false,
        selectedRecord: record,
      );

      return record;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Delete a health record
  Future<bool> deleteRecord(int recordId) async {
    try {
      await _remote.deleteHealthRecord(
        recordId: recordId,
        userId: _userId,
      );

      // Remove from local state
      state = state.copyWith(
        records: state.records.where((r) => r.id != recordId).toList(),
        timelineEntries:
            state.timelineEntries.where((e) => e.id != recordId).toList(),
      );

      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  /// Toggle emergency access for a record
  Future<bool> toggleEmergencyAccess(int recordId, bool accessible) async {
    try {
      await _remote.setEmergencyAccess(
        recordId: recordId,
        userId: _userId,
        accessible: accessible,
      );

      // Reload the record
      await getRecord(recordId);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  /// Clear analysis result
  void clearAnalysis() {
    state = state.clearAnalysis();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final healthRecordsControllerProvider =
    StateNotifierProvider<HealthRecordsController, HealthRecordsState>((ref) {
  return HealthRecordsController(
    ref,
    ref.watch(healthRecordRemoteDataSourceProvider),
  );
});
