import '../../../../core/config/api_config.dart';
import '../../../../core/utils/json_parse.dart';

class ComercioModel {
  const ComercioModel({
    required this.id,
    required this.name,
    this.logo,
    this.portada,
    this.descripcion,
    this.direccion,
    this.telefono,
    required this.estaAbierto,
    this.estaAbiertoManual,
    this.horarioAutomatico = false,
    this.categoriaId,
    this.categoriaNombre,
    this.horarios,
    this.tiempoEntregaMin,
    this.tiempoEntregaMax,
    this.montoMinimo = 0,
    this.tiposEntrega = const [],
    this.metodosPago = const [],
    this.aprobado = true,
    this.estatus,
  });

  factory ComercioModel.fromJson(Map<String, dynamic> json) {
    final categoria = parseJsonMap(json['categoria']);
    final estatus = json['estatus']?.toString();
    final aprobado = estatus != null && estatus.isNotEmpty
        ? estatus == 'aprobado' || estatus == 'activo'
        : parseJsonBool(json['aprobado'], defaultValue: true);

    return ComercioModel(
      id: parseJsonInt(json['id']),
      name: json['name'] as String? ?? '',
      logo: json['logo'] as String?,
      portada: json['portada'] as String?,
      descripcion: json['descripcion'] as String?,
      direccion: json['direccion'] as String?,
      telefono: json['telefono'] as String?,
      estaAbierto: parseJsonBool(json['estaAbierto']),
      estaAbiertoManual: json.containsKey('estaAbiertoManual')
          ? parseJsonBool(json['estaAbiertoManual'])
          : null,
      horarioAutomatico: parseJsonBool(json['horarioAutomatico']),
      categoriaId: json['categoriaId'] != null
          ? parseJsonInt(json['categoriaId'])
          : (categoria?['id'] != null
              ? parseJsonInt(categoria!['id'])
              : null),
      categoriaNombre: categoria?['nombreCategoria'] as String?,
      horarios: parseJsonMap(json['horarios']),
      tiempoEntregaMin: json['tiempoEntregaMin'] != null
          ? parseJsonInt(json['tiempoEntregaMin'])
          : null,
      tiempoEntregaMax: json['tiempoEntregaMax'] != null
          ? parseJsonInt(json['tiempoEntregaMax'])
          : null,
      montoMinimo: parseJsonDouble(json['montoMinimo']),
      tiposEntrega: parseJsonStringList(json['tiposEntrega']),
      metodosPago: parseJsonStringList(json['metodosPago']),
      aprobado: aprobado,
      estatus: estatus,
    );
  }

  final int id;
  final String name;
  final String? logo;
  final String? portada;
  final String? descripcion;
  final String? direccion;
  final String? telefono;
  final bool estaAbierto;
  final bool? estaAbiertoManual;
  final bool horarioAutomatico;
  final int? categoriaId;
  final String? categoriaNombre;
  final Map<String, dynamic>? horarios;
  final int? tiempoEntregaMin;
  final int? tiempoEntregaMax;
  final double montoMinimo;
  final List<String> tiposEntrega;
  final List<String> metodosPago;
  final bool aprobado;
  final String? estatus;

  /// Puede abrir/cerrar local (estatus público).
  bool get canToggleAbierto =>
      aprobado || estatus == 'aprobado' || estatus == 'activo';

  String get imageUrl => ApiConfig.resolveImageUrl(portada ?? logo);

  String get logoUrl => ApiConfig.resolveImageUrl(logo);

  String get categoryLabel => categoriaNombre ?? 'Comercio';

  String get statusLabel =>
      estaAbierto ? 'Abierto ahora' : 'Cerrado temporalmente';

  /// Ej: "25-40 min" o "30 min".
  String? get etaLabel {
    if (tiempoEntregaMin == null && tiempoEntregaMax == null) return null;
    if (tiempoEntregaMin != null &&
        tiempoEntregaMax != null &&
        tiempoEntregaMin != tiempoEntregaMax) {
      return '$tiempoEntregaMin-$tiempoEntregaMax min';
    }
    final only = tiempoEntregaMax ?? tiempoEntregaMin;
    return only != null ? '$only min' : null;
  }

