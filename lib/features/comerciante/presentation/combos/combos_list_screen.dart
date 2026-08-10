import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/panel/panel_widgets.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../cliente/data/models/catalog_models.dart';
import '../../data/comerciante_repository.dart';

class CombosListScreen extends StatefulWidget {
  const CombosListScreen({super.key, required this.comercio});

  final ComercioModel comercio;

  @override
  State<CombosListScreen> createState() => _CombosListScreenState();
}

class _CombosListScreenState extends State<CombosListScreen> {
  late final ComercianteRepository _repository;
  List<ComboModel> _combos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final api = context.read<AuthProvider>().repository.apiClient;
    _repository = ComercianteRepository(api);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _repository.getCombos(widget.comercio.id);
      if (!mounted) return;
      setState(() {
        _combos = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e);
    }
  }

  void _showError(Object e) {
    final msg = e is ApiException ? e.message : e.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openForm({ComboModel? combo}) async {
    final result = await context.push<bool>(
      '/comerciante/combos/form',
      extra: <String, dynamic>{
        'comercio': widget.comercio,
        if (combo != null) 'combo': combo,
      },
    );
    if (result == true) await _load();
  }

  Future<void> _toggleActivo(ComboModel combo) async {
    try {
      await _repository.updateCombo(id: combo.id, activo: !combo.activo);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete(ComboModel combo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar combo'),
        content: Text('¿Eliminar "${combo.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _repository.deleteCombo(combo.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Combo "${combo.nombre}" eliminado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        title: Text(
          'Combos',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Nuevo combo',
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_circle, color: AppColors.yellow),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            )
          : _combos.isEmpty
              ? const EmptyPanelState(
                  icon: Icons.local_offer_outlined,
                  title: 'Sin combos',
                  subtitle:
                      'Creá combos para ofrecer packs de productos a precio especial.',
                )
              : RefreshIndicator(
                  color: AppColors.yellow,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _combos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final combo = _combos[index];
                      return _ComboTile(
                        combo: combo,
                        onTap: () => _openForm(combo: combo),
                        onToggleActivo: () => _toggleActivo(combo),
                        onDelete: () => _delete(combo),
                      );
                    },
                  ),
                ),
    );
  }
}

class _ComboTile extends StatelessWidget {
  const _ComboTile({
    required this.combo,
    required this.onTap,
    required this.onToggleActivo,
    required this.onDelete,
  });

  final ComboModel combo;
  final VoidCallback onTap;
  final VoidCallback onToggleActivo;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
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
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: combo.imagen != null && combo.imagen!.isNotEmpty
                    ? Image.network(
                        combo.imageUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      combo.nombre,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.navy,
                      ),
                    ),
                    if (combo.descripcion != null && combo.descripcion!.isNotEmpty)
                      Text(
                        combo.descripcion!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.gray500,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          combo.precioLabel,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                        Text(
                          '· ${combo.items.length} items',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.gray500,
                          ),
                        ),
                        PanelBadge(
                          label: combo.activo ? 'Activo' : 'Inactivo',
                          background: combo.activo
                              ? AppColors.green.withValues(alpha: 0.15)
                              : AppColors.gray400.withValues(alpha: 0.2),
                          foreground:
                              combo.activo ? AppColors.green : AppColors.gray500,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert, color: AppColors.gray500),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(combo.activo ? 'Desactivar' : 'Activar'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
                onSelected: (v) {
                  if (v == 'edit') onTap();
                  if (v == 'toggle') onToggleActivo();
                  if (v == 'delete') onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 56,
      height: 56,
      color: AppColors.cream,
      alignment: Alignment.center,
      child: const Icon(Icons.local_offer, color: AppColors.navy, size: 24),
    );
  }
}
