import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'journal_entry_model.g.dart';

@HiveType(typeId: 2)
class JournalEntry extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final List<JournalSegment> segments;

  @HiveField(3)
  final bool isPrivate;

  @HiveField(4)
  final String? pin;

  @HiveField(5)
  final List<JournalSticker> stickers;

  @HiveField(6)
  final List<JournalDrawing> drawings;

  JournalEntry({
    String? id,
    required this.date,
    this.segments = const [],
    this.isPrivate = false,
    this.pin,
    this.stickers = const [],
    this.drawings = const [],
  }) : id = id ?? const Uuid().v4();

  String get content => segments.map((s) => s.content).join(' ');
}

@HiveType(typeId: 3)
class JournalSegment {
  @HiveField(0)
  final String content; // Text content or Image/Asset path

  @HiveField(1)
  final String fontFamily;

  @HiveField(2)
  final String type; // 'text', 'image'

  @HiveField(3)
  final String? metadata;

  JournalSegment({
    required this.content,
    required this.fontFamily,
    required this.type,
    this.metadata,
  });
}

@HiveType(typeId: 4)
class JournalSticker {
  @HiveField(0)
  final String assetPath;

  @HiveField(1)
  final double dx;

  @HiveField(2)
  final double dy;

  JournalSticker({
    required this.assetPath,
    required this.dx,
    required this.dy,
  });
}

@HiveType(typeId: 5)
class JournalDrawing {
  @HiveField(0)
  final List<OffsetData> points;

  @HiveField(1)
  final int color;

  @HiveField(2)
  final double strokeWidth;

  @HiveField(3)
  final String brushType;

  JournalDrawing({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.brushType,
  });
}

@HiveType(typeId: 6)
class OffsetData {
  @HiveField(0)
  final double dx;

  @HiveField(1)
  final double dy;

  OffsetData(this.dx, this.dy);
}
