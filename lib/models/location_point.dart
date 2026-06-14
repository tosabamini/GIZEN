import 'dart:convert';

class LocationPoint {
  final double lat;
  final double lng;
  final DateTime timestamp;
  final String? note;

  LocationPoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'timestamp': timestamp.toIso8601String(),
        'note': note,
      };

  factory LocationPoint.fromJson(Map<String, dynamic> json) => LocationPoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        note: json['note'] as String?,
      );

  String toJsonString() => jsonEncode(toJson());

  static LocationPoint fromJsonString(String s) =>
      LocationPoint.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
