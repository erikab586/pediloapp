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
    this.categoriaId,
    this.categoriaNombre,
    this.horarios,
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
      categoriaId: json['categoriaId'] != null
          ? parseJsonInt(json['categoriaId'])
          : (categoria?['id'] != null
              ? parseJsonInt(categoria!['id'])
              : null),
      categoriaNombre: categoria?['nombreCategoria'] as String?,
      horarios: parseJsonMap(json['horarios']),
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
  final int? categoriaId;
  final String? categoriaNombre;
  final Map<String, dynamic>? horarios;
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

  ComercioModel copyWith({
    String? name,
    String? logo,
    String? portada,
    String? descripcion,
    String? direccion,
    String? telefono,
    bool? estaAbierto,
    int? categoriaId,
    String? categoriaNombre,
    Map<String, dynamic>? horarios,
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
      categoriaId: categoriaId ?? this.categoriaId,
      categoriaNombre: categoriaNombre ?? this.categoriaNombre,
      horarios: horarios ?? this.horarios,
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
        json['idCategoriaProducto'] ??
            json['id_categoria_producto'] ??
            json['id'],
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

  String get label => '$rubro — $descripcion';

  String get imageUrl => ApiConfig.resolveImageUrl(imagen);
}

class ProductoModel {
  const ProductoModel({
    required this.id,
    required this.comercioId,
    required this.nombre,
    required this.precio,
    this.descripcion,
    this.imagen,
    this.categoriaProductoId,
    this.categoriaNombre,
    this.categoriaRubro,
    this.cantidad = 0,
    required this.activo,
  });

  factory ProductoModel.fromJson(Map<String, dynamic> json) {
    final categoriaProducto =
        json['categoriaProducto'] as Map<String, dynamic>?;
    final categoria = json['categoria'] as Map<String, dynamic>?;
    final cpId = json['categoriaProductoId'] as int? ??
        json['id_categoria_producto'] as int? ??
        categoriaProducto?['idCategoriaProducto'] as int? ??
        json['categoriaId'] as int? ??
        categoria?['id'] as int?;
    final cpDescripcion = categoriaProducto?['descripcion'] as String?;
    final cpRubro = categoriaProducto?['rubro'] as String?;

    return ProductoModel(
      id: json['id'] as int,
      comercioId: json['comercioId'] as int,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      precio: double.parse(json['precio'].toString()),
      imagen: json['imagen'] as String?,
      categoriaProductoId: cpId,
      categoriaNombre: cpDescripcion ?? categoria?['nombreCategoria'] as String?,
      categoriaRubro: cpRubro,
      cantidad: json['cantidad'] as int? ?? 0,
      activo: json['activo'] as bool? ?? true,
    );
  }

  final int id;
  final int comercioId;
  final String nombre;
  final String? descripcion;
  final double precio;
  final String? imagen;
  final int? categoriaProductoId;
  final String? categoriaNombre;
  final String? categoriaRubro;
  final int cantidad;
  final bool activo;

  int? get categoriaId => categoriaProductoId;

  String get imageUrl => ApiConfig.resolveImageUrl(imagen);

  String get precioLabel => '\$${precio.toStringAsFixed(0)}';

  String get categoriaLabel {
    if (categoriaRubro != null && categoriaNombre != null) {
      return '$categoriaRubro — $categoriaNombre';
    }
    return categoriaNombre ?? 'Sin categoría';
  }
}
