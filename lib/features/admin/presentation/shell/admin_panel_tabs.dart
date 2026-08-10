import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/panel/panel_widgets.dart';
import '../../../../core/widgets/pedilo_logo.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../data/admin_repository.dart';
import '../../../comerciante/presentation/forms/comercio_form_screen.dart';
import '../../../shared/data/categoria_repository.dart';
import '../../../shared/data/categoria_producto_repository.dart';
import '../../../shared/data/comercio_form_repository.dart';
import '../../../shared/presentation/categorias/categoria_form_screen.dart';
import '../../../shared/presentation/categorias_producto/categoria_producto_form_screen.dart';
import '../forms/admin_comisiones_screen.dart';
import '../forms/admin_cupones_screen.dart';
import '../forms/comercio_admin_detail_screen.dart';
import '../forms/usuario_admin_detail_screen.dart';
import '../widgets/admin_sales_chart.dart';
import '../../../../core/utils/error_messages.dart';

// ─── Dashboard ───────────────────────────────────────────────────────────────

class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({
    super.key,
    required this.repository,
    required this.onGoComercios,
    required this.onGoUsuarios,
    required this.onGoReportes,
    required this.onGoConfig,
  });

  final AdminRepository repository;
  final VoidCallback onGoComercios;
  final VoidCallback onGoUsuarios;
  final VoidCallback onGoReportes;
  final VoidCallback onGoConfig;

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  GlobalStatsModel? _stats;
  List<DailyStatModel> _series = [];
  List<AdminComercioModel> _comercios = [];
  List<AdminUserModel> _usuarios = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    GlobalStatsModel? stats;
    List<DailyStatModel> series = [];
    List<AdminComercioModel> comercios = [];
    List<AdminUserModel> usuarios = [];
    final errores = <String>[];

    try {
      stats = await widget.repository.getGlobalStats();
    } catch (e) {
      errores.add('Estadísticas: ${mensajeErrorEspanol(e)}');
    }

    try {
      series = await widget.repository.getGlobalSeries(rango: 'semana');
    } catch (e) {
      errores.add('Gráfico de ventas: ${mensajeErrorEspanol(e)}');
    }

    try {
      comercios = await widget.repository.getComercios();
    } catch (e) {
      errores.add('Comercios: ${mensajeErrorEspanol(e)}');
    }

    try {
      usuarios = await widget.repository.getUsuarios();
    } catch (e) {
      errores.add('Usuarios: ${mensajeErrorEspanol(e)}');
    }

    if (!mounted) return;
    setState(() {
      _stats = stats;
      _series = series;
      _comercios = comercios;
      _usuarios = usuarios;
      _loading = false;
    });

    if (errores.isNotEmpty && mounted) {
      await mostrarAlertaError(
        context,
        mensaje: errores.join('\n\n'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final activos = _comercios.where((c) => c.aprobado && c.estaAbierto).length;
    final sinAprobar = _comercios.where((c) => !c.aprobado).length;

    return RefreshIndicator(
      color: AppColors.yellow,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _AdminHeader(
              title: 'Dashboard',
              userName: auth.user?.name ?? 'Administrador',
            ),
          ),
          if (_loading)
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
                      value: '$activos',
                      label: 'Comercios activos',
                      highlight: true,
                      change: '$sinAprobar sin aprobar',
                    ),
                    StatCardData(
                      value: '${_stats?.pedidosTotales ?? 0}',
                      label: 'Pedidos totales',
                    ),
                    StatCardData(
                      value: _stats?.ventasLabel ?? '\$0',
                      label: 'Ventas totales',
                    ),
                    StatCardData(
                      value: '${_usuarios.length}',
                      label: 'Usuarios',
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: AdminSalesBarChart(
                  data: _series,
                  title: 'Ventas globales — últimos 7 días',
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: QuickActionsRow(
                actions: [
                  QuickActionData(
                    emoji: '🏪',
                    label: 'Comercios',
                    onTap: widget.onGoComercios,
                  ),
                  QuickActionData(
                    emoji: '👥',
                    label: 'Usuarios',
                    onTap: widget.onGoUsuarios,
                  ),
                  QuickActionData(
                    emoji: '📊',
                    label: 'Reportes',
                    onTap: widget.onGoReportes,
                  ),
                  QuickActionData(
                    emoji: '⚙️',
                    label: 'Config',
                    onTap: widget.onGoConfig,
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: PanelSectionHeader(
                title: 'Top comercios',
                action: 'Ver todos',
                onAction: widget.onGoComercios,
              ),
            ),
            if ((_stats?.topComercios ?? []).isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: EmptyPanelState(
                    icon: Icons.store_outlined,
                    title: 'Sin datos de ventas',
                    subtitle: 'Los top comercios aparecerán cuando haya pedidos.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _stats!.topComercios[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _TopComercioTile(rank: index + 1, item: item),
                      );
                    },
                    childCount: _stats!.topComercios.length,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TopComercioTile extends StatelessWidget {
  const _TopComercioTile({required this.rank, required this.item});

  final int rank;
  final TopComercioStat item;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.yellow,
            child: Text(
              '$rank',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.nombre,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
          Text(
            item.totalLabel,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: AppColors.green,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Comercios ───────────────────────────────────────────────────────────────

class AdminComerciosTab extends StatefulWidget {
  const AdminComerciosTab({
    super.key,
    required this.repository,
    required this.formRepository,
    required this.categoriaRepository,
  });

  final AdminRepository repository;
  final ComercioFormRepository formRepository;
  final CategoriaRepository categoriaRepository;

  @override
  State<AdminComerciosTab> createState() => _AdminComerciosTabState();
}

class _AdminComerciosTabState extends State<AdminComerciosTab> {
  static const _filters = ['Todos', 'Sin aprobar', 'Activos', 'Suspendidos'];

  int _filterIndex = 0;
  List<AdminComercioModel> _comercios = [];
  bool _loading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final comercios = await widget.repository.getComercios();
      if (!mounted) return;
      setState(() {
        _comercios = comercios;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await mostrarAlertaError(
        context,
        mensaje: mensajeErrorEspanol(e),
      );
    }
  }

  List<AdminComercioModel> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    return _comercios.where((c) {
      final matchesSearch = query.isEmpty ||
          c.name.toLowerCase().contains(query) ||
          (c.comercianteNombre?.toLowerCase().contains(query) ?? false);

      final matchesFilter = switch (_filterIndex) {
        1 => c.estatusValue == 'pendiente',
        2 => c.isPublic,
        3 => c.estatusValue == 'suspendido' || c.estatusValue == 'inactivo',
        _ => true,
      };

      return matchesSearch && matchesFilter;
    }).toList();
  }

  Future<void> _setEstatus(
    AdminComercioModel comercio,
    String estatus,
  ) async {
    final aprobar = estatus == 'activo' || estatus == 'aprobado';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(aprobar ? 'Aprobar comercio' : 'Suspender comercio'),
        content: Text(
          aprobar
              ? '¿Aprobar "${comercio.name}"?\nQuedará visible para los clientes.'
              : '¿Suspender "${comercio.name}"?\nDejará de aparecer en el listado público.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: aprobar ? AppColors.green : const Color(0xFFEF4444),
              foregroundColor: AppColors.white,
            ),
            child: Text(aprobar ? 'Aprobar' : 'Suspender'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    try {
      await widget.repository.setComercioEstatus(comercio.id, estatus);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            aprobar
                ? '${comercio.name} fue aprobado y ya es visible'
                : '${comercio.name} fue suspendido',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: aprobar ? AppColors.green : const Color(0xFFEF4444),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  Future<void> _openCreate() async {
    final cats = await widget.categoriaRepository.getCategorias();
    if (!mounted) return;
    if (cats.isEmpty) {
      await mostrarAlertaError(
        context,
        titulo: 'Sin categorías',
        mensaje:
            'Primero creá al menos una categoría en Config → Categorías.',
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComercioFormScreen(
          repository: widget.formRepository,
          categorias: cats,
          isAdmin: true,
          onSaved: (_) => _load(),
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.paddingOf(context).top + 8,
            16,
            12,
          ),
          color: AppColors.navy,
          child: Row(
            children: [
              Text(
                'Comercios',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _openCreate,
                icon: const Icon(Icons.add_circle, color: AppColors.yellow),
                tooltip: 'Registrar comercio',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar comercio...',
              prefixIcon: const Icon(Icons.search, color: AppColors.gray500),
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        FilterChips(
          labels: _filters,
          selectedIndex: _filterIndex,
          onSelected: (i) => setState(() => _filterIndex = i),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.yellow),
                )
              : filtered.isEmpty
                  ? const EmptyPanelState(
                      icon: Icons.store_outlined,
                      title: 'Sin comercios',
                      subtitle: 'No hay comercios que coincidan con el filtro.',
                    )
                  : RefreshIndicator(
                      color: AppColors.yellow,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final comercio = filtered[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ComercioAdminCard(
                              comercio: comercio,
                              onOpenDetail: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ComercioAdminDetailScreen(
                                      repository: widget.repository,
                                      formRepository: widget.formRepository,
                                      comercio: comercio,
                                      onUpdated: _load,
                                    ),
                                  ),
                                );
                              },
                              onAprobar: comercio.canAprobar
                                  ? () => _setEstatus(comercio, 'activo')
                                  : null,
                              onSuspender: comercio.canSuspender
                                  ? () => _setEstatus(comercio, 'suspendido')
                                  : null,
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

class _ComercioAdminCard extends StatelessWidget {
  const _ComercioAdminCard({
    required this.comercio,
    required this.onOpenDetail,
    this.onAprobar,
    this.onSuspender,
  });

  final AdminComercioModel comercio;
  final VoidCallback onOpenDetail;
  final VoidCallback? onAprobar;
  final VoidCallback? onSuspender;

  @override
  Widget build(BuildContext context) {
    final status = comercio.statusLabel;
    final (bg, fg) = switch (status) {
      'Sin aprobar' => (
          AppColors.yellow.withValues(alpha: 0.25),
          AppColors.navy,
        ),
      'Activo' => (
          AppColors.green.withValues(alpha: 0.15),
          AppColors.green,
        ),
      'Cerrado' => (
          AppColors.gray400.withValues(alpha: 0.2),
          AppColors.gray600,
        ),
      'Suspendido' => (
          const Color(0xFFFEE2E2),
          const Color(0xFFEF4444),
        ),
      _ => (
          AppColors.gray400.withValues(alpha: 0.2),
          AppColors.gray600,
        ),
    };

    return Container(
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
          InkWell(
            onTap: onOpenDetail,
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: comercio.logo != null
                      ? Image.network(
                          comercio.logoUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _logoPlaceholder(),
                        )
                      : _logoPlaceholder(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comercio.name,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        comercio.categoriaNombre ?? 'Sin categoría',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.gray500,
                        ),
                      ),
                      if (comercio.comercianteNombre != null)
                        Text(
                          comercio.comercianteNombre!,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.gray400,
                          ),
                        ),
                    ],
                  ),
                ),
                PanelBadge(label: status, background: bg, foreground: fg),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (onAprobar != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAprobar,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                label: Text(
                  'Aprobar comercio',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            )
          else if (onSuspender != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSuspender,
                icon: const Icon(Icons.block, size: 18),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFEE2E2),
                  foregroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                label: Text(
                  'Suspender comercio',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _logoPlaceholder() {
    return Container(
      width: 48,
      height: 48,
      color: AppColors.cream,
      alignment: Alignment.center,
      child: const Icon(Icons.store, color: AppColors.navy),
    );
  }
}

// ─── Usuarios ────────────────────────────────────────────────────────────────

class AdminUsuariosTab extends StatefulWidget {
  const AdminUsuariosTab({
    super.key,
    required this.repository,
    required this.formRepository,
  });

  final AdminRepository repository;
  final ComercioFormRepository formRepository;

  @override
  State<AdminUsuariosTab> createState() => _AdminUsuariosTabState();
}

class _AdminUsuariosTabState extends State<AdminUsuariosTab> {
  static const _filters = [
    'Todos',
    'Clientes',
    'Comerciantes',
    'Admins',
    'Suspendidos',
  ];

  int _filterIndex = 0;
  List<AdminUserModel> _usuarios = [];
  bool _loading = true;
  final _searchController = TextEditingController();

  int? get _currentUserId => context.read<AuthProvider>().user?.id;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final usuarios = await widget.repository.getUsuarios();
      if (!mounted) return;
      setState(() {
        _usuarios = usuarios;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  List<AdminUserModel> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    return _usuarios.where((u) {
      final matchesSearch = query.isEmpty ||
          u.name.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query);

      final matchesFilter = switch (_filterIndex) {
        1 => u.role == 'cliente',
        2 => u.role == 'comerciante',
        3 => u.role == 'administrador',
        4 => !u.activo,
        _ => true,
      };

      return matchesSearch && matchesFilter;
    }).toList();
  }

  Future<void> _toggleActivo(AdminUserModel user, bool activo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(activo ? 'Reactivar usuario' : 'Suspender usuario'),
        content: Text(
          activo
              ? '¿Reactivar a "${user.name}"?\nPodrá iniciar sesión nuevamente.'
              : '¿Suspender a "${user.name}"?\nNo podrá iniciar sesión hasta ser reactivado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: activo ? AppColors.green : const Color(0xFFEF4444),
              foregroundColor: AppColors.white,
            ),
            child: Text(activo ? 'Reactivar' : 'Suspender'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    try {
      await widget.repository.setUsuarioActivo(user.id, activo);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            activo
                ? '${user.name} fue reactivado'
                : '${user.name} fue suspendido',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: activo ? AppColors.green : const Color(0xFFEF4444),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdminSubHeader(title: 'Usuarios'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar usuario...',
              prefixIcon: const Icon(Icons.search, color: AppColors.gray500),
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        FilterChips(
          labels: _filters,
          selectedIndex: _filterIndex,
          onSelected: (i) => setState(() => _filterIndex = i),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.yellow),
                )
              : filtered.isEmpty
                  ? const EmptyPanelState(
                      icon: Icons.people_outline,
                      title: 'Sin usuarios',
                      subtitle: 'No hay usuarios que coincidan con el filtro.',
                    )
                  : RefreshIndicator(
                      color: AppColors.yellow,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final user = filtered[index];
                          final currentUserId = _currentUserId;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _UsuarioTile(
                              user: user,
                              isSelf: currentUserId == user.id,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UsuarioAdminDetailScreen(
                                      repository: widget.repository,
                                      formRepository: widget.formRepository,
                                      user: user,
                                      onUpdated: _load,
                                    ),
                                  ),
                                );
                                _load();
                              },
                              onSuspender: user.canBeSuspended &&
                                      currentUserId != user.id &&
                                      user.activo
                                  ? () => _toggleActivo(user, false)
                                  : null,
                              onReactivar: user.canBeSuspended &&
                                      currentUserId != user.id &&
                                      !user.activo
                                  ? () => _toggleActivo(user, true)
                                  : null,
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

class _UsuarioTile extends StatelessWidget {
  const _UsuarioTile({
    required this.user,
    required this.isSelf,
    required this.onTap,
    this.onSuspender,
    this.onReactivar,
  });

  final AdminUserModel user;
  final bool isSelf;
  final VoidCallback onTap;
  final VoidCallback? onSuspender;
  final VoidCallback? onReactivar;

  @override
  Widget build(BuildContext context) {
    final (roleBg, roleFg) = switch (user.role) {
      'administrador' => (
          AppColors.blue.withValues(alpha: 0.15),
          AppColors.blue,
        ),
      'comerciante' => (
          AppColors.yellow.withValues(alpha: 0.25),
          AppColors.navy,
        ),
      _ => (
          AppColors.gray400.withValues(alpha: 0.15),
          AppColors.gray600,
        ),
    };

    final status = user.statusLabel;
    final (statusBg, statusFg) = switch (status) {
      'Activo' => (
          AppColors.green.withValues(alpha: 0.15),
          AppColors.green,
        ),
      _ => (
          AppColors.gray400.withValues(alpha: 0.2),
          AppColors.gray600,
        ),
    };

    return Container(
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
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.yellow,
                  child: Text(
                    user.initials,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        user.email,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.gray500,
                        ),
                      ),
                      if (isSelf)
                        Text(
                          'Tu cuenta',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    PanelBadge(
                      label: user.roleLabel,
                      background: roleBg,
                      foreground: roleFg,
                    ),
                    const SizedBox(height: 6),
                    PanelBadge(
                      label: status,
                      background: statusBg,
                      foreground: statusFg,
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.gray400),
              ],
            ),
          ),
          if (onReactivar != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onReactivar,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                label: Text(
                  'Reactivar usuario',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ] else if (onSuspender != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSuspender,
                icon: const Icon(Icons.block, size: 18),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFEE2E2),
                  foregroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                label: Text(
                  'Suspender usuario',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Reportes ────────────────────────────────────────────────────────────────

class AdminReportesTab extends StatefulWidget {
  const AdminReportesTab({super.key, required this.repository});

  final AdminRepository repository;

  @override
  State<AdminReportesTab> createState() => _AdminReportesTabState();
}

class _AdminReportesTabState extends State<AdminReportesTab> {
  static const _rangos = ['mes', 'trimestre', 'anio'];
  static const _rangoLabels = ['Mes', 'Trimestre', 'Año'];

  int _rangoIndex = 0;
  AdminReportModel? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final report =
          await widget.repository.getReport(rango: _rangos[_rangoIndex]);
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
    final report = _report;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AdminSubHeader(title: 'Reportes globales'),
        FilterChips(
          labels: _rangoLabels,
          selectedIndex: _rangoIndex,
          onSelected: (i) {
            setState(() => _rangoIndex = i);
            _load();
          },
          dark: true,
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.yellow),
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
                            value: report?.ventasPeriodoLabel ?? '\$0',
                            label: 'Ventas totales',
                            highlight: true,
                          ),
                          StatCardData(
                            value: '${report?.pedidosPeriodo ?? 0}',
                            label: 'Pedidos',
                          ),
                          StatCardData(
                            value:
                                '\$${(report?.ticketPeriodo ?? 0).toStringAsFixed(0)}',
                            label: 'Ticket promedio',
                          ),
                          StatCardData(
                            value:
                                '${report?.cancelaciones.totalCancelados ?? 0}',
                            label: 'Cancelados',
                            change: report != null
                                ? '${report.cancelaciones.porcentaje.toStringAsFixed(1)}% del total'
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AdminSalesBarChart(
                        data: report?.series ?? const [],
                        title: 'Ventas por día',
                      ),
                      const SizedBox(height: 16),
                      if ((report?.stats.topComercios ?? []).isNotEmpty)
                        _ReportCard(
                          title: 'Top comercios (histórico total)',
                          child: Column(
                            children: report!.stats.topComercios
                                .asMap()
                                .entries
                                .map(
                                  (e) => _RankRow(
                                    rank: e.key + 1,
                                    title: e.value.nombre,
                                    subtitle: e.value.totalLabel,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      if ((report?.topProductos ?? []).isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _ReportCard(
                          title: 'Productos más vendidos',
                          child: Column(
                            children: report!.topProductos
                                .asMap()
                                .entries
                                .map(
                                  (e) => _RankRow(
                                    rank: e.key + 1,
                                    title: e.value.nombre,
                                    subtitle:
                                        '${e.value.comercioNombre} · ${e.value.cantidadVendida} uds',
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                      if ((report?.topCategorias ?? []).isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _ReportCard(
                          title: 'Categorías más vendidas',
                          child: Column(
                            children: report!.topCategorias
                                .asMap()
                                .entries
                                .map(
                                  (e) => _RankRow(
                                    rank: e.key + 1,
                                    title: e.value.nombre,
                                    subtitle:
                                        '${e.value.cantidadVendida} uds · \$${e.value.total.toStringAsFixed(0)}',
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                      if ((report?.metodosPago ?? []).isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _ReportCard(
                          title: 'Métodos de pago',
                          child: Column(
                            children: report!.metodosPago
                                .map(
                                  (m) => _SummaryLine(
                                    label: m.metodo,
                                    value:
                                        '${m.cantidad} (${m.porcentaje}%)',
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                      if ((report?.clientesFrecuentes ?? []).isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _ReportCard(
                          title: 'Clientes frecuentes',
                          child: Column(
                            children: report!.clientesFrecuentes
                                .asMap()
                                .entries
                                .map(
                                  (e) => _RankRow(
                                    rank: e.key + 1,
                                    title: e.value.nombre,
                                    subtitle:
                                        '${e.value.pedidos} pedidos · \$${e.value.totalGastado.toStringAsFixed(0)}',
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _ReportCard(
                        title:
                            'Comisiones generadas (${kAdminComisionPorcentaje.toStringAsFixed(0)}%)',
                        child: Column(
                          children: [
                            _SummaryLine(
                              label: 'Total comisiones',
                              value:
                                  '\$${(report?.comisionesGeneradas ?? 0).toStringAsFixed(0)}',
                              bold: true,
                            ),
                            _SummaryLine(
                              label: 'Pedidos en período',
                              value: '${report?.pedidosPeriodo ?? 0}',
                            ),
                            _SummaryLine(
                              label: 'Tasa de cancelación',
                              value:
                                  '${report?.cancelaciones.porcentaje.toStringAsFixed(1) ?? '0'}%',
                            ),
                            _SummaryLine(
                              label: 'Clientes frecuentes',
                              value:
                                  '${report?.clientesFrecuentes.length ?? 0}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.title, required this.child});

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

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.title,
    required this.subtitle,
  });

  final int rank;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor:
                rank == 1 ? AppColors.yellow : AppColors.cream,
            child: Text(
              '$rank',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
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

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

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
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: bold ? AppColors.green : AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Config ──────────────────────────────────────────────────────────────────

class AdminConfigTab extends StatelessWidget {
  const AdminConfigTab({
    super.key,
    required this.repository,
    required this.categoriaRepository,
    required this.categoriaProductoRepository,
    required this.onLogout,
  });

  final AdminRepository repository;
  final CategoriaRepository categoriaRepository;
  final CategoriaProductoRepository categoriaProductoRepository;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AdminSubHeader(title: 'Configuración'),
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
                            : 'A',
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
                            auth.user?.name ?? 'Administrador',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                          ),
                          Text(
                            'Administrador',
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
              _ConfigSection(
                items: [
                  _ConfigItem(
                    icon: Icons.category_outlined,
                    label: 'Categorías de comercio',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CategoriasListScreen(
                            repository: categoriaRepository,
                            canDelete: true,
                          ),
                        ),
                      );
                    },
                  ),
                  _ConfigItem(
                    icon: Icons.inventory_2_outlined,
                    label: 'Categorías de producto',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CategoriasProductoListScreen(
                            repository: categoriaProductoRepository,
                            canDelete: true,
                          ),
                        ),
                      );
                    },
                  ),
                  _ConfigItem(
                    icon: Icons.percent,
                    label: 'Comisiones',
                    subtitle:
                        '${kAdminComisionPorcentaje.toStringAsFixed(0)}% por venta',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminComisionesScreen(
                            repository: repository,
                          ),
                        ),
                      );
                    },
                  ),
                  _ConfigItem(
                    icon: Icons.local_offer_outlined,
                    label: 'Promociones globales',
                    subtitle: 'Cupones de descuento',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminCuponesScreen(
                            repository: repository,
                          ),
                        ),
                      );
                    },
                  ),
                  _ConfigItem(
                    icon: Icons.logout,
                    label: 'Cerrar sesión',
                    destructive: true,
                    onTap: onLogout,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConfigSection extends StatelessWidget {
  const _ConfigSection({required this.items});

  final List<_ConfigItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: items
            .map(
              (item) => ListTile(
                leading: Icon(
                  item.icon,
                  color: item.destructive
                      ? const Color(0xFFEF4444)
                      : AppColors.navy,
                ),
                title: Text(
                  item.label,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: item.destructive
                        ? const Color(0xFFEF4444)
                        : AppColors.navy,
                  ),
                ),
                subtitle: item.subtitle == null
                    ? null
                    : Text(
                        item.subtitle!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.gray500,
                        ),
                      ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.gray400),
                onTap: item.onTap,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ConfigItem {
  const _ConfigItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;
}

// ─── Shared headers ──────────────────────────────────────────────────────────

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.title, required this.userName});

  final String title;
  final String userName;

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
                  'Admin',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
          Text(
            'Hola, $userName',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.gray400,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSubHeader extends StatelessWidget {
  const _AdminSubHeader({required this.title});

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
