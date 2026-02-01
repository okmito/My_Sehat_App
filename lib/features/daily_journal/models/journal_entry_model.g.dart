// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_entry_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class JournalEntryAdapter extends TypeAdapter<JournalEntry> {
  @override
  final int typeId = 2;

  @override
  JournalEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return JournalEntry(
      id: fields[0] as String?,
      date: fields[1] as DateTime,
      segments: (fields[2] as List).cast<JournalSegment>(),
      isPrivate: fields[3] as bool,
      pin: fields[4] as String?,
      stickers: (fields[5] as List).cast<JournalSticker>(),
      drawings: (fields[6] as List).cast<JournalDrawing>(),
    );
  }

  @override
  void write(BinaryWriter writer, JournalEntry obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.segments)
      ..writeByte(3)
      ..write(obj.isPrivate)
      ..writeByte(4)
      ..write(obj.pin)
      ..writeByte(5)
      ..write(obj.stickers)
      ..writeByte(6)
      ..write(obj.drawings);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class JournalSegmentAdapter extends TypeAdapter<JournalSegment> {
  @override
  final int typeId = 3;

  @override
  JournalSegment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return JournalSegment(
      content: fields[0] as String,
      fontFamily: fields[1] as String,
      type: fields[2] as String,
      metadata: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, JournalSegment obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.content)
      ..writeByte(1)
      ..write(obj.fontFamily)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalSegmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class JournalStickerAdapter extends TypeAdapter<JournalSticker> {
  @override
  final int typeId = 4;

  @override
  JournalSticker read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return JournalSticker(
      assetPath: fields[0] as String,
      dx: fields[1] as double,
      dy: fields[2] as double,
      scale: fields[3] as double,
      rotation: fields[4] as double,
    );
  }

  @override
  void write(BinaryWriter writer, JournalSticker obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.assetPath)
      ..writeByte(1)
      ..write(obj.dx)
      ..writeByte(2)
      ..write(obj.dy)
      ..writeByte(3)
      ..write(obj.scale)
      ..writeByte(4)
      ..write(obj.rotation);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalStickerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class JournalDrawingAdapter extends TypeAdapter<JournalDrawing> {
  @override
  final int typeId = 5;

  @override
  JournalDrawing read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return JournalDrawing(
      points: (fields[0] as List).cast<OffsetData>(),
      color: fields[1] as int,
      strokeWidth: fields[2] as double,
      brushType: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, JournalDrawing obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.points)
      ..writeByte(1)
      ..write(obj.color)
      ..writeByte(2)
      ..write(obj.strokeWidth)
      ..writeByte(3)
      ..write(obj.brushType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalDrawingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OffsetDataAdapter extends TypeAdapter<OffsetData> {
  @override
  final int typeId = 6;

  @override
  OffsetData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OffsetData(
      fields[0] as double,
      fields[1] as double,
    );
  }

  @override
  void write(BinaryWriter writer, OffsetData obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.dx)
      ..writeByte(1)
      ..write(obj.dy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OffsetDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
