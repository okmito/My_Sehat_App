import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'add_medicine_page.dart';

import 'providers/medicine_provider.dart';
import 'models/medicine_model.dart';

class MedicineReminderPage extends ConsumerStatefulWidget {
  const MedicineReminderPage({super.key});

  @override
  ConsumerState<MedicineReminderPage> createState() =>
      _MedicineReminderPageState();
}

class _MedicineReminderPageState extends ConsumerState<MedicineReminderPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

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

  DateTime _parseTime(String timeStr) {
    final format = DateFormat("hh:mm a");
    final time = format.parse(timeStr);
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, time.hour, time.minute);
  }

  void _updateStatus(String id, String timeStr, String newStatus) {
    ScaffoldMessenger.of(context).clearSnackBars(); // Immediate feedback
    final medTime = _parseTime(timeStr);
    final now = DateTime.now();
    final startWindow = medTime.subtract(const Duration(minutes: 30));
    final endWindow = medTime.add(const Duration(minutes: 60));

    if (newStatus == 'TAKEN') {
      if (now.isBefore(startWindow)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Too early to take. 😴"),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.orange));
        return;
      }
      if (now.isAfter(endWindow)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Time window missed. ☹️"),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.red));
        return;
      }
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final key = "${dateStr}_$timeStr";
    final statusToSave = newStatus == 'PENDING' ? null : newStatus;

    ref
        .read(medicineProvider.notifier)
        .toggleStatusByKey(id, key, statusToSave);
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
            "This medicine will no longer appear in your future schedule, but history will be kept."),
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
    final medicines = ref.watch(medicineProvider);

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
          _buildScheduledTab(medicines),
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

  Widget _buildScheduledTab(List<MedicineModel> medicines) {
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final schedule = <Map<String, dynamic>>[];

    for (var med in medicines) {
      final creationDate = med.createdDate ?? DateTime(2000);
      final creationDateOnly = DateUtils.dateOnly(creationDate);
      final selectedDateOnly = DateUtils.dateOnly(_selectedDate);
      if (selectedDateOnly.isBefore(creationDateOnly)) continue;
      if (med.endDate != null &&
          selectedDateOnly.isAfter(DateUtils.dateOnly(med.endDate!))) {
        continue;
      }

      if (med.scheduleType == 'Daily') {
        for (var time in med.times) {
          final key = "${selectedDateStr}_$time";
          final status = med.history[key] ?? 'PENDING';
          schedule.add({
            'id': med.id,
            'name': med.name,
            'strength': med.strength,
            'time': time,
            'status': status,
          });
        }
      }
    }

    schedule.sort((a, b) {
      final format = DateFormat("hh:mm a");
      return format.parse(a['time']).compareTo(format.parse(b['time']));
    });

    return Column(
      children: [
        // Date Selector Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDate =
                        _selectedDate.subtract(const Duration(days: 1));
                  });
                },
                icon: const Icon(Icons.chevron_left),
              ),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, MMM d').format(_selectedDate),
                      style: GoogleFonts.outfit(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.add(const Duration(days: 1));
                  });
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        Expanded(
            child: schedule.isEmpty
                ? Center(
                    child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_busy,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text("No medicines for this date",
                          style: GoogleFonts.outfit(
                              color: Colors.grey, fontSize: 16)),
                    ],
                  ))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: schedule.length,
                    itemBuilder: (context, index) {
                      final item = schedule[index];
                      final isTaken = item['status'] == 'TAKEN';
                      // final isMissed = item['status'] == 'MISSED'; // Should we support specific 'Missed' in history? For now PENDING/TAKEN logic dominates.

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
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
                            item['name'],
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              decoration:
                                  isTaken ? TextDecoration.lineThrough : null,
                              color: isTaken ? Colors.grey : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            "${item['strength']} mg • ${item['time']}",
                            style: GoogleFonts.outfit(color: Colors.grey[600]),
                          ),
                          // Only allow taking/undoing if date is today (for safety) or maybe allow correcting history?
                          // User request implies checking history.
                          trailing: isTaken
                              ? IconButton(
                                  onPressed: () => _updateStatus(
                                      item['id'], item['time'], 'PENDING'),
                                  icon: const Icon(Icons.undo,
                                      color: Colors.grey),
                                )
                              : ElevatedButton(
                                  onPressed: () => _updateStatus(
                                      item['id'], item['time'], 'TAKEN'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).primaryColor,
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
                  )),
      ],
    );
  }

  Widget _buildAllMedicinesTab(List<MedicineModel> medicines) {
    if (medicines.isEmpty) {
      return const Center(child: Text("No medicines added yet."));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: medicines.length,
      itemBuilder: (context, index) {
        final med = medicines[index];
        final today = DateUtils.dateOnly(DateTime.now());
        final endDate =
            med.endDate != null ? DateUtils.dateOnly(med.endDate!) : null;
        final showEndOption = endDate == null || endDate.isAfter(today);

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
                "${med.strength} mg • ${med.scheduleType} • ${med.times.join(", ")}\nForm: ${med.form}",
                style: GoogleFonts.outfit(height: 1.5)),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') _deleteMedicine(med.id);
                if (value == 'end') _endMedicine(med.id);
                if (value == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => AddMedicinePage(medicine: med)),
                  );
                }
              },
              itemBuilder: (context) => [
                if (showEndOption)
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
