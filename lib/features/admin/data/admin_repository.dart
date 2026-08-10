import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/utils/json_parse.dart';
import '../../cliente/data/models/catalog_models.dart';

class AdminUserModel {
  const AdminUserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.activo = true,
  });

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    final role = parseJsonMap(json['role']);
    return AdminUserModel(
      id: parseJsonInt(json['id']),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      role: role?['rol'] as String? ?? json['role'] as String? ?? 'cliente',
      activo: parseJsonBool(json['activo'], defaultValue: true),
    );
  }

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final bool activo;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get roleLabel => switch (role) {
        'administrador' => 'Administrador',
        'comerciante' => 'Comerciante',
        _ => 'Cliente',
      };

  String get statusLabel => activo ? 'Activo' : 'Suspendido';

  bool get canBeSuspended => role != 'administrador';
}

class AdminComercioModel extends ComercioModel {
  const AdminComercioModel({
    required super.id,
    required super.name,
    super.logo,
    super.portada,
    super.descripcion,
    super.direccion,
    super.telefono,
    required super.estaAbierto,
    super.categoriaId,
    super.categoriaNombre,
    required super.aprobado,
    super.estatus = 'pendiente',
    this.comercianteId,
    this.comercianteNombre,
    this.comercianteEmail,
    super.metodosPago,
    super.tiposEntrega,
    super.horarios,
  });

  factory AdminComercioModel.fromJson(Map<String, dynamic> json) {
    final categoria = parseJsonMap(json['categoria']);
    final comerciante = parseJsonMap(json['comerciante']);
    final estatus = _parseEstatus(json);
    final isPublic = estatus == 'aprobado' || estatus == 'activo';
    return AdminComercioModel(
      id: parseJsonInt(json['id']),
      name: json['name'] as String? ?? '',
      logo: json['logo'] as String?,
      portada: json['portada'] as String?,
      descripcion: json['descripcion'] as String?,
      direccion: json['direccion'] as String?,
      telefono: json['telefono'] as String?,
      estaAbierto: parseJsonBool(json['estaAbierto']),
      categoriaId: json['categoriaId'] != null
          ? parseJsonInt(json['categoriaId'])
          : (categoria?['id'] != null
              ? parseJsonInt(categoria!['id'])
              : null),
      categoriaNombre: categoria?['nombreCategoria'] as String?,
      aprobado: isPublic,
      estatus: estatus,
      comercianteId: json['comercianteId'] != null
          ? parseJsonInt(json['comercianteId'])
          : (comerciante?['id'] != null
              ? parseJsonInt(comerciante!['id'])
              : null),
      comercianteNombre: comerciante?['name'] as String?,
      comercianteEmail: comerciante?['email'] as String?,
      metodosPago: parseJsonStringList(json['metodosPago']),
      tiposEntrega: parseJsonStringList(json['tiposEntrega']),
      horarios: parseJsonMap(json['horarios']),
    );
  }

  /// Compatible con API nueva (`estatus`) y dumps viejos (`aprobado` bool).
  static String _parseEstatus(Map<String, dynamic> json) {
    final raw = json['estatus']?.toString().trim();
    if (raw != null && raw.isNotEmpty) return raw;
    if (json.containsKey('aprobado')) {
      return parseJsonBool(json['aprobado']) ? 'activo' : 'pendiente';
    }
    return 'pendiente';
  }

  final int? comercianteId;
  final String? comercianteNombre;
  final String? comercianteEmail;

  String get estatusValue => estatus ?? 'pendiente';

  bool get isPublic =>
      estatusValue == 'aprobado' || estatusValue == 'activo';

  bool get canAprobar =>
      estatusValue == 'pendiente' ||
      estatusValue == 'suspendido' ||
      estatusValue == 'inactivo' ||
      estatusValue == 'eliminado';

  bool get canSuspender => isPublic;

  @override
  String get statusLabel => switch (estatusValue) {
        'pendiente' => 'Sin aprobar',
        'aprobado' => estaAbierto ? 'Activo' : 'Cerrado',
        'activo' => estaAbierto ? 'Activo' : 'Cerrado',
        'inactivo' => 'Inactivo',
        'suspendido' => 'Suspendido',
        'eliminado' => 'Eliminado',
        _ => estatusValue,
      };
}

