import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roomcraft_ai/models/project_details.dart';
import 'package:roomcraft_ai/services/saved_works_service.dart';
import 'package:roomcraft_ai/services/workspace_repository.dart';
import 'package:roomcraft_ai/screens/workspace_screen.dart';
import 'package:roomcraft_ai/screens/create_project_screen.dart';
import 'package:roomcraft_ai/screens/02_login.dart';
import 'package:roomcraft_ai/screens/register_screen.dart';
import 'package:roomcraft_ai/screens/04_ai_create.dart';
import 'package:roomcraft_ai/screens/06_editor.dart';
import 'package:roomcraft_ai/screens/05_result.dart';
import 'package:roomcraft_ai/theme/app_theme.dart';

class MemoryWorkspace implements WorkspaceRepository {
  MemoryWorkspace(this.items);
  List<SavedWorkWithId> items;
  final events = StreamController<List<SavedWorkWithId>>.broadcast();
  final auth = StreamController<String?>.broadcast();
  bool failCreate = false;
  bool failWatch = false;
  int watchCount = 0;
  int createCount = 0;
  String? uid = 'designer';
  @override
  String? get userId => uid;
  @override
  String get userLabel => 'Алия';
  @override
  Stream<String?> get userChanges => auth.stream;
  @override
  Stream<List<SavedWorkWithId>> watchWorks() async* {
    watchCount++;
    if (failWatch) throw StateError('offline');
    yield List.of(items);
    yield* events.stream;
  }

  @override
  Future<String> create(SavedWork work, {required String requestId}) async {
    createCount++;
    if (failCreate) throw StateError('offline');
    final id = requestId;
    items = [...items, SavedWorkWithId(id: id, work: work)];
    events.add(List.of(items));
    return id;
  }

  @override
  Future<void> delete(String id) async {
    items = items.where((item) => item.id != id).toList();
    events.add(List.of(items));
  }

  Future<void> dispose() async {
    await events.close();
    await auth.close();
  }
}

Uint8List testPhoto() => img.encodeJpg(img.Image(width: 32, height: 24));
SavedWorkWithId project(String id, String name, {bool ready = false}) =>
    SavedWorkWithId(
      id: id,
      work: SavedWork(
        imagePath: '',
        style: 'Modern',
        mode: 'Проект',
        dateLabel: '18.10.2026',
        project: ProjectDetails(
          title: name,
          roomType: 'Гостиная',
          area: 25,
          sourceImageBase64: base64Encode(testPhoto()),
          status: ready ? 'ready' : 'draft',
        ),
      ),
    );

