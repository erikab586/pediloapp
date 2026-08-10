import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/socket_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../data/catalog_repository.dart';
import '../../data/cliente_repository.dart';
import '../home/cliente_home_tab.dart';
import '../widgets/cliente_widgets.dart';
import 'cliente_panel_tabs.dart';

class ClienteShellScreen extends StatefulWidget {
  const ClienteShellScreen({super.key});

  @override
  State<ClienteShellScreen> createState() => _ClienteShellScreenState();
}

class _ClienteShellScreenState extends State<ClienteShellScreen> {
  late final CatalogRepository _catalogRepository;
  late final ClienteRepository _clienteRepository;
  int _tabIndex = 0;
  int _cartCount = 0;
  int _cartRefreshToken = 0;
  int _pedidosRefreshToken = 0;
  StreamSubscription<Map<String, dynamic>>? _estadoPedidoSub;
  bool _socketInitialized = false;

  @override
  void initState() {
    super.initState();
    final api = context.read<AuthProvider>().repository.apiClient;
    _catalogRepository = CatalogRepository(api);
    _clienteRepository = ClienteRepository(api);

    _refreshCartCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // GoRouterState requiere InheritedWidget; no usar en initState().
    final tabParam = GoRouterState.of(context).uri.queryParameters['tab'];
    if (tabParam != null) {
      final tab = int.tryParse(tabParam);
      if (tab != null && tab >= 0 && tab <= 4 && tab != _tabIndex) {
        setState(() => _tabIndex = tab);
      }
    }

    if (!_socketInitialized) {
      _socketInitialized = true;
      _setupSocket();
    }
  }

  @override
  void dispose() {
    _estadoPedidoSub?.cancel();
    super.dispose();
  }

  void _setupSocket() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    unawaited(PedidosSocket.instance.connect(
      userId: user.id,
      role: user.userRole.name,
    ));

    _estadoPedidoSub =
        PedidosSocket.instance.onEstadoPedido.listen((_) {
      if (!mounted) return;
      setState(() => _pedidosRefreshToken++);
    });
  }

  Future<void> _refreshCartCount() async {
    try {
      final carrito = await _clienteRepository.getCarrito();
      if (!mounted) return;
      setState(() => _cartCount = carrito.resumen.cantidadItems);
    } catch (_) {}
  }

  void _goTab(int index) {
    setState(() {
      _tabIndex = index;
      if (index == 2) _cartRefreshToken++;
      if (index == 3) _pedidosRefreshToken++;
    });
    if (index == 2) _refreshCartCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _tabIndex,
        children: [
          ClienteHomeTab(
            catalogRepository: _catalogRepository,
            onOpenComercio: (id) =>
                context.push('/cliente/comercio/$id').then((_) {
              _refreshCartCount();
              setState(() => _cartRefreshToken++);
            }),
            onGoSearch: () => _goTab(1),
          ),
          ClienteSearchTab(
            catalogRepository: _catalogRepository,
            onOpenComercio: (id) =>
                context.push('/cliente/comercio/$id').then((_) {
              _refreshCartCount();
              setState(() => _cartRefreshToken++);
            }),
          ),
          ClienteCarritoTab(
            repository: _clienteRepository,
            catalogRepository: _catalogRepository,
            refreshToken: _cartRefreshToken,
            onCartChanged: _refreshCartCount,
            onGoCheckout: (comercioId) async {
              final result = await context.push<bool>(
                '/cliente/checkout',
                extra: comercioId,
              );
              if (result == true) {
                _refreshCartCount();
                setState(() {
                  _cartRefreshToken++;
                  _tabIndex = 3;
                  _pedidosRefreshToken++;
                });
              } else {
                setState(() => _cartRefreshToken++);
              }
            },
          ),
          ClientePedidosTab(
            repository: _clienteRepository,
            refreshToken: _pedidosRefreshToken,
            onOpenTracking: (id) =>
                context.push('/cliente/pedidos/$id/tracking'),
          ),
          ClientePerfilTab(
            repository: _clienteRepository,
            onLogout: () async {
              await PedidosSocket.instance.disconnect();
              if (!mounted) return;
              final auth = context.read<AuthProvider>();
              await auth.logout();
              if (!context.mounted) return;
              context.go('/role-selection');
            },
          ),
        ],
      ),
      bottomNavigationBar: ClienteBottomNav(
        currentIndex: _tabIndex,
        cartCount: _cartCount,
        onTap: _goTab,
      ),
    );
  }
}
