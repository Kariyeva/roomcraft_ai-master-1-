import 'package:flutter/material.dart';
import '../widgets/studio_components.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  FirebaseAuth get _auth => FirebaseAuth.instance;

  bool isLoading = false;

  Future<void> register() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заполните все поля')));
      return;
    }

    if (!email.contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите корректный email')));
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пароль должен быть не короче 6 символов'),
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Пароли не совпадают')));
      return;
    }

    setState(() => isLoading = true);

    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, '/mode', (_) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'Ошибка регистрации';

      if (e.code == 'email-already-in-use') {
        message = 'Этот email уже используется';
      } else if (e.code == 'invalid-email') {
        message = 'Некорректный email';
      } else if (e.code == 'weak-password') {
        message = 'Слишком простой пароль';
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
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthFrame(
    title: 'Создайте аккаунт',
    subtitle:
        'Сохраняйте проекты и возвращайтесь к работе с любого устройства.',
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
            autofillHints: const [AutofillHints.newPassword],
          ),
          StudioField(
            label: 'Повторите пароль',
            controller: confirmPasswordController,
            obscure: true,
          ),
          StudioButton(
            label: 'Зарегистрироваться',
            onPressed: isLoading ? null : register,
            busy: isLoading,
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: isLoading ? null : () => Navigator.pop(context),
            child: const Text('Уже есть аккаунт? Войти'),
          ),
        ],
      ),
    ),
  );
}
