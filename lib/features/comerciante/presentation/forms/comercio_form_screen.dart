import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/panel/form_widgets.dart';
import '../../../cliente/data/models/catalog_models.dart';
import '../../../shared/data/comercio_form_repository.dart';

const kMetodosPago = [
  'Efectivo',
  'Tarjeta',
  'MercadoPago',
  'Transferencia',
];

const kTiposEntrega = [
  'Retiro',
  'Delivery propio',
  'Delivery terceros',
];

class ComercioFormScreen extends StatefulWidget {
  const ComercioFormScreen({
    super.key,
    required this.repository,
    required this.categorias,
    this.comercio,
    this.isAdmin = false,
    this.onSaved,
  });

  final ComercioFormRepository repository;
  final List<CategoriaModel> categorias;
  final ComercioModel? comercio;
  final bool isAdmin;
  final ValueChanged<ComercioModel>? onSaved;

  @override
  State<ComercioFormScreen> createState() => _ComercioFormScreenState();
}

class _ComercioFormScreenState extends State<ComercioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _descripcionCtrl;

  int? _categoriaId;
  Uint8List? _logoBytes;
  Uint8List? _portadaBytes;
  Set<String> _metodosPago = {};
  Set<String> _tiposEntrega = {};
  bool _saving = false;

  bool get _isEdit => widget.comercio != null;

  @override
  void initState() {
    super.initState();
    final c = widget.comercio;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _telefonoCtrl = TextEditingController(text: c?.telefono ?? '');
    _direccionCtrl = TextEditingController(text: c?.direccion ?? '');
    _descripcionCtrl = TextEditingController(text: c?.descripcion ?? '');
    _categoriaId = c?.categoriaId ?? widget.categorias.firstOrNull?.id;
    _metodosPago = Set<String>.from(
      c?.metodosPago.isNotEmpty == true ? c!.metodosPago : ['Efectivo'],
    );
    _tiposEntrega = Set<String>.from(
      c?.tiposEntrega.isNotEmpty == true ? c!.tiposEntrega : ['Retiro'],
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_categoriaId == null) {
      await mostrarAlertaError(
        context,
        titulo: 'Datos incompletos',
        mensaje: 'Seleccioná una categoría para el comercio.',
      );
      return;
    }

    if (_metodosPago.isEmpty) {
      await mostrarAlertaError(
        context,
        titulo: 'Datos incompletos',
        mensaje: 'Seleccioná al menos un método de pago.',
      );
      return;
    }

    if (_tiposEntrega.isEmpty) {
      await mostrarAlertaError(
        context,
        titulo: 'Datos incompletos',
        mensaje: 'Seleccioná al menos un tipo de entrega.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final ComercioModel saved;
      if (_isEdit) {
        saved = await widget.repository.updateComercio(
          id: widget.comercio!.id,
          categoriaId: _categoriaId,
          name: _nameCtrl.text.trim(),
          telefono: _telefonoCtrl.text.trim(),
          direccion: _direccionCtrl.text.trim(),
          descripcion: _descripcionCtrl.text.trim(),
          metodosPago: _metodosPago.toList(),
          tiposEntrega: _tiposEntrega.toList(),
          logoBytes: _logoBytes,
          portadaBytes: _portadaBytes,
        );
      } else {
        saved = await widget.repository.createComercio(
          categoriaId: _categoriaId!,
          name: _nameCtrl.text.trim(),
          telefono: _telefonoCtrl.text.trim(),
          direccion: _direccionCtrl.text.trim(),
          descripcion: _descripcionCtrl.text.trim(),
          metodosPago: _metodosPago.toList(),
          tiposEntrega: _tiposEntrega.toList(),
          logoBytes: _logoBytes,
          portadaBytes: _portadaBytes,
        );
      }

      if (!mounted) return;
      widget.onSaved?.call(saved);
      Navigator.pop(context, saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Comercio actualizado' : 'Comercio registrado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await mostrarAlertaError(
        context,
        mensaje: mensajeErrorEspanol(e),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final portadaUrl = widget.comercio?.portada != null
        ? ApiConfig.resolveImageUrl(widget.comercio!.portada)
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        title: Text(_isEdit ? 'Editar comercio' : 'Registrar comercio'),
      ),
      body: widget.categorias.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No hay categorías disponibles.\nCreá al menos una categoría antes de registrar un comercio.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: AppColors.gray500),
                ),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ImagePickerField(
                    label: 'Logo del comercio',
                    imageUrl: widget.comercio?.logoUrl,
                    imageBytes: _logoBytes,
                    onPicked: (bytes) => setState(() => _logoBytes = bytes),
                    height: 120,
                  ),
                  const SizedBox(height: 16),
                  ImagePickerField(
                    label: 'Portada del comercio',
                    imageUrl: portadaUrl,
                    imageBytes: _portadaBytes,
                    onPicked: (bytes) => setState(() => _portadaBytes = bytes),
                    height: 160,
                  ),
                  const SizedBox(height: 16),
                  PanelTextField(
                    label: 'Nombre *',
                    controller: _nameCtrl,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 14),
                  _buildCategoriaDropdown(),
                  const SizedBox(height: 14),
                  PanelTextField(
                    label: 'Teléfono',
                    controller: _telefonoCtrl,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  PanelTextField(
                    label: 'Dirección',
                    controller: _direccionCtrl,
                  ),
                  const SizedBox(height: 14),
                  PanelTextField(
                    label: 'Descripción',
                    controller: _descripcionCtrl,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  _buildMultiSelect('Métodos de pago *', kMetodosPago, _metodosPago),
                  const SizedBox(height: 12),
                  _buildMultiSelect('Tipos de entrega *', kTiposEntrega, _tiposEntrega),
                  const SizedBox(height: 24),
                  PanelSaveButton(
                    label: _isEdit ? 'Guardar cambios' : 'Registrar comercio',
                    loading: _saving,
                    onPressed: _save,
                  ),
                  if (!_isEdit) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.isAdmin
                          ? 'Como administrador, el comercio quedará aprobado y visible de inmediato.'
                          : 'Tu comercio quedará pendiente de aprobación por el administrador.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildCategoriaDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categoría *',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: _categoriaId,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: widget.categorias
              .map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.nombreCategoria),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _categoriaId = v),
        ),
      ],
    );
  }

  Widget _buildMultiSelect(
    String title,
    List<String> options,
    Set<String> selected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (v) {
                setState(() {
                  if (v) {
                    selected.add(option);
                  } else {
                    selected.remove(option);
                  }
                });
              },
              selectedColor: AppColors.yellow,
            );
          }).toList(),
        ),
      ],
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
