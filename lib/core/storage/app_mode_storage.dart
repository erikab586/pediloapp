import 'package:shared_preferences/shared_preferences.dart';

/// Modo de uso para usuarios comerciante (también pueden comprar).
enum AppMode { comprador, comercio }

class AppModeStorage {
  static const _key = 'app_mode';

  Future<AppMode> read() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == AppMode.comercio.name) return AppMode.comercio;
    return AppMode.comprador;
  }

  Future<void> save(AppMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
