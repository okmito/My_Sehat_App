import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Not strictly using controllers for the "Block" display unless editing is requested.
  // For the prompt's requirement "Block - pic, name, phn no., blood grp", it implies a display mode first.

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final name = user?.name ?? "Guest User";
    final phone = user?.phoneNumber ?? "+1234567890";
    final bloodGroup = user?.bloodGroup ?? "O+"; // Moked if null

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Block
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 10)
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor:
                        Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Icon(Icons.person,
                        size: 50, color: Theme.of(context).primaryColor),
                  ),
                  const SizedBox(height: 16),
                  Text(name,
                      style: GoogleFonts.outfit(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(phone,
                      style:
                          GoogleFonts.outfit(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _InfoItem(label: "Blood Group", value: bloodGroup),
                      _InfoItem(
                          label: "Age", value: user?.age?.toString() ?? "--"),
                      _InfoItem(label: "Gender", value: user?.gender ?? "--"),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Options List
            _ProfileOptionTile(
                icon: Icons.contact_phone,
                title: "Emergency Contacts",
                onTap: () => context.push('/emergency-contacts')),
            _ProfileOptionTile(
                icon: Icons.language,
                title: "Language Selection",
                onTap: () => context.push('/language-selection')),
            _ProfileOptionTile(
                icon: Icons.info_outline,
                title: "App Info",
                onTap: () => context.push('/app-info')),
            _ProfileOptionTile(
                icon: Icons.help_outline,
                title: "Help & Support",
                onTap: () => context.push('/help-support')),
            _ProfileOptionTile(
                icon: Icons.settings,
                title: "Settings",
                onTap: () => context.push('/settings')),
            _ProfileOptionTile(
                icon: Icons.logout,
                title: "Logout",
                color: Colors.red,
                onTap: () {
                  ref.read(authStateProvider.notifier).logout();
                  context.go('/login');
                }),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
        Text(value,
            style:
                GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ProfileOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color color;

  const _ProfileOptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                        color: color, fontWeight: FontWeight.w500),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: color.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
