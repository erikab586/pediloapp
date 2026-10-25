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
  bool _loadingDetalles = false;
  bool _loadingOpcionales = false;
  bool _loadingExtras = false;

  /// Producto persistido (tras crear o el que se está editando).
  ProductoModel? _producto;
  List<DetalleProductoModel> _detalles = [];
  List<OpcionalModel> _opcionales = [];
  List<ExtraModel> _extras = [];

  bool get _isEdit => _producto != null;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _producto = p;
    _nombreCtrl = TextEditingController(text: p?.nombre ?? '');
    _descripcionCtrl = TextEditingController(text: p?.descripcion ?? '');
    _precioCtrl = TextEditingController(
      text: p != null ? p.precioValue.toStringAsFixed(0) : '',
    );
    _cantidadCtrl = TextEditingController(
      text: p != null ? '${p.cantidad ?? 0}' : '0',
    );
    _categoriaProductoId = p?.categoriaProductoId ??
        widget.categoriasProducto.firstOrNull?.idCategoriaProducto;
    _activo = p?.activo ?? true;
    _detalles = List.of(p?.detalles ?? const []);
    _opcionales = List.of(p?.opcionales ?? const []);
    _extras = List.of(p?.extras ?? const []);
    if (p != null) {
      _loadDetalles();
      _loadOpcionales();
      _loadExtras();
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioCtrl.dispose();
    _cantidadCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetalles() async {
    final id = _producto?.id;
    if (id == null) return;
    setState(() => _loadingDetalles = true);
    try {
      final list = await widget.repository.getDetallesProducto(id);
      if (!mounted) return;
      setState(() {
        _detalles = list;
        _loadingDetalles = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingDetalles = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  Future<void> _loadOpcionales() async {
    final id = _producto?.id;
    if (id == null) return;
    setState(() => _loadingOpcionales = true);
    try {
      final list = await widget.repository.getOpcionalesProducto(id);
      if (!mounted) return;
      setState(() {
        _opcionales = list;
        _loadingOpcionales = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingOpcionales = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  Future<void> _loadExtras() async {
    final id = _producto?.id;
    if (id == null) return;
    setState(() => _loadingExtras = true);
    try {
      final list = await widget.repository.getExtrasProducto(id);
      if (!mounted) return;
      setState(() {
        _extras = list;
        _loadingExtras = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingExtras = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
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
          id: _producto!.id,
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
      setState(() {
        _producto = saved;
        _imagenBytes = null;
        _saving = false;
      });
      widget.onSaved?.call(saved);

      if (widget.producto == null && _detalles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Producto creado. Podés agregar detalles (ej. peperoni, orégano).',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      Navigator.pop(context, saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.producto != null
                ? 'Producto actualizado'
                : 'Producto guardado',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openDetalleForm([DetalleProductoModel? existing]) async {
    if (_producto == null) {
      await mostrarAlertaError(
        context,
        titulo: 'Guardá el producto primero',
        mensaje:
            'Creá el producto y después agregá detalles como peperoni, orégano, etc.',
      );
      return;
    }

    final result = await showDialog<DetalleProductoModel>(
      context: context,
      builder: (ctx) => _DetalleProductoDialog(
        repository: widget.repository,
        productoId: _producto!.id,
        existing: existing,
      ),
    );
    if (result == null || !mounted) return;
    await _loadDetalles();
    widget.onSaved?.call(_producto!);
  }

  Future<void> _toggleDetalle(DetalleProductoModel d, bool activo) async {
    try {
      await widget.repository.setDetalleProductoActivo(d.id, activo);
      await _loadDetalles();
    } catch (e) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  Future<void> _deleteDetalle(DetalleProductoModel d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar detalle'),
        content: Text('¿Eliminar "${d.titulo}"?'),
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
    if (ok != true || !mounted) return;
    try {
      await widget.repository.deleteDetalleProducto(d.id);
      await _loadDetalles();
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
        title: Text(_isEdit ? 'Editar producto' : 'Nuevo producto'),
        actions: [
          if (_isEdit)
            TextButton(
              onPressed: () => Navigator.pop(context, _producto),
              child: Text(
                'Listo',
                style: GoogleFonts.poppins(
                  color: AppColors.yellow,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ImagePickerField(
              label: 'Imagen del producto',
              imageUrl: _producto?.imageUrl ?? widget.producto?.imageUrl,
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
            const SizedBox(height: 8),
            PanelSaveButton(
              label: _isEdit ? 'Guardar cambios' : 'Crear producto',
              loading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: 28),
            _buildDetallesSection(),
            const SizedBox(height: 28),
            _buildOpcionalesSection(),
            const SizedBox(height: 28),
            _buildExtrasSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildExtrasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Adicionales / Extras',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _openExtraForm,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar'),
            ),
          ],
        ),
        Text(
          'Se suman al precio del producto (maíz, queso…). El cliente elige unidades.',
          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.gray500),
        ),
        const SizedBox(height: 10),
        if (!_isEdit)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.yellow.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Primero creá el producto para cargar adicionales.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.navy),
            ),
          )
        else if (_loadingExtras)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            ),
          )
        else if (_extras.isEmpty)
          Text(
            'Sin adicionales. Son opcionales: el cliente puede sumarlos al pedir.',
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.gray500),
          )
        else
          ..._extras.map((e) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.gray400.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.nombre,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                        Text(
                          '+ ${e.precioLabel}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                        if (e.descripcion != null &&
                            e.descripcion!.trim().isNotEmpty)
                          Text(
                            e.descripcion!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.gray500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Switch(
                    value: e.activo,
                    activeThumbColor: AppColors.navy,
                    activeTrackColor: AppColors.yellow,
                    onChanged: (v) => _toggleExtra(e, v),
                  ),
                  IconButton(
                    onPressed: () => _openExtraForm(e),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                  IconButton(
                    onPressed: () => _deleteExtra(e),
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Future<void> _openExtraForm([ExtraModel? existing]) async {
    if (_producto == null) {
      await mostrarAlertaError(
        context,
        titulo: 'Guardá el producto primero',
        mensaje: 'Creá el producto y después agregá adicionales.',
      );
      return;
    }
    final result = await showDialog<ExtraModel>(
      context: context,
      builder: (ctx) => _ExtraDialog(
        repository: widget.repository,
        productoId: _producto!.id,
        existing: existing,
      ),
    );
    if (result == null || !mounted) return;
    await _loadExtras();
    widget.onSaved?.call(_producto!);
  }

  Future<void> _toggleExtra(ExtraModel e, bool activo) async {
    try {
      await widget.repository.setExtraActivo(e.id, activo);
      await _loadExtras();
    } catch (err) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(err));
    }
  }

  Future<void> _deleteExtra(ExtraModel e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar adicional'),
        content: Text('¿Eliminar "${e.nombre}"?'),
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
    if (ok != true || !mounted) return;
    try {
      await widget.repository.deleteExtra(e.id);
      await _loadExtras();
    } catch (err) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(err));
    }
  }

  Widget _buildOpcionalesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Opcionales',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _openOpcionalForm,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar'),
            ),
          ],
        ),
        Text(
          'Tamaños o presentaciones con precio propio (pequeño, mediano, 250g…).',
          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.gray500),
        ),
        const SizedBox(height: 10),
        if (!_isEdit)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.yellow.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Primero creá el producto para cargar opcionales.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.navy),
            ),
          )
        else if (_loadingOpcionales)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            ),
          )
        else if (_opcionales.isEmpty)
          Text(
            'Sin opcionales. Si agregás, el cliente deberá elegir uno al pedir.',
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.gray500),
          )
        else
          ..._opcionales.map((o) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.gray400.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.nombre,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                        Text(
                          o.precioLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                        if (o.descripcion != null &&
                            o.descripcion!.trim().isNotEmpty)
                          Text(
                            o.descripcion!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.gray500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Switch(
                    value: o.activo,
                    activeThumbColor: AppColors.navy,
                    activeTrackColor: AppColors.yellow,
                    onChanged: (v) => _toggleOpcional(o, v),
                  ),
                  IconButton(
                    onPressed: () => _openOpcionalForm(o),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                  IconButton(
                    onPressed: () => _deleteOpcional(o),
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Future<void> _openOpcionalForm([OpcionalModel? existing]) async {
    if (_producto == null) {
      await mostrarAlertaError(
        context,
        titulo: 'Guardá el producto primero',
        mensaje: 'Creá el producto y después agregá opcionales con precio.',
      );
      return;
    }
    final result = await showDialog<OpcionalModel>(
      context: context,
      builder: (ctx) => _OpcionalDialog(
        repository: widget.repository,
        productoId: _producto!.id,
        existing: existing,
      ),
    );
    if (result == null || !mounted) return;
    await _loadOpcionales();
    widget.onSaved?.call(_producto!);
  }

  Future<void> _toggleOpcional(OpcionalModel o, bool activo) async {
    try {
      await widget.repository.setOpcionalActivo(o.id, activo);
      await _loadOpcionales();
    } catch (e) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  Future<void> _deleteOpcional(OpcionalModel o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar opcional'),
        content: Text('¿Eliminar "${o.nombre}"?'),
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
    if (ok != true || !mounted) return;
    try {
      await widget.repository.deleteOpcional(o.id);
      await _loadOpcionales();
    } catch (e) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  Widget _buildDetallesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Detalle producto',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _openDetalleForm,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar'),
            ),
          ],
        ),
        Text(
          'Opciones del producto (ej. peperoni, orégano, cebolla).',
          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.gray500),
        ),
        const SizedBox(height: 10),
        if (!_isEdit)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.yellow.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Primero creá el producto para poder cargar detalles.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.navy),
            ),
          )
        else if (_loadingDetalles)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            ),
          )
        else if (_detalles.isEmpty)
          Text(
            'Sin detalles aún. Agregá ingredientes u opciones.',
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.gray500),
          )
        else
          ..._detalles.map((d) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.gray400.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  if (d.imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        d.imageUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(Icons.image_outlined),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.restaurant_menu, size: 20),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.titulo,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                        if (d.descripcion != null &&
                            d.descripcion!.trim().isNotEmpty)
                          Text(
                            d.descripcion!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.gray500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Switch(
                    value: d.activo,
                    activeThumbColor: AppColors.navy,
                    activeTrackColor: AppColors.yellow,
                    onChanged: (v) => _toggleDetalle(d, v),
                  ),
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: () => _openDetalleForm(d),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    onPressed: () => _deleteDetalle(d),
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
                ],
              ),
            );
          }),
      ],
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
          initialValue: _categoriaProductoId,
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

