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
    // Handling potential variations in backend response
    return Reminder(
      id: json['id']?.toString() ?? '',
      medicationId: json['medication_id']?.toString() ?? '',
      medicationName: json['medication_name'] ?? 'Unknown Medicine',
      strength: json['strength'],
      dueTime: json['due_time'] ?? '',
      status: json['status'] ?? 'PENDING',
      date: json['date'] ?? '',
    );
  }
}
