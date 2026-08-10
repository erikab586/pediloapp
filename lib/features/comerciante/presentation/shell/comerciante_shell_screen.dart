import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/socket_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/panel/panel_widgets.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../cliente/data/models/catalog_models.dart';
import '../../../shared/data/categoria_repository.dart';
import '../../../shared/data/categoria_producto_repository.dart';
import '../../../shared/data/comercio_form_repository.dart';
import '../../data/comerciante_repository.dart';
import 'comerciante_panel_tabs.dart';

class ComercianteShellScreen extends StatefulWidget {
  const ComercianteShellScreen({super.key});

  @override
  State<ComercianteShellScreen> createState() => _ComercianteShellScreenState();
}

class _ComercianteShellScreenState extends State<ComercianteShellScreen> {
  late final ComercianteRepository _repository;
  late final ComercioFormRepository _formRepository;
  late final CategoriaRepository _categoriaRepository;
  late final CategoriaProductoRepository _categoriaProductoRepository;
  int _tabIndex = 0;
  List<ComercioModel> _comercios = [];
  ComercioModel? _comercio;
  bool _loading = true;
  int _pendingCount = 0;
  int _lastNuevoPedidoId = 0;
  int _pedidosRefreshToken = 0;

  StreamSubscription<Map<String, dynamic>>? _nuevoPedidoSub;
  StreamSubscription<Map<String, dynamic>>? _pedidoCanceladoSub;
  StreamSubscription<SocketConnection>? _connSub;

  @override
  void initState() {
    super.initState();
    final api = context.read<AuthProvider>().repository.apiClient;
    _repository = ComercianteRepository(api);
    _formRepository = ComercioFormRepository(api);
    _categoriaRepository = CategoriaRepository(api);
    _categoriaProductoRepository = CategoriaProductoRepository(api);
    _loadComercios();
    _setupSocket();
  }

  @override
  void dispose() {
    _nuevoPedidoSub?.cancel();
    _pedidoCanceladoSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  void _setupSocket() {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    // Conexión inicial (sin comercioId: el backend acepta el room cuando
    // el cliente lo envía; se re-conecta al cambiar de comercio).
    unawaited(_connectSocket());

    _nuevoPedidoSub =
        PedidosSocket.instance.onNuevoPedido.listen(_onNuevoPedido);
    _pedidoCanceladoSub =
        PedidosSocket.instance.onPedidoCancelado.listen(_onPedidoCancelado);
    _connSub =
        PedidosSocket.instance.onConnectionChange.listen(_onConnectionChange);
  }

  Future<void> _connectSocket() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;
    await PedidosSocket.instance.connect(
      userId: user.id,
      role: user.userRole.name,
      comercioId: _comercio?.id,
    );
  }

  void _onConnectionChange(SocketConnection status) {
    if (!mounted) return;
    if (status == SocketConnection.connected) {
      // Al reconectar, refrescamos contadores por si nos perdimos algo.
      _refreshPendingCount();
    }
  }

