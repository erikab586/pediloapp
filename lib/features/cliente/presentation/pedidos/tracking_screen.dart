import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/socket_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../data/cliente_repository.dart';

class ClienteTrackingScreen extends StatefulWidget {
  const ClienteTrackingScreen({super.key, required this.pedidoId});

  final int pedidoId;

  @override
  State<ClienteTrackingScreen> createState() => _ClienteTrackingScreenState();
}

class _ClienteTrackingScreenState extends State<ClienteTrackingScreen> {
  late final ClienteRepository _repository;
  ClientePedidoDetailModel? _pedido;
  bool _loading = true;
  bool _repeating = false;
  bool _openingRating = false;
  StreamSubscription<Map<String, dynamic>>? _estadoSub;

  static const _steps = [
    'Pendiente',
    'Aceptado',
    'Preparando',
    'Listo',
    'Enviado',
    'Entregado',
  ];

  static const _icons = [
    Icons.receipt_long_outlined,
    Icons.storefront_outlined,
    Icons.soup_kitchen_outlined,
    Icons.check_circle_outline,
    Icons.delivery_dining_outlined,
    Icons.home_outlined,
  ];

  static const _messages = {
    'Pendiente': 'Recibimos tu pedido. El comercio lo está revisando.',
    'Aceptado': '¡El comercio aceptó tu pedido!',
    'Preparando': 'Están preparando tu pedido.',
    'Listo': 'Tu pedido está listo para salir.',
    'Enviado': 'Va en camino. Pronto llega.',
    'Entregado': '¡Entregado! Gracias por pedir en pedilo.',
    'Cancelado': 'Este pedido fue cancelado.',
  };

  @override
  void initState() {
    super.initState();
    _repository = ClienteRepository(
      context.read<AuthProvider>().repository.apiClient,
    );
    _load();
    _estadoSub = PedidosSocket.instance.onEstadoPedido.listen((data) {
      final ordenId = data['ordenId'] as int? ?? data['id'] as int?;
      if (ordenId == widget.pedidoId) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _estadoSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final pedido = await _repository.getPedido(widget.pedidoId);
      if (!mounted) return;
      setState(() {
        _pedido = pedido;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  Future<void> _cancelar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: const Text('¿Querés cancelar este pedido?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _repository.cancelarPedido(widget.pedidoId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  Future<void> _pedirDeNuevo() async {
    final pedido = _pedido;
    if (pedido == null) return;
    setState(() => _repeating = true);
    try {
      await _repository.repetirPedido(pedido);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agregamos los productos al carrito'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/cliente/home?tab=2');
    } catch (e) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    } finally {
      if (mounted) setState(() => _repeating = false);
    }
  }

  Future<void> _confirmarRecepcion() async {
    if (_openingRating) return;
    setState(() => _openingRating = true);
    try {
      await context.push<bool>(
        '/cliente/pedidos/${widget.pedidoId}/valorar',
      );
      await _load();
    } finally {
      if (mounted) setState(() => _openingRating = false);
    }
  }

  int _stepIndex(String status) {
    final idx = _steps.indexOf(status);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    final pedido = _pedido;
    final cancelled = pedido?.status == 'Cancelado';
    final current =
        pedido == null || cancelled ? -1 : _stepIndex(pedido.status);
    final progress =
        cancelled || current < 0 ? 0.0 : (current + 1) / _steps.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          pedido != null ? 'Pedido #${pedido.id}' : 'Seguimiento',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            )
          : pedido == null
              ? const Center(child: Text('Pedido no encontrado'))
              : RefreshIndicator(
                  color: AppColors.yellow,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pedido.comercioNombre ?? 'Comercio',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                color: AppColors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _messages[pedido.status] ?? pedido.status,
                              style: GoogleFonts.poppins(
                                color: AppColors.yellow,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: cancelled ? 0 : progress,
                                minHeight: 6,
                                backgroundColor:
                                    AppColors.white.withValues(alpha: 0.15),
                                color: AppColors.yellow,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  pedido.status,
                                  style: GoogleFonts.poppins(
                                    color: AppColors.gray400,
                                    fontSize: 12,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  pedido.totalLabel,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Estado del pedido',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._steps.asMap().entries.map((entry) {
                        final done = !cancelled && entry.key <= current;
                        final active = !cancelled && entry.key == current;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: done
                                        ? (active
                                            ? AppColors.yellow
                                            : AppColors.green)
                                        : const Color(0xFFE5E7EB),
                                    child: Icon(
                                      _icons[entry.key],
                                      size: 18,
                                      color: done
                                          ? AppColors.navy
                                          : AppColors.gray500,
                                    ),
                                  ),
                                  if (entry.key < _steps.length - 1)
                                    Container(
                                      width: 2,
                                      height: 22,
                                      color: done && entry.key < current
                                          ? AppColors.green
                                          : const Color(0xFFE5E7EB),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.value,
                                        style: GoogleFonts.poppins(
                                          fontWeight: active
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: done
                                              ? AppColors.navy
                                              : AppColors.gray500,
                                        ),
                                      ),
                                      if (active)
                                        Text(
                                          _messages[entry.value] ?? '',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: AppColors.gray500,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (pedido.items.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Items',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...pedido.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• $item',
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                      if (pedido.direccion != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Entrega: ${pedido.direccion}',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (pedido.isActive && pedido.status == 'Pendiente')
                        OutlinedButton(
                          onPressed: _cancelar,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Cancelar pedido'),
                        ),
                      if (!pedido.valorada &&
                          const {
                            'Listo',
                            'En espera',
                            'Enviado',
                            'Entregado',
                          }.contains(pedido.status)) ...[
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed:
                              _openingRating ? null : _confirmarRecepcion,
                          icon: _openingRating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.star_rounded),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.yellow,
                            foregroundColor: AppColors.navy,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          label: Text(
                            'Confirmar recepción y calificar',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      if (!pedido.isActive) ...[
                        FilledButton(
                          onPressed: _repeating ? null : _pedirDeNuevo,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.yellow,
                            foregroundColor: AppColors.navy,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _repeating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Pedir de nuevo'),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
