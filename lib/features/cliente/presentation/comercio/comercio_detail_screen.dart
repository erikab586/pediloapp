import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../data/catalog_repository.dart';
import '../../data/cliente_repository.dart';
import '../../data/models/catalog_models.dart';

class ComercioDetailScreen extends StatefulWidget {
  const ComercioDetailScreen({super.key, required this.comercioId});

  final int comercioId;

  @override
  State<ComercioDetailScreen> createState() => _ComercioDetailScreenState();
}

class _ComercioDetailScreenState extends State<ComercioDetailScreen> {
  late final CatalogRepository _repository;
  late final ClienteRepository _clienteRepository;
  ComercioModel? _comercio;
  List<ProductoModel> _productos = [];
  bool _loading = true;
  String? _error;
  int _tabIndex = 0;
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    final api = context.read<AuthProvider>().repository.apiClient;
    _repository = CatalogRepository(api);
    _clienteRepository = ClienteRepository(api);
    _load();
    _loadCartCount();
  }

  Future<void> _loadCartCount() async {
    try {
      final carrito = await _clienteRepository.getCarrito();
      if (!mounted) return;
      setState(() => _cartCount = carrito.resumen.cantidadItems);
    } catch (_) {}
  }

  Future<void> _addToCart(ProductoModel producto) async {
    try {
      await _clienteRepository.addToCarrito(producto.id);
      await _loadCartCount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${producto.nombre} agregado al carrito'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Ver carrito',
            onPressed: () => context.go('/cliente/home?tab=2'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo agregar: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleFavorito() async {
    try {
      await _clienteRepository.toggleFavoritoComercio(widget.comercioId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Favorito actualizado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final comercio = await _repository.getComercio(widget.comercioId);
      final productos =
          await _repository.getProductos(comercioId: widget.comercioId);

      if (!mounted) return;
      setState(() {
        _comercio = comercio;
        _productos = productos.data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el comercio.';
        _loading = false;
      });
    }
  }

  Map<String, List<ProductoModel>> get _productosPorCategoria {
    final map = <String, List<ProductoModel>>{};
    for (final producto in _productos) {
      final key = producto.categoriaLabel;
      map.putIfAbsent(key, () => []).add(producto);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.yellow),
        ),
      );
    }

    if (_error != null || _comercio == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Comercio no encontrado'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final comercio = _comercio!;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: _cartCount > 0
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/cliente/home?tab=2'),
              backgroundColor: AppColors.yellow,
              foregroundColor: AppColors.navy,
              icon: const Icon(Icons.shopping_cart),
              label: Text('Ver carrito ($_cartCount)'),
            )
          : null,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _StoreHero(
                  comercio: comercio,
                  onFavorite: _toggleFavorito,
                )),
                SliverToBoxAdapter(child: _StoreInfoCard(comercio: comercio)),
                SliverToBoxAdapter(child: _StoreTabs(
                  index: _tabIndex,
                  onChanged: (i) => setState(() => _tabIndex = i),
                )),
                if (_tabIndex == 0) ..._buildMenuSlivers(),
                if (_tabIndex == 1)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: _EmptyTabMessage(
                        'Las promociones aparecerán cuando el comercio las publique.',
                      ),
                    ),
                  ),
                if (_tabIndex == 2)
                  SliverToBoxAdapter(child: _InfoTab(comercio: comercio)),
                if (_tabIndex == 3)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: _EmptyTabMessage(
                        'Las opiniones estarán disponibles próximamente.',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMenuSlivers() {
    if (_productos.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: _EmptyTabMessage(
              'Este comercio aún no cargó productos en la plataforma.',
            ),
          ),
        ),
      ];
    }

    return _productosPorCategoria.entries.expand((entry) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              entry.key,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _MenuItemCard(
              producto: entry.value[index],
              onAdd: () => _addToCart(entry.value[index]),
            ),
            childCount: entry.value.length,
          ),
        ),
      ];
    }).toList();
  }
}

class _StoreHero extends StatelessWidget {
  const _StoreHero({required this.comercio, this.onFavorite});

  final ComercioModel comercio;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _NetworkImage(
            url: comercio.imageUrl,
            fallback: Container(color: const Color(0xFFE5E7EB)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onFavorite,
                    icon: const Icon(Icons.favorite_border, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.share_outlined, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreInfoCard extends StatelessWidget {
  const _StoreInfoCard({required this.comercio});

  final ComercioModel comercio;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -40),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.translate(
                offset: const Offset(0, -36),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: _NetworkImage(
                      url: comercio.logoUrl.isNotEmpty
                          ? comercio.logoUrl
                          : comercio.imageUrl,
                      fallback: Container(
                        color: AppColors.cream,
                        child: const Icon(Icons.store, color: AppColors.navy),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comercio.name,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      comercio.categoryLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.gray500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: comercio.estaAbierto
                              ? AppColors.green
                              : AppColors.gray400,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          comercio.statusLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: comercio.estaAbierto
                                ? AppColors.green
                                : AppColors.gray500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreTabs extends StatelessWidget {
  const _StoreTabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _tabs = ['Menú', 'Promociones', 'Información', 'Opiniones'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final selected = i == index;
            return GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? AppColors.yellow : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  _tabs[i],
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AppColors.navy : AppColors.gray500,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({required this.producto, required this.onAdd});

  final ProductoModel producto;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.nombre,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                if (producto.descripcion != null &&
                    producto.descripcion!.isNotEmpty)
                  Text(
                    producto.descripcion!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.gray500,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  producto.precioLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: _NetworkImage(
                    url: producto.imageUrl,
                    fallback: Container(
                      color: const Color(0xFFE5E7EB),
                      child: const Icon(Icons.fastfood_outlined),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Material(
                  color: AppColors.yellow,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onAdd,
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(Icons.add, size: 18, color: AppColors.navy),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.comercio});

  final ComercioModel comercio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (comercio.descripcion != null)
            _InfoRow('Descripción', comercio.descripcion!),
          if (comercio.direccion != null)
            _InfoRow('Dirección', comercio.direccion!),
          if (comercio.telefono != null)
            _InfoRow('Teléfono', comercio.telefono!),
          if (comercio.tiposEntrega.isNotEmpty)
            _InfoRow('Entrega', comercio.tiposEntrega.join(', ')),
          if (comercio.metodosPago.isNotEmpty)
            _InfoRow('Pagos', comercio.metodosPago.join(', ')),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.gray600),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _EmptyTabMessage extends StatelessWidget {
  const _EmptyTabMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(fontSize: 13, color: AppColors.gray500),
      ),
    );
  }
}

class _NetworkImage extends StatelessWidget {
  const _NetworkImage({required this.url, required this.fallback});

  final String url;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return fallback;

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
