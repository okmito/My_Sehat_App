import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../services/auth_api_service.dart';
import '../providers/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // Form controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  // Preferences
  String _language = 'en';
  bool _emergencyEnabled = true;
  bool _medicineReminders = true;

  // DPDP Consents (mandatory)
  bool _consentEmergencySharing = false;
  bool _consentHealthRecords = false;
  bool _consentAiSymptoms = false;

  // DPDP Consents (optional)
  bool _consentMentalHealth = false;
  bool _consentMedicineReminders = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  bool get _mandatoryConsentsGranted =>
      _consentEmergencySharing && _consentHealthRecords && _consentAiSymptoms;

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_mandatoryConsentsGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept all mandatory consents to continue'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final consents = [
      ConsentItem(
        dataCategory: 'emergency',
        purpose: 'emergency_sharing',
        granted: _consentEmergencySharing,
        consentText:
            'I consent to sharing my emergency data with healthcare providers during emergencies.',
      ),
      ConsentItem(
        dataCategory: 'health_records',
        purpose: 'health_record_storage',
        granted: _consentHealthRecords,
        consentText:
            'I consent to storing my health records securely for personal health management.',
      ),
      ConsentItem(
        dataCategory: 'ai_symptoms',
        purpose: 'ai_symptom_checker',
        granted: _consentAiSymptoms,
        consentText:
            'I consent to AI-powered analysis of my symptoms for health insights.',
      ),
      ConsentItem(
        dataCategory: 'mental_health',
        purpose: 'mental_health_processing',
        granted: _consentMentalHealth,
        consentText:
            'I consent to processing my mental health data for wellness support.',
      ),
      ConsentItem(
        dataCategory: 'medications',
        purpose: 'medicine_reminders',
        granted: _consentMedicineReminders,
        consentText:
            'I consent to processing my medication data for reminder services.',
      ),
    ];

    final result = await AuthApiService.signup(
      name: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      language: _language,
      emergencyEnabled: _emergencyEnabled,
      medicineReminders: _medicineReminders,
      consents: consents,
      emergencyContact: _emergencyContactController.text.trim().isEmpty
          ? null
          : _emergencyContactController.text.trim(),
      emergencyPhone: _emergencyPhoneController.text.trim().isEmpty
          ? null
          : _emergencyPhoneController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (result.success && result.user != null) {
      // Update auth state
      ref.read(authStateProvider.notifier).setAuthenticatedUser(result.user!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome to MySehat!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/home');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Signup failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
                onPressed: _previousPage,
              )
            : IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF1E293B)),
                onPressed: () => context.go('/login'),
              ),
        title: Text(
          'Create Account',
          style: GoogleFonts.outfit(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index <= _currentPage
                            ? const Color(0xFF0EA5E9)
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildBasicInfoPage(),
                  _buildPreferencesPage(),
                  _buildConsentsPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your personal details to create your health profile.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),

          // Full Name
          _buildTextField(
            controller: _nameController,
            label: 'Full Name',
            hint: 'Enter your full name',
            icon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your name';
              }
              if (value.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Phone Number
          _buildTextField(
            controller: _phoneController,
            label: 'Phone Number',
            hint: 'Enter 10-digit phone number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your phone number';
              }
              if (value.trim().length != 10 ||
                  int.tryParse(value.trim()) == null) {
                return 'Please enter a valid 10-digit phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Emergency Contact (Optional)
          Text(
            'Emergency Contact (Optional)',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),

          _buildTextField(
            controller: _emergencyContactController,
            label: 'Contact Name',
            hint: 'e.g., Parent, Spouse',
            icon: Icons.contact_emergency_outlined,
          ),
          const SizedBox(height: 12),

          _buildTextField(
            controller: _emergencyPhoneController,
            label: 'Contact Phone',
            hint: 'Emergency contact phone',
            icon: Icons.phone_callback_outlined,
            keyboardType: TextInputType.phone,
            maxLength: 10,
          ),

          const SizedBox(height: 32),

          // Next button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_nameController.text.trim().isNotEmpty &&
                    _phoneController.text.trim().length == 10) {
                  _nextPage();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in required fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Continue',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Preferences',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Customize your app experience.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),

          // Language preference
          Text(
            'Language',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _language,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'hi', child: Text('हिंदी (Hindi)')),
                  DropdownMenuItem(value: 'ta', child: Text('தமிழ் (Tamil)')),
                  DropdownMenuItem(value: 'te', child: Text('తెలుగు (Telugu)')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _language = value);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Feature toggles
          _buildPreferenceSwitch(
            title: 'Emergency Contact Sharing',
            subtitle: 'Allow sharing your emergency data with responders',
            value: _emergencyEnabled,
            onChanged: (value) => setState(() => _emergencyEnabled = value),
            icon: Icons.emergency_outlined,
          ),
          const SizedBox(height: 16),

          _buildPreferenceSwitch(
            title: 'Medicine Reminders',
            subtitle: 'Get notifications for your medication schedule',
            value: _medicineReminders,
            onChanged: (value) => setState(() => _medicineReminders = value),
            icon: Icons.medication_outlined,
          ),

          const SizedBox(height: 32),

          // Next button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Continue',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DPDP Consents',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Under the Digital Personal Data Protection Act 2023, we need your consent for the following data uses.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          // Mandatory consents section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Required Consents',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'These consents are required to use the app\'s core features.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.red[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildConsentCheckbox(
            title: 'Emergency Data Sharing',
            description:
                'Share your emergency health data (blood type, allergies, conditions) with first responders during emergencies.',
            value: _consentEmergencySharing,
            onChanged: (value) =>
                setState(() => _consentEmergencySharing = value ?? false),
            required: true,
          ),

          _buildConsentCheckbox(
            title: 'Health Record Storage',
            description:
                'Store your prescription, lab reports, and health documents securely in the app.',
            value: _consentHealthRecords,
            onChanged: (value) =>
                setState(() => _consentHealthRecords = value ?? false),
            required: true,
          ),

          _buildConsentCheckbox(
            title: 'AI Symptom Checker',
            description:
                'Use AI-powered analysis to check your symptoms and get health recommendations.',
            value: _consentAiSymptoms,
            onChanged: (value) =>
                setState(() => _consentAiSymptoms = value ?? false),
            required: true,
          ),

          const SizedBox(height: 24),

          // Optional consents section
          Text(
            'Optional Consents',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'These are optional features you can enable.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),

          _buildConsentCheckbox(
            title: 'Mental Health Support',
            description:
                'Allow processing of your mental health conversations for personalized wellness support. Enabled by default: OFF',
            value: _consentMentalHealth,
            onChanged: (value) =>
                setState(() => _consentMentalHealth = value ?? false),
            required: false,
          ),

          _buildConsentCheckbox(
            title: 'Medicine Reminder Processing',
            description:
                'Process your medication data for intelligent reminder scheduling.',
            value: _consentMedicineReminders,
            onChanged: (value) =>
                setState(() => _consentMedicineReminders = value ?? false),
            required: false,
          ),

          const SizedBox(height: 32),

          // Signup button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSignup,
              style: ElevatedButton.styleFrom(
                backgroundColor: _mandatoryConsentsGranted
                    ? const Color(0xFF0EA5E9)
                    : Colors.grey[400],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Create Account',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Already have account
          Center(
            child: TextButton(
              onPressed: () => context.go('/login'),
              child: Text(
                'Already have an account? Login',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF0EA5E9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(color: Colors.grey[400]),
            prefixIcon: Icon(icon, color: const Color(0xFF0EA5E9)),
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            counterText: '',
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF0EA5E9), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF0EA5E9),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentCheckbox({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required bool required,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: value ? Colors.green[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? Colors.green[300]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    if (required)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Required',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.4,
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
