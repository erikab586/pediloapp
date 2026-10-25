import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/socket_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../data/chat_repository.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.conversacionId,
    required this.titulo,
    this.soyCliente = true,
  });

  final int conversacionId;
  final String titulo;
  final bool soyCliente;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  late final ChatRepository _repo;
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMensajeModel> _mensajes = [];
  bool _loading = true;
  bool _sending = false;
  StreamSubscription<Map<String, dynamic>>? _sub;
  int? _myUserId;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _repo = ChatRepository(auth.repository.apiClient);
    _myUserId = auth.user?.id;
    PedidosSocket.instance.joinConversacion(widget.conversacionId);
    _sub = PedidosSocket.instance.onChatMensaje.listen(_onSocketMessage);
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    PedidosSocket.instance.leaveConversacion(widget.conversacionId);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSocketMessage(Map<String, dynamic> data) {
    final convId = data['conversacionId'];
    if (convId != null && parseIntSafe(convId) != widget.conversacionId) {
      return;
    }
    final raw = data['mensaje'];
    if (raw is! Map) return;
    final msg = ChatMensajeModel.fromJson(Map<String, dynamic>.from(raw));
    if (_mensajes.any((m) => m.id == msg.id)) return;
    setState(() => _mensajes = [..._mensajes, msg]);
    _scrollToEnd();
  }

  int parseIntSafe(dynamic v) =>
      int.tryParse(v?.toString() ?? '') ?? -1;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _repo.listMensajes(widget.conversacionId);
      await _repo.marcarLeidos(widget.conversacionId);
      if (!mounted) return;
      setState(() {
        _mensajes = rows;
        _loading = false;
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final msg = await _repo.enviar(
        conversacionId: widget.conversacionId,
        mensaje: text,
      );
      _ctrl.clear();
      if (!mounted) return;
      if (!_mensajes.any((m) => m.id == msg.id)) {
        setState(() => _mensajes = [..._mensajes, msg]);
      }
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        title: Text(
          widget.titulo,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.yellow),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: _mensajes.length,
                    itemBuilder: (context, i) {
                      final m = _mensajes[i];
                      final mine = m.remitenteId == _myUserId;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                          ),
                          decoration: BoxDecoration(
                            color: mine
                                ? AppColors.yellow
                                : AppColors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(14),
                              topRight: const Radius.circular(14),
                              bottomLeft: Radius.circular(mine ? 14 : 4),
                              bottomRight: Radius.circular(mine ? 4 : 14),
                            ),
                          ),
                          child: Text(
                            m.mensaje,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppColors.navy,
                              height: 1.35,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            color: AppColors.white,
            padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottom),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Escribí un mensaje…',
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: AppColors.yellow,
                  ),
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
