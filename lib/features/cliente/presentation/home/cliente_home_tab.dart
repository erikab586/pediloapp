import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/rubro_copy.dart';
import '../../../../core/widgets/pedilo_logo.dart';
import '../../../../core/widgets/notification_bell.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/catalog_mock_data.dart';
import '../../data/catalog_repository.dart';
import '../../data/cliente_repository.dart';
import '../../data/models/catalog_models.dart';
import '../shell/cliente_panel_tabs.dart';
import '../widgets/cliente_widgets.dart';
import '../widgets/promo_ads_banner.dart';

class ClienteHomeTab extends StatefulWidget {
  const ClienteHomeTab({
    super.key,
    required this.catalogRepository,
    required this.clienteRepository,
    required this.onOpenComercio,
    this.onGoSearch,
    this.onOpenTracking,
    this.onGoPedidos,
    this.onOpenNotification,
  });

  final CatalogRepository catalogRepository;
  final ClienteRepository clienteRepository;
  final ValueChanged<int> onOpenComercio;
  final VoidCallback? onGoSearch;
  final ValueChanged<int>? onOpenTracking;
  final VoidCallback? onGoPedidos;
  final ValueChanged<Map<String, dynamic>>? onOpenNotification;

  @override
  State<ClienteHomeTab> createState() => _ClienteHomeTabState();
}

class _ClienteHomeTabState extends State<ClienteHomeTab> {
  List<CategoriaModel> _categorias = [];
  List<ComercioModel> _comercios = [];
  List<ComercioModel> _favoritos = [];
  List<ComercioModel> _conPromo = [];
  Map<int, String> _promoBadges = {};
  List<DireccionModel> _direcciones = [];
  List<ClientePedidoModel> _pedidosActivos = [];
  ClientePedidoModel? _ultimoEntregado;
  List<CuponModel> _cupones = [];
  DireccionModel? _selectedDireccion;
  int? _selectedCategoriaId;
  bool _loading = true;

  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  bool _searchLoading = false;
  List<ComercioModel> _searchComercios = [];
  List<ProductoModel> _searchProductos = [];
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({int? categoriaId, bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      final categoriasResult =
          await widget.catalogRepository.getCategorias(limit: 30);
      final comerciosResult = await widget.catalogRepository.getComercios(
        limit: 50,
        categoriaId: categoriaId,
      );

      List<DireccionModel> direcciones = [];
      List<ClientePedidoModel> activos = [];
      ClientePedidoModel? ultimo;
      List<ComercioModel> favoritos = [];
      List<CuponModel> cupones = [];
      try {
        direcciones = await widget.clienteRepository.getDirecciones();
      } catch (_) {}
      try {
        final pedidos = await widget.clienteRepository.getPedidos(limit: 20);
        activos = pedidos.data.where((p) => p.isActive).toList();
        ultimo = pedidos.data.where((p) => p.status == 'Entregado').firstOrNull;
      } catch (_) {}
      try {
        favoritos = await widget.clienteRepository.getFavoritosComercios();
      } catch (_) {}
      try {
        cupones = await widget.catalogRepository.getCuponesActivos();
      } catch (_) {}

      final comercios = comerciosResult.data;
      final promoBadges = <int, String>{};
      final conPromo = <ComercioModel>[];
      await Future.wait(
        comercios.take(12).map((c) async {
          try {
            final promos =
                await widget.catalogRepository.getPromociones(c.id);
            final activas = promos.where((p) => p.activo).toList();
            if (activas.isNotEmpty) {
              promoBadges[c.id] = activas.first.badgeLabel;
              conPromo.add(c);
            }
          } catch (_) {}
        }),
      );

      if (!mounted) return;

      DireccionModel? selected = _selectedDireccion;
      if (selected == null && direcciones.isNotEmpty) {
        selected = direcciones.where((d) => d.predeterminada).firstOrNull ??
            direcciones.first;
      } else if (selected != null) {
        final match = direcciones.where((d) => d.id == selected!.id);
        selected = match.isEmpty ? selected : match.first;
      }

      setState(() {
        _categorias = categoriasResult.data;
        _comercios = comercios;
        _favoritos = favoritos;
        _conPromo = conPromo;
        _promoBadges = promoBadges;
        _direcciones = direcciones;
        _pedidosActivos = activos;
        _ultimoEntregado = ultimo;
        _cupones = cupones;
        _selectedDireccion = selected;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categorias = CatalogMockData.fallbackCategorias;
        _comercios = CatalogMockData.fallbackComercios;
        // Sin banner de error: fallback silencioso.
        _loading = false;
      });
    }
  }

