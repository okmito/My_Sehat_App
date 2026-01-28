import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/diagnostics_provider.dart';

class DiagnosticsResultScreen extends ConsumerWidget {
  const DiagnosticsResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.read(diagnosticsProvider);
    final result = state.finalResult;

    if (result == null) {
      // Fallback if accessed directly without state
      return Scaffold(
        appBar: AppBar(title: const Text("Results")),
        body: const Center(child: Text("No results found.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Analysis Report"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSeverityBadge(context, result.severity),
            const SizedBox(height: 16),
            _buildSectionTitle("Summary"),
            _buildCard(
                child: Text(result.summary,
                    style: GoogleFonts.outfit(fontSize: 16))),
            const SizedBox(height: 16),
            _buildSectionTitle("Possible Causes"),
            _buildListCard(result.causes),
            const SizedBox(height: 16),
            if (result.redFlags.isNotEmpty) ...[
              _buildSectionTitle("Red Flags (Urgent)"),
              _buildListCard(result.redFlags, isWarning: true),
              const SizedBox(height: 16),
            ],
            // Removed whenToSeekCare and prevention as they are not in the backend model
            _buildSectionTitle("Home Care Advice"),
            _buildListCard(result.homeCare),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Text(
                "DISCLAIMER: ${result.disclaimer}",
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.brown,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Clear state and go directly to chat (skipping entry screen)
                ref.read(diagnosticsProvider.notifier).startNewSession();
                context.go('/diagnostics/chat');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Start New Check"),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go('/home'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text("Back to Home"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child, bool isWarning = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWarning ? Colors.red.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isWarning
            ? Border.all(color: Colors.red.withValues(alpha: 0.2))
            : null,
        boxShadow: [
          if (!isWarning)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, 2),
              blurRadius: 8,
            )
        ],
      ),
      child: child,
    );
  }

  Widget _buildListCard(List<String> items, {bool isWarning = false}) {
    if (items.isEmpty) {
      return _buildCard(
          child: const Text("None provided."), isWarning: isWarning);
    }

    return _buildCard(
      isWarning: isWarning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isWarning
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 16,
                        color: isWarning ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(item,
                              style: GoogleFonts.outfit(fontSize: 15))),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildSeverityBadge(BuildContext context, String severity) {
    Color color;
    switch (severity.toLowerCase()) {
      case 'high':
      case 'critical':
        color = Colors.red;
        break;
      case 'medium':
        color = Colors.orange;
        break;
      default:
        color = Colors.green;
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Text(
          "Severity: ${severity.toUpperCase()}",
          style: GoogleFonts.outfit(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
