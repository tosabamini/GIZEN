import 'package:latlong2/latlong.dart';

// IIT KGP campus approximate trash bin locations
const List<Map<String, dynamic>> kTrashBinData = [
  {'name': 'Main Building', 'lat': 22.3193, 'lng': 87.3107},
  {'name': 'Gymkhana', 'lat': 22.3149, 'lng': 87.3099},
  {'name': 'Technology Market', 'lat': 22.3167, 'lng': 87.3083},
  {'name': "Scholars' Avenue North", 'lat': 22.3140, 'lng': 87.3120},
  {'name': "Scholars' Avenue South", 'lat': 22.3118, 'lng': 87.3125},
  {'name': 'Azad Hall', 'lat': 22.3108, 'lng': 87.3138},
  {'name': 'Nehru Museum', 'lat': 22.3155, 'lng': 87.3173},
  {'name': 'Main Gate', 'lat': 22.3224, 'lng': 87.3107},
  {'name': 'Swimming Pool', 'lat': 22.3140, 'lng': 87.3065},
  {'name': 'Hijli Hall', 'lat': 22.3175, 'lng': 87.3150},
];

List<LatLng> get trashBinLatLngs => kTrashBinData
    .map((b) => LatLng(b['lat'] as double, b['lng'] as double))
    .toList();
