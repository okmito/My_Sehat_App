import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../data/models/health_record_model.dart';
import '../providers/health_records_controller.dart';

class HealthRecordDetailScreen extends ConsumerStatefulWidget {
  final HealthRecordModel record;

  const HealthRecordDetailScreen({super.key, required this.record});

  @override
  ConsumerState<HealthRecordDetailScreen> createState() =>
      _HealthRecordDetailScreenState();
}

class _HealthRecordDetailScreenState
    extends ConsumerState<HealthRecordDetailScreen> {
  late HealthRecordModel _record;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
  }

  Future<void> _deleteRecord() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Record', style: GoogleFonts.outfit()),
        content: Text(
          'Are you sure you want to delete this health record? This action cannot be undone.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(healthRecordsControllerProvider.notifier)
          .deleteRecord(_record.id);

      if (success && mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMMM yyyy');

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _record.documentType.displayName,
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: (value) {
              if (value == 'delete') {
                _deleteRecord();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Text('Delete',
                        style: GoogleFonts.outfit(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
                children: [
                  // Type Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF64748B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getTypeIcon(_record.documentType),
                          color: const Color(0xFF64748B),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _record.documentType.displayName,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Diagnosis
                  if (_record.diagnosis != null)
                    Text(
                      _record.diagnosis!,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 8),
                  // Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        _record.documentDate != null
                            ? dateFormat.format(_record.documentDate!)
                            : dateFormat.format(_record.uploadDate),
                        style: GoogleFonts.outfit(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Status Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_record.isVerified)
                        _StatusChip(
                          icon: Icons.verified,
                          label: 'Verified',
                          color: Colors.green,
                        ),
                      if (_record.isEmergencyAccessible) ...[
                        const SizedBox(width: 8),
                        _StatusChip(
                          icon: Icons.emergency,
                          label: 'Emergency Access',
                          color: Colors.orange,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Doctor & Hospital Info
            if (_record.doctorName != null || _record.hospitalName != null)
              _DetailSection(
                title: 'Provider Information',
                children: [
                  if (_record.doctorName != null)
                    _DetailRow(
                      icon: Icons.person_outline,
                      label: 'Doctor',
                      value: _record.doctorName!,
                    ),
                  if (_record.hospitalName != null)
                    _DetailRow(
                      icon: Icons.local_hospital_outlined,
                      label: 'Hospital/Clinic',
                      value: _record.hospitalName!,
                    ),
                ],
              ),
            if (_record.doctorName != null || _record.hospitalName != null)
              const SizedBox(height: 16),

            // Medications
            if (_record.medications.isNotEmpty)
              _DetailSection(
                title: 'Medications',
                children: _record.medications.map((med) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.medication,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                med.name,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (med.dosage != null ||
                                  med.frequency != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  [med.dosage, med.frequency, med.duration]
                                      .whereType<String>()
                                      .join(' • '),
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                              if (med.instructions != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  med.instructions!,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            if (_record.medications.isNotEmpty) const SizedBox(height: 16),

            // Test Results
            if (_record.testResults.isNotEmpty)
              _DetailSection(
                title: 'Test Results',
                children: _record.testResults.map((test) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: test.isAbnormal
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.science,
                            color: test.isAbnormal
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                test.testName,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '${test.resultValue ?? ''} ${test.unit ?? ''}'
                                        .trim(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: test.isAbnormal
                                          ? Colors.red.shade700
                                          : Colors.green.shade700,
                                    ),
                                  ),
                                  if (test.referenceRange != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '(Ref: ${test.referenceRange})',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (test.isAbnormal)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'ABNORMAL',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            if (_record.testResults.isNotEmpty) const SizedBox(height: 16),

            // Notes
            if (_record.notes != null)
              _DetailSection(
                title: 'Notes',
                children: [
                  Text(
                    _record.notes!,
                    style: GoogleFonts.outfit(
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            if (_record.notes != null) const SizedBox(height: 16),

            // Metadata
            _DetailSection(
              title: 'Record Information',
              children: [
                _DetailRow(
                  icon: Icons.upload,
                  label: 'Uploaded',
                  value: dateFormat.format(_record.uploadDate),
                ),
                _DetailRow(
                  icon: Icons.percent,
                  label: 'Confidence Score',
                  value: '${(_record.confidenceScore * 100).toInt()}%',
                ),
                if (_record.purposeTag != null)
                  _DetailRow(
                    icon: Icons.label_outline,
                    label: 'Purpose',
                    value: _record.purposeTag!,
                  ),
                if (_record.storagePolicy != null)
                  _DetailRow(
                    icon: Icons.security,
                    label: 'Storage Policy',
                    value: _record.storagePolicy!,
                  ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(DocumentType type) {
    switch (type) {
      case DocumentType.prescription:
        return Icons.medication_rounded;
      case DocumentType.labReport:
        return Icons.science_rounded;
      case DocumentType.radiology:
        return Icons.medical_information_rounded;
      case DocumentType.dischargeSummary:
        return Icons.summarize_rounded;
      case DocumentType.medicalCertificate:
        return Icons.verified_rounded;
      case DocumentType.other:
        return Icons.description_rounded;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({
    required this.title,
    required this.children,
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
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
