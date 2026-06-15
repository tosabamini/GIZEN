# GIZEN — Great India, Zero Environmental Neglect

A Flutter mobile app (Android & iOS) for the IIT Kharagpur campus trash-collection movement.  
Volunteers can map trash bins, record cleaning routes, and log every session with photos, bag counts, and team info.

---

## Features

### Map
| Feature | Details |
|---|---|
| Campus map | CartoDB Voyager tiles, restricted to IIT KGP campus bounds |
| Offline tiles | Pre-cached at zoom 14–17 via flutter_map_tile_caching (FMTC + ObjectBox) |
| Building labels | 106 real buildings from OSM Overpass API — editable (rename / recolor / delete) with a visibility toggle |
| Current location | GPS blue dot with geolocator |

### Trash Bins
| Feature | Details |
|---|---|
| Add / Edit / Delete | Long-press map to place; tap pin to edit |
| Size color coding | Yellow = Small · Orange = Medium · Red = Large |
| Comments | Notes on bin condition shown as blue badge |
| Persistence | Stored locally with shared_preferences |

### Cleaning Sessions
| Feature | Details |
|---|---|
| Start / Stop button | Floating button on map |
| GPS route recording | Outlier filter: rejects jumps > 100 m or > 8 m/s |
| Background GPS | Android foreground service · iOS background location mode |
| Route visualization | Semi-transparent green polyline; repeated passes darken |
| Post-stop form | Participants, bag count, free notes, multiple photos |
| Photo attachments | Camera or gallery; saved locally to app documents |

### Cleaning Log
| Feature | Details |
|---|---|
| Session history | Grouped by date with total stats banner |
| Per-session card | Duration, distance, participants, bags, notes, photo thumbnails |
| Photo viewer | Fullscreen swipe + pinch-zoom |
| Delete session | Tap trash icon → confirm dialog (for accidental starts) |

### Auth (optional)
- Firebase Auth with email / password / nickname
- Gracefully disabled if `flutterfire configure` has not been run

---

## Tech Stack

| Layer | Library / Version |
|---|---|
| Framework | Flutter 3.41.6 / Dart 3.11.4 |
| Map | flutter_map 7.0.2 + latlong2 |
| Tile cache | flutter_map_tile_caching 9.1.4 (ObjectBox backend) |
| GPS | geolocator 13.0.4 |
| Local storage | shared_preferences 2.5.5 |
| Building fonts | google_fonts 6.2.1 (Nunito) |
| Photos | image_picker 1.1.2 + path_provider 2.1.4 |
| Auth | firebase_core 3.x + firebase_auth 5.x (optional) |

---

## Project Structure

```
IITKGP_Cleaning/
└── app/                          # Flutter project root
    ├── lib/
    │   ├── main.dart             # App entry point; FMTC + Firebase init
    │   ├── models/
    │   │   ├── trash_bin.dart    # TrashBin model + BinSize enum
    │   │   ├── building.dart     # Building model (name, lat/lng, color)
    │   │   └── cleaning_session.dart
    │   ├── data/
    │   │   └── buildings.dart    # 106 IIT KGP buildings from OSM
    │   ├── services/
    │   │   ├── trash_bin_service.dart
    │   │   ├── building_service.dart
    │   │   ├── cleaning_session_service.dart
    │   │   ├── location_service.dart  # Normal + background GPS streams
    │   │   └── auth_service.dart
    │   └── screens/
    │       ├── map_screen.dart   # Main screen (map, bins, cleaning)
    │       ├── log_screen.dart   # Cleaning history
    │       └── auth_screen.dart  # Login / Register
    ├── android/
    │   └── app/src/main/AndroidManifest.xml  # Foreground service permissions
    └── ios/
        └── Runner/Info.plist     # Background location + camera permissions
```

---

## Setup

### Prerequisites
- Flutter SDK ≥ 3.41.6
- Android Studio / Xcode

### Run

```bash
cd app
flutter pub get
flutter run
```

The app runs without Firebase. Auth features are hidden until you configure Firebase:

```bash
dart pub global activate flutterfire_cli
flutterfire configure   # select your Firebase project
```

### Android — background GPS
The `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_LOCATION` permissions are already in `AndroidManifest.xml`.  
No `ACCESS_BACKGROUND_LOCATION` is needed; the foreground notification keeps GPS alive.

### iOS — background GPS
`UIBackgroundModes: location` and `NSLocationAlwaysAndWhenInUseUsageDescription` are already in `Info.plist`.

---

## Campus Bounds

| | Latitude | Longitude |
|---|---|---|
| Center | 22.3149 | 87.3105 |
| SW corner | 22.292 | 87.276 |
| NE corner | 22.348 | 87.345 |

---

*GIZEN — Great India, Zero Environmental Neglect*  
IIT Kharagpur Campus Cleaning Initiative
