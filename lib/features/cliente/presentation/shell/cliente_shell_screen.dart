import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/analytics/app_analytics.dart';
import '../../../../core/audio/notification_sound.dart';
import '../../../../core/network/socket_service.dart';
import '../../../../core/storage/app_mode_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../comerciante/presentation/shell/comerciante_shell_screen.dart';
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
  StreamSubscription<Map<String, dynamic>>? _notifSub;
  StreamSubscription<Map<String, dynamic>>? _chatSub;
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
    _notifSub?.cancel();
    _chatSub?.cancel();
    super.dispose();
  }

  void _setupSocket() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    unawaited(PedidosSocket.instance.connect(
      userId: user.id,
      role: user.userRole.name,
    ));

    _estadoPedidoSub = PedidosSocket.instance.onEstadoPedido.listen((data) {
      if (!mounted) return;
      NotificationSound.play();
      setState(() => _pedidosRefreshToken++);
      final status = data['status']?.toString() ??
          data['estado']?.toString() ??
          data['nuevoEstado']?.toString();
      final ordenId = data['ordenId'] ?? data['id'];
      final msg = switch (status) {
        'Aceptado' => 'Tu pedido #$ordenId fue aceptado',
        'Preparando' => 'Están preparando tu pedido #$ordenId',
        'Listo' => 'Tu pedido #$ordenId está listo',
        'Enviado' => 'Tu pedido #$ordenId va en camino',
        'Entregado' => '¡Pedido #$ordenId entregado!',
        'Cancelado' => 'Pedido #$ordenId cancelado',
        _ => status != null
            ? 'Pedido #$ordenId: $status'
            : 'Actualizamos el estado de tu pedido',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.navy,
          action: ordenId != null
              ? SnackBarAction(
                  label: 'Ver',
                  textColor: AppColors.yellow,
                  onPressed: () =>
                      context.push('/cliente/pedidos/$ordenId/tracking'),
                )
              : null,
        ),
      );
    });

    _notifSub = PedidosSocket.instance.onNotificacionNueva.listen((data) {
      if (!mounted) return;
      NotificationSound.play();
    });

    _chatSub = PedidosSocket.instance.onChatMensaje.listen((data) {
      if (!mounted) return;
      final mensaje = data['mensaje'];
      if (mensaje is! Map) return;
      final remitenteId =
          int.tryParse(mensaje['remitenteId']?.toString() ?? '');
      if (remitenteId != null &&
          remitenteId != context.read<AuthProvider>().user?.id) {
        NotificationSound.play();
      }
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

  void _openNotification(Map<String, dynamic> notification) {
    final data = notification['data'];
    final details = data is Map ? Map<String, dynamic>.from(data) : const {};
    final tipo = notification['tipo']?.toString() ?? '';
    if (tipo == 'chat_mensaje') {
      final conversationId =
          int.tryParse(details['conversacionId']?.toString() ?? '');
      if (conversationId != null) {
        context.push(
          '/cliente/chat/$conversationId',
          extra: {
            'titulo': notification['titulo']?.toString() ?? 'Chat',
            'soyCliente': true,
          },
        );
      } else {
        context.push('/cliente/chat');
      }
      return;
    }

    final orderId = int.tryParse(details['ordenId']?.toString() ?? '');
    if (orderId != null) {
      context.push('/cliente/pedidos/$orderId/tracking');
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(notification['titulo']?.toString() ?? 'Notificación'),
        content: Text(notification['mensaje']?.toString() ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.appMode == AppMode.comercio && auth.canUseComercioMode) {
      return const ComercianteShellScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _tabIndex,
        children: [
          ClienteHomeTab(
            catalogRepository: _catalogRepository,
            clienteRepository: _clienteRepository,
            onOpenComercio: (id) {
              AppAnalytics.homeOpenComercio(id);
              context.push('/cliente/comercio/$id').then((_) {
                _refreshCartCount();
                setState(() => _cartRefreshToken++);
              });
            },
            onGoSearch: () => _goTab(1),
            onGoPedidos: () => _goTab(3),
            onOpenTracking: (id) =>
                context.push('/cliente/pedidos/$id/tracking'),
            onOpenNotification: _openNotification,
          ),
          ClienteSearchTab(
            catalogRepository: _catalogRepository,
            onOpenComercio: (id) {
              AppAnalytics.homeOpenComercio(id);
              context.push('/cliente/comercio/$id').then((_) {
                _refreshCartCount();
                setState(() => _cartRefreshToken++);
              });
            },
            onOpenCategoria: (categoria) {
              final nombre =
                  Uri.encodeQueryComponent(categoria.nombreCategoria);
              context.push(
                '/cliente/categoria/${categoria.id}?nombre=$nombre',
              );
            },
          ),
          ClienteCarritoTab(
            repository: _clienteRepository,
            catalogRepository: _catalogRepository,
            refreshToken: _cartRefreshToken,
            onCartChanged: _refreshCartCount,
            onGoCheckout: (comercioId) async {
              await context.push(
                '/cliente/checkout',
                extra: comercioId,
              );
              _refreshCartCount();
              setState(() {
                _cartRefreshToken++;
                _pedidosRefreshToken++;
              });
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
              final router = GoRouter.of(context);
              final auth = context.read<AuthProvider>();
              await PedidosSocket.instance.disconnect();
              if (!mounted) return;
              await auth.logout();
              if (!mounted) return;
              router.go('/welcome');
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
