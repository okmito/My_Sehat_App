import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'add_medicine_page.dart';
import 'widgets/today_reminder_card.dart';
import 'widgets/medicine_card.dart';

class MedicineReminderPage extends StatefulWidget {
  const MedicineReminderPage({super.key});

  @override
  State<MedicineReminderPage> createState() => _MedicineReminderPageState();
}

class _MedicineReminderPageState extends State<MedicineReminderPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mock data for Today's reminders
  final List<Map<String, dynamic>> _todayReminders = [
    {
      'id': 1,
      'name': 'Paracetamol',
      'time': '08:00 AM',
      'status': 'PENDING',
    },
    {
      'id': 2,
      'name': 'Vitamin D',
      'time': '09:00 AM',
      'status': 'TAKEN',
    },
    {
      'id': 3,
      'name': 'Amoxicillin',
      'time': '02:00 PM',
      'status': 'MISSED', // Example missed
    },
    {
      'id': 4,
      'name': 'Ibuprofen',
      'time': '08:00 PM',
      'status': 'PENDING',
    },
  ];

  // Mock data for All Medicines
  final List<Map<String, dynamic>> _allMedicines = [
    {
      'name': 'Paracetamol',
      'strength': '500 mg',
      'form': 'Tablet',
      'frequency': 'Daily',
      'times': ['08:00 AM', '08:00 PM'],
    },
    {
      'name': 'Vitamin D',
      'strength': '1000 IU',
      'form': 'Capsule',
      'frequency': 'Weekly',
      'times': ['09:00 AM'],
    },
    {
      'name': 'Amoxicillin',
      'strength': '250 mg',
      'form': 'Syrup',
      'frequency': 'Interval',
      'times': ['08:00 AM', '02:00 PM', '08:00 PM'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateStatus(int id, String newStatus) {
    setState(() {
      final index = _todayReminders.indexWhere((r) => r['id'] == id);
      if (index != -1) {
        _todayReminders[index]['status'] = newStatus;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Medicine Reminder",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: "Today"),
            Tab(text: "All Medicines"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayTab(),
          _buildAllMedicinesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddMedicinePage()),
          );
        },
        backgroundColor: Theme.of(context).primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          "Add Medicine",
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTodayTab() {
    if (_todayReminders.isEmpty) {
      return Center(
        child: Text(
          "No reminders for today",
          style: GoogleFonts.outfit(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _todayReminders.length,
      itemBuilder: (context, index) {
        final reminder = _todayReminders[index];
        return TodayReminderCard(
          medicineName: reminder['name'],
          time: reminder['time'],
          status: reminder['status'],
          onTaken: () => _updateStatus(reminder['id'], 'TAKEN'),
          onSkipped: () => _updateStatus(reminder['id'], 'MISSED'),
          onReset: () => _updateStatus(reminder['id'], 'PENDING'),
        );
      },
    );
  }

  Widget _buildAllMedicinesTab() {
    if (_allMedicines.isEmpty) {
      return Center(
        child: Text(
          "No medicines added yet",
          style: GoogleFonts.outfit(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16) +
          const EdgeInsets.only(bottom: 80), // Extra padding for FAB
      itemCount: _allMedicines.length,
      itemBuilder: (context, index) {
        final medicine = _allMedicines[index];
        return MedicineCard(
          medicineName: medicine['name'],
          strength: medicine['strength'],
          form: medicine['form'],
          frequency: medicine['frequency'],
          times: List<String>.from(medicine['times']),
        );
      },
    );
  }
}
