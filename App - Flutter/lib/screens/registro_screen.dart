import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pillbox/componentes/botones_principales.dart';
import 'package:pillbox/componentes/textos.dart';
import 'package:pillbox/componentes/textfield.dart';
import 'package:pillbox/core/colores.dart';
import 'home_screen.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({Key? key}) : super(key: key);

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final nombreController = TextEditingController();
  final emailController  = TextEditingController();
  final passController   = TextEditingController();

  bool _loading = false;

  Future<void> registrarUsuario() async {
    final email = emailController.text.trim().toLowerCase();
    final pass  = passController.text.trim();
    final nombre= nombreController.text.trim();

    if (email.isEmpty || pass.isEmpty || nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa nombre, email y contraseña')),
      );
      return;
    }
    if (pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // 👉 Crear usuario en AUTH (si el mail ya existe, cae al catch con code email-already-in-use)
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );
      final uid = cred.user!.uid;

      // Guardar datos de registro en Firestore
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'displayName': nombre,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String msg = 'Error al registrarse';
      if (e.code == 'email-already-in-use') {
        msg = 'El email ya está registrado';
      } else if (e.code == 'invalid-email') {
        msg = 'Email inválido';
      } else if (e.code == 'weak-password') {
        msg = 'La contraseña es muy débil';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
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
            TextoDeRegistro(),
            RegistroInputs(
              nombreController: nombreController,
              emailController: emailController,
              passController: passController,
            ),
            FinalizarRegistro(
              onPressed: _loading ? null : registrarUsuario,
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