class GlobalStatsModel {
  const GlobalStatsModel({
    required this.ventasTotales,
    required this.pedidosTotales,
    required this.ticketPromedio,
    required this.topComercios,
  });

  factory GlobalStatsModel.fromJson(Map<String, dynamic> json) {
    final top = parseJsonMapList(json['topComercios'])
        .map(TopComercioStat.fromJson)
        .toList();

    return GlobalStatsModel(
      ventasTotales: parseJsonDouble(json['ventasTotales']),
      pedidosTotales: parseJsonInt(json['pedidosTotales']),
      ticketPromedio: parseJsonDouble(json['ticketPromedioGlobal']),
      topComercios: top,
    );
  }

  final double ventasTotales;
  final int pedidosTotales;
  final double ticketPromedio;
  final List<TopComercioStat> topComercios;

  String get ventasLabel => '\$${ventasTotales.toStringAsFixed(0)}';
}

class TopComercioStat {
  const TopComercioStat({
    required this.comercioId,
    required this.nombre,
    required this.total,
  });

  factory TopComercioStat.fromJson(Map<String, dynamic> json) {
    return TopComercioStat(
      comercioId: int.tryParse(json['comercioId']?.toString() ?? '0') ?? 0,
      nombre: json['nombre'] as String? ?? 'Comercio',
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
    );
  }

  final int comercioId;
  final String nombre;
  final double total;

  String get totalLabel => '\$${total.toStringAsFixed(0)}';
}

/// Porcentaje de comisión de plataforma sobre ventas (sin endpoint dedicado).
const double kAdminComisionPorcentaje = 8.0;

class AdminReportModel {
  const AdminReportModel({
    required this.stats,
    required this.ventasPeriodo,
    required this.pedidosPeriodo,
    required this.ticketPeriodo,
    required this.series,
    required this.topProductos,
    required this.topCategorias,
    required this.cancelaciones,
    required this.clientesFrecuentes,
    required this.metodosPago,
  });

  final GlobalStatsModel stats;
  final double ventasPeriodo;
  final int pedidosPeriodo;
  final double ticketPeriodo;
  final List<DailyStatModel> series;
  final List<TopProductoStat> topProductos;
  final List<TopCategoriaStat> topCategorias;
  final CancelacionesStat cancelaciones;
  final List<ClienteFrecuenteStat> clientesFrecuentes;
  final List<MetodoPagoStat> metodosPago;

  double get comisionesGeneradas =>
      ventasPeriodo * kAdminComisionPorcentaje / 100;

  String get ventasPeriodoLabel => '\$${ventasPeriodo.toStringAsFixed(0)}';
}

class DailyStatModel {
  const DailyStatModel({
    required this.fecha,
    required this.totalVentas,
    required this.cantidadPedidos,
    this.pedidosCancelados = 0,
  });

  factory DailyStatModel.fromJson(Map<String, dynamic> json) {
    return DailyStatModel(
      fecha: json['fecha'] as String? ?? '',
      totalVentas: double.tryParse(json['totalVentas']?.toString() ?? '0') ?? 0,
      cantidadPedidos:
          int.tryParse(json['cantidadPedidos']?.toString() ?? '0') ?? 0,
      pedidosCancelados:
          int.tryParse(json['pedidosCancelados']?.toString() ?? '0') ?? 0,
    );
  }

  final String fecha;
  final double totalVentas;
  final int cantidadPedidos;
  final int pedidosCancelados;
}

class TopProductoStat {
  const TopProductoStat({
    required this.productoId,
    required this.nombre,
    required this.comercioNombre,
    required this.cantidadVendida,
    required this.total,
  });

  factory TopProductoStat.fromJson(Map<String, dynamic> json) {
    return TopProductoStat(
      productoId: int.tryParse(json['productoId']?.toString() ?? '0') ?? 0,
      nombre: json['nombre'] as String? ?? 'Producto',
      comercioNombre: json['comercioNombre'] as String? ?? 'Comercio',
      cantidadVendida:
          int.tryParse(json['cantidadVendida']?.toString() ?? '0') ?? 0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
    );
  }

