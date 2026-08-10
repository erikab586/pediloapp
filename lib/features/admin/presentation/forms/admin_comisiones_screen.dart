import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../data/admin_repository.dart';

class AdminComisionesScreen extends StatefulWidget {
  const AdminComisionesScreen({super.key, required this.repository});

  final AdminRepository repository;

  @override
  State<AdminComisionesScreen> createState() => _AdminComisionesScreenState();
}

class _AdminComisionesScreenState extends State<AdminComisionesScreen> {
  GlobalStatsModel? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final stats = await widget.repository.getGlobalStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ventas = _stats?.ventasTotales ?? 0;
    final comision = ventas * kAdminComisionPorcentaje / 100;
    final pedidos = _stats?.pedidosTotales ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        title: Text(
          'Comisiones',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            )
          : RefreshIndicator(
              color: AppColors.yellow,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Comisión de plataforma',
                          style: GoogleFonts.poppins(
                            color: AppColors.gray400,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${kAdminComisionPorcentaje.toStringAsFixed(0)}%',
                          style: GoogleFonts.poppins(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: AppColors.yellow,
                          ),
                        ),
                        Text(
                          'por cada venta completada',
                          style: GoogleFonts.poppins(
                            color: AppColors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SummaryRow(
                    label: 'Ventas totales acumuladas',
                    value: '\$${ventas.toStringAsFixed(0)}',
                  ),
                  _SummaryRow(
                    label: 'Comisiones generadas',
                    value: '\$${comision.toStringAsFixed(0)}',
                    highlight: true,
                  ),
                  _SummaryRow(
                    label: 'Pedidos completados',
                    value: '$pedidos',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'El porcentaje de comisión es un parámetro de plataforma. '
                      'Contactá al equipo técnico para modificarlo en producción.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.gray500,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.yellow.withValues(alpha: 0.2)
            : AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: AppColors.navy,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: highlight ? AppColors.green : AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}
