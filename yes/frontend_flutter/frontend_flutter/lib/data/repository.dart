import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'fixtures.dart';
import 'types.dart';

abstract class AppRepository {
  Future<AppData> load();
  Future<void> save(AppData data);
  Future<AppData> reset();
}

AppData cloneInitialData() => AppData.fromJson(jsonDecode(jsonEncode(initialData.toJson())));
const STORAGE_KEY = 'elly.mock-data.v1';

/**
 * Drop-in development repository. The eventual client repository only needs
 * to implement the same three methods; screens never import fixtures directly.
 */
final AppRepository mockRepository = _MockRepository();

class _MockRepository implements AppRepository {
  @override
  Future<AppData> load() async {
    final localStorage = await SharedPreferences.getInstance();
    final saved = localStorage.getString(STORAGE_KEY);
    if (saved != null) {
      try {
        final data = AppData.fromJson(jsonDecode(saved));
        for (final place in data.profile.savedPlaces) {
          if (place.label == 'ELLY Office') place.label = 'Work';
        }
        for (final event in data.profile.calendarEvents) {
          if (event.location.label == 'ELLY Office') event.location.label = 'Work';
          if (event.subtitle == 'ELLY Office · Level 4') event.subtitle = 'Work · Level 4';
        }
        return data;
      } catch (_) {
        await localStorage.remove(STORAGE_KEY);
      }
    }
    return cloneInitialData();
  }

  @override
  Future<void> save(AppData data) async {
    final localStorage = await SharedPreferences.getInstance();
    await localStorage.setString(STORAGE_KEY, jsonEncode(data.toJson()));
  }

  @override
  Future<AppData> reset() async {
    final next = cloneInitialData();
    final localStorage = await SharedPreferences.getInstance();
    await localStorage.setString(STORAGE_KEY, jsonEncode(next.toJson()));
    return next;
  }
}