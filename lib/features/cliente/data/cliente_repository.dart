import '../../../core/config/api_config.dart';
import '../../../core/models/api_models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/json_parse.dart';
import 'models/catalog_models.dart';

class CarritoItemExtraModel {
  const CarritoItemExtraModel({
    required this.extraId,
    required this.cantidad,
    required this.nombre,
    required this.precioUnit,
    required this.lineTotal,
  });

  factory CarritoItemExtraModel.fromJson(Map<String, dynamic> json) {
    final extra = parseJsonMap(json['extra']);
    return CarritoItemExtraModel(
      extraId: parseJsonInt(json['extraId'] ?? extra?['id']),
      cantidad: parseJsonInt(json['cantidad'], defaultValue: 1),
      nombre: extra?['nombre'] as String? ?? 'Extra',
      precioUnit: json['precioUnit'] != null
          ? parseJsonDouble(json['precioUnit'])
          : parseJsonDouble(extra?['precio']),
      lineTotal: parseJsonDouble(json['lineTotal']),
    );
  }

  final int extraId;
  final int cantidad;
  final String nombre;
  final double precioUnit;
  final double lineTotal;

  String get label => '$nombre ×$cantidad (+${precioUnit.toStringAsFixed(0)})';
}

class CarritoItemModel {
  const CarritoItemModel({
    required this.id,
    required this.productoId,
    required this.cantidad,
    required this.lineTotal,
    required this.nombre,
    this.imagen,
    required this.precioUnit,
    this.opcionalId,
    this.opcionalNombre,
    this.extrasTotal = 0,
    this.extras = const [],
  });

  factory CarritoItemModel.fromJson(Map<String, dynamic> json) {
    final producto = parseJsonMap(json['producto']);
    final opcional = parseJsonMap(json['opcional']);
    final productoId = json['productoId'] ?? producto?['id'];
    final precioUnit = json['precioUnit'] != null
        ? parseJsonDouble(json['precioUnit'])
        : (opcional?['precio'] != null
            ? parseJsonDouble(opcional!['precio'])
            : parseJsonDouble(producto?['precio']));
    final nombreBase = producto?['nombre'] as String? ?? 'Producto';
    final opcionalNombre = opcional?['nombre'] as String?;
    final extrasRaw = json['extras'];
    final extras = extrasRaw is List
        ? extrasRaw
            .whereType<Map>()
            .map(
              (e) => CarritoItemExtraModel.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList()
        : <CarritoItemExtraModel>[];
    return CarritoItemModel(
      id: parseJsonInt(json['id']),
      productoId: parseJsonInt(productoId),
      cantidad: parseJsonInt(json['cantidad'], defaultValue: 1),
      lineTotal: parseJsonDouble(json['lineTotal']),
      nombre: opcionalNombre != null && opcionalNombre.isNotEmpty
          ? '$nombreBase ($opcionalNombre)'
          : nombreBase,
      imagen:
          (opcional?['imagen'] as String?) ?? (producto?['imagen'] as String?),
      precioUnit: precioUnit,
      opcionalId: json['opcionalId'] != null
          ? parseJsonInt(json['opcionalId'])
          : (opcional?['id'] != null ? parseJsonInt(opcional!['id']) : null),
      opcionalNombre: opcionalNombre,
      extrasTotal: parseJsonDouble(json['extrasTotal']),
      extras: extras,
    );
  }

  final int id;
  final int productoId;
  final int cantidad;
  final double lineTotal;
  final String nombre;
  final String? imagen;
  final double precioUnit;
  final int? opcionalId;
  final String? opcionalNombre;
  final double extrasTotal;
  final List<CarritoItemExtraModel> extras;

  String get lineTotalLabel => '\$${lineTotal.toStringAsFixed(0)}';

  String get imageUrl => ApiConfig.resolveImageUrl(imagen);

  String get precioUnitLabel => '\$${precioUnit.toStringAsFixed(0)}';

  String get extrasSummary {
    if (extras.isEmpty) return '';
    return extras.map((e) => e.label).join(' · ');
  }
}

class CarritoResumenModel {
  const CarritoResumenModel({
    required this.subtotal,
    required this.total,
    this.comercioId,
    required this.cantidadItems,
    this.entregaPrecio = 0,
  });

  factory CarritoResumenModel.fromJson(Map<String, dynamic> json) {
    return CarritoResumenModel(
      subtotal: parseJsonDouble(json['subtotal']),
      total: parseJsonDouble(json['total']),
      comercioId:
          json['comercioId'] != null ? parseJsonInt(json['comercioId']) : null,
      cantidadItems: parseJsonInt(json['cantidadItems']),
      entregaPrecio: parseJsonDouble(json['entregaPrecio']),
    );
  }

