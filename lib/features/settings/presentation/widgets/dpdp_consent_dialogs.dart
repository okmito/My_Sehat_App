import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../pages/my_data_privacy_screen.dart';

/// DPDP Consent Dialogs
///
/// These dialogs MUST be shown before:
/// - SOS: Sharing emergency location
/// - Symptom Checker: AI processing health data
/// - Mental Health: Storing conversation data
/// - Medicine: Medication reminders
/// - Health Records: Storing documents

// ============================================================================
// CONSENT DIALOG WIDGET
// ============================================================================

class DPDPConsentDialog extends ConsumerWidget {
  final DataCategory category;
  final ConsentPurpose purpose;
  final String featureName;
  final String explanation;
  final List<String> dataCollected;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const DPDPConsentDialog({
    super.key,
    required this.category,
    required this.purpose,
    required this.featureName,
    required this.explanation,
    required this.dataCollected,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Shield icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.privacy_tip,
                  size: 48,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Consent Required',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // DPDP Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'DPDP Act 2023 Compliant',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: Colors.blueGrey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Feature name
              Text(
                featureName,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              // Explanation
              Text(
                explanation,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Data collected section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data we will collect:',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...dataCollected.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item,
                                  style: GoogleFonts.outfit(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Purpose and rights
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Purpose: ${purpose.displayName}',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.refresh, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can revoke consent anytime in Settings > My Data & Privacy',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDecline,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Decline',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAccept,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Accept',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CONSENT CHECKER MIXIN
// ============================================================================

/// Mixin to check and request consent before feature access
mixin ConsentChecker {
  /// Check if consent is granted, show dialog if not
  Future<bool> checkAndRequestConsent({
    required BuildContext context,
    required WidgetRef ref,
    required DataCategory category,
    required ConsentPurpose purpose,
    required String featureName,
    required String explanation,
    required List<String> dataCollected,
  }) async {
    final manager = ref.read(consentManagerProvider.notifier);

    // Check if consent already granted
    if (manager.hasConsent(category, purpose)) {
      // Log the access
      await manager.logDataAccess(
        action: 'DATA_ACCESS',
        dataType: category.displayName,
        purpose: purpose.displayName,
        accessor: featureName,
      );
      return true;
    }

    // Show consent dialog
    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DPDPConsentDialog(
        category: category,
        purpose: purpose,
        featureName: featureName,
        explanation: explanation,
        dataCollected: dataCollected,
        onAccept: () {
          manager.grantConsent(category, purpose);
          Navigator.pop(context, true);
        },
        onDecline: () {
          Navigator.pop(context, false);
        },
      ),
    );

    if (granted == true) {
      await manager.logDataAccess(
        action: 'DATA_ACCESS',
        dataType: category.displayName,
        purpose: purpose.displayName,
        accessor: featureName,
      );
    }

    return granted ?? false;
  }
}

// ============================================================================
// FEATURE-SPECIFIC CONSENT HELPERS
// ============================================================================

class FeatureConsents {
  /// Check consent for SOS Emergency Feature
  static Future<bool> checkSOSConsent(
      BuildContext context, WidgetRef ref) async {
    final manager = ref.read(consentManagerProvider.notifier);

    if (manager.hasConsent(DataCategory.emergency, ConsentPurpose.emergency)) {
      return true;
    }

    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DPDPConsentDialog(
        category: DataCategory.emergency,
        purpose: ConsentPurpose.emergency,
        featureName: 'SOS Emergency',
        explanation:
            'In an emergency, MySehat needs to share your location and medical information with emergency services to help you.',
        dataCollected: [
          'Current GPS location',
          'Emergency contact details',
          'Medical conditions (if any)',
          'Blood type and allergies',
        ],
        onAccept: () {
          manager.grantConsent(
              DataCategory.emergency, ConsentPurpose.emergency);
          manager.grantConsent(DataCategory.location, ConsentPurpose.emergency);
          Navigator.pop(context, true);
        },
        onDecline: () {
          Navigator.pop(context, false);
        },
      ),
    );

    return granted ?? false;
  }

  /// Check consent for Symptom Checker AI Feature
  static Future<bool> checkSymptomCheckerConsent(
      BuildContext context, WidgetRef ref) async {
    final manager = ref.read(consentManagerProvider.notifier);

    if (manager.hasConsent(
        DataCategory.diagnostics, ConsentPurpose.aiProcessing)) {
      return true;
    }

    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DPDPConsentDialog(
        category: DataCategory.diagnostics,
        purpose: ConsentPurpose.aiProcessing,
        featureName: 'AI Symptom Checker',
        explanation:
            'Our AI will analyze your symptoms to provide health guidance. Your data is processed securely and NOT used to train AI models.',
        dataCollected: [
          'Symptoms you describe',
          'Medical history (optional)',
          'Images you upload (optional)',
          'Chat conversation history',
        ],
        onAccept: () {
          manager.grantConsent(
              DataCategory.diagnostics, ConsentPurpose.aiProcessing);
          manager.grantConsent(
              DataCategory.diagnostics, ConsentPurpose.storage);
          Navigator.pop(context, true);
        },
        onDecline: () {
          Navigator.pop(context, false);
        },
      ),
    );

    return granted ?? false;
  }

  /// Check consent for Mental Health Feature
  static Future<bool> checkMentalHealthConsent(
      BuildContext context, WidgetRef ref) async {
    final manager = ref.read(consentManagerProvider.notifier);

    if (manager.hasConsent(
        DataCategory.mentalHealth, ConsentPurpose.aiProcessing)) {
      return true;
    }

    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MentalHealthConsentDialog(),
    );

    return granted ?? false;
  }

  /// Check consent for Medicine Reminders
  static Future<bool> checkMedicineConsent(
      BuildContext context, WidgetRef ref) async {
    final manager = ref.read(consentManagerProvider.notifier);

    if (manager.hasConsent(DataCategory.medications, ConsentPurpose.reminder)) {
      return true;
    }

    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DPDPConsentDialog(
        category: DataCategory.medications,
        purpose: ConsentPurpose.reminder,
        featureName: 'Medicine Reminders',
        explanation:
            'MySehat will store your medication schedule locally to send you timely reminders.',
        dataCollected: [
          'Medication names',
          'Dosage information',
          'Schedule and times',
          'Reminder preferences',
        ],
        onAccept: () {
          manager.grantConsent(
              DataCategory.medications, ConsentPurpose.reminder);
          manager.grantConsent(
              DataCategory.medications, ConsentPurpose.storage);
          Navigator.pop(context, true);
        },
        onDecline: () {
          Navigator.pop(context, false);
        },
      ),
    );

    return granted ?? false;
  }

  /// Check consent for Health Records Storage
  static Future<bool> checkHealthRecordsConsent(
      BuildContext context, WidgetRef ref) async {
    final manager = ref.read(consentManagerProvider.notifier);

    if (manager.hasConsent(
        DataCategory.healthRecords, ConsentPurpose.storage)) {
      return true;
    }

    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DPDPConsentDialog(
        category: DataCategory.healthRecords,
        purpose: ConsentPurpose.storage,
        featureName: 'Health Records',
        explanation:
            'MySehat will securely store your health documents. You can delete them anytime.',
        dataCollected: [
          'Uploaded medical documents',
          'Lab reports and prescriptions',
          'Document metadata',
          'Organization tags',
        ],
        onAccept: () {
          manager.grantConsent(
              DataCategory.healthRecords, ConsentPurpose.storage);
          manager.grantConsent(DataCategory.documents, ConsentPurpose.storage);
          Navigator.pop(context, true);
        },
        onDecline: () {
          Navigator.pop(context, false);
        },
      ),
    );

    return granted ?? false;
  }
}

