import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/panel/panel_widgets.dart';
import '../../data/admin_repository.dart';
import 'comercio_admin_detail_screen.dart';
import '../../../shared/data/comercio_form_repository.dart';

/// Detalle de un usuario (admin). Si es comerciante, lista sus comercios.
class UsuarioAdminDetailScreen extends StatefulWidget {
  const UsuarioAdminDetailScreen({
    super.key,
    required this.repository,
    required this.formRepository,
    required this.user,
    this.onUpdated,
  });

  final AdminRepository repository;
  final ComercioFormRepository formRepository;
  final AdminUserModel user;
  final VoidCallback? onUpdated;

  @override
  State<UsuarioAdminDetailScreen> createState() =>
      _UsuarioAdminDetailScreenState();
}

class _UsuarioAdminDetailScreenState extends State<UsuarioAdminDetailScreen> {
  late AdminUserModel _user;
  List<AdminComercioModel> _comercios = [];
  bool _loadingComercios = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    if (_user.role == 'comerciante') {
      _loadComercios();
    }
  }

  Future<void> _loadComercios() async {
    setState(() => _loadingComercios = true);
    try {
      final list =
          await widget.repository.getComerciosByComerciante(_user.id);
      if (!mounted) return;
      setState(() {
        _comercios = list;
        _loadingComercios = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingComercios = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  Future<void> _toggleActivo(bool activo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(activo ? 'Reactivar usuario' : 'Suspender usuario'),
        content: Text(
          activo
              ? '¿Reactivar a "${_user.name}"?'
              : '¿Suspender a "${_user.name}"?\nNo podrá iniciar sesión.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  activo ? AppColors.green : const Color(0xFFEF4444),
              foregroundColor: AppColors.white,
            ),
            child: Text(activo ? 'Reactivar' : 'Suspender'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final updated =
          await widget.repository.setUsuarioActivo(_user.id, activo);
      if (!mounted) return;
      setState(() {
        _user = updated;
        _saving = false;
      });
      widget.onUpdated?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            activo
                ? '${_user.name} fue reactivado'
                : '${_user.name} fue suspendido',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  Future<void> _setComercioEstatus(
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
              ? '¿Aprobar "${comercio.name}"?'
              : '¿Suspender "${comercio.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(aprobar ? 'Aprobar' : 'Suspender'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    try {
      await widget.repository.setComercioEstatus(comercio.id, estatus);
      await _loadComercios();
      widget.onUpdated?.call();
    } catch (e) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (roleBg, roleFg) = switch (_user.role) {
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        title: Text(_user.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.yellow,
                  child: Text(
                    _user.initials,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _user.name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PanelBadge(
                      label: _user.roleLabel,
                      background: roleBg,
                      foreground: roleFg,
                    ),
                    const SizedBox(width: 8),
                    PanelBadge(
                      label: _user.statusLabel,
                      background: _user.activo
                          ? AppColors.green.withValues(alpha: 0.15)
                          : AppColors.gray400.withValues(alpha: 0.2),
                      foreground:
                          _user.activo ? AppColors.green : AppColors.gray600,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _row('Email', _user.email),
                _row('Teléfono', _user.phone ?? '—'),
                _row('Rol', _user.roleLabel),
                _row('Estado', _user.statusLabel),
                _row('ID', '${_user.id}'),
              ],
            ),
          ),
          if (_user.canBeSuspended) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving
                    ? null
                    : () => _toggleActivo(!_user.activo),
                icon: Icon(_user.activo ? Icons.block : Icons.check_circle_outline),
                style: FilledButton.styleFrom(
                  backgroundColor: _user.activo
                      ? const Color(0xFFFEE2E2)
                      : AppColors.green,
                  foregroundColor: _user.activo
                      ? const Color(0xFFEF4444)
                      : AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                label: Text(
                  _user.activo ? 'Suspender usuario' : 'Reactivar usuario',
                ),
              ),
            ),
          ],
          if (_user.role == 'comerciante') ...[
            const SizedBox(height: 24),
            Text(
              'Comercios del comerciante',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 10),
            if (_loadingComercios)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.yellow),
                ),
              )
            else if (_comercios.isEmpty)
              const EmptyPanelState(
                icon: Icons.store_outlined,
                title: 'Sin comercios',
                subtitle: 'Este comerciante aún no registró comercios.',
              )
            else
              ..._comercios.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ComercioMiniCard(
                      comercio: c,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ComercioAdminDetailScreen(
                              repository: widget.repository,
                              formRepository: widget.formRepository,
                              comercio: c,
                              onUpdated: () {
                                _loadComercios();
                                widget.onUpdated?.call();
                              },
                            ),
                          ),
                        );
                        _loadComercios();
                      },
                      onAprobar: c.canAprobar
                          ? () => _setComercioEstatus(c, 'activo')
                          : null,
                      onSuspender: c.canSuspender
                          ? () => _setComercioEstatus(c, 'suspendido')
                          : null,
                    ),
                  )),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.gray500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComercioMiniCard extends StatelessWidget {
  const _ComercioMiniCard({
    required this.comercio,
    required this.onTap,
    this.onAprobar,
    this.onSuspender,
  });

  final AdminComercioModel comercio;
  final VoidCallback onTap;
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
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
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
                        comercio.categoryLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
                PanelBadge(label: status, background: bg, foreground: fg),
                const Icon(Icons.chevron_right, color: AppColors.gray400),
              ],
            ),
          ),
          if (onAprobar != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAprobar,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: AppColors.white,
                ),
                label: const Text('Aprobar comercio'),
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
                ),
                label: const Text('Suspender comercio'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
