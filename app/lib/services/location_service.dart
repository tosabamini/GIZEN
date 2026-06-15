import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/location_point.dart';

class LocationService {
  static const _cleanedKey = 'cleaned_locations';

  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Stream<Position> getPositionStream() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      );

  // Background stream: keeps GPS alive when app is backgrounded during cleaning.
  Stream<Position> getBackgroundPositionStream() {
    if (Platform.isAndroid) {
      return Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: '🧹 GIZEN — Cleaning in progress',
            notificationText: 'GPS is tracking your cleaning route.',
            enableWakeLock: true,
            setOngoing: true,
          ),
        ),
      );
    } else if (Platform.isIOS) {
      return Geolocator.getPositionStream(
        locationSettings: AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
          allowBackgroundLocationUpdates: true,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
        ),
      );
    }
    return getPositionStream();
  }

  Future<List<LocationPoint>> loadCleanedLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_cleanedKey) ?? [];
    return list.map(LocationPoint.fromJsonString).toList();
  }

  Future<void> saveCleanedLocation(LocationPoint point) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_cleanedKey) ?? [];
    list.add(point.toJsonString());
    await prefs.setStringList(_cleanedKey, list);
  }
}
