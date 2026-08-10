import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/panel/panel_widgets.dart';
import '../../../../core/widgets/pedilo_logo.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../cliente/data/models/catalog_models.dart';
import '../../data/comerciante_repository.dart';
import '../../../shared/data/categoria_repository.dart';
import '../../../shared/data/categoria_producto_repository.dart';
import '../../../shared/data/comercio_form_repository.dart';
import '../../../shared/presentation/categorias/categoria_form_screen.dart';
import '../../../shared/presentation/categorias_producto/categoria_producto_form_screen.dart';
import '../forms/comercio_form_screen.dart';
import '../forms/producto_form_screen.dart';
import '../widgets/sales_chart.dart';

// ─── Dashboard ───────────────────────────────────────────────────────────────

class ComercianteDashboardTab extends StatefulWidget {
  const ComercianteDashboardTab({
    super.key,
    required this.repository,
    required this.comercio,
    required this.comercios,
    required this.onSelectComercio,
    required this.onToggleAbierto,
    required this.onGoPedidos,
    required this.onGoProductos,
    required this.onGoVentas,
    required this.onGoLocal,
    required this.onOpenCombos,
  });

  final ComercianteRepository repository;
  final ComercioModel? comercio;
  final List<ComercioModel> comercios;
  final ValueChanged<ComercioModel> onSelectComercio;
  final ValueChanged<bool> onToggleAbierto;
  final VoidCallback onGoPedidos;
  final VoidCallback onGoProductos;
  final VoidCallback onGoVentas;
  final VoidCallback onGoLocal;
  final VoidCallback onOpenCombos;

  @override
  State<ComercianteDashboardTab> createState() =>
      _ComercianteDashboardTabState();
}

