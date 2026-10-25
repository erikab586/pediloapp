import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/storage/app_mode_storage.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/panel/panel_widgets.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../../core/utils/open_backoffice.dart';
import '../../../comerciante/data/comerciante_repository.dart';
import '../../data/catalog_repository.dart';
import '../../data/cliente_repository.dart';
import '../../data/models/catalog_models.dart';
import '../widgets/cliente_widgets.dart';

// ─── Buscar ──────────────────────────────────────────────────────────────────

class ClienteSearchTab extends StatefulWidget {
  const ClienteSearchTab({
    super.key,
    required this.catalogRepository,
    required this.onOpenComercio,
    required this.onOpenCategoria,
  });

  final CatalogRepository catalogRepository;
  final ValueChanged<int> onOpenComercio;
  final ValueChanged<CategoriaModel> onOpenCategoria;

  @override
  State<ClienteSearchTab> createState() => _ClienteSearchTabState();
}

class _ClienteSearchTabState extends State<ClienteSearchTab> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<ComercioModel> _todosComercios = [];
  List<ComercioModel> _comercios = [];
  List<ProductoModel> _productos = [];
  List<CategoriaModel> _categorias = [];
  List<CategoriaModel> _categoriasFiltradas = [];
  bool _loading = true;
  String? _loadError;
  String? _searchError;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final categoriesResponse =
          await widget.catalogRepository.getCategorias(limit: 100);
      final firstPage =
          await widget.catalogRepository.getComercios(page: 1, limit: 100);
      final allStores = [...firstPage.data];
      for (var page = 2; page <= firstPage.meta.totalPages; page++) {
        final result =
            await widget.catalogRepository.getComercios(page: page, limit: 100);
        allStores.addAll(result.data);
      }
      if (!mounted) return;
      setState(() {
        _categorias = categoriesResponse.data.where((c) => c.activo).toList();
        _todosComercios = allStores;
        _comercios = allStores;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = mensajeErrorEspanol(e);
      });
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _requestId++;
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _query = '';
        _loading = false;
        _comercios = _todosComercios;
        _productos = [];
        _categoriasFiltradas = [];
        _searchError = null;
      });
      return;
    }

    setState(() {
      _query = query;
      _loading = true;
    });

    _debounce = Timer(const Duration(milliseconds: 320), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    final id = ++_requestId;
    try {
      final normalizedQuery = query.toLowerCase();
      final categorias = _categorias
          .where((categoria) =>
              categoria.nombreCategoria.toLowerCase().contains(normalizedQuery))
          .toList();
      final matchingCategoryIds = categorias.map((c) => c.id).toSet();
      final matchingCategoryStores = _todosComercios.where(
          (comercio) => matchingCategoryIds.contains(comercio.categoriaId));
      final comerciosFuture = widget.catalogRepository.getComercios(
        search: query,
        limit: 100,
      );
      final productosFuture = widget.catalogRepository.getProductos(
        search: query,
        limit: 16,
      );
      final comerciosResult = await comerciosFuture;
      final productosResult = await productosFuture;
      final matchingStores = <int, ComercioModel>{
        for (final comercio in matchingCategoryStores) comercio.id: comercio,
        for (final comercio in comerciosResult.data) comercio.id: comercio,
      }.values.toList();
      if (!mounted || id != _requestId) return;
      setState(() {
        _comercios = matchingStores;
        _productos = productosResult.data;
        _categoriasFiltradas = categorias;
        _searchError = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      final normalizedQuery = query.toLowerCase();
      setState(() {
        _comercios = _todosComercios.where((comercio) {
          return comercio.name.toLowerCase().contains(normalizedQuery) ||
              (comercio.categoriaNombre?.toLowerCase() ?? '')
                  .contains(normalizedQuery);
        }).toList();
        _productos = [];
        _categoriasFiltradas = _categorias
            .where((categoria) => categoria.nombreCategoria
                .toLowerCase()
                .contains(normalizedQuery))
            .toList();
        _searchError = mensajeErrorEspanol(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final empty = !_loading &&
        _query.isNotEmpty &&
        _comercios.isEmpty &&
        _productos.isEmpty &&
        _categoriasFiltradas.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ClienteSubHeader(title: 'Buscar'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _searchController,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Comercios, productos...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _debounce?.cancel();
                        _requestId++;
                        _searchController.clear();
                        setState(() {
                          _query = '';
                          _loading = false;
                          _comercios = _todosComercios;
                          _productos = [];
                          _categoriasFiltradas = [];
                          _searchError = null;
                        });
                      },
                    ),
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          size: 48,
                          color: AppColors.gray400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No se pudo cargar el catálogo',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.gray500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loadCatalog,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.yellow),
                    )
                  : _query.isEmpty
                      ? _todosComercios.isEmpty
                          ? const EmptyPanelState(
                              icon: Icons.storefront_outlined,
                              title: 'Todavía no hay comercios disponibles',
                              subtitle: 'Volvé a revisar más tarde.',
                            )
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                if (_searchError != null) ...[
                                  Text(
                                    'Algunos resultados no están disponibles: '
                                    '$_searchError',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.gray500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Text(
                                  'Todos los locales',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ComercioMarketplaceList(
                                  comercios: _todosComercios,
                                  onOpen: widget.onOpenComercio,
                                ),
                              ],
                            )
                      : empty
                          ? EmptyPanelState(
                              icon: Icons.search_off_rounded,
                              title: 'Sin coincidencias',
                              subtitle:
                                  'No encontramos resultados para “$_query”.',
                            )
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                if (_categoriasFiltradas.isNotEmpty) ...[
                                  Text(
                                    'Categorías',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ..._categoriasFiltradas.map(
                                    (categoria) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _UnifiedSearchTile(
                                        imageUrl: categoria.imageUrl,
                                        title: categoria.nombreCategoria,
                                        subtitle: 'Categoría',
                                        trailing: 'Ver',
                                        fallbackIcon: Icons.category_outlined,
                                        onTap: () =>
                                            widget.onOpenCategoria(categoria),
                                      ),
                                    ),
                                  ),
                                ],
                                if (_productos.isNotEmpty) ...[
                                  Text(
                                    'Productos',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ..._productos.map(
                                    (p) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _UnifiedSearchTile(
                                        imageUrl: p.imageUrl,
                                        title: p.nombre,
                                        subtitle:
                                            p.comercioNombre ?? 'Producto',
                                        trailing: p.precioLabel,
                                        fallbackIcon:
                                            Icons.lunch_dining_rounded,
                                        onTap: () {
                                          final id = p.comercioId;
                                          if (id != null) {
                                            widget.onOpenComercio(id);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                if (_comercios.isNotEmpty) ...[
                                  Text(
                                    'Comercios',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ComercioMarketplaceList(
                                    comercios: _comercios,
                                    onOpen: widget.onOpenComercio,
                                    spacing: 8,
                                  ),
                                ],
                              ],
                            ),
        ),
      ],
    );
  }
}

class _UnifiedSearchTile extends StatelessWidget {
  const _UnifiedSearchTile({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.fallbackIcon,
    required this.onTap,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final String trailing;
  final IconData fallbackIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: imageUrl.isEmpty
                      ? ColoredBox(
                          color: const Color(0xFFF3F4F6),
                          child: Icon(
                            fallbackIcon,
                            color: AppColors.gray400,
                            size: 22,
                          ),
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: const Color(0xFFF3F4F6),
                            child: Icon(
                              fallbackIcon,
                              color: AppColors.gray400,
                              size: 22,
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
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                trailing,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Carrito ─────────────────────────────────────────────────────────────────

class ClienteCarritoTab extends StatefulWidget {
  const ClienteCarritoTab({
    super.key,
    required this.repository,
    required this.catalogRepository,
    required this.onCartChanged,
    required this.onGoCheckout,
    this.refreshToken = 0,
  });

  final ClienteRepository repository;
  final CatalogRepository catalogRepository;
  final VoidCallback onCartChanged;
  final ValueChanged<int> onGoCheckout;
  final int refreshToken;

  @override
  State<ClienteCarritoTab> createState() => _ClienteCarritoTabState();
}

class _ClienteCarritoTabState extends State<ClienteCarritoTab> {
  CarritoModel? _carrito;
  ComercioModel? _comercio;
  bool _loading = true;
  String? _error;

  /// `delivery` | `retiro`
  String _entrega = 'delivery';

  static const double _envioDefault = 50;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ClienteCarritoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final carrito = await widget.repository.getCarrito();
      ComercioModel? comercio;
      final comercioId = carrito.resumen.comercioId;
      if (comercioId != null) {
        try {
          comercio = await widget.catalogRepository.getComercio(comercioId);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _carrito = carrito;
        _comercio = comercio;
        _loading = false;
        if (comercio != null) {
          final tipos =
              comercio.tiposEntrega.map((t) => t.toLowerCase()).toList();
          final hasDelivery = tipos.any(
            (t) => t.contains('env') || t.contains('deliv'),
          );
          final hasRetiro = tipos.any((t) => t.contains('retir'));
          if (!hasDelivery && hasRetiro) {
            _entrega = 'retiro';
          } else if (hasDelivery) {
            _entrega = 'delivery';
          }
        }
      });
      widget.onCartChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = mensajeErrorEspanol(e);
      });
    }
  }

  Future<void> _updateQty(CarritoItemModel item, int qty) async {
    try {
      if (qty < 1) {
        await widget.repository.removeCarritoItem(item.id);
      } else {
        await widget.repository.updateCarritoItem(item.id, qty);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  Future<void> _removeItem(CarritoItemModel item) async {
    try {
      await widget.repository.removeCarritoItem(item.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  double get _envioFee {
    if (_entrega != 'delivery') return 0;
    final api = _carrito?.resumen.entregaPrecio ?? 0;
    return api > 0 ? api : _envioDefault;
  }

  double get _subtotal => _carrito?.resumen.subtotal ?? 0;

  double get _total => _subtotal + _envioFee;

  bool get _offersDelivery {
    final tipos = _comercio?.tiposEntrega ?? const <String>[];
    if (tipos.isEmpty) return true;
    return tipos.any(
      (t) {
        final l = t.toLowerCase();
        return l.contains('env') || l.contains('deliv');
      },
    );
  }

  bool get _offersRetiro {
    final tipos = _comercio?.tiposEntrega ?? const <String>[];
    if (tipos.isEmpty) return true;
    return tipos.any((t) => t.toLowerCase().contains('retir'));
  }

  @override
  Widget build(BuildContext context) {
    final carrito = _carrito;
    final items = carrito?.items ?? [];
    final vendor = _comercio?.name ??
        (carrito?.resumen.comercioId != null
            ? 'Comercio #${carrito!.resumen.comercioId}'
            : 'Comercio');

    return ColoredBox(
      color: AppColors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: SizedBox(
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      'Tu carrito',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => context.go('/cliente/home'),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.yellow),
                    )
                  : RefreshIndicator(
                      color: AppColors.yellow,
                      onRefresh: _load,
                      child: items.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.sizeOf(context).height * 0.55,
                                  child: EmptyActionState(
                                    icon: Icons.shopping_cart_outlined,
                                    title: _error != null
                                        ? 'No se pudo cargar el carrito'
                                        : 'Carrito vacío',
                                    subtitle: _error ??
                                        'Agregá productos desde un comercio para armar tu pedido.',
                                    actionLabel: 'Explorar comercios',
                                    onAction: () => context.go('/cliente/home'),
                                  ),
                                ),
                              ],
                            )
                          : ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              children: [
                                ...items.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final item = entry.value;
                                  return Column(
                                    children: [
                                      _CarritoItemTile(
                                        item: item,
                                        vendorName: vendor,
                                        onMinus: () => _updateQty(
                                          item,
                                          item.cantidad - 1,
                                        ),
                                        onPlus: () => _updateQty(
                                          item,
                                          item.cantidad + 1,
                                        ),
                                        onDelete: () => _removeItem(item),
                                      ),
                                      if (i < items.length - 1)
                                        const Divider(
                                          height: 1,
                                          color: Color(0xFFEEEEEE),
                                        ),
                                    ],
                                  );
                                }),
                                const SizedBox(height: 20),
                                _CartSummaryCard(
                                  subtotal: _subtotal,
                                  envio: _envioFee,
                                  total: _total,
                                ),
                                const SizedBox(height: 22),
                                Text(
                                  'Elegí método de entrega',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _DeliveryMethodCard(
                                  entrega: _entrega,
                                  showRetiro: _offersRetiro,
                                  showDelivery: _offersDelivery,
                                  envioLabel:
                                      '\$${_envioFee.toStringAsFixed(0)}',
                                  onChanged: (v) =>
                                      setState(() => _entrega = v),
                                ),
                                const SizedBox(height: 88),
                              ],
                            ),
                    ),
            ),
            if (!_loading && items.isNotEmpty)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: carrito?.resumen.comercioId == null
                          ? null
                          : () => widget.onGoCheckout(
                                carrito!.resumen.comercioId!,
                              ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.yellow,
                        foregroundColor: AppColors.navy,
                        disabledBackgroundColor:
                            AppColors.yellow.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Continuar',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CarritoItemTile extends StatelessWidget {
  const _CarritoItemTile({
    required this.item,
    required this.vendorName,
    required this.onMinus,
    required this.onPlus,
    required this.onDelete,
  });

  final CarritoItemModel item;
  final String vendorName;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: item.imageUrl.isNotEmpty
                  ? Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgFallback(),
                    )
                  : _imgFallback(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  vendorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.gray500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.precioUnitLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                if (item.extrasSummary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.extrasSummary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.gray500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: AppColors.gray500,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _QtyBtn(icon: Icons.remove, onTap: onMinus),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '${item.cantidad}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    _QtyBtn(icon: Icons.add, onTap: onPlus),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imgFallback() {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: const Icon(Icons.lunch_dining_outlined, color: AppColors.gray400),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(icon, size: 16, color: AppColors.navy),
      ),
    );
  }
}

class _CartSummaryCard extends StatelessWidget {
  const _CartSummaryCard({
    required this.subtotal,
    required this.envio,
    required this.total,
  });

  final double subtotal;
  final double envio;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        children: [
          _moneyRow('Subtotal', '\$${subtotal.toStringAsFixed(0)}'),
          const SizedBox(height: 10),
          _moneyRow('Envío', '\$${envio.toStringAsFixed(0)}'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFEEEEEE)),
          ),
          _moneyRow(
            'Total',
            '\$${total.toStringAsFixed(0)}',
            bold: true,
            larger: true,
          ),
        ],
      ),
    );
  }

  Widget _moneyRow(
    String label,
    String value, {
    bool bold = false,
    bool larger = false,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: larger ? 15 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.navy,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: larger ? 16 : 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
      ],
    );
  }
}

class _DeliveryMethodCard extends StatelessWidget {
  const _DeliveryMethodCard({
    required this.entrega,
    required this.onChanged,
    required this.showRetiro,
    required this.showDelivery,
    required this.envioLabel,
  });

  final String entrega;
  final ValueChanged<String> onChanged;
  final bool showRetiro;
  final bool showDelivery;
  final String envioLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          if (showRetiro)
            _DeliveryOption(
              selected: entrega == 'retiro',
              title: 'Retiro en el local',
              subtitle: '20–25 min',
              onTap: () => onChanged('retiro'),
            ),
          if (showRetiro && showDelivery)
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
          if (showDelivery)
            _DeliveryOption(
              selected: entrega == 'delivery',
              title: 'Delivery',
              subtitle: '30–40 min',
              trailing: entrega == 'delivery' ? envioLabel : '\$50',
              onTap: () => onChanged('delivery'),
            ),
        ],
      ),
    );
  }
}