  void _onCategoryTap(int? categoriaId) {
    if (categoriaId == null) {
      if (_selectedCategoriaId == null) return;
      setState(() => _selectedCategoriaId = null);
      _loadData(silent: true);
      return;
    }

    final cat = _categorias.where((c) => c.id == categoriaId).firstOrNull;
    final nombre = Uri.encodeQueryComponent(cat?.nombreCategoria ?? '');
    context.push('/cliente/categoria/$categoriaId?nombre=$nombre');
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchLoading = false;
        _searchComercios = [];
        _searchProductos = [];
      });
      return;
    }

    setState(() {
      _searchQuery = query;
      _searchLoading = true;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      _runLiveSearch(query);
    });
  }

  Future<void> _runLiveSearch(String query) async {
    final requestId = ++_searchRequestId;
    try {
      final comerciosFuture =
          widget.catalogRepository.getComercios(search: query, limit: 8);
      final productosFuture =
          widget.catalogRepository.getProductos(search: query, limit: 12);
      final comercios = await comerciosFuture;
      final productos = await productosFuture;
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchComercios = comercios.data;
        _searchProductos = productos.data;
        _searchLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchComercios = [];
        _searchProductos = [];
        _searchLoading = false;
      });
    }
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchLoading = false;
      _searchComercios = [];
      _searchProductos = [];
    });
  }

  bool get _isSearching => _searchQuery.isNotEmpty;

  List<ComercioModel> get _abiertos =>
      _comercios.where((c) => c.estaAbierto).toList();

  Future<void> _pedirDeNuevo(ClientePedidoModel pedido) async {
    try {
      final detail = await widget.clienteRepository.getPedido(pedido.id);
      await widget.clienteRepository.repetirPedido(detail);
      if (!mounted) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pedido agregado al carrito'),
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
          content: Text('No se pudo repetir: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickLocation() async {
    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _LocationPickerSheet(
        direcciones: _direcciones,
        selectedId: _selectedDireccion?.id,
        onManage: () {
          Navigator.pop(ctx, 'manage');
        },
      ),
    );

    if (!mounted) return;
    if (result == 'manage') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ClienteDireccionesScreen(
            repository: widget.clienteRepository,
          ),
        ),
      );
      if (!mounted) return;
      await _loadData(categoriaId: _selectedCategoriaId);
      return;
    }
    if (result is DireccionModel) {
      setState(() => _selectedDireccion = result);
    }
  }

  /// Solo el tipo (Casa / Trabajo / …) para el header compacto.
  String get _locationShortLabel {
    final d = _selectedDireccion;
    if (d == null) return 'Dónde';
    final tipo = d.tipo.trim();
    if (tipo.isEmpty) return 'Dirección';
    return tipo;
  }

  @override
  Widget build(BuildContext context) {
    final abiertos = _abiertos;
    final destacados = abiertos.isNotEmpty ? abiertos : _comercios;
    final showVerMas = destacados.length > 3;
    final destacadosPreview = destacados.take(3).toList();
    final searchHint = searchPlaceholderForRubro(
      _categorias
          .where((c) => c.id == _selectedCategoriaId)
          .firstOrNull
          ?.nombreCategoria,
    );

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _HomeHeader(
            locationLabel: _locationShortLabel,
            onLocationTap: _pickLocation,
            onOpenNotification: widget.onOpenNotification,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: PromoAdsBanner(height: 140),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _YellowSearchCard(
              placeholder: searchHint,
              controller: _searchController,
              onChanged: _onSearchChanged,
              onClear: _clearSearch,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.yellow,
              onRefresh: () =>
                  _loadData(categoriaId: _selectedCategoriaId, silent: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                children: [
                  if (_isSearching) ...[
                    _LiveSearchResults(
                      loading: _searchLoading,
                      query: _searchQuery,
                      comercios: _searchComercios,
                      productos: _searchProductos,
                      onOpenComercio: widget.onOpenComercio,
                      onClear: _clearSearch,
                    ),
                  ] else ...[
                    CategoryMatrixSection(
                      categorias: _categorias,
                      selectedId: _selectedCategoriaId,
                      onTap: _onCategoryTap,
                      onMore: _openMoreCategoriesSheet,
                    ),
                    const SizedBox(height: 12),
                    _CouponBannerCarousel(cupones: _cupones),
                    if (_loading) ...[
                      const SizedBox(height: 16),
                      const StoresSectionSkeleton(),
                    ] else ...[
                      const SizedBox(height: 16),
                          if (_pedidosActivos.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _ActiveOrderCard(
                              pedido: _pedidosActivos.first,
                              onTap: () => widget.onOpenTracking
                                  ?.call(_pedidosActivos.first.id),
                              onSeeAll: widget.onGoPedidos,
                            ),
                          ],
                          if (_ultimoEntregado != null) ...[
                            const SizedBox(height: 12),
                            _RepeatOrderCard(
                              pedido: _ultimoEntregado!,
                              logoUrl: _logoForUltimoPedido(),
                              onRepeat: () => _pedirDeNuevo(_ultimoEntregado!),
                              onOpenComercio:
                                  _ultimoEntregado!.comercioId == null
                                      ? null
                                      : () => widget.onOpenComercio(
                                            _ultimoEntregado!.comercioId!,
                                          ),
                            ),
                          ],
                          if (_favoritos.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _SectionHeader(
                              title: 'Tus favoritos',
                              action: 'Ver más',
                              onAction: widget.onGoSearch,
                            ),
                            const SizedBox(height: 12),
                            ComercioMarketplaceList(
                              comercios: _favoritos,
                              promoBadges: _promoBadges,
                              onOpen: widget.onOpenComercio,
                            ),
                          ],
                          const SizedBox(height: 16),
                          _SectionHeader(
                            title: 'Locales destacados',
                            action: showVerMas ? 'Ver más' : '',
                            onAction: showVerMas ? widget.onGoSearch : null,
                          ),
                          const SizedBox(height: 12),
                          if (destacadosPreview.isEmpty)
                            EmptyActionState(
                              icon: Icons.store_outlined,
                              title: 'Sin comercios por ahora',
                              subtitle:
                                  'Probá otra categoría o buscá por nombre.',
                              actionLabel: 'Ir a buscar',
                              onAction: widget.onGoSearch,
                            )
                          else
                            ComercioMarketplaceList(
                              comercios: destacadosPreview,
                              promoBadges: _promoBadges,
                              onOpen: widget.onOpenComercio,
                            ),
                          if (_conPromo.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _SectionHeader(
                              title: 'Con promo hoy',
                              action: _conPromo.length > 3 ? 'Ver más' : '',
                              onAction: _conPromo.length > 3
                                  ? widget.onGoSearch
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            ComercioMarketplaceList(
                              comercios: _conPromo.take(3).toList(),
                              promoBadges: _promoBadges,
                              onOpen: widget.onOpenComercio,
                            ),
                          ],
                          if (_comercios.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const _SectionHeader(
                              title: 'Todos los locales',
                              action: '',
                            ),
                            const SizedBox(height: 12),
                            ComercioMarketplaceList(
                              comercios: _comercios,
                              promoBadges: _promoBadges,
                              onOpen: widget.onOpenComercio,
                            ),
                          ],
                        ],
                      ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _logoForUltimoPedido() {
    final pedido = _ultimoEntregado;
    if (pedido == null) return '';
    if (pedido.comercioLogoUrl.isNotEmpty) return pedido.comercioLogoUrl;
    final id = pedido.comercioId;
    if (id == null) return '';
    final match = [..._comercios, ..._favoritos]
        .where((c) => c.id == id)
        .firstOrNull;
    if (match == null) return '';
    return match.logoUrl.isNotEmpty ? match.logoUrl : match.imageUrl;
  }

  Future<void> _openMoreCategoriesSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Más categorías',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: 0.96,
                  ),
                  itemCount: _categorias.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return CategoryGridTile(
                        label: 'Todos',
                        emoji: '🏠',
                        backgroundColor: CategoryPalette.tileBackground(0),
                        selected: _selectedCategoriaId == null,
                        onTap: () {
                          Navigator.pop(ctx);
                          _onCategoryTap(null);
                        },
                      );
                    }
                    final cat = _categorias[index - 1];
                    return CategoryGridTile(
                      label: cat.nombreCategoria,
                      emoji: CatalogMockData.emojiForCategory(
                        cat.nombreCategoria,
                      ),
                      imageUrl:
                          cat.imageUrl.isNotEmpty ? cat.imageUrl : null,
                      backgroundColor: CategoryPalette.tileBackground(index),
                      selected: _selectedCategoriaId == cat.id,
                      onTap: () {
                        Navigator.pop(ctx);
                        _onCategoryTap(cat.id);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.locationLabel,
    required this.onLocationTap,
    this.onOpenNotification,
  });

  final String locationLabel;
  final VoidCallback onLocationTap;
  final ValueChanged<Map<String, dynamic>>? onOpenNotification;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 4, 0),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            InkWell(
              onTap: onLocationTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: AppColors.yellow,
                      size: 18,
                    ),
                    const SizedBox(width: 2),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 72),
                      child: Text(
                        locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.expand_more,
                      color: AppColors.gray500,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            const Expanded(
              child: Center(
                child: PediloLogo(height: 26, textColor: AppColors.navy),
              ),
            ),
            NotificationBell(onOpenNotification: onOpenNotification),
          ],
        ),
      ),
    );
  }
}

