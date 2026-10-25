import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/panel/panel_widgets.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../cliente/data/models/catalog_models.dart';
import '../../data/comerciante_repository.dart';

class PromocionesListScreen extends StatefulWidget {
  const PromocionesListScreen({super.key, required this.comercio});

  final ComercioModel comercio;

  @override
  State<PromocionesListScreen> createState() => _PromocionesListScreenState();
}

class _PromocionesListScreenState extends State<PromocionesListScreen> {
  late final ComercianteRepository _repository;
  List<PromocionModel> _promos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final api = context.read<AuthProvider>().repository.apiClient;
    _repository = ComercianteRepository(api);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _repository.getPromociones(widget.comercio.id);
      if (!mounted) return;
      setState(() {
        _promos = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e);
    }
  }

  void _showError(Object e) {
    final msg = e is ApiException ? e.message : e.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openForm() async {
    final result = await context.push<bool>(
      '/comerciante/promociones/form',
      extra: widget.comercio,
    );
    if (result == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        title: Text(
          'Promociones',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Nueva promo',
            onPressed: _openForm,
            icon: const Icon(Icons.add_circle, color: AppColors.yellow),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            )
          : _promos.isEmpty
              ? const EmptyPanelState(
                  icon: Icons.percent,
                  title: 'Sin promociones',
                  subtitle:
                      'Creá descuentos % , monto fijo o 2x1 para atraer clientes.',
                )
              : RefreshIndicator(
                  color: AppColors.yellow,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _promos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final promo = _promos[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.yellow,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                promo.badgeLabel,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
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
                                    promo.nombre,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  Text(
                                    promo.descripcion?.isNotEmpty == true
                                        ? promo.descripcion!
                                        : promo.valorLabel,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.gray500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!promo.activo)
                              Text(
                                'Inactiva',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.gray400,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