class _DeliveryOption extends StatelessWidget {
  const _DeliveryOption({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            _RadioDot(selected: selected),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.gray500,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.yellow : AppColors.gray400,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: AppColors.navy,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

// ─── Pedidos ─────────────────────────────────────────────────────────────────

class ClientePedidosTab extends StatefulWidget {
  const ClientePedidosTab({
    super.key,
    required this.repository,
    required this.onOpenTracking,
    this.refreshToken = 0,
  });

  final ClienteRepository repository;
  final ValueChanged<int> onOpenTracking;
  final int refreshToken;

  @override
  State<ClientePedidosTab> createState() => _ClientePedidosTabState();
}

class _ClientePedidosTabState extends State<ClientePedidosTab> {
  static const _filters = [
    'Todos',
    'Pendiente',
    'Aceptado',
    'Preparando',
    'Listo',
    'En espera',
    'Enviado',
    'Entregado',
    'Cancelado',
  ];

  int _filterIndex = 0;
  List<ClientePedidoModel> _allPedidos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ClientePedidosTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  String? get _statusFilter =>
      _filterIndex <= 0 ? null : _filters[_filterIndex];

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.getPedidos(
        limit: 50,
        status: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _allPedidos = page.data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = mensajeErrorEspanol(e);
      });
    }
  }

