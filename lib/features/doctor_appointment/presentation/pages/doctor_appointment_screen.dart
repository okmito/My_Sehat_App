import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/online_consultation_tab.dart';
import '../widgets/offline_visit_tab.dart';

class DoctorAppointmentScreen extends StatelessWidget {
  const DoctorAppointmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Book Appointment",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          bottom: TabBar(
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(text: "Online Consultation"),
              Tab(text: "Offline Visit"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            OnlineConsultationTab(),
            OfflineVisitTab(),
          ],
        ),
      ),
    );
  }
}
