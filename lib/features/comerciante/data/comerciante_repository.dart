import 'dart:convert';
import 'dart:typed_data';

import '../../../core/config/api_config.dart';
import '../../../core/models/api_models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/json_parse.dart';
import '../../cliente/data/models/catalog_models.dart';

/// Modelo con el detalle completo de un pedido (vista /pedidos/:id).
class PedidoDetailModel {
  const PedidoDetailModel({
    required this.id,
    required this.status,
    required this.total,
    required this.metodoPago,
    required this.tipoEntrega,
    required this.items,
    this.cliente,
    this.direccion,
    this.notas,
    this.motivoCancelacion,
    required this.createdAt,
  });

  factory PedidoDetailModel.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>?) ?? const [];
    final usuario = json['usuario'] as Map<String, dynamic>?;
    final direccion = json['direccion'] as Map<String, dynamic>?;
    return PedidoDetailModel(
      id: json['id'] as int,
      status: json['status'] as String? ?? 'Pendiente',
      total: double.parse(json['total'].toString()),
      metodoPago: json['metodoPago'] as String? ?? '',
      tipoEntrega: json['tipoEntrega'] as String? ?? '',
      cliente: usuario == null
          ? null
          : PedidoClienteModel(
              id: usuario['id'] as int? ?? 0,
              name: usuario['name'] as String? ?? 'Cliente',
              phone: usuario['phone'] as String?,
            ),
      direccion: direccion == null
          ? null
          : PedidoDireccionModel(
              id: direccion['id'] as int? ?? 0,
              calle: direccion['calle'] as String?,
              numero: direccion['numero']?.toString(),
              ciudad: direccion['ciudad'] as String?,
              referencia: direccion['referencia'] as String?,
            ),
      notas: json['notas'] as String?,
      motivoCancelacion: json['motivoCancelacion'] as String?,
      items: items
          .map((e) => PedidoItemModel.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final int id;
  final String status;
  final double total;
  final String metodoPago;
  final String tipoEntrega;
  final PedidoClienteModel? cliente;
  final PedidoDireccionModel? direccion;
  final String? notas;
  final String? motivoCancelacion;
  final List<PedidoItemModel> items;
  final DateTime createdAt;

  String get totalLabel => '\$${total.toStringAsFixed(0)}';
}

class PedidoClienteModel {
  const PedidoClienteModel({
    required this.id,
    required this.name,
    this.phone,
  });
  final int id;
  final String name;
  final String? phone;
}

class PedidoDireccionModel {
  const PedidoDireccionModel({
    required this.id,
    this.calle,
    this.numero,
    this.ciudad,
    this.referencia,
  });
  final int id;
  final String? calle;
  final String? numero;
  final String? ciudad;
  final String? referencia;

  String get oneLine {
    final parts = <String>[
      if (calle != null && calle!.isNotEmpty) calle!,
      if (numero != null && numero!.isNotEmpty) numero!,
      if (ciudad != null && ciudad!.isNotEmpty) ciudad!,
    ];
    return parts.join(' ');
  }
}

class PedidoItemModel {
  const PedidoItemModel({
    required this.id,
    required this.cantidad,
    required this.precioUnit,
    this.subtotal,
    this.producto,
    this.combo,
  });

  factory PedidoItemModel.fromJson(Map<String, dynamic> json) {
    final producto = json['producto'] as Map<String, dynamic>?;
    final combo = json['combo'] as Map<String, dynamic>?;
    final subtotal = json['subtotal'];
    return PedidoItemModel(
      id: json['id'] as int? ?? 0,
      cantidad: json['cantidad'] as int? ?? 1,
      precioUnit: double.tryParse(json['precioUnit']?.toString() ?? '0') ?? 0,
      subtotal: subtotal == null
          ? null
          : double.tryParse(subtotal.toString()),
      producto: producto == null
          ? null
          : ProductoModel.fromJson({
              ...producto,
              'comercioId': producto['comercioId'] ??
                  producto['comercio_id'] ??
                  json['comercioId'] ??
                  0,
            }),
      combo: combo == null
          ? null
          : ComboModel.fromJson(combo),
    );
  }

  final int id;
  final int cantidad;
  final double precioUnit;
  final double? subtotal;
  final ProductoModel? producto;
  final ComboModel? combo;

  String get nombre =>
      combo?.nombre ??
      producto?.nombre ??
      'Item';

  double get total => subtotal ?? (precioUnit * cantidad);
  String get totalLabel => '\$${total.toStringAsFixed(0)}';
}

class DailyStatModel {
  const DailyStatModel({
    required this.fecha,
    required this.totalVentas,
    required this.cantidadPedidos,
    required this.pedidosCancelados,
  });

  factory DailyStatModel.fromJson(Map<String, dynamic> json) {
    return DailyStatModel(
      fecha: json['fecha'] as String? ?? '',
      totalVentas: double.tryParse(json['totalVentas']?.toString() ?? '0') ?? 0,
      cantidadPedidos: json['cantidadPedidos'] as int? ?? 0,
      pedidosCancelados: json['pedidosCancelados'] as int? ?? 0,
    );
  }

  final String fecha;
  final double totalVentas;
  final int cantidadPedidos;
  final int pedidosCancelados;
}

class PedidoModel {
  const PedidoModel({
    required this.id,
    required this.status,
    required this.total,
    required this.metodoPago,
    required this.tipoEntrega,
    this.clienteNombre,
    this.itemsResumen,
    required this.createdAt,
  });

  factory PedidoModel.fromJson(Map<String, dynamic> json) {
    final usuario = json['usuario'] as Map<String, dynamic>?;
    final items = json['items'] as List<dynamic>? ?? [];

    return PedidoModel(
      id: json['id'] as int,
      status: json['status'] as String? ?? 'Pendiente',
      total: double.parse(json['total'].toString()),
      metodoPago: json['metodoPago'] as String? ?? '',
      tipoEntrega: json['tipoEntrega'] as String? ?? '',
      clienteNombre: usuario?['name'] as String?,
      itemsResumen: items
          .map((item) {
            final map = item as Map<String, dynamic>;
            final producto = map['producto'] as Map<String, dynamic>?;
            final nombre = producto?['nombre'] as String? ?? 'Producto';
            final qty = map['cantidad'] as int? ?? 1;
            return '$nombre x$qty';
          })
          .join(', '),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final int id;
  final String status;
  final double total;
  final String metodoPago;
  final String tipoEntrega;
  final String? clienteNombre;
  final String? itemsResumen;
  final DateTime createdAt;

  String get totalLabel => '\$${total.toStringAsFixed(0)}';
}

class ComercioStatsModel {
  const ComercioStatsModel({
    required this.totalVentas,
    required this.cantidadPedidos,
    required this.ticketPromedio,
    required this.pedidosCancelados,
  });

  factory ComercioStatsModel.fromDailyList(List<DailyStatModel> rows) {
    var ventas = 0.0;
    var pedidos = 0;
    var cancelados = 0;

    for (final row in rows) {
      ventas += row.totalVentas;
      pedidos += row.cantidadPedidos;
      cancelados += row.pedidosCancelados;
    }

    final ticket = pedidos > 0 ? ventas / pedidos : 0.0;

    return ComercioStatsModel(
      totalVentas: ventas,
      cantidadPedidos: pedidos,
      ticketPromedio: ticket,
      pedidosCancelados: cancelados,
    );
  }

  final double totalVentas;
  final int cantidadPedidos;
  final double ticketPromedio;
  final int pedidosCancelados;
}

class ComercioPeriodReport {
  const ComercioPeriodReport({
    required this.stats,
    required this.series,
    required this.topProductos,
    required this.metodosPago,
    this.cancelaciones = 0,
    this.tasaCancelacion = 0,
  });

  final ComercioStatsModel stats;
  final List<DailyStatModel> series;
  final List<TopProductoStat> topProductos;
  final List<MetodoPagoComercioStat> metodosPago;
  final int cancelaciones;
  final double tasaCancelacion;
}

class TopProductoStat {
  const TopProductoStat({
    required this.nombre,
    required this.cantidadVendida,
    required this.total,
  });

  factory TopProductoStat.fromJson(Map<String, dynamic> json) {
    final producto = parseJsonMap(json['producto']);
    return TopProductoStat(
      nombre: producto?['nombre'] as String? ??
          json['nombre'] as String? ??
          'Producto',
      cantidadVendida: parseJsonInt(json['cantidadVendida']),
      total: parseJsonDouble(json['totalVendido'] ?? json['total']),
    );
  }

  final String nombre;
  final int cantidadVendida;
  final double total;
}

class MetodoPagoComercioStat {
  const MetodoPagoComercioStat({
    required this.metodo,
    required this.cantidad,
    required this.porcentaje,
  });

  factory MetodoPagoComercioStat.fromJson(Map<String, dynamic> json) {
    return MetodoPagoComercioStat(
      metodo: json['metodo'] as String? ?? 'Otro',
      cantidad: parseJsonInt(json['cantidad']),
      porcentaje: parseJsonInt(json['porcentaje']),
    );
  }

  final String metodo;
  final int cantidad;
  final int porcentaje;
}

class ComercianteRepository {
  ComercianteRepository(this._api);

  final ApiClient _api;

  Future<List<ComercioModel>> getMisComercios() async {
    final rows = await _api.getList(
      '/comercios/mis-comercios',
      authenticated: true,
    );
    return rows.map(ComercioModel.fromJson).toList();
  }

  Future<ComercioModel> getComercio(int id) async {
    final json = await _api.get('/comercios/show/$id', authenticated: true);
    return ComercioModel.fromJson(json);
  }

  Future<ComercioModel> createComercio({
    required int categoriaId,
    required String name,
    String? telefono,
    String? direccion,
    String? portada,
    List<String>? metodosPago,
    List<String>? tiposEntrega,
    Uint8List? logoBytes,
  }) async {
    final fields = <String, String>{
      'categoriaId': '$categoriaId',
      'name': name,
      if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
      if (direccion != null && direccion.isNotEmpty) 'direccion': direccion,
      if (portada != null && portada.isNotEmpty) 'portada': portada,
      if (metodosPago != null && metodosPago.isNotEmpty)
        'metodosPago': jsonEncode(metodosPago),
      if (tiposEntrega != null && tiposEntrega.isNotEmpty)
        'tiposEntrega': jsonEncode(tiposEntrega),
    };

    final files = logoBytes == null
        ? null
        : {
            'logo': MultipartFileData(
              bytes: logoBytes,
              filename: 'logo.jpg',
            ),
          };

    final json = await _api.postMultipart(
      '/comercios/register',
      fields: fields,
      files: files,
      authenticated: true,
    );
    return ComercioModel.fromJson(json);
  }

  Future<ComercioModel> updateComercio({
    required int id,
    int? categoriaId,
    String? name,
    String? telefono,
    String? direccion,
    String? portada,
    String? descripcion,
    bool? estaAbierto,
    List<String>? metodosPago,
    List<String>? tiposEntrega,
    Uint8List? logoBytes,
  }) async {
    final fields = <String, String>{
      if (categoriaId != null) 'categoriaId': '$categoriaId',
      if (name != null) 'name': name,
      if (telefono != null) 'telefono': telefono,
      if (direccion != null) 'direccion': direccion,
      if (portada != null) 'portada': portada,
      if (descripcion != null) 'descripcion': descripcion,
      if (estaAbierto != null) 'estaAbierto': estaAbierto.toString(),
      if (metodosPago != null) 'metodosPago': jsonEncode(metodosPago),
      if (tiposEntrega != null) 'tiposEntrega': jsonEncode(tiposEntrega),
    };

    final files = logoBytes == null
        ? null
        : {
            'logo': MultipartFileData(
              bytes: logoBytes,
              filename: 'logo.jpg',
            ),
          };

    final json = files == null
        ? await _api.put('/comercios/$id', authenticated: true, body: {
            if (categoriaId != null) 'categoriaId': categoriaId,
            if (name != null) 'name': name,
            if (telefono != null) 'telefono': telefono,
            if (direccion != null) 'direccion': direccion,
            if (portada != null) 'portada': portada,
            if (descripcion != null) 'descripcion': descripcion,
            if (estaAbierto != null) 'estaAbierto': estaAbierto,
            if (metodosPago != null) 'metodosPago': metodosPago,
            if (tiposEntrega != null) 'tiposEntrega': tiposEntrega,
          })
        : await _api.putMultipart(
            '/comercios/$id',
            fields: fields,
            files: files,
            authenticated: true,
          );

    return ComercioModel.fromJson(json);
  }

  Future<PaginatedResponse<PedidoModel>> getPedidos({
    int? comercioId,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final json = await _api.get(
      '/pedidos',
      authenticated: true,
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (comercioId != null) 'comercioId': '$comercioId',
        if (status != null) 'status': status,
      },
    );
    return PaginatedResponse.fromJson(json, PedidoModel.fromJson);
  }

  Future<void> updatePedidoStatus(int id, String status) async {
    await _api.patch(
      '/pedidos/$id/status',
      authenticated: true,
      body: {'status': status},
    );
  }

  Future<List<DailyStatModel>> getDailyStats(int comercioId) async {
    final rows = await _api.getList(
      '/estadisticas/comercio/$comercioId',
      authenticated: true,
    );
    return rows.map(DailyStatModel.fromJson).toList();
  }

  Future<ComercioStatsModel> getStats(int comercioId) async {
    final report = await getPeriodStats(comercioId, rango: 'dia');
    return report.stats;
  }

  Future<ComercioPeriodReport> getPeriodStats(
    int comercioId, {
    String rango = 'mes',
  }) async {
    final json = await _api.get(
      '/estadisticas/comercio/$comercioId',
      authenticated: true,
      queryParameters: {'rango': rango},
    );

    List<DailyStatModel> series;
    ComercioStatsModel stats;

    if (json.containsKey('series')) {
      series = parseJsonMapList(json['series'])
          .map(DailyStatModel.fromJson)
          .toList();
      final totales = parseJsonMap(json['totales']) ?? {};
      stats = ComercioStatsModel(
        totalVentas: parseJsonDouble(totales['ventas']),
        cantidadPedidos: parseJsonInt(totales['pedidos']),
        ticketPromedio: parseJsonDouble(totales['ticketPromedio']),
        pedidosCancelados: 0,
      );
    } else {
      series = await getDailyStats(comercioId);
      stats = ComercioStatsModel.fromDailyList(series);
    }

    List<TopProductoStat> topProductos = [];
    List<MetodoPagoComercioStat> metodosPago = [];
    var cancelaciones = 0;
    var tasaCancelacion = 0.0;

    try {
      final topRows = await _api.getList(
        '/estadisticas/comercio/$comercioId/top-productos',
        authenticated: true,
      );
      topProductos =
          topRows.map(TopProductoStat.fromJson).toList();
    } catch (_) {}

    try {
      final metodosJson = await _api.get(
        '/estadisticas/metodos-pago',
        authenticated: true,
        queryParameters: {'comercioId': '$comercioId', 'rango': rango},
      );
      metodosPago = parseJsonMapList(metodosJson['items'])
          .map(MetodoPagoComercioStat.fromJson)
          .toList();
    } catch (_) {}

    try {
      final cancelJson = await _api.get(
        '/estadisticas/cancelaciones',
        authenticated: true,
        queryParameters: {'comercioId': '$comercioId', 'rango': rango},
      );
      cancelaciones = parseJsonInt(cancelJson['totalCancelados']);
      tasaCancelacion = parseJsonDouble(cancelJson['porcentaje']);
      stats = ComercioStatsModel(
        totalVentas: stats.totalVentas,
        cantidadPedidos: stats.cantidadPedidos,
        ticketPromedio: stats.ticketPromedio,
        pedidosCancelados: cancelaciones,
      );
    } catch (_) {}

    return ComercioPeriodReport(
      stats: stats,
      series: series,
      topProductos: topProductos,
      metodosPago: metodosPago,
      cancelaciones: cancelaciones,
      tasaCancelacion: tasaCancelacion,
    );
  }

  Future<PaginatedResponse<ProductoModel>> getProductos(
    int comercioId, {
    bool soloActivos = false,
  }) async {
    final json = await _api.get(
      '/productos/show',
      queryParameters: {
        'comercioId': '$comercioId',
        'limit': '100',
        if (!soloActivos) 'soloActivos': 'false',
      },
    );
    return PaginatedResponse.fromJson(json, ProductoModel.fromJson);
  }

  Future<ProductoModel> createProducto({
    required int comercioId,
    required int categoriaProductoId,
    required String nombre,
    required double precio,
    String? descripcion,
    int cantidad = 0,
    bool activo = true,
    Uint8List? imagenBytes,
  }) async {
    final fields = <String, String>{
      'comercioId': '$comercioId',
      'categoriaProductoId': '$categoriaProductoId',
      'nombre': nombre,
      'precio': '$precio',
      if (descripcion != null && descripcion.isNotEmpty)
        'descripcion': descripcion,
      'cantidad': '$cantidad',
      'activo': activo.toString(),
    };

    final files = imagenBytes == null
        ? null
        : {
            'imagen': MultipartFileData(
              bytes: imagenBytes,
              filename: 'producto.jpg',
            ),
          };

    final json = await _api.postMultipart(
      '/productos/register',
      fields: fields,
      files: files,
      authenticated: true,
    );
    return ProductoModel.fromJson(json);
  }

  Future<ProductoModel> updateProducto({
    required int id,
    int? categoriaProductoId,
    String? nombre,
    String? descripcion,
    double? precio,
    int? cantidad,
    bool? activo,
    Uint8List? imagenBytes,
  }) async {
    final fields = <String, String>{
      if (categoriaProductoId != null)
        'categoriaProductoId': '$categoriaProductoId',
      if (nombre != null) 'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      if (precio != null) 'precio': '$precio',
      if (cantidad != null) 'cantidad': '$cantidad',
      if (activo != null) 'activo': activo.toString(),
    };

    final files = imagenBytes == null
        ? null
        : {
            'imagen': MultipartFileData(
              bytes: imagenBytes,
              filename: 'producto.jpg',
            ),
          };

    final json = files == null
        ? await _api.put('/productos/$id', authenticated: true, body: {
            if (categoriaProductoId != null)
              'categoriaProductoId': categoriaProductoId,
            if (nombre != null) 'nombre': nombre,
            if (descripcion != null) 'descripcion': descripcion,
            if (precio != null) 'precio': precio,
            if (cantidad != null) 'cantidad': cantidad,
            if (activo != null) 'activo': activo,
          })
        : await _api.putMultipart(
            '/productos/$id',
            fields: fields,
            files: files,
            authenticated: true,
          );

    return ProductoModel.fromJson(json);
  }

  Future<void> deleteProducto(int id) async {
    await _api.delete('/productos/$id', authenticated: true);
  }

  Future<List<CategoriaModel>> getCategorias() async {
    final json = await _api.get('/categorias/show', queryParameters: {
      'limit': '50',
    });
    final page = PaginatedResponse.fromJson(json, CategoriaModel.fromJson);
    return page.data;
  }

  /// Usa el endpoint dedicado `PATCH /comercios/:id/estado`.
  /// Body: `{ "abierto": true|false }` → columna `esta_abierto`.
  Future<ComercioModel> setComercioAbierto(int id, bool abierto) async {
    final json = await _api.patch(
      '/comercios/$id/estado',
      authenticated: true,
      body: {'abierto': abierto},
    );
    return ComercioModel.fromJson(json);
  }

  // ─── Pedidos: detalle completo ──────────────────────────────────────────

  Future<PedidoDetailModel> getPedido(int id) async {
    final json = await _api.get('/pedidos/$id', authenticated: true);
    return PedidoDetailModel.fromJson(json);
  }

  // ─── Combos ─────────────────────────────────────────────────────────────

  Future<List<ComboModel>> getCombos(int comercioId) async {
    final rows = await _api.getList(
      '/promociones/comercio/$comercioId/combos',
      authenticated: true,
    );
    return rows.map(ComboModel.fromJson).toList();
  }

  Future<ComboModel> getCombo(int id) async {
    final json = await _api.get('/promociones/combos/$id', authenticated: true);
    return ComboModel.fromJson(json);
  }

  Future<ComboModel> createCombo({
    required int comercioId,
    required String nombre,
    required double precio,
    String? descripcion,
    String? imagen,
    bool activo = true,
    required List<ComboItemInput> items,
  }) async {
    final json = await _api.post(
      '/promociones/comercio/$comercioId/combos',
      authenticated: true,
      body: {
        'nombre': nombre,
        'precio': precio,
        if (descripcion != null && descripcion.isNotEmpty)
          'descripcion': descripcion,
        if (imagen != null && imagen.isNotEmpty) 'imagen': imagen,
        'activo': activo,
        'items': items
            .map((i) => {'productoId': i.productoId, 'cantidad': i.cantidad})
            .toList(),
      },
    );
    return ComboModel.fromJson(json);
  }

  Future<ComboModel> updateCombo({
    required int id,
    String? nombre,
    double? precio,
    String? descripcion,
    String? imagen,
    bool? activo,
    List<ComboItemInput>? items,
  }) async {
    final body = <String, dynamic>{
      if (nombre != null) 'nombre': nombre,
      if (precio != null) 'precio': precio,
      if (descripcion != null) 'descripcion': descripcion,
      if (imagen != null) 'imagen': imagen,
      if (activo != null) 'activo': activo,
      if (items != null)
        'items': items
            .map((i) => {'productoId': i.productoId, 'cantidad': i.cantidad})
            .toList(),
    };
    final json = await _api.put(
      '/promociones/combos/$id',
      authenticated: true,
      body: body,
    );
    return ComboModel.fromJson(json);
  }

  Future<void> deleteCombo(int id) async {
    await _api.delete('/promociones/combos/$id', authenticated: true);
  }
}

class ComboItemInput {
  const ComboItemInput({required this.productoId, required this.cantidad});
  final int productoId;
  final int cantidad;
}

class ComboItemModel {
  const ComboItemModel({
    required this.id,
    required this.productoId,
    required this.cantidad,
    this.producto,
  });

  factory ComboItemModel.fromJson(Map<String, dynamic> json) {
    final producto = json['producto'] as Map<String, dynamic>?;
    return ComboItemModel(
      id: json['id'] as int,
      productoId: json['productoId'] as int? ??
          json['producto_id'] as int? ??
          (producto?['id'] as int? ?? 0),
      cantidad: json['cantidad'] as int? ?? 1,
      producto: producto == null
          ? null
          : ProductoModel.fromJson({
              ...producto,
              'comercioId': producto['comercioId'] ??
                  producto['comercio_id'] ??
                  json['comercioId'] ??
                  0,
            }),
    );
  }

  final int id;
  final int productoId;
  final int cantidad;
  final ProductoModel? producto;
}

class ComboModel {
  const ComboModel({
    required this.id,
    required this.comercioId,
    required this.nombre,
    required this.precio,
    this.descripcion,
    this.imagen,
    this.activo = true,
    this.items = const [],
  });

  factory ComboModel.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>?) ?? const [];
    return ComboModel(
      id: json['id'] as int,
      comercioId: json['comercioId'] as int? ?? json['comercio_id'] as int? ?? 0,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      precio: double.parse(json['precio'].toString()),
      imagen: json['imagen'] as String?,
      activo: json['activo'] as bool? ?? true,
      items: items
          .map((e) => ComboItemModel.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
    );
  }

  final int id;
  final int comercioId;
  final String nombre;
  final String? descripcion;
  final double precio;
  final String? imagen;
  final bool activo;
  final List<ComboItemModel> items;

  String get imageUrl => ApiConfig.resolveImageUrl(imagen);
  String get precioLabel => '\$${precio.toStringAsFixed(0)}';
}
