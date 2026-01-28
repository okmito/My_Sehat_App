import 'package:hive/hive.dart';

part 'medicine_model.g.dart';

@HiveType(
    typeId:
        7) // Using next available typeId (assuming current max is around 6 based on previous files)
class MedicineModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String strength;

  @HiveField(3)
  final String form;

  @HiveField(4)
  final String scheduleType; // 'Daily', 'Weekly', 'Interval'

  @HiveField(5)
  final List<String> times; // ["08:00 AM", "08:00 PM"]

  @HiveField(6)
  final Map<String, String>
      history; // Key: "yyyy-MM-dd_time", Value: "taken" | "skipped"

  @HiveField(7)
  final DateTime? createdDate;

  @HiveField(8)
  final DateTime? endDate;

  MedicineModel({
    required this.id,
    required this.name,
    required this.strength,
    required this.form,
    required this.scheduleType,
    required this.times,
    this.history = const {},
    this.createdDate,
    this.endDate,
  });

  MedicineModel copyWith({
    String? id,
    String? name,
    String? strength,
    String? form,
    String? scheduleType,
    List<String>? times,
    Map<String, String>? history,
    DateTime? createdDate,
    DateTime? endDate,
  }) {
    return MedicineModel(
      id: id ?? this.id,
      name: name ?? this.name,
      strength: strength ?? this.strength,
      form: form ?? this.form,
      scheduleType: scheduleType ?? this.scheduleType,
      times: times ?? this.times,
      history: history ?? this.history,
      createdDate: createdDate ?? this.createdDate,
      endDate: endDate ?? this.endDate,
    );
  }
}
