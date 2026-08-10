import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/shell/admin_shell_screen.dart';
import '../../features/auth/domain/user_role.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/cliente/data/models/catalog_models.dart';
import '../../features/cliente/presentation/checkout/checkout_screen.dart';
import '../../features/cliente/presentation/comercio/comercio_detail_screen.dart';
import '../../features/cliente/presentation/shell/cliente_shell_screen.dart';
import '../../features/cliente/presentation/pedidos/tracking_screen.dart';
import '../../features/comerciante/data/comerciante_repository.dart';
import '../../features/comerciante/presentation/combos/combo_form_screen.dart';
import '../../features/comerciante/presentation/combos/combos_list_screen.dart';
import '../../features/comerciante/presentation/pedidos/pedido_detail_screen.dart';
import '../../features/comerciante/presentation/shell/comerciante_shell_screen.dart';
import '../../features/role_selection/presentation/role_selection_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';

GoRouter createAppRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authProvider,
    redirect: (context, state) {
      if (!authProvider.isInitialized) return null;

      final path = state.uri.path;
      final isSplash = path == '/';
      final isAuthEntry = path == '/role-selection' ||
          path.startsWith('/login') ||
          path.startsWith('/register');
      final isProtected = path.startsWith('/cliente/') ||
          path.startsWith('/comerciante/') ||
          path.startsWith('/admin/');

      // Sesión inválida / usuario borrado → selector de rol (cualquier perfil).
      if (!authProvider.isAuthenticated && (isProtected || isSplash)) {
        if (isSplash) return null; // deja animar el splash
        return '/role-selection';
      }

      if (authProvider.isAuthenticated && isAuthEntry) {
        return authProvider.homeRoute;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/login/:role',
        builder: (context, state) {
          final role = _parseRole(state.pathParameters['role']);
          return LoginScreen(role: role);
        },
      ),
      GoRoute(
        path: '/register/:role',
        builder: (context, state) {
          final role = _parseRole(state.pathParameters['role']);
          return RegisterScreen(role: role);
        },
      ),
      GoRoute(
        path: '/cliente/home',
        builder: (context, state) => const ClienteShellScreen(),
      ),
      GoRoute(
        path: '/cliente/comercio/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return ComercioDetailScreen(comercioId: id);
        },
      ),
      GoRoute(
        path: '/cliente/checkout',
        builder: (context, state) {
          final comercioId = state.extra as int?;
          if (comercioId == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Checkout')),
              body: const Center(child: Text('Sin comercio')),
            );
          }
          return ClienteCheckoutScreen(comercioId: comercioId);
        },
      ),
      GoRoute(
        path: '/cliente/pedidos/:id/tracking',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return ClienteTrackingScreen(pedidoId: id);
        },
      ),
      GoRoute(
        path: '/comerciante/home',
        builder: (context, state) => const ComercianteShellScreen(),
      ),
      // Detalle de pedido del comerciante (con realtime)
      GoRoute(
        path: '/comerciante/pedidos/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return PedidoDetailScreen(pedidoId: id);
        },
      ),
      // Lista de combos del comercio
      GoRoute(
        path: '/comerciante/combos',
        builder: (context, state) {
          final comercio = state.extra as ComercioModel?;
          if (comercio == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Combos')),
              body: const Center(
                child: Text('Sin comercio seleccionado'),
              ),
            );
          }
          return CombosListScreen(comercio: comercio);
        },
      ),
      // Form de combo (nuevo / edición) — el form obtiene el repository
      // internamente vía AuthProvider, así el router solo pasa el contexto.
      GoRoute(
        path: '/comerciante/combos/form',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final comercio = args?['comercio'] as ComercioModel?;
          final combo = args?['combo'] as ComboModel?;
          if (comercio == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Combo')),
              body: const Center(child: Text('Faltan argumentos')),
            );
          }
          return ComboFormScreen(comercio: comercio, combo: combo);
        },
      ),
      GoRoute(
        path: '/admin/home',
        builder: (context, state) => const AdminShellScreen(),
      ),
    ],
  );
}

UserRole _parseRole(String? roleName) {
  return UserRole.values.firstWhere(
    (role) => role.name == roleName,
    orElse: () => UserRole.cliente,
  );
}
