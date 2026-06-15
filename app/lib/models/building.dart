import 'dart:convert';
import 'package:latlong2/latlong.dart';

class Building {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final int colorValue;

  const Building({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.colorValue = 0xF0FFFFFF,
  });

  LatLng get location => LatLng(lat, lng);

  Building copyWith({String? name, int? colorValue}) => Building(
        id: id,
        name: name ?? this.name,
        lat: lat,
        lng: lng,
        colorValue: colorValue ?? this.colorValue,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
        'colorValue': colorValue,
      };

  factory Building.fromJson(Map<String, dynamic> j) => Building(
        id: j['id'] as String,
        name: j['name'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        colorValue: (j['colorValue'] as int?) ?? 0xF0FFFFFF,
      );

  String toJsonString() => jsonEncode(toJson());

  factory Building.fromJsonString(String s) =>
      Building.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
