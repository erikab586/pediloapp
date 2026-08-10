import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/panel/form_widgets.dart';
import '../../../../core/widgets/panel/panel_widgets.dart';
import '../../../cliente/data/models/catalog_models.dart';
import '../../data/categoria_repository.dart';

class CategoriaFormScreen extends StatefulWidget {
  const CategoriaFormScreen({
    super.key,
    required this.repository,
    this.categoria,
    this.onSaved,
  });

  final CategoriaRepository repository;
  final CategoriaModel? categoria;
  final ValueChanged<CategoriaModel>? onSaved;

  @override
  State<CategoriaFormScreen> createState() => _CategoriaFormScreenState();
}

class _CategoriaFormScreenState extends State<CategoriaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  Uint8List? _imagenBytes;
  bool _activo = true;
  bool _saving = false;

  bool get _isEdit => widget.categoria != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl =
        TextEditingController(text: widget.categoria?.nombreCategoria ?? '');
    _activo = widget.categoria?.activo ?? true;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final CategoriaModel saved;
      if (_isEdit) {
        saved = await widget.repository.updateCategoria(
          id: widget.categoria!.id,
          nombreCategoria: _nombreCtrl.text.trim(),
          activo: _activo,
          imagenBytes: _imagenBytes,
        );
      } else {
        saved = await widget.repository.createCategoria(
          nombreCategoria: _nombreCtrl.text.trim(),
          activo: _activo,
          imagenBytes: _imagenBytes,
        );
      }

      if (!mounted) return;
      widget.onSaved?.call(saved);
      Navigator.pop(context, saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Categoría actualizada' : 'Categoría creada'),
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
        title: Text(_isEdit ? 'Editar categoría' : 'Nueva categoría'),
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
              label: 'Nombre *',
              controller: _nombreCtrl,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Categoría activa',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              value: _activo,
              activeThumbColor: AppColors.yellow,
              onChanged: (v) => setState(() => _activo = v),
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

class CategoriasListScreen extends StatefulWidget {
  const CategoriasListScreen({
    super.key,
    required this.repository,
    this.canDelete = false,
  });

  final CategoriaRepository repository;
  final bool canDelete;

  @override
  State<CategoriasListScreen> createState() => _CategoriasListScreenState();
}

class _CategoriasListScreenState extends State<CategoriasListScreen> {
  List<CategoriaModel> _categorias = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cats = await widget.repository.getCategorias();
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

  Future<void> _openForm([CategoriaModel? categoria]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoriaFormScreen(
          repository: widget.repository,
          categoria: categoria,
          onSaved: (_) => _load(),
        ),
      ),
    );
    _load();
  }

  Future<void> _delete(CategoriaModel categoria) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar "${categoria.nombreCategoria}"?'),
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
      await widget.repository.deleteCategoria(categoria.id);
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
        title: const Text('Categorías'),
        actions: [
          IconButton(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            tooltip: 'Nueva categoría',
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
                          icon: Icons.category_outlined,
                          title: 'Sin categorías',
                          subtitle:
                              'Creá una categoría para organizar comercios y productos.',
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
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: cat.imagenCategoria != null
                                ? Image.network(
                                    cat.imageUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.category),
                                  )
                                : Container(
                                    width: 48,
                                    height: 48,
                                    color: AppColors.cream,
                                    child: const Icon(Icons.category),
                                  ),
                          ),
                          title: Text(
                            cat.nombreCategoria,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(cat.activo ? 'Activa' : 'Inactiva'),
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
