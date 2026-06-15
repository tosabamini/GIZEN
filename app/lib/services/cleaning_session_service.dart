import 'package:shared_preferences/shared_preferences.dart';
import '../models/cleaning_session.dart';

class CleaningSessionService {
  static const _key = 'cleaning_sessions_v1';

  Future<List<CleaningSession>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? [])
        .map(CleaningSession.fromJsonString)
        .toList();
  }

  Future<void> add(CleaningSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.add(session.toJsonString());
    await prefs.setStringList(_key, list);
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await loadAll();
    sessions.removeWhere((s) => s.id == id);
    await prefs.setStringList(
        _key, sessions.map((s) => s.toJsonString()).toList());
  }
}
