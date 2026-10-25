import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/panel/form_widgets.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../cliente/data/models/catalog_models.dart';
import '../../data/comerciante_repository.dart';

const _tiposPromo = ['Porcentaje', 'Fijo', '2x1'];

class PromocionFormScreen extends StatefulWidget {
  const PromocionFormScreen({super.key, required this.comercio});

  final ComercioModel comercio;

  @override
  State<PromocionFormScreen> createState() => _PromocionFormScreenState();
}

class _PromocionFormScreenState extends State<PromocionFormScreen> {
  late final ComercianteRepository _repository;
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _valorCtrl = TextEditingController(text: '10');
  String _tipo = 'Porcentaje';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository = ComercianteRepository(
      context.read<AuthProvider>().repository.apiClient,
    );
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    _valorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nombre = _nombreCtrl.text.trim();
    final valor = double.tryParse(_valorCtrl.text.trim().replaceAll(',', '.'));
    if (nombre.isEmpty || valor == null || valor < 0) {
      await mostrarAlertaError(
        context,
        titulo: 'Datos incompletos',
        mensaje: 'Completá nombre y un valor válido.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _repository.createPromocion(
        comercioId: widget.comercio.id,
        nombre: nombre,
        tipo: _tipo,
        valor: valor,
        descripcion: _descCtrl.text.trim(),
      );
      if (!mounted) return;
      context.pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Promoción creada'),
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
          'Nueva promoción',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PanelTextField(
            label: 'Nombre *',
            controller: _nombreCtrl,
          ),
          const SizedBox(height: 14),
          PanelTextField(
            label: 'Descripción',
            controller: _descCtrl,
            maxLines: 2,
          ),
          const SizedBox(height: 14),
          Text(
            'Tipo',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _tiposPromo
                .map(
                  (t) => ChoiceChip(
                    label: Text(t),
                    selected: _tipo == t,
                    onSelected: (_) => setState(() => _tipo = t),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          PanelTextField(
            label: _tipo == '2x1' ? 'Valor (referencia)' : 'Valor *',
            controller: _valorCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          Text(
            _tipo == 'Porcentaje'
                ? 'Ej: 20 = 20% de descuento'
                : _tipo == 'Fijo'
                    ? 'Ej: 100 = \$100 de descuento'
                    : 'Para 2x1 podés poner 0 o el precio de referencia',
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.gray500),
          ),
          const SizedBox(height: 24),
          PanelSaveButton(
            label: 'Publicar promoción',
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
