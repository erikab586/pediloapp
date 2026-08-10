import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../comerciante/presentation/forms/comercio_form_screen.dart';
import '../../../shared/data/comercio_form_repository.dart';
import '../../data/admin_repository.dart';

class ComercioAdminDetailScreen extends StatefulWidget {
  const ComercioAdminDetailScreen({
    super.key,
    required this.repository,
    required this.formRepository,
    required this.comercio,
    this.onUpdated,
  });

  final AdminRepository repository;
  final ComercioFormRepository formRepository;
  final AdminComercioModel comercio;
  final VoidCallback? onUpdated;

  @override
  State<ComercioAdminDetailScreen> createState() =>
      _ComercioAdminDetailScreenState();
}

class _ComercioAdminDetailScreenState extends State<ComercioAdminDetailScreen> {
  late AdminComercioModel _comercio;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _comercio = widget.comercio;
  }

  Future<void> _setEstatus(String estatus) async {
    final aprobar = estatus == 'activo' || estatus == 'aprobado';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(aprobar ? 'Aprobar comercio' : 'Suspender comercio'),
        content: Text(
          aprobar
              ? '¿Aprobar "${_comercio.name}"?\nQuedará visible para los clientes.'
              : '¿Suspender "${_comercio.name}"?\nDejará de aparecer en el listado público.',
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
                  aprobar ? AppColors.green : const Color(0xFFEF4444),
              foregroundColor: AppColors.white,
            ),
            child: Text(aprobar ? 'Aprobar' : 'Suspender'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final updated =
          await widget.repository.setComercioEstatus(_comercio.id, estatus);
      if (!mounted) return;
      setState(() {
        _comercio = updated;
        _saving = false;
      });
      widget.onUpdated?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            aprobar
                ? '${_comercio.name} fue aprobado'
                : '${_comercio.name} fue suspendido',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: aprobar ? AppColors.green : const Color(0xFFEF4444),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = _comercio.portada != null
        ? ApiConfig.resolveImageUrl(_comercio.portada)
        : _comercio.logoUrl;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        title: Text(_comercio.name),
        actions: [
          IconButton(
            onPressed: _saving
                ? null
                : () async {
                    final cats = await widget.formRepository.getCategorias();
                    if (!context.mounted) return;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ComercioFormScreen(
                          repository: widget.formRepository,
                          categorias: cats,
                          comercio: _comercio,
                          isAdmin: true,
                          onSaved: (_) {
                            widget.onUpdated?.call();
                          },
                        ),
                      ),
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_comercio.logo != null || _comercio.portada != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                coverUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  color: AppColors.cream,
                  child: const Icon(Icons.store, size: 48),
                ),
              ),
            ),
          const SizedBox(height: 16),
          _InfoCard(
            items: [
              _InfoItem('Estatus', _comercio.statusLabel),
              _InfoItem('Estatus API', _comercio.estatusValue),
              _InfoItem('Categoría', _comercio.categoryLabel),
              _InfoItem('Comerciante', _comercio.comercianteNombre ?? '—'),
              _InfoItem('Teléfono', _comercio.telefono ?? '—'),
              _InfoItem('Dirección', _comercio.direccion ?? '—'),
              _InfoItem(
                'Métodos de pago',
                _comercio.metodosPago.isEmpty
                    ? '—'
                    : _comercio.metodosPago.join(', '),
              ),
              _InfoItem(
                'Entrega',
                _comercio.tiposEntrega.isEmpty
                    ? '—'
                    : _comercio.tiposEntrega.join(', '),
              ),
              if (_comercio.descripcion != null)
                _InfoItem('Descripción', _comercio.descripcion!),
            ],
          ),
          const SizedBox(height: 16),
          if (_comercio.canAprobar)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _setEstatus('activo'),
                icon: const Icon(Icons.check_circle_outline),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                label: const Text('Aprobar comercio'),
              ),
            )
          else if (_comercio.canSuspender)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _setEstatus('suspendido'),
                icon: const Icon(Icons.block),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFEE2E2),
                  foregroundColor: const Color(0xFFEF4444),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                label: const Text('Suspender comercio'),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.items});

  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        item.label,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.gray500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.value,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _InfoItem {
  const _InfoItem(this.label, this.value);
  final String label;
  final String value;
}