class _YellowSearchCard extends StatelessWidget {
  const _YellowSearchCard({
    required this.placeholder,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final String placeholder;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.yellow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(999),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.navy,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: placeholder,
            hintStyle: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.gray500,
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: AppColors.gray500,
              size: 16,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 32,
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  tooltip: 'Limpiar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.gray500,
                  ),
                );
              },
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: const BorderSide(
                color: AppColors.navy,
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveSearchResults extends StatelessWidget {
  const _LiveSearchResults({
    required this.loading,
    required this.query,
    required this.comercios,
    required this.productos,
    required this.onOpenComercio,
    required this.onClear,
  });

  final bool loading;
  final String query;
  final List<ComercioModel> comercios;
  final List<ProductoModel> productos;
  final ValueChanged<int> onOpenComercio;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.yellow,
            ),
          ),
        ),
      );
    }

    final empty = comercios.isEmpty && productos.isEmpty;
    if (empty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, color: AppColors.gray400),
            const SizedBox(height: 8),
            Text(
              'Sin resultados para “$query”',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Probá con otro nombre de producto o comercio.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.gray500,
              ),
            ),
            TextButton(
              onPressed: onClear,
              child: Text(
                'Limpiar búsqueda',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blue,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (productos.isNotEmpty) ...[
          Text(
            'Productos',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          ...productos.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SearchHitTile(
                imageUrl: p.imageUrl,
                title: p.nombre,
                subtitle: p.comercioNombre ?? 'Producto',
                trailing: p.precioLabel,
                fallbackIcon: Icons.lunch_dining_rounded,
                onTap: () {
                  final id = p.comercioId;
                  if (id != null) onOpenComercio(id);
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (comercios.isNotEmpty) ...[
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
            comercios: comercios,
            onOpen: onOpenComercio,
            spacing: 10,
          ),
        ],
      ],
    );
  }
}

class _SearchHitTile extends StatelessWidget {
  const _SearchHitTile({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.fallbackIcon,
    required this.onTap,
    this.trailingMuted = false,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final String trailing;
  final IconData fallbackIcon;
  final VoidCallback onTap;
  final bool trailingMuted;

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
                  color: trailingMuted ? AppColors.gray400 : AppColors.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationPickerSheet extends StatelessWidget {
  const _LocationPickerSheet({
    required this.direcciones,
    required this.selectedId,
    required this.onManage,
  });

  final List<DireccionModel> direcciones;
  final int? selectedId;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray400.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¿Dónde entregamos?',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Elegí una dirección guardada o agregá una nueva.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.gray500,
              ),
            ),
            const SizedBox(height: 16),
            if (direcciones.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Todavía no tenés direcciones guardadas.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.gray500,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: direcciones.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final d = direcciones[index];
                    final selected = d.id == selectedId;
                    return Material(
                      color: selected
                          ? AppColors.yellow.withValues(alpha: 0.25)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => Navigator.pop(context, d),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: selected
                                    ? AppColors.navy
                                    : AppColors.gray400,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.tipo,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                    Text(
                                      d.label,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppColors.gray500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (d.predeterminada)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.green,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Principal',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onManage,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Administrar direcciones'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepeatOrderCard extends StatelessWidget {
  const _RepeatOrderCard({
    required this.pedido,
    required this.onRepeat,
    this.logoUrl = '',
    this.onOpenComercio,
  });

  final ClientePedidoModel pedido;
  final VoidCallback onRepeat;
  final String logoUrl;
  final VoidCallback? onOpenComercio;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpenComercio ?? onRepeat,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: logoUrl.isNotEmpty
                      ? Image.network(
                          logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _logoFallback(),
                        )
                      : _logoFallback(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Último pedido',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      pedido.comercioNombre ?? 'Pedido #${pedido.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onRepeat,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.yellowDark,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  'Pedir de nuevo',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoFallback() {
    return Container(
      color: AppColors.navy,
      alignment: Alignment.center,
      child: const Icon(Icons.storefront_rounded, color: AppColors.yellow),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({
    required this.pedido,
    this.onTap,
    this.onSeeAll,
  });

  final ClientePedidoModel pedido;
  final VoidCallback? onTap;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Seguí tu pedido',
          action: 'Ver todos',
          onAction: onSeeAll,
        ),
        const SizedBox(height: 10),
        Material(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.yellow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delivery_dining,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pedido.comercioNombre ?? 'Tu pedido #${pedido.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                        Text(
                          pedido.status,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.yellow,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    pedido.totalLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.white.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    this.onAction,
  });

  final String title;
  final String action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const Spacer(),
        if (action.isNotEmpty && onAction != null)
          InkWell(
            onTap: onAction,
            child: Text(
              action,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.yellowDark,
              ),
            ),
          ),
      ],
    );
  }
}

class _CouponBannerCarousel extends StatefulWidget {
  const _CouponBannerCarousel({
    required this.cupones,
    this.autoPlayInterval = const Duration(seconds: 5),
  });

  final List<CuponModel> cupones;
  final Duration autoPlayInterval;

  @override
  State<_CouponBannerCarousel> createState() => _CouponBannerCarouselState();
}

class _CouponBannerCarouselState extends State<_CouponBannerCarousel> {
  late final PageController _controller;
  int _page = 0;
  Timer? _timer;

  List<CuponModel> get _items {
    if (widget.cupones.isNotEmpty) return widget.cupones;
    return const [
      CuponModel(
        id: 0,
        codigo: 'PEDILO20',
        tipo: 'Porcentaje',
        valor: 20,
        descripcion: 'en tu primera compra',
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant _CouponBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cupones != widget.cupones ||
        oldWidget.autoPlayInterval != widget.autoPlayInterval) {
      _startAutoPlay();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    final items = _items;
    if (items.length <= 1) return;
    _timer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % items.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 132,
          child: PageView.builder(
            controller: _controller,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, index) => _CouponSlide(cupon: items[index]),
          ),
        ),
        if (items.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(items.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: active ? 14 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: active ? AppColors.yellow : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _CouponSlide extends StatelessWidget {
  const _CouponSlide({required this.cupon});

  final CuponModel cupon;

  @override
  Widget build(BuildContext context) {
    final headline = cupon.tipo.toLowerCase().contains('porcent')
        ? '${cupon.valor.toStringAsFixed(0)}% OFF'
        : (cupon.valor > 0
            ? '\$${cupon.valor.toStringAsFixed(0)} OFF'
            : cupon.headline);
    final sub = (cupon.descripcion != null && cupon.descripcion!.trim().isNotEmpty)
        ? cupon.descripcion!
        : 'en tu primera compra';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (cupon.codigo.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.yellow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Usá el código: ${cupon.codigo}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.navyLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.lunch_dining_rounded,
                    color: AppColors.yellow,
                    size: 36,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