  final int productoId;
  final String nombre;
  final String comercioNombre;
  final int cantidadVendida;
  final double total;
}

class TopCategoriaStat {
  const TopCategoriaStat({
    required this.categoriaId,
    required this.nombre,
    required this.cantidadVendida,
    required this.total,
  });

  factory TopCategoriaStat.fromJson(Map<String, dynamic> json) {
    return TopCategoriaStat(
      categoriaId: int.tryParse(json['categoriaId']?.toString() ?? '0') ?? 0,
      nombre: json['nombre'] as String? ?? 'Sin categoría',
      cantidadVendida:
          int.tryParse(json['cantidadVendida']?.toString() ?? '0') ?? 0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
    );
  }

  final dynamic categoriaId;
  final String nombre;
  final int cantidadVendida;
  final double total;
}

class CancelacionesStat {
  const CancelacionesStat({
    required this.totalCancelados,
    required this.totalPedidos,
    required this.porcentaje,
  });

  factory CancelacionesStat.fromJson(Map<String, dynamic> json) {
    return CancelacionesStat(
      totalCancelados:
          int.tryParse(json['totalCancelados']?.toString() ?? '0') ?? 0,
      totalPedidos: int.tryParse(json['totalPedidos']?.toString() ?? '0') ?? 0,
      porcentaje: double.tryParse(json['porcentaje']?.toString() ?? '0') ?? 0,
    );
  }

  final int totalCancelados;
  final int totalPedidos;
  final double porcentaje;
}

class ClienteFrecuenteStat {
  const ClienteFrecuenteStat({
    required this.usuarioId,
    required this.nombre,
    required this.pedidos,
    required this.totalGastado,
  });

  factory ClienteFrecuenteStat.fromJson(Map<String, dynamic> json) {
    return ClienteFrecuenteStat(
      usuarioId: int.tryParse(json['usuarioId']?.toString() ?? '0') ?? 0,
      nombre: json['nombre'] as String? ?? 'Cliente',
      pedidos: int.tryParse(json['pedidos']?.toString() ?? '0') ?? 0,
      totalGastado:
          double.tryParse(json['totalGastado']?.toString() ?? '0') ?? 0,
    );
  }

  final int usuarioId;
  final String nombre;
  final int pedidos;
  final double totalGastado;
}

class MetodoPagoStat {
  const MetodoPagoStat({
    required this.metodo,
    required this.cantidad,
    required this.porcentaje,
  });

  factory MetodoPagoStat.fromJson(Map<String, dynamic> json) {
    return MetodoPagoStat(
      metodo: json['metodo'] as String? ?? 'Otro',
      cantidad: int.tryParse(json['cantidad']?.toString() ?? '0') ?? 0,
      porcentaje: int.tryParse(json['porcentaje']?.toString() ?? '0') ?? 0,
    );
  }

  final String metodo;
  final int cantidad;
  final int porcentaje;
}

class CuponModel {
  const CuponModel({
    required this.id,
    required this.codigo,
    required this.tipo,
    required this.valor,
    this.minCompra = 0,
    this.activo = true,
  });

  factory CuponModel.fromJson(Map<String, dynamic> json) {
    return CuponModel(
      id: json['id'] as int,
      codigo: json['codigo'] as String,
      tipo: json['tipo'] as String? ?? 'Porcentaje',
      valor: double.tryParse(json['valor']?.toString() ?? '0') ?? 0,
      minCompra: double.tryParse(json['minCompra']?.toString() ?? '0') ?? 0,
      activo: json['activo'] as bool? ?? true,
    );
  }

  final int id;
  final String codigo;
  final String tipo;
  final double valor;
  final double minCompra;
  final bool activo;

  String get valorLabel => switch (tipo) {
        'Porcentaje' => '${valor.toStringAsFixed(0)}%',
        'Fijo' => '\$${valor.toStringAsFixed(0)}',
        'Envio' => 'Envío gratis',
        _ => '\$${valor.toStringAsFixed(0)}',
      };
}

class AdminRepository {
  AdminRepository(this._api);

