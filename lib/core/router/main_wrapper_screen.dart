import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainWrapperScreen extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainWrapperScreen({
    Key? key,
    required this.navigationShell,
  }) : super(key: key ?? const ValueKey<String>('MainWrapperScreen'));

  @override
  State<MainWrapperScreen> createState() => _MainWrapperScreenState();
}

class _MainWrapperScreenState extends State<MainWrapperScreen> {
  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      // A common pattern when switching branches is to support
      // navigating to the initial location when tapping the item that is
      // already active.
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        destinations: const [
          NavigationDestination(
              label: 'Home',
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home)),
          NavigationDestination(label: 'Search', icon: Icon(Icons.search)),
          NavigationDestination(
              label: 'SOS',
              icon: Icon(Icons.sos, color: Colors.red)), // Highlighted SOS?
          NavigationDestination(
              label: 'Notifications',
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications)),
          NavigationDestination(label: 'History', icon: Icon(Icons.history)),
        ],
        onDestinationSelected: _goBranch,
      ),
    );
  }
}
