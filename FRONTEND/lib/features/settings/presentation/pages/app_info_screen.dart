import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "App Info",
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Logo and Name
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.health_and_safety,
                      size: 80,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "MySehat",
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Your Offline-First Health Companion",
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Version 1.0.0",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // About Section
            const _SectionTitle(title: "About MySehat"),
            const SizedBox(height: 12),
            _InfoCard(
              child: Text(
                "MySehat is a comprehensive health management application designed to help you take control of your health journey. With offline-first capabilities, you can access your health information anytime, anywhere, even without an internet connection.",
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: Colors.black87,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Key Features
            const _SectionTitle(title: "Key Features"),
            const SizedBox(height: 12),
            const _InfoCard(
              child: Column(
                children: [
                  _FeatureItem(
                    icon: Icons.emergency,
                    title: "Emergency SOS",
                    description:
                        "Quick access to emergency contacts and services",
                  ),
                  Divider(height: 24),
                  _FeatureItem(
                    icon: Icons.healing,
                    title: "AI-assisted Symptom Triage System",
                    description:
                        "AI-assisted symptom understanding & triage system",
                  ),
                  Divider(height: 24),
                  _FeatureItem(
                    icon: Icons.psychology,
                    title: "Mental Health Support",
                    description:
                        "Track your mood and access mental wellness resources",
                  ),
                  Divider(height: 24),
                  _FeatureItem(
                    icon: Icons.calendar_today,
                    title: "Doctor Appointments",
                    description:
                        "Schedule and manage your medical appointments",
                  ),
                  Divider(height: 24),
                  _FeatureItem(
                    icon: Icons.history,
                    title: "Medical History",
                    description:
                        "Keep track of your health records and past consultations",
                  ),
                  Divider(height: 24),
                  _FeatureItem(
                    icon: Icons.offline_bolt,
                    title: "Offline Access",
                    description:
                        "Access your health data even without internet connection",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Privacy & Security
            const _SectionTitle(title: "Privacy & Security"),
            const SizedBox(height: 12),
            _InfoCard(
              child: Text(
                "Your health data is private and secure. All information is stored locally on your device with encryption. We never share your personal health information with third parties without your explicit consent.",
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: Colors.black87,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Contact Information
            const _SectionTitle(title: "Contact & Support"),
            const SizedBox(height: 12),
            const _InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ContactItem(
                    icon: Icons.email,
                    label: "Email",
                    value: "support@mysehat.com",
                  ),
                  SizedBox(height: 12),
                  _ContactItem(
                    icon: Icons.phone,
                    label: "Phone",
                    value: "+91 1800-XXX-XXXX",
                  ),
                  SizedBox(height: 12),
                  _ContactItem(
                    icon: Icons.language,
                    label: "Website",
                    value: "www.mysehat.com",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Legal
            const _SectionTitle(title: "Legal"),
            const SizedBox(height: 12),
            const _InfoCard(
              child: Column(
                children: [
                  _LegalItem(title: "Terms of Service"),
                  Divider(height: 16),
                  _LegalItem(title: "Privacy Policy"),
                  Divider(height: 16),
                  _LegalItem(title: "Licenses"),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Copyright
            Center(
              child: Text(
                "© 2026 MySehat. All rights reserved.",
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
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

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).primaryColor),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegalItem extends StatelessWidget {
  final String title;
  const _LegalItem({required this.title});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Navigate to respective legal document
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey[400],
          ),
        ],
      ),
    );
  }
}
