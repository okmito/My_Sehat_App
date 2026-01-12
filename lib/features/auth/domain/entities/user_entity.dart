import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String phoneNumber;
  final String? name;
  final int? age;
  final String? gender;
  final String? bloodGroup;
  final List<String> allergies;
  final List<String> conditions;

  const UserEntity({
    required this.id,
    required this.phoneNumber,
    this.name,
    this.age,
    this.gender,
    this.bloodGroup,
    this.allergies = const [],
    this.conditions = const [],
  });

  @override
  List<Object?> get props => [
        id,
        phoneNumber,
        name,
        age,
        gender,
        bloodGroup,
        allergies,
        conditions,
      ];
}
