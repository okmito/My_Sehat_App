import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userName = authState.value?.name ?? "User";

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeHeader(userName: userName),
              const SizedBox(height: 24),
              const _HeroSection(),
              const SizedBox(height: 24),
              _SectionTitle(title: "Diagnostics Flow"),
              const SizedBox(height: 16),
              const _DiagnosticsRow(),
              const SizedBox(height: 24),
              _SectionTitle(title: "Health Record"),
              const SizedBox(height: 12),
              const _HealthRecordList(),
              const SizedBox(height: 24),
              _SectionTitle(title: "Quick Actions"),
              const SizedBox(height: 12),
              const _QuickActionsStrip(),
              const SizedBox(height: 20), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final String userName;
  const _HomeHeader({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hi, $userName!",
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              "How are you feeling today?",
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: () => context.push('/help-support'),
              icon:
                  const Icon(Icons.help_outline_rounded, color: Colors.black54),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => context.push('/profile'),
                child: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).primaryColor.withOpacity(0.1),
                  radius: 24,
                  child:
                      Icon(Icons.person, color: Theme.of(context).primaryColor),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HeroCard(
            title: "Doctor\nAppointment",
            icon: Icons.calendar_today_rounded,
            color: Colors.indigo,
            onTap: () {
              context.push('/appointment');
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _HeroCard(
            title: "Mental\nHealth",
            icon: Icons.psychology_rounded,
            color: Colors.teal,
            onTap: () => context.push('/mental_health'),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HeroCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        splashColor: color.withOpacity(0.2),
        highlightColor: color.withOpacity(0.1),
        onTap: onTap,
        child: Container(
          height: 160,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  height: 1.2,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }
}

class _DiagnosticsRow extends StatelessWidget {
  const _DiagnosticsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _DiagnosticsItem(
          icon: Icons.medical_services_outlined,
          label: "Symptom\nChecker",
          onTap: () => context.push('/symptom'),
        ),
        _DiagnosticsItem(
          icon: Icons.add_a_photo_outlined,
          label: "Image\nUploader",
          onTap: () {}, // TODO
        ),
        _DiagnosticsItem(
          icon: Icons.health_and_safety_outlined,
          label: "Health\nWorker",
          onTap: () {}, // TODO
        ),
      ],
    );
  }
}

class _DiagnosticsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DiagnosticsItem(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          // borderRadius removed because it conflicts with shape potentially,
          // or we can just use shape if we wanted border.
          // But here specifically, I didn't set shape above, I set borderRadius.
          // Wait, in previous turn I set:
          // borderRadius: BorderRadius.circular(20),
          // elevation: 2,
          // In the code I read back:
          // borderRadius: BorderRadius.circular(20),
          // elevation: 2,
          // There IS NO shape here. So why did I think there was?
          // Ah, check the code again.
          // _DiagnosticsItem ONLY has borderRadius, NO shape.
          // So _DiagnosticsItem might NOT be the one crashing?
          // The error log mentioned: _HeroCard and _HealthListTile.
          // _DiagnosticsItem was NOT in the error log.
          // I will leave _DiagnosticsItem alone if it only has borderRadius.
          // Reviewing code:
          // lines 249-253: borderRadius: BorderRadius.circular(20), elevation: 2. NO SHAPE.
          // So this chunk is UNNECESSARY. I will skip this chunk.
          // WAIT, verifying _HealthcareListTile which IS in error log.
          elevation: 2,
          borderRadius: BorderRadius.circular(20),
          shadowColor: Colors.black.withOpacity(0.3),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                // decorations moved to Material to allow ripple
              ),
              child:
                  Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

class _HealthRecordList extends StatelessWidget {
  const _HealthRecordList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HealthListTile(
          icon: Icons.history_rounded,
          title: "Past Visits",
          subtitle: "Check your consultation history",
          onTap: () {},
        ),
        _HealthListTile(
          icon: Icons.file_upload_rounded,
          title: "Upload E-Reports",
          subtitle: "Digitalize your medical records",
          onTap: () {},
        ),
        _HealthListTile(
          icon: Icons.medication_rounded,
          title: "My Medications",
          subtitle: "Active prescriptions & reminders",
          onTap: () {},
        ),
      ],
    );
  }
}

class _HealthListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HealthListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: ListTile(
          onTap: onTap,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.blue),
          ),
          title: Text(
            title,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.outfit(fontSize: 12),
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded,
              size: 16, color: Colors.grey),
        ),
      ),
    );
  }
}

class _QuickActionsStrip extends StatelessWidget {
  const _QuickActionsStrip();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickActionChip(
              label: "Journaling", icon: Icons.book, color: Colors.orange),
          const SizedBox(width: 12),
          _QuickActionChip(
              label: "Medicine Reminder",
              icon: Icons.alarm,
              color: Colors.purple),
          const SizedBox(width: 12),
          _QuickActionChip(
              label: "Steps", icon: Icons.directions_walk, color: Colors.red),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _QuickActionChip(
      {required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.8),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {}, // Placeholder for action
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
