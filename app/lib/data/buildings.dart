import 'package:latlong2/latlong.dart';

class Building {
  final String name;
  final LatLng location;

  const Building(this.name, this.location);
}

// Key IIT KGP buildings from OpenStreetMap data
const List<Building> kBuildings = [
  Building('Main Building', LatLng(22.3193, 87.3107)),
  Building('Central Library', LatLng(22.3175, 87.3130)),
  Building('Gymkhana', LatLng(22.3149, 87.3099)),
  Building('Nehru Museum', LatLng(22.3155, 87.3173)),
  Building('CSE Dept', LatLng(22.3185, 87.3095)),
  Building('Electrical Engg', LatLng(22.3178, 87.3085)),
  Building('Mech Engg', LatLng(22.3200, 87.3080)),
  Building('Nalanda Complex', LatLng(22.3160, 87.3110)),
  Building('Azad Hall', LatLng(22.3108, 87.3138)),
  Building('Nehru Hall', LatLng(22.3125, 87.3095)),
  Building('Patel Hall', LatLng(22.3118, 87.3115)),
  Building('HJB Hall', LatLng(22.3135, 87.3155)),
  Building('Technology Market', LatLng(22.3167, 87.3083)),
  Building('Main Gate', LatLng(22.3224, 87.3107)),
  Building('Swimming Pool', LatLng(22.3140, 87.3065)),
];
