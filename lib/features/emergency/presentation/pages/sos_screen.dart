import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'sos_screen.dart'; // Import to use the locationProvider defined in original (or I can re-define it if I overwrite).

// Re-defining for safety if I overwrite the whole file
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

final locationProvider = FutureProvider<Position?>((ref) async {
  final permission = await Permission.location.request();
  if (permission.isGranted) {
    return await Geolocator.getCurrentPosition();
  }
  return null;
});

class SOSScreen extends ConsumerStatefulWidget {
  const SOSScreen({super.key});

  @override
  ConsumerState<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends ConsumerState<SOSScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerSOS() async {
    setState(() {
      _isSending = true;
    });

    final position = await ref.read(locationProvider.future);
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isSending = false;
      });
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("SOS Sent!"),
          content: Text(
              "Emergency contacts notified.\nLocation: ${position?.latitude}, ${position?.longitude}"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text("OK"))
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Emergency SOS",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SOS Content
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isSending ? null : _triggerSOS,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.5),
                                blurRadius: 20 + (_controller.value * 20),
                                spreadRadius: 5 + (_controller.value * 10),
                              )
                            ],
                          ),
                          child: Center(
                            child: _isSending
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text(
                                    "SOS",
                                    style: TextStyle(
                                      fontSize: 48,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Press to alert contacts & ambulance",
                    style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Emergency Contacts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Emergency Contacts",
                    style: GoogleFonts.outfit(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(onPressed: () {}, child: const Text("Edit"))
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ContactAvatar(name: "Mom", color: Colors.purple),
                  const SizedBox(width: 16),
                  _ContactAvatar(name: "Dad", color: Colors.blue),
                  const SizedBox(width: 16),
                  _ContactAvatar(name: "Wife", color: Colors.pink),
                  const SizedBox(width: 16),
                  _AddContactButton(),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Nearby Hospitals
            Text("Nearby Hospitals",
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _HospitalTile(
                name: "City Hospital", distance: "1.2 km", time: "5 min"),
            _HospitalTile(
                name: "Global Health", distance: "2.5 km", time: "12 min"),

            const SizedBox(height: 32),
            // Ambulance Tracking
            Text("Ambulance Tracking",
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!)),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.map, size: 40, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text("Map Loading...",
                        style: GoogleFonts.outfit(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactAvatar extends StatelessWidget {
  final String name;
  final Color color;
  const _ContactAvatar({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: color.withOpacity(0.2),
          child: Text(name[0],
              style: GoogleFonts.outfit(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ),
        const SizedBox(height: 8),
        Text(name, style: GoogleFonts.outfit(fontSize: 14)),
      ],
    );
  }
}

class _AddContactButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey[200],
          child: const Icon(Icons.add, color: Colors.black),
        ),
        const SizedBox(height: 8),
        Text("Add", style: GoogleFonts.outfit(fontSize: 14)),
      ],
    );
  }
}

class _HospitalTile extends StatelessWidget {
  final String name;
  final String distance;
  final String time;

  const _HospitalTile(
      {required this.name, required this.distance, required this.time});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.local_hospital, color: Colors.red),
      ),
      title: Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      subtitle: Text("$distance • $time away",
          style: GoogleFonts.outfit(color: Colors.grey)),
      trailing: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: const StadiumBorder()),
        child: const Text("Call"),
      ),
    );
  }
}