class _DetalleProductoDialog extends StatefulWidget {
  const _DetalleProductoDialog({
    required this.repository,
    required this.productoId,
    this.existing,
  });

  final ComercianteRepository repository;
  final int productoId;
  final DetalleProductoModel? existing;

  @override
  State<_DetalleProductoDialog> createState() => _DetalleProductoDialogState();
}

class _DetalleProductoDialogState extends State<_DetalleProductoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _descCtrl;
  Uint8List? _imagenBytes;
  bool _activo = true;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _tituloCtrl = TextEditingController(text: e?.titulo ?? '');
    _descCtrl = TextEditingController(text: e?.descripcion ?? '');
    _activo = e?.activo ?? true;
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final DetalleProductoModel saved;
      if (_isEdit) {
        saved = await widget.repository.updateDetalleProducto(
          id: widget.existing!.id,
          titulo: _tituloCtrl.text.trim(),
          descripcion: _descCtrl.text.trim(),
          activo: _activo,
          imagenBytes: _imagenBytes,
        );
      } else {
        saved = await widget.repository.createDetalleProducto(
          productoId: widget.productoId,
          titulo: _tituloCtrl.text.trim(),
          descripcion: _descCtrl.text.trim(),
          activo: _activo,
          imagenBytes: _imagenBytes,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Editar detalle' : 'Nuevo detalle'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ImagePickerField(
                  label: 'Imagen (opcional)',
                  imageUrl: widget.existing?.imageUrl,
                  imageBytes: _imagenBytes,
                  onPicked: (b) => setState(() => _imagenBytes = b),
                  height: 100,
                ),
                const SizedBox(height: 12),
                PanelTextField(
                  label: 'Título *',
                  controller: _tituloCtrl,
                  hint: 'Ej: Peperoni',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                PanelTextField(
                  label: 'Descripción',
                  controller: _descCtrl,
                  maxLines: 2,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo (visible al cliente)'),
                  value: _activo,
                  onChanged: (v) => setState(() => _activo = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.navy,
            foregroundColor: AppColors.white,
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEdit ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }
}

class _OpcionalDialog extends StatefulWidget {
  const _OpcionalDialog({
    required this.repository,
    required this.productoId,
    this.existing,
  });

  final ComercianteRepository repository;
  final int productoId;
  final OpcionalModel? existing;

  @override
  State<_OpcionalDialog> createState() => _OpcionalDialogState();
}

class _OpcionalDialogState extends State<_OpcionalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _precioCtrl;
  Uint8List? _imagenBytes;
  bool _activo = true;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nombreCtrl = TextEditingController(text: e?.nombre ?? '');
    _descCtrl = TextEditingController(text: e?.descripcion ?? '');
    _precioCtrl = TextEditingController(
      text: e != null ? e.precio.toStringAsFixed(0) : '',
    );
    _activo = e?.activo ?? true;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final precio = double.tryParse(_precioCtrl.text.trim().replaceAll(',', '.'));
    if (precio == null || precio < 0) {
      await mostrarAlertaError(
        context,
        mensaje: 'Ingresá un precio válido para el opcional.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final OpcionalModel saved;
      if (_isEdit) {
        saved = await widget.repository.updateOpcional(
          id: widget.existing!.id,
          nombre: _nombreCtrl.text.trim(),
          descripcion: _descCtrl.text.trim(),
          precio: precio,
          activo: _activo,
          imagenBytes: _imagenBytes,
        );
      } else {
        saved = await widget.repository.createOpcional(
          productoId: widget.productoId,
          nombre: _nombreCtrl.text.trim(),
          descripcion: _descCtrl.text.trim(),
          precio: precio,
          activo: _activo,
          imagenBytes: _imagenBytes,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Editar opcional' : 'Nuevo opcional'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ImagePickerField(
                  label: 'Imagen (opcional)',
                  imageUrl: widget.existing?.imageUrl,
                  imageBytes: _imagenBytes,
                  onPicked: (b) => setState(() => _imagenBytes = b),
                  height: 100,
                ),
                const SizedBox(height: 12),
                PanelTextField(
                  label: 'Nombre *',
                  controller: _nombreCtrl,
                  hint: 'Ej: Mediano / 250g',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                PanelTextField(
                  label: 'Precio *',
                  controller: _precioCtrl,
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                PanelTextField(
                  label: 'Descripción',
                  controller: _descCtrl,
                  maxLines: 2,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo (visible al cliente)'),
                  value: _activo,
                  onChanged: (v) => setState(() => _activo = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.navy,
            foregroundColor: AppColors.white,
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEdit ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }
}

class _ExtraDialog extends StatefulWidget {
  const _ExtraDialog({
    required this.repository,
    required this.productoId,
    this.existing,
  });

  final ComercianteRepository repository;
  final int productoId;
  final ExtraModel? existing;

  @override
  State<_ExtraDialog> createState() => _ExtraDialogState();
}

class _ExtraDialogState extends State<_ExtraDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _precioCtrl;
  Uint8List? _imagenBytes;
  bool _activo = true;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nombreCtrl = TextEditingController(text: e?.nombre ?? '');
    _descCtrl = TextEditingController(text: e?.descripcion ?? '');
    _precioCtrl = TextEditingController(
      text: e != null ? e.precio.toStringAsFixed(0) : '',
    );
    _activo = e?.activo ?? true;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final precio =
        double.tryParse(_precioCtrl.text.trim().replaceAll(',', '.'));
    if (precio == null || precio < 0) {
      await mostrarAlertaError(
        context,
        mensaje: 'Ingresá un precio válido para el adicional.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final ExtraModel saved;
      if (_isEdit) {
        saved = await widget.repository.updateExtra(
          id: widget.existing!.id,
          nombre: _nombreCtrl.text.trim(),
          descripcion: _descCtrl.text.trim(),
          precio: precio,
          activo: _activo,
          imagenBytes: _imagenBytes,
        );
      } else {
        saved = await widget.repository.createExtra(
          productoId: widget.productoId,
          nombre: _nombreCtrl.text.trim(),
          descripcion: _descCtrl.text.trim(),
          precio: precio,
          activo: _activo,
          imagenBytes: _imagenBytes,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Editar adicional' : 'Nuevo adicional'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ImagePickerField(
                  label: 'Imagen (opcional)',
                  imageUrl: widget.existing?.imageUrl,
                  imageBytes: _imagenBytes,
                  onPicked: (b) => setState(() => _imagenBytes = b),
                  height: 100,
                ),
                const SizedBox(height: 12),
                PanelTextField(
                  label: 'Nombre *',
                  controller: _nombreCtrl,
                  hint: 'Ej: Maíz / Queso extra',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                PanelTextField(
                  label: 'Precio *',
                  controller: _precioCtrl,
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                PanelTextField(
                  label: 'Descripción',
                  controller: _descCtrl,
                  maxLines: 2,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo (visible al cliente)'),
                  value: _activo,
                  onChanged: (v) => setState(() => _activo = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.navy,
            foregroundColor: AppColors.white,
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEdit ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
