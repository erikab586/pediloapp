import 'dart:convert';
import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../cliente/data/models/catalog_models.dart';

class ComercioFormRepository {
  ComercioFormRepository(this._api);

  final ApiClient _api;

  Future<List<CategoriaModel>> getCategorias() async {
    final json = await _api.get('/categorias/show', queryParameters: {
      'limit': '50',
    });
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((item) => CategoriaModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ComercioModel> createComercio({
    required int categoriaId,
    required String name,
    String? telefono,
    String? direccion,
    String? descripcion,
    List<String>? metodosPago,
    List<String>? tiposEntrega,
    Uint8List? logoBytes,
    Uint8List? portadaBytes,
  }) async {
    final json = await _api.postMultipart(
      '/comercios/register',
      fields: _fields(
        categoriaId: categoriaId,
        name: name,
        telefono: telefono,
        direccion: direccion,
        descripcion: descripcion,
        metodosPago: metodosPago,
        tiposEntrega: tiposEntrega,
      ),
      files: _files(logoBytes: logoBytes, portadaBytes: portadaBytes),
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
    String? descripcion,
    bool? estaAbierto,
    List<String>? metodosPago,
    List<String>? tiposEntrega,
    Uint8List? logoBytes,
    Uint8List? portadaBytes,
  }) async {
    final fields = _fields(
      categoriaId: categoriaId,
      name: name,
      telefono: telefono,
      direccion: direccion,
      descripcion: descripcion,
      estaAbierto: estaAbierto,
      metodosPago: metodosPago,
      tiposEntrega: tiposEntrega,
    );

    final files = _files(logoBytes: logoBytes, portadaBytes: portadaBytes);

    final json = files == null
        ? await _api.put('/comercios/$id', authenticated: true, body: {
            if (categoriaId != null) 'categoriaId': categoriaId,
            if (name != null) 'name': name,
            if (telefono != null) 'telefono': telefono,
            if (direccion != null) 'direccion': direccion,
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

  Map<String, String> _fields({
    int? categoriaId,
    String? name,
    String? telefono,
    String? direccion,
    String? descripcion,
    bool? estaAbierto,
    List<String>? metodosPago,
    List<String>? tiposEntrega,
  }) {
    return {
      if (categoriaId != null) 'categoriaId': '$categoriaId',
      if (name != null) 'name': name,
      if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
      if (direccion != null && direccion.isNotEmpty) 'direccion': direccion,
      if (descripcion != null && descripcion.isNotEmpty)
        'descripcion': descripcion,
      if (estaAbierto != null) 'estaAbierto': estaAbierto.toString(),
      if (metodosPago != null && metodosPago.isNotEmpty)
        'metodosPago': jsonEncode(metodosPago),
      if (tiposEntrega != null && tiposEntrega.isNotEmpty)
        'tiposEntrega': jsonEncode(tiposEntrega),
    };
  }

  Map<String, MultipartFileData>? _files({
    Uint8List? logoBytes,
    Uint8List? portadaBytes,
  }) {
    final files = <String, MultipartFileData>{};
    if (logoBytes != null) {
      files['logo'] = MultipartFileData(bytes: logoBytes, filename: 'logo.jpg');
    }
    if (portadaBytes != null) {
      files['portada'] =
          MultipartFileData(bytes: portadaBytes, filename: 'portada.jpg');
    }
    return files.isEmpty ? null : files;
  }
}
