import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/analytics/app_analytics.dart';
import '../../../../core/network/socket_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/promo_pricing.dart';
import '../../../../core/utils/rubro_copy.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../shared/data/chat_repository.dart';
import '../../data/catalog_repository.dart';
import '../../data/cliente_repository.dart';
import '../../data/models/catalog_models.dart';
import 'product_bottom_sheet.dart';

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
  List<PromocionModel> _promociones = [];
  List<ValoracionModel> _valoraciones = [];
  bool _loading = true;
  String? _error;
  int _tabIndex = 0;
  int _cartCount = 0;
  double _cartTotal = 0;

  double? get _avgRating {
    if (_valoraciones.isEmpty) return null;
    final sum = _valoraciones.fold<int>(0, (a, v) => a + v.calificacion);
    return sum / _valoraciones.length;
  }

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
      setState(() {
        _cartCount = carrito.resumen.cantidadItems;
        _cartTotal = carrito.resumen.total;
      });
    } catch (_) {}
  }

  Future<void> _openProduct(ProductoModel producto) async {
    ProductoModel detail = producto;
    try {
      final loaded = await _repository.getProducto(producto.id);
      detail = loaded.copyWith(promocion: producto.promocion);
    } catch (_) {
      // Usa el ítem de lista si falla el detalle.
    }
    if (!mounted) return;
    final result = await showProductBottomSheet(
      context,
      producto: detail,
      categoriaNombre: _comercio?.categoriaNombre,
    );
    if (result == null || !mounted) return;
    await _addToCart(
      detail,
      cantidad: result.cantidad,
      opcionalId: result.opcionalId,
      extras: result.extras
          .map((e) => {'extraId': e.extraId, 'cantidad': e.cantidad})
          .toList(),
    );
  }

  Future<void> _addToCart(
    ProductoModel producto, {
    int cantidad = 1,
    int? opcionalId,
    List<Map<String, int>>? extras,
  }) async {
    try {
      await _clienteRepository.addToCarrito(
        producto.id,
        cantidad: cantidad,
        opcionalId: opcionalId,
        extras: extras,
      );
      AppAnalytics.addToCart(productoId: producto.id, cantidad: cantidad);
      await _loadCartCount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cantidad > 1
                ? '${producto.nombre} ×$cantidad agregado'
                : '${producto.nombre} agregado al carrito',
          ),
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

  Future<void> _openChat() async {
    try {
      final repo = ChatRepository(
        context.read<AuthProvider>().repository.apiClient,
      );
      final conv = await repo.abrir(comercioId: widget.comercioId);
      if (!mounted) return;
      await context.push(
        '/cliente/chat/${conv.id}',
        extra: {
          'titulo': _comercio?.name ?? 'Chat',
          'soyCliente': true,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir el chat: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

      List<PromocionModel> promos = [];
      List<ValoracionModel> vals = [];
      try {
        promos = await _repository.getPromociones(widget.comercioId);
      } catch (_) {}
      try {
        vals = await _repository.getValoracionesComercio(widget.comercioId);
      } catch (_) {}

      if (!mounted) return;
      final vigentes = promos.where((p) => p.isVigente).toList();
      final byProducto = <int, PromocionModel>{};
      for (final p in vigentes) {
        if (p.productoId != null) {
          byProducto.putIfAbsent(p.productoId!, () => p);
        }
      }
      setState(() {
        _comercio = comercio;
        _productos = productos.data
            .map(
              (prod) => byProducto.containsKey(prod.id)
                  ? prod.copyWith(promocion: byProducto[prod.id])
                  : prod,
            )
            .toList();
        _promociones = vigentes;
        _valoraciones = vals;
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

  Future<void> _submitValoracion() async {
    var stars = 5;
    final commentCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Dejá tu opinión'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final n = i + 1;
                  return IconButton(
                    onPressed: () => setLocal(() => stars = n),
                    icon: Icon(
                      n <= stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: AppColors.yellow,
                    ),
                  );
                }),
              ),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Comentario (opcional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) {
      commentCtrl.dispose();
      return;
    }
    try {
      await _clienteRepository.crearValoracionComercio(
        comercioId: widget.comercioId,
        calificacion: stars,
        comentario: commentCtrl.text.trim(),
      );
      commentCtrl.dispose();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Gracias por tu opinión!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      commentCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        backgroundColor: AppColors.background,
        body: ComercioDetailSkeleton(),
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
    final rating = _avgRating ?? (4.6 + (comercio.id % 5) * 0.05);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _StoreHeader(
                    comercio: comercio,
                    rating: rating,
                    reviewsCount: _valoraciones.length,
                    onFavorite: _toggleFavorito,
                    onChat: _openChat,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _StoreTabs(
                    index: _tabIndex,
                    menuLabel: menuTabLabelForRubro(comercio.categoriaNombre),
                    onChanged: (i) => setState(() => _tabIndex = i),
                  ),
                ),
                if (_tabIndex == 0) ..._buildMenuSlivers(),
                if (_tabIndex == 1) ..._buildPromosSlivers(),
                if (_tabIndex == 2)
                  SliverToBoxAdapter(child: _InfoTab(comercio: comercio)),
                if (_tabIndex == 3) ..._buildOpinionesSlivers(),
                if (_cartCount > 0)
                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
          ),
          if (_cartCount > 0)
            _StickyCartBar(
              itemCount: _cartCount,
              total: _cartTotal,
              ctaLabel: stickyCartCtaForRubro(comercio.categoriaNombre),
              onTap: () => context.go('/cliente/home?tab=2'),
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
            (context, index) {
              final producto = entry.value[index];
              return _MenuItemCard(
                producto: producto,
                showDivider: index < entry.value.length - 1,
                onTap: () => _openProduct(producto),
                onAdd: () => _addToCart(producto),
              );
            },
            childCount: entry.value.length,
          ),
        ),
      ];
    }).toList();
  }

  List<Widget> _buildPromosSlivers() {
    if (_promociones.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: _EmptyTabMessage(
              'Este comercio todavía no publicó promociones.',
            ),
          ),
        ),
      ];
    }
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final promo = _promociones[index];
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.yellow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        promo.badgeLabel,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            promo.nombre,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                            ),
                          ),
                          Text(
                            promo.descripcion?.isNotEmpty == true
                                ? promo.descripcion!
                                : promo.valorLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.gray500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: _promociones.length,
        ),
      ),
    ];
  }

  List<Widget> _buildOpinionesSlivers() {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              if (_avgRating != null) ...[
                const Icon(Icons.star_rounded, color: AppColors.yellow),
                const SizedBox(width: 4),
                Text(
                  _avgRating!.toStringAsFixed(1),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  ' · ${_valoraciones.length} opiniones',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.gray500,
                  ),
                ),
              ] else
                Text(
                  'Todavía no hay opiniones',
                  style: GoogleFonts.poppins(color: AppColors.gray500),
                ),
              const Spacer(),
              TextButton(
                onPressed: _submitValoracion,
                child: const Text('Opinar'),
              ),
            ],
          ),
        ),
      ),
      if (_valoraciones.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: _EmptyTabMessage(
              'Sé el primero en dejar una opinión sobre este local.',
            ),
          ),
        )
      else
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final v = _valoraciones[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            v.usuarioNombre ?? 'Cliente',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                            ),
                          ),
                          const Spacer(),
                          ...List.generate(
                            5,
                            (i) => Icon(
                              i < v.calificacion
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 16,
                              color: AppColors.yellow,
                            ),
                          ),
                        ],
                      ),
                      if (v.comentario != null &&
                          v.comentario!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          v.comentario!,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.gray600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
            childCount: _valoraciones.length,
          ),
        ),
    ];
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({
    required this.comercio,
    required this.rating,
    required this.reviewsCount,
    this.onFavorite,
    this.onChat,
  });

  final ComercioModel comercio;
  final double rating;
  final int reviewsCount;
  final VoidCallback? onFavorite;
  final VoidCallback? onChat;

  static const _coverHeight = 220.0;
  static const _logoSize = 72.0;

  String get _envioLabel {
    final tipos = comercio.tiposEntrega;
    if (tipos.isEmpty) return 'Retiro en local';
    final envio = tipos.any(
      (t) =>
          t.toLowerCase().contains('env') || t.toLowerCase().contains('deliv'),
    );
    return envio ? 'Envío disponible' : tipos.first;
  }

  String get _statusLine {
    if (!comercio.estaAbierto) return 'Cerrado temporalmente';
    final until = _closingTimeToday(comercio.horarios);
    if (until != null) return 'Abierto hasta $until';
    return 'Abierto ahora';
  }

  @override
  Widget build(BuildContext context) {
    final logoUrl =
        comercio.logoUrl.isNotEmpty ? comercio.logoUrl : comercio.imageUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _coverHeight + _logoSize / 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _coverHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _NetworkImage(
                      url: comercio.imageUrl,
                      fallback: Container(
                        color: AppColors.navyLight,
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: AppColors.yellow,
                          size: 48,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => context.pop(),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const Spacer(),
                            if (onChat != null)
                              IconButton(
                                onPressed: onChat,
                                tooltip: 'Chat',
                                icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            IconButton(
                              onPressed: onFavorite,
                              icon: const Icon(
                                Icons.favorite_border_rounded,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(
                                Icons.share_outlined,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                top: _coverHeight - _logoSize / 2,
                child: Container(
                  width: _logoSize,
                  height: _logoSize,
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.navy.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _NetworkImage(
                    url: logoUrl,
                    fallback: Container(
                      color: AppColors.navy,
                      alignment: Alignment.center,
                      child: Text(
                        comercio.name.isNotEmpty
                            ? comercio.name[0].toUpperCase()
                            : 'P',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.yellow,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      comercio.name,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (reviewsCount > 0) ...[
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '($reviewsCount)',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.gray500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                comercio.categoryLabel,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.gray500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '30–40 min · $_envioLabel',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.gray500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _statusLine,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: comercio.estaAbierto
                      ? AppColors.green
                      : AppColors.gray500,
                ),
              ),
              if (onChat != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onChat,
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: Text(
                      'Chatear con el comercio',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      side: const BorderSide(color: AppColors.navy),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String? _closingTimeToday(Map<String, dynamic>? horarios) {
  if (horarios == null || horarios.isEmpty) return null;
  final weekday = DateTime.now().weekday; // 1=Mon … 7=Sun
  final key = kDiasSemana[weekday - 1];
  final raw = horarios[key]?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  final lower = raw.toLowerCase();
  if (lower.contains('cerr')) return null;
  final parts = raw.split(RegExp(r'[-–—]|a', caseSensitive: false));
  if (parts.length < 2) return null;
  final end = parts.last.trim();
  return end.isEmpty ? null : end;
}

class _StickyCartBar extends StatelessWidget {
  const _StickyCartBar({
    required this.itemCount,
    required this.total,
    required this.onTap,
    this.ctaLabel = 'Ver carrito',
  });

  final int itemCount;
  final double total;
  final VoidCallback onTap;
  final String ctaLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Material(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(18),
          elevation: 8,
          shadowColor: AppColors.navy.withValues(alpha: 0.35),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.yellow,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          color: AppColors.navy,
                          size: 20,
                        ),
                      ),
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.yellow,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.navy,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '$itemCount',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      ctaLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  Text(
                    '\$${total.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.yellow,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreTabs extends StatelessWidget {
  const _StoreTabs({
    required this.index,
    required this.onChanged,
    this.menuLabel = 'Menú',
  });

  final int index;
  final ValueChanged<int> onChanged;
  final String menuLabel;

  List<String> get _tabs =>
      [menuLabel, 'Promociones', 'Información', 'Opiniones'];

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final selected = i == index;
            return GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? AppColors.yellow : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  tabs[i],
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.yellowDark : AppColors.gray500,
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
  const _MenuItemCard({
    required this.producto,
    required this.onAdd,
    this.onTap,
    this.showDivider = true,
  });

  final ProductoModel producto;
  final VoidCallback onAdd;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final promo = producto.tienePromocion ? producto.promocion : null;
    final priced = calculatePromoPrice(
      unitPrice: producto.precioValue,
      cantidad: 1,
      promo: promo,
    );

    return Column(
      children: [
        Material(
          color: AppColors.white,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                producto.nombre,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                            if (priced.hasPromo &&
                                priced.badgeLabel != null) ...[
                              const SizedBox(width: 8),
                              _ProductPromoBadge(label: priced.badgeLabel!),
                            ],
                          ],
                        ),
                        if (producto.descripcion != null &&
                            producto.descripcion!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            producto.descripcion!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              height: 1.35,
                              color: AppColors.gray500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (priced.hasPromo &&
                            priced.precioUnitario < priced.precioOriginal)
                          Row(
                            children: [
                              Text(
                                '\$${priced.precioUnitario.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '\$${priced.precioOriginal.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.gray400,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            producto.precioLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 92,
                          height: 92,
                          child: _NetworkImage(
                            url: producto.imageUrl,
                            fallback: Container(
                              color: const Color(0xFFF3F4F6),
                              child: const Icon(
                                Icons.lunch_dining_outlined,
                                color: AppColors.gray400,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (priced.hasPromo && priced.badgeLabel != null)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: _ProductPromoBadge(
                            label: priced.badgeLabel!,
                            compact: true,
                          ),
                        ),
                      Positioned(
                        right: -6,
                        bottom: -6,
                        child: Material(
                          color: AppColors.yellow,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onAdd,
                            child: const SizedBox(
                              width: 32,
                              height: 32,
                              child: Icon(
                                Icons.add,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: Color(0xFFEEEEEE)),
          ),
      ],
    );
  }
}

class _ProductPromoBadge extends StatelessWidget {
  const _ProductPromoBadge({
    required this.label,
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE11D48),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.1,
        ),
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
          if (formatHorarios(comercio.horarios).isNotEmpty)
            _InfoRow('Horarios', formatHorarios(comercio.horarios)),
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
