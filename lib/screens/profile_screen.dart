import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/studio_components.dart';
import '../theme/app_text.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final guest = user == null || user.isAnonymous;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          IconButton(
            tooltip: 'Личный кабинет',
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/mode',
              (_) => false,
            ),
            icon: const Icon(Icons.space_dashboard_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const StudioHeading(
                  eyebrow: 'ЛИЧНОЕ ПРОСТРАНСТВО',
                  title: 'Ваш профиль.',
                ),
                const SizedBox(height: 32),
                StudioPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guest ? 'Гостевой доступ' : 'Аккаунт дизайнера',
                        style: AppText.heading.copyWith(fontSize: 26),
                      ),
                      const SizedBox(height: 18),
                      SelectableText(
                        user?.email ?? 'Войдите для сохранения проектов',
                        style: AppText.body,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        guest
                            ? 'Ручной редактор доступен. Для облачных проектов требуется вход.'
                            : 'Проекты и концепции сохраняются в вашем личном кабинете.',
                        style: AppText.body,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                if (guest)
                  StudioButton(
                    label: 'Войти',
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                  )
                else
                  StudioButton(
                    label: 'Выйти из аккаунта',
                    secondary: true,
                    onPressed: () async {
                      try {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/',
                            (_) => false,
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Не удалось выйти. Повторите позже.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
