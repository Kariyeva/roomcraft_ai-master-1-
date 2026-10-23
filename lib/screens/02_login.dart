// ignore_for_file: file_names
import 'package:flutter/material.dart';
import '../widgets/studio_components.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '03_mode_select.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  FirebaseAuth get _auth => FirebaseAuth.instance;

  bool isLoading = false;

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заполните email и пароль')));
      return;
    }

    if (!email.contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите корректный email')));
      return;
    }

    setState(() => isLoading = true);

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, '/mode', (_) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'Ошибка входа';

      if (e.code == 'user-not-found') {
        message = 'Пользователь не найден';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Неверный email или пароль';
      } else if (e.code == 'invalid-email') {
        message = 'Некорректный email';
      } else if (e.code == 'too-many-requests') {
        message = 'Слишком много попыток, попробуйте позже';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Что-то пошло не так')));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthFrame(
    title: 'С возвращением.',
    subtitle: 'Продолжите создавать пространства с вашим характером.',
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StudioField(
            label: 'Email',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
          StudioField(
            label: 'Пароль',
            controller: passwordController,
            obscure: true,
            autofillHints: const [AutofillHints.password],
          ),

          StudioButton(
            label: 'Войти',
            onPressed: isLoading ? null : login,
            busy: isLoading,
          ),
          const SizedBox(height: 18),
          StudioButton(
            label: 'Продолжить как гость',
            secondary: true,
            onPressed: isLoading
                ? null
                : () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const ModeSelectScreen()),
                  ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: isLoading
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
            child: const Text('Создать аккаунт'),
          ),
        ],
      ),
    ),
  );
}
