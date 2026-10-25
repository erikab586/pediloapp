import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalScaffold(
      title: 'Privacidad',
      children: const [
        _P(
          'pedilo (“la App”) trata datos personales para operar el marketplace '
          'de pedidos multi-rubro.',
        ),
        _H('Qué datos tratamos'),
        _P(
          'Cuenta (nombre, email, teléfono), direcciones de entrega, pedidos, '
          'preferencias (favoritos) y, si sos comerciante, datos del local.',
        ),
        _H('Para qué'),
        _P(
          'Autenticación, procesamiento de pedidos, soporte, mejora del '
          'servicio y cumplimiento legal. No vendemos tus datos.',
        ),
        _H('Ubicación'),
        _P(
          'Usamos la dirección que cargás para estimar disponibilidad y entrega. '
          'No pedimos GPS continuo en esta versión.',
        ),
        _H('Contacto'),
        _P('Consultas de privacidad: soporte@pedilo.app (reemplazar por email real).'),
      ],
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalScaffold(
      title: 'Términos',
      children: const [
        _P(
          'Al usar pedilo aceptás estos términos. La App conecta clientes con '
          'comercios; el contrato de compra es entre vos y el comercio.',
        ),
        _H('Pedidos y pagos'),
        _P(
          'Los precios, stock y tiempos los define cada comercio. pedilo puede '
          'mostrar totales estimados; el comercio confirma el pedido.',
        ),
        _H('Cuentas'),
        _P(
          'Sos responsable de tu contraseña. Podés solicitar baja de cuenta '
          'contactando soporte.',
        ),
        _H('Comerciantes'),
        _P(
          'Al registrar un local aceptás la revisión de aprobación y las reglas '
          'de la plataforma.',
        ),
      ],
    );
  }
}

class _LegalScaffold extends StatelessWidget {
  const _LegalScaffold({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: children,
      ),
    );
  }
}

class _H extends StatelessWidget {
  const _H(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
    );
  }
}

class _P extends StatelessWidget {
  const _P(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        height: 1.45,
        color: AppColors.gray600,
      ),
    );
  }
}
