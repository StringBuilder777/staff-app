import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/dot_matrix.dart';
import '../theme/motion.dart';
import '../theme/nothing.dart';

/// Acceso del staff con correo y contraseña.
///
/// No hay registro ni recuperación a propósito: las cuentas las crea
/// coordinación en Supabase → Authentication, y el día del evento la pantalla
/// debe resolverse en un solo paso. La sesión la persiste `supabase_flutter`,
/// así que solo se pide una vez por teléfono.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Escribe tu correo y tu contraseña.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // No hace falta navegar: el AuthGate escucha el cambio de sesión y entra.
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'No se pudo conectar. Revisa tu conexión a internet.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Nothing.gutter,
          40,
          Nothing.gutter,
          Nothing.gutter,
        ),
        children: [
          const Reveal(
            child: DotText('STAFF', dot: 5, gap: 3, motion: DotMotion.reveal),
          ),
          const SizedBox(height: 44),
          const Reveal(step: 1, child: SectionLabel('01', 'Acceso')),
          const SizedBox(height: 18),
          Reveal(
            step: 1,
            child: Text('ACCESO\nDE STAFF', style: Nothing.display(44)),
          ),
          const SizedBox(height: 16),
          const Reveal(
            step: 2,
            child: Text(
              'Entra con tu cuenta para registrar accesos.',
              style: Nothing.body,
            ),
          ),
          const SizedBox(height: 40),
          Reveal(
            step: 3,
            child: UnderlineField(
              label: 'Correo',
              controller: _emailController,
              enabled: !_isSubmitting,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: 28),
          Reveal(
            step: 3,
            child: UnderlineField(
              label: 'Contraseña',
              controller: _passwordController,
              enabled: !_isSubmitting,
              obscure: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _isSubmitting ? null : _signIn(),
              suffix: IconButton(
                iconSize: 20,
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Nothing.muted,
                ),
                tooltip: _obscurePassword
                    ? 'Mostrar contraseña'
                    : 'Ocultar contraseña',
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 28),
            Notice(message: _errorMessage!, danger: true),
          ],
          const SizedBox(height: 40),
          Reveal(
            step: 4,
            child: PrimaryAction(
              label: _isSubmitting ? 'Entrando' : 'Entrar',
              busy: _isSubmitting,
              onPressed: _signIn,
            ),
          ),
          const SizedBox(height: 28),
          const Reveal(
            step: 4,
            child: Text(
              'Si no tienes cuenta, pídesela a coordinación.',
              style: Nothing.body,
            ),
          ),
          const SizedBox(height: 40),
          const Reveal(
            step: 4,
            child: DotField(columns: 14, rows: 3, dot: 3, gap: 8),
          ),
        ],
      ),
    ),
  );
}
