import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../data/chat_repository.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key, this.soyCliente = true});

  final bool soyCliente;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late final ChatRepository _repo;
  List<ChatConversacionModel> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = ChatRepository(context.read<AuthProvider>().repository.apiClient);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _repo.listConversaciones();
      if (!mounted) return;
      setState(() {
        _items = rows;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        title: Text(
          'Mensajes',
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
              child: _items.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Text(
                            'Todavía no tenés conversaciones',
                            style: GoogleFonts.poppins(
                              color: AppColors.gray500,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final c = _items[i];
                        final title = c.tituloPara(
                          soyCliente: widget.soyCliente,
                        );
                        final preview = c.ultimoMensaje?.mensaje ?? 'Sin mensajes';
                        return Material(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.yellow.withValues(alpha: 0.35),
                              child: Text(
                                title.isNotEmpty
                                    ? title[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                            title: Text(
                              title,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            trailing: c.noLeidos > 0
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.yellow,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      '${c.noLeidos}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                                : null,
                            onTap: () async {
                              await context.push(
                                '/cliente/chat/${c.id}',
                                extra: {
                                  'titulo': title,
                                  'soyCliente': widget.soyCliente,
                                },
                              );
                              _load();
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
