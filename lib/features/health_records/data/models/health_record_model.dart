/// Document types supported by the health record system
enum DocumentType {
  prescription,
  labReport,
  radiology,
  dischargeSummary,
  medicalCertificate,
  other;

  String get displayName {
    switch (this) {
      case DocumentType.prescription:
        return 'Prescription';
      case DocumentType.labReport:
        return 'Lab Report';
      case DocumentType.radiology:
        return 'Radiology';
      case DocumentType.dischargeSummary:
        return 'Discharge Summary';
      case DocumentType.medicalCertificate:
        return 'Medical Certificate';
      case DocumentType.other:
        return 'Other';
    }
  }

  String get apiValue {
    switch (this) {
      case DocumentType.prescription:
        return 'prescription';
      case DocumentType.labReport:
        return 'lab_report';
      case DocumentType.radiology:
        return 'radiology';
      case DocumentType.dischargeSummary:
        return 'discharge_summary';
      case DocumentType.medicalCertificate:
        return 'medical_certificate';
      case DocumentType.other:
        return 'other';
    }
  }

  static DocumentType fromApiValue(String value) {
    switch (value.toLowerCase()) {
      case 'prescription':
        return DocumentType.prescription;
      case 'lab_report':
        return DocumentType.labReport;
      case 'radiology':
        return DocumentType.radiology;
      case 'discharge_summary':
        return DocumentType.dischargeSummary;
      case 'medical_certificate':
        return DocumentType.medicalCertificate;
      default:
        return DocumentType.other;
    }
  }
}

/// Storage type for health records
enum StorageType {
  permanent,
  temporary,
  doNotStore;

  String get apiValue {
    switch (this) {
      case StorageType.permanent:
        return 'permanent';
      case StorageType.temporary:
        return 'temporary';
      case StorageType.doNotStore:
        return 'do_not_store';
    }
  }

  String get displayName {
    switch (this) {
      case StorageType.permanent:
        return 'Save permanently';
      case StorageType.temporary:
        return 'Save for 90 days';
      case StorageType.doNotStore:
        return 'View only (don\'t save)';
    }
  }

  String get description {
    switch (this) {
      case StorageType.permanent:
        return 'Stored securely until you delete it';
      case StorageType.temporary:
        return 'Auto-deleted after 90 days';
      case StorageType.doNotStore:
        return 'Extracted info shown now, not saved';
    }
  }
}

/// Critical info types
enum CriticalInfoType {
  bloodGroup,
  allergy,
  chronicCondition;

  String get apiValue {
    switch (this) {
      case CriticalInfoType.bloodGroup:
        return 'blood_group';
      case CriticalInfoType.allergy:
        return 'allergy';
      case CriticalInfoType.chronicCondition:
        return 'chronic_condition';
    }
  }

  String get displayName {
    switch (this) {
      case CriticalInfoType.bloodGroup:
        return 'Blood Group';
      case CriticalInfoType.allergy:
        return 'Allergy';
      case CriticalInfoType.chronicCondition:
        return 'Chronic Condition';
    }
  }

  static CriticalInfoType fromApiValue(String value) {
    switch (value.toLowerCase()) {
      case 'blood_group':
        return CriticalInfoType.bloodGroup;
      case 'allergy':
        return CriticalInfoType.allergy;
      case 'chronic_condition':
        return CriticalInfoType.chronicCondition;
      default:
        return CriticalInfoType.chronicCondition;
    }
  }
}

/// Critical health information model
class CriticalInfoModel {
  final int? id;
  final CriticalInfoType infoType;
  final String value;
  final String? severity;
  final bool shareInEmergency;

  const CriticalInfoModel({
    this.id,
    required this.infoType,
    required this.value,
    this.severity,
    this.shareInEmergency = true,
  });

  factory CriticalInfoModel.fromJson(Map<String, dynamic> json) {
    return CriticalInfoModel(
      id: json['id'] as int?,
      infoType:
          CriticalInfoType.fromApiValue(json['info_type']?.toString() ?? ''),
      value: json['value']?.toString() ?? '',
      severity: json['severity']?.toString(),
      shareInEmergency: json['share_in_emergency'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'info_type': infoType.apiValue,
      'value': value,
      'severity': severity,
      'share_in_emergency': shareInEmergency,
    };
  }

  bool get isEmergencyCritical =>
      infoType == CriticalInfoType.bloodGroup ||
      infoType == CriticalInfoType.allergy;
}

/// Medication model
class MedicationModel {
  final int? id;
  final String name;
  final String? dosage;
  final String? frequency;
  final String? duration;
  final String? instructions;
  final double confidence;
  final bool isVerified;

