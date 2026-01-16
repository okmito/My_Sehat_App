import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class AppointmentScreen extends ConsumerWidget {
  const AppointmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Book Appointment",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          bottom: TabBar(
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
            tabs: const [
              Tab(text: "Offline Visit"),
              Tab(text: "Online Consult"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OfflineAppointmentTab(),
            _OnlineAppointmentTab(),
          ],
        ),
      ),
    );
  }
}

class _OfflineAppointmentTab extends StatelessWidget {
  const _OfflineAppointmentTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text("Nearest Hospitals",
            style:
                GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _HospitalCard(
          name: "City General Hospital",
          distance: "2.5 km",
          address: "123 Main St, Downtown",
          rating: 4.5,
          onBook: () {},
        ),
        _HospitalCard(
          name: "Sunshine Clinic",
          distance: "4.1 km",
          address: "456 Oak Ave, Westside",
          rating: 4.2,
          onBook: () {},
        ),
        _HospitalCard(
          name: "Metro Health Center",
          distance: "5.8 km",
          address: "789 Pine Rd, Northside",
          rating: 4.0,
          onBook: () {},
        ),
      ],
    );
  }
}

class _OnlineAppointmentTab extends StatelessWidget {
  const _OnlineAppointmentTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text("Available Doctors",
            style:
                GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _DoctorCard(
          name: "Dr. Sarah Smith",
          specialty: "General Physician",
          experience: "8 years",
          price: "\$30",
          onBook: () {},
        ),
        _DoctorCard(
          name: "Dr. James Wilson",
          specialty: "Psychiatrist",
          experience: "12 years",
          price: "\$50",
          onBook: () {},
        ),
      ],
    );
  }
}

class _HospitalCard extends StatelessWidget {
  final String name;
  final String distance;
  final String address;
  final double rating;
  final VoidCallback onBook;

  const _HospitalCard({
    required this.name,
    required this.distance,
    required this.address,
    required this.rating,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.outfit(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(rating.toString(),
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 4),
            Text(address, style: GoogleFonts.outfit(color: Colors.grey)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text(distance,
                    style: GoogleFonts.outfit(
                        color: Colors.blue, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Book Now"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final String name;
  final String specialty;
  final String experience;
  final String price;
  final VoidCallback onBook;

  const _DoctorCard({
    required this.name,
    required this.specialty,
    required this.experience,
    required this.price,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.grey[200],
              child: const Icon(Icons.person, size: 30, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.outfit(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(specialty,
                      style: GoogleFonts.outfit(color: Colors.grey)),
                  Text("$experience Experience",
                      style:
                          GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Column(
              children: [
                Text(price,
                    style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: onBook,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  child: const Text("Book"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
