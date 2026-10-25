import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../data/cliente_repository.dart';

class PedidoRatingScreen extends StatefulWidget {
  const PedidoRatingScreen({super.key, required this.pedidoId});

  final int pedidoId;

  @override
  State<PedidoRatingScreen> createState() => _PedidoRatingScreenState();
}

class _PedidoRatingScreenState extends State<PedidoRatingScreen> {
  late final ClienteRepository _repository;
  final _comentarioComercio = TextEditingController();
  final Map<int, int> _calificacionesProductos = {};
  final Map<int, TextEditingController> _comentariosProductos = {};
  List<PedidoLineItem> _productos = [];
  bool _loading = true;
  bool _sending = false;
  bool _completed = false;
  String? _error;
  int _calificacionComercio = 0;

  static const _statusesConfirmables = {
    'Listo',
    'En espera',
    'Enviado',
    'Entregado',
  };

  @override
  void initState() {
    super.initState();
    _repository = ClienteRepository(
      context.read<AuthProvider>().repository.apiClient,
    );
    _loadPedido();
  }

  @override
  void dispose() {
    _comentarioComercio.dispose();
    for (final controller in _comentariosProductos.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPedido() async {
    try {
      final pedido = await _repository.getPedido(widget.pedidoId);
      if (!mounted) return;
      final productos = <int, PedidoLineItem>{};
      for (final item in pedido.lineItems) {
        final id = item.productoId;
        if (id != null) productos.putIfAbsent(id, () => item);
      }
      setState(() {
        _productos = productos.values.toList();
        _completed = pedido.valorada;
        if (!_completed && !_statusesConfirmables.contains(pedido.status)) {
          _error = 'El pedido todavía no está listo para confirmar la entrega.';
        }
        for (final producto in _productos) {
          final id = producto.productoId!;
          _calificacionesProductos[id] = 0;
          _comentariosProductos[id] = TextEditingController();
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mensajeErrorEspanol(e);
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_sending || _error != null) return;
    if (_calificacionComercio == 0 ||
        _calificacionesProductos.values.any((rating) => rating == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calificá el comercio y cada producto para continuar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await _repository.confirmarEntregaConValoracion(
        pedidoId: widget.pedidoId,
        calificacion: _calificacionComercio,
        comentario: _comentarioComercio.text,
        productos: _productos.map((producto) {
          final id = producto.productoId!;
          return {
            'productoId': id,
            'calificacion': _calificacionesProductos[id],
            if (_comentariosProductos[id]!.text.trim().isNotEmpty)
              'comentario': _comentariosProductos[id]!.text.trim(),
          };
        }).toList(),
      );
      if (!mounted) return;
      setState(() {
        _completed = true;
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
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
        title: Text(
          _completed ? '¡Gracias por tu opinión!' : 'Confirmar entrega',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            )
          : _completed
              ? _buildCompleted()
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: AppColors.gray600),
                        ),
                      ),
                    )
                  : _buildForm(),
    );
  }

  Widget _buildCompleted() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 76,
              color: AppColors.green,
            ),
            const SizedBox(height: 16),
            Text(
              '¡Pedido entregado!',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gracias por calificar el comercio y sus productos.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: AppColors.gray500),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  foregroundColor: AppColors.navy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Ver pedido',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '¿Ya recibiste tu pedido #${widget.pedidoId}?',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Al enviar tu opinión, confirmás que recibiste el pedido.',
          style: GoogleFonts.poppins(color: AppColors.gray500),
        ),
        const SizedBox(height: 20),
        _ratingCard(
          title: 'Comercio',
          rating: _calificacionComercio,
          onChanged: (rating) => setState(() => _calificacionComercio = rating),
          controller: _comentarioComercio,
          commentHint: 'Dejá un comentario sobre el comercio (opcional)',
        ),
        for (final producto in _productos) ...[
          const SizedBox(height: 12),
          _ratingCard(
            title: producto.nombre,
            rating: _calificacionesProductos[producto.productoId] ?? 0,
            onChanged: (rating) => setState(
              () => _calificacionesProductos[producto.productoId!] = rating,
            ),
            controller: _comentariosProductos[producto.productoId!]!,
            commentHint: 'Comentario sobre el producto (opcional)',
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _sending ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.yellow,
              foregroundColor: AppColors.navy,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: _sending
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Confirmar recepción y enviar opinión',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _ratingCard({
    required String title,
    required int rating,
    required ValueChanged<int> onChanged,
    required TextEditingController controller,
    required String commentHint,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(
              5,
              (index) => IconButton(
                onPressed: () => onChanged(index + 1),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 38, minHeight: 40),
                icon: Icon(
                  index < rating ? Icons.star_rounded : Icons.star_outline,
                  color: AppColors.yellowDark,
                  size: 30,
                ),
                tooltip: '${index + 1} estrellas',
              ),
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: commentHint,
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
