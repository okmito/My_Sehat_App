import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Mock data for demonstration
  List<Map<String, dynamic>> notifications = [
    {
      "title": "Appointment Confirmed",
      "body":
          "Your appointment with Dr. Sharma is confirmed for tomorrow at 10:00 AM.",
      "time": "2 hours ago",
      "isRead": false,
      "icon": Icons.calendar_today,
      "color": Colors.blue,
    },
    {
      "title": "Medication Reminder",
      "body": "It's time to take your Vitamin D supplement.",
      "time": "5 hours ago",
      "isRead": true,
      "icon": Icons.medication,
      "color": Colors.orange,
    },
    {
      "title": "Lab Results Available",
      "body": "Your blood test results are now available to view.",
      "time": "1 day ago",
      "isRead": true,
      "icon": Icons.assignment,
      "color": Colors.purple,
    },
  ];

  void _clearNotifications() {
    final deletedNotifications = List<Map<String, dynamic>>.from(notifications);
    setState(() {
      notifications.clear();
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Expanded(child: Text("All notifications cleared")),
            TextButton(
              onPressed: () {
                setState(() {
                  notifications.addAll(deletedNotifications);
                });
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
              style: TextButton.styleFrom(
                foregroundColor:
                    Colors.blueAccent, // Use your app's accent color
                padding: EdgeInsets.zero,
                minimumSize: const Size(50, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text("Undo"),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Notifications",
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (notifications.isNotEmpty)
            IconButton(
              onPressed: _clearNotifications,
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              tooltip: "Clear All",
            )
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return Dismissible(
                  key: Key(notification['title'].toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    setState(() {
                      notifications.removeAt(index);
                    });

                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Expanded(
                                child:
                                    Text("${notification['title']} dismissed")),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  notifications.insert(index, notification);
                                });
                                ScaffoldMessenger.of(context)
                                    .hideCurrentSnackBar();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.blueAccent,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(50, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text("Undo"),
                            ),
                          ],
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: notification['color'].withOpacity(0.1),
                      child: Icon(
                        notification['icon'],
                        color: notification['color'],
                        size: 20,
                      ),
                    ),
                    title: Text(
                      notification['title'],
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          notification['body'],
                          style: GoogleFonts.outfit(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification['time'],
                          style: GoogleFonts.outfit(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    tileColor: notification['isRead']
                        ? Colors.transparent
                        : Colors.blue.withOpacity(0.05),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No Notifications",
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You're all caught up! Check back later.",
            style: GoogleFonts.outfit(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
