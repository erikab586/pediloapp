import '../../../core/models/api_models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/json_parse.dart';
import 'models/catalog_models.dart';

class CarritoItemModel {
  const CarritoItemModel({
    required this.id,
    required this.productoId,
    required this.cantidad,
    required this.lineTotal,
    required this.nombre,
    this.imagen,
    required this.precioUnit,
  });

  factory CarritoItemModel.fromJson(Map<String, dynamic> json) {
    final producto = parseJsonMap(json['producto']);
    final productoId = json['productoId'] ?? producto?['id'];
    return CarritoItemModel(
      id: parseJsonInt(json['id']),
      productoId: parseJsonInt(productoId),
      cantidad: parseJsonInt(json['cantidad'], defaultValue: 1),
      lineTotal: parseJsonDouble(json['lineTotal']),
      nombre: producto?['nombre'] as String? ?? 'Producto',
      imagen: producto?['imagen'] as String?,
      precioUnit: parseJsonDouble(producto?['precio']),
    );
  }

  final int id;
  final int productoId;
  final int cantidad;
  final double lineTotal;
  final String nombre;
  final String? imagen;
  final double precioUnit;

  String get lineTotalLabel => '\$${lineTotal.toStringAsFixed(0)}';
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
      comercioId: json['comercioId'] != null
          ? parseJsonInt(json['comercioId'])
          : null,
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
    final items = parseJsonMapList(json['items'])
        .map(CarritoItemModel.fromJson)
        .toList();
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

class ClientePedidoModel {
  const ClientePedidoModel({
    required this.id,
    required this.status,
    required this.total,
    required this.metodoPago,
    required this.tipoEntrega,
    this.comercioNombre,
    required this.createdAt,
  });

  factory ClientePedidoModel.fromJson(Map<String, dynamic> json) {
    final comercio = parseJsonMap(json['comercio']);
    return ClientePedidoModel(
      id: parseJsonInt(json['id']),
      status: json['status'] as String? ?? 'Pendiente',
      total: parseJsonDouble(json['total']),
      metodoPago: json['metodoPago'] as String? ?? '',
      tipoEntrega: json['tipoEntrega'] as String? ?? '',
      comercioNombre: comercio?['name'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final int id;
  final String status;
  final double total;
  final String metodoPago;
  final String tipoEntrega;
  final String? comercioNombre;
  final DateTime createdAt;

  String get totalLabel => '\$${total.toStringAsFixed(0)}';

  bool get isActive => !const {
        'Entregado',
        'Cancelado',
      }.contains(status);
}

class ClientePedidoDetailModel extends ClientePedidoModel {
  const ClientePedidoDetailModel({
    required super.id,
    required super.status,
    required super.total,
    required super.metodoPago,
    required super.tipoEntrega,
    super.comercioNombre,
    required super.createdAt,
    this.items = const [],
    this.direccion,
  });

  factory ClientePedidoDetailModel.fromJson(Map<String, dynamic> json) {
    final comercio = parseJsonMap(json['comercio']);
    final direccion = parseJsonMap(json['direccion']);
    final items = parseJsonMapList(json['items']).map((item) {
      final producto = parseJsonMap(item['producto']);
      return '${producto?['nombre'] ?? 'Item'} x${parseJsonInt(item['cantidad'])}';
    }).toList();

    return ClientePedidoDetailModel(
      id: parseJsonInt(json['id']),
      status: json['status'] as String? ?? 'Pendiente',
      total: parseJsonDouble(json['total']),
      metodoPago: json['metodoPago'] as String? ?? '',
      tipoEntrega: json['tipoEntrega'] as String? ?? '',
      comercioNombre: comercio?['name'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      items: items,
      direccion: direccion?['direccion'] as String?,
    );
  }

  final List<String> items;
  final String? direccion;
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

  Future<CarritoModel> addToCarrito(int productoId, {int cantidad = 1}) async {
    final json = await _api.post(
      '/carrito/items',
      authenticated: true,
      body: {'productoId': productoId, 'cantidad': cantidad},
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
      },
    );
    return ClientePedidoDetailModel.fromJson(json);
  }

  Future<PaginatedResponse<ClientePedidoModel>> getPedidos({
    int page = 1,
    int limit = 50,
  }) async {
    final json = await _api.get(
      '/pedidos',
      authenticated: true,
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
    return PaginatedResponse.fromJson(json, ClientePedidoModel.fromJson);
  }

  Future<ClientePedidoDetailModel> getPedido(int id) async {
    final json = await _api.get('/pedidos/$id', authenticated: true);
    return ClientePedidoDetailModel.fromJson(json);
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
    return rows.map(ComercioModel.fromJson).toList();
  }
}
