import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/panel/panel_widgets.dart';
import '../../data/admin_repository.dart';

class AdminCuponesScreen extends StatefulWidget {
  const AdminCuponesScreen({super.key, required this.repository});

  final AdminRepository repository;

  @override
  State<AdminCuponesScreen> createState() => _AdminCuponesScreenState();
}

class _AdminCuponesScreenState extends State<AdminCuponesScreen> {
  List<CuponModel> _cupones = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cupones = await widget.repository.getCupones();
      if (!mounted) return;
      setState(() {
        _cupones = cupones;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  Future<void> _openCreate() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CuponFormSheet(repository: widget.repository),
    );
    if (created == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        title: Text(
          'Cupones globales',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: _openCreate,
            icon: const Icon(Icons.add, color: AppColors.yellow),
            tooltip: 'Nuevo cupón',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            )
          : _cupones.isEmpty
              ? const EmptyPanelState(
                  icon: Icons.local_offer_outlined,
                  title: 'Sin cupones',
                  subtitle: 'Creá un cupón para promociones globales.',
                )
              : RefreshIndicator(
                  color: AppColors.yellow,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _cupones.length,
                    itemBuilder: (context, index) {
                      final cupon = _cupones[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.yellow.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.confirmation_number_outlined,
                                  color: AppColors.navy,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cupon.codigo,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                    Text(
                                      '${cupon.valorLabel} · ${cupon.tipo}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppColors.gray500,
                                      ),
                                    ),
                                    if (cupon.minCompra > 0)
                                      Text(
                                        'Mín. compra: \$${cupon.minCompra.toStringAsFixed(0)}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: AppColors.gray400,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              PanelBadge(
                                label: cupon.activo ? 'Activo' : 'Inactivo',
                                background: cupon.activo
                                    ? AppColors.green.withValues(alpha: 0.15)
                                    : AppColors.gray400.withValues(alpha: 0.2),
                                foreground: cupon.activo
                                    ? AppColors.green
                                    : AppColors.gray600,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _CuponFormSheet extends StatefulWidget {
  const _CuponFormSheet({required this.repository});

  final AdminRepository repository;

  @override
  State<_CuponFormSheet> createState() => _CuponFormSheetState();
}

class _CuponFormSheetState extends State<_CuponFormSheet> {
  final _codigoController = TextEditingController();
  final _valorController = TextEditingController();
  final _minCompraController = TextEditingController();
  String _tipo = 'Porcentaje';
  bool _saving = false;

  static const _tipos = ['Porcentaje', 'Fijo', 'Envio'];

  @override
  void dispose() {
    _codigoController.dispose();
    _valorController.dispose();
    _minCompraController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final codigo = _codigoController.text.trim().toUpperCase();
    final valor = double.tryParse(_valorController.text.trim());
    if (codigo.isEmpty || valor == null) {
      await mostrarAlertaError(
        context,
        titulo: 'Datos incompletos',
        mensaje: 'Ingresá código y valor del cupón.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.repository.createCupon(
        codigo: codigo,
        tipo: _tipo,
        valor: valor,
        minCompra: double.tryParse(_minCompraController.text.trim()),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nuevo cupón',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codigoController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Código',
              hintText: 'VERANO2026',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _tipo,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: _tipos
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _tipo = v ?? 'Porcentaje'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _valorController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _tipo == 'Porcentaje' ? 'Porcentaje' : 'Valor',
              hintText: _tipo == 'Porcentaje' ? '15' : '500',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minCompraController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Compra mínima (opcional)',
              hintText: '1000',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.yellow,
              foregroundColor: AppColors.navy,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Crear cupón',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }
}
