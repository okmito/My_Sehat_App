import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/health_record_model.dart';
import '../providers/health_records_controller.dart';

class ScanDocumentScreen extends ConsumerStatefulWidget {
  final File file;

  const ScanDocumentScreen({super.key, required this.file});

  @override
  ConsumerState<ScanDocumentScreen> createState() => _ScanDocumentScreenState();
}

class _ScanDocumentScreenState extends ConsumerState<ScanDocumentScreen> {
  DocumentType _selectedType = DocumentType.prescription;
  StorageType _storageType = StorageType.permanent;
  final _doctorController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();
  final _patientNameController = TextEditingController();
  DateTime? _documentDate;
  bool _consentGiven = false;
  bool _shareInEmergency = true;
  bool _hasAnalyzed = false;

  @override
  void initState() {
    super.initState();
    // Start analysis immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analyzeDocument();
    });
  }

  @override
  void dispose() {
    _doctorController.dispose();
    _hospitalController.dispose();
    _diagnosisController.dispose();
    _notesController.dispose();
    _patientNameController.dispose();
    super.dispose();
  }

  Future<void> _analyzeDocument() async {
    final result = await ref
        .read(healthRecordsControllerProvider.notifier)
        .analyzeDocument(widget.file);

    if (result != null && mounted) {
      setState(() {
        _hasAnalyzed = true;
        _selectedType = DocumentType.fromApiValue(result.documentType);
        if (result.doctor != null) _doctorController.text = result.doctor!;
        if (result.hospital != null) {
          _hospitalController.text = result.hospital!;
        }
        if (result.diagnosis != null) {
          _diagnosisController.text = result.diagnosis!;
        }
        if (result.notes != null) _notesController.text = result.notes!;
        if (result.patientName != null) {
          _patientNameController.text = result.patientName!;
        }
        if (result.date != null) {
          _documentDate = DateTime.tryParse(result.date!);
        }
        // Auto-enable emergency sharing if critical info found
        if (result.hasEmergencyCriticalInfo) {
          _shareInEmergency = true;
        }
      });
    }
  }

  Future<void> _saveRecord() async {
    // Handle view-only mode
    if (_storageType == StorageType.doNotStore) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Document viewed. No data was saved.'),
          backgroundColor: Colors.blue.shade600,
        ),
      );
      Navigator.pop(context);
      return;
    }

    if (!_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide consent to save your health record'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final analysis = ref.read(healthRecordsControllerProvider).analysisResult;

    final record = await ref
        .read(healthRecordsControllerProvider.notifier)
        .saveRecord(
          file: widget.file,
          documentType: _selectedType,
          documentDate: _documentDate?.toIso8601String(),
          doctorName:
              _doctorController.text.isEmpty ? null : _doctorController.text,
          hospitalName: _hospitalController.text.isEmpty
              ? null
              : _hospitalController.text,
          patientName: _patientNameController.text.isEmpty
              ? null
              : _patientNameController.text,
          diagnosis: _diagnosisController.text.isEmpty
              ? null
              : _diagnosisController.text,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          storageType: _storageType,
          shareInEmergency: _shareInEmergency,
          criticalInfo: analysis?.criticalInfo,
        );

    if (record != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Health record saved successfully!'),
          backgroundColor: Colors.green.shade600,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _documentDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _documentDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(healthRecordsControllerProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () {
            ref.read(healthRecordsControllerProvider.notifier).clearAnalysis();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Scan Document',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: state.isAnalyzing ? _buildAnalyzingState() : _buildFormState(state),
    );
  }

  Widget _buildAnalyzingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Analyzing Document...',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI is extracting medical information',
                  style: GoogleFonts.outfit(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfPreview() {
    final fileName = widget.file.path.split('/').last.split('\\').last;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.picture_as_pdf_rounded,
              size: 64,
              color: Colors.red.shade400,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            fileName,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'PDF Document',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormState(HealthRecordsState state) {
    final analysis = state.analysisResult;
    final isPdf = widget.file.path.toLowerCase().endsWith('.pdf');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document Preview
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: isPdf
                ? _buildPdfPreview()
                : Image.file(
                    widget.file,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildPdfPreview();
                    },
                  ),
          ),
          const SizedBox(height: 16),

          // AI Disclaimer
          if (_hasAnalyzed && analysis != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.amber.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Extracted Information',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        Text(
                          'Please verify and correct if needed',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(analysis.overallConfidence * 100).toInt()}%',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Emergency Critical Info Section
          if (analysis != null && analysis.hasEmergencyCriticalInfo)
            _buildEmergencyCriticalInfo(analysis),

          // Patient Info Section
          if (analysis != null && analysis.patientName != null)
            _buildPatientInfoSection(analysis),

          // Document Type Selection
          _SectionCard(
            title: 'Document Type',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DocumentType.values.map((type) {
                final isSelected = _selectedType == type;
                return ChoiceChip(
                  label: Text(type.displayName),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedType = type);
                  },
                  selectedColor: const Color(0xFF64748B),
                  labelStyle: GoogleFonts.outfit(
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Document Details
          _SectionCard(
            title: 'Document Details',
            child: Column(
              children: [
                // Date
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    _documentDate != null
                        ? '${_documentDate!.day}/${_documentDate!.month}/${_documentDate!.year}'
                        : 'Select Date',
                    style: GoogleFonts.outfit(),
                  ),
                  trailing: TextButton(
                    onPressed: _selectDate,
                    child: const Text('Change'),
                  ),
                ),
                const Divider(),
                // Doctor
                TextField(
                  controller: _doctorController,
                  decoration: InputDecoration(
                    labelText: 'Doctor Name',
                    labelStyle: GoogleFonts.outfit(),
                    prefixIcon: const Icon(Icons.person_outline),
                    border: InputBorder.none,
                  ),
                ),
                const Divider(),
                // Hospital
                TextField(
                  controller: _hospitalController,
                  decoration: InputDecoration(
                    labelText: 'Hospital/Clinic',
                    labelStyle: GoogleFonts.outfit(),
                    prefixIcon: const Icon(Icons.local_hospital_outlined),
                    border: InputBorder.none,
                  ),
                ),
                const Divider(),
                // Diagnosis
                TextField(
                  controller: _diagnosisController,
                  decoration: InputDecoration(
                    labelText: 'Diagnosis/Condition',
                    labelStyle: GoogleFonts.outfit(),
                    prefixIcon: const Icon(Icons.medical_information_outlined),
                    border: InputBorder.none,
                  ),
                ),
                const Divider(),
                // Notes
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Additional Notes',
                    labelStyle: GoogleFonts.outfit(),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 48),
                      child: Icon(Icons.notes_outlined),
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Extracted Medications
          if (analysis != null && analysis.medications.isNotEmpty)
            _SectionCard(
              title: 'Extracted Medications',
              child: Column(
                children: analysis.medications.map((med) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.medication,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    title: Text(med.name, style: GoogleFonts.outfit()),
                    subtitle: Text(
                      [med.dosage, med.frequency, med.duration]
                          .whereType<String>()
                          .join(' • '),
                      style: GoogleFonts.outfit(fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
            ),
          if (analysis != null && analysis.medications.isNotEmpty)
            const SizedBox(height: 16),

          // Extracted Test Results
          if (analysis != null && analysis.testResults.isNotEmpty)
            _SectionCard(
              title: 'Extracted Test Results',
              child: Column(
                children: analysis.testResults.map((test) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: test.isAbnormal
                            ? Colors.red.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.science,
                        color: test.isAbnormal
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                    title: Text(test.testName, style: GoogleFonts.outfit()),
                    subtitle: Text(
                      '${test.resultValue ?? ''} ${test.unit ?? ''}'.trim(),
                      style: GoogleFonts.outfit(fontSize: 12),
                    ),
                    trailing: test.isAbnormal
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Abnormal',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : null,
                  );
                }).toList(),
              ),
            ),
          if (analysis != null && analysis.testResults.isNotEmpty)
            const SizedBox(height: 16),

          // Consent Section
          _SectionCard(
            title: 'Storage & Consent',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Storage Type Options
                Text(
                  'How would you like to store this?',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ...StorageType.values.map((type) {
                  final isSelected = _storageType == type;
                  return RadioListTile<StorageType>(
                    contentPadding: EdgeInsets.zero,
                    value: type,
                    groupValue: _storageType,
                    onChanged: (value) {
                      setState(() {
                        _storageType = value ?? StorageType.permanent;
                        if (_storageType != StorageType.doNotStore) {
                          _consentGiven = true;
                        }
                      });
                    },
                    title: Text(
                      type.displayName,
                      style: GoogleFonts.outfit(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      type.description,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    activeColor: const Color(0xFF64748B),
                  );
                }),
                const Divider(height: 24),
                // Emergency Sharing Toggle
                if (analysis != null && analysis.hasEmergencyCriticalInfo)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _shareInEmergency,
                    onChanged: (value) {
                      setState(() => _shareInEmergency = value);
                    },
                    title: Row(
                      children: [
                        Icon(
                          Icons.emergency,
                          size: 20,
                          color: Colors.red.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Share in emergencies',
                            style: GoogleFonts.outfit(),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      'Blood group & allergies accessible to emergency responders',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    activeTrackColor:
                        const Color(0xFF64748B).withValues(alpha: 0.5),
                    thumbColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const Color(0xFF64748B);
                      }
                      return null;
                    }),
                  ),
                if (_storageType != StorageType.doNotStore)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _consentGiven,
                    onChanged: (value) {
                      setState(() => _consentGiven = value ?? false);
                    },
                    title: Text(
                      'I consent to store this health record',
                      style: GoogleFonts.outfit(),
                    ),
                    subtitle: Text(
                      'Your data is encrypted and DPDP-compliant',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    activeColor: const Color(0xFF64748B),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: state.isSaving ? null : _saveRecord,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF64748B),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: state.isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Save Health Record',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildEmergencyCriticalInfo(DocumentAnalysisResult analysis) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade50, Colors.red.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.emergency,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency-Critical Info Found',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                    Text(
                      'This info can be shared with emergency responders',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Blood Group
          if (analysis.bloodGroup != null)
            _buildCriticalInfoChip(
              icon: Icons.bloodtype,
              label: 'Blood Group',
              value: analysis.bloodGroup!,
              color: Colors.red,
            ),
          // Allergies
          ...analysis.allergies.map((allergy) => _buildCriticalInfoChip(
                icon: Icons.warning_amber_rounded,
                label: 'Allergy',
                value: allergy.value,
                color: Colors.orange,
                severity: allergy.severity,
              )),
          // Chronic Conditions
          ...analysis.chronicConditions
              .map((condition) => _buildCriticalInfoChip(
                    icon: Icons.medical_information,
                    label: 'Chronic Condition',
                    value: condition.value,
                    color: Colors.blue,
                  )),
        ],
      ),
    );
  }

  Widget _buildCriticalInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required MaterialColor color,
    String? severity,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color.shade600, size: 20),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: color.shade800,
              ),
            ),
          ),
          if (severity != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: severity.toLowerCase() == 'severe'
                    ? Colors.red.shade100
                    : severity.toLowerCase() == 'moderate'
                        ? Colors.orange.shade100
                        : Colors.yellow.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                severity,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: severity.toLowerCase() == 'severe'
                      ? Colors.red.shade700
                      : severity.toLowerCase() == 'moderate'
                          ? Colors.orange.shade700
                          : Colors.yellow.shade800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPatientInfoSection(DocumentAnalysisResult analysis) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.person,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patient Name',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.blue.shade600,
                  ),
                ),
                Text(
                  analysis.patientName ?? 'Not found',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: Colors.blue.shade600),
            onPressed: () {
              // Allow editing patient name
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Edit Patient Name'),
                  content: TextField(
                    controller: _patientNameController,
                    decoration: const InputDecoration(
                      labelText: 'Patient Name',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
