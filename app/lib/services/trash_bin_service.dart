import 'package:shared_preferences/shared_preferences.dart';
import '../models/trash_bin.dart';

class TrashBinService {
  static const _key = 'trash_bins_v2';
  static const _seededKey = 'trash_bins_seeded';

  static const _defaults = [
    {'lat': 22.3193, 'lng': 87.3107, 'name': 'Main Building', 'comment': ''},
    {'lat': 22.3149, 'lng': 87.3099, 'name': 'Gymkhana', 'comment': ''},
    {'lat': 22.3167, 'lng': 87.3083, 'name': 'Technology Market', 'comment': ''},
    {'lat': 22.3140, 'lng': 87.3120, 'name': "Scholars' Avenue North", 'comment': ''},
    {'lat': 22.3118, 'lng': 87.3125, 'name': "Scholars' Avenue South", 'comment': ''},
    {'lat': 22.3108, 'lng': 87.3138, 'name': 'Azad Hall', 'comment': ''},
    {'lat': 22.3155, 'lng': 87.3173, 'name': 'Nehru Museum', 'comment': ''},
    {'lat': 22.3224, 'lng': 87.3107, 'name': 'Main Gate', 'comment': ''},
    {'lat': 22.3140, 'lng': 87.3065, 'name': 'Swimming Pool', 'comment': ''},
    {'lat': 22.3175, 'lng': 87.3150, 'name': 'Hijli Hall', 'comment': ''},
  ];

  Future<List<TrashBin>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_seededKey) ?? false)) {
      final seeds = _defaults
          .map((d) => TrashBin(
                lat: d['lat'] as double,
                lng: d['lng'] as double,
                name: d['name'] as String,
                comment: d['comment'] as String,
              ))
          .toList();
      await _persist(seeds, prefs);
      await prefs.setBool(_seededKey, true);
      return seeds;
    }
    return (prefs.getStringList(_key) ?? [])
        .map(TrashBin.fromJsonString)
        .toList();
  }

  Future<void> add(TrashBin bin) async {
    final prefs = await SharedPreferences.getInstance();
    final bins = await loadAll();
    bins.add(bin);
    await _persist(bins, prefs);
  }

  Future<void> update(TrashBin bin) async {
    final prefs = await SharedPreferences.getInstance();
    final bins = await loadAll();
    final i = bins.indexWhere((b) => b.id == bin.id);
    if (i != -1) bins[i] = bin;
    await _persist(bins, prefs);
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final bins = await loadAll();
    bins.removeWhere((b) => b.id == id);
    await _persist(bins, prefs);
  }

  Future<void> _persist(List<TrashBin> bins, SharedPreferences prefs) =>
      prefs.setStringList(_key, bins.map((b) => b.toJsonString()).toList());
}
