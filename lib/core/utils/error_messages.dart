import 'package:flutter/material.dart';

import '../network/api_exception.dart';

String mensajeErrorEspanol(Object error) {
  final raw = error is ApiException ? error.message : error.toString();
  final msg = raw.toLowerCase();

  if (msg.contains('401') || msg.contains('unauthorized')) {
    return 'Tu sesión expiró. Volvé a iniciar sesión.';
  }
  if (msg.contains('403') || msg.contains('forbidden')) {
    return 'No tenés permiso para realizar esta acción.';
  }
  if (msg.contains('404') ||
      msg.contains('not found') ||
      msg.contains('no encontrado')) {
    return 'No se encontró el recurso solicitado.';
  }
  if (msg.contains('internal server error') ||
      msg.contains('error del servidor (500)')) {
    return 'Error interno del servidor. Verificá que la API en el hosting '
        'esté actualizada y que las migraciones de base de datos estén aplicadas.';
  }
  if (msg.contains('network') ||
      msg.contains('socket') ||
      msg.contains('failed host')) {
    return 'No hay conexión con el servidor. Revisá tu internet.';
  }
  if (msg.contains('cloudinary') ||
      msg.contains('upload') ||
      msg.contains('imagen')) {
    return 'No se pudo subir la imagen. Probá con otra foto o más tarde.';
  }
  if (msg.contains('categoriaid') || msg.contains('categoría')) {
    return 'Seleccioná una categoría válida.';
  }
  if (msg.contains('name') && msg.contains('empty')) {
    return 'El nombre del comercio es obligatorio.';
  }

  return raw.isNotEmpty
      ? raw
      : 'Ocurrió un error inesperado. Intentá de nuevo.';
}

Future<void> mostrarAlertaError(
  BuildContext context, {
  required String mensaje,
  String titulo = 'Error',
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}
