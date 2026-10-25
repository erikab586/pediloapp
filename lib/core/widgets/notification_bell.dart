import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../network/api_client.dart';
import '../network/socket_service.dart';
import '../theme/app_colors.dart';
import '../../features/auth/presentation/auth_provider.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({
    super.key,
    this.onOpenNotification,
  });

  final ValueChanged<Map<String, dynamic>>? onOpenNotification;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  late final ApiClient _api;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _api = context.read<AuthProvider>().repository.apiClient;
    _subscription =
        PedidosSocket.instance.onNotificacionNueva.listen((_) => _refreshCount());
    unawaited(_refreshCount());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshCount() async {
    try {
      final result = await _api.get(
        '/notificaciones/unread-count',
        authenticated: true,
      );
      if (!mounted) return;
      setState(() => _unreadCount = int.tryParse(
            result['total']?.toString() ?? '',
          ) ??
          0);
    } catch (error) {
      debugPrint('No se pudo actualizar el contador de notificaciones: $error');
    }
  }

  Future<void> _openNotifications() async {
    try {
      final notifications = await _api.getList(
        '/notificaciones',
        authenticated: true,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Notificaciones',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: notifications.isEmpty
                      ? Center(
                          child: Text(
                            'No tenés notificaciones',
                            style: GoogleFonts.poppins(
                              color: AppColors.gray500,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: notifications.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 72),
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            final unread = notification['leida'] != true;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: unread
                                    ? AppColors.yellow.withValues(alpha: 0.35)
                                    : const Color(0xFFF3F4F6),
                                child: Icon(
                                  notification['tipo'] == 'chat_mensaje'
                                      ? Icons.chat_bubble_outline
                                      : Icons.notifications_none_rounded,
                                  color: AppColors.navy,
                                ),
                              ),
                              title: Text(
                                notification['titulo']?.toString() ??
                                    'Notificación',
                                style: GoogleFonts.poppins(
                                  fontWeight: unread
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: AppColors.navy,
                                ),
                              ),
                              subtitle: Text(
                                notification['mensaje']?.toString() ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.gray500,
                                ),
                              ),
                              trailing: unread
                                  ? const Icon(
                                      Icons.circle,
                                      size: 9,
                                      color: AppColors.blue,
                                    )
                                  : null,
                              onTap: () =>
                                  _selectNotification(sheetContext, notification),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudieron cargar las notificaciones: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _selectNotification(
    BuildContext sheetContext,
    Map<String, dynamic> notification,
  ) async {
    final id = int.tryParse(notification['id']?.toString() ?? '');
    final unread = notification['leida'] != true;
    if (unread && id != null) {
      try {
        await _api.patch(
          '/notificaciones/$id/leida',
          authenticated: true,
        );
        if (mounted) {
          setState(() => _unreadCount = (_unreadCount - 1).clamp(0, 9999));
        }
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo marcar como leída: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    if (!sheetContext.mounted) return;
    Navigator.pop(sheetContext);
    final handler = widget.onOpenNotification;
    if (handler != null) {
      handler(notification);
    } else if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(notification['titulo']?.toString() ?? 'Notificación'),
          content: Text(notification['mensaje']?.toString() ?? ''),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final badge = _unreadCount > 99 ? '99+' : '$_unreadCount';
    return IconButton(
      tooltip: 'Notificaciones',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      onPressed: _openNotifications,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.navy,
            size: 22,
          ),
          if (_unreadCount > 0)
            Positioned(
              top: -7,
              right: -10,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.poppins(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
