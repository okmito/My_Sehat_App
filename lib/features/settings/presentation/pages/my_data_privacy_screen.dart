import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../widgets/hospital_fhir_consent_widget.dart';

/// DPDP Act 2023 Compliance - My Data & Privacy Screen
///
/// Implements user rights:
/// - Right to Access (view all stored data)
/// - Right to Portability (download data)
/// - Right to Erasure (delete data)
/// - Consent Management (grant/revoke consents)
/// - Audit Trail (view access history)

// ============================================================================
// CONSENT MODELS
// ============================================================================

enum DataCategory {
  location('Location Data', Icons.location_on),
  mentalHealth('Mental Health', Icons.psychology),
  documents('Health Documents', Icons.description),
  medications('Medications', Icons.medication),
  diagnostics('Symptom Data', Icons.medical_services),
  emergency('Emergency Data', Icons.emergency),
  healthRecords('Health Records', Icons.folder_shared),
  personalInfo('Personal Info', Icons.person);

  final String displayName;
  final IconData icon;
  const DataCategory(this.displayName, this.icon);
}

enum ConsentPurpose {
  emergency('Emergency Use', 'Share critical data in emergencies'),
  treatment('Treatment', 'Use for medical treatment'),
  storage('Storage', 'Store health records'),
  aiProcessing('AI Processing', 'Allow AI-powered analysis'),
  reminder('Reminders', 'Send medication reminders'),
  analytics('Analytics', 'Personal health analytics');

  final String displayName;
  final String description;
  const ConsentPurpose(this.displayName, this.description);
}

class ConsentRecord {
  final String id;
  final DataCategory category;
  final ConsentPurpose purpose;
  final bool isGranted;
  final DateTime? grantedAt;
  final DateTime? revokedAt;

  ConsentRecord({
    required this.id,
    required this.category,
    required this.purpose,
    required this.isGranted,
    this.grantedAt,
    this.revokedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'purpose': purpose.name,
        'isGranted': isGranted,
        'grantedAt': grantedAt?.toIso8601String(),
        'revokedAt': revokedAt?.toIso8601String(),
      };

  factory ConsentRecord.fromJson(Map<String, dynamic> json) => ConsentRecord(
        id: json['id'],
        category:
            DataCategory.values.firstWhere((e) => e.name == json['category']),
        purpose:
            ConsentPurpose.values.firstWhere((e) => e.name == json['purpose']),
        isGranted: json['isGranted'],
        grantedAt: json['grantedAt'] != null
            ? DateTime.parse(json['grantedAt'])
            : null,
        revokedAt: json['revokedAt'] != null
            ? DateTime.parse(json['revokedAt'])
            : null,
      );
}

class AuditLogEntry {
  final String id;
  final String action;
  final String dataType;
  final String purpose;
  final DateTime timestamp;
  final String accessor;
  final bool success;

  AuditLogEntry({
    required this.id,
    required this.action,
    required this.dataType,
    required this.purpose,
    required this.timestamp,
    required this.accessor,
    this.success = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'action': action,
        'dataType': dataType,
        'purpose': purpose,
        'timestamp': timestamp.toIso8601String(),
        'accessor': accessor,
        'success': success,
      };

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
        id: json['id'],
        action: json['action'],
        dataType: json['dataType'],
        purpose: json['purpose'],
        timestamp: DateTime.parse(json['timestamp']),
        accessor: json['accessor'],
        success: json['success'] ?? true,
      );
}

// ============================================================================
// CONSENT MANAGER PROVIDER
// ============================================================================

class ConsentManagerState {
  final Map<String, ConsentRecord> consents;
  final List<AuditLogEntry> auditLogs;
  final bool isLoading;
  final String? error;

  ConsentManagerState({
    this.consents = const {},
    this.auditLogs = const [],
    this.isLoading = false,
    this.error,
  });

