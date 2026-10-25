import '../../../core/network/api_client.dart';
import '../../../core/utils/json_parse.dart';

class ChatMensajeModel {
  const ChatMensajeModel({
    required this.id,
    required this.conversacionId,
    required this.remitenteId,
    required this.mensaje,
    required this.leido,
    required this.createdAt,
    this.remitenteNombre,
  });

  factory ChatMensajeModel.fromJson(Map<String, dynamic> json) {
    final remitente = parseJsonMap(json['remitente']);
    return ChatMensajeModel(
      id: parseJsonInt(json['id']),
      conversacionId: parseJsonInt(json['conversacionId']),
      remitenteId: parseJsonInt(json['remitenteId']),
      mensaje: json['mensaje'] as String? ?? '',
      leido: parseJsonBool(json['leido']),
      createdAt: json['createdAt']?.toString() ?? '',
      remitenteNombre: remitente?['name'] as String?,
    );
  }

  final int id;
  final int conversacionId;
  final int remitenteId;
  final String mensaje;
  final bool leido;
  final String createdAt;
  final String? remitenteNombre;
}

class ChatConversacionModel {
  const ChatConversacionModel({
    required this.id,
    required this.clienteId,
    required this.comercioId,
    this.ordenId,
    this.noLeidos = 0,
    this.ultimoMensajeAt,
    this.ultimoMensaje,
    this.clienteNombre,
    this.comercioNombre,
    this.comercioLogo,
  });

  factory ChatConversacionModel.fromJson(Map<String, dynamic> json) {
    final cliente = parseJsonMap(json['cliente']);
    final comercio = parseJsonMap(json['comercio']);
    final last = parseJsonMap(json['ultimoMensaje']);
    return ChatConversacionModel(
      id: parseJsonInt(json['id']),
      clienteId: parseJsonInt(json['clienteId']),
      comercioId: parseJsonInt(json['comercioId']),
      ordenId:
          json['ordenId'] != null ? parseJsonInt(json['ordenId']) : null,
      noLeidos: parseJsonInt(json['noLeidos']),
      ultimoMensajeAt: json['ultimoMensajeAt']?.toString(),
      ultimoMensaje:
          last != null ? ChatMensajeModel.fromJson(last) : null,
      clienteNombre: cliente?['name'] as String?,
      comercioNombre: comercio?['name'] as String?,
      comercioLogo: comercio?['logo'] as String?,
    );
  }

  final int id;
  final int clienteId;
  final int comercioId;
  final int? ordenId;
  final int noLeidos;
  final String? ultimoMensajeAt;
  final ChatMensajeModel? ultimoMensaje;
  final String? clienteNombre;
  final String? comercioNombre;
  final String? comercioLogo;

  String tituloPara({required bool soyCliente}) =>
      soyCliente ? (comercioNombre ?? 'Comercio') : (clienteNombre ?? 'Cliente');
}

class ChatRepository {
  ChatRepository(this._api);

  final ApiClient _api;

  Future<ChatConversacionModel> abrir({
    required int comercioId,
    int? ordenId,
  }) async {
    final json = await _api.post(
      '/chat/abrir',
      authenticated: true,
      body: {
        'comercioId': comercioId,
        if (ordenId != null) 'ordenId': ordenId,
      },
    );
    return ChatConversacionModel.fromJson(json);
  }

  Future<List<ChatConversacionModel>> listConversaciones() async {
    final rows =
        await _api.getList('/chat/conversaciones', authenticated: true);
    return rows.map(ChatConversacionModel.fromJson).toList();
  }

  Future<List<ChatMensajeModel>> listMensajes(int conversacionId) async {
    final json = await _api.get(
      '/chat/conversaciones/$conversacionId/mensajes',
      authenticated: true,
      queryParameters: {'limit': '100'},
    );
    final data = json['data'];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => ChatMensajeModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ChatMensajeModel> enviar({
    required int conversacionId,
    required String mensaje,
  }) async {
    final json = await _api.post(
      '/chat/mensajes',
      authenticated: true,
      body: {
        'conversacionId': conversacionId,
        'mensaje': mensaje,
      },
    );
    return ChatMensajeModel.fromJson(json);
  }

  Future<void> marcarLeidos(int conversacionId) async {
    await _api.patch(
      '/chat/conversaciones/$conversacionId/leer',
      authenticated: true,
    );
  }
}
