import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

class PedidoSuccessScreen extends StatelessWidget {
  const PedidoSuccessScreen({
    super.key,
    required this.pedidoId,
    this.comercioNombre,
    this.total,
    this.tipoEntrega,
  });

  final int pedidoId;
  final String? comercioNombre;
  final double? total;
  final String? tipoEntrega;

  @override
  Widget build(BuildContext context) {
    final eta = (tipoEntrega ?? '').toLowerCase().contains('delivery')
        ? '25-40 min'
        : '15-25 min (retiro)';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: AppColors.yellow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 56,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '¡Pedido confirmado!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu pedido se envió al local. Te avisamos cuando cambie el estado.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.gray500,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    _InfoRow(label: 'Pedido', value: '#$pedidoId'),
                    if (comercioNombre != null && comercioNombre!.isNotEmpty)
                      _InfoRow(label: 'Local', value: comercioNombre!),
                    _InfoRow(label: 'Tiempo estimado', value: eta),
                    if (total != null)
                      _InfoRow(
                        label: 'Total',
                        value: '\$${total!.toStringAsFixed(0)}',
                        emphasize: true,
                      ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      context.go('/cliente/pedidos/$pedidoId/tracking'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.yellow,
                    foregroundColor: AppColors.navy,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Seguir pedido',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => context.go('/cliente/home'),
                child: Text(
                  'Volver al inicio',
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
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.gray500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
              color: emphasize ? AppColors.green : AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}
