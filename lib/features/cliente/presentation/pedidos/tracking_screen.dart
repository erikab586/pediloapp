import 'dart:async';

import 'package:flutter/material.dart';
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
  StreamSubscription<Map<String, dynamic>>? _estadoSub;

  static const _steps = [
    'Pendiente',
    'Aceptado',
    'Preparando',
    'Listo',
    'Enviado',
    'Entregado',
  ];

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

  int _stepIndex(String status) {
    final idx = _steps.indexOf(status);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    final pedido = _pedido;

    return Scaffold(
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pedido.comercioNombre ?? 'Comercio',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            Text(
                              pedido.status,
                              style: GoogleFonts.poppins(
                                color: AppColors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              pedido.totalLabel,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
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
                        final current = _stepIndex(pedido.status);
                        final done = entry.key <= current;
                        final active = entry.key == current;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: done
                                    ? (active
                                        ? AppColors.yellow
                                        : AppColors.green)
                                    : AppColors.gray400.withValues(alpha: 0.3),
                                child: Icon(
                                  done ? Icons.check : Icons.circle,
                                  size: 14,
                                  color: AppColors.navy,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                entry.value,
                                style: GoogleFonts.poppins(
                                  fontWeight:
                                      active ? FontWeight.w700 : FontWeight.w500,
                                  color: done
                                      ? AppColors.navy
                                      : AppColors.gray500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (pedido.items.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Items',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        ...pedido.items.map(
                          (item) => Text(
                            '• $item',
                            style: GoogleFonts.poppins(fontSize: 13),
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
                      if (pedido.isActive &&
                          pedido.status == 'Pendiente') ...[
                        const SizedBox(height: 24),
                        OutlinedButton(
                          onPressed: _cancelar,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                          ),
                          child: const Text('Cancelar pedido'),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
