import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/saved_works_service.dart';
import '../services/workspace_repository.dart';
import '../widgets/studio_components.dart';
import '../widgets/project_card.dart';
import '../theme/app_text.dart';

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({
    super.key,
    required this.item,
    required this.repository,
  });
  final SavedWorkWithId item;
  final WorkspaceRepository repository;
  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  late Stream<List<SavedWorkWithId>> _stream;
  StreamSubscription<String?>? _auth;
  bool _access = true;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    try {
      _stream = widget.repository.watchWorks();
    } catch (error) {
      _stream = Stream.error(error);
    }
    final owner = widget.repository.userId;
    _auth = widget.repository.userChanges.listen((uid) {
      if (uid != owner && mounted) setState(() => _access = false);
    });
  }

  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }

  Future<void> _openTool(SavedWorkWithId item, bool ai) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final work = item.work;
      final source = ai
          ? work.project?.sourceImageBase64 ?? work.imageBase64
          : work.imageBase64.isNotEmpty
          ? work.imageBase64
          : work.project?.sourceImageBase64 ?? '';
      Uint8List? bytes;
      if (source.isNotEmpty) {
        bytes = base64Decode(source);
      } else if (work.imagePath.startsWith('https://') ||
          work.imagePath.startsWith('http://')) {
        final response = await http
            .get(Uri.parse(work.imagePath))
            .timeout(const Duration(seconds: 25));
        if (response.statusCode != 200) throw StateError('Фото недоступно');
        bytes = response.bodyBytes;
      }
      if (bytes == null || bytes.isEmpty) throw StateError('Нет фотографии');
      if (!mounted || !_access) return;
      await Navigator.pushNamed(
        context,
        ai ? '/ai_create' : '/editor',
        arguments: {
          'projectId': item.id,
          'projectOwnerId': widget.repository.userId,
          'imageBytes': bytes,
          'style': work.project?.interiorStyle.isNotEmpty == true
              ? work.project!.interiorStyle
              : work.style,
          'prompt': ai ? work.project?.brief ?? work.prompt : work.prompt,
          if (!ai) 'placedItems': work.placedItems,
        },
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось открыть фотографию. Проверьте доступность изображения и повторите.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(SavedWorkWithId item) async {
    if (_busy ||
        !await confirmProjectDeletion(context, item.work.title) ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repository.delete(item.id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Проект не удалён. Повторите позже.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Проект')),
    body: !_access
        ? const Center(
            child: Text('Аккаунт изменился. Вернитесь в личный кабинет.'),
          )
        : StreamBuilder<List<SavedWorkWithId>>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: StudioState(
                    title: 'Не удалось открыть проект',
                    message: 'Проверьте соединение и права доступа.',
                    action: StudioButton(
                      label: 'Повторить',
                      onPressed: () => setState(
                        () => _stream = widget.repository.watchWorks(),
                      ),
                    ),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final matches = (snapshot.data ?? []).where(
                (item) => item.id == widget.item.id,
              );
              if (matches.isEmpty) {
                return const Center(
                  child: Text('Проект удалён или недоступен.'),
                );
              }
              final item = matches.first;
              final work = item.work;
              final details = work.project;
              return SingleChildScrollView(
                padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 600 ? 18 : 40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StudioHeading(
                          eyebrow:
                              '${work.statusLabel.toUpperCase()} / ${work.dateLabel}',
                          title: work.title,
                          subtitle: details == null
                              ? 'Сохранённая работа из вашей коллекции.'
                              : '${details.roomType} · ${details.area} м² · ${details.interiorStyle.isEmpty ? work.style : details.interiorStyle}',
                        ),
                        const SizedBox(height: 28),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: SizedBox(
                            height: MediaQuery.sizeOf(context).width < 600
                                ? 280
                                : 450,
                            child: WorkPreview(work: work, fit: BoxFit.contain),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            StudioButton(
                              label: 'Перейти в AI Studio ↗',
                              busy: _busy,
                              onPressed: _busy
                                  ? null
                                  : () => _openTool(item, true),
                            ),
                            StudioButton(
                              label: 'Открыть в редакторе',
                              secondary: true,
                              onPressed: _busy
                                  ? null
                                  : () => _openTool(item, false),
                            ),
                            if (work.status == 'ready')
                              StudioButton(
                                label: 'Открыть результат',
                                secondary: true,
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.pushNamed(
                                        context,
                                        '/result',
                                        arguments: {
                                          'projectId': item.id,
                                          'projectOwnerId':
                                              widget.repository.userId,
                                          'imagePath': work.imagePath,
                                          'imageBytes': work.imageBase64.isEmpty
                                              ? null
                                              : base64Decode(work.imageBase64),
                                          'style': work.style,
                                          'mode': work.mode,
                                          'placedItems': work.placedItems,
                                          'prompt': work.prompt,
                                        },
                                      ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        StudioPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Задание на пространство',
                                style: AppText.heading.copyWith(fontSize: 26),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                details?.brief ??
                                    (work.prompt.isEmpty
                                        ? 'Пожелания не указаны.'
                                        : work.prompt),
                                style: AppText.body,
                              ),
                              if (details != null) ...[
                                const SizedBox(height: 24),
                                const Text(
                                  'ИСХОДНАЯ ФОТОГРАФИЯ',
                                  style: AppText.label,
                                ),
                                const SizedBox(height: 16),
                                WorkSourcePhoto(
                                  base64: details.sourceImageBase64,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _busy ? null : () => _delete(item),
                            child: const Text('Удалить проект'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
  );
}

class WorkSourcePhoto extends StatelessWidget {
  const WorkSourcePhoto({super.key, required this.base64});
  final String base64;
  @override
  Widget build(BuildContext context) {
    try {
      return Image.memory(
        base64Decode(base64),
        height: 240,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Text('Исходное фото недоступно'),
      );
    } catch (_) {
      return const Text('Исходное фото недоступно');
    }
  }
}