  final double subtotal;
  final double total;
  final int? comercioId;
  final int cantidadItems;
  final double entregaPrecio;
}

class CarritoModel {
  const CarritoModel({required this.items, required this.resumen});

  factory CarritoModel.fromJson(Map<String, dynamic> json) {
    final items =
        parseJsonMapList(json['items']).map(CarritoItemModel.fromJson).toList();
    return CarritoModel(
      items: items,
      resumen: CarritoResumenModel.fromJson(
        parseJsonMap(json['resumen']) ?? {},
      ),
    );
  }

  final List<CarritoItemModel> items;
  final CarritoResumenModel resumen;
}

class PedidoPreviewModel {
  const PedidoPreviewModel({
    required this.subtotal,
    required this.descuento,
    required this.entregaPrecio,
    required this.total,
  });

  factory PedidoPreviewModel.fromJson(Map<String, dynamic> json) {
    return PedidoPreviewModel(
      subtotal: parseJsonDouble(json['subtotal']),
      descuento: parseJsonDouble(json['descuento']),
      entregaPrecio: parseJsonDouble(json['entregaPrecio']),
      total: parseJsonDouble(json['total']),
    );
  }

  final double subtotal;
  final double descuento;
  final double entregaPrecio;
  final double total;
}

class PedidoLineItem {
  const PedidoLineItem({
    required this.nombre,
    required this.cantidad,
    this.productoId,
  });

  final int? productoId;
  final String nombre;
  final int cantidad;

  String get label => '$nombre x$cantidad';
}

class ClientePedidoModel {
  const ClientePedidoModel({
    required this.id,
    required this.status,
    required this.total,
    required this.metodoPago,
    required this.tipoEntrega,
    this.comercioId,
    this.comercioNombre,
    this.comercioLogo,
    this.comercioPortada,
    this.productoNombre,
    this.imagen,
    this.valorada = false,
    required this.createdAt,
  });

  factory ClientePedidoModel.fromJson(Map<String, dynamic> json) {
    final comercio = parseJsonMap(json['comercio']);
    final items = parseJsonMapList(json['items']);
    String? productoNombre = json['productoNombre'] as String?;
    String? imagen = json['imagen'] as String?;
    if ((productoNombre == null || productoNombre.isEmpty) &&
        items.isNotEmpty) {
      productoNombre = items.map((item) {
        final producto = parseJsonMap(item['producto']);
        return producto?['nombre'] as String? ?? 'Producto';
      }).join(', ');
    }
    if ((imagen == null || imagen.isEmpty) && items.isNotEmpty) {
      final producto = parseJsonMap(items.first['producto']);
      imagen = producto?['imagen'] as String?;
    }
    imagen ??=
        (comercio?['logo'] as String?) ?? (comercio?['portada'] as String?);

    return ClientePedidoModel(
      id: parseJsonInt(json['id']),
      status: json['status'] as String? ?? 'Pendiente',
      total: parseJsonDouble(json['total']),
      metodoPago: json['metodoPago'] as String? ?? '',
      tipoEntrega: json['tipoEntrega'] as String? ?? '',
      comercioId: json['comercioId'] != null
          ? parseJsonInt(json['comercioId'])
          : (comercio?['id'] != null ? parseJsonInt(comercio!['id']) : null),
      comercioNombre: comercio?['name'] as String?,
      comercioLogo: comercio?['logo'] as String?,
      comercioPortada: comercio?['portada'] as String?,
      productoNombre: productoNombre,
      imagen: imagen,
      valorada: parseJsonBool(json['valorada']),
      createdAt: DateTime.tryParse(
            (json['fechaPedido'] ?? json['createdAt']) as String? ?? '',
          ) ??
          DateTime.now(),
    );
  }

  final int id;
  final String status;
  final double total;
  final String metodoPago;
  final String tipoEntrega;
  final int? comercioId;
  final String? comercioNombre;
  final String? comercioLogo;
  final String? comercioPortada;
  final String? productoNombre;
  final String? imagen;
  final bool valorada;
  final DateTime createdAt;

  String get totalLabel => '\$${total.toStringAsFixed(0)}';

  /// Imagen del producto (fallback a logo del comercio).
  String get imageUrl => ApiConfig.resolveImageUrl(
        imagen ?? comercioLogo ?? comercioPortada,
      );

  /// Logo del comercio (fallback a portada).
  String get comercioLogoUrl =>
      ApiConfig.resolveImageUrl(comercioLogo ?? comercioPortada);