  const MedicationModel({
    this.id,
    required this.name,
    this.dosage,
    this.frequency,
    this.duration,
    this.instructions,
    this.confidence = 0.0,
    this.isVerified = false,
  });

  factory MedicationModel.fromJson(Map<String, dynamic> json) {
    return MedicationModel(
      id: json['id'] as int?,
      name: json['name']?.toString() ?? '',
      dosage: json['dosage']?.toString(),
      frequency: json['frequency']?.toString(),
      duration: json['duration']?.toString(),
      instructions: json['instructions']?.toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'instructions': instructions,
      'confidence': confidence,
      'is_verified': isVerified,
    };
  }
}

/// Test result model
class TestResultModel {
  final int? id;
  final String testName;
  final String? resultValue;
  final String? unit;
  final String? referenceRange;
  final bool isAbnormal;
  final double confidence;
  final bool isVerified;

  const TestResultModel({
    this.id,
    required this.testName,
    this.resultValue,
    this.unit,
    this.referenceRange,
    this.isAbnormal = false,
    this.confidence = 0.0,
    this.isVerified = false,
  });

  factory TestResultModel.fromJson(Map<String, dynamic> json) {
    return TestResultModel(
      id: json['id'] as int?,
      testName: json['test_name']?.toString() ?? '',
      resultValue: json['result_value']?.toString(),
      unit: json['unit']?.toString(),
      referenceRange: json['reference_range']?.toString(),
      isAbnormal: json['is_abnormal'] as bool? ?? false,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'test_name': testName,
      'result_value': resultValue,
      'unit': unit,
      'reference_range': referenceRange,
      'is_abnormal': isAbnormal,
      'confidence': confidence,
      'is_verified': isVerified,
    };
  }
}

/// Health record model
class HealthRecordModel {
  final int id;
  final String userId;
  final DocumentType documentType;
  final DateTime? documentDate;
  final DateTime uploadDate;
  final String? doctorName;
  final String? hospitalName;
  final String? patientName;
  final String? diagnosis;
  final String? notes;
  final double confidenceScore;
  final bool isVerified;
  final bool isEmergencyAccessible;
  final String? purposeTag;
  final String? storagePolicy;
  final List<MedicationModel> medications;
  final List<TestResultModel> testResults;

  const HealthRecordModel({
    required this.id,
    required this.userId,
    required this.documentType,
    this.documentDate,
    required this.uploadDate,
    this.doctorName,
    this.hospitalName,
    this.patientName,
    this.diagnosis,
    this.notes,
    this.confidenceScore = 0.0,
    this.isVerified = false,
    this.isEmergencyAccessible = false,
    this.purposeTag,
    this.storagePolicy,
    this.medications = const [],
    this.testResults = const [],
  });

