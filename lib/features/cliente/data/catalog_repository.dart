import '../../../core/models/api_models.dart';
import '../../../core/network/api_client.dart';
import 'models/catalog_models.dart';

class CatalogRepository {
  CatalogRepository(this._api);

  final ApiClient _api;

  Future<PaginatedResponse<ComercioModel>> getComercios({
    int page = 1,
    int limit = 10,
    int? categoriaId,
    String? search,
  }) async {
    final json = await _api.get(
      '/comercios/show',
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (categoriaId != null) 'categoriaId': '$categoriaId',
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );

    return PaginatedResponse.fromJson(json, ComercioModel.fromJson);
  }

  Future<ComercioModel> getComercio(int id) async {
    final json = await _api.get('/comercios/show/$id');
    return ComercioModel.fromJson(json);
  }

  Future<PaginatedResponse<CategoriaModel>> getCategorias({
    int page = 1,
    int limit = 20,
  }) async {
    final json = await _api.get(
      '/categorias/show',
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
      },
    );

    return PaginatedResponse.fromJson(json, CategoriaModel.fromJson);
  }

  Future<PaginatedResponse<ProductoModel>> getProductos({
    int? comercioId,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    final json = await _api.get(
      '/productos/show',
      queryParameters: {
        if (comercioId != null) 'comercioId': '$comercioId',
        if (search != null && search.isNotEmpty) 'search': search,
        'page': '$page',
        'limit': '$limit',
      },
    );

    return PaginatedResponse.fromJson(json, ProductoModel.fromJson);
  }

  Future<ProductoModel> getProducto(int id) async {
    final json = await _api.get('/productos/show/$id');
    return ProductoModel.fromJson(json);
  }

  Future<List<PromocionModel>> getPromociones(int comercioId) async {
    final rows = await _api.getList('/promociones/comercio/$comercioId');
    return rows.map(PromocionModel.fromJson).toList();
  }

  Future<List<CuponModel>> getCuponesActivos() async {
    final rows = await _api.getList('/promociones/cupones/show');
    return rows.map(CuponModel.fromJson).toList();
  }

  Future<List<ValoracionModel>> getValoracionesComercio(int comercioId) async {
    final rows = await _api.getList('/valoraciones/comercio/$comercioId');
    return rows.map(ValoracionModel.fromJson).toList();
  }
}
