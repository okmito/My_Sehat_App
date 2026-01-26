import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RiskBanner extends StatelessWidget {
  final bool isRiskHigh;

  const RiskBanner({super.key, required this.isRiskHigh});

  @override
  Widget build(BuildContext context) {
    if (!isRiskHigh) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 24),
              const SizedBox(width: 8),
              Text(
                "Immediate Support",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.red.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "If you feel unsafe, please reach out now.",
            style: GoogleFonts.outfit(color: Colors.red.shade800),
          ),
          const SizedBox(height: 12),
          _HelplineRow(name: "Emergency", number: "112"),
          _HelplineRow(name: "AASRA", number: "9152987821"),
          _HelplineRow(name: "Kiran (Govt)", number: "1800-599-0019"),
        ],
      ),
    );
  }
}

class _HelplineRow extends StatelessWidget {
  final String name;
  final String number;

  const _HelplineRow({required this.name, required this.number});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text("$name: ",
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold, color: Colors.black87)),
          SelectableText(
            number,
            style: GoogleFonts.outfit(
              color: Colors.blue.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
