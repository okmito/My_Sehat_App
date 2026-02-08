class Reminder {
  final String id;
  final String medicationId;
  final String medicationName; // Assuming backend returns this for display
  final String? strength;
  final String
      dueTime; // ISO or HH:mm? "Get today's reminders" usually implies specific time.
  final String status; // PENDING, TAKEN, SKIPPED
  final String date; // YYYY-MM-DD

  Reminder({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    this.strength,
    required this.dueTime,
    required this.status,
    required this.date,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) {
    // Parse scheduled_at to extract date and time
    String dueTime = '';
    String date = '';
    
    if (json['scheduled_at'] != null) {
      try {
        final scheduledAt = DateTime.parse(json['scheduled_at']);
        dueTime = '${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}';
        date = '${scheduledAt.year}-${scheduledAt.month.toString().padLeft(2, '0')}-${scheduledAt.day.toString().padLeft(2, '0')}';
      } catch (e) {
        dueTime = json['due_time'] ?? '';
        date = json['date'] ?? '';
      }
    } else {
      dueTime = json['due_time'] ?? '';
      date = json['date'] ?? '';
    }
    
    return Reminder(
      id: json['id']?.toString() ?? '',
      medicationId: json['medication_id']?.toString() ?? '',
      medicationName: json['medication_name'] ?? 'Unknown Medicine',
      strength: json['strength']?.toString(),
      dueTime: dueTime,
      status: json['status'] ?? 'PENDING',
      date: date,
    );
  }
}
