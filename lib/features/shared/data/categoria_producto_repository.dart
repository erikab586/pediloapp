import 'dart:typed_data';

import '../../../core/models/api_models.dart';
import '../../../core/network/api_client.dart';
import '../../cliente/data/models/catalog_models.dart';

class CategoriaProductoRepository {
  CategoriaProductoRepository(this._api);

  final ApiClient _api;

  Future<List<CategoriaProductoModel>> getCategoriasProducto({
    int limit = 100,
    String? rubro,
    String? search,
  }) async {
    final json = await _api.get('/categoria-producto/show', queryParameters: {
      'limit': '$limit',
      if (rubro != null && rubro.isNotEmpty) 'rubro': rubro,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final page =
        PaginatedResponse.fromJson(json, CategoriaProductoModel.fromJson);
    return page.data;
  }

  Future<CategoriaProductoModel> createCategoriaProducto({
    required String descripcion,
    required String rubro,
    Uint8List? imagenBytes,
  }) async {
    final fields = <String, String>{
      'descripcion': descripcion,
      'rubro': rubro,
    };

    final files = imagenBytes == null
        ? null
        : {
            'imagen': MultipartFileData(
              bytes: imagenBytes,
              filename: 'categoria-producto.jpg',
            ),
          };

    final json = files == null
        ? await _api.post(
            '/categoria-producto/register',
            authenticated: true,
            body: fields,
          )
        : await _api.postMultipart(
            '/categoria-producto/register',
            fields: fields,
            files: files,
            authenticated: true,
          );
    return CategoriaProductoModel.fromJson(json);
  }

  Future<CategoriaProductoModel> updateCategoriaProducto({
    required int id,
    String? descripcion,
    String? rubro,
    Uint8List? imagenBytes,
  }) async {
    final fields = <String, String>{
      if (descripcion != null) 'descripcion': descripcion,
      if (rubro != null) 'rubro': rubro,
    };

    final files = imagenBytes == null
        ? null
        : {
            'imagen': MultipartFileData(
              bytes: imagenBytes,
              filename: 'categoria-producto.jpg',
            ),
          };

    final json = files == null
        ? await _api.put(
            '/categoria-producto/$id',
            authenticated: true,
            body: {
              if (descripcion != null) 'descripcion': descripcion,
              if (rubro != null) 'rubro': rubro,
            },
          )
        : await _api.putMultipart(
            '/categoria-producto/$id',
            fields: fields,
            files: files,
            authenticated: true,
          );

    return CategoriaProductoModel.fromJson(json);
  }

  Future<void> deleteCategoriaProducto(int id) async {
    await _api.delete('/categoria-producto/$id', authenticated: true);
  }
}