class _ComercianteDashboardTabState extends State<ComercianteDashboardTab> {
  ComercioStatsModel? _stats;
  List<DailyStatModel> _weekSeries = [];
  List<PedidoModel> _recentPedidos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ComercianteDashboardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comercio?.id != widget.comercio?.id) _load();
  }

  Future<void> _load() async {
    final comercio = widget.comercio;
    if (comercio == null) {
      setState(() {
        _loading = false;
        _stats = null;
        _recentPedidos = [];
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final today = await widget.repository.getPeriodStats(
        comercio.id,
        rango: 'dia',
      );
      final week = await widget.repository.getPeriodStats(
        comercio.id,
        rango: 'semana',
      );
      final pedidosPage = await widget.repository.getPedidos(
        comercioId: comercio.id,
        limit: 5,
      );
      if (!mounted) return;
      setState(() {
        _stats = today.stats;
        _weekSeries = week.series;
        _recentPedidos = pedidosPage.data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final comercio = widget.comercio;

    return RefreshIndicator(
      color: AppColors.yellow,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _MerchantHeader(
              title: comercio?.name ?? 'Mi comercio',
              subtitle: comercio == null
                  ? 'Panel de Comerciante'
                  : (comercio.aprobado
                      ? 'Panel de Comerciante'
                      : 'Pendiente de aprobación'),
              userName: auth.user?.name ?? 'Comerciante',
              estaAbierto: comercio?.estaAbierto ?? false,
              aprobado: comercio?.aprobado ?? false,
              onToggleAbierto: comercio == null || !comercio.canToggleAbierto
                  ? null
                  : widget.onToggleAbierto,
              comercios: widget.comercios,
              selectedComercio: comercio,
              onSelectComercio: widget.onSelectComercio,
            ),
          ),
          if (comercio == null)
            const SliverFillRemaining(
              child: EmptyPanelState(
                icon: Icons.store_outlined,
                title: 'Sin comercio registrado',
                subtitle:
                    'Contactá al administrador para registrar tu local en la plataforma.',
              ),
            )
          else if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.yellow),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: StatGrid(
                  cards: [
                    StatCardData(
                      value: '${_stats?.cantidadPedidos ?? 0}',
                      label: 'Pedidos hoy',
                      highlight: true,
                    ),
                    StatCardData(
                      value:
                          '\$${(_stats?.totalVentas ?? 0).toStringAsFixed(0)}',
                      label: 'Ventas hoy',
                    ),
                    StatCardData(
                      value:
                          '\$${(_stats?.ticketPromedio ?? 0).toStringAsFixed(0)}',
                      label: 'Ticket promedio',
                    ),
                    StatCardData(
                      value: '${_stats?.pedidosCancelados ?? 0}',
                      label: 'Cancelados',
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: SalesBarChart(
                  data: _weekSeries,
                  title: 'Ventas — últimos 7 días',
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: QuickActionsRow(
                actions: [
                  QuickActionData(
                    emoji: '📦',
                    label: 'Pedidos',
                    onTap: widget.onGoPedidos,
                  ),
                  QuickActionData(
                    emoji: '🍔',
                    label: 'Productos',
                    onTap: widget.onGoProductos,
                  ),
                  QuickActionData(
                    emoji: '🏪',
                    label: 'Mi local',
                    onTap: widget.onGoLocal,
                  ),
                  QuickActionData(
                    emoji: '📊',
                    label: 'Ventas',
                    onTap: widget.onGoVentas,
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: PanelSectionHeader(
                title: 'Pedidos recientes',
                action: 'Ver todos',
                onAction: widget.onGoPedidos,
              ),
            ),
            if (_recentPedidos.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: EmptyPanelState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Sin pedidos aún',
                    subtitle: 'Los nuevos pedidos aparecerán acá.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PedidoCard(
                        pedido: _recentPedidos[index],
                        compact: true,
                        onTap: () => context.push(
                          '/comerciante/pedidos/${_recentPedidos[index].id}',
                        ),
                      ),
                    ),
                    childCount: _recentPedidos.length,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Pedidos ─────────────────────────────────────────────────────────────────

class ComerciantePedidosTab extends StatefulWidget {
  const ComerciantePedidosTab({
    super.key,
    required this.repository,
    required this.comercio,
    this.onOrdersChanged,
    this.refreshToken = 0,
  });

  final ComercianteRepository repository;
  final ComercioModel? comercio;
  final VoidCallback? onOrdersChanged;
  final int refreshToken;

  @override
  State<ComerciantePedidosTab> createState() => _ComerciantePedidosTabState();
}

class _ComerciantePedidosTabState extends State<ComerciantePedidosTab> {
  static const _filters = [
    'Todos',
    'Nuevos',
    'En curso',
    'Listos',
    'Historial',
  ];

  int _filterIndex = 0;
  List<PedidoModel> _allPedidos = [];
  List<PedidoModel> _pedidos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ComerciantePedidosTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comercio?.id != widget.comercio?.id ||
        oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  List<PedidoModel> _applyFilter(List<PedidoModel> all) {
    return switch (_filterIndex) {
      1 => all.where((p) => p.status == 'Pendiente').toList(),
      2 => all
          .where((p) => p.status == 'Aceptado' || p.status == 'Preparando')
          .toList(),
      3 => all
          .where((p) =>
              p.status == 'Listo' ||
              p.status == 'Enviado' ||
              p.status == 'En espera')
          .toList(),
      4 => all
          .where((p) => p.status == 'Entregado' || p.status == 'Cancelado')
          .toList(),
      _ => all,
    };
  }

  Future<void> _load() async {
    final comercio = widget.comercio;
    if (comercio == null) {
      setState(() {
        _loading = false;
        _allPedidos = [];
        _pedidos = [];
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final page = await widget.repository.getPedidos(
        comercioId: comercio.id,
        limit: 100,
      );
      if (!mounted) return;
      setState(() {
        _allPedidos = page.data;
        _pedidos = _applyFilter(_allPedidos);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  Future<void> _updateStatus(PedidoModel pedido, String status) async {
    try {
      await widget.repository.updatePedidoStatus(pedido.id, status);
      widget.onOrdersChanged?.call();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pedido #${pedido.id} → $status'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final comercio = widget.comercio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelAppBar(title: 'Pedidos', subtitle: comercio?.name),
        FilterChips(
          labels: _filters,
          selectedIndex: _filterIndex,
          onSelected: (index) {
            setState(() {
              _filterIndex = index;
              _pedidos = _applyFilter(_allPedidos);
            });
          },
        ),
        Expanded(
          child: comercio == null
              ? const EmptyPanelState(
                  icon: Icons.store_outlined,
                  title: 'Sin comercio',
                  subtitle: 'No hay un local asociado a tu cuenta.',
                )
              : _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.yellow),
                    )
                  : _pedidos.isEmpty
                      ? const EmptyPanelState(
                          icon: Icons.inbox_outlined,
                          title: 'No hay pedidos',
                          subtitle: 'Cuando lleguen pedidos los verás acá.',
                        )
                      : RefreshIndicator(
                          color: AppColors.yellow,
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: _pedidos.length,
                            itemBuilder: (context, index) {
                              final pedido = _pedidos[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: PedidoCard(
                                  pedido: pedido,
                                  onTap: () => context.push(
                                    '/comerciante/pedidos/${pedido.id}',
                                  ),
                                  onAction: (status) =>
                                      _updateStatus(pedido, status),
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

// ─── Productos ───────────────────────────────────────────────────────────────

class ComercianteProductosTab extends StatefulWidget {
  const ComercianteProductosTab({
    super.key,
    required this.repository,
    required this.categoriaProductoRepository,
    required this.comercio,
    this.onOpenCombos,
  });

  final ComercianteRepository repository;
  final CategoriaProductoRepository categoriaProductoRepository;
  final ComercioModel? comercio;
  final VoidCallback? onOpenCombos;

  @override
  State<ComercianteProductosTab> createState() =>
      _ComercianteProductosTabState();
}

class _ComercianteProductosTabState extends State<ComercianteProductosTab> {
  List<ProductoModel> _productos = [];
  List<CategoriaProductoModel> _categoriasProducto = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ComercianteProductosTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comercio?.id != widget.comercio?.id) _load();
  }

  Future<void> _load() async {
    final comercio = widget.comercio;
    if (comercio == null) {
      setState(() {
        _loading = false;
        _productos = [];
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final page =
          await widget.repository.getProductos(comercio.id, soloActivos: false);
      final cats =
          await widget.categoriaProductoRepository.getCategoriasProducto();
      if (!mounted) return;
      setState(() {
        _productos = page.data;
        _categoriasProducto = cats;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openCategoriasProducto() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoriasProductoListScreen(
          repository: widget.categoriaProductoRepository,
        ),
      ),
    );
    _load();
  }

  Future<void> _openForm([ProductoModel? producto]) async {
    final comercio = widget.comercio;
    if (comercio == null) return;

    if (_categoriasProducto.isEmpty) {
      final crear = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sin categorías de producto'),
          content: const Text(
            'Para crear productos necesitás al menos una categoría de producto. ¿Querés crear una ahora?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Crear categoría'),
            ),
          ],
        ),
      );
      if (crear == true && mounted) await _openCategoriasProducto();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductoFormScreen(
          repository: widget.repository,
          comercioId: comercio.id,
          categoriasProducto: _categoriasProducto,
          producto: producto,
          onManageCategorias: _openCategoriasProducto,
        ),
      ),
    );
    _load();
  }

  Future<void> _toggleActivo(ProductoModel producto) async {
    try {
      await widget.repository.updateProducto(
        id: producto.id,
        activo: !producto.activo,
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _delete(ProductoModel producto) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${producto.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await widget.repository.deleteProducto(producto.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final comercio = widget.comercio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelAppBar(
          title: 'Productos',
          subtitle: comercio?.name,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _openCategoriasProducto,
                icon: const Icon(Icons.category_outlined, color: AppColors.white),
                tooltip: 'Categorías de producto',
              ),
              if (widget.onOpenCombos != null)
                IconButton(
                  onPressed: widget.onOpenCombos,
                  icon: const Icon(Icons.local_offer_outlined,
                      color: AppColors.white),
                  tooltip: 'Combos',
                ),
              IconButton(
                onPressed: comercio == null ? null : () => _openForm(),
                icon: const Icon(Icons.add_circle, color: AppColors.yellow),
                tooltip: 'Nuevo producto',
              ),
            ],
          ),
        ),
        Expanded(
          child: comercio == null
              ? const EmptyPanelState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Sin comercio',
                  subtitle: 'Registrá tu local para gestionar productos.',
                )
              : _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.yellow),
                    )
                  : _productos.isEmpty
                      ? const EmptyPanelState(
                          icon: Icons.fastfood_outlined,
                          title: 'Sin productos',
                          subtitle:
                              'Agregá items a tu menú para empezar a vender.',
                        )
                      : RefreshIndicator(
                          color: AppColors.yellow,
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _productos.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final producto = _productos[index];
                              return _ProductoTile(
                                producto: producto,
                                onTap: () => _openForm(producto),
                                onToggleActivo: () => _toggleActivo(producto),
                                onDelete: () => _delete(producto),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

class _ProductoTile extends StatelessWidget {
  const _ProductoTile({
    required this.producto,
    required this.onTap,
    required this.onToggleActivo,
    required this.onDelete,
  });

  final ProductoModel producto;
  final VoidCallback onTap;
  final VoidCallback onToggleActivo;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: producto.imagen != null
                ? Image.network(
                    producto.imageUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _productoPlaceholder(),
                  )
                : _productoPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.nombre,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.navy,
                  ),
                ),
                if (producto.categoriaProductoId != null)
                  Text(
                    producto.categoriaLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.gray500,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                producto.precioLabel,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              PanelBadge(
                label: producto.activo ? 'Activo' : 'Inactivo',
                background: producto.activo
                    ? AppColors.green.withValues(alpha: 0.15)
                    : AppColors.gray400.withValues(alpha: 0.2),
                foreground:
                    producto.activo ? AppColors.green : AppColors.gray500,
              ),
            ],
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert, color: AppColors.gray500),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(
                value: 'toggle',
                child: Text(producto.activo ? 'Desactivar' : 'Activar'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
            onSelected: (v) {
              if (v == 'edit') onTap();
              if (v == 'toggle') onToggleActivo();
              if (v == 'delete') onDelete();
            },
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _productoPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      color: AppColors.cream,
      alignment: Alignment.center,
      child: const Icon(Icons.fastfood, color: AppColors.navy, size: 24),
    );
  }
}

// ─── Ventas ──────────────────────────────────────────────────────────────────

class ComercianteVentasTab extends StatefulWidget {
  const ComercianteVentasTab({
    super.key,
    required this.repository,
    required this.comercio,
  });

  final ComercianteRepository repository;
  final ComercioModel? comercio;

  @override
  State<ComercianteVentasTab> createState() => _ComercianteVentasTabState();
}

class _ComercianteVentasTabState extends State<ComercianteVentasTab> {
  static const _rangos = ['dia', 'semana', 'mes', 'anio'];
  static const _rangoLabels = ['Hoy', 'Semana', 'Mes', 'Año'];

  int _rangoIndex = 2;
  ComercioPeriodReport? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ComercianteVentasTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comercio?.id != widget.comercio?.id) _load();
  }

  Future<void> _load() async {
    final comercio = widget.comercio;
    if (comercio == null) {
      setState(() {
        _loading = false;
        _report = null;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final report = await widget.repository.getPeriodStats(
        comercio.id,
        rango: _rangos[_rangoIndex],
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final comercio = widget.comercio;
    final report = _report;
    final stats = report?.stats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelAppBar(title: 'Ventas', subtitle: comercio?.name),
        FilterChips(
          labels: _rangoLabels,
          selectedIndex: _rangoIndex,
          onSelected: (index) {
            setState(() => _rangoIndex = index);
            _load();
          },
        ),
        Expanded(
          child: comercio == null
              ? const EmptyPanelState(
                  icon: Icons.bar_chart_outlined,
                  title: 'Sin comercio',
                  subtitle: 'Las estadísticas aparecerán cuando tengas un local.',
                )
              : _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.yellow),
                    )
                  : RefreshIndicator(
                      color: AppColors.yellow,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          StatGrid(
                            cards: [
                              StatCardData(
                                value:
                                    '\$${(stats?.totalVentas ?? 0).toStringAsFixed(0)}',
                                label: 'Ventas',
                                highlight: true,
                              ),
                              StatCardData(
                                value: '${stats?.cantidadPedidos ?? 0}',
                                label: 'Pedidos',
                              ),
                              StatCardData(
                                value:
                                    '\$${(stats?.ticketPromedio ?? 0).toStringAsFixed(0)}',
                                label: 'Ticket promedio',
                              ),
                              StatCardData(
                                value: '${stats?.pedidosCancelados ?? 0}',
                                label: 'Cancelaciones',
                                change: report != null &&
                                        report.tasaCancelacion > 0
                                    ? '${report.tasaCancelacion.toStringAsFixed(1)}% del total'
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SalesBarChart(
                            data: report?.series ?? const [],
                            title: 'Ventas por día',
                          ),
                          if ((report?.topProductos ?? []).isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _VentasSection(
                              title: 'Productos más vendidos',
                              child: Column(
                                children: report!.topProductos
                                    .take(5)
                                    .map(
                                      (p) => _VentasRankRow(
                                        title: p.nombre,
                                        subtitle:
                                            '${p.cantidadVendida} uds · \$${p.total.toStringAsFixed(0)}',
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                          if ((report?.metodosPago ?? []).isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _VentasSection(
                              title: 'Métodos de pago',
                              child: Column(
                                children: report!.metodosPago
                                    .map(
                                      (m) => _VentasSummaryRow(
                                        label: m.metodo,
                                        value:
                                            '${m.cantidad} (${m.porcentaje}%)',
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}

class _VentasSection extends StatelessWidget {
  const _VentasSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _VentasRankRow extends StatelessWidget {
  const _VentasRankRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.star, color: AppColors.yellow, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.gray500,
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

class _VentasSummaryRow extends StatelessWidget {
  const _VentasSummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: AppColors.gray600,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Más / Config ────────────────────────────────────────────────────────────

class ComercianteMasTab extends StatelessWidget {
  const ComercianteMasTab({
    super.key,
    required this.formRepository,
    required this.categoriaRepository,
    required this.categoriaProductoRepository,
    required this.comercio,
    required this.comercios,
    required this.onLogout,
    required this.onComercioUpdated,
    this.onOpenCombos,
  });

  final ComercioFormRepository formRepository;
  final CategoriaRepository categoriaRepository;
  final CategoriaProductoRepository categoriaProductoRepository;
  final ComercioModel? comercio;
  final List<ComercioModel> comercios;
  final VoidCallback onLogout;
  final VoidCallback onComercioUpdated;
  final VoidCallback? onOpenCombos;

  Future<void> _editLocal(BuildContext context) async {
    final cats = await formRepository.getCategorias();
    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComercioFormScreen(
          repository: formRepository,
          categorias: cats,
          comercio: comercio,
          onSaved: (_) => onComercioUpdated(),
        ),
      ),
    );
    onComercioUpdated();
  }

  Future<void> _openCategoriasComercio(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoriasListScreen(
          repository: categoriaRepository,
        ),
      ),
    );
  }

  Future<void> _openCategoriasProducto(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoriasProductoListScreen(
          repository: categoriaProductoRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelAppBar(title: 'Más', subtitle: 'Configuración'),
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
                        _initials(auth.user?.name ?? 'C'),
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
                            auth.user?.name ?? 'Comerciante',
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
              if (comercio != null) ...[
                _MenuSection(
                  title: 'Mi local',
                  items: [
                    _MenuItemData(
                      icon: Icons.store,
                      label: comercio!.name,
                      subtitle: comercio!.direccion ?? 'Sin dirección',
                      onTap: () => _editLocal(context),
                    ),
                    _MenuItemData(
                      icon: Icons.category_outlined,
                      label: 'Categoría',
                      subtitle: comercio!.categoryLabel,
                    ),
                    _MenuItemData(
                      icon: Icons.phone_outlined,
                      label: 'Teléfono',
                      subtitle: comercio!.telefono ?? 'No configurado',
                    ),
                    _MenuItemData(
                      icon: Icons.delivery_dining_outlined,
                      label: 'Entrega',
                      subtitle: comercio!.tiposEntrega.isEmpty
                          ? 'No configurado'
                          : comercio!.tiposEntrega.join(', '),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ] else ...[
                _MenuSection(
                  title: 'Mi local',
                  items: [
                    _MenuItemData(
                      icon: Icons.add_business,
                      label: 'Registrar comercio',
                      subtitle: 'Creá tu local en la plataforma',
                      onTap: () => _editLocal(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              _MenuSection(
                title: 'Catálogo',
                items: [
                  _MenuItemData(
                    icon: Icons.inventory_2_outlined,
                    label: 'Categorías de producto',
                    subtitle: 'Crear y ver categorías para tus productos',
                    onTap: () => _openCategoriasProducto(context),
                  ),
                  _MenuItemData(
                    icon: Icons.category_outlined,
                    label: 'Categorías de comercio',
                    subtitle: 'Rubros de locales en la plataforma',
                    onTap: () => _openCategoriasComercio(context),
                  ),
                  if (comercio != null && onOpenCombos != null)
                    _MenuItemData(
                      icon: Icons.local_offer_outlined,
                      label: 'Combos',
                      subtitle:
                          'Packs de productos a precio especial',
                      onTap: onOpenCombos!,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _MenuSection(
                title: 'Cuenta',
                items: [
                  _MenuItemData(
                    icon: Icons.logout,
                    label: 'Cerrar sesión',
                    destructive: true,
                    onTap: onLogout,
                  ),
                ],
              ),
              if (comercios.length > 1) ...[
                const SizedBox(height: 12),
                Text(
                  '${comercios.length} comercios en tu cuenta',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'C';
  }
}

// ─── Shared widgets ──────────────────────────────────────────────────────────

class _MerchantHeader extends StatelessWidget {
  const _MerchantHeader({
    required this.title,
    required this.subtitle,
    required this.userName,
    required this.estaAbierto,
    this.aprobado = true,
    this.onToggleAbierto,
    this.comercios = const [],
    this.selectedComercio,
    this.onSelectComercio,
  });

  final String title;
  final String subtitle;
  final String userName;
  final bool estaAbierto;
  final bool aprobado;
  final ValueChanged<bool>? onToggleAbierto;
  final List<ComercioModel> comercios;
  final ComercioModel? selectedComercio;
  final ValueChanged<ComercioModel>? onSelectComercio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 16,
        20,
        24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PediloLogo(height: 28, textColor: AppColors.white),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'Comercio',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const Spacer(),
              if (onToggleAbierto != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      estaAbierto ? 'Abierto' : 'Cerrado',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.gray400,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Switch(
                      value: estaAbierto,
                      onChanged: onToggleAbierto,
                      activeThumbColor: AppColors.yellow,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
              if (!aprobado)
                PanelBadge(
                  label: 'Pendiente',
                  background: AppColors.yellow,
                  foreground: AppColors.navy,
                ),
            ],
          ),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.gray400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hola, $userName',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.white.withValues(alpha: 0.7),
            ),
          ),
          if (comercios.length > 1 && onSelectComercio != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ComercioModel>(
                  value: selectedComercio,
                  isExpanded: true,
                  dropdownColor: AppColors.navyLight,
                  style: GoogleFonts.poppins(color: AppColors.white, fontSize: 13),
                  items: comercios
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.name),
                        ),
                      )
                      .toList(),
                  onChanged: (c) {
                    if (c != null) onSelectComercio!(c);
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PanelAppBar extends StatelessWidget {
  const _PanelAppBar({
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                    style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.gray400,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class PedidoCard extends StatelessWidget {
  const PedidoCard({
    super.key,
    required this.pedido,
    this.onAction,
    this.onTap,
    this.compact = false,
  });

  final PedidoModel pedido;
  final ValueChanged<String>? onAction;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyle(pedido.status);

    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#${pedido.id}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const Spacer(),
              PanelBadge(
                label: pedido.status,
                background: statusStyle.bg,
                foreground: statusStyle.fg,
              ),
            ],
          ),
          if (pedido.clienteNombre != null) ...[
            const SizedBox(height: 4),
            Text(
              pedido.clienteNombre!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.gray500,
              ),
            ),
          ],
          if (pedido.itemsResumen != null && pedido.itemsResumen!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                pedido.itemsResumen!,
                style: GoogleFonts.poppins(fontSize: 13, color: AppColors.navy),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                pedido.totalLabel,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${pedido.tipoEntrega} · ${pedido.metodoPago}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.gray500,
                ),
              ),
            ],
          ),
          if (!compact && onAction != null) ...[
            const SizedBox(height: 10),
            ..._buildActions(),
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: card,
      ),
    );
  }

  List<Widget> _buildActions() {
    final actions = _nextActions(pedido.status, pedido.tipoEntrega);
    if (actions.isEmpty) return [];

    return [
      Row(
        children: actions.map((action) {
          final isReject = action.status == 'Cancelado';
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilledButton(
                onPressed: () => onAction!(action.status),
                style: FilledButton.styleFrom(
                  backgroundColor: isReject
                      ? const Color(0xFFFEE2E2)
                      : action.color,
                  foregroundColor:
                      isReject ? const Color(0xFFEF4444) : AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  action.label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ];
  }

  static _StatusStyle _statusStyle(String status) {
    return switch (status) {
      'Pendiente' => _StatusStyle(
          AppColors.yellow.withValues(alpha: 0.25),
          AppColors.navy,
        ),
      'Preparando' || 'Aceptado' => _StatusStyle(
          AppColors.blue.withValues(alpha: 0.15),
          AppColors.blue,
        ),
      'Listo' || 'Enviado' => _StatusStyle(
          AppColors.green.withValues(alpha: 0.15),
          AppColors.green,
        ),
      'Entregado' => _StatusStyle(
          AppColors.green.withValues(alpha: 0.2),
          AppColors.green,
        ),
      'Cancelado' => _StatusStyle(
          const Color(0xFFFEE2E2),
          const Color(0xFFEF4444),
        ),
      _ => _StatusStyle(
          AppColors.gray400.withValues(alpha: 0.2),
          AppColors.gray600,
        ),
    };
  }

  static List<_PedidoAction> _nextActions(String status, String tipoEntrega) {
    final isDelivery = tipoEntrega.toLowerCase().contains('delivery') ||
        tipoEntrega.toLowerCase().contains('envio');

    return switch (status) {
      'Pendiente' => [
          _PedidoAction('Aceptar', 'Aceptado', AppColors.green),
          _PedidoAction('Rechazar', 'Cancelado', AppColors.gray400),
        ],
      'Aceptado' => [
          _PedidoAction('Preparar', 'Preparando', AppColors.blue),
        ],
      'Preparando' => [
          _PedidoAction('Listo', 'Listo', AppColors.blue),
        ],
      'Listo' || 'En espera' => [
          if (isDelivery)
            _PedidoAction('Enviado', 'Enviado', AppColors.blue),
          _PedidoAction('Entregado', 'Entregado', AppColors.green),
        ],
      'Enviado' => [
          _PedidoAction('Entregado', 'Entregado', AppColors.green),
        ],
      _ => [],
    };
  }
}

class _StatusStyle {
  const _StatusStyle(this.bg, this.fg);
  final Color bg;
  final Color fg;
}

class _PedidoAction {
  const _PedidoAction(this.label, this.status, this.color);
  final String label;
  final String status;
  final Color color;
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.title, required this.items});

  final String title;
  final List<_MenuItemData> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.gray500,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: items.map((item) => _MenuTile(item: item)).toList(),
          ),
        ),
      ],
    );
  }
}

class _MenuItemData {
  const _MenuItemData({
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool destructive;
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.item});

  final _MenuItemData item;

  @override
  Widget build(BuildContext context) {
    final color = item.destructive ? const Color(0xFFEF4444) : AppColors.navy;

    return ListTile(
      leading: Icon(item.icon, color: color),
      title: Text(
        item.label,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: color),
      ),
      subtitle: item.subtitle != null
          ? Text(
              item.subtitle!,
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.gray500),
            )
          : null,
      trailing: item.onTap != null
          ? Icon(Icons.chevron_right, color: AppColors.gray400)
          : null,
      onTap: item.onTap,
    );
  }
}