  ConsentManagerState copyWith({
    Map<String, ConsentRecord>? consents,
    List<AuditLogEntry>? auditLogs,
    bool? isLoading,
    String? error,
  }) {
    return ConsentManagerState(
      consents: consents ?? this.consents,
      auditLogs: auditLogs ?? this.auditLogs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ConsentManager extends StateNotifier<ConsentManagerState> {
  ConsentManager() : super(ConsentManagerState()) {
    _loadConsents();
  }

  static const _consentsKey = 'dpdp_consents';
  static const _auditKey = 'dpdp_audit_logs';

  Future<void> _loadConsents() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load consents
      final consentsJson = prefs.getString(_consentsKey);
      Map<String, ConsentRecord> consents = {};
      if (consentsJson != null) {
        final decoded = jsonDecode(consentsJson) as Map<String, dynamic>;
        consents = decoded
            .map((key, value) => MapEntry(key, ConsentRecord.fromJson(value)));
      } else {
        // Initialize default consents (all denied by default - DPDP compliant)
        consents = _initializeDefaultConsents();
        await _saveConsents(consents);
      }

      // Load audit logs
      final auditJson = prefs.getString(_auditKey);
      List<AuditLogEntry> auditLogs = [];
      if (auditJson != null) {
        final decoded = jsonDecode(auditJson) as List;
        auditLogs = decoded.map((e) => AuditLogEntry.fromJson(e)).toList();
      }

      state = state.copyWith(
        consents: consents,
        auditLogs: auditLogs,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Map<String, ConsentRecord> _initializeDefaultConsents() {
    final consents = <String, ConsentRecord>{};

    // DPDP Requirement: All consents start as DENIED
    for (final category in DataCategory.values) {
      for (final purpose in ConsentPurpose.values) {
        // Skip irrelevant combinations
        if (_isValidConsentCombination(category, purpose)) {
          final id = '${category.name}_${purpose.name}';
          consents[id] = ConsentRecord(
            id: id,
            category: category,
            purpose: purpose,
            isGranted: false, // DEFAULT: NO CONSENT
          );
        }
      }
    }
    return consents;
  }

  bool _isValidConsentCombination(
      DataCategory category, ConsentPurpose purpose) {
    // Define valid combinations
    switch (category) {
      case DataCategory.emergency:
        return purpose == ConsentPurpose.emergency;
      case DataCategory.mentalHealth:
        return [ConsentPurpose.aiProcessing, ConsentPurpose.storage]
            .contains(purpose);
      case DataCategory.medications:
        return [ConsentPurpose.reminder, ConsentPurpose.storage]
            .contains(purpose);
      case DataCategory.diagnostics:
        return [ConsentPurpose.aiProcessing, ConsentPurpose.storage]
            .contains(purpose);
      case DataCategory.healthRecords:
      case DataCategory.documents:
        return [ConsentPurpose.storage, ConsentPurpose.emergency]
            .contains(purpose);
      case DataCategory.location:
        return purpose == ConsentPurpose.emergency;
      case DataCategory.personalInfo:
        return [ConsentPurpose.storage, ConsentPurpose.emergency]
            .contains(purpose);
    }
  }

  Future<void> _saveConsents(Map<String, ConsentRecord> consents) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(consents.map((k, v) => MapEntry(k, v.toJson())));
    await prefs.setString(_consentsKey, json);
  }

  Future<void> _saveAuditLogs(List<AuditLogEntry> logs) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(logs.map((e) => e.toJson()).toList());
    await prefs.setString(_auditKey, json);
  }

  /// Grant consent for a specific category and purpose
  Future<void> grantConsent(
      DataCategory category, ConsentPurpose purpose) async {
    final id = '${category.name}_${purpose.name}';
    final newConsent = ConsentRecord(
      id: id,
      category: category,
      purpose: purpose,
      isGranted: true,
      grantedAt: DateTime.now(),
    );

    final newConsents = Map<String, ConsentRecord>.from(state.consents);
    newConsents[id] = newConsent;

    // Log the consent grant
    await _logAction(
        'CONSENT_GRANTED', category.displayName, purpose.displayName);

    await _saveConsents(newConsents);
    state = state.copyWith(consents: newConsents);
  }

  /// Revoke consent for a specific category and purpose
  Future<void> revokeConsent(
      DataCategory category, ConsentPurpose purpose) async {
    final id = '${category.name}_${purpose.name}';
    final existingConsent = state.consents[id];

    final newConsent = ConsentRecord(
      id: id,
      category: category,
      purpose: purpose,
      isGranted: false,
      grantedAt: existingConsent?.grantedAt,
      revokedAt: DateTime.now(),
    );

    final newConsents = Map<String, ConsentRecord>.from(state.consents);
    newConsents[id] = newConsent;

    // Log the consent revocation
    await _logAction(
        'CONSENT_REVOKED', category.displayName, purpose.displayName);

    await _saveConsents(newConsents);
    state = state.copyWith(consents: newConsents);
  }

  /// Check if consent is granted
  bool hasConsent(DataCategory category, ConsentPurpose purpose) {
    final id = '${category.name}_${purpose.name}';
    return state.consents[id]?.isGranted ?? false;
  }

  /// Log an action to audit trail
  Future<void> _logAction(
      String action, String dataType, String purpose) async {
    final entry = AuditLogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      action: action,
      dataType: dataType,
      purpose: purpose,
      timestamp: DateTime.now(),
      accessor: 'User',
    );

    final newLogs =
        [entry, ...state.auditLogs].take(100).toList(); // Keep last 100
    await _saveAuditLogs(newLogs);
    state = state.copyWith(auditLogs: newLogs);
  }

  /// Log data access (called by other features)
  Future<void> logDataAccess({
    required String action,
    required String dataType,
    required String purpose,
    required String accessor,
    bool success = true,
  }) async {
    final entry = AuditLogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      action: action,
      dataType: dataType,
      purpose: purpose,
      timestamp: DateTime.now(),
      accessor: accessor,
      success: success,
    );

    final newLogs = [entry, ...state.auditLogs].take(100).toList();
    await _saveAuditLogs(newLogs);
    state = state.copyWith(auditLogs: newLogs);
  }

