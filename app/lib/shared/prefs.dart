import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class AppPrefs {
  final SharedPreferences _prefs;
  static const _roleKey = 'app_role';

  AppPrefs._(this._prefs);

  static Future<AppPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppPrefs._(prefs);
  }

  AppRole? get role {
    final val = _prefs.getString(_roleKey);
    if (val == null) return null;
    return AppRole.values.firstWhere((r) => r.name == val);
  }

  Future<void> setRole(AppRole role) => _prefs.setString(_roleKey, role.name);
}
