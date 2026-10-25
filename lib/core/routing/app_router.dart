import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user_role.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/cliente/presentation/checkout/checkout_screen.dart';
import '../../features/cliente/presentation/categoria/categoria_comercios_screen.dart';
import '../../features/cliente/presentation/comercio/comercio_detail_screen.dart';
import '../../features/cliente/presentation/shell/cliente_shell_screen.dart';
import '../../features/cliente/data/models/catalog_models.dart';
import '../../features/cliente/presentation/pedidos/pedido_success_screen.dart';
import '../../features/cliente/presentation/pedidos/pedido_rating_screen.dart';
import '../../features/cliente/presentation/pedidos/tracking_screen.dart';
import '../../features/cliente/presentation/vender/vender_en_pedilo_wizard.dart';
import '../../features/comerciante/presentation/pedidos/pedido_detail_screen.dart';
import '../../features/comerciante/presentation/promociones/promocion_form_screen.dart';
import '../../features/comerciante/presentation/promociones/promociones_list_screen.dart';
import '../../features/mi_comercio/presentation/mi_comercio_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/shared/presentation/chat/chat_list_screen.dart';
import '../../features/shared/presentation/chat/chat_room_screen.dart';
import '../../features/legal/presentation/legal_screens.dart';

GoRouter createAppRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authProvider,
    redirect: (context, state) {
      if (!authProvider.isInitialized) return null;

      final path = state.uri.path;
      final isSplash = path == '/';
      final isAuthEntry = path == '/welcome' ||
          path == '/role-selection' ||
          path.startsWith('/login') ||
          path.startsWith('/register');
      final isProtected = path.startsWith('/cliente/');

      // Rutas legacy → nuevas rutas app simplificada
      if (path.startsWith('/comerciante/') || path.startsWith('/admin/')) {
        if (path == '/comerciante/promociones' ||
            path == '/comerciante/promociones/form') {
          return null;
        }
        if (path.contains('/pedidos/')) {
          final id = path.split('/pedidos/').last.split('/').first;
          return '/cliente/mi-comercio/pedidos/$id';
        }
        if (path.startsWith('/comerciante/')) return '/cliente/mi-comercio';
        return '/cliente/home';
      }

      if (!authProvider.isAuthenticated && (isProtected || isSplash)) {
        if (isSplash) return null;
        return '/welcome';
      }

      if (path == '/role-selection') return '/welcome';

      if (authProvider.isAuthenticated &&
          isAuthEntry &&
          !authProvider.loginNavigationPending) {
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
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/login/:role',
        builder: (context, state) {
          final role = _parseRole(state.pathParameters['role']);
          return LoginScreen(role: role);
        },
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/register/:role',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/cliente/home',
        builder: (context, state) => const ClienteShellScreen(),
      ),
      GoRoute(
        path: '/cliente/mi-comercio',
        builder: (context, state) => const MiComercioScreen(),
      ),
      GoRoute(
        path: '/comerciante/promociones',
        builder: (context, state) {
          final comercio = state.extra as ComercioModel?;
          if (comercio == null) {
            return const Scaffold(
              body: Center(child: Text('No se encontró el comercio')),
            );
          }
          return PromocionesListScreen(comercio: comercio);
        },
      ),
      GoRoute(
        path: '/comerciante/promociones/form',
        builder: (context, state) {
          final comercio = state.extra as ComercioModel?;
          if (comercio == null) {
            return const Scaffold(
              body: Center(child: Text('No se encontró el comercio')),
            );
          }
          return PromocionFormScreen(comercio: comercio);
        },
      ),
      GoRoute(
        path: '/cliente/mi-comercio/pedidos/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return PedidoDetailScreen(pedidoId: id);
        },
      ),
      GoRoute(
        path: '/cliente/vender',
        builder: (context, state) => const VenderEnPediloWizard(),
      ),
      GoRoute(
        path: '/cliente/categoria/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          final nombre = state.uri.queryParameters['nombre'];
          return CategoriaComerciosScreen(
            categoriaId: id,
            categoriaNombre: nombre,
          );
        },
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
        path: '/cliente/pedidos/:id/exito',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          final extra = state.extra as Map<String, dynamic>?;
          return PedidoSuccessScreen(
            pedidoId: id,
            comercioNombre: extra?['comercioNombre'] as String?,
            total: (extra?['total'] as num?)?.toDouble(),
            tipoEntrega: extra?['tipoEntrega'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/cliente/pedidos/:id/valorar',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return PedidoRatingScreen(pedidoId: id);
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
        path: '/cliente/chat',
        builder: (context, state) {
          final soyCliente = state.uri.queryParameters['rol'] != 'comerciante';
          return ChatListScreen(soyCliente: soyCliente);
        },
      ),
      GoRoute(
        path: '/cliente/chat/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          final extra = state.extra as Map<String, dynamic>?;
          return ChatRoomScreen(
            conversacionId: id,
            titulo: extra?['titulo'] as String? ?? 'Chat',
            soyCliente: extra?['soyCliente'] as bool? ?? true,
          );
        },
      ),
      GoRoute(
        path: '/legal/privacidad',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/legal/terminos',
        builder: (context, state) => const TermsOfServiceScreen(),
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
