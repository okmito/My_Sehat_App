import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'sos_slider_button.dart';
import 'emergency_content_widgets.dart';
import '../providers/sos_controller.dart';
import '../pages/ambulance_tracking_screen.dart';

class SOSBottomSheet extends ConsumerStatefulWidget {
  const SOSBottomSheet({super.key});

  @override
  ConsumerState<SOSBottomSheet> createState() => _SOSBottomSheetState();
}

class _SOSBottomSheetState extends ConsumerState<SOSBottomSheet> {
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Prepare location and hospitals in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sosControllerProvider.notifier).prepare();
    });
  }

  Future<void> _handleSOS() async {
    if (_isSending) return;

    setState(() => _isSending = true);

    try {
      await ref.read(sosControllerProvider.notifier).triggerSOS();

      if (!mounted) return;

      // Close the bottom sheet
      Navigator.pop(context);

      // Navigate to tracking screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const AmbulanceTrackingScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSending = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send SOS: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.0,
      maxChildSize: 0.93,
      snap: true,
      snapSizes: const [0.5],
      shouldCloseOnMinExtent: true,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: [
                Column(
                  children: [
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.emergency_share,
                                color: Colors.red, size: 32),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Emergency SOS",
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Swipe safely to alert everyone",
                            style: GoogleFonts.outfit(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _isSending
                          ? Container(
                              height: 60,
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
                              onSlideComplete: _handleSOS,
                              text: "SLIDE TO SEND SOS",
                            ),
                    ),
                    const SizedBox(height: 32),
                    Divider(height: 1, color: Colors.grey.shade200),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EmergencyContactsWidget(),
                      const SizedBox(height: 24),
                      const NearbyHospitalsWidget(),
                      const SizedBox(height: 24),
                      const AmbulanceTrackingWidget(),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black54,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            "Cancel",
                            style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      SizedBox(
                          height: MediaQuery.of(context).padding.bottom + 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
