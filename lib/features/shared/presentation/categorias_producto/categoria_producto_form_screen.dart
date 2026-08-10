import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/panel/form_widgets.dart';
import '../../../../core/widgets/panel/panel_widgets.dart';
import '../../../cliente/data/models/catalog_models.dart';
import '../../data/categoria_producto_repository.dart';

class CategoriaProductoFormScreen extends StatefulWidget {
  const CategoriaProductoFormScreen({
    super.key,
    required this.repository,
    this.categoria,
    this.onSaved,
  });

  final CategoriaProductoRepository repository;
  final CategoriaProductoModel? categoria;
  final ValueChanged<CategoriaProductoModel>? onSaved;

  @override
  State<CategoriaProductoFormScreen> createState() =>
      _CategoriaProductoFormScreenState();
}

class _CategoriaProductoFormScreenState
    extends State<CategoriaProductoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _rubroCtrl;
  Uint8List? _imagenBytes;
  bool _saving = false;

  bool get _isEdit => widget.categoria != null;

  @override
  void initState() {
    super.initState();
    _descripcionCtrl =
        TextEditingController(text: widget.categoria?.descripcion ?? '');
    _rubroCtrl = TextEditingController(text: widget.categoria?.rubro ?? '');
  }

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _rubroCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final CategoriaProductoModel saved;
      if (_isEdit) {
        saved = await widget.repository.updateCategoriaProducto(
          id: widget.categoria!.idCategoriaProducto,
          descripcion: _descripcionCtrl.text.trim(),
          rubro: _rubroCtrl.text.trim(),
          imagenBytes: _imagenBytes,
        );
      } else {
        saved = await widget.repository.createCategoriaProducto(
          descripcion: _descripcionCtrl.text.trim(),
          rubro: _rubroCtrl.text.trim(),
          imagenBytes: _imagenBytes,
        );
      }

      if (!mounted) return;
      widget.onSaved?.call(saved);
      Navigator.pop(context, saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Categoría de producto actualizada'
                : 'Categoría de producto creada',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    } finally {
      if (mounted) setState(() => _saving = false);
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
          _isEdit ? 'Editar categoría de producto' : 'Nueva categoría de producto',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ImagePickerField(
              label: 'Imagen de categoría',
              imageUrl: widget.categoria?.imageUrl,
              imageBytes: _imagenBytes,
              onPicked: (bytes) => setState(() => _imagenBytes = bytes),
              height: 120,
            ),
            const SizedBox(height: 16),
            PanelTextField(
              label: 'Rubro *',
              controller: _rubroCtrl,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 14),
            PanelTextField(
              label: 'Descripción *',
              controller: _descripcionCtrl,
              maxLines: 2,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 24),
            PanelSaveButton(
              label: _isEdit ? 'Guardar cambios' : 'Crear categoría',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class CategoriasProductoListScreen extends StatefulWidget {
  const CategoriasProductoListScreen({
    super.key,
    required this.repository,
    this.canDelete = false,
  });

  final CategoriaProductoRepository repository;
  final bool canDelete;

  @override
  State<CategoriasProductoListScreen> createState() =>
      _CategoriasProductoListScreenState();
}

class _CategoriasProductoListScreenState
    extends State<CategoriasProductoListScreen> {
  List<CategoriaProductoModel> _categorias = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cats = await widget.repository.getCategoriasProducto();
      if (!mounted) return;
      setState(() {
        _categorias = cats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  Future<void> _openForm([CategoriaProductoModel? categoria]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoriaProductoFormScreen(
          repository: widget.repository,
          categoria: categoria,
          onSaved: (_) => _load(),
        ),
      ),
    );
    _load();
  }

  Future<void> _delete(CategoriaProductoModel categoria) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar "${categoria.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await widget.repository.deleteCategoriaProducto(
        categoria.idCategoriaProducto,
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        title: const Text('Categorías de producto'),
        actions: [
          IconButton(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            tooltip: 'Nueva categoría de producto',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            )
          : RefreshIndicator(
              color: AppColors.yellow,
              onRefresh: _load,
              child: _categorias.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        EmptyPanelState(
                          icon: Icons.inventory_2_outlined,
                          title: 'Sin categorías de producto',
                          subtitle:
                              'Creá categorías para clasificar tus productos.',
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _categorias.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final cat = _categorias[index];
                        return ListTile(
                          tileColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: cat.imagen != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    cat.imageUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => CircleAvatar(
                                      backgroundColor: AppColors.cream,
                                      child: Text(
                                        cat.rubro.isNotEmpty
                                            ? cat.rubro[0].toUpperCase()
                                            : '?',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.navy,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : CircleAvatar(
                                  backgroundColor: AppColors.cream,
                                  child: Text(
                                    cat.rubro.isNotEmpty
                                        ? cat.rubro[0].toUpperCase()
                                        : '?',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ),
                          title: Text(
                            cat.descripcion,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text('Rubro: ${cat.rubro}'),
                          trailing: PopupMenuButton(
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar'),
                              ),
                              if (widget.canDelete)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Eliminar'),
                                ),
                            ],
                            onSelected: (v) {
                              if (v == 'edit') _openForm(cat);
                              if (v == 'delete') _delete(cat);
                            },
                          ),
                          onTap: () => _openForm(cat),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.navy,
        child: const Icon(Icons.add),
      ),
    );
  }
}