// ============================================================================
// MENTAL HEALTH CONSENT (SPECIAL HANDLING)
// ============================================================================

class _MentalHealthConsentDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MentalHealthConsentDialog> createState() =>
      _MentalHealthConsentDialogState();
}

class _MentalHealthConsentDialogState
    extends ConsumerState<_MentalHealthConsentDialog> {
  bool _saveConversations = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.psychology,
                  size: 48,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Mental Health Support',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Sensitivity notice
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber,
                        size: 14, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Sensitive Data',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Explanation
              Text(
                'Your mental health conversations are highly sensitive. We give you full control over what is stored.',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Storage option
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Save conversation history',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        _saveConversations
                            ? 'Conversations will be saved for continuity'
                            : 'Conversations will be deleted after session',
                        style: GoogleFonts.outfit(fontSize: 11),
                      ),
                      value: _saveConversations,
                      onChanged: (value) {
                        setState(() => _saveConversations = value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // AI Notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.smart_toy,
                        size: 20, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AI will process your messages to provide support. Data is NOT used for training.',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Decline',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final manager =
                            ref.read(consentManagerProvider.notifier);
                        manager.grantConsent(DataCategory.mentalHealth,
                            ConsentPurpose.aiProcessing);
                        if (_saveConversations) {
                          manager.grantConsent(DataCategory.mentalHealth,
                              ConsentPurpose.storage);
                        }
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Continue',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CONSENT BLOCKED SCREEN
// ============================================================================

class ConsentBlockedScreen extends StatelessWidget {
  final String featureName;
  final String message;
  final VoidCallback onGoToSettings;

  const ConsentBlockedScreen({
    super.key,
    required this.featureName,
    required this.message,
    required this.onGoToSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Blocked icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block,
                  size: 64,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Feature Blocked',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Message
              Text(
                '$featureName requires your consent to operate.',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // DPDP Notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blueGrey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.gavel, color: Colors.blueGrey.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'MySehat enforces DPDP Act 2023 compliance. We cannot process your data without explicit consent.',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.blueGrey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onGoToSettings,
                  icon: const Icon(Icons.settings),
                  label: Text(
                    'Grant Consent in Settings',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Go Back',
                  style: GoogleFonts.outfit(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