  final ApiClient _api;

  Future<List<AdminComercioModel>> getComercios() async {
    final rows = await _api.getList('/admin/comercios', authenticated: true);
    return rows.map(AdminComercioModel.fromJson).toList();
  }

  Future<List<AdminUserModel>> getUsuarios() async {
    final rows = await _api.getList('/admin/usuarios', authenticated: true);
    return rows.map(AdminUserModel.fromJson).toList();
  }

  /// Activa (`true`) o suspende (`false`) un usuario.
  Future<AdminUserModel> setUsuarioActivo(int id, bool activo) async {
    final json = await _api.patch(
      '/admin/usuarios/$id/activo',
      authenticated: true,
      body: {'activo': activo},
    );
    return AdminUserModel.fromJson(json);
  }

  Future<GlobalStatsModel> getGlobalStats() async {
    final json = await _api.get('/estadisticas/global', authenticated: true);
    return GlobalStatsModel.fromJson(json);
  }

  Future<List<DailyStatModel>> getGlobalSeries({String rango = 'mes'}) async {
    final json = await _api.get(
      '/estadisticas/global/series',
      authenticated: true,
      queryParameters: {'rango': rango},
    );
    final series = parseJsonMapList(json['series']);
    return series.map(DailyStatModel.fromJson).toList();
  }

  Future<AdminReportModel> getReport({String rango = 'mes'}) async {
    final results = await Future.wait([
      getGlobalStats(),
      _api.get(
        '/estadisticas/global/series',
        authenticated: true,
        queryParameters: {'rango': rango},
      ),
      _api.get(
        '/estadisticas/global/top-productos',
        authenticated: true,
        queryParameters: {'rango': rango, 'limite': '10'},
      ),
      _api.get(
        '/estadisticas/global/categorias-mas-vendidas',
        authenticated: true,
        queryParameters: {'rango': rango, 'limite': '10'},
      ),
      _api.get(
        '/estadisticas/global/cancelaciones',
        authenticated: true,
        queryParameters: {'rango': rango},
      ),
      _api.get(
        '/estadisticas/global/clientes-frecuentes',
        authenticated: true,
        queryParameters: {'rango': rango, 'limite': '10'},
      ),
      _api.get(
        '/estadisticas/global/metodos-pago',
        authenticated: true,
        queryParameters: {'rango': rango},
      ),
    ]);

    final seriesJson = results[1] as Map<String, dynamic>;
    final topProductosJson = results[2] as Map<String, dynamic>;
    final topCategoriasJson = results[3] as Map<String, dynamic>;
    final cancelacionesJson = results[4] as Map<String, dynamic>;
    final clientesJson = results[5] as Map<String, dynamic>;
    final metodosJson = results[6] as Map<String, dynamic>;
    final totales = seriesJson['totales'] as Map<String, dynamic>? ?? {};

    return AdminReportModel(
      stats: results[0] as GlobalStatsModel,
      ventasPeriodo:
          double.tryParse(totales['ventas']?.toString() ?? '0') ?? 0,
      pedidosPeriodo:
          int.tryParse(totales['pedidos']?.toString() ?? '0') ?? 0,
      ticketPeriodo:
          double.tryParse(totales['ticketPromedio']?.toString() ?? '0') ?? 0,
      series: parseJsonMapList(seriesJson['series'])
          .map(DailyStatModel.fromJson)
          .toList(),
      topProductos: parseJsonMapList(topProductosJson['items'])
          .map(TopProductoStat.fromJson)
          .toList(),
      topCategorias: parseJsonMapList(topCategoriasJson['items'])
          .map(TopCategoriaStat.fromJson)
          .toList(),
      cancelaciones:
          CancelacionesStat.fromJson(cancelacionesJson),
      clientesFrecuentes: parseJsonMapList(clientesJson['items'])
          .map(ClienteFrecuenteStat.fromJson)
          .toList(),
      metodosPago: parseJsonMapList(metodosJson['items'])
          .map(MetodoPagoStat.fromJson)
          .toList(),
    );
  }

  Future<List<CuponModel>> getCupones() async {
    final rows = await _api.getList('/promociones/cupones/show');
    return rows.map(CuponModel.fromJson).toList();
  }