  String? get montoMinimoLabel {
    if (montoMinimo <= 0) return null;
    final whole = montoMinimo == montoMinimo.roundToDouble();
    final amount =
        whole ? montoMinimo.toInt().toString() : montoMinimo.toStringAsFixed(2);
    return 'Gs. $amount';
  }

  ComercioModel copyWith({
    String? name,
    String? logo,
    String? portada,
    String? descripcion,
    String? direccion,
    String? telefono,
    bool? estaAbierto,
    bool? estaAbiertoManual,
    bool? horarioAutomatico,
    int? categoriaId,
    String? categoriaNombre,
    Map<String, dynamic>? horarios,
    int? tiempoEntregaMin,
    int? tiempoEntregaMax,
    double? montoMinimo,
    List<String>? tiposEntrega,
    List<String>? metodosPago,
    bool? aprobado,
    String? estatus,
  }) {
    return ComercioModel(
      id: id,
      name: name ?? this.name,
      logo: logo ?? this.logo,
      portada: portada ?? this.portada,
      descripcion: descripcion ?? this.descripcion,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      estaAbierto: estaAbierto ?? this.estaAbierto,
      estaAbiertoManual: estaAbiertoManual ?? this.estaAbiertoManual,
      horarioAutomatico: horarioAutomatico ?? this.horarioAutomatico,
      categoriaId: categoriaId ?? this.categoriaId,
      categoriaNombre: categoriaNombre ?? this.categoriaNombre,
      horarios: horarios ?? this.horarios,
      tiempoEntregaMin: tiempoEntregaMin ?? this.tiempoEntregaMin,
      tiempoEntregaMax: tiempoEntregaMax ?? this.tiempoEntregaMax,
      montoMinimo: montoMinimo ?? this.montoMinimo,
      tiposEntrega: tiposEntrega ?? this.tiposEntrega,
      metodosPago: metodosPago ?? this.metodosPago,
      aprobado: aprobado ?? this.aprobado,
      estatus: estatus ?? this.estatus,
    );
  }
}

class CategoriaModel {
  const CategoriaModel({
    required this.id,
    required this.nombreCategoria,
    this.imagenCategoria,
    this.activo = true,
  });

  factory CategoriaModel.fromJson(Map<String, dynamic> json) {
    return CategoriaModel(
      id: json['id'] as int,
      nombreCategoria: json['nombreCategoria'] as String,
      imagenCategoria: json['imagenCategoria'] as String?,
      activo: json['activo'] as bool? ?? true,
    );
  }

  final int id;
  final String nombreCategoria;
  final String? imagenCategoria;
  final bool activo;

  String get imageUrl => ApiConfig.resolveImageUrl(imagenCategoria);
}

class CategoriaProductoModel {
  const CategoriaProductoModel({
    required this.idCategoriaProducto,
    required this.descripcion,
    required this.rubro,
    this.imagen,
  });

  factory CategoriaProductoModel.fromJson(Map<String, dynamic> json) {
    return CategoriaProductoModel(
      idCategoriaProducto: parseJsonInt(
        json['idCategoriaProducto'] ?? json['id'],
      ),
      descripcion: json['descripcion'] as String? ?? '',
      rubro: json['rubro'] as String? ?? '',
      imagen: json['imagen'] as String?,
    );
  }

  final int idCategoriaProducto;
  final String descripcion;
  final String rubro;
  final String? imagen;

  String get imageUrl => ApiConfig.resolveImageUrl(imagen);

  String get label =>
      rubro.isNotEmpty ? '$descripcion · $rubro' : descripcion;
}

class DetalleProductoModel {
  const DetalleProductoModel({
    required this.id,
    required this.productoId,
    required this.titulo,
    this.descripcion,
    this.imagen,
    this.activo = true,
  });

