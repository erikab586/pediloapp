import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/open_backoffice.dart';
import '../../../core/widgets/pedilo_logo.dart';

/// Entrada pública: onboarding estilo marketplace (todos empiezan como clientes).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoMotion;
  late final Animation<double> _logoOffset;
  late final Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();
    _logoMotion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _logoOffset = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _logoMotion, curve: Curves.easeInOut),
    );
    _logoScale = Tween<double>(begin: 1, end: 1.03).animate(
      CurvedAnimation(parent: _logoMotion, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _logoMotion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Column(
        children: [
          Expanded(
            child: ColoredBox(
              color: AppColors.navy,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Motorizado como fondo: cubre todo el bloque azul (sin bandas)
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/welcome_motorizado.png',
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, 0.15),
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: AppColors.navy,
                        child: Center(
                          child: Icon(
                            Icons.delivery_dining,
                            size: 120,
                            color: AppColors.yellow,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Logo encima, misma posición de cabecera
                  SafeArea(
                    bottom: false,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: AnimatedBuilder(
                          animation: _logoMotion,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _logoOffset.value),
                              child: Transform.scale(
                                scale: _logoScale.value,
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/images/pedilo.jpg',
                                height: 32,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Image.asset(
                                  'assets/images/pedilo.jpeg',
                                  height: 32,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const PediloLogo(
                                    height: 26,
                                    textColor: AppColors.navy,
                                    useAsset: false,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Panel inferior (estilo onboarding imagen 2)
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(24, 28, 24, 16 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Lo que querés,\ncuando querés',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Comida, farmacia, súper y más.\nPedí de todos los comercios en un solo lugar.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.gray500,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 22,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppColors.yellow,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _dot(AppColors.gray400.withValues(alpha: 0.45)),
                    const SizedBox(width: 6),
                    _dot(AppColors.gray400.withValues(alpha: 0.45)),
                  ],
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: () => context.push('/register'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.yellow,
                    foregroundColor: AppColors.navy,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Comenzar',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => context.push('/login'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(color: AppColors.navy, width: 1.4),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Ya tengo cuenta',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => showAdminWebOnlyDialog(context),
                  child: Text(
                    'Administración (web)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.gray400,
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

  Widget _dot(Color color) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
