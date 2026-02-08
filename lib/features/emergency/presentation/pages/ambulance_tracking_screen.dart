import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/sos_event_model.dart';
import '../providers/sos_controller.dart';

class AmbulanceTrackingScreen extends ConsumerStatefulWidget {
  const AmbulanceTrackingScreen({super.key});

  @override
  ConsumerState<AmbulanceTrackingScreen> createState() =>
      _AmbulanceTrackingScreenState();
}

class _AmbulanceTrackingScreenState
    extends ConsumerState<AmbulanceTrackingScreen> {
  final MapController _mapController = MapController();
  Timer? _centerTimer;
  bool _hasShownArrivalAlert = false;

  @override
  void initState() {
    super.initState();
    // Auto-fit map after initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitMapToBounds();
    });
  }

  @override
  void dispose() {
    _centerTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _fitMapToBounds() {
    final sosState = ref.read(sosControllerProvider);
    final event = sosState.currentEvent;
    if (event == null) return;

    final userPos = event.userPosition;
    final ambPos = event.ambulancePosition;

    if (ambPos != null) {
      final bounds = LatLngBounds.fromPoints([userPos, ambPos]);
      try {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(80),
          ),
        );
      } catch (_) {
        // Map might not be ready yet
      }
    }
  }

  String _getStatusLabel(SOSStatus status) {
    switch (status) {
      case SOSStatus.triggered:
        return 'TRIGGERED';
      case SOSStatus.acknowledged:
        return 'ACKNOWLEDGED';
      case SOSStatus.onTheWay:
        return 'EN ROUTE';
      case SOSStatus.resolved:
        return 'ARRIVED';
    }
  }

  Color _getStatusColor(SOSStatus status) {
    switch (status) {
      case SOSStatus.triggered:
        return Colors.orange;
      case SOSStatus.acknowledged:
        return const Color(0xFFFF9800);
      case SOSStatus.onTheWay:
        return const Color(0xFF4CAF50);
      case SOSStatus.resolved:
        return const Color(0xFF2196F3);
    }
  }

  String _formatETA(SOSEventModel event) {
    // Estimate based on route progress
    if (event.routePoints.isEmpty) return '~5-10 min';

    final totalPoints = event.routePoints.length;
    final remaining = totalPoints - event.routeProgress;
    // Rough estimate: ~2 seconds per point update, 30 updates per minute
    final estimatedMinutes = (remaining / 30).ceil();

    if (estimatedMinutes <= 1) return '< 1 min';
    if (estimatedMinutes < 5) return '~$estimatedMinutes min';
    return '~5-10 min';
  }

  String _formatDistance(SOSEventModel event) {
    final userPos = event.userPosition;
    final ambPos = event.ambulancePosition;

    if (ambPos == null) return '-- km';

    const distance = Distance();
    final km = distance.as(LengthUnit.Kilometer, userPos, ambPos);

    if (km < 0.1) return '< 100 m';
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  Future<void> _callDriver() async {
    // Mock driver phone - in real app this would come from backend
    final uri = Uri(scheme: 'tel', path: '+911234567890');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to make call')),
        );
      }
    }
  }

  Future<void> _shareLocation() async {
    final sosState = ref.read(sosControllerProvider);
    final event = sosState.currentEvent;
    if (event == null) return;

    final userPos = event.userPosition;
    final ambId = event.assignedAmbulanceId ?? 'Unknown';

    final shareText = '''
🚑 Emergency SOS Alert

Ambulance ID: $ambId
Status: ${_getStatusLabel(event.status)}

📍 My Location:
https://www.google.com/maps?q=${userPos.latitude},${userPos.longitude}

ETA: ${_formatETA(event)}
''';

    await SharePlus.instance.share(ShareParams(text: shareText));
  }

  void _showArrivalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 50,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Ambulance Arrived!',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The ambulance has reached your location. Please look out for the medical team.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Go back to previous screen
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Done',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sosState = ref.watch(sosControllerProvider);
    final event = sosState.currentEvent;

    if (event == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Ambulance Tracking', style: GoogleFonts.outfit()),
        ),
        body: const Center(
          child: Text('No active emergency'),
        ),
      );
    }

    final userPos = event.userPosition;
    final ambPos = event.ambulancePosition;
    final status = event.status;

    // Show arrival alert when ambulance arrives
    if (status == SOSStatus.resolved && !_hasShownArrivalAlert) {
      _hasShownArrivalAlert = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showArrivalDialog();
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Map Layer
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: userPos,
                initialZoom: 14,
                minZoom: 10,
                maxZoom: 18,
              ),
              children: [
                // OpenStreetMap Tiles
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.mysehat.app',
                ),
                // Route Polyline - traveled portion (grey)
                if (event.routePoints.isNotEmpty && event.routeProgress > 0)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: event.routePoints.sublist(
                            0,
                            event.routeProgress
                                .clamp(0, event.routePoints.length)),
                        strokeWidth: 5,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                // Route Polyline - remaining portion (blue)
                if (event.routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: event.routePoints.sublist(event.routeProgress
                            .clamp(0, event.routePoints.length - 1)),
                        strokeWidth: 5,
                        color: Colors.blue.shade600,
                      ),
                    ],
                  ),
                // Markers
                MarkerLayer(
                  markers: [
                    // User Location Marker
                    Marker(
                      point: userPos,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.medical_services,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    // Ambulance Marker
                    if (ambPos != null)
                      Marker(
                        point: ambPos,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_hospital,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Top Header Card
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Back Button
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title and ID
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ambulance En Route',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${event.assignedAmbulanceId ?? 'Pending'}',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(status).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _getStatusLabel(status),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Map Controls
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 110,
            child: Column(
              children: [
                // Center on route button
                _MapControlButton(
                  icon: Icons.my_location,
                  onPressed: _fitMapToBounds,
                ),
                const SizedBox(height: 8),
                // Zoom In
                _MapControlButton(
                  icon: Icons.add,
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom + 1,
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Zoom Out
                _MapControlButton(
                  icon: Icons.remove,
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom - 1,
                    );
                  },
                ),
              ],
            ),
          ),

          // Bottom Info Panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag Handle
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // ETA and Distance Row
                      Row(
                        children: [
                          Expanded(
                            child: _InfoCard(
                              icon: Icons.access_time_rounded,
                              value: _formatETA(event),
                              label: 'ETA',
                              backgroundColor: Colors.orange.shade50,
                              iconColor: Colors.orange.shade700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoCard(
                              icon: Icons.straighten_rounded,
                              value: _formatDistance(event),
                              label: 'Distance',
                              backgroundColor: Colors.blue.shade50,
                              iconColor: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Action Buttons Row
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _callDriver,
                              icon: const Icon(Icons.call, size: 20),
                              label: Text(
                                'Call Driver',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _shareLocation,
                              icon: const Icon(Icons.share, size: 20),
                              label: Text(
                                'Share',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey.shade800,
                                side: BorderSide(color: Colors.grey.shade300),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

// Map Control Button Widget
class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MapControlButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, size: 22, color: Colors.grey.shade700),
        ),
      ),
    );
  }
}

// Info Card Widget
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color backgroundColor;
  final Color iconColor;

  const _InfoCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.backgroundColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