  void _onNuevoPedido(Map<String, dynamic> data) {
    if (!mounted) return;

    // El backend emite la `Orden` directamente; el .md sugiere `{ orden }`.
    // Aceptamos ambos formatos.
    final Map<String, dynamic> orden = data['orden'] is Map
        ? Map<String, dynamic>.from(data['orden'] as Map)
        : data;
    final ordenId = (orden['id'] as int?) ?? 0;

    // Si es un pedido que ya mostramos hace instantes, ignorar.
    if (ordenId == _lastNuevoPedidoId) return;
    _lastNuevoPedidoId = ordenId;

    // Refrescar contadores y lista en background.
    _refreshPendingCount();
    setState(() => _pedidosRefreshToken++);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.navy,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: AppColors.yellow),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ordenId > 0
                    ? '¡Nuevo pedido #$ordenId!'
                    : '¡Nuevo pedido recibido!',
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                setState(() => _tabIndex = 1);
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.yellow),
              child: const Text('Ver'),
            ),
          ],
        ),
      ),
    );
  }

  void _onPedidoCancelado(Map<String, dynamic> data) {
    if (!mounted) return;
    final ordenId = data['ordenId'] as int? ?? 0;
    final motivo = data['motivo'] as String?;
    _refreshPendingCount();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        content: Text(
          motivo != null
              ? 'Pedido #$ordenId cancelado · $motivo'
              : 'Pedido #$ordenId cancelado',
        ),
      ),
    );
  }

  Future<void> _loadComercios() async {
    setState(() => _loading = true);
    try {
      final comercios = await _repository.getMisComercios();
      if (!mounted) return;
      setState(() {
        _comercios = comercios;
        final currentId = _comercio?.id;
        _comercio = currentId != null
            ? comercios.where((c) => c.id == currentId).firstOrNull
            : comercios.firstOrNull;
        _comercio ??= comercios.firstOrNull;
        _loading = false;
      });
      _refreshPendingCount();
      _maybeReconnectSocket();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _maybeReconnectSocket() {
    final c = _comercio;
    if (c == null) return;
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;
    // Re-conectar para refrescar el query param `comercioId`.
    unawaited(PedidosSocket.instance.connect(
      userId: user.id,
      role: user.userRole.name,
      comercioId: c.id,
    ));
  }

  Future<void> _refreshPendingCount() async {
    final comercio = _comercio;
    if (comercio == null) return;
    try {
      final page = await _repository.getPedidos(
        comercioId: comercio.id,
        status: 'Pendiente',
        limit: 50,
      );
      if (!mounted) return;
      setState(() => _pendingCount = page.data.length);
    } catch (_) {}
  }

  Future<void> _toggleAbierto(bool value) async {
    final comercio = _comercio;
    if (comercio == null) return;
    try {
      final updated = await _repository.setComercioAbierto(comercio.id, value);
      if (!mounted) return;
      setState(() {
        _comercio = updated;
        _comercios = _comercios
            .map((c) => c.id == updated.id ? updated : c)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cambiar el estado: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _comercio = comercio);
    }
  }

  void _goTab(int index) {
    setState(() => _tabIndex = index);
    if (index == 1) _refreshPendingCount();
  }

  void _selectComercio(ComercioModel comercio) {
    setState(() => _comercio = comercio);
    _refreshPendingCount();
    _maybeReconnectSocket();
  }

  void _openCombos() {
    final c = _comercio;
    if (c == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Necesitás tener un comercio registrado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    context.push('/comerciante/combos', extra: c);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.yellow)),
      );
    }

    final pedidosBadge =
        _pendingCount > 0 ? (_pendingCount > 9 ? '9+' : '$_pendingCount') : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _tabIndex,
        children: [
          ComercianteDashboardTab(
            repository: _repository,
            comercio: _comercio,
            comercios: _comercios,
            onSelectComercio: _selectComercio,
            onToggleAbierto: _toggleAbierto,
            onGoPedidos: () => _goTab(1),
            onGoProductos: () => _goTab(2),
            onGoVentas: () => _goTab(3),
            onGoLocal: () => _goTab(4),
            onOpenCombos: _openCombos,
          ),
          ComerciantePedidosTab(
            repository: _repository,
            comercio: _comercio,
            onOrdersChanged: _refreshPendingCount,
            refreshToken: _pedidosRefreshToken,
          ),
          ComercianteProductosTab(
            repository: _repository,
            categoriaProductoRepository: _categoriaProductoRepository,
            comercio: _comercio,
            onOpenCombos: _openCombos,
          ),
          ComercianteVentasTab(
            repository: _repository,
            comercio: _comercio,
          ),
          ComercianteMasTab(
            formRepository: _formRepository,
            categoriaRepository: _categoriaRepository,
            categoriaProductoRepository: _categoriaProductoRepository,
            comercio: _comercio,
            comercios: _comercios,
            onOpenCombos: _openCombos,
            onComercioUpdated: _loadComercios,
            onLogout: () async {
              // Capturamos las refs antes del await para no usar
              // `context` después del gap asíncrono.
              final auth = context.read<AuthProvider>();
              final router = GoRouter.of(context);
              await PedidosSocket.instance.disconnect();
              await auth.logout();
              router.go('/role-selection');
            },
          ),
        ],
      ),
      bottomNavigationBar: PanelBottomNav(
        currentIndex: _tabIndex,
        onTap: _goTab,
        items: [
          const PanelNavItem(icon: Icons.home_outlined, label: 'Inicio'),
          PanelNavItem(
            icon: Icons.receipt_long_outlined,
            label: 'Pedidos',
            badge: pedidosBadge,
          ),
          const PanelNavItem(icon: Icons.inventory_2_outlined, label: 'Productos'),
          const PanelNavItem(icon: Icons.bar_chart_outlined, label: 'Ventas'),
          const PanelNavItem(icon: Icons.settings_outlined, label: 'Más'),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
