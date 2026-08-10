import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/socket_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../data/comerciante_repository.dart';

class PedidoDetailScreen extends StatefulWidget {
  const PedidoDetailScreen({
    super.key,
    required this.pedidoId,
    this.onStatusChanged,
  });

  final int pedidoId;
  final VoidCallback? onStatusChanged;

  @override
  State<PedidoDetailScreen> createState() => _PedidoDetailScreenState();
}

class _PedidoDetailScreenState extends State<PedidoDetailScreen> {
  late final ComercianteRepository _repository;
  PedidoDetailModel? _pedido;
  bool _loading = true;
  bool _updating = false;
  StreamSubscription<Map<String, dynamic>>? _estadoSub;

  @override
  void initState() {
    super.initState();
    final api = context.read<AuthProvider>().repository.apiClient;
    _repository = ComercianteRepository(api);
    _load();
    _listenEstado();
  }

  @override
  void dispose() {
    _estadoSub?.cancel();
    super.dispose();
  }

  void _listenEstado() {
    _estadoSub = PedidosSocket.instance.onEstadoPedido.listen((data) {
      final ordenId = data['ordenId'] as int? ??
          (data['orden'] as Map?)?['id'] as int?;
      if (ordenId == null || ordenId != widget.pedidoId) return;

      // Refrescamos el pedido para tener todos los datos sincronizados
      _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await _repository.getPedido(widget.pedidoId);
      if (!mounted) return;
      setState(() {
        _pedido = p;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final msg = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _updateStatus(String status) async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      await _repository.updatePedidoStatus(widget.pedidoId, status);
      widget.onStatusChanged?.call();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pedido #${widget.pedidoId} → $status'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
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
          _pedido == null
              ? 'Pedido'
              : 'Pedido #${_pedido!.id}',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.white),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            )
          : _pedido == null
              ? const Center(child: Text('Pedido no encontrado'))
              : _Body(
                  pedido: _pedido!,
                  updating: _updating,
                  onAction: _updateStatus,
                ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.pedido,
    required this.updating,
    required this.onAction,
  });

  final PedidoDetailModel pedido;
  final bool updating;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusHeader(status: pedido.status),
        const SizedBox(height: 14),
        _ClientCard(pedido: pedido),
        const SizedBox(height: 10),
        if (pedido.direccion != null) _AddressCard(pedido: pedido),
        if (pedido.direccion != null) const SizedBox(height: 10),
        _ItemsCard(pedido: pedido),
        const SizedBox(height: 10),
        _TotalsCard(pedido: pedido),
        if (pedido.motivoCancelacion != null &&
            pedido.motivoCancelacion!.isNotEmpty) ...[
          const SizedBox(height: 10),
          _CancelReasonCard(pedido: pedido),
        ],
        const SizedBox(height: 16),
        _ActionsRow(
          status: pedido.status,
          tipoEntrega: pedido.tipoEntrega,
          updating: updating,
          onAction: onAction,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            _iconForStatus(status),
            color: AppColors.yellow,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado',
                  style: GoogleFonts.poppins(
                    color: AppColors.gray400,
                    fontSize: 11,
                  ),
                ),
                Text(
                  status,
                  style: GoogleFonts.poppins(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForStatus(String s) => switch (s) {
        'Pendiente' => Icons.hourglass_empty,
        'Aceptado' || 'Preparando' => Icons.local_fire_department,
        'Listo' || 'Enviado' => Icons.check_circle_outline,
        'Entregado' => Icons.task_alt,
        'Cancelado' => Icons.cancel_outlined,
        _ => Icons.receipt_long,
      };
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.pedido});
  final PedidoDetailModel pedido;

  @override
  Widget build(BuildContext context) {
    final c = pedido.cliente;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardBox(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.yellow,
            child: Text(
              _initials(c?.name ?? 'C'),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c?.name ?? 'Cliente',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                if (c?.phone != null && c!.phone!.isNotEmpty)
                  Text(
                    c.phone!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.gray500,
                    ),
                  ),
                Text(
                  'Pedido realizado: ${_formatDate(pedido.createdAt)}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'C';
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.pedido});
  final PedidoDetailModel pedido;

  @override
  Widget build(BuildContext context) {
    final d = pedido.direccion!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardBox(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_outlined,
              color: AppColors.blue, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dirección de entrega',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.gray500,
                  ),
                ),
                if (d.oneLine.isNotEmpty)
                  Text(
                    d.oneLine,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                if (d.referencia != null && d.referencia!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      d.referencia!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.gray500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.pedido});
  final PedidoDetailModel pedido;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Items (${pedido.items.length})',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.gray600,
            ),
          ),
          const SizedBox(height: 8),
          ...pedido.items.map(
            (it) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'x${it.cantidad}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.nombre,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                        Text(
                          '\$${it.precioUnit.toStringAsFixed(0)} c/u',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    it.totalLabel,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.pedido});
  final PedidoDetailModel pedido;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardBox(),
      child: Column(
        children: [
          _row('Tipo de entrega', pedido.tipoEntrega),
          const SizedBox(height: 4),
          _row('Método de pago', pedido.metodoPago),
          const Divider(height: 18),
          _row(
            'Total',
            pedido.totalLabel,
            valueBold: true,
            color: AppColors.navy,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value,
      {bool valueBold = false, Color? color}) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.gray600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? AppColors.navy,
          ),
        ),
      ],
    );
  }
}

