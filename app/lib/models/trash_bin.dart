import 'dart:convert';

enum BinSize { small, medium, large }

class TrashBin {
  final String id;
  final double lat;
  final double lng;
  final String name;
  final String comment;
  final BinSize size;

  TrashBin({
    String? id,
    required this.lat,
    required this.lng,
    this.name = '',
    this.comment = '',
    this.size = BinSize.medium,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  TrashBin copyWith({
    double? lat,
    double? lng,
    String? name,
    String? comment,
    BinSize? size,
  }) =>
      TrashBin(
        id: id,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        name: name ?? this.name,
        comment: comment ?? this.comment,
        size: size ?? this.size,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': lat,
        'lng': lng,
        'name': name,
        'comment': comment,
        'size': size.name,
      };

  factory TrashBin.fromJson(Map<String, dynamic> j) => TrashBin(
        id: j['id'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        name: j['name'] as String? ?? '',
        comment: j['comment'] as String? ?? '',
        size: BinSize.values.firstWhere(
          (e) => e.name == (j['size'] as String?),
          orElse: () => BinSize.medium,
        ),
      );

  String toJsonString() => jsonEncode(toJson());
  static TrashBin fromJsonString(String s) =>
      TrashBin.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