  factory DetalleProductoModel.fromJson(Map<String, dynamic> json) {
    return DetalleProductoModel(
      id: parseJsonInt(json['id']),
      productoId: parseJsonInt(json['productoId'] ?? json['id_producto'] ?? 0),
      titulo: json['titulo'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      imagen: json['imagen'] as String?,
      activo: parseJsonBool(json['activo'], defaultValue: true),
    );
  }

  final int id;
  final int productoId;
  final String titulo;
  final String? descripcion;
  final String? imagen;
  final bool activo;

  String get imageUrl => ApiConfig.resolveImageUrl(imagen);

  DetalleProductoModel copyWith({
    String? titulo,
    String? descripcion,
    String? imagen,
    bool? activo,
  }) {
    return DetalleProductoModel(
      id: id,
      productoId: productoId,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      imagen: imagen ?? this.imagen,
      activo: activo ?? this.activo,
    );
  }
}

class OpcionalModel {
  const OpcionalModel({
    required this.id,
    required this.productoId,
    required this.nombre,
    required this.precio,
    this.descripcion,
    this.imagen,
    this.activo = true,
  });

  factory OpcionalModel.fromJson(Map<String, dynamic> json) {
    return OpcionalModel(
      id: parseJsonInt(json['id']),
      productoId: parseJsonInt(json['productoId'] ?? json['id_producto'] ?? 0),
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      precio: parseJsonDouble(json['precio']),
      imagen: json['imagen'] as String?,
      activo: parseJsonBool(json['activo'], defaultValue: true),
    );
  }

  final int id;
  final int productoId;
  final String nombre;
  final String? descripcion;
  final double precio;
  final String? imagen;
  final bool activo;

  String get imageUrl => ApiConfig.resolveImageUrl(imagen);

  String get precioLabel => '\$${precio.toStringAsFixed(0)}';
}

class ExtraModel {
  const ExtraModel({
    required this.id,
    required this.productoId,
    required this.nombre,
    required this.precio,
    this.descripcion,
    this.imagen,
    this.activo = true,
  });

  factory ExtraModel.fromJson(Map<String, dynamic> json) {
    return ExtraModel(
      id: parseJsonInt(json['id']),
      productoId: parseJsonInt(json['productoId'] ?? json['id_producto'] ?? 0),
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      precio: parseJsonDouble(json['precio']),
      imagen: json['imagen'] as String?,
      activo: parseJsonBool(json['activo'], defaultValue: true),
    );
  }

  final int id;
  final int productoId;
  final String nombre;
  final String? descripcion;
  final double precio;
  final String? imagen;
  final bool activo;

  String get imageUrl => ApiConfig.resolveImageUrl(imagen);

  String get precioLabel => '\$${precio.toStringAsFixed(0)}';
}

class ProductoModel {
  const ProductoModel({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.precio,
    this.imagen,
    this.cantidad,
    this.activo = true,
    this.comercioId,
    this.comercioNombre,
    this.categoriaProductoId,
    this.categoriaProducto,
    this.detalles = const [],
    this.opcionales = const [],
    this.extras = const [],
    this.promocion,
  });

