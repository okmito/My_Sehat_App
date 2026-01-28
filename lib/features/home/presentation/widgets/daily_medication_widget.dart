import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../medicine_reminder/providers/medicine_provider.dart';

class DailyMedicationWidget extends ConsumerStatefulWidget {
  const DailyMedicationWidget({super.key});

  @override
  ConsumerState<DailyMedicationWidget> createState() =>
      _DailyMedicationWidgetState();
}

class _DailyMedicationWidgetState extends ConsumerState<DailyMedicationWidget> {
  DateTime _selectedDate = DateTime.now();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Refresh UI every minute to keep time slots accurate
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String get _timeOfDay {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return "Morning";
    if (hour >= 12 && hour < 17) return "Afternoon";
    if (hour >= 17 && hour < 21) return "Evening";
    return "Night";
  }

  IconData get _timeOfDayIcon {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return Icons.wb_sunny_rounded;
    if (hour >= 12 && hour < 17) return Icons.wb_sunny_outlined;
    if (hour >= 17 && hour < 21) return Icons.wb_twilight;
    return Icons.nightlight_round;
  }

  Color get _timeOfDayColor {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return Colors.orange;
    if (hour >= 12 && hour < 17) return Colors.amber.shade700;
    if (hour >= 17 && hour < 21) return Colors.indigo;
    return Colors.purple;
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && !DateUtils.isSameDay(pickedDate, _selectedDate)) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  DateTime _parseTime(String timeStr) {
    final format = DateFormat("hh:mm a");
    final time = format.parse(timeStr);
    final now = _selectedDate;
    return DateTime(now.year, now.month, now.day, time.hour, time.minute);
  }

  bool _isWithinWindow(String timeStr) {
    final medTime = _parseTime(timeStr);
    final now = DateTime.now();

    final startWindow = medTime.subtract(const Duration(minutes: 30));
    final endWindow = medTime.add(const Duration(minutes: 60));

    // Only relevant if selected date is today
    if (!DateUtils.isSameDay(_selectedDate, DateTime.now())) return false;

    return now.isAfter(startWindow) && now.isBefore(endWindow);
  }

  void _toggleStatus(String id, String timeStr, String currentStatus) {
    ScaffoldMessenger.of(context).clearSnackBars(); // Immediate replacement

    if (currentStatus == 'MISSED') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("You missed this medication time. ☹️"),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
      ));
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final key = "${dateStr}_$timeStr";
    final now = DateTime.now();
    final medTime = _parseTime(timeStr);

    if (currentStatus == 'TAKEN') {
      ref.read(medicineProvider.notifier).toggleStatusByKey(id, key, null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Medication marked as not taken. ↩️"),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.grey[800],
      ));
      return;
    }

    final startWindow = medTime.subtract(const Duration(minutes: 30));
    final endWindow = medTime.add(const Duration(minutes: 60));

    if (now.isBefore(startWindow)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("It's too early to take this medication. 😴"),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange,
      ));
      return;
    }

    if (now.isAfter(endWindow)) {
      // This case handles PENDING items that are past their window (effectively missed but not yet marked/refreshed)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("You missed the time window. ☹️"),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
      ));
      return;
    }

    ref.read(medicineProvider.notifier).toggleStatusByKey(id, key, 'TAKEN');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Great! You've taken this medication. 😊"),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final allMedicines = ref.watch(medicineProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final schedule = <Map<String, dynamic>>[];
    for (var med in allMedicines) {
      // Filter 1: Check creation date
      final creationDate = med.createdDate ?? DateTime(2000);
      final creationDateOnly = DateUtils.dateOnly(creationDate);
      final selectedDateOnly = DateUtils.dateOnly(_selectedDate);

      if (selectedDateOnly.isBefore(creationDateOnly)) {
        continue;
      }

      // Filter 2: Check end date
      if (med.endDate != null) {
        final endDateOnly = DateUtils.dateOnly(med.endDate!);
        if (selectedDateOnly.isAfter(endDateOnly)) {
          continue;
        }
      }

      bool matchesDate = false;
      if (med.scheduleType == 'Daily') {
        matchesDate = true;
      } else {
        matchesDate = true;
      }

      if (matchesDate) {
        for (var time in med.times) {
          final key = "${dateStr}_$time";
          final status = med.history[key] ?? 'PENDING';
          schedule.add({
            'id': med.id,
            'name': med.name,
            'strength': med.strength,
            'time': time,
            'status': status,
            'model': med
          });
        }
      }
    }

    schedule.sort((a, b) {
      final format = DateFormat("hh:mm a");
      final t1 = format.parse(a['time']);
      final t2 = format.parse(b['time']);
      return t1.compareTo(t2);
    });

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Daily Medications",
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _changeDate(-1),
                    icon: const Icon(Icons.chevron_left_rounded,
                        size: 20, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _selectDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      child: Text(
                        DateFormat('d MMM yyyy').format(_selectedDate),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _changeDate(1),
                    icon: const Icon(Icons.chevron_right_rounded,
                        size: 20, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => context.push('/medicine_reminder'),
                icon: const Icon(Icons.edit_rounded,
                    size: 20, color: Colors.grey),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: "Edit Medications",
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _timeOfDayColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_timeOfDayIcon, size: 18, color: _timeOfDayColor),
                  const SizedBox(width: 8),
                  Text(
                    "It's $_timeOfDay",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _timeOfDayColor,
                    ),
                  ),
                ],
              ),
            ),
          if (schedule.isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                    child: Text(
                  "No medications for this day",
                  style: GoogleFonts.outfit(color: Colors.grey),
                ))),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: schedule.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final med = schedule[index];
              final status = med['status'];
              final isInWindow = _isWithinWindow(med['time']);

              Color statusColor;
              IconData statusIcon;
              String statusText;
              bool isInteractive = false;
              double opacity = 1.0;

              switch (status) {
                case 'TAKEN':
                  statusColor = Colors.green;
                  statusIcon = Icons.check_circle_rounded;
                  statusText = "Taken";
                  isInteractive = true;
                  opacity = 1.0;
                  break;
                case 'MISSED':
                  statusColor = Colors.red;
                  statusIcon = Icons.error_rounded;
                  statusText = "Missed";
                  isInteractive = true; // Enabled for feedback
                  opacity = 0.6;
                  break;
                default:
                  if (isInWindow) {
                    statusColor = Colors.blue;
                    statusIcon = Icons.radio_button_unchecked;
                    statusText = "Take Now";
                    isInteractive = true;
                  } else {
                    final medTime = _parseTime(med['time']);
                    if (isToday &&
                        DateTime.now()
                            .isAfter(medTime.add(const Duration(minutes: 60)))) {
                      statusColor = Colors.red;
                      statusIcon = Icons.error_rounded;
                      statusText = "Missed";
                      isInteractive = true; // Enabled for feedback
                      opacity = 0.6;
                    } else {
                      statusColor = Colors.orange;
                      statusIcon = Icons.access_time_rounded;
                      statusText = "Upcoming";
                      isInteractive = true; // Enabled for feedback
                      opacity = 0.5;
                    }
                  }
              }

              return Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(
                      med['time'],
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 40,
                    color: Colors.grey[200],
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          med['name'],
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (med['strength'].isNotEmpty)
                          Text(
                            "${med['strength']} mg",
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Opacity(
                    opacity: opacity,
                    child: InkWell(
                      onTap: isInteractive
                          ? () => _toggleStatus(med['id'], med['time'], status)
                          : null,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 16, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
