import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MedicineCard extends StatelessWidget {
  final String medicineName;
  final String strength;
  final String form;
  final String frequency;
  final List<String> times;

  const MedicineCard({
    super.key,
    required this.medicineName,
    required this.strength,
    required this.form,
    required this.frequency,
    required this.times,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  medicineName,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    form,
                    style: GoogleFonts.outfit(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Strength: $strength",
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 4),
            Text(
              "Frequency: $frequency",
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: times
                  .map((time) => Chip(
                        label: Text(time),
                        labelStyle: GoogleFonts.outfit(fontSize: 12),
                        backgroundColor: Colors.grey[100],
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
