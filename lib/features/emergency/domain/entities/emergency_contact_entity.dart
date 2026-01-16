import 'package:equatable/equatable.dart';

class EmergencyContactEntity extends Equatable {
  final String id;
  final String name;
  final String phoneNumber;
  final String? relationship;

  const EmergencyContactEntity({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.relationship,
  });

  @override
  List<Object?> get props => [id, name, phoneNumber, relationship];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'relationship': relationship,
    };
  }

  factory EmergencyContactEntity.fromJson(Map<String, dynamic> json) {
    return EmergencyContactEntity(
      id: json['id'] as String,
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String,
      relationship: json['relationship'] as String?,
    );
  }

  EmergencyContactEntity copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? relationship,
  }) {
    return EmergencyContactEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      relationship: relationship ?? this.relationship,
    );
  }
}
