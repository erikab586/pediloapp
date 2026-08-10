import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/auth_provider.dart';
import '../../data/catalog_repository.dart';
import '../../data/cliente_repository.dart';
import '../../data/models/catalog_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';

class ClienteCheckoutScreen extends StatefulWidget {
  const ClienteCheckoutScreen({super.key, required this.comercioId});

  final int comercioId;

  @override
  State<ClienteCheckoutScreen> createState() => _ClienteCheckoutScreenState();
}

class _ClienteCheckoutScreenState extends State<ClienteCheckoutScreen> {
  late final ClienteRepository _repository;
  late final CatalogRepository _catalogRepository;

  ComercioModel? _comercio;
  List<DireccionModel> _direcciones = [];
  PedidoPreviewModel? _preview;
  String _tipoEntrega = 'Retiro';
  String _metodoPago = 'Efectivo';
  int? _direccionId;
  final _cuponController = TextEditingController();
  bool _loading = true;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    final api = context.read<AuthProvider>().repository.apiClient;
    _repository = ClienteRepository(api);
    _catalogRepository = CatalogRepository(api);
    _load();
  }

  @override
  void dispose() {
    _cuponController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final comercio = await _catalogRepository.getComercio(widget.comercioId);
      final direcciones = await _repository.getDirecciones();
      if (!mounted) return;

      _comercio = comercio;
      _direcciones = direcciones;
      if (comercio.tiposEntrega.isNotEmpty) {
        _tipoEntrega = comercio.tiposEntrega.first;
      }
      if (comercio.metodosPago.isNotEmpty) {
        _metodoPago = comercio.metodosPago.first;
      }
      _direccionId = direcciones
          .where((d) => d.predeterminada)
          .map((d) => d.id)
          .firstOrNull;

      await _refreshPreview();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  Future<void> _refreshPreview() async {
    final preview = await _repository.previewPedido(
      comercioId: widget.comercioId,
      metodoPago: _metodoPago,
      tipoEntrega: _tipoEntrega,
      direccionId: _needsDireccion ? _direccionId : null,
      cuponCodigo: _cuponController.text.trim().isEmpty
          ? null
          : _cuponController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _preview = preview);
  }

  bool get _needsDireccion =>
      _tipoEntrega.toLowerCase().contains('delivery');

  Future<void> _confirmar() async {
    if (_needsDireccion && _direccionId == null) {
      await mostrarAlertaError(
        context,
        titulo: 'Dirección requerida',
        mensaje: 'Seleccioná una dirección para delivery.',
      );
      return;
    }

    setState(() => _confirming = true);
    try {
      await _repository.confirmarPedido(
        metodoPago: _metodoPago,
        tipoEntrega: _tipoEntrega,
        direccionId: _needsDireccion ? _direccionId : null,
        entregaPrecio: _preview?.entregaPrecio,
      );
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirming = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final comercio = _comercio;
    final preview = _preview;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Confirmar pedido',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (comercio != null)
                  Text(
                    comercio.name,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                const SizedBox(height: 16),
                Text('Tipo de entrega',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: (comercio?.tiposEntrega.isNotEmpty == true
                          ? comercio!.tiposEntrega
                          : ['Retiro', 'Delivery propio'])
                      .map(
                        (t) => ChoiceChip(
                          label: Text(t),
                          selected: _tipoEntrega == t,
                          onSelected: (_) async {
                            setState(() => _tipoEntrega = t);
                            await _refreshPreview();
                          },
                        ),
                      )
                      .toList(),
                ),
                if (_needsDireccion) ...[
                  const SizedBox(height: 16),
                  Text('Dirección',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_direcciones.isEmpty)
                    Text(
                      'No tenés direcciones. Agregá una desde Perfil.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.gray500,
                      ),
                    )
                  else
                    ..._direcciones.map(
                      (d) => RadioListTile<int>(
                        value: d.id,
                        groupValue: _direccionId,
                        onChanged: (v) async {
                          setState(() => _direccionId = v);
                          await _refreshPreview();
                        },
                        title: Text(d.label),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                Text('Método de pago',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: (comercio?.metodosPago.isNotEmpty == true
                          ? comercio!.metodosPago
                          : ['Efectivo', 'Tarjeta'])
                      .map(
                        (m) => ChoiceChip(
                          label: Text(m),
                          selected: _metodoPago == m,
                          onSelected: (_) async {
                            setState(() => _metodoPago = m);
                            await _refreshPreview();
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _cuponController,
                  decoration: const InputDecoration(
                    labelText: 'Código de cupón (opcional)',
                  ),
                  onSubmitted: (_) => _refreshPreview(),
                ),
                TextButton(
                  onPressed: _refreshPreview,
                  child: const Text('Aplicar cupón'),
                ),
                const SizedBox(height: 16),
                if (preview != null) ...[
                  _Row(label: 'Subtotal', value: '\$${preview.subtotal.toStringAsFixed(0)}'),
                  if (preview.descuento > 0)
                    _Row(
                      label: 'Descuento',
                      value: '-\$${preview.descuento.toStringAsFixed(0)}',
                    ),
                  if (preview.entregaPrecio > 0)
                    _Row(
                      label: 'Envío',
                      value: '\$${preview.entregaPrecio.toStringAsFixed(0)}',
                    ),
                  _Row(
                    label: 'Total',
                    value: '\$${preview.total.toStringAsFixed(0)}',
                    bold: true,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _confirming ? null : _confirmar,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.yellow,
                    foregroundColor: AppColors.navy,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _confirming
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Confirmar pedido',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: GoogleFonts.poppins(color: AppColors.gray600)),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: bold ? AppColors.green : AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
