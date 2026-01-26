import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TodayReminderCard extends StatelessWidget {
  final String medicineName;
  final String time;
  final String status;
  final VoidCallback onTaken;
  final VoidCallback onSkipped;
  final VoidCallback onReset;

  const TodayReminderCard({
    super.key,
    required this.medicineName,
    required this.time,
    required this.status,
    required this.onTaken,
    required this.onSkipped,
    required this.onReset,
  });

  Color _getStatusColor() {
    switch (status) {
      case 'TAKEN':
        return Colors.green;
      case 'MISSED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicineName,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      status,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(),
                      ),
                    ),
                    if (status != 'PENDING') ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: onReset,
                        icon: const Icon(Icons.edit, size: 18),
                        color: Colors.grey,
                        tooltip: "Edit",
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      )
                    ],
                  ],
                ),
              ],
            ),
            if (status == 'PENDING') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSkipped,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text("Skipped"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onTaken,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text("Taken"),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
