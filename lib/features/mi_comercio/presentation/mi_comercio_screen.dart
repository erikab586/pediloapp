import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/audio/notification_sound.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/open_backoffice.dart';
import '../../../core/widgets/panel/panel_widgets.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../cliente/data/models/catalog_models.dart';
import '../../comerciante/data/comerciante_repository.dart';

/// Gestión rápida del comercio (app). Lo completo está en el backoffice web.
class MiComercioScreen extends StatefulWidget {
  const MiComercioScreen({super.key});

  @override
  State<MiComercioScreen> createState() => _MiComercioScreenState();
}

class _MiComercioScreenState extends State<MiComercioScreen> {
  late final ComercianteRepository _repository;
  List<ComercioModel> _comercios = [];
  ComercioModel? _comercio;
  List<PedidoModel> _pedidos = [];
  bool _loading = true;
  bool _loadingPedidos = false;
  bool _togglingAbierto = false;

  StreamSubscription<Map<String, dynamic>>? _nuevoPedidoSub;
  StreamSubscription<Map<String, dynamic>>? _canceladoSub;
  StreamSubscription<Map<String, dynamic>>? _notifSub;
  StreamSubscription<Map<String, dynamic>>? _chatSub;

  static const _activos = {
    'Pendiente',
    'Aceptado',
    'Preparando',
    'Listo',
    'Enviado',
  };

  @override
  void initState() {
    super.initState();
    _repository = ComercianteRepository(
      context.read<AuthProvider>().repository.apiClient,
    );
    _loadComercios();
    _setupSocket();
  }

  @override
  void dispose() {
    _nuevoPedidoSub?.cancel();
    _canceladoSub?.cancel();
    _notifSub?.cancel();
    _chatSub?.cancel();
    super.dispose();
  }

  void _setupSocket() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    unawaited(PedidosSocket.instance.connect(
      userId: user.id,
      role: user.userRole.name,
      comercioId: _comercio?.id,
    ));

