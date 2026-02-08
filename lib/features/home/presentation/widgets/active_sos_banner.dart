import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../emergency/presentation/providers/sos_controller.dart';
import '../../../emergency/data/models/sos_event_model.dart';

/// Active SOS Banner - Shows at the top of dashboard when an SOS is active
class ActiveSOSBanner extends ConsumerWidget {
  const ActiveSOSBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sosState = ref.watch(sosControllerProvider);
    final event = sosState.currentEvent;

    // Don't show if no active SOS or if resolved
    if (event == null || event.status == SOSStatus.resolved) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.shade600,
            Colors.red.shade800,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/ambulance-tracking'),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Pulsing Emergency Icon
                _PulsingIcon(),
                const SizedBox(width: 16),
                // Status Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "🚨 EMERGENCY ACTIVE",
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getStatusMessage(event.status),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.95),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Tap to track ambulance",
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getStatusMessage(SOSStatus status) {
    switch (status) {
      case SOSStatus.triggered:
        return "Help is being dispatched...";
      case SOSStatus.acknowledged:
        return "Emergency acknowledged";
      case SOSStatus.onTheWay:
        return "Ambulance on the way!";
      case SOSStatus.resolved:
        return "Emergency resolved";
    }
  }
}

class _PulsingIcon extends StatefulWidget {
  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.5),
                  blurRadius: 8 * _animation.value,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.emergency_rounded,
              color: Colors.red,
              size: 28,
            ),
          ),
        );
      },
    );
  }
}
