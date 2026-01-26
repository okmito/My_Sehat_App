import 'package:equatable/equatable.dart';

class SOSAlertEntity extends Equatable {
  final String id;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final bool isSynced;

  const SOSAlertEntity({
    required this.id,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.isSynced = false,
  });

  @override
  List<Object?> get props => [id, timestamp, latitude, longitude, isSynced];
}
