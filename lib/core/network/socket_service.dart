import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';
import '../storage/token_storage.dart';

/// Conecta al namespace `/pedidos` de Socket.IO y expone los eventos
/// como [Stream]s para que las pantallas reaccionen en tiempo real.
///
/// Eventos soportados (ver `pedidos.gateway.ts` del backend):
/// - `nuevo_pedido`        → llega al room `comercio:{id}`
/// - `estado_pedido`       → llega al room `user:{userId}`
/// - `pedido_cancelado`    → llega al room `comercio:{id}`
/// - `comercio_estado`     → broadcast a todos
/// - `promo_nueva`         → broadcast a todos
class PedidosSocket {
  PedidosSocket._();

  static final PedidosSocket instance = PedidosSocket._();

  io.Socket? _socket;
  final TokenStorage _storage = TokenStorage();

  final _nuevoPedido = StreamController<Map<String, dynamic>>.broadcast();
  final _estadoPedido = StreamController<Map<String, dynamic>>.broadcast();
  final _pedidoCancelado = StreamController<Map<String, dynamic>>.broadcast();
  final _comercioEstado = StreamController<Map<String, dynamic>>.broadcast();
  final _promoNueva = StreamController<Map<String, dynamic>>.broadcast();
  final _connection = StreamController<SocketConnection>.broadcast();

  Stream<Map<String, dynamic>> get onNuevoPedido => _nuevoPedido.stream;
  Stream<Map<String, dynamic>> get onEstadoPedido => _estadoPedido.stream;
  Stream<Map<String, dynamic>> get onPedidoCancelado =>
      _pedidoCancelado.stream;
  Stream<Map<String, dynamic>> get onComercioEstado => _comercioEstado.stream;
  Stream<Map<String, dynamic>> get onPromoNueva => _promoNueva.stream;
  Stream<SocketConnection> get onConnectionChange => _connection.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Conecta al namespace de pedidos. Si ya está conectado, primero
  /// desconecta para refrescar el token y los query params.
  Future<void> connect({
    required int userId,
    required String role,
    int? comercioId,
  }) async {
    await disconnect();

    final token = await _storage.readAccessToken();

    _socket = io.io(
      '${ApiConfig.host}/pedidos',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(20)
          .disableAutoConnect()
          .setQuery({
            'userId': '$userId',
            'role': role,
            if (comercioId != null) 'comercioId': '$comercioId',
            if (token != null) 'token': token,
          })
          .build(),
    );

    _socket!
      ..onConnect((_) {
        if (kDebugMode) {
          debugPrint('[socket] conectado');
        }
        _connection.add(SocketConnection.connected);
      })
      ..onDisconnect((_) {
        if (kDebugMode) {
          debugPrint('[socket] desconectado');
        }
        _connection.add(SocketConnection.disconnected);
      })
      ..onConnectError((err) {
        if (kDebugMode) {
          debugPrint('[socket] error de conexión: $err');
        }
        _connection.add(SocketConnection.disconnected);
      })
      ..on('nuevo_pedido', (data) {
        if (data is Map) {
          _nuevoPedido.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('estado_pedido', (data) {
        if (data is Map) {
          _estadoPedido.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('pedido_cancelado', (data) {
        if (data is Map) {
          _pedidoCancelado.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('comercio_estado', (data) {
        if (data is Map) {
          _comercioEstado.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('promo_nueva', (data) {
        if (data is Map) {
          _promoNueva.add(Map<String, dynamic>.from(data));
        }
      });

    _socket!.connect();
  }

  Future<void> disconnect() async {
    _socket?.dispose();
    _socket = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _nuevoPedido.close();
    await _estadoPedido.close();
    await _pedidoCancelado.close();
    await _comercioEstado.close();
    await _promoNueva.close();
    await _connection.close();
  }
}

enum SocketConnection { connected, disconnected }
