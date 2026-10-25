import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/analytics/app_analytics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../data/catalog_repository.dart';
import '../../data/cliente_repository.dart';
import '../../data/models/catalog_models.dart';

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
  String _tipoEntrega = 'Retiro en local';
  String _metodoPago = 'Efectivo';
  int? _direccionId;
  final _cuponController = TextEditingController();
  final _valorEfectivoController = TextEditingController();
  final _notaController = TextEditingController();
  bool _loading = true;
  bool _confirming = false;
  int _step = 0; // 0 entrega, 1 pago, 2 confirmar

  static const _steps = ['Entrega', 'Pago', 'Confirmar'];

  bool get _isEfectivo =>
      _metodoPago.toLowerCase().contains('efectivo');

  double get _totalPedido => _preview?.total ?? 0;

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
    _valorEfectivoController.dispose();
    _notaController.dispose();
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
    try {
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
    } catch (_) {}
  }

  bool get _needsDireccion {
    final t = _tipoEntrega.toLowerCase();
    return t.contains('delivery') ||
        t.contains('envío') ||
        t.contains('envio') ||
        t.contains('domicilio');
  }

  bool get _canContinueStep0 {
    if (!_needsDireccion) return true;
    return _direccionId != null;
  }

  Future<void> _next() async {
    if (_step == 0) {
      if (!_canContinueStep0) {
        await mostrarAlertaError(
          context,
          titulo: 'Dirección requerida',
          mensaje: 'Seleccioná una dirección para delivery o agregá una nueva.',
        );
        return;
      }
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (!await _validarValorEfectivo()) return;
      setState(() => _step = 2);
      return;
    }
    await _confirmar();
  }

  /// Valida el campo Valor cuando el pago es Efectivo.
  /// Si es insuficiente muestra modal tipo SweetAlert y deja editar el input.
  Future<bool> _validarValorEfectivo() async {
    if (!_isEfectivo) return true;

    final raw = _valorEfectivoController.text.trim().replaceAll(',', '.');
    final valor = double.tryParse(raw);
    if (valor == null) {
      await mostrarAlertaError(
        context,
        titulo: 'Valor requerido',
        mensaje: 'Indicá con cuánto vas a pagar en efectivo.',
      );
      return false;
    }
    if (valor < _totalPedido) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Saldo insuficiente',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          content: Text(
            'Saldo insuficiente. El valor debe ser igual o mayor al total',
            style: GoogleFonts.poppins(color: AppColors.gray600),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.yellow,
                foregroundColor: AppColors.navy,
              ),
              child: Text(
                'Ok',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _confirmar() async {
    if (_needsDireccion && _direccionId == null) {
      setState(() => _step = 0);
      await mostrarAlertaError(
        context,
        titulo: 'Dirección requerida',
        mensaje: 'Seleccioná una dirección para delivery.',
      );
      return;
    }

    if (!await _validarValorEfectivo()) {
      setState(() => _step = 1);
      return;
    }

    setState(() => _confirming = true);
    try {
      final valorRaw =
          _valorEfectivoController.text.trim().replaceAll(',', '.');
      final pedido = await _repository.confirmarPedido(
        metodoPago: _metodoPago,
        tipoEntrega: _tipoEntrega,
        direccionId: _needsDireccion ? _direccionId : null,
        entregaPrecio: _preview?.entregaPrecio,
        notas: _notaController.text.trim().isEmpty
            ? null
            : _notaController.text.trim(),
        valorEfectivo: _isEfectivo ? double.tryParse(valorRaw) : null,
      );
      if (!mounted) return;
      AppAnalytics.checkoutConfirmed(pedidoId: pedido.id);
      context.go(
        '/cliente/pedidos/${pedido.id}/exito',
        extra: {
          'comercioNombre': _comercio?.name ?? pedido.comercioNombre,
          'total': _preview?.total ?? pedido.total,
          'tipoEntrega': _tipoEntrega,
        },
      );
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Checkout',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step > 0) {
              setState(() => _step -= 1);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  ShimmerBox(height: 48, borderRadius: 12),
                  SizedBox(height: 16),
                  ShimmerBox(height: 120, borderRadius: 16),
                  SizedBox(height: 12),
                  ShimmerBox(height: 120, borderRadius: 16),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _CheckoutStepper(step: _step, labels: _steps),
                ),
                if (comercio != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        comercio.name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_step == 0) _buildEntregaStep(comercio),
                      if (_step == 1) _buildPagoStep(comercio),
                      if (_step == 2) _buildConfirmarStep(preview),
                      const SizedBox(height: 88),
                    ],
                  ),
                ),
                _StickyCheckoutBar(
                  total: preview?.total,
                  label: _step == 2 ? 'Confirmar pedido' : 'Continuar',
                  loading: _confirming,
                  onPressed: _confirming ? null : _next,
                ),
              ],
            ),
    );
  }

  Widget _buildEntregaStep(ComercioModel? comercio) {
    final tipos = comercio?.tiposEntrega.isNotEmpty == true
        ? comercio!.tiposEntrega
        : ['Retiro en local', 'Envío a domicilio'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '¿Cómo lo querés recibir?',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        ...tipos.map((t) {
          final selected = _tipoEntrega == t;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: selected
                  ? AppColors.yellow.withValues(alpha: 0.3)
                  : AppColors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () async {
                  setState(() => _tipoEntrega = t);
                  await _refreshPreview();
                },
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: AppColors.navy,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        if (_needsDireccion) ...[
          const SizedBox(height: 16),
          Text(
            'Dirección de entrega',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          if (_direcciones.isEmpty)
            EmptyActionState(
              icon: Icons.location_off_outlined,
              title: 'Sin direcciones',
              subtitle:
                  'Agregá una dirección para poder pedir con delivery.',
              actionLabel: 'Ir a direcciones',
              onAction: () => context.push('/cliente/home?tab=4'),
            )
          else
            ..._direcciones.map((d) {
              final selected = _direccionId == d.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: selected
                      ? AppColors.yellow.withValues(alpha: 0.3)
                      : AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () async {
                      setState(() => _direccionId = d.id);
                      await _refreshPreview();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: AppColors.navy,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.tipo,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.navy,
                                  ),
                                ),
                                Text(
                                  d.label,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.gray500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ],
    );
  }

  Widget _buildPagoStep(ComercioModel? comercio) {
    final metodos = comercio?.metodosPago.isNotEmpty == true
        ? comercio!.metodosPago
        : ['Efectivo', 'POS'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Método de pago',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _metodoPago.toLowerCase().contains('efectivo')
              ? 'Pagás al recibir el pedido.'
              : 'El local confirmará el pago según el método elegido.',
          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.gray500),
        ),
        const SizedBox(height: 12),
        ...metodos.map((m) {
          final selected = _metodoPago == m;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: selected
                  ? AppColors.yellow.withValues(alpha: 0.3)
                  : AppColors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () async {
                  setState(() => _metodoPago = m);
                  if (!m.toLowerCase().contains('efectivo')) {
                    _valorEfectivoController.clear();
                  }
                  await _refreshPreview();
                },
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: AppColors.navy,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        m,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        if (_isEfectivo) ...[
          const SizedBox(height: 16),
          Text(
            'Valor',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Con cuánto vas a pagar (debe ser ≥ \$${_totalPedido.toStringAsFixed(0)})',
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.gray500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _valorEfectivoController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Valor',
              hintText: '0.00',
              filled: true,
              fillColor: AppColors.white,
              prefixText: '\$ ',
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Cupón (opcional)',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cuponController,
                decoration: const InputDecoration(
                  hintText: 'Código de cupón',
                  filled: true,
                  fillColor: AppColors.white,
                ),
                onSubmitted: (_) => _refreshPreview(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _refreshPreview,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfirmarStep(PedidoPreviewModel? preview) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Revisá y confirmá',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _SummaryRow(label: 'Entrega', value: _tipoEntrega),
              if (_needsDireccion && _direccionId != null)
                _SummaryRow(
                  label: 'Dirección',
                  value: _direcciones
                          .where((d) => d.id == _direccionId)
                          .map((d) => d.label)
                          .firstOrNull ??
                      '—',
                ),
              _SummaryRow(label: 'Pago', value: _metodoPago),
              if (_isEfectivo &&
                  _valorEfectivoController.text.trim().isNotEmpty)
                _SummaryRow(
                  label: 'Valor',
                  value:
                      '\$${_valorEfectivoController.text.trim().replaceAll(',', '.')}',
                ),
              const Divider(height: 24),
              if (preview != null) ...[
                _SummaryRow(
                  label: 'Subtotal',
                  value: '\$${preview.subtotal.toStringAsFixed(0)}',
                ),
                if (preview.descuento > 0)
                  _SummaryRow(
                    label: 'Descuento',
                    value: '-\$${preview.descuento.toStringAsFixed(0)}',
                  ),
                if (preview.entregaPrecio > 0)
                  _SummaryRow(
                    label: 'Envío',
                    value: '\$${preview.entregaPrecio.toStringAsFixed(0)}',
                  ),
                _SummaryRow(
                  label: 'Total',
                  value: '\$${preview.total.toStringAsFixed(0)}',
                  bold: true,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Nota',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Observaciones para el comercio (sin cebolla, timbre, etc.).',
          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.gray500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notaController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Nota',
            hintText: 'Escribí tus observaciones…',
            filled: true,
            fillColor: AppColors.white,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tu pedido se envía al local en segundos.',
          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.gray500),
        ),
      ],
    );
  }
}

class _CheckoutStepper extends StatelessWidget {
  const _CheckoutStepper({required this.step, required this.labels});

  final int step;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          final done = step > i ~/ 2;
          return Expanded(
            child: Container(
              height: 2,
              color: done ? AppColors.yellow : const Color(0xFFE5E7EB),
            ),
          );
        }
        final index = i ~/ 2;
        final active = step >= index;
        return Column(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.yellow : const Color(0xFFE5E7EB),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              labels[index],
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? AppColors.navy : AppColors.gray400,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _StickyCheckoutBar extends StatelessWidget {
  const _StickyCheckoutBar({
    required this.total,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final double? total;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      color: AppColors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              if (total != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.gray500,
                        ),
                      ),
                      Text(
                        '\$${total!.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Spacer(),
              FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  foregroundColor: AppColors.navy,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        label,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(color: AppColors.gray600)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: bold ? AppColors.green : AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
