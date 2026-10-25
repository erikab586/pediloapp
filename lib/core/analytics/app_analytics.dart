/// Eventos mínimos de producto (consola en debug; listo para wire a Firebase/analytics).
class AppAnalytics {
  AppAnalytics._();

  static void log(String name, [Map<String, Object?> params = const {}]) {
    assert(() {
      // ignore: avoid_print
      print('[analytics] $name $params');
      return true;
    }());
  }

  static void homeOpenComercio(int comercioId) =>
      log('home_open_comercio', {'comercioId': comercioId});

  static void addToCart({required int productoId, required int cantidad}) =>
      log('add_to_cart', {'productoId': productoId, 'cantidad': cantidad});

  static void checkoutConfirmed({required int pedidoId}) =>
      log('checkout_confirmed', {'pedidoId': pedidoId});
}
