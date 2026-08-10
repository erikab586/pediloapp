import 'dart:typed_data';

import '../../../core/models/api_models.dart';
import '../../../core/network/api_client.dart';
import '../../cliente/data/models/catalog_models.dart';

class CategoriaRepository {
  CategoriaRepository(this._api);

  final ApiClient _api;

  Future<List<CategoriaModel>> getCategorias({int limit = 100}) async {
    final json = await _api.get('/categorias/show', queryParameters: {
      'limit': '$limit',
    });
    final page = PaginatedResponse.fromJson(json, CategoriaModel.fromJson);
    return page.data;
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
}
