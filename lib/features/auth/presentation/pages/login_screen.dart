import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController(text: "123456"); // Pre-fill mock
  bool _isOtpSent = false;

  void _onSendOtp() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length != 10 || int.tryParse(phone) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid 10-digit phone number"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isOtpSent = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("OTP '123456' sent to your phone")),
    );
  }

  void _onLogin() {
    ref.read(authStateProvider.notifier).login(
          _phoneController.text.trim(),
          _otpController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (prev, next) {
      next.whenOrNull(
        data: (user) {
          if (user != null) {
            context.go('/home'); // Navigate to Home on success
          }
        },
        error: (err, stack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(err.toString()), backgroundColor: Colors.red),
          );
        },
      );
    });

    final isLoading = ref.watch(authStateProvider).isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              children: [
                const SizedBox(height: 60),

                // App Logo with shadow
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/logo/app_logo.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),

                // App Name
                Text(
                  "MySehat",
                  style: GoogleFonts.outfit(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Your Offline-First Health Companion",
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 50),

                // Login Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isOtpSent ? "Verify OTP" : "Login",
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isOtpSent
                            ? "Enter the OTP sent to your phone"
                            : "Enter your phone number to continue",
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Phone Number Field
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        style: GoogleFonts.outfit(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: "Phone Number",
                          labelStyle:
                              GoogleFonts.outfit(color: Colors.grey[600]),
                          prefixIcon: Icon(Icons.phone_outlined,
                              color: Colors.grey[600]),
                          prefixText: "+91 ",
                          prefixStyle: GoogleFonts.outfit(
                              fontSize: 16, color: Colors.black87),
                          counterText: "",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF64748B), width: 2),
                          ),
                        ),
                        enabled: !_isOtpSent && !isLoading,
                      ),

                      if (_isOtpSent) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          style: GoogleFonts.outfit(
                              fontSize: 16, letterSpacing: 8),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: "Enter OTP",
                            labelStyle:
                                GoogleFonts.outfit(color: Colors.grey[600]),
                            counterText: "",
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xFF64748B), width: 2),
                            ),
                          ),
                          enabled: !isLoading,
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : (_isOtpSent ? _onLogin : _onSendOtp),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _isOtpSent ? "Verify & Login" : "Get OTP",
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      if (_isOtpSent) ...[
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _isOtpSent = false;
                              });
                            },
                            child: Text(
                              "Change Phone Number",
                              style: GoogleFonts.outfit(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Signup link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/signup'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        "Sign Up",
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0EA5E9),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Footer text
                Text(
                  "By continuing, you agree to our Terms of Service\nand Privacy Policy",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.grey[500],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
