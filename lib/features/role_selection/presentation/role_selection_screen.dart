import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pedilo_logo.dart';
import '../../auth/domain/user_role.dart';

/// Selector de app según rol: Cliente, Comerciante o Administrador.
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.navy,
              Color(0xFF1A365D),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              children: [
                const SizedBox(height: 40),
                const PediloLogo(height: 64, textColor: AppColors.white),
                const SizedBox(height: 16),
                Text(
                  'Marketplace de pedidos — Prototipos UI/UX',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: AppColors.gray400,
                    height: 1.5,
                  ),
                ),
                Text(
                  'Seleccioná la app para explorar',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: AppColors.gray400,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                _RoleCard(
                  role: UserRole.cliente,
                  icon: Icons.shopping_cart_outlined,
                  iconBackground: AppColors.yellow,
                  iconColor: AppColors.navy,
                  onTap: () => context.push('/login/${UserRole.cliente.name}'),
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  role: UserRole.comerciante,
                  icon: Icons.storefront_outlined,
                  iconBackground: AppColors.green,
                  iconColor: AppColors.white,
                  onTap: () =>
                      context.push('/login/${UserRole.comerciante.name}'),
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  role: UserRole.administrador,
                  icon: Icons.settings_outlined,
                  iconBackground: AppColors.blue,
                  iconColor: AppColors.white,
                  onTap: () =>
                      context.push('/login/${UserRole.administrador.name}'),
                ),
                const SizedBox(height: 60),
                Text(
                  'Prototipo Flutter · Poppins · #FFC83D · #0D1B2A',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.white.withValues(alpha: 0.4),
                    height: 1.5,
                  ),
                ),
                Text(
                  'Optimizado para móvil (390×844)',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.white.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.onTap,
  });

  final UserRole role;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.title,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        role.description,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.gray400,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.white.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