  List<ClientePedidoModel> get _pedidos => _allPedidos;

  @override
  Widget build(BuildContext context) {
    final pedidos = _pedidos;
    final emptyTitle = _error != null
        ? 'No se pudieron cargar los pedidos'
        : _statusFilter == null
            ? 'Sin pedidos'
            : 'Sin pedidos con estado $_statusFilter';
    final emptySubtitle = _error ??
        'Cuando hagas un pedido va a aparecer acá con imagen, comercio y productos.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ClienteSubHeader(title: 'Mis pedidos'),
        FilterChips(
          labels: _filters,
          selectedIndex: _filterIndex,
          onSelected: (i) {
            if (_filterIndex == i) return;
            setState(() => _filterIndex = i);
            _load();
          },
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.yellow),
                )
              : RefreshIndicator(
                  color: AppColors.yellow,
                  onRefresh: _load,
                  child: pedidos.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.45,
                              child: EmptyPanelState(
                                icon: Icons.receipt_long_outlined,
                                title: emptyTitle,
                                subtitle: emptySubtitle,
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: pedidos.length,
                          itemBuilder: (context, index) {
                            final pedido = pedidos[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PedidoClienteCard(
                                pedido: pedido,
                                onTap: () => widget.onOpenTracking(pedido.id),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

class _PedidoClienteCard extends StatelessWidget {
  const _PedidoClienteCard({required this.pedido, required this.onTap});

  final ClientePedidoModel pedido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: pedido.imageUrl.isNotEmpty
                      ? Image.network(
                          pedido.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFF1F5F9),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.receipt_long,
                              color: AppColors.gray400,
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFFF1F5F9),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.receipt_long,
                            color: AppColors.gray400,
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
                      pedido.comercioNombre ?? 'Comercio',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (pedido.productoNombre?.isNotEmpty == true)
                          ? pedido.productoNombre!
                          : 'Pedido',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#${pedido.id} · ${pedido.fechaPedidoLabel}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.gray500,
                      ),
                    ),
                    Text(
                      pedido.status,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                pedido.totalLabel,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Perfil ──────────────────────────────────────────────────────────────────

class ClientePerfilTab extends StatefulWidget {
  const ClientePerfilTab({
    super.key,
    required this.repository,
    required this.onLogout,
  });

  final ClienteRepository repository;
  final VoidCallback onLogout;

  @override
  State<ClientePerfilTab> createState() => _ClientePerfilTabState();
}

class _ClientePerfilTabState extends State<ClientePerfilTab> {
  List<ComercioModel> _misComercios = [];
  bool _loadingComercios = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMisComercios());
  }

  Future<void> _loadMisComercios() async {
    final auth = context.read<AuthProvider>();
    if (!auth.canUseComercioMode) {
      if (mounted) setState(() => _misComercios = []);
      return;
    }
    setState(() => _loadingComercios = true);
    try {
      final repo = ComercianteRepository(auth.repository.apiClient);
      final list = await repo.getMisComercios();
      if (!mounted) return;
      setState(() {
        _misComercios = list;
        _loadingComercios = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingComercios = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron cargar tus comercios.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _registerCommerce() async {
    final ok = await context.push<bool>('/cliente/vender');
    if (ok != true || !mounted) return;

    try {
      await context.read<AuthProvider>().promoteToComerciante();
      await _loadMisComercios();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo activar el modo comercio: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String? get _primaryEstatus {
    if (_misComercios.isEmpty) return null;
    final aprobado = _misComercios.where((c) {
      final e = c.estatus;
      return e == 'aprobado' || e == 'activo';
    });
    if (aprobado.isNotEmpty) return aprobado.first.estatus;
    final pendiente = _misComercios.where((c) => c.estatus == 'pendiente');
    if (pendiente.isNotEmpty) return 'pendiente';
    return _misComercios.first.estatus;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ClienteSubHeader(title: 'Perfil'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.yellow,
                      child: Text(
                        auth.user?.name.isNotEmpty == true
                            ? auth.user!.name[0].toUpperCase()
                            : 'C',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.user?.name ?? 'Cliente',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                          ),
                          Text(
                            auth.user?.email ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.gray400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _VenderEnPediloCard(
                canSwitchToComercio: auth.canUseComercioMode,
                loading: _loadingComercios,
                comercioEstatus: _primaryEstatus,
                onRegister: _registerCommerce,
                onOpenMiComercio: () async {
                  await auth.setAppMode(AppMode.comercio);
                  if (context.mounted) context.go('/cliente/home');
                },
                onOpenBackoffice: () =>
                    openBackofficeFromContext(context, from: 'app'),
              ),
              const SizedBox(height: 8),
              _PerfilTile(
                icon: Icons.chat_bubble_outline,
                label: 'Mensajes',
                onTap: () => context.push('/cliente/chat'),
              ),
              _PerfilTile(
                icon: Icons.location_on_outlined,
                label: 'Mis direcciones',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClienteDireccionesScreen(
                        repository: widget.repository,
                      ),
                    ),
                  );
                },
              ),
              _PerfilTile(
                icon: Icons.favorite_border,
                label: 'Favoritos',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClienteFavoritosScreen(
                        repository: widget.repository,
                      ),
                    ),
                  );
                },
              ),
              _PerfilTile(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacidad',
                onTap: () => context.push('/legal/privacidad'),
              ),
              _PerfilTile(
                icon: Icons.description_outlined,
                label: 'Términos',
                onTap: () => context.push('/legal/terminos'),
              ),
              _PerfilTile(
                icon: Icons.logout,
                label: 'Cerrar sesión',
                destructive: true,
                onTap: widget.onLogout,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _VenderCardState { sinSolicitud, pendiente, aprobado, noActivo }

class _VenderEnPediloCard extends StatelessWidget {
  const _VenderEnPediloCard({
    required this.canSwitchToComercio,
    required this.onRegister,
    required this.onOpenMiComercio,
    required this.onOpenBackoffice,
    this.loading = false,
    this.comercioEstatus,
  });

  final bool canSwitchToComercio;
  final bool loading;
  final String? comercioEstatus;
  final VoidCallback onRegister;
  final VoidCallback onOpenMiComercio;
  final VoidCallback onOpenBackoffice;

  _VenderCardState get _state {
    if (!canSwitchToComercio) return _VenderCardState.sinSolicitud;
    final e = comercioEstatus;
    if (e == null) return _VenderCardState.sinSolicitud;
    if (e == 'pendiente') return _VenderCardState.pendiente;
    if (e == 'aprobado' || e == 'activo') return _VenderCardState.aprobado;
    return _VenderCardState.noActivo;
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final subtitle = switch (state) {
      _VenderCardState.sinSolicitud =>
        'Publicá tu local y recibí pedidos en vivo.',
      _VenderCardState.pendiente =>
        'Tu solicitud está en revisión (24–48 hs). Podés seguir comprando.',
      _VenderCardState.aprobado =>
        'Gestioná pedidos, productos y tu local directamente desde la app.',
      _VenderCardState.noActivo =>
        'Tu comercio no está activo. Contactá soporte o registrá otro local.',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.yellow.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.storefront, color: AppColors.navy),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vender en pedilo',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.gray400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (state == _VenderCardState.pendiente) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.yellow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'En revisión',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.yellow,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (loading)
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.yellow,
                ),
              ),
            )
          else ...[
            if (canSwitchToComercio) ...[
              FilledButton(
                onPressed: onOpenMiComercio,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  foregroundColor: AppColors.navy,
                ),
                child: const Text('Cambiar a modo comercio'),
              ),
              const SizedBox(height: 8),
            ],
            if (state == _VenderCardState.sinSolicitud)
              FilledButton(
                onPressed: onRegister,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  foregroundColor: AppColors.navy,
                ),
                child: const Text('Registrar mi comercio'),
              )
            else if (state == _VenderCardState.pendiente ||
                state == _VenderCardState.noActivo)
              TextButton(
                onPressed: onRegister,
                child: Text(
                  'Registrar otro local',
                  style: GoogleFonts.poppins(color: AppColors.yellow),
                ),
              )
            else ...[
              OutlinedButton(
                onPressed: onOpenBackoffice,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.yellow,
                  side: const BorderSide(color: AppColors.yellow),
                ),
                child: const Text('Administrar en web'),
              ),
              TextButton(
                onPressed: onRegister,
                child: Text(
                  'Registrar otro local',
                  style: GoogleFonts.poppins(color: AppColors.yellow),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PerfilTile extends StatelessWidget {
  const _PerfilTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: destructive ? const Color(0xFFEF4444) : AppColors.navy,
        ),
        title: Text(
          label,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            color: destructive ? const Color(0xFFEF4444) : AppColors.navy,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.gray400),
        onTap: onTap,
      ),
    );
  }
}

class _ClienteSubHeader extends StatelessWidget {
  const _ClienteSubHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 8,
        16,
        12,
      ),
      color: AppColors.navy,
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
    );
  }
}

// ─── Direcciones ─────────────────────────────────────────────────────────────

class ClienteDireccionesScreen extends StatefulWidget {
  const ClienteDireccionesScreen({super.key, required this.repository});

