import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/sos_slider_button.dart';
import '../widgets/emergency_content_widgets.dart';
import '../providers/sos_controller.dart';
import 'ambulance_tracking_screen.dart';
import '../../../settings/presentation/widgets/dpdp_consent_dialogs.dart';
import '../../../settings/presentation/pages/my_data_privacy_screen.dart';

class SOSScreen extends ConsumerStatefulWidget {
  const SOSScreen({super.key});

  @override
  ConsumerState<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends ConsumerState<SOSScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Prepare location and hospitals
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sosControllerProvider.notifier).prepare();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _triggerSOS() async {
    if (_isSending) return;

    // DPDP Compliance: Check consent before sharing emergency data
    final hasConsent = await FeatureConsents.checkSOSConsent(context, ref);
    if (!hasConsent) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'SOS requires consent to share location and medical data',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const MyDataPrivacyScreen()),
                );
              },
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isSending = true);

    try {
      await ref.read(sosControllerProvider.notifier).triggerSOS();

      if (mounted) {
        // Navigate to tracking screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AmbulanceTrackingScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send SOS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text("Emergency SOS",
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
              child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.4),
                radius: 1.2,
                colors: [
                  Colors.red.withValues(alpha: 0.05),
                  Colors.white,
                ],
              ),
            ),
          )),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 250 * _pulseAnimation.value,
                            height: 250 * _pulseAnimation.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red.withValues(
                                  alpha: 0.1 * (1.2 - _pulseAnimation.value)),
                            ),
                          );
                        },
                      ),
                      Container(
                        height: 200,
                        width: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.1),
                              blurRadius: 30,
                              spreadRadius: 5,
                            )
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.local_hospital,
                                size: 60, color: Color(0xFFFF4B4B)),
                            const SizedBox(height: 12),
                            Text(
                              "Emergency",
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                Center(
                  child: _isSending
                      ? Container(
                          height: 60,
                          width: 280,
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Sending SOS...',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SOSSliderButton(
                          onSlideComplete: _triggerSOS,
                          text: "SLIDE FOR SOS",
                        ),
                ),
                const SizedBox(height: 48),
                const EmergencyContactsWidget(),
                const SizedBox(height: 24),
                const NearbyHospitalsWidget(),
                const SizedBox(height: 24),
                const AmbulanceTrackingWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