Future<void> show(
  WidgetTester tester,
  Widget page,
  double width, {
  Map<String, WidgetBuilder> routes = const {},
  Map<String, dynamic>? arguments,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: arguments == null ? page : null,
      routes: {if (arguments != null) '/': (_) => page, ...routes},
      onGenerateInitialRoutes: arguments == null
          ? null
          : (_) => [
              MaterialPageRoute(
                settings: RouteSettings(name: '/', arguments: arguments),
                builder: (_) => page,
              ),
            ],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String label) async {
  final finder = find.text(label).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> enterLabel(WidgetTester tester, String label, String value) async {
  final finder = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [320.0, 375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('Workspace, filters, detail and tools at $width', (
      tester,
    ) async {
      final repository = MemoryWorkspace([
        project('1', 'Квартира у парка'),
        project('2', 'Дом у озера', ready: true),
      ]);
      addTearDown(repository.dispose);
      await show(
        tester,
        WorkspaceScreen(repository: repository),
        width,
        routes: {
          '/ai_create': (context) => Scaffold(
            body: Text(
              'AI ${((ModalRoute.of(context)?.settings.arguments) as Map)['projectId']}',
            ),
          ),
          '/editor': (context) => Scaffold(
            body: Text(
              'Editor ${((ModalRoute.of(context)?.settings.arguments) as Map)['projectId']}',
            ),
          ),
        },
      );
      expect(find.text('Здравствуйте, Алия.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Все проекты ↗');
      await enterLabel(tester, 'Поиск по названию', 'озера');
      expect(find.text('Квартира у парка'), findsNothing);
      expect(find.text('Дом у озера'), findsOneWidget);
      await tapText(tester, 'Черновики');
      expect(find.text('Ничего не найдено'), findsOneWidget);
      await tapText(tester, 'Сбросить фильтры');
      expect(
        repository.watchCount,
        1,
        reason: 'Filtering should reuse the same subscription',
      );
      await tester.ensureVisible(find.text('Квартира у парка'));
      await tester.tap(find.text('Квартира у парка'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Перейти в AI Studio ↗');
      expect(find.text('AI 1'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      await tapText(tester, 'Открыть в редакторе');
      expect(find.text('Editor 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Auth, wizard and existing tools render at $width', (
      tester,
    ) async {
      final repository = MemoryWorkspace([]);
      addTearDown(repository.dispose);
      for (final page in <Widget>[
        const LoginScreen(),
        const RegisterScreen(),
        CreateProjectScreen(repository: repository),
        const AiCreateScreen(),
        const EditorScreen(),
        const ResultScreen(),
      ]) {
        await show(tester, page, width);
        expect(
          tester.takeException(),
          isNull,
          reason: '${page.runtimeType} at $width',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    });
  }
  for (final width in [320.0, 375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('Existing tools handle a project photo at $width', (
      tester,
    ) async {
      for (final page in <Widget>[
        const AiCreateScreen(),
        const EditorScreen(),
        const ResultScreen(),
      ]) {
        await show(
          tester,
          page,
          width,
          arguments: {
            'projectId': 'existing-project',
            'projectOwnerId': 'designer',
            'imageBytes': testPhoto(),
            'style': 'Modern',
            'prompt': 'Тёплый свет',
            'placedItems': [
              {
                'id': 'sofa',
                'title': 'ДИВАН',
                'iconCodePoint': Icons.weekend.codePoint,
                'x': 0.1,
                'y': 0.1,
                'scale': 1.0,
              },
            ],
          },
        );
        expect(
          tester.takeException(),
          isNull,
          reason: '${page.runtimeType} with photo at $width',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    });
  }
  testWidgets('Mobile drawer scrolls on a short screen', (tester) async {
    final repository = MemoryWorkspace([]);
    addTearDown(repository.dispose);
    await show(tester, WorkspaceScreen(repository: repository), 320);
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Профиль'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Delete asks confirmation; cancel keeps data', (tester) async {
    final repository = MemoryWorkspace([project('1', 'Квартира')]);
    addTearDown(repository.dispose);
    await show(
      tester,
      WorkspaceScreen(repository: repository, showProjects: true),
      1440,
    );
    await tester.ensureVisible(find.byTooltip('Удалить проект'));
    await tester.tap(find.byTooltip('Удалить проект'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Отмена');
    expect(repository.items.length, 1);
    await tester.tap(find.byTooltip('Удалить проект'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Удалить');
    expect(repository.items, isEmpty);
    expect(find.text('Начнём с чистого пространства.'), findsOneWidget);
  });
  testWidgets('Load error can be retried without clearing projects', (
    tester,
  ) async {
    final repository = MemoryWorkspace([project('1', 'Проект')])
      ..failWatch = true;
    addTearDown(repository.dispose);
    await show(tester, WorkspaceScreen(repository: repository), 768);
    expect(find.text('Не удалось загрузить проекты'), findsOneWidget);
    repository.failWatch = false;
    await tapText(tester, 'Повторить');
    expect(find.text('Проект'), findsOneWidget);
    expect(repository.watchCount, 2);
  });
  testWidgets('Closing a dirty wizard requires explicit discard', (
    tester,
  ) async {
    final repository = MemoryWorkspace([]);
    addTearDown(repository.dispose);
    await show(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateProjectScreen(repository: repository),
              ),
            ),
            child: const Text('Open wizard'),
          ),
        ),
      ),
      375,
    );
    await tapText(tester, 'Open wizard');
    await enterLabel(tester, 'Название проекта', 'Не потерять');
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(find.text('Закрыть создание проекта?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Продолжить'));
    await tester.pumpAndSettle();
    expect(find.text('Не потерять'), findsOneWidget);
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Закрыть');
    expect(find.text('Open wizard'), findsOneWidget);
    expect(repository.items, isEmpty);
  });
  testWidgets('Login and register validate before contacting Firebase', (
    tester,
  ) async {
    await show(tester, const LoginScreen(), 375);
    await tapText(tester, 'Войти');
    expect(find.text('Заполните email и пароль'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await show(tester, const RegisterScreen(), 375);
    await tapText(tester, 'Зарегистрироваться');
    expect(find.text('Заполните все поля'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Auth change hides previous user data', (tester) async {
    final repository = MemoryWorkspace([project('1', 'Личный проект')]);
    addTearDown(repository.dispose);
    await show(tester, WorkspaceScreen(repository: repository), 1440);
    expect(find.text('Личный проект'), findsOneWidget);
    repository.uid = null;
    repository.auth.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Личный проект'), findsNothing);
    expect(find.text('Ваше пространство ждёт.'), findsOneWidget);
  });
  testWidgets(
    'Wizard validates, preserves values, retries save and opens saved project',
    (tester) async {
      final repository = MemoryWorkspace([]);
      addTearDown(repository.dispose);
      await show(
        tester,
        CreateProjectScreen(
          repository: repository,
          pickPhoto: () async => PickedProjectPhoto('room.jpg', testPhoto()),
        ),
        375,
      );
      await tapText(tester, 'Продолжить');
      expect(find.text('Введите название проекта'), findsOneWidget);
      await enterLabel(tester, 'Название проекта', 'Квартира в Алматы');
      await enterLabel(tester, 'Площадь, м²', '32,5');
      await tapText(tester, 'Продолжить');
      await enterLabel(tester, 'Цветовая палитра', 'Тёплый белый');
      await enterLabel(tester, 'Бюджет, ₸ (необязательно)', '-4');
      await tapText(tester, 'Продолжить');
      expect(find.text('Введите корректный бюджет в тенге'), findsOneWidget);
      await enterLabel(tester, 'Бюджет, ₸ (необязательно)', '2000000');
      await tapText(tester, 'Назад');
      expect(find.text('Квартира в Алматы'), findsOneWidget);
      await tapText(tester, 'Продолжить');
      expect(find.text('Тёплый белый'), findsOneWidget);
      await tapText(tester, 'Продолжить');
      await tapText(tester, 'Продолжить');
      expect(find.text('Добавьте фотографию помещения.'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Загрузить фотографию'));
        // Photo preparation runs on an isolate outside the test's fake clock.
        for (var count = 0; count < 100; count++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
          if (find.text('room.jpg').evaluate().isNotEmpty) break;
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('room.jpg'), findsOneWidget);
      await tapText(tester, 'Продолжить');
      repository.failCreate = true;
      await tapText(tester, 'Создать проект');
      expect(find.textContaining('Проект не сохранён.'), findsOneWidget);
      expect(repository.items, isEmpty);
      repository.failCreate = false;
      await tapText(tester, 'Создать проект');
      expect(repository.items.length, 1);
      final details = repository.items.single.work.project!;
      expect(details.title, 'Квартира в Алматы');
      expect(details.area, 32.5);
      expect(details.budget, 2000000);
      expect(details.palette, 'Тёплый белый');
      expect(details.status, 'draft');
      expect(find.text('Перейти в AI Studio ↗'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