  factory ProductoModel.fromJson(Map<String, dynamic> json) {
    final cat = parseJsonMap(json['categoriaProducto']);
    final comercio = parseJsonMap(json['comercio']);
    final detallesRaw = json['detalles'];
    final detalles = detallesRaw is List
        ? detallesRaw
            .whereType<Map>()
            .map(
              (e) => DetalleProductoModel.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList()
        : <DetalleProductoModel>[];
    final opcionalesRaw = json['opcionales'];
    final opcionales = opcionalesRaw is List
        ? opcionalesRaw
            .whereType<Map>()
            .map(
              (e) => OpcionalModel.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList()
        : <OpcionalModel>[];
    final extrasRaw = json['extras'];
    final extras = extrasRaw is List
        ? extrasRaw
            .whereType<Map>()
            .map((e) => ExtraModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <ExtraModel>[];

    final promoRaw = parseJsonMap(json['promocion']);

    return ProductoModel(
      id: parseJsonInt(json['id']),
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      precio: json['precio'] != null ? parseJsonDouble(json['precio']) : null,
      imagen: json['imagen'] as String?,
      cantidad: json['cantidad'] != null ? parseJsonInt(json['cantidad']) : null,
      activo: parseJsonBool(json['activo'], defaultValue: true),
      comercioId:
          json['comercioId'] != null ? parseJsonInt(json['comercioId']) : null,
      comercioNombre: json['comercioNombre'] as String? ??
          comercio?['name'] as String?,
      categoriaProductoId: json['categoriaProductoId'] != null
          ? parseJsonInt(json['categoriaProductoId'])
          : null,
      categoriaProducto:
          cat != null ? CategoriaProductoModel.fromJson(cat) : null,
      detalles: detalles,
      opcionales: opcionales,
      extras: extras,
      promocion:
          promoRaw != null ? PromocionModel.fromJson(promoRaw) : null,
    );
  }

  final int id;
  final String nombre;
  final String? descripcion;
  final double? precio;
  final String? imagen;
  final int? cantidad;
  final bool activo;
  final int? comercioId;
  final String? comercioNombre;
  final int? categoriaProductoId;
  final CategoriaProductoModel? categoriaProducto;
  final List<DetalleProductoModel> detalles;
  final List<OpcionalModel> opcionales;
  final List<ExtraModel> extras;
  /// Promo vigente asignada a este producto (solo afecta su precio).
  final PromocionModel? promocion;

  String get imageUrl => ApiConfig.resolveImageUrl(imagen);

  String get categoriaLabel =>
      categoriaProducto?.label ?? 'Sin categoría';

  double get precioValue => precio ?? 0;

  bool get tienePromocion => promocion != null && promocion!.isVigente;

  String? get promoBadgeLabel =>
      tienePromocion ? promocion!.badgeLabel : null;

  String get precioLabel => '\$${precioValue.toStringAsFixed(0)}';

  List<DetalleProductoModel> get detallesActivos =>
      detalles.where((d) => d.activo).toList();

  List<OpcionalModel> get opcionalesActivos =>
      opcionales.where((o) => o.activo).toList();

  List<ExtraModel> get extrasActivos =>
      extras.where((e) => e.activo).toList();

  bool get requiereOpcional => opcionalesActivos.isNotEmpty;

  ProductoModel copyWith({
    PromocionModel? promocion,
    bool clearPromocion = false,
    List<DetalleProductoModel>? detalles,
    List<OpcionalModel>? opcionales,
    List<ExtraModel>? extras,
  }) {
    return ProductoModel(
      id: id,
      nombre: nombre,
      descripcion: descripcion,
      precio: precio,
      imagen: imagen,
      cantidad: cantidad,
      activo: activo,
      comercioId: comercioId,
      comercioNombre: comercioNombre,
      categoriaProductoId: categoriaProductoId,
      categoriaProducto: categoriaProducto,
      detalles: detalles ?? this.detalles,
      opcionales: opcionales ?? this.opcionales,
      extras: extras ?? this.extras,
      promocion: clearPromocion ? null : (promocion ?? this.promocion),
    );
  }
}

/// Cupón global (tabla `cupones`) para banners del home.
class CuponModel {
  const CuponModel({
    required this.id,
    required this.codigo,
    required this.tipo,
    required this.valor,
    this.descripcion,
    this.minCompra = 0,
    this.activo = true,
  });

  factory CuponModel.fromJson(Map<String, dynamic> json) {
    return CuponModel(
      id: parseJsonInt(json['id']),
      codigo: json['codigo'] as String? ?? '',
      tipo: json['tipo']?.toString() ?? 'Porcentaje',
      valor: parseJsonDouble(json['valor']),
      descripcion: json['descripcion'] as String?,
      minCompra: parseJsonDouble(json['minCompra'] ?? json['min_compra']),
      activo: parseJsonBool(json['activo'], defaultValue: true),
    );
  }

  final int id;
  final String codigo;
  final String tipo;
  final double valor;
  final String? descripcion;
  final double minCompra;
  final bool activo;

  String get headline =>
      codigo.isNotEmpty ? codigo : (descripcion?.trim().isNotEmpty == true
          ? descripcion!.trim()
          : 'Cupón');
}

class ValoracionModel {
  const ValoracionModel({
    required this.id,
    required this.calificacion,
    this.comentario,
    this.usuarioNombre,
    this.comercioId,
    this.productoId,
    this.createdAt,
  });

  factory ValoracionModel.fromJson(Map<String, dynamic> json) {
    final usuario = parseJsonMap(json['usuario']);
    return ValoracionModel(
      id: parseJsonInt(json['id']),
      calificacion: parseJsonInt(json['calificacion']),
      comentario: json['comentario'] as String?,
      usuarioNombre: usuario?['name'] as String? ??
          json['usuarioNombre'] as String?,
      comercioId: json['comercioId'] != null
          ? parseJsonInt(json['comercioId'])
          : null,
      productoId: json['productoId'] != null
          ? parseJsonInt(json['productoId'])
          : null,
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString(),
    );
  }

  final int id;
  final int calificacion;
  final String? comentario;
  final String? usuarioNombre;
  final int? comercioId;
  final int? productoId;
  final String? createdAt;
}

class PromocionModel {
  const PromocionModel({
    required this.id,
    required this.comercioId,
    required this.nombre,
    required this.tipo,
    required this.valor,
    this.productoId,
    this.descripcion,
    this.ejemplo,
    this.valorSecundario,
    this.activo = true,
    this.fechaInicio,
    this.fechaFin,
  });

  factory PromocionModel.fromJson(Map<String, dynamic> json) {
    return PromocionModel(
      id: parseJsonInt(json['id']),
      comercioId: parseJsonInt(json['comercioId'] ?? json['comercio_id'] ?? 0),
      productoId: json['productoId'] != null || json['producto_id'] != null
          ? parseJsonInt(json['productoId'] ?? json['producto_id'])
          : null,
      nombre: json['nombre'] as String? ?? '',
      tipo: json['tipo'] as String? ?? 'descuento_porcentual',
      valor: parseJsonDouble(json['valor']),
      valorSecundario: json['valorSecundario'] != null
          ? parseJsonDouble(json['valorSecundario'])
          : (json['valor_secundario'] != null
              ? parseJsonDouble(json['valor_secundario'])
              : null),
      descripcion: json['descripcion'] as String?,
      ejemplo: json['ejemplo'] as String?,
      activo: parseJsonBool(json['activo'], defaultValue: true),
      fechaInicio: json['fechaInicio']?.toString() ?? json['fecha_inicio']?.toString(),
      fechaFin: json['fechaFin']?.toString() ?? json['fecha_fin']?.toString(),
    );
  }

  final int id;
  final int comercioId;
  final int? productoId;
  final String nombre;
  final String tipo;
  final double valor;
  final double? valorSecundario;
  final String? descripcion;
  final String? ejemplo;
  final bool activo;
  final String? fechaInicio;
  final String? fechaFin;

  bool get isVigente {
    if (!activo) return false;
    final now = DateTime.now();
    if (fechaInicio != null && fechaInicio!.isNotEmpty) {
      final start = DateTime.tryParse(fechaInicio!);
      if (start != null && now.isBefore(start)) return false;
    }
    if (fechaFin != null && fechaFin!.isNotEmpty) {
      final end = DateTime.tryParse(fechaFin!);
      if (end != null && now.isAfter(end)) return false;
    }
    return true;
  }

  String get badgeLabel {
    if (ejemplo != null && ejemplo!.trim().isNotEmpty) {
      return ejemplo!.trim();
    }
    final t = tipo.toLowerCase();
    if (t.contains('porcent') || t == 'liquidacion') {
      return '-${valor.toStringAsFixed(0)}%';
    }
    if (t.contains('fijo') || t == 'descuento_fijo') {
      return '-\$${valor.toStringAsFixed(0)}';
    }
    if (t.contains('precio_promocional')) {
      return '\$${valor.toStringAsFixed(0)}';
    }
    if (t == '2x1' || t.contains('dos')) return '2x1';
    if (t == '3x2') return '3x2';
    if (t == 'n_x_m') {
      final n = valor.round();
      final m = (valorSecundario ?? 1).round();
      return '${n}x$m';
    }
    if (nombre.isNotEmpty) return nombre;
    return 'PROMO';
  }

  String get valorLabel {
    if (descripcion != null && descripcion!.trim().isNotEmpty) {
      return descripcion!.trim();
    }
    return badgeLabel;
  }
}