class _CancelReasonCard extends StatelessWidget {
  const _CancelReasonCard({required this.pedido});
  final PedidoDetailModel pedido;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFEF4444)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Motivo de cancelación',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFEF4444),
                  ),
                ),
                Text(
                  pedido.motivoCancelacion ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.status,
    required this.tipoEntrega,
    required this.updating,
    required this.onAction,
  });

  final String status;
  final String tipoEntrega;
  final bool updating;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final actions = _nextActions(status, tipoEntrega);
    if (actions.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions
          .map(
            (a) => SizedBox(
              width: actions.length == 1 ? double.infinity : null,
              child: FilledButton.icon(
                onPressed: updating ? null : () => onAction(a.status),
                style: FilledButton.styleFrom(
                  backgroundColor: a.destructive
                      ? const Color(0xFFFEE2E2)
                      : a.color,
                  foregroundColor: a.destructive
                      ? const Color(0xFFEF4444)
                      : AppColors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: a.destructive
                    ? const Icon(Icons.cancel_outlined, size: 18)
                    : null,
                label: Text(
                  a.label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  List<_ActionData> _nextActions(String status, String tipoEntrega) {
    final isDelivery = tipoEntrega.toLowerCase().contains('delivery') ||
        tipoEntrega.toLowerCase().contains('envio');

    return switch (status) {
        'Pendiente' => [
            _ActionData('Aceptar', 'Aceptado', AppColors.green),
            _ActionData('Rechazar', 'Cancelado', const Color(0xFFEF4444),
                destructive: true),
          ],
        'Aceptado' => [
            _ActionData('Marcar preparando', 'Preparando', AppColors.blue),
            _ActionData('Cancelar', 'Cancelado', const Color(0xFFEF4444),
                destructive: true),
          ],
        'Preparando' => [
            _ActionData('Marcar listo', 'Listo', AppColors.blue),
            _ActionData('Cancelar', 'Cancelado', const Color(0xFFEF4444),
                destructive: true),
          ],
        'Listo' => [
            if (isDelivery)
              _ActionData('Marcar enviado', 'Enviado', AppColors.blue),
            _ActionData('Marcar entregado', 'Entregado', AppColors.green),
          ],
        'Enviado' => [
            _ActionData('Marcar entregado', 'Entregado', AppColors.green),
          ],
        _ => [],
      };
  }
}

class _ActionData {
  const _ActionData(this.label, this.status, this.color, {this.destructive = false});
  final String label;
  final String status;
  final Color color;
  final bool destructive;
}

BoxDecoration _cardBox() => BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: AppColors.navy.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