  String get fechaPedidoLabel {
    final d = createdAt;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year} $hh:$mi';
  }

  bool get isActive => !const {
        'Entregado',
        'Cancelado',
      }.contains(status);

  bool get canRepeat => status == 'Entregado' || status == 'Cancelado';
}

class ClientePedidoDetailModel extends ClientePedidoModel {
  const ClientePedidoDetailModel({
    required super.id,
    required super.status,
    required super.total,
    required super.metodoPago,
    required super.tipoEntrega,
    super.comercioId,
    super.comercioNombre,
    super.comercioLogo,
    super.comercioPortada,
    super.productoNombre,
    super.imagen,
    super.valorada,
    required super.createdAt,
    this.lineItems = const [],
    this.direccion,
  });

  factory ClientePedidoDetailModel.fromJson(Map<String, dynamic> json) {
    final direccion = parseJsonMap(json['direccion']);
    final lineItems = parseJsonMapList(json['items']).map((item) {
      final producto = parseJsonMap(item['producto']);
      final productoId = item['productoId'] != null
          ? parseJsonInt(item['productoId'])
          : (producto?['id'] != null ? parseJsonInt(producto!['id']) : null);
      return PedidoLineItem(
        productoId: productoId,
        nombre: producto?['nombre'] as String? ?? 'Item',
        cantidad: parseJsonInt(item['cantidad'], defaultValue: 1),
      );
    }).toList();

    final base = ClientePedidoModel.fromJson(json);

    return ClientePedidoDetailModel(
      id: base.id,
      status: base.status,
      total: base.total,
      metodoPago: base.metodoPago,
      tipoEntrega: base.tipoEntrega,
      comercioId: base.comercioId,
      comercioNombre: base.comercioNombre,
      comercioLogo: base.comercioLogo,
      comercioPortada: base.comercioPortada,
      productoNombre: base.productoNombre,
      imagen: base.imagen,
      valorada: base.valorada,
      createdAt: base.createdAt,
      lineItems: lineItems,
      direccion: direccion?['direccion'] as String?,
    );
  }

  final List<PedidoLineItem> lineItems;
  final String? direccion;

  List<String> get items => lineItems.map((e) => e.label).toList();
}

class DireccionModel {
  const DireccionModel({
    required this.id,
    required this.tipo,
    required this.direccion,
    this.referencia,
    this.predeterminada = false,
  });

  factory DireccionModel.fromJson(Map<String, dynamic> json) {
    return DireccionModel(
      id: parseJsonInt(json['id']),
      tipo: json['tipo'] as String? ?? 'Otra',
      direccion: json['direccion'] as String? ?? '',
      referencia: json['referencia'] as String?,
      predeterminada: parseJsonBool(json['predeterminada']),
    );
  }

  final int id;
  final String tipo;
  final String direccion;
  final String? referencia;
  final bool predeterminada;

  String get label => referencia != null && referencia!.isNotEmpty
      ? '$direccion ($referencia)'
      : direccion;
}

class ClienteRepository {
  ClienteRepository(this._api);

  final ApiClient _api;

  Future<CarritoModel> getCarrito() async {
    final json = await _api.get('/carrito', authenticated: true);
    return CarritoModel.fromJson(json);
  }

  Future<CarritoModel> addToCarrito(
    int productoId, {
    int cantidad = 1,
    int? opcionalId,
    List<Map<String, int>>? extras,
  }) async {
    final json = await _api.post(
      '/carrito/items',
      authenticated: true,
      body: {
        'productoId': productoId,
        'cantidad': cantidad,
        if (opcionalId != null) 'opcionalId': opcionalId,
        if (extras != null && extras.isNotEmpty) 'extras': extras,
      },
    );
    return CarritoModel.fromJson(json);
  }

  Future<CarritoModel> updateCarritoItem(int itemId, int cantidad) async {
    final json = await _api.put(
      '/carrito/items/$itemId',
      authenticated: true,
      body: {'cantidad': cantidad},
    );
    return CarritoModel.fromJson(json);
  }

  Future<CarritoModel> removeCarritoItem(int itemId) async {
    final json = await _api.delete(
      '/carrito/items/$itemId',
      authenticated: true,
    );
    return CarritoModel.fromJson(json);
  }

  Future<CarritoModel> clearCarrito() async {
    final json = await _api.delete('/carrito', authenticated: true);
    return CarritoModel.fromJson(json);
  }

