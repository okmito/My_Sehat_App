// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medicine_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MedicineModelAdapter extends TypeAdapter<MedicineModel> {
  @override
  final int typeId = 7;

  @override
  MedicineModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MedicineModel(
      id: fields[0] as String,
      name: fields[1] as String,
      strength: fields[2] as String,
      form: fields[3] as String,
      scheduleType: fields[4] as String,
      times: (fields[5] as List).cast<String>(),
      history: (fields[6] as Map).cast<String, String>(),
      createdDate: fields[7] as DateTime?,
      endDate: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, MedicineModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.strength)
      ..writeByte(3)
      ..write(obj.form)
      ..writeByte(4)
      ..write(obj.scheduleType)
      ..writeByte(5)
      ..write(obj.times)
      ..writeByte(6)
      ..write(obj.history)
      ..writeByte(7)
      ..write(obj.createdDate)
      ..writeByte(8)
      ..write(obj.endDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicineModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
