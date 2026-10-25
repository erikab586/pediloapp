/// URL del backoffice web (comerciante completo + admin).
abstract final class BackofficeConfig {
  static const String webUrl = String.fromEnvironment(
    'BACKOFFICE_WEB_URL',
    defaultValue: 'http://187.127.44.110:8080',
  );

  static String loginUrl({String? from}) {
    final base = webUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/login');
    if (from == null) return uri.toString();
    return uri.replace(queryParameters: {'from': from}).toString();
  }
}