  Future<PedidoPreviewModel> previewPedido({
    required int comercioId,
    required String metodoPago,
    required String tipoEntrega,
    int? direccionId,
    String? cuponCodigo,
  }) async {
    final json = await _api.post(
      '/pedidos/preview',
      authenticated: true,
      body: {
        'comercioId': comercioId,
        'metodoPago': metodoPago,
        'tipoEntrega': tipoEntrega,
        if (direccionId != null) 'direccionId': direccionId,
        if (cuponCodigo != null && cuponCodigo.isNotEmpty)
          'cuponCodigo': cuponCodigo,
      },
    );
    return PedidoPreviewModel.fromJson(json);
  }

  Future<ClientePedidoDetailModel> confirmarPedido({
    required String metodoPago,
    required String tipoEntrega,
    int? direccionId,
    double? entregaPrecio,
    int? cuponId,
    String? notas,
    double? valorEfectivo,
  }) async {
    final json = await _api.post(
      '/pedidos',
      authenticated: true,
      body: {
        'metodoPago': metodoPago,
        'tipoEntrega': tipoEntrega,
        if (direccionId != null) 'direccionId': direccionId,
        if (entregaPrecio != null) 'entregaPrecio': entregaPrecio,
        if (cuponId != null) 'cuponId': cuponId,
        if (notas != null && notas.trim().isNotEmpty) 'notas': notas.trim(),
        if (valorEfectivo != null) 'valorEfectivo': valorEfectivo,
      },
    );
    return ClientePedidoDetailModel.fromJson(json);
  }

  Future<PaginatedResponse<ClientePedidoModel>> getPedidos({
    int page = 1,
    int limit = 50,
    String? status,
  }) async {
    final json = await _api.get(
      '/pedidos',
      authenticated: true,
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return PaginatedResponse.fromJson(json, ClientePedidoModel.fromJson);
  }

  Future<ClientePedidoDetailModel> getPedido(int id) async {
    final json = await _api.get('/pedidos/$id', authenticated: true);
    return ClientePedidoDetailModel.fromJson(json);
  }

  Future<void> confirmarEntregaConValoracion({
    required int pedidoId,
    required int calificacion,
    String? comentario,
    required List<Map<String, dynamic>> productos,
  }) async {
    await _api.post(
      '/valoraciones/pedido/$pedidoId/confirmar-entrega',
      authenticated: true,
      body: {
        'calificacion': calificacion,
        if (comentario != null && comentario.trim().isNotEmpty)
          'comentario': comentario.trim(),
        'productos': productos,
      },
    );
  }

  Future<void> cancelarPedido(int id) async {
    await _api.patch('/pedidos/$id/cancelar', authenticated: true);
  }

  Future<List<DireccionModel>> getDirecciones() async {
    final rows = await _api.getList('/direcciones', authenticated: true);
    return rows.map(DireccionModel.fromJson).toList();
  }

  Future<DireccionModel> createDireccion({
    required String tipo,
    required String direccion,
    String? referencia,
    bool predeterminada = false,
  }) async {
    final json = await _api.post(
      '/direcciones',
      authenticated: true,
      body: {
        'tipo': tipo,
        'direccion': direccion,
        if (referencia != null) 'referencia': referencia,
        'predeterminada': predeterminada,
      },
    );
    return DireccionModel.fromJson(json);
  }

  Future<void> toggleFavoritoComercio(int comercioId) async {
    await _api.post(
      '/favoritos/comercios/$comercioId',
      authenticated: true,
    );
  }

  Future<List<ComercioModel>> getFavoritosComercios() async {
    final rows = await _api.getList(
      '/favoritos/comercios',
      authenticated: true,
    );
    return rows.map((row) {
      final nested = parseJsonMap(row['comercio']);
      if (nested != null) {
        return ComercioModel.fromJson(nested);
      }
      return ComercioModel.fromJson(row);
    }).toList();
  }

  /// Recrea el carrito con los ítems de un pedido anterior.
  Future<CarritoModel> repetirPedido(ClientePedidoDetailModel pedido) async {
    final lines = pedido.lineItems
        .where((l) => l.productoId != null && l.productoId! > 0)
        .toList();
    if (lines.isEmpty) {
      throw Exception('Este pedido no tiene productos para repetir.');
    }
    await clearCarrito();
    CarritoModel? last;
    for (final line in lines) {
      last = await addToCarrito(line.productoId!, cantidad: line.cantidad);
    }
    return last ?? await getCarrito();
  }

  Future<void> crearValoracionComercio({
    required int comercioId,
    required int calificacion,
    String? comentario,
  }) async {
    await _api.post(
      '/valoraciones',
      authenticated: true,
      body: {
        'comercioId': comercioId,
        'calificacion': calificacion,
        if (comentario != null && comentario.isNotEmpty)
          'comentario': comentario,
      },
    );
  }
}
