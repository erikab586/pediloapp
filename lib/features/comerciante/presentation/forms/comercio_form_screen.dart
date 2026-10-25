import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/utils/rubro_copy.dart';
import '../../../../core/widgets/panel/form_widgets.dart';
import '../../../cliente/data/models/catalog_models.dart';
import '../../../shared/data/comercio_form_repository.dart';

const kMetodosPago = [
  'Efectivo',
  'POS',
  'MercadoPago',
  'Transferencia',
];

const kTiposEntrega = [
  'Retiro en local',
  'Envío a domicilio',
];

class _DiaHorarioState {
  _DiaHorarioState({
    this.cerrado = false,
    String abre = '10:00',
    String cierra = '22:00',
  })  : abreCtrl = TextEditingController(text: abre),
        cierraCtrl = TextEditingController(text: cierra);

  bool cerrado;
  final TextEditingController abreCtrl;
  final TextEditingController cierraCtrl;

  void dispose() {
    abreCtrl.dispose();
    cierraCtrl.dispose();
  }

  Map<String, dynamic> toJson() {
    if (cerrado) return {'cerrado': true};
    return {
      'cerrado': false,
      'abre': abreCtrl.text.trim(),
      'cierra': cierraCtrl.text.trim(),
    };
  }

  static _DiaHorarioState fromRaw(dynamic raw, {bool defaultCerrado = false}) {
    if (raw == null) {
      return _DiaHorarioState(cerrado: defaultCerrado);
    }
    if (raw is String) {
      final s = raw.trim().toLowerCase();
      if (s.isEmpty || s == 'cerrado' || s == 'closed') {
        return _DiaHorarioState(cerrado: true);
      }
      final parts = raw.split('-').map((p) => p.trim()).toList();
      if (parts.length == 2) {
        return _DiaHorarioState(
          cerrado: false,
          abre: parts[0],
          cierra: parts[1],
        );
      }
      return _DiaHorarioState(cerrado: defaultCerrado);
    }
    if (raw is Map) {
      final cerrado = raw['cerrado'] == true;
      return _DiaHorarioState(
        cerrado: cerrado,
        abre: (raw['abre']?.toString().trim().isNotEmpty == true)
            ? raw['abre'].toString()
            : '10:00',
        cierra: (raw['cierra']?.toString().trim().isNotEmpty == true)
            ? raw['cierra'].toString()
            : '22:00',
      );
    }
    return _DiaHorarioState(cerrado: defaultCerrado);
  }
}

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
  late final TextEditingController _tiempoMinCtrl;
  late final TextEditingController _tiempoMaxCtrl;
  late final TextEditingController _montoMinCtrl;

  int? _categoriaId;
  Uint8List? _logoBytes;
  Uint8List? _portadaBytes;
  Set<String> _metodosPago = {};
  Set<String> _tiposEntrega = {};
  final Map<String, _DiaHorarioState> _horarios = {};
  bool _horarioAutomatico = false;
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
    _tiempoMinCtrl = TextEditingController(
      text: c?.tiempoEntregaMin?.toString() ?? '25',
    );
    _tiempoMaxCtrl = TextEditingController(
      text: c?.tiempoEntregaMax?.toString() ?? '40',
    );
    _montoMinCtrl = TextEditingController(
      text: c != null && c.montoMinimo > 0
          ? (c.montoMinimo == c.montoMinimo.roundToDouble()
              ? c.montoMinimo.toInt().toString()
              : c.montoMinimo.toStringAsFixed(2))
          : '0',
    );
    _categoriaId = c?.categoriaId ?? widget.categorias.firstOrNull?.id;
    _horarioAutomatico = c?.horarioAutomatico ?? false;
    _metodosPago = Set<String>.from(
      c?.metodosPago.isNotEmpty == true ? c!.metodosPago : ['Efectivo', 'POS'],
    );
    _tiposEntrega = Set<String>.from(
      c?.tiposEntrega.isNotEmpty == true
          ? c!.tiposEntrega
          : ['Retiro en local', 'Envío a domicilio'],
    );
    for (final d in kDiasSemana) {
      _horarios[d] = _DiaHorarioState.fromRaw(
        c?.horarios?[d],
        defaultCerrado: d == 'domingo',
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _descripcionCtrl.dispose();
    _tiempoMinCtrl.dispose();
    _tiempoMaxCtrl.dispose();
    _montoMinCtrl.dispose();
    for (final h in _horarios.values) {
      h.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _horariosMap {
    final map = <String, dynamic>{};
    for (final d in kDiasSemana) {
      map[d] = _horarios[d]!.toJson();
    }
    return map;
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

    final tiempoMin = int.tryParse(_tiempoMinCtrl.text.trim());
    final tiempoMax = int.tryParse(_tiempoMaxCtrl.text.trim());
    final montoMin = double.tryParse(
          _montoMinCtrl.text.trim().replaceAll(',', '.'),
        ) ??
        0;

    if (tiempoMin != null && tiempoMax != null && tiempoMax < tiempoMin) {
      await mostrarAlertaError(
        context,
        titulo: 'Datos inválidos',
        mensaje: 'El tiempo máximo de entrega no puede ser menor al mínimo.',
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
          horarios: _horariosMap,
          horarioAutomatico: _horarioAutomatico,
          tiempoEntregaMin: tiempoMin,
          tiempoEntregaMax: tiempoMax,
          montoMinimo: montoMin,
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
          horarios: _horariosMap,
          horarioAutomatico: _horarioAutomatico,
          tiempoEntregaMin: tiempoMin,
          tiempoEntregaMax: tiempoMax,
          montoMinimo: montoMin,
          logoBytes: _logoBytes,
          portadaBytes: _portadaBytes,
        );
      }

      if (!mounted) return;
      widget.onSaved?.call(saved);
      Navigator.pop(context, saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(_isEdit ? 'Comercio actualizado' : 'Comercio registrado'),
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
                  Text(
                    'Entrega',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: PanelTextField(
                          label: 'Demora mín. (min)',
                          controller: _tiempoMinCtrl,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Requerido';
                            }
                            if (int.tryParse(v.trim()) == null) {
                              return 'Número inválido';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PanelTextField(
                          label: 'Demora máx. (min)',
                          controller: _tiempoMaxCtrl,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Requerido';
                            }
                            if (int.tryParse(v.trim()) == null) {
                              return 'Número inválido';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  PanelTextField(
                    label: 'Monto mínimo de envío / pedido',
                    controller: _montoMinCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerido';
                      final n = double.tryParse(v.replaceAll(',', '.'));
                      if (n == null || n < 0) return 'Monto inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildMultiSelect(
                    'Métodos de pago *',
                    kMetodosPago,
                    _metodosPago,
                  ),
                  const SizedBox(height: 12),
                  _buildMultiSelect(
                    'Tipos de entrega *',
                    kTiposEntrega,
                    _tiposEntrega,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Horario de atención',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Marcá cada día con hora de apertura y cierre.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.gray500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Abrir/cerrar automáticamente según horario',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.navy,
                      ),
                    ),
                    subtitle: Text(
                      'Si está activo, el estado del local sigue el horario. El botón manual lo desactiva.',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.gray500,
                      ),
                    ),
                    value: _horarioAutomatico,
                    activeThumbColor: AppColors.navy,
                    activeTrackColor: AppColors.yellow,
                    onChanged: (v) => setState(() => _horarioAutomatico = v),
                  ),
                  const SizedBox(height: 8),
                  ...kDiasSemana.map(_buildDiaHorario),
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

  Widget _buildDiaHorario(String dia) {
    final state = _horarios[dia]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray400.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  kDiasLabels[dia] ?? dia,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              ),
              Text(
                'Cerrado',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.gray500,
                ),
              ),
              Switch(
                value: state.cerrado,
                activeThumbColor: AppColors.navy,
                onChanged: (v) => setState(() => state.cerrado = v),
              ),
            ],
          ),
          if (!state.cerrado) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: PanelTextField(
                    label: 'Abre (HH:mm)',
                    controller: state.abreCtrl,
                    validator: (v) {
                      if (state.cerrado) return null;
                      if (v == null || !_isHm(v.trim())) {
                        return 'Ej: 10:00';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PanelTextField(
                    label: 'Cierra (HH:mm)',
                    controller: state.cierraCtrl,
                    validator: (v) {
                      if (state.cerrado) return null;
                      if (v == null || !_isHm(v.trim())) {
                        return 'Ej: 22:00';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _isHm(String value) {
    return RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$').hasMatch(value);
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
    final allOptions = {...options, ...selected}.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.navy,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _addCustomOption(selected),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar'),
            ),
          ],
        ),
        Text(
          'Activo = seleccionado. Podés agregar nombres propios (ej. POS).',
          style: GoogleFonts.poppins(fontSize: 11, color: AppColors.gray500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allOptions.map((option) {
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
              onDeleted: options.contains(option)
                  ? null
                  : () {
                      setState(() {
                        selected.remove(option);
                      });
                    },
              selectedColor: AppColors.yellow,
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _addCustomOption(Set<String> selected) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva opción'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Ej: POS / Envío a domicilio',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => selected.add(name));
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
