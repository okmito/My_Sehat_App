import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../medicine_reminder/providers/medicine_provider.dart';
import '../../../medicine_reminder/models/reminder.dart';

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

  DateTime _parseTime(String timeStr) {
    try {
      final format = DateFormat("hh:mm a");
      final time = format.parse(timeStr);
      final now = _selectedDate;
      return DateTime(now.year, now.month, now.day, time.hour, time.minute);
    } catch (e) {
      // Fallback
      return DateTime.now();
    }
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
    ref.read(medicineProvider.notifier).toggleStatus(id, 'TAKEN');
  }

  @override
  Widget build(BuildContext context) {
    // Only support Today for now as per API limit
    final remindersAsync = ref.watch(todayRemindersProvider);

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
              const SizedBox(width: 8),
              Text(
                DateFormat('d MMM yyyy').format(DateTime.now()),
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueAccent,
                ),
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
          remindersAsync.when(
            data: (reminders) {
              if (reminders.isEmpty) {
                return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                        child: Text(
                      "No medications for today",
                      style: GoogleFonts.outfit(color: Colors.grey),
                    )));
              }

              final sortedReminders = List<Reminder>.from(reminders);
              sortedReminders.sort((a, b) => a.dueTime.compareTo(b.dueTime));

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedReminders.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final med = sortedReminders[index];
                  final status = med.status;
                  final isInWindow = _isWithinWindow(med.dueTime);

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
                      isInteractive = true;
                      opacity = 0.6;
                      break;
                    default:
                      if (isInWindow) {
                        statusColor = Colors.blue;
                        statusIcon = Icons.radio_button_unchecked;
                        statusText = "Take Now";
                        isInteractive = true;
                      } else {
                        // Logic for upcoming vs missed if PENDING
                        // Simplified check
                        statusColor = Colors.orange;
                        statusIcon = Icons.access_time_rounded;
                        statusText = "Upcoming";
                        isInteractive = true;
                        opacity = 0.5;
                      }
                  }

                  return Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(
                          med.dueTime,
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
                              med.medicationName,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            if (med.strength != null)
                              Text(
                                "${med.strength} mg",
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
                              ? () => _toggleStatus(med.id, med.dueTime, status)
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
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Text("Error: $err"),
          ),
        ],
      ),
    );
  }
}
