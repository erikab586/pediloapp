import 'models/catalog_models.dart';

/// Datos de respaldo cuando la API no responde (desarrollo/demo).
abstract final class CatalogMockData {
  static const fallbackCategorias = [
    CategoriaModel(id: 1, nombreCategoria: 'Restaurantes'),
    CategoriaModel(id: 2, nombreCategoria: 'Cafeterías'),
    CategoriaModel(id: 3, nombreCategoria: 'Supermercados'),
    CategoriaModel(id: 4, nombreCategoria: 'Farmacias'),
  ];

  static const fallbackComercios = [
    ComercioModel(
      id: 1,
      name: 'Burger House',
      portada:
          'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=320&h=200&fit=crop',
      descripcion: 'Hamburguesas artesanales',
      estaAbierto: true,
      categoriaNombre: 'Hamburguesas',
    ),
    ComercioModel(
      id: 2,
      name: 'Pizza Roma',
      portada:
          'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=320&h=200&fit=crop',
      descripcion: 'Pizzas al horno de leña',
      estaAbierto: true,
      categoriaNombre: 'Pizzas',
    ),
    ComercioModel(
      id: 3,
      name: 'Sushi Zen',
      portada:
          'https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=320&h=200&fit=crop',
      descripcion: 'Cocina japonesa',
      estaAbierto: true,
      categoriaNombre: 'Japonés',
    ),
  ];

  static String emojiForCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('restaurant')) return '🍽️';
    if (lower.contains('caf')) return '☕';
    if (lower.contains('super')) return '🛒';
    if (lower.contains('farma')) return '💊';
    if (lower.contains('pizza')) return '🍕';
    if (lower.contains('burger') || lower.contains('hambur')) return '🍔';
    if (lower.contains('sushi') || lower.contains('japon')) return '🍣';
    return '🏪';
  }
}
