import 'package:shared_preferences/shared_preferences.dart';
import '../models/building.dart';
import '../data/buildings.dart';

class BuildingService {
  static const _key = 'buildings_v1';
  static const _seededKey = 'buildings_seeded';

  Future<List<Building>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_seededKey) ?? false)) {
      final seeds = kDefaultBuildings.toList();
      await _persist(seeds, prefs);
      await prefs.setBool(_seededKey, true);
      return seeds;
    }
    return (prefs.getStringList(_key) ?? [])
        .map(Building.fromJsonString)
        .toList();
  }

  Future<void> update(Building building) async {
    final prefs = await SharedPreferences.getInstance();
    final buildings = await loadAll();
    final i = buildings.indexWhere((b) => b.id == building.id);
    if (i != -1) buildings[i] = building;
    await _persist(buildings, prefs);
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final buildings = await loadAll();
    buildings.removeWhere((b) => b.id == id);
    await _persist(buildings, prefs);
  }

  Future<void> _persist(List<Building> buildings, SharedPreferences prefs) =>
      prefs.setStringList(_key, buildings.map((b) => b.toJsonString()).toList());
}
