/// Configuración de la API backend.
///
/// - Producción: `https://api.pedilo.tech`
/// - Emulador Android (local): `http://10.0.2.2:3000`
/// - Celular USB: `adb reverse tcp:3000 tcp:3000` + `http://127.0.0.1:3000`
/// - Celular Wi‑Fi: IP local de la PC, ej. `http://192.168.2.194:3000`
abstract final class ApiConfig {
  static const String host = 'https://api.pedilo.tech';
  static const String baseUrl = '$host/api';

  static String resolveImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '$host$url';
  }
}
