import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/backoffice_config.dart';

Future<bool> openBackoffice({
  String from = 'app',
  bool login = true,
}) async {
  final url = login ? BackofficeConfig.loginUrl(from: from) : BackofficeConfig.webUrl;
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}

Future<void> openBackofficeFromContext(
  BuildContext context, {
  String from = 'app',
  bool login = true,
}) async {
  final ok = await openBackoffice(from: from, login: login);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No se pudo abrir el backoffice. Verificá BACKOFFICE_WEB_URL.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

Future<void> showAdminWebOnlyDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Administración en la web'),
      content: const Text(
        'La administración de Pedilo se realiza desde el backoffice web. '
        'La app móvil es para clientes y gestión rápida de comercios.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await openBackofficeFromContext(context, from: 'app_admin');
          },
          child: const Text('Abrir backoffice'),
        ),
      ],
    ),
  );
}