  /// Export all user data (Right to Portability)
  Future<Map<String, dynamic>> exportAllData() async {
    await _logAction('DATA_EXPORT', 'All Data', 'User Request');

    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();

    final exportData = <String, dynamic>{
      'export_date': DateTime.now().toIso8601String(),
      'dpdp_act_compliance': 'Right to Access & Portability',
      'consents': state.consents.map((k, v) => MapEntry(k, v.toJson())),
      'audit_logs': state.auditLogs.map((e) => e.toJson()).toList(),
      'stored_data': {},
    };

    // Collect all stored data (excluding system keys)
    for (final key in allKeys) {
      if (!key.startsWith('flutter.')) {
        exportData['stored_data'][key] = prefs.get(key);
      }
    }

    return exportData;
  }

  /// Delete all user data (Right to Erasure)
  Future<void> deleteAllData() async {
    await _logAction('DATA_ERASURE', 'All Data', 'User Request');

    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys().toList();

    for (final key in allKeys) {
      if (!key.startsWith('flutter.')) {
        await prefs.remove(key);
      }
    }

    // Reset to default state with no consents
    state = ConsentManagerState(
      consents: _initializeDefaultConsents(),
      auditLogs: [],
    );
    await _saveConsents(state.consents);
  }
}

final consentManagerProvider =
    StateNotifierProvider<ConsentManager, ConsentManagerState>((ref) {
  return ConsentManager();
});

// ============================================================================
// MY DATA & PRIVACY SCREEN
// ============================================================================

class MyDataPrivacyScreen extends ConsumerStatefulWidget {
  const MyDataPrivacyScreen({super.key});

  @override
  ConsumerState<MyDataPrivacyScreen> createState() =>
      _MyDataPrivacyScreenState();
}

class _MyDataPrivacyScreenState extends ConsumerState<MyDataPrivacyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(consentManagerProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "My Data & Privacy",
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          isScrollable: true,
          tabs: const [
            Tab(text: "Consents"),
            Tab(text: "Hospital"),
            Tab(text: "My Data"),
            Tab(text: "Audit Log"),
            Tab(text: "Rights"),
          ],
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _ConsentsTab(state: state),
                const HospitalFhirConsentWidget(),
                _MyDataTab(state: state),
                _AuditLogTab(state: state),
                _RightsTab(),
              ],
            ),
    );
  }
}

// ============================================================================
// CONSENTS TAB
// ============================================================================

class _ConsentsTab extends ConsumerWidget {
  final ConsentManagerState state;
  const _ConsentsTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Group consents by category
    final consentsByCategory = <DataCategory, List<ConsentRecord>>{};
    for (final consent in state.consents.values) {
      consentsByCategory.putIfAbsent(consent.category, () => []).add(consent);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // DPDP Compliance Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueGrey.shade400, Colors.blueGrey.shade600],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user, color: Colors.white, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "DPDP Act 2023 Compliant",
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "Your data, your control. Manage all consents here.",
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Consent Categories
        ...consentsByCategory.entries.map((entry) => _ConsentCategoryCard(
              category: entry.key,
              consents: entry.value,
            )),
      ],
    );
  }
}

