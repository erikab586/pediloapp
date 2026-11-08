import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import 'auth_provider.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key, this.token});

  final String? token;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _message;
  String? _error;

  bool get _hasToken => widget.token?.isNotEmpty == true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      final repository = context.read<AuthProvider>().repository;
      if (_hasToken) {
        await repository.resetPassword(
          token: widget.token!,
          password: _passwordController.text,
        );
        if (!mounted) return;
        setState(() {
          _message = 'Contraseña actualizada. Ya podés iniciar sesión.';
        });
      } else {
        await repository.requestPasswordReset(_emailController.text);
        if (!mounted) return;
        setState(() {
          _message =
              'Si el correo está registrado, recibirás instrucciones para restablecer tu contraseña.';
        });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo completar la solicitud. Intentá nuevamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _hasToken ? 'Nueva contraseña' : 'Recuperar contraseña';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _hasToken
                        ? 'Elegí una contraseña nueva para tu cuenta.'
                        : 'Ingresá tu correo y te enviaremos un enlace de un solo uso.',
                  ),
                  const SizedBox(height: 20),
                  if (!_hasToken)
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          const InputDecoration(labelText: 'Correo electrónico'),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        return email.contains('@')
                            ? null
                            : 'Ingresá un correo válido';
                      },
                    )
                  else ...[
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'Nueva contraseña'),
                      validator: (value) => (value?.length ?? 0) >= 8
                          ? null
                          : 'Usá al menos 8 caracteres',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar contraseña',
                      ),
                      validator: (value) =>
                          value == _passwordController.text
                              ? null
                              : 'Las contraseñas no coinciden',
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(_message!),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading || _message != null ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_hasToken ? 'Guardar contraseña' : 'Enviar enlace'),
                  ),
                  if (_hasToken && _message != null)
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Volver a iniciar sesión'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