  final ClienteRepository repository;

  @override
  State<ClienteDireccionesScreen> createState() =>
      _ClienteDireccionesScreenState();
}

class _ClienteDireccionesScreenState extends State<ClienteDireccionesScreen> {
  List<DireccionModel> _direcciones = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await widget.repository.getDirecciones();
      if (!mounted) return;
      setState(() {
        _direcciones = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  Future<void> _add() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva dirección'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Calle, número, ciudad'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;

    try {
      await widget.repository.createDireccion(
        tipo: 'Casa',
        direccion: ctrl.text.trim(),
        predeterminada: _direcciones.isEmpty,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis direcciones')),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.navy,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            )
          : _direcciones.isEmpty
              ? const EmptyPanelState(
                  icon: Icons.location_on_outlined,
                  title: 'Sin direcciones',
                  subtitle: 'Agregá una dirección para delivery.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _direcciones.length,
                  itemBuilder: (context, index) {
                    final d = _direcciones[index];
                    return ListTile(
                      title: Text(d.direccion),
                      subtitle: Text(d.tipo),
                      trailing: d.predeterminada
                          ? const Icon(Icons.star, color: AppColors.yellow)
                          : null,
                    );
                  },
                ),
    );
  }
}

class ClienteFavoritosScreen extends StatefulWidget {
  const ClienteFavoritosScreen({super.key, required this.repository});

  final ClienteRepository repository;

  @override
  State<ClienteFavoritosScreen> createState() => _ClienteFavoritosScreenState();
}

class _ClienteFavoritosScreenState extends State<ClienteFavoritosScreen> {
  List<ComercioModel> _favoritos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await widget.repository.getFavoritosComercios();
      if (!mounted) return;
      setState(() {
        _favoritos = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            )
          : _favoritos.isEmpty
              ? const EmptyPanelState(
                  icon: Icons.favorite_border,
                  title: 'Sin favoritos',
                  subtitle: 'Marcá comercios con el corazón.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _favoritos.length,
                  itemBuilder: (context, index) {
                    final c = _favoritos[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SearchResultTile(
                        comercio: c,
                        onTap: () => context.push('/cliente/comercio/${c.id}'),
                      ),
                    );
                  },
                ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.comercio, required this.onTap});

  final ComercioModel comercio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: comercio.imageUrl.isEmpty
                    ? Container(
                        width: 56,
                        height: 56,
                        color: const Color(0xFFE5E7EB),
                        child:
                            const Icon(Icons.store, color: AppColors.gray400),
                      )
                    : Image.network(
                        comercio.imageUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 56,
                          height: 56,
                          color: const Color(0xFFE5E7EB),
                          child:
                              const Icon(Icons.store, color: AppColors.gray400),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      comercio.categoryLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                comercio.estaAbierto ? Icons.circle : Icons.circle_outlined,
                size: 12,
                color:
                    comercio.estaAbierto ? AppColors.green : AppColors.gray400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
