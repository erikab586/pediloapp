import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/panel/form_widgets.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../cliente/data/models/catalog_models.dart';
import '../../../comerciante/presentation/forms/comercio_form_screen.dart';
import '../../../shared/data/comercio_form_repository.dart';

/// Wizard: cliente registra su comercio (queda pendiente de aprobación).
class VenderEnPediloWizard extends StatefulWidget {
  const VenderEnPediloWizard({super.key});

  @override
  State<VenderEnPediloWizard> createState() => _VenderEnPediloWizardState();
}

class _VenderEnPediloWizardState extends State<VenderEnPediloWizard> {
  late final ComercioFormRepository _repository;
  List<CategoriaModel> _categorias = [];
  bool _loading = true;
  bool _submitting = false;
  int _step = 0;

  final _clienteNombreCtrl = TextEditingController();
  final _clienteTelefonoCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  int? _categoriaId;
  Uint8List? _logoBytes;
  Uint8List? _portadaBytes;
  final Set<String> _metodosPago = {'Efectivo', 'POS'};
  final Set<String> _tiposEntrega = {'Retiro en local'};

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _clienteNombreCtrl.text = auth.user?.name ?? '';
    _clienteTelefonoCtrl.text = auth.user?.phone ?? '';
    final api = auth.repository.apiClient;
    _repository = ComercioFormRepository(api);
    _load();
  }

  @override
  void dispose() {
    _clienteNombreCtrl.dispose();
    _clienteTelefonoCtrl.dispose();
    _nameCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cats = await _repository.getCategorias();
      if (!mounted) return;
      setState(() {
        _categorias = cats;
        _categoriaId = cats.firstOrNull?.id;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  Future<void> _submit() async {
    if (_clienteNombreCtrl.text.trim().isEmpty ||
        _clienteTelefonoCtrl.text.trim().isEmpty) {
      await mostrarAlertaError(
        context,
        titulo: 'Datos incompletos',
        mensaje: 'Completá tu nombre y apellido y un número de contacto.',
      );
      setState(() => _step = 0);
      return;
    }
    if (_nameCtrl.text.trim().isEmpty || _categoriaId == null) {
      await mostrarAlertaError(
        context,
        titulo: 'Datos incompletos',
        mensaje: 'Completá el nombre y la categoría del comercio.',
      );
      setState(() => _step = 0);
      return;
    }
    if (_direccionCtrl.text.trim().isEmpty ||
        _telefonoCtrl.text.trim().isEmpty) {
      await mostrarAlertaError(
        context,
        titulo: 'Datos incompletos',
        mensaje: 'Completá dirección y teléfono del local.',
      );
      setState(() => _step = 1);
      return;
    }
    if (_metodosPago.isEmpty || _tiposEntrega.isEmpty) {
      setState(() => _step = 2);
      return;
    }

    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    try {
      // Asegura rol comerciante + tokens frescos antes de registrar.
      await auth.promoteToComerciante();
      final saved = await _repository.createComercio(
        categoriaId: _categoriaId!,
        solicitanteNombre: _clienteNombreCtrl.text.trim(),
        solicitanteTelefono: _clienteTelefonoCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
        metodosPago: _metodosPago.toList(),
        tiposEntrega: _tiposEntrega.toList(),
        logoBytes: _logoBytes,
        portadaBytes: _portadaBytes,
      );
      auth.updateLocalUserContact(
        name: _clienteNombreCtrl.text.trim(),
        phone: _clienteTelefonoCtrl.text.trim(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('¡Solicitud enviada!'),
          content: Text(
            'Revisaremos “${saved.name}” en 24–48 hs.\n'
            'Mientras tanto podés seguir comprando en pedilo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Seguir comprando'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (!mounted) return;
                context.push('/cliente/mi-comercio');
              },
              child: const Text('Ir a mi comercio'),
            ),
          ],
        ),
      );
      if (mounted) context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Vender en pedilo',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: List.generate(4, (i) {
                      final active = _step >= i;
                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                          height: 4,
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.yellow
                                : const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_step == 0) _buildNegocio(),
                      if (_step == 1) _buildUbicacion(),
                      if (_step == 2) _buildOperacion(),
                      if (_step == 3) _buildIdentidad(),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        if (_step > 0)
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : () => setState(() => _step -= 1),
                            child: const Text('Atrás'),
                          ),
                        const Spacer(),
                        FilledButton(
                          onPressed: _submitting
                              ? null
                              : () {
                                  if (_step < 3) {
                                    setState(() => _step += 1);
                                  } else {
                                    _submit();
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.yellow,
                            foregroundColor: AppColors.navy,
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _step < 3 ? 'Continuar' : 'Enviar solicitud'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildNegocio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tus datos',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _clienteNombreCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre y apellido del cliente *',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _clienteTelefonoCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Número de contacto del cliente *',
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Tu negocio',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Nombre del comercio *'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          // ignore: deprecated_member_use
          value: _categoriaId,
          decoration: const InputDecoration(labelText: 'Rubro / categoría *'),
          items: _categorias
              .map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.nombreCategoria),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _categoriaId = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descripcionCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Descripción corta'),
        ),
      ],
    );
  }

  Widget _buildUbicacion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Ubicación y contacto',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _direccionCtrl,
          decoration: const InputDecoration(labelText: 'Dirección del local *'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _telefonoCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Teléfono del local *'),
        ),
      ],
    );
  }

  Widget _buildOperacion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Cómo operás',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        Text('Métodos de pago',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: kMetodosPago
              .map(
                (m) => FilterChip(
                  label: Text(m),
                  selected: _metodosPago.contains(m),
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _metodosPago.add(m);
                      } else {
                        _metodosPago.remove(m);
                      }
                    });
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        Text('Tipos de entrega',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: kTiposEntrega
              .map(
                (t) => FilterChip(
                  label: Text(t),
                  selected: _tiposEntrega.contains(t),
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _tiposEntrega.add(t);
                      } else {
                        _tiposEntrega.remove(t);
                      }
                    });
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildIdentidad() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Identidad visual',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Opcional: podés subir logo y portada ahora o más tarde.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.gray500),
        ),
        const SizedBox(height: 16),
        ImagePickerField(
          label: 'Logo',
          imageBytes: _logoBytes,
          onPicked: (b) => setState(() => _logoBytes = b),
        ),
        const SizedBox(height: 12),
        ImagePickerField(
          label: 'Portada',
          imageBytes: _portadaBytes,
          onPicked: (b) => setState(() => _portadaBytes = b),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Al enviar, tu comercio queda en estado pendiente hasta que un administrador lo apruebe.',
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.navy),
          ),
        ),
      ],
    );
  }
}