class _ConsentCategoryCard extends ConsumerWidget {
  final DataCategory category;
  final List<ConsentRecord> consents;

  const _ConsentCategoryCard({
    required this.category,
    required this.consents,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(category.icon, color: Theme.of(context).primaryColor),
          ),
          title: Text(
            category.displayName,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${consents.where((c) => c.isGranted).length}/${consents.length} consents granted',
            style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
          ),
          children: consents
              .map((consent) => _ConsentTile(consent: consent))
              .toList(),
        ),
      ),
    );
  }
}

class _ConsentTile extends ConsumerWidget {
  final ConsentRecord consent;
  const _ConsentTile({required this.consent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  consent.purpose.displayName,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                ),
                Text(
                  consent.purpose.description,
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                ),
                if (consent.isGranted && consent.grantedAt != null)
                  Text(
                    'Granted: ${DateFormat.yMMMd().format(consent.grantedAt!)}',
                    style:
                        GoogleFonts.outfit(fontSize: 10, color: Colors.green),
                  ),
              ],
            ),
          ),
          Switch(
            value: consent.isGranted,
            activeColor: Theme.of(context).primaryColor,
            onChanged: (value) async {
              final confirmed =
                  await _showConsentDialog(context, consent, value);
              if (confirmed) {
                if (value) {
                  await ref
                      .read(consentManagerProvider.notifier)
                      .grantConsent(consent.category, consent.purpose);
                } else {
                  await ref
                      .read(consentManagerProvider.notifier)
                      .revokeConsent(consent.category, consent.purpose);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<bool> _showConsentDialog(
      BuildContext context, ConsentRecord consent, bool granting) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              granting ? 'Grant Consent?' : 'Revoke Consent?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  granting
                      ? 'You are granting permission to:'
                      : 'You are revoking permission to:',
                  style: GoogleFonts.outfit(),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data: ${consent.category.displayName}',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Purpose: ${consent.purpose.displayName}',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  granting
                      ? '✅ You can revoke this consent at any time.'
                      : '⚠️ Revoking consent will immediately stop data access for this purpose.',
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      granting ? Theme.of(context).primaryColor : Colors.red,
                ),
                child: Text(granting ? 'Grant' : 'Revoke'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

// ============================================================================
// MY DATA TAB
// ============================================================================

class _MyDataTab extends ConsumerWidget {
  final ConsentManagerState state;
  const _MyDataTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Under DPDP Act 2023, you have the right to access, download, and delete your personal data at any time.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // View My Data
        _DataActionCard(
          icon: Icons.visibility_outlined,
          iconColor: Colors.blue,
          title: 'View My Data',
          subtitle: 'See all data stored by MySehat',
          onTap: () => _showDataViewer(context, ref),
        ),

        // Download My Data
        _DataActionCard(
          icon: Icons.download_outlined,
          iconColor: Colors.green,
          title: 'Download My Data',
          subtitle: 'Export all your data in JSON format',
          onTap: () => _downloadData(context, ref),
        ),

        // Delete My Data
        _DataActionCard(
          icon: Icons.delete_forever_outlined,
          iconColor: Colors.red,
          title: 'Delete My Data',
          subtitle: 'Permanently erase all your data',
          onTap: () => _deleteData(context, ref),
        ),

        const SizedBox(height: 24),

        // Data Summary
        Text(
          'Data Summary',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        _DataSummaryItem(
          label: 'Active Consents',
          value: '${state.consents.values.where((c) => c.isGranted).length}',
          icon: Icons.check_circle,
          color: Colors.green,
        ),
        _DataSummaryItem(
          label: 'Audit Log Entries',
          value: '${state.auditLogs.length}',
          icon: Icons.history,
          color: Colors.blue,
        ),
      ],
    );
  }

  void _showDataViewer(BuildContext context, WidgetRef ref) async {
    final data =
        await ref.read(consentManagerProvider.notifier).exportAllData();

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'Your Stored Data',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(data),
                    style: GoogleFonts.firaCode(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _downloadData(BuildContext context, WidgetRef ref) async {
    // Export data for download (in production, this would save to file)
    await ref.read(consentManagerProvider.notifier).exportAllData();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Data exported! In production, this would download a file.',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // For demo: show the data
      _showDataViewer(context, ref);
    }
  }

  void _deleteData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '⚠️ Delete All Data?',
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, color: Colors.red),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This action will permanently delete:',
              style: GoogleFonts.outfit(),
            ),
            const SizedBox(height: 12),
            _DeletionItem('All health records'),
            _DeletionItem('All medication data'),
            _DeletionItem('All mental health conversations'),
            _DeletionItem('All diagnostic history'),
            _DeletionItem('All consent records'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'This cannot be undone!',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(consentManagerProvider.notifier).deleteAllData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ All your data has been deleted.',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _DeletionItem extends StatelessWidget {
  final String text;
  const _DeletionItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.remove_circle, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Text(text, style: GoogleFonts.outfit(fontSize: 13)),
        ],
      ),
    );
  }
}

