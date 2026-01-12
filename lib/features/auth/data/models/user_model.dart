import 'package:hive/hive.dart';
import '../../domain/entities/user_entity.dart';

part 'user_model.g.dart';

@HiveType(typeId: 0)
class UserModel {
  @HiveField(0)
  late String userId;

  @HiveField(1)
  late String phoneNumber;

  @HiveField(2)
  String? name;

  @HiveField(3)
  int? age;

  @HiveField(4)
  String? gender;

  @HiveField(5)
  String? bloodGroup;

  @HiveField(6)
  List<String>? allergies;

  @HiveField(7)
  List<String>? conditions;

  UserModel();

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel()
      ..userId = entity.id
      ..phoneNumber = entity.phoneNumber
      ..name = entity.name
      ..age = entity.age
      ..gender = entity.gender
      ..bloodGroup = entity.bloodGroup
      ..allergies = entity.allergies
      ..conditions = entity.conditions;
  }

  UserEntity toEntity() {
    return UserEntity(
      id: userId,
      phoneNumber: phoneNumber,
      name: name,
      age: age,
      gender: gender,
      bloodGroup: bloodGroup,
      allergies: allergies ?? [],
      conditions: conditions ?? [],
    );
  }
}
