import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class WorkspaceShell extends StatelessWidget {
  const WorkspaceShell({
    super.key,
    required this.title,
    required this.child,
    this.section = 'dashboard',
    this.onSection,
    this.onCreate,
  });
  final String title;
  final Widget child;
  final String section;
  final ValueChanged<String>? onSection;
  final VoidCallback? onCreate;
  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1100;
    void navigate(String target) {
      if (target == 'dashboard' || target == 'projects') {
        if (onSection != null) {
          onSection!(target);
        } else {
          Navigator.pushNamedAndRemoveUntil(
            context,
            target == 'projects' ? '/projects' : '/mode',
            (_) => false,
          );
        }
      } else if (target == '/project/new' && onCreate != null) {
        onCreate!();
      } else {
        Navigator.pushNamed(context, target);
      }
    }

    Widget navigation() => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'ROOMCRAFT\n/ AI',
                style: TextStyle(fontSize: 18, letterSpacing: 3, height: 1.5),
              ),
            ),
            const Text('ЛИЧНОЕ ПРОСТРАНСТВО', style: AppText.label),
            const SizedBox(height: 24),
            for (final item in const [
              ('dashboard', 'Обзор', Icons.space_dashboard_outlined),
              ('projects', 'Мои проекты', Icons.folder_open_outlined),
              ('/project/new', 'Создать проект', Icons.add),
              ('/ai_create', 'AI Studio', Icons.auto_awesome_outlined),
              ('/editor', 'Редактор', Icons.tune),
              ('/profile', 'Профиль', Icons.person_outline),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  selected: section == item.$1,
                  selectedColor: AppColors.charcoal,
                  selectedTileColor: AppColors.sand,
                  leading: Icon(item.$3, size: 20),
                  title: Text(item.$2, style: const TextStyle(fontSize: 14)),
                  onTap: () {
                    if (!desktop) Navigator.pop(context);
                    navigate(item.$1);
                  },
                ),
              ),
            const SizedBox(height: 32),
            const Divider(),
            TextButton(
              onPressed: () =>
                  Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false),
              child: const Text('Публичный сайт ↗'),
            ),
            const Text('МЕСТО ДЛЯ НОВЫХ ИДЕЙ', style: AppText.label),
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: desktop ? null : AppBar(title: Text(title)),
      drawer: desktop
          ? null
          : Drawer(backgroundColor: AppColors.ivory, child: navigation()),
      body: SafeArea(
        child: Row(
          children: [
            if (desktop)
              Container(
                width: 230,
                decoration: const BoxDecoration(
                  color: AppColors.paper,
                  border: Border(right: BorderSide(color: AppColors.line)),
                ),
                child: Material(color: AppColors.paper, child: navigation()),
              ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
