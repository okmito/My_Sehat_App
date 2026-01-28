import 'dart:convert';

import 'package:latlong2/latlong.dart';

enum SOSStatus { triggered, acknowledged, onTheWay, resolved }

SOSStatus sosStatusFromString(String raw) {
  switch (raw.toLowerCase()) {
    case 'acknowledged':
      return SOSStatus.acknowledged;
    case 'ontheway':
    case 'on_the_way':
    case 'on the way':
      return SOSStatus.onTheWay;
    case 'resolved':
      return SOSStatus.resolved;
    case 'triggered':
    default:
      return SOSStatus.triggered;
  }
}

String sosStatusToReadable(SOSStatus status) {
  switch (status) {
    case SOSStatus.triggered:
      return 'Triggered';
    case SOSStatus.acknowledged:
      return 'Acknowledged';
    case SOSStatus.onTheWay:
      return 'On The Way';
    case SOSStatus.resolved:
      return 'Resolved';
  }
}

class SOSEventModel {
  final int id;
  final String userId;
  final double latitude;
  final double longitude;
  final String emergencyType;
  final DateTime timestamp;
  final SOSStatus status;
  final String? assignedAmbulanceId;
  final double? ambulanceLat;
  final double? ambulanceLon;
  final List<LatLng> routePoints;
  final int routeProgress;

  const SOSEventModel({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.emergencyType,
    required this.timestamp,
    required this.status,
    this.assignedAmbulanceId,
    this.ambulanceLat,
    this.ambulanceLon,
    this.routePoints = const [],
    this.routeProgress = 0,
  });

  LatLng get userPosition => LatLng(latitude, longitude);

  LatLng? get ambulancePosition {
    if (ambulanceLat == null || ambulanceLon == null) return null;
    return LatLng(ambulanceLat!, ambulanceLon!);
  }

  bool get isResolved => status == SOSStatus.resolved;

  factory SOSEventModel.fromJson(Map<String, dynamic> json) {
    final rawRoute = json['route_coords'];
    List<LatLng> parsedRoute = const [];
    if (rawRoute != null) {
      try {
        final decoded = rawRoute is String ? jsonDecode(rawRoute) : rawRoute;
        if (decoded is List) {
          final rawPoints =
              decoded.whereType<List>().where((e) => e.length >= 2).toList();

          // Downsample to reduce polyline complexity (improves map render speed)
          const maxPoints = 300;
          final step = rawPoints.length > maxPoints
              ? (rawPoints.length / maxPoints).ceil()
              : 1;

          parsedRoute = List.generate(rawPoints.length, (i) => i)
              .where((i) => i % step == 0 || i == rawPoints.length - 1)
              .map((i) => rawPoints[i])
              .map((e) => LatLng(
                    (e[1] as num).toDouble(),
                    (e[0] as num).toDouble(),
                  ))
              .toList(growable: false);
        }
      } catch (_) {
        parsedRoute = const [];
      }
    }

    return SOSEventModel(
      id: (json['id'] as num).toInt(),
      userId: json['user_id']?.toString() ?? 'unknown',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      emergencyType: json['emergency_type']?.toString() ?? 'Medical',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      status: sosStatusFromString(json['status']?.toString() ?? 'Triggered'),
      assignedAmbulanceId: json['assigned_ambulance_id']?.toString(),
      ambulanceLat: json['ambulance_lat'] != null
          ? (json['ambulance_lat'] as num).toDouble()
          : null,
      ambulanceLon: json['ambulance_lon'] != null
          ? (json['ambulance_lon'] as num).toDouble()
          : null,
      routePoints: parsedRoute,
      routeProgress: (json['route_progress'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      'emergency_type': emergencyType,
      'timestamp': timestamp.toIso8601String(),
      'status': sosStatusToReadable(status),
      'assigned_ambulance_id': assignedAmbulanceId,
      'ambulance_lat': ambulanceLat,
      'ambulance_lon': ambulanceLon,
      'route_coords': routePoints
          .map((p) => [p.longitude, p.latitude])
          .toList(growable: false),
      'route_progress': routeProgress,
    };
  }

  SOSEventModel copyWith({
    int? id,
    String? userId,
    double? latitude,
    double? longitude,
    String? emergencyType,
    DateTime? timestamp,
    SOSStatus? status,
    String? assignedAmbulanceId,
    double? ambulanceLat,
    double? ambulanceLon,
    List<LatLng>? routePoints,
    int? routeProgress,
  }) {
    return SOSEventModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      emergencyType: emergencyType ?? this.emergencyType,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      assignedAmbulanceId: assignedAmbulanceId ?? this.assignedAmbulanceId,
      ambulanceLat: ambulanceLat ?? this.ambulanceLat,
      ambulanceLon: ambulanceLon ?? this.ambulanceLon,
      routePoints: routePoints ?? this.routePoints,
      routeProgress: routeProgress ?? this.routeProgress,
    );
  }
}
