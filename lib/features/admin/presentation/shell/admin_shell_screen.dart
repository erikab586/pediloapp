import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/panel/panel_widgets.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../shared/data/categoria_repository.dart';
import '../../../shared/data/categoria_producto_repository.dart';
import '../../../shared/data/comercio_form_repository.dart';
import '../../data/admin_repository.dart';
import 'admin_panel_tabs.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  late final AdminRepository _repository;
  late final ComercioFormRepository _formRepository;
  late final CategoriaRepository _categoriaRepository;
  late final CategoriaProductoRepository _categoriaProductoRepository;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    final api = context.read<AuthProvider>().repository.apiClient;
    _repository = AdminRepository(api);
    _formRepository = ComercioFormRepository(api);
    _categoriaRepository = CategoriaRepository(api);
    _categoriaProductoRepository = CategoriaProductoRepository(api);
  }

  void _goTab(int index) => setState(() => _tabIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _tabIndex,
        children: [
          AdminDashboardTab(
            repository: _repository,
            onGoComercios: () => _goTab(1),
            onGoUsuarios: () => _goTab(2),
            onGoReportes: () => _goTab(3),
            onGoConfig: () => _goTab(4),
          ),
          AdminComerciosTab(
            repository: _repository,
            formRepository: _formRepository,
            categoriaRepository: _categoriaRepository,
          ),
          AdminUsuariosTab(
            repository: _repository,
            formRepository: _formRepository,
          ),
          AdminReportesTab(repository: _repository),
          AdminConfigTab(
            repository: _repository,
            categoriaRepository: _categoriaRepository,
            categoriaProductoRepository: _categoriaProductoRepository,
            onLogout: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) context.go('/role-selection');
            },
          ),
        ],
      ),
      bottomNavigationBar: PanelBottomNav(
        currentIndex: _tabIndex,
        onTap: _goTab,
        items: const [
          PanelNavItem(icon: Icons.dashboard_outlined, label: 'Inicio'),
          PanelNavItem(icon: Icons.storefront_outlined, label: 'Comercios'),
          PanelNavItem(icon: Icons.people_outline, label: 'Usuarios'),
          PanelNavItem(icon: Icons.analytics_outlined, label: 'Reportes'),
          PanelNavItem(icon: Icons.settings_outlined, label: 'Config'),
        ],
      ),
    );
  }
}