    _nuevoPedidoSub =
        PedidosSocket.instance.onNuevoPedido.listen((_) => _onPedidoEvent());
    _canceladoSub = PedidosSocket.instance.onPedidoCancelado
        .listen((_) => _onPedidoEvent());
    _notifSub = PedidosSocket.instance.onNotificacionNueva.listen((data) {
      if (!mounted) return;
      NotificationSound.play();
    });
    _chatSub = PedidosSocket.instance.onChatMensaje.listen((data) {
      if (!mounted) return;
      final raw = data['mensaje'];
      if (raw is! Map) return;
      final remitenteId = int.tryParse(raw['remitenteId']?.toString() ?? '');
      if (remitenteId != null &&
          remitenteId != context.read<AuthProvider>().user?.id) {
        NotificationSound.play();
      }
    });
  }

  void _onPedidoEvent() {
    if (!mounted) return;
    NotificationSound.play();
    _loadPedidos();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Actualizamos los pedidos'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadComercios() async {
    setState(() => _loading = true);
    try {
      final list = await _repository.getMisComercios();
      if (!mounted) return;
      setState(() {
        _comercios = list;
        _comercio = list.isNotEmpty ? list.first : null;
        _loading = false;
      });
      if (_comercio != null) {
        await _reconnectSocket();
        await _loadPedidos();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e);
    }
  }

  Future<void> _reconnectSocket() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    await PedidosSocket.instance.connect(
      userId: user.id,
      role: user.userRole.name,
      comercioId: _comercio?.id,
    );
  }

  Future<void> _loadPedidos() async {
    final c = _comercio;
    if (c == null) return;
    setState(() => _loadingPedidos = true);
    try {
      final page = await _repository.getPedidos(
        comercioId: c.id,
        limit: 40,
      );
      if (!mounted) return;
      setState(() {
        _pedidos = page.data.where((p) => _activos.contains(p.status)).toList();
        _loadingPedidos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPedidos = false);
      _showError(e);
    }
  }

  Future<void> _toggleAbierto(bool abierto) async {
    final c = _comercio;
    if (c == null || _togglingAbierto) return;
    setState(() => _togglingAbierto = true);
    try {
      final updated = await _repository.setComercioAbierto(c.id, abierto);
      if (!mounted) return;
      setState(() {
        _comercio = updated;
        _comercios =
            _comercios.map((x) => x.id == updated.id ? updated : x).toList();
        _togglingAbierto = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _togglingAbierto = false);
      _showError(e);
    }
  }

  void _showError(Object e) {
    final msg = e is ApiException ? e.message : e.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void _openPedido(int id) {
    context
        .push('/cliente/mi-comercio/pedidos/$id')
        .then((_) => _loadPedidos());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        title: Text(
          'Mi comercio',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            )
          : _comercios.isEmpty
              ? const EmptyPanelState(
                  icon: Icons.storefront_outlined,
                  title: 'Sin comercio',
                  subtitle:
                      'Registrá tu local desde Perfil → Vender en pedilo.',
                )
              : RefreshIndicator(
                  color: AppColors.yellow,
                  onRefresh: () async {
                    await _loadComercios();
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _ComercioHeader(
                        comercios: _comercios,
                        comercio: _comercio!,
                        toggling: _togglingAbierto,
                        onComercioChanged: (c) async {
                          setState(() => _comercio = c);
                          await _reconnectSocket();
                          await _loadPedidos();
                        },
                        onToggleAbierto: _toggleAbierto,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => context.push(
                          '/cliente/chat?rol=comerciante',
                        ),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Mensajes con clientes'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.navy,
                          side: const BorderSide(color: AppColors.navy),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            openBackofficeFromContext(context, from: 'app'),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Administrar comercio (web)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.navy,
                          side: const BorderSide(color: AppColors.navy),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Pedidos activos',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_loadingPedidos)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.yellow,
                            ),
                          ),
                        )
                      else if (_pedidos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: EmptyPanelState(
                            icon: Icons.receipt_long_outlined,
                            title: 'Sin pedidos activos',
                            subtitle: 'Los nuevos pedidos aparecerán aquí.',
                          ),
                        )
                      else
                        ..._pedidos.map(
                          (p) => _PedidoTile(
                            pedido: p,
                            onTap: () => _openPedido(p.id),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _ComercioHeader extends StatelessWidget {
  const _ComercioHeader({
    required this.comercios,
    required this.comercio,
    required this.toggling,
    required this.onComercioChanged,
    required this.onToggleAbierto,
  });

  final List<ComercioModel> comercios;
  final ComercioModel comercio;
  final bool toggling;
  final ValueChanged<ComercioModel> onComercioChanged;
  final ValueChanged<bool> onToggleAbierto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (comercios.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<ComercioModel>(
                value: comercio,
                dropdownColor: AppColors.navyLight,
                style: GoogleFonts.poppins(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Local',
                  labelStyle: GoogleFonts.poppins(color: AppColors.gray400),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: AppColors.white.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: comercios
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.name),
                      ),
                    )
                    .toList(),
                onChanged: (c) {
                  if (c != null) onComercioChanged(c);
                },
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comercio.name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      comercio.estatus ?? '—',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.gray400,
                      ),
                    ),
                  ],
                ),
              ),
              if (toggling)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.yellow,
                  ),
                )
              else
                Switch(
                  value: comercio.estaAbierto,
                  activeThumbColor: AppColors.yellow,
                  onChanged: onToggleAbierto,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            comercio.estaAbierto ? 'Abierto — recibiendo pedidos' : 'Cerrado',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: comercio.estaAbierto ? AppColors.green : AppColors.gray400,
            ),
          ),
        ],
      ),
    );
  }
}

class _PedidoTile extends StatelessWidget {
  const _PedidoTile({required this.pedido, required this.onTap});

  final PedidoModel pedido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        title: Text(
          'Pedido #${pedido.id}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${pedido.clienteNombre ?? 'Cliente'} · ${pedido.status}',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.gray600),
        ),
        trailing: Text(
          '\$${pedido.total.toStringAsFixed(0)}',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
      ),
    );
  }
}
