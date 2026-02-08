import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../data/models/health_record_model.dart';
import '../providers/health_records_controller.dart';
import 'scan_document_screen.dart';
import 'health_record_detail_screen.dart';
import '../../../settings/presentation/widgets/dpdp_consent_dialogs.dart';

class HealthRecordsScreen extends ConsumerStatefulWidget {
  const HealthRecordsScreen({super.key});

  @override
  ConsumerState<HealthRecordsScreen> createState() =>
      _HealthRecordsScreenState();
}

class _HealthRecordsScreenState extends ConsumerState<HealthRecordsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load records on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(healthRecordsControllerProvider.notifier).loadRecords();
      ref.read(healthRecordsControllerProvider.notifier).loadTimeline();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _scanDocument() async {
    // DPDP Compliance: Check consent before storing health documents
    final hasConsent =
        await FeatureConsents.checkHealthRecordsConsent(context, ref);
    if (!hasConsent) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Health Records requires consent for document storage',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Scan Document',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ScanOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                  _ScanOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                  _ScanOption(
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'PDF',
                    onTap: () => _pickPdf(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context); // Close bottom sheet

    final XFile? pickedFile = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
    );

    if (pickedFile != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScanDocumentScreen(file: File(pickedFile.path)),
        ),
      );
    }
  }

  Future<void> _pickPdf() async {
    Navigator.pop(context); // Close bottom sheet

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty && mounted) {
      final file = File(result.files.first.path!);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScanDocumentScreen(file: file),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(healthRecordsControllerProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Health Records',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              // TODO: Implement search
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.black),
            onPressed: () {
              _showInfoDialog();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF64748B),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF64748B),
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.outfit(),
          tabs: const [
            Tab(text: 'All Records'),
            Tab(text: 'Timeline'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Information is extracted from uploaded documents. Not a medical diagnosis.',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // All Records Tab
                _buildRecordsTab(state),
                // Timeline Tab
                _buildTimelineTab(state),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanDocument,
        backgroundColor: const Color(0xFF64748B),
        icon: const Icon(Icons.document_scanner_rounded),
        label: Text(
          'Scan Document',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildRecordsTab(HealthRecordsState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.records.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(healthRecordsControllerProvider.notifier).loadRecords(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: state.records.length,
        itemBuilder: (context, index) {
          final record = state.records[index];
          return _RecordCard(
            record: record,
            onTap: () => _openRecordDetail(record),
          );
        },
      ),
    );
  }

  Widget _buildTimelineTab(HealthRecordsState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.timelineEntries.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(healthRecordsControllerProvider.notifier).loadTimeline(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: state.timelineEntries.length,
        itemBuilder: (context, index) {
          final entry = state.timelineEntries[index];
          final isFirst = index == 0;
          final isLast = index == state.timelineEntries.length - 1;

          return _TimelineCard(
            entry: entry,
            isFirst: isFirst,
            isLast: isLast,
            onTap: () async {
              final record = await ref
                  .read(healthRecordsControllerProvider.notifier)
                  .getRecord(entry.id);
              if (record != null && mounted) {
                _openRecordDetail(record);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF64748B).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: 64,
                color: const Color(0xFF64748B).withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Health Records Yet',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan your prescriptions, lab reports, and other\nmedical documents to digitalize your health records.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _scanDocument,
              icon: const Icon(Icons.document_scanner_rounded),
              label: Text(
                'Scan Your First Document',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                side: const BorderSide(color: Color(0xFF64748B)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openRecordDetail(HealthRecordModel record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HealthRecordDetailScreen(record: record),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.security, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text('Privacy & Security', style: GoogleFonts.outfit()),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoItem(
              icon: Icons.lock,
              text: 'Your data is encrypted end-to-end',
            ),
            const SizedBox(height: 12),
            _InfoItem(
              icon: Icons.person,
              text: 'You own and control your health data',
            ),
            const SizedBox(height: 12),
            _InfoItem(
              icon: Icons.verified_user,
              text: 'DPDP-compliant storage',
            ),
            const SizedBox(height: 12),
            _InfoItem(
              icon: Icons.emergency,
              text: 'Emergency responders see only critical info',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
  }
}

class _ScanOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ScanOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: const Color(0xFF64748B)),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final HealthRecordModel record;
  final VoidCallback onTap;

  const _RecordCard({
    required this.record,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getTypeColor(record.documentType)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getTypeIcon(record.documentType),
                    color: _getTypeColor(record.documentType),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.documentType.displayName,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (record.diagnosis != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          record.diagnosis!,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            record.documentDate != null
                                ? dateFormat.format(record.documentDate!)
                                : dateFormat.format(record.uploadDate),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          if (record.isVerified) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.verified,
                                size: 14, color: Colors.green.shade600),
                            const SizedBox(width: 2),
                            Text(
                              'Verified',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: Colors.green.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(DocumentType type) {
    switch (type) {
      case DocumentType.prescription:
        return Colors.blue;
      case DocumentType.labReport:
        return Colors.purple;
      case DocumentType.radiology:
        return Colors.orange;
      case DocumentType.dischargeSummary:
        return Colors.red;
      case DocumentType.medicalCertificate:
        return Colors.green;
      case DocumentType.other:
        return Colors.grey;
    }
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

class _TimelineCard extends StatelessWidget {
  final TimelineEntryModel entry;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _TimelineCard({
    required this.entry,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM');
    final yearFormat = DateFormat('yyyy');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline line
          SizedBox(
            width: 60,
            child: Column(
              children: [
                Text(
                  dateFormat.format(entry.date),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  yearFormat.format(entry.date),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF64748B),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0xFF64748B).withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          // Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                elevation: 1,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF64748B)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                entry.documentType.displayName,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.title,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (entry.doctorName != null ||
                            entry.hospitalName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            [entry.doctorName, entry.hospitalName]
                                .whereType<String>()
                                .join(' • '),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blue.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
