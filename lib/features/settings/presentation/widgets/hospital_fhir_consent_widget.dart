// Hospital FHIR Consent Widget
// Part of DPDP-compliant data sharing for HL7 FHIR R4
//
// Allows patients to:
// - Grant time-limited consent to hospitals for FHIR data access
// - View all active hospital consents
// - Instantly revoke any consent (will fail hospital's next FHIR request)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../services/dpdp/fhir_consent_service.dart';

// Hardcoded demo user ID - in production, get from auth provider
const _demoUserId = 'USER_001';

class HospitalFhirConsentWidget extends ConsumerStatefulWidget {
  const HospitalFhirConsentWidget({super.key});

  @override
  ConsumerState<HospitalFhirConsentWidget> createState() =>
      _HospitalFhirConsentWidgetState();
}

class _HospitalFhirConsentWidgetState
    extends ConsumerState<HospitalFhirConsentWidget> {
  @override
  Widget build(BuildContext context) {
    final consentState = ref.watch(fhirConsentProvider(_demoUserId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          _buildHeaderCard(context),
          const SizedBox(height: 16),

          // Grant New Consent Button
          _buildGrantConsentCard(context),
          const SizedBox(height: 24),

          // Active Consents Section
          Text(
            'Active Hospital Consents',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          if (consentState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (consentState.activeConsents.isEmpty)
            _buildNoConsentsCard(context)
          else
            ...consentState.activeConsents
                .map((consent) => _buildConsentCard(context, consent)),

          // Revoked/Expired Consents
          if (consentState.hospitalConsents
              .where((c) => !c.isValidAccess)
              .isNotEmpty) ...[
            const SizedBox(height: 24),
            ExpansionTile(
              title: Text(
                'Revoked/Expired Consents',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              children: consentState.hospitalConsents
                  .where((c) => !c.isValidAccess)
                  .map((consent) => _buildRevokedConsentCard(context, consent))
                  .toList(),
            ),
          ],

          // Revoke All Button
          if (consentState.activeConsents.isNotEmpty) ...[
            const SizedBox(height: 32),
            _buildRevokeAllButton(context),
          ],

          // Error Display
          if (consentState.error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      consentState.error!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      ref
                          .read(fhirConsentProvider(_demoUserId).notifier)
                          .clearError();
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.1),
            Theme.of(context).primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.local_hospital,
              color: Theme.of(context).primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HL7 FHIR R4 Hospital Sharing',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Control which hospitals can access your health data via FHIR.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrantConsentCard(BuildContext context) {
    return InkWell(
      onTap: () => _showGrantConsentDialog(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.add_circle_outline, color: Colors.green[700]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Share With New Hospital',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[800],
                    ),
                  ),
                  Text(
                    'Grant time-limited FHIR access',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.green[700]),
          ],
        ),
      ),
    );
  }

  Widget _buildNoConsentsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.shield_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No Active Hospital Access',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your health data is currently not shared with any hospital via FHIR.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentCard(BuildContext context, HospitalFhirConsent consent) {
    final expiresIn = consent.expiresAt?.difference(DateTime.now());
    final isExpiringSoon = expiresIn != null &&
        expiresIn.inHours < 24 &&
        expiresIn.isNegative == false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpiringSoon ? Colors.orange[300]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.local_hospital,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      consent.hospitalName,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'ID: ${consent.hospitalId}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(consent),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Granted Resources
          Text(
            'Accessible FHIR Resources:',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: consent.grantedResources
                .map((r) => _buildResourceChip(r))
                .toList(),
          ),

          const SizedBox(height: 12),

          // Time Info
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                'Granted: ${DateFormat.yMMMd().add_jm().format(consent.grantedAt)}',
                style:
                    GoogleFonts.outfit(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          if (consent.expiresAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: isExpiringSoon ? Colors.orange[700] : Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  'Expires: ${DateFormat.yMMMd().add_jm().format(consent.expiresAt!)}',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color:
                        isExpiringSoon ? Colors.orange[700] : Colors.grey[500],
                    fontWeight:
                        isExpiringSoon ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Revoke Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmRevoke(context, consent),
              icon: const Icon(Icons.block, size: 18),
              label: const Text('Revoke Access'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[700],
                side: BorderSide(color: Colors.red[300]!),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevokedConsentCard(
      BuildContext context, HospitalFhirConsent consent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.local_hospital, color: Colors.grey[400], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  consent.hospitalName,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.grey[600],
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                Text(
                  consent.isExpired
                      ? 'Expired: ${consent.expiresAt != null ? DateFormat.yMMMd().format(consent.expiresAt!) : "N/A"}'
                      : 'Revoked: ${consent.revokedAt ?? "Unknown"}',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              consent.isExpired ? 'EXPIRED' : 'REVOKED',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(HospitalFhirConsent consent) {
    Color bgColor;
    Color textColor;
    String text;

    if (consent.sosEventId != null) {
      bgColor = Colors.red[100]!;
      textColor = Colors.red[800]!;
      text = 'SOS';
    } else if (consent.expiresAt != null) {
      bgColor = Colors.blue[100]!;
      textColor = Colors.blue[800]!;
      text = 'TIME-LIMITED';
    } else {
      bgColor = Colors.green[100]!;
      textColor = Colors.green[800]!;
      text = 'ACTIVE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildResourceChip(FhirResourceCategory resource) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Text(
        resource.displayName,
        style: GoogleFonts.outfit(
          fontSize: 11,
          color: Colors.blue[800],
        ),
      ),
    );
  }

  Widget _buildRevokeAllButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Emergency: Revoke All Access',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Instantly revoke FHIR access from all hospitals. This action takes effect immediately.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _confirmRevokeAll(context),
              icon: const Icon(Icons.block),
              label: const Text('Revoke All Hospital Access'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // DIALOGS
  // ============================================================================

  void _showGrantConsentDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _GrantConsentSheet(),
    );
  }

  void _confirmRevoke(BuildContext context, HospitalFhirConsent consent) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Access?'),
        content: Text(
          'This will immediately revoke "${consent.hospitalName}"\'s access to your FHIR data. '
          'Their next data request will fail with a 403 Forbidden error.\n\n'
          'You can grant access again at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(fhirConsentProvider(_demoUserId).notifier)
                  .revokeHospitalConsent(consent.hospitalId);
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Access revoked for ${consent.hospitalName}'),
                  backgroundColor: Colors.red[700],
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }

  void _confirmRevokeAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[700]),
            const SizedBox(width: 8),
            const Text('Revoke All Access?'),
          ],
        ),
        content: const Text(
          'This will immediately revoke FHIR access from ALL hospitals. '
          'Any pending data requests will fail.\n\n'
          'This action cannot be undone, but you can grant access again individually.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(fhirConsentProvider(_demoUserId).notifier)
                  .revokeAllConsents();
              HapticFeedback.heavyImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('All hospital access revoked'),
                  backgroundColor: Colors.red[700],
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Revoke All'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// GRANT CONSENT BOTTOM SHEET
// ============================================================================

class _GrantConsentSheet extends ConsumerStatefulWidget {
  const _GrantConsentSheet();

  @override
  ConsumerState<_GrantConsentSheet> createState() => _GrantConsentSheetState();
}

class _GrantConsentSheetState extends ConsumerState<_GrantConsentSheet> {
  final _hospitalIdController = TextEditingController();
  final _hospitalNameController = TextEditingController();
  final Set<FhirResourceCategory> _selectedResources = {};
  Duration? _expiryDuration;
  bool _isGranting = false;

  // Demo hospitals
  final _demoHospitals = [
    {'id': 'APOLLO_MUMBAI_001', 'name': 'Apollo Hospitals, Mumbai'},
    {'id': 'FORTIS_DELHI_001', 'name': 'Fortis Hospital, Delhi'},
    {'id': 'MAX_NOIDA_001', 'name': 'Max Super Specialty, Noida'},
    {'id': 'AIIMS_DELHI_001', 'name': 'AIIMS New Delhi'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Share Data with Hospital',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Grant FHIR R4 access with explicit DPDP consent',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),

                // Hospital Selection
                Text(
                  'Select Hospital',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _demoHospitals.map((h) {
                    final isSelected = _hospitalIdController.text == h['id'];
                    return ChoiceChip(
                      label: Text(h['name']!),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _hospitalIdController.text = h['id']!;
                          _hospitalNameController.text = h['name']!;
                        });
                      },
                      selectedColor:
                          Theme.of(context).primaryColor.withOpacity(0.2),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Resource Selection
                Text(
                  'Select FHIR Resources to Share',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...FhirResourceCategory.values.map((resource) {
                  return CheckboxListTile(
                    title: Text(resource.displayName),
                    subtitle: Text('FHIR: ${resource.fhirResource}'),
                    value: _selectedResources.contains(resource),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedResources.add(resource);
                        } else {
                          _selectedResources.remove(resource);
                        }
                      });
                    },
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }),
                const SizedBox(height: 24),

                // Expiry Duration
                Text(
                  'Access Duration',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildDurationChip('24 Hours', const Duration(hours: 24)),
                    _buildDurationChip('7 Days', const Duration(days: 7)),
                    _buildDurationChip('30 Days', const Duration(days: 30)),
                    _buildDurationChip('Unlimited', null),
                  ],
                ),
                const SizedBox(height: 32),

                // DPDP Notice
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.amber[800], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'By granting consent, you authorize the hospital to access your data via FHIR R4 API under DPDP Act 2023. You can revoke this consent at any time.',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.amber[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Grant Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _canGrant ? () => _grantConsent() : null,
                    icon: _isGranting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.verified_user),
                    label:
                        Text(_isGranting ? 'Granting...' : 'Grant FHIR Access'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  bool get _canGrant =>
      _hospitalIdController.text.isNotEmpty &&
      _selectedResources.isNotEmpty &&
      !_isGranting;

  Widget _buildDurationChip(String label, Duration? duration) {
    final isSelected = _expiryDuration == duration;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _expiryDuration = duration);
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
    );
  }

  Future<void> _grantConsent() async {
    setState(() => _isGranting = true);

    final success = await ref
        .read(fhirConsentProvider(_demoUserId).notifier)
        .grantHospitalConsent(
          hospitalId: _hospitalIdController.text,
          hospitalName: _hospitalNameController.text,
          resources: _selectedResources.toList(),
          expiresAfter: _expiryDuration,
        );

    setState(() => _isGranting = false);

    if (success && mounted) {
      Navigator.pop(context);
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'FHIR access granted to ${_hospitalNameController.text}',
          ),
          backgroundColor: Colors.green[700],
        ),
      );
    }
  }
}
