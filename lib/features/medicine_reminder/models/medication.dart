class Medication {
  final String? id; // Backend likely returns an ID
  final String name;
  final String? strength;
  final String form;
  final String? instructions;
  final MedicationSchedule? schedule; // Optional, if backend returns it nested

  Medication({
    this.id,
    required this.name,
    this.strength,
    required this.form,
    this.instructions,
    this.schedule,
  });

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id']?.toString(), // Ensure ID is string
      name: json['name'] ?? '',
      strength: json['strength'],
      form: json['form'] ?? '',
      instructions: json['instructions'],
      schedule: json['schedule'] != null
          ? MedicationSchedule.fromJson(json['schedule'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'strength': strength,
      'form': form,
      'instructions': instructions,
    };
  }
}

class MedicationSchedule {
  final String scheduleType; // DAILY, INTERVAL, WEEKLY
  final List<String> times; // ["HH:mm"]
  final String? endDate; // YYYY-MM-DD

  MedicationSchedule({
    required this.scheduleType,
    required this.times,
    this.endDate,
  });

  factory MedicationSchedule.fromJson(Map<String, dynamic> json) {
    return MedicationSchedule(
      scheduleType: json['schedule_type'] ?? 'DAILY',
      times: List<String>.from(json['times'] ?? []),
      endDate: json['end_date'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schedule_type': scheduleType,
      'times': times,
      'end_date': endDate,
    };
  }
}