  factory HealthRecordModel.fromJson(Map<String, dynamic> json) {
    return HealthRecordModel(
      id: (json['id'] as num).toInt(),
      userId: json['user_id']?.toString() ?? '',
      documentType: DocumentType.fromApiValue(
          json['document_type']?.toString() ?? 'other'),
      documentDate: json['document_date'] != null
          ? DateTime.tryParse(json['document_date'].toString())
          : null,
      uploadDate: DateTime.tryParse(json['upload_date']?.toString() ?? '') ??
          DateTime.now(),
      doctorName: json['doctor_name']?.toString(),
      hospitalName: json['hospital_name']?.toString(),
      patientName: json['patient_name']?.toString(),
      diagnosis: json['diagnosis']?.toString(),
      notes: json['notes']?.toString(),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      isVerified: json['is_verified'] as bool? ?? false,
      isEmergencyAccessible: json['is_emergency_accessible'] as bool? ?? false,
      purposeTag: json['purpose_tag']?.toString(),
      storagePolicy: json['storage_policy']?.toString(),
      medications: (json['medications'] as List<dynamic>?)
              ?.map((e) => MedicationModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      testResults: (json['test_results'] as List<dynamic>?)
              ?.map((e) => TestResultModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'document_type': documentType.apiValue,
      'document_date': documentDate?.toIso8601String(),
      'upload_date': uploadDate.toIso8601String(),
      'doctor_name': doctorName,
      'hospital_name': hospitalName,
      'patient_name': patientName,
      'diagnosis': diagnosis,
      'notes': notes,
      'confidence_score': confidenceScore,
      'is_verified': isVerified,
      'is_emergency_accessible': isEmergencyAccessible,
      'purpose_tag': purposeTag,
      'storage_policy': storagePolicy,
      'medications': medications.map((e) => e.toJson()).toList(),
      'test_results': testResults.map((e) => e.toJson()).toList(),
    };
  }
}

/// Document analysis result
class DocumentAnalysisResult {
  final String documentType;
  final String? date;
  final String? doctor;
  final String? hospital;
  final String? patientName;
  final String? diagnosis;
  final List<MedicationModel> medications;
  final List<TestResultModel> testResults;
  final List<CriticalInfoModel> criticalInfo;
  final String? notes;
  final double overallConfidence;
  final List<String> lowConfidenceFields;
  final String purposeTag;
  final String storagePolicy;
  final String aiDisclaimer;

  const DocumentAnalysisResult({
    required this.documentType,
    this.date,
    this.doctor,
    this.hospital,
    this.patientName,
    this.diagnosis,
    this.medications = const [],
    this.testResults = const [],
    this.criticalInfo = const [],
    this.notes,
    this.overallConfidence = 0.0,
    this.lowConfidenceFields = const [],
    this.purposeTag = 'Personal Health Record',
    this.storagePolicy = 'Encrypted | User-owned | DPDP-compliant',
    this.aiDisclaimer =
        'This information is extracted from uploaded documents. It is not a medical diagnosis and should be verified by a professional.',
  });

  factory DocumentAnalysisResult.fromJson(Map<String, dynamic> json) {
    return DocumentAnalysisResult(
      documentType: json['document_type']?.toString() ?? 'other',
      date: json['date']?.toString(),
      doctor: json['doctor']?.toString(),
      hospital: json['hospital']?.toString(),
      patientName: json['patient_name']?.toString(),
      diagnosis: json['diagnosis']?.toString(),
      medications: (json['medications'] as List<dynamic>?)
              ?.map((e) => MedicationModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      testResults: (json['test_results'] as List<dynamic>?)
              ?.map((e) => TestResultModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      criticalInfo: (json['critical_info'] as List<dynamic>?)
              ?.map(
                  (e) => CriticalInfoModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes']?.toString(),
      overallConfidence:
          (json['overall_confidence'] as num?)?.toDouble() ?? 0.0,
      lowConfidenceFields: (json['low_confidence_fields'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      purposeTag: json['purpose_tag']?.toString() ?? 'Personal Health Record',
      storagePolicy: json['storage_policy']?.toString() ??
          'Encrypted | User-owned | DPDP-compliant',
      aiDisclaimer: json['ai_disclaimer']?.toString() ?? '',
    );
  }

  /// Get blood group if extracted
  String? get bloodGroup {
    try {
      return criticalInfo
          .firstWhere((info) => info.infoType == CriticalInfoType.bloodGroup)
          .value;
    } catch (_) {
      return null;
    }
  }

  /// Get list of allergies
  List<CriticalInfoModel> get allergies => criticalInfo
      .where((info) => info.infoType == CriticalInfoType.allergy)
      .toList();

  /// Get list of chronic conditions
  List<CriticalInfoModel> get chronicConditions => criticalInfo
      .where((info) => info.infoType == CriticalInfoType.chronicCondition)
      .toList();

  /// Check if any emergency-critical info was found
  bool get hasEmergencyCriticalInfo =>
      bloodGroup != null || allergies.isNotEmpty;
}

/// Timeline entry model
class TimelineEntryModel {
  final int id;
  final DateTime date;
  final DocumentType documentType;
  final String title;
  final String? doctorName;
  final String? hospitalName;

  const TimelineEntryModel({
    required this.id,
    required this.date,
    required this.documentType,
    required this.title,
    this.doctorName,
    this.hospitalName,
  });

  factory TimelineEntryModel.fromJson(Map<String, dynamic> json) {
    return TimelineEntryModel(
      id: (json['id'] as num).toInt(),
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      documentType: DocumentType.fromApiValue(
          json['document_type']?.toString() ?? 'other'),
      title: json['title']?.toString() ?? '',
      doctorName: json['doctor_name']?.toString(),
      hospitalName: json['hospital_name']?.toString(),
    );
  }
}
