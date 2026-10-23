import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/saved_works_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class WorkPreview extends StatefulWidget {
  const WorkPreview({super.key, required this.work, this.fit = BoxFit.cover});
  final SavedWork work;
  final BoxFit fit;
  @override
  State<WorkPreview> createState() => _WorkPreviewState();
}

class _WorkPreviewState extends State<WorkPreview> {
  Uint8List? _bytes;
  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant WorkPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.work.previewBase64 != widget.work.previewBase64) _decode();
  }

  void _decode() {
    try {
      _bytes = widget.work.previewBase64.isEmpty
          ? null
          : base64Decode(widget.work.previewBase64);
    } catch (_) {
      _bytes = null;
    }
  }

  Widget _fallback() => const ColoredBox(
    color: AppColors.sand,
    child: Center(
      child: Icon(Icons.image_outlined, color: AppColors.stone, size: 32),
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        fit: widget.fit,
        width: double.infinity,
        cacheWidth: 1000,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    if (Uri.tryParse(widget.work.imagePath)?.scheme == 'https' ||
        Uri.tryParse(widget.work.imagePath)?.scheme == 'http') {
      return Image.network(
        widget.work.imagePath,
        fit: widget.fit,
        width: double.infinity,
        errorBuilder: (_, _, _) => _fallback(),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _fallback(),
      );
    }
    return _fallback();
  }
}

class ProjectCard extends StatefulWidget {
  const ProjectCard({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onDelete,
  });
  final SavedWorkWithId item;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: _hover ? AppColors.paper : AppColors.ivory,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _hover ? AppColors.stone : AppColors.line),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13),
                  ),
                  child: WorkPreview(work: widget.item.work),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.item.work.statusLabel,
                            style: AppText.label.copyWith(letterSpacing: 1),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Удалить проект',
                          onPressed: widget.onDelete,
                          icon: const Icon(Icons.delete_outline, size: 20),
                        ),
                      ],
                    ),
                    Text(
                      widget.item.work.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.heading.copyWith(fontSize: 23),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.item.work.dateLabel}  ·  Открыть ↗',
                      style: AppText.body,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<bool> confirmProjectDeletion(BuildContext context, String title) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить проект?'),
        content: Text(
          '«$title» будет удалён из личного кабинета. Восстановить его нельзя.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    ) ??
    false;