class _DataActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DataActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class _DataSummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _DataSummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.outfit()),
          const Spacer(),
          Text(
            value,
            style:
                GoogleFonts.outfit(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// AUDIT LOG TAB
// ============================================================================

class _AuditLogTab extends StatelessWidget {
  final ConsentManagerState state;
  const _AuditLogTab({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.auditLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No audit logs yet',
              style: GoogleFonts.outfit(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'All data access will be logged here',
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.shield, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data Access History',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Every data access is logged for accountability',
                      style:
                          GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Logs
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.auditLogs.length,
            itemBuilder: (context, index) {
              final log = state.auditLogs[index];
              return _AuditLogCard(log: log);
            },
          ),
        ),
      ],
    );
  }
}

class _AuditLogCard extends StatelessWidget {
  final AuditLogEntry log;
  const _AuditLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (log.action) {
      case 'CONSENT_GRANTED':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'CONSENT_REVOKED':
        icon = Icons.cancel;
        color = Colors.orange;
        break;
      case 'DATA_EXPORT':
        icon = Icons.download;
        color = Colors.blue;
        break;
      case 'DATA_ERASURE':
        icon = Icons.delete_forever;
        color = Colors.red;
        break;
      case 'DATA_ACCESS':
        icon = Icons.visibility;
        color = Colors.purple;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.action.replaceAll('_', ' '),
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  '${log.dataType} • ${log.purpose}',
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  DateFormat.yMMMd().add_Hm().format(log.timestamp),
                  style: GoogleFonts.outfit(
                      fontSize: 10, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          Icon(
            log.success ? Icons.check : Icons.error,
            color: log.success ? Colors.green : Colors.red,
            size: 16,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// RIGHTS TAB
// ============================================================================

class _RightsTab extends StatelessWidget {
  const _RightsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // DPDP Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade400, Colors.indigo.shade700],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Icon(Icons.gavel, color: Colors.white, size: 48),
              const SizedBox(height: 12),
              Text(
                'Your Rights Under DPDP Act 2023',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Digital Personal Data Protection Act',
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _RightCard(
          icon: Icons.visibility,
          title: 'Right to Access',
          description: 'You can view all personal data we hold about you.',
          implemented: true,
        ),
        _RightCard(
          icon: Icons.download,
          title: 'Right to Portability',
          description: 'You can download all your data in a portable format.',
          implemented: true,
        ),
        _RightCard(
          icon: Icons.edit,
          title: 'Right to Correction',
          description: 'You can request correction of inaccurate data.',
          implemented: true,
        ),
        _RightCard(
          icon: Icons.delete_forever,
          title: 'Right to Erasure',
          description: 'You can request deletion of all your personal data.',
          implemented: true,
        ),
        _RightCard(
          icon: Icons.block,
          title: 'Right to Withdraw Consent',
          description:
              'You can revoke consent at any time with immediate effect.',
          implemented: true,
        ),
        _RightCard(
          icon: Icons.gavel,
          title: 'Right to Grievance Redressal',
          description: 'You can lodge complaints about data processing.',
          implemented: true,
        ),

        const SizedBox(height: 24),

        // Compliance Statement
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              const Icon(Icons.verified, color: Colors.green, size: 32),
              const SizedBox(height: 8),
              Text(
                'MySehat enforces DPDP compliance at runtime — not on paper.',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'If consent is missing, the system refuses to operate.',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.green.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool implemented;

  const _RightCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.implemented,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                Text(
                  description,
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Icon(
            implemented ? Icons.check_circle : Icons.pending,
            color: implemented ? Colors.green : Colors.orange,
          ),
        ],
      ),
    );
  }
}