  Future<CuponModel> createCupon({
    required String codigo,
    required String tipo,
    required double valor,
    double? minCompra,
  }) async {
    final json = await _api.post(
      '/promociones/cupones/register',
      authenticated: true,
      body: {
        'codigo': codigo,
        'tipo': tipo,
        'valor': valor,
        if (minCompra != null) 'minCompra': minCompra,
      },
    );
    return CuponModel.fromJson(json);
  }

  /// Cambia el estatus del comercio (solo admin).
  /// Valores: pendiente | aprobado | activo | inactivo | suspendido | eliminado
  Future<AdminComercioModel> setComercioEstatus(
    int id,
    String estatus,
  ) async {
    final json = await _api.patch(
      '/comercios/$id/estatus',
      authenticated: true,
      body: {'estatus': estatus},
    );
    return AdminComercioModel.fromJson(json);
  }

  /// Aprueba (`activo`) o suspende (`suspendido`) un comercio.
  Future<AdminComercioModel> setComercioAprobado(int id, bool aprobado) {
    return setComercioEstatus(id, aprobado ? 'activo' : 'suspendido');
  }

  Future<List<AdminComercioModel>> getComerciosByComerciante(
    int comercianteId,
  ) async {
    final all = await getComercios();
    return all.where((c) => c.comercianteId == comercianteId).toList();
  }

  Future<List<CategoriaModel>> getCategorias() async {
    final json = await _api.get('/categorias/show', queryParameters: {
      'limit': '100',
    });
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((item) => CategoriaModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CategoriaModel> createCategoria({
    required String nombreCategoria,
    bool activo = true,
    Uint8List? imagenBytes,
  }) async {
    final fields = <String, String>{
      'nombreCategoria': nombreCategoria,
      'activo': activo.toString(),
    };

    final files = imagenBytes == null
        ? null
        : {
            'imagen': MultipartFileData(
              bytes: imagenBytes,
              filename: 'categoria.jpg',
            ),
          };

    final json = await _api.postMultipart(
      '/categorias/register',
      fields: fields,
      files: files,
      authenticated: true,
    );
    return CategoriaModel.fromJson(json);
  }

  Future<CategoriaModel> updateCategoria({
    required int id,
    String? nombreCategoria,
    bool? activo,
    Uint8List? imagenBytes,
  }) async {
    final fields = <String, String>{
      if (nombreCategoria != null) 'nombreCategoria': nombreCategoria,
      if (activo != null) 'activo': activo.toString(),
    };

    final files = imagenBytes == null
        ? null
        : {
            'imagen': MultipartFileData(
              bytes: imagenBytes,
              filename: 'categoria.jpg',
            ),
          };

    final json = files == null
        ? await _api.put('/categorias/$id', authenticated: true, body: {
            if (nombreCategoria != null) 'nombreCategoria': nombreCategoria,
            if (activo != null) 'activo': activo,
          })
        : await _api.putMultipart(
            '/categorias/$id',
            fields: fields,
            files: files,
            authenticated: true,
          );

    return CategoriaModel.fromJson(json);
  }

  Future<void> deleteCategoria(int id) async {
    await _api.delete('/categorias/$id', authenticated: true);
  }

  Future<ComercioModel> updateComercio({
    required int id,
    int? categoriaId,
    String? name,
    String? telefono,
    String? direccion,
    String? portada,
    bool? estaAbierto,
    Uint8List? logoBytes,
  }) async {
    final fields = <String, String>{
      if (categoriaId != null) 'categoriaId': '$categoriaId',
      if (name != null) 'name': name,
      if (telefono != null) 'telefono': telefono,
      if (direccion != null) 'direccion': direccion,
      if (portada != null) 'portada': portada,
      if (estaAbierto != null) 'estaAbierto': estaAbierto.toString(),
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
            if (estaAbierto != null) 'estaAbierto': estaAbierto,
          })
        : await _api.putMultipart(
            '/comercios/$id',
            fields: fields,
            files: files,
            authenticated: true,
          );

    return ComercioModel.fromJson(json);
  }
}
