import 'dart:async';
import 'package:flutter/material.dart';
import '../services/saved_works_service.dart';
import '../services/workspace_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/studio_components.dart';
import '../widgets/workspace_shell.dart';
import '../widgets/project_card.dart';
import 'create_project_screen.dart';
import 'project_screen.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    this.repository,
    this.showProjects = false,
  });
  final WorkspaceRepository? repository;
  final bool showProjects;
  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  late final WorkspaceRepository _repository;
  StreamSubscription<String?>? _authSubscription;
  Stream<List<SavedWorkWithId>>? _works;
  late bool _projects;
  final _searchController = TextEditingController();
  String _search = '';
  String _status = 'all';
  String? _owner;
  bool _access = false;
  final Set<String> _deleting = {};
  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseWorkspaceRepository();
    _owner = _repository.userId;
    _access = _owner != null;
    _projects = widget.showProjects;
    _subscribe();
    _authSubscription = _repository.userChanges.listen((uid) {
      if (uid != _owner && mounted) {
        setState(() {
          _access = false;
          _works = null;
        });
      }
    });
  }

  void _subscribe() {
    if (!_access) return;
    try {
      _works = _repository.watchWorks();
    } catch (error) {
      _works = Stream.error(error);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_access) {
      Navigator.pushNamed(context, '/login');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateProjectScreen(repository: _repository),
      ),
    );
  }

  Future<void> _delete(SavedWorkWithId item) async {
    if (_deleting.contains(item.id)) return;
    if (!await confirmProjectDeletion(context, item.work.title) || !mounted) {
      return;
    }
    setState(() => _deleting.add(item.id));
    try {
      await _repository.delete(item.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось удалить проект. Проверьте подключение и права доступа.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) => WorkspaceShell(
    title: _projects ? 'Мои проекты' : 'Рабочее пространство',
    section: _projects ? 'projects' : 'dashboard',
    onCreate: _create,
    onSection: (section) => setState(() => _projects = section == 'projects'),
    child: !_access
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: StudioState(
              title: 'Ваше пространство ждёт.',
              message:
                  'Войдите в аккаунт, чтобы создавать и сохранять проекты. Ручной редактор доступен через меню.',
              action: StudioButton(
                label: 'Войти',
                onPressed: () => Navigator.pushNamed(context, '/login'),
              ),
            ),
          )
        : StreamBuilder<List<SavedWorkWithId>>(
            stream: _works,
            builder: (context, snapshot) {
              final all = snapshot.data ?? [];
              final matching = all
                  .where(
                    (item) =>
                        item.work.title.toLowerCase().contains(
                          _search.toLowerCase().trim(),
                        ) &&
                        (_status == 'all' || item.work.status == _status),
                  )
                  .toList();
              final items = _projects ? matching : all.take(6).toList();
              return LayoutBuilder(
                builder: (context, constraints) {
                  final gutter = constraints.maxWidth < 600 ? 18.0 : 40.0;
                  final columns = constraints.maxWidth >= 1150
                      ? 3
                      : constraints.maxWidth >= 650
                      ? 2
                      : 1;
                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(gutter, 36, gutter, 28),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!_projects)
                                Container(
                                  padding: EdgeInsets.all(
                                    constraints.maxWidth < 600 ? 22 : 36,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.sand,
                                        Color(0xFFE8DDD5),
                                        AppColors.ivory,
                                      ],
                                    ),
                                  ),
                                  child: StudioPanel(
                                    glass: true,
                                    child: StudioHeading(
                                      eyebrow: 'ЛИЧНОЕ АТЕЛЬЕ / ROOMCRAFT AI',
                                      title:
                                          'Здравствуйте, ${_repository.userLabel}.',
                                      subtitle:
                                          'Каждая идея начинается с нового взгляда на пространство.',
                                    ),
                                  ),
                                )
                              else
                                const StudioHeading(
                                  eyebrow: 'КОЛЛЕКЦИЯ / ROOMCRAFT AI',
                                  title: 'Мои проекты',
                                  subtitle:
                                      'Ваши пространства, идеи и сохранённые концепции.',
                                ),
                              const SizedBox(height: 24),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: StudioButton(
                                  label: 'Создать проект +',
                                  onPressed: _create,
                                ),
                              ),
                              const SizedBox(height: 32),
                              if (_projects) ...[
                                TextField(
                                  controller: _searchController,
                                  onChanged: (value) =>
                                      setState(() => _search = value),
                                  decoration: const InputDecoration(
                                    labelText: 'Поиск по названию',
                                    prefixIcon: Icon(Icons.search),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  children: [
                                    for (final filter in const [
                                      ('all', 'Все'),
                                      ('draft', 'Черновики'),
                                      ('ready', 'Концепции готовы'),
                                    ])
                                      ChoiceChip(
                                        label: Text(filter.$2),
                                        selected: _status == filter.$1,
                                        onSelected: (_) =>
                                            setState(() => _status = filter.$1),
                                      ),
                                  ],
                                ),
                              ] else
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'ПОСЛЕДНИЕ ПРОЕКТЫ',
                                        style: AppText.label,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          setState(() => _projects = true),
                                      child: const Text('Все проекты ↗'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (snapshot.hasError)
                        SliverPadding(
                          padding: EdgeInsets.all(gutter),
                          sliver: SliverToBoxAdapter(
                            child: StudioState(
                              title: 'Не удалось загрузить проекты',
                              message:
                                  'Проверьте подключение к интернету. Если ошибка повторяется, обратитесь к администратору.',
                              action: StudioButton(
                                label: 'Повторить',
                                onPressed: () => setState(_subscribe),
                              ),
                            ),
                          ),
                        )
                      else if (snapshot.connectionState ==
                          ConnectionState.waiting)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        )
                      else if (items.isEmpty)
                        SliverPadding(
                          padding: EdgeInsets.all(gutter),
                          sliver: SliverToBoxAdapter(
                            child: StudioState(
                              title: all.isEmpty
                                  ? 'Начнём с чистого пространства.'
                                  : 'Ничего не найдено',
                              message: all.isEmpty
                                  ? 'Создайте первый проект: добавьте пожелания и фотографию помещения.'
                                  : 'Попробуйте другое название или статус.',
                              action: all.isEmpty
                                  ? StudioButton(
                                      label: 'Создать первый проект',
                                      onPressed: _create,
                                    )
                                  : TextButton(
                                      onPressed: () => setState(() {
                                        _status = 'all';
                                        _search = '';
                                        _searchController.clear();
                                      }),
                                      child: const Text('Сбросить фильтры'),
                                    ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 40),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisExtent: 370,
                                  crossAxisSpacing: 24,
                                  mainAxisSpacing: 28,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final item = items[index];
                              return ProjectCard(
                                item: item,
                                onOpen: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProjectScreen(
                                      item: item,
                                      repository: _repository,
                                    ),
                                  ),
                                ),
                                onDelete: () => _delete(item),
                              );
                            }, childCount: items.length),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
  );
}
