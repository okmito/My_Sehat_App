class HospitalModel {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final double distanceKm;

  const HospitalModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
  });

  factory HospitalModel.fromJson(Map<String, dynamic> json) {
    return HospitalModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Hospital',
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lon'] as num).toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
    );
  }
}
