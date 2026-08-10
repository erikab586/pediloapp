import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/panel/form_widgets.dart';
import '../../../cliente/data/models/catalog_models.dart';
import '../../data/comerciante_repository.dart';

class ProductoFormScreen extends StatefulWidget {
  const ProductoFormScreen({
    super.key,
    required this.repository,
    required this.comercioId,
    required this.categoriasProducto,
    this.producto,
    this.onSaved,
    this.onManageCategorias,
  });

  final ComercianteRepository repository;
  final int comercioId;
  final List<CategoriaProductoModel> categoriasProducto;
  final ProductoModel? producto;
  final ValueChanged<ProductoModel>? onSaved;
  final VoidCallback? onManageCategorias;

  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _precioCtrl;
  late final TextEditingController _cantidadCtrl;

  int? _categoriaProductoId;
  Uint8List? _imagenBytes;
  bool _activo = true;
  bool _saving = false;

  bool get _isEdit => widget.producto != null;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _nombreCtrl = TextEditingController(text: p?.nombre ?? '');
    _descripcionCtrl = TextEditingController(text: p?.descripcion ?? '');
    _precioCtrl = TextEditingController(
      text: p != null ? p.precio.toStringAsFixed(0) : '',
    );
    _cantidadCtrl = TextEditingController(
      text: p != null ? '${p.cantidad}' : '0',
    );
    _categoriaProductoId =
        p?.categoriaProductoId ?? widget.categoriasProducto.firstOrNull?.idCategoriaProducto;
    _activo = p?.activo ?? true;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioCtrl.dispose();
    _cantidadCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoriaProductoId == null) {
      await mostrarAlertaError(
        context,
        titulo: 'Datos incompletos',
        mensaje: 'Seleccioná una categoría de producto.',
      );
      return;
    }

    final precio = double.tryParse(_precioCtrl.text.trim());
    if (precio == null) {
      await mostrarAlertaError(
        context,
        titulo: 'Datos incompletos',
        mensaje: 'Ingresá un precio válido.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final ProductoModel saved;
      if (_isEdit) {
        saved = await widget.repository.updateProducto(
          id: widget.producto!.id,
          categoriaProductoId: _categoriaProductoId,
          nombre: _nombreCtrl.text.trim(),
          descripcion: _descripcionCtrl.text.trim(),
          precio: precio,
          cantidad: int.tryParse(_cantidadCtrl.text.trim()) ?? 0,
          activo: _activo,
          imagenBytes: _imagenBytes,
        );
      } else {
        saved = await widget.repository.createProducto(
          comercioId: widget.comercioId,
          categoriaProductoId: _categoriaProductoId!,
          nombre: _nombreCtrl.text.trim(),
          descripcion: _descripcionCtrl.text.trim(),
          precio: precio,
          cantidad: int.tryParse(_cantidadCtrl.text.trim()) ?? 0,
          activo: _activo,
          imagenBytes: _imagenBytes,
        );
      }

      if (!mounted) return;
      widget.onSaved?.call(saved);
      Navigator.pop(context, saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Producto actualizado' : 'Producto creado'),
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
        title: Text(_isEdit ? 'Editar producto' : 'Nuevo producto'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ImagePickerField(
              label: 'Imagen del producto',
              imageUrl: widget.producto?.imageUrl,
              imageBytes: _imagenBytes,
              onPicked: (bytes) => setState(() => _imagenBytes = bytes),
            ),
            const SizedBox(height: 16),
            PanelTextField(
              label: 'Nombre *',
              controller: _nombreCtrl,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 14),
            _buildCategoriaDropdown(),
            const SizedBox(height: 14),
            PanelTextField(
              label: 'Precio *',
              controller: _precioCtrl,
              keyboardType: TextInputType.number,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 14),
            PanelTextField(
              label: 'Stock / cantidad',
              controller: _cantidadCtrl,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),
            PanelTextField(
              label: 'Descripción',
              controller: _descripcionCtrl,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Producto activo',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              value: _activo,
              activeThumbColor: AppColors.yellow,
              onChanged: (v) => setState(() => _activo = v),
            ),
            const SizedBox(height: 24),
            PanelSaveButton(
              label: _isEdit ? 'Guardar cambios' : 'Crear producto',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriaDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Categoría de producto *',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.navy,
                ),
              ),
            ),
            if (widget.onManageCategorias != null)
              TextButton(
                onPressed: widget.onManageCategorias,
                child: const Text('Gestionar'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          value: _categoriaProductoId,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: widget.categoriasProducto
              .map(
                (c) => DropdownMenuItem(
                  value: c.idCategoriaProducto,
                  child: Text(c.label),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _categoriaProductoId = v),
        ),
      ],
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
