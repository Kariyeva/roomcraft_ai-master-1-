import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/project_details.dart';
import '../services/project_photo_service.dart';
import '../services/saved_works_service.dart';
import '../services/workspace_repository.dart';
import '../theme/app_text.dart';
import '../widgets/studio_components.dart';
import 'project_screen.dart';

class PickedProjectPhoto {
  const PickedProjectPhoto(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key, this.repository, this.pickPhoto});
  final WorkspaceRepository? repository;
  final Future<PickedProjectPhoto?> Function()? pickPhoto;
  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  late final WorkspaceRepository _repository;
  final _formKeys = [GlobalKey<FormState>(), GlobalKey<FormState>()];
  final _title = TextEditingController();
  final _area = TextEditingController();
  final _palette = TextEditingController();
  final _materials = TextEditingController();
  final _wishes = TextEditingController();
  final _budget = TextEditingController();
  final _scroll = ScrollController();
  final _requestId =
      'project_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}';
  String _roomType = 'Гостиная';
  String _style = 'Minimalist';
  int _step = 0;
  Uint8List? _photo;
  String? _photoName;
  String? _error;
  bool _working = false;
  bool _allowExit = false;
  bool _dirty = false;
  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseWorkspaceRepository();
    for (final controller in [
      _title,
      _area,
      _palette,
      _materials,
      _wishes,
      _budget,
    ]) {
      controller.addListener(() => _dirty = true);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _area,
      _palette,
      _materials,
      _wishes,
      _budget,
    ]) {
      controller.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  static double? _number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));
  void _move(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _error = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _next() {
    if (_step < 2 && !_formKeys[_step].currentState!.validate()) return;
    if (_step == 2 && _photo == null) {
      setState(() => _error = 'Добавьте фотографию помещения.');
      return;
    }
    _move(_step + 1);
  }

  Future<void> _pick() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      PickedProjectPhoto? selected;
      if (widget.pickPhoto != null) {
        selected = await widget.pickPhoto!();
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png'],
          withData: true,
        );
        if (result != null && result.files.single.bytes != null) {
          selected = PickedProjectPhoto(
            result.files.single.name,
            result.files.single.bytes!,
          );
        }
      }
      if (selected == null) return;
      final prepared = await ProjectPhotoService.prepare(
        selected.bytes,
        selected.name,
      );
      if (!mounted) return;
      setState(() {
        _photo = prepared;
        _photoName = selected!.name;
        _dirty = true;
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Не удалось прочитать фотографию. Попробуйте другой JPG или PNG.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  ProjectDetails get _details => ProjectDetails(
    title: _title.text.trim(),
    interiorStyle: _style,
    roomType: _roomType,
    area: _number(_area.text)!,
    palette: _palette.text.trim(),
    materials: _materials.text.trim(),
    wishes: _wishes.text.trim(),
    budget: _number(_budget.text),
    sourceImageBase64: base64Encode(_photo!),
  );
  Future<void> _save() async {
    if (_working || _photo == null) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final work = SavedWork(
        imagePath: '',
        style: _style,
        mode: 'Проект',
        dateLabel:
            '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}',
        project: _details,
        prompt: _details.brief,
      );
      final id = await _repository.create(work, requestId: _requestId);
      if (!mounted) return;
      setState(() => _allowExit = true);
      // Replacement keeps dashboard underneath; no obsolete wizard on Back.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectScreen(
            item: SavedWorkWithId(id: id, work: work),
            repository: _repository,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Проект не сохранён. Проверьте подключение и доступ к аккаунту. Данные формы сохранены — можно повторить.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _leave() async {
    if (_working) return;
    final discard =
        !_dirty ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Закрыть создание проекта?'),
                content: const Text('Введённые данные ещё не сохранены.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Продолжить'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Закрыть'),
                  ),
                ],
              ),
            ) ==
            true;
    if (discard && mounted) {
      setState(() => _allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowExit,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Новый проект'),
        leading: IconButton(
          tooltip: 'Назад',
          onPressed: _working ? null : _leave,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: _repository.userId == null
          ? Center(
              child: StudioButton(
                label: 'Войти для создания проекта',
                onPressed: () => Navigator.pushNamed(context, '/login'),
              ),
            )
          : SingleChildScrollView(
              controller: _scroll,
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 600 ? 18 : 40,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const StudioHeading(
                        eyebrow: 'НОВОЕ ПРОСТРАНСТВО',
                        title: 'Сначала — ваша идея.',
                        subtitle:
                            'Четыре шага до проекта. Генерацию можно запустить после сохранения.',
                      ),
                      const SizedBox(height: 28),
                      Wrap(
                        spacing: 18,
                        runSpacing: 12,
                        children: [
                          for (final step in const [
                            (0, 'Помещение'),
                            (1, 'Предпочтения'),
                            (2, 'Фотография'),
                            (3, 'Обзор'),
                          ])
                            Text(
                              '${step.$1 + 1} / ${step.$2}',
                              style: AppText.body.copyWith(
                                fontWeight: _step == step.$1
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      StudioPanel(child: _stepContent()),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          if (_step > 0)
                            StudioButton(
                              label: 'Назад',
                              secondary: true,
                              onPressed: _working
                                  ? null
                                  : () => _move(_step - 1),
                            ),
                          StudioButton(
                            label: _step == 3 ? 'Создать проект' : 'Продолжить',
                            busy: _working,
                            onPressed: _working
                                ? null
                                : _step == 3
                                ? _save
                                : _next,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );

  Widget _stepContent() => switch (_step) {
    0 => Form(
      key: _formKeys[0],
      child: Column(
        children: [
          StudioField(
            label: 'Название проекта',
            controller: _title,
            maxLength: 100,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Введите название проекта'
                : null,
          ),
          DropdownButtonFormField<String>(
            initialValue: _roomType,
            decoration: const InputDecoration(labelText: 'Тип помещения'),
            items:
                const [
                      'Гостиная',
                      'Спальня',
                      'Кухня',
                      'Кабинет',
                      'Ванная',
                      'Студия',
                      'Другое',
                    ]
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
            onChanged: (value) {
              _roomType = value!;
              _dirty = true;
            },
          ),
          const SizedBox(height: 20),
          StudioField(
            label: 'Площадь, м²',
            controller: _area,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              final number = _number(value ?? '');
              return number == null ||
                      !number.isFinite ||
                      number <= 0 ||
                      number > 100000
                  ? 'Введите площадь от 0 до 100 000 м²'
                  : null;
            },
          ),
        ],
      ),
    ),
    1 => Form(
      key: _formKeys[1],
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _style,
            decoration: const InputDecoration(labelText: 'Стиль интерьера'),
            items:
                const [
                      ('Minimalist', 'Минимализм'),
                      ('Modern', 'Современный'),
                      ('Scandi', 'Скандинавский'),
                      ('Classic', 'Классический'),
                      ('Industrial', 'Индустриальный'),
                      ('Boho', 'Бохо'),
                      ('Loft', 'Лофт'),
                      ('Zen', 'Дзен'),
                    ]
                    .map(
                      (style) => DropdownMenuItem(
                        value: style.$1,
                        child: Text(style.$2),
                      ),
                    )
                    .toList(),
            onChanged: (value) {
              _style = value!;
              _dirty = true;
            },
          ),
          const SizedBox(height: 20),
          StudioField(
            label: 'Цветовая палитра',
            controller: _palette,
            maxLength: 200,
          ),
          StudioField(
            label: 'Предпочитаемые материалы',
            controller: _materials,
            maxLength: 300,
          ),
          StudioField(
            label: 'Пожелания к интерьеру',
            controller: _wishes,
            lines: 4,
            maxLength: 2000,
          ),
          StudioField(
            label: 'Бюджет, ₸ (необязательно)',
            controller: _budget,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final number = _number(value);
              return number == null ||
                      !number.isFinite ||
                      number < 0 ||
                      number > 1000000000000
                  ? 'Введите корректный бюджет в тенге'
                  : null;
            },
          ),
        ],
      ),
    ),
    2 => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Взгляд на ваше помещение',
          style: AppText.heading.copyWith(fontSize: 26),
        ),
        const SizedBox(height: 16),
        const Text(
          'JPG или PNG · до 10 МБ · до 24 Мп. Для хранения фото будет оптимизировано до 1600 px и 220 КБ. Файл на вашем устройстве останется прежним.',
          style: AppText.body,
        ),
        const SizedBox(height: 24),
        if (_photo != null) ...[
          Image.memory(_photo!, height: 280, fit: BoxFit.contain),
          const SizedBox(height: 14),
          Text(_photoName!, style: AppText.body),
          const SizedBox(height: 18),
        ],
        StudioButton(
          label: _photo == null
              ? 'Загрузить фотографию'
              : 'Заменить фотографию',
          secondary: true,
          onPressed: _working ? null : _pick,
        ),
      ],
    ),
    _ => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_title.text.trim(), style: AppText.heading.copyWith(fontSize: 28)),
        const SizedBox(height: 18),
        Text(
          '$_roomType · ${_area.text} м²\nСтиль: $_style',
          style: AppText.body,
        ),
        const SizedBox(height: 14),
        Text(_details.brief, style: AppText.body),
        const SizedBox(height: 24),
        Image.memory(
          _photo!,
          height: 260,
          width: double.infinity,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 20),
        const Text(
          'Сохраним черновик в вашем аккаунте. Создание проекта не запускает платную AI-генерацию.',
          style: AppText.body,
        ),
      ],
    ),
  };
}
