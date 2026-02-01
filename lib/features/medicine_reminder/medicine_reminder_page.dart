import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'add_medicine_page.dart';

import 'providers/medicine_provider.dart';
import 'models/medication.dart';
import 'models/reminder.dart';

class MedicineReminderPage extends ConsumerStatefulWidget {
  const MedicineReminderPage({super.key});

  @override
  ConsumerState<MedicineReminderPage> createState() =>
      _MedicineReminderPageState();
}

class _MedicineReminderPageState extends ConsumerState<MedicineReminderPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  void _deleteMedicine(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Medicine?"),
        content: const Text(
            "This will remove the medicine and its history completely."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(medicineProvider.notifier).deleteMedicine(id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Medicine deleted.")));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _endMedicine(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("End Medication Course?"),
        content: const Text(
            "This medicine will no longer appear in your future schedule."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              ref.read(medicineProvider.notifier).endMedicine(id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Medication course ended.")));
            },
            child: const Text("End Course",
                style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch providers
    final medicines = ref.watch(medicineProvider);
    final remindersAsync = ref.watch(todayRemindersProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Medicine Reminder",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.outfit(),
          tabs: const [
            Tab(text: "Scheduled Medicines"),
            Tab(text: "All Medicines"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScheduledTab(remindersAsync),
          _buildAllMedicinesTab(medicines),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddMedicinePage()),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: Text("Add Medicine",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildScheduledTab(AsyncValue<List<Reminder>> remindersAsync) {
    return remindersAsync.when(
      data: (reminders) {
        if (reminders.isEmpty) {
          return Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.event_available, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text("No reminders for today",
                  style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16)),
            ],
          ));
        }

        // Group by date if needed, but endpoint is "today".
        // We'll verify sorting.
        final sortedReminders = List<Reminder>.from(reminders);
        sortedReminders.sort((a, b) => a.dueTime.compareTo(b.dueTime));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedReminders.length,
          itemBuilder: (context, index) {
            final reminder = sortedReminders[index];
            final isTaken = reminder.status == 'TAKEN';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: isTaken
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.blue.withValues(alpha: 0.1),
                  child: Icon(
                    isTaken ? Icons.check : Icons.medication_rounded,
                    color: isTaken ? Colors.green : Colors.blue,
                  ),
                ),
                title: Text(
                  reminder.medicationName,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    decoration: isTaken ? TextDecoration.lineThrough : null,
                    color: isTaken ? Colors.grey : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  "${reminder.strength != null ? '${reminder.strength} mg • ' : ''}${reminder.dueTime}",
                  style: GoogleFonts.outfit(color: Colors.grey[600]),
                ),
                trailing: isTaken
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : ElevatedButton(
                        onPressed: () {
                          ref
                              .read(medicineProvider.notifier)
                              .toggleStatus(reminder.id, 'TAKEN');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 0),
                        ),
                        child: const Text("Take"),
                      ),
              ),
            );
          },
        );
      },
      error: (err, stack) => Center(child: Text("Error: $err")),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildAllMedicinesTab(List<Medication> medicines) {
    if (medicines.isEmpty) {
      return const Center(child: Text("No medicines added yet."));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: medicines.length,
      itemBuilder: (context, index) {
        final med = medicines[index];
        final scheduleText = med.schedule != null
            ? "${med.schedule!.scheduleType} • ${med.schedule!.times.join(", ")}"
            : "No schedule";

        return Card(
          elevation: 0,
          color: Colors.grey[100],
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            title: Text(med.name,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            subtitle: Text(
                "${med.strength != null ? '${med.strength} mg • ' : ''}$scheduleText\nForm: ${med.form}",
                style: GoogleFonts.outfit(height: 1.5)),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (med.id != null) {
                  if (value == 'delete') _deleteMedicine(med.id!);
                  if (value == 'end') _endMedicine(med.id!);
                  if (value == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => AddMedicinePage(medicine: med)),
                    );
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'end',
                  child: Row(children: [
                    Icon(Icons.stop_circle_outlined, color: Colors.orange),
                    SizedBox(width: 8),
                    Text("End Course")
                  ]),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit, color: Colors.blue),
                    SizedBox(width: 8),
                    Text("Edit")
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text("Delete")
                  ]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
