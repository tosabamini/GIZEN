import 'dart:convert';
import 'package:latlong2/latlong.dart';

class CleaningSession {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final List<LatLng> path;
  final String participants;
  final int bagCount;
  final String notes;
  final String? creatorNickname;

  final List<String> imagePaths;

  CleaningSession({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.path,
    this.participants = '',
    this.bagCount = 0,
    this.notes = '',
    this.creatorNickname,
    List<String>? imagePaths,
  }) : imagePaths = imagePaths ?? [];

  Duration get duration => endTime.difference(startTime);

  double get distanceMeters {
    double total = 0;
    for (int i = 1; i < path.length; i++) {
      total += const Distance().as(LengthUnit.Meter, path[i - 1], path[i]);
    }
    return total;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'path': path
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
        'participants': participants,
        'bagCount': bagCount,
        'notes': notes,
        'creatorNickname': creatorNickname,
        'imagePaths': imagePaths,
      };

  factory CleaningSession.fromJson(Map<String, dynamic> j) => CleaningSession(
        id: j['id'] as String,
        startTime: DateTime.parse(j['startTime'] as String),
        endTime: DateTime.parse(j['endTime'] as String),
        path: (j['path'] as List)
            .map((p) => LatLng(
                (p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
            .toList(),
        participants: j['participants'] as String? ?? '',
        bagCount: (j['bagCount'] as int?) ?? 0,
        notes: j['notes'] as String? ?? '',
        creatorNickname: j['creatorNickname'] as String?,
        imagePaths: (j['imagePaths'] as List?)?.cast<String>(),
      );

  String toJsonString() => jsonEncode(toJson());

  factory CleaningSession.fromJsonString(String s) =>
      CleaningSession.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
