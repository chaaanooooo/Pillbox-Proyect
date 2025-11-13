import 'package:flutter/material.dart';
import 'package:pillbox/componentes/botones_principales.dart';
import 'package:pillbox/componentes/textfield.dart';
import 'package:pillbox/componentes/textos.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pillbox/core/colores.dart';
import 'package:pillbox/screens/home_screen.dart';

class InicioSesion extends StatefulWidget {
  const InicioSesion({super.key});
  @override
  State<InicioSesion> createState() => _InicioSesionState();
}

class _InicioSesionState extends State<InicioSesion> {
  final emailController = TextEditingController();
  final passController = TextEditingController();
  // ignore: unused_field
  bool _loading = false;

  Future<void> _login() async {

    //guarda las credenciales
    final email = emailController.text.trim();
    final pass  = passController.text.trim();

    print("email: $email, pass: $pass");

    //Si una credencial está vacía, le recuerda al usuario y no hace nada
    if (email.isEmpty || pass.isEmpty) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completá email y contraseña.')),
      );

      return;
    }

    //Cambia el estado a cargando
    setState(() => _loading = true);

    //intenta loguear
    try {

      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: pass);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );

    } on FirebaseAuthException catch (e) {

      // Mostrá el code para saber exactamente qué pasa
      final msg = _humanizeAuthError(e.code);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$msg (code: ${e.code})')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: $e')),
      );
    }

  }

  String _humanizeAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'El email no tiene un formato válido.';
      case 'user-not-found':
        return 'No existe un usuario con ese email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email o contraseña incorrectos.';
      case 'too-many-requests':
        return 'Demasiados intentos. Probá más tarde.';
      case 'operation-not-allowed':
        return 'Método Email/Password deshabilitado en Firebase.';
      default:
        return 'Error de autenticación';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.prueba2,
      body: SafeArea(
        child: Column(
          children: [
            VolverButton(),
            TextoDeInicioSesion(),
            InicioSesionInputs(
              emailController: emailController,
              passController: passController
            ),
            FinalizarRegistro(onPressed: _login),
            TextButton(
              onPressed: () => showDialog(
              context: context,
              builder: (_) => const _ResetPasswordDialog(),
              ),
              child: const Text('¿Olvidaste tu contraseña?'),
              ),
          ],
        )
        ),
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog();

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _emailCtrl = TextEditingController();
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Recuperar contraseña'),
      content: TextField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Email'),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _sending ? null : _sendReset,
          child: Text(_sending ? 'Enviando...' : 'Enviar'),
        ),
      ],
    );
  }

  Future<void> _sendReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá tu email.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (mounted) {
        Navigator.pop(context); // cerrar el diálogo
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
            'Si el email está registrado, recibirás un enlace para resetear tu contraseña.',
          )),
        );
      }
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'invalid-email' => 'El email no es válido.',
        'user-not-found' => 'Si el email está registrado, te enviaremos un enlace.',
        'too-many-requests' => 'Demasiados intentos, probá más tarde.',
        _ => 'No se pudo enviar el email.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}