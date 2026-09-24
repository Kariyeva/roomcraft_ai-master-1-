import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AiCreateScreen extends StatefulWidget {
  const AiCreateScreen({super.key});

  @override
  State<AiCreateScreen> createState() => _AiCreateScreenState();
}

class _AiCreateScreenState extends State<AiCreateScreen> {
  String? selectedStyle;
  Uint8List? selectedImageBytes;
  String? selectedImageName;

  bool _restoredArgs = false;
  bool isGenerating = false;

  final TextEditingController promptController = TextEditingController();

  final List<String> styles = const [
    'Minimalist',
    'Modern',
    'Scandi',
    'Classic',
    'Industrial',
    'Boho',
    'Loft',
    'Zen',
  ];

  @override
  void dispose() {
    promptController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_restoredArgs) return;
    _restoredArgs = true;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final Uint8List? imageBytes = args?['imageBytes'] as Uint8List?;
    final String? style = args?['style'] as String?;
    final String? prompt = args?['prompt'] as String?;

    if (imageBytes != null && imageBytes.isNotEmpty) {
      selectedImageBytes = imageBytes;
    }

    if (style != null && style.isNotEmpty) {
      selectedStyle = style;
    }

    if (prompt != null && prompt.isNotEmpty) {
      promptController.text = prompt;
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );

      if (result == null) return;

      final file = result.files.single;

      if (file.bytes == null || file.bytes!.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Файл не загрузился. Выберите JPG или PNG'),
          ),
        );
        return;
      }

      setState(() {
        selectedImageBytes = file.bytes!;
        selectedImageName = file.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка выбора файла: $e')));
    }
  }

  void _removeImage() {
    setState(() {
      selectedImageBytes = null;
      selectedImageName = null;
      selectedStyle = null;
      promptController.clear();
    });
  }

  void _appendPrompt(String text) {
    final current = promptController.text.trim();

    setState(() {
      promptController.text = current.isEmpty ? text : '$current, $text';
      promptController.selection = TextSelection.fromPosition(
        TextPosition(offset: promptController.text.length),
      );
    });
  }

  Future<void> _generateDesign() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Войдите в аккаунт, чтобы использовать ИИ'),
        ),
      );
      return;
    }

    if (selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала загрузите фото комнаты')),
      );
      return;
    }

    setState(() {
      isGenerating = true;
    });

    try {
      final uri = Uri.parse(
        'https://roomcraft-backend-pugy.onrender.com/generate-room',
      );

      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          selectedImageBytes!,
          filename: selectedImageName ?? 'room.jpg',
        ),
      );

      request.fields['prompt'] = promptController.text.trim();
      request.fields['style'] = selectedStyle ?? '';
      request.fields['userId'] = user.uid;

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      Map<String, dynamic> decoded = {};

      if (responseData.isNotEmpty) {
        decoded = jsonDecode(responseData) as Map<String, dynamic>;
      }

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.pushNamed(
          context,
          '/result',
          arguments: {
            'imagePath': decoded['imageUrl'],
            'style': selectedStyle,
            'prompt': promptController.text.trim(),
          },
        );
      } else if (response.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Лимит генераций исчерпан')),
        );
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Войдите в аккаунт')));
      } else {
        final message = decoded['error'] ?? 'Ошибка генерации';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message.toString())));
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка генерации: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color previewAccent = _accentColor(selectedStyle);
    final Color previewOverlay = _overlayColor(selectedStyle);
    final bool hasImage = selectedImageBytes != null;

    final bool canGenerate =
        hasImage &&
        !isGenerating &&
        (selectedStyle != null || promptController.text.trim().isNotEmpty);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF5F8FF),
                    Color(0xFFEAF4FF),
                    Color(0xFFF4F1FF),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7DC1FF).withOpacity(0.20),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFB39DFF).withOpacity(0.16),
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: 24,
            child: Opacity(
              opacity: 0.08,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: Color(0xFF2E90FA), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'RoomCraft AI',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppBar(
                  automaticallyImplyLeading: false,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: const Text(
                    'Создать дизайн',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  centerTitle: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: const [
                    Text(
                      '1. Загрузите фото',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(width: 10),
                    Chip(
                      label: Text(
                        'ОБЯЗАТЕЛЬНО',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      backgroundColor: Color(0xFFE8F1FF),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(width: 170, child: _FeatureCard(icon: Icons.auto_awesome, title: 'ИИ-помощник', subtitle: 'Текстовый запрос')),
                    SizedBox(width: 170, child: _FeatureCard(icon: Icons.photo_camera_back_outlined, title: 'Фото комнаты', subtitle: 'Сохранить план')),
                    SizedBox(width: 170, child: _FeatureCard(icon: Icons.currency_exchange, title: 'Бюджет', subtitle: 'С учётом цены')),
                    SizedBox(width: 170, child: _FeatureCard(icon: Icons.compare_arrows_rounded, title: '3 варианта', subtitle: 'Выбрать лучший')),
                  ],
                ),
                const SizedBox(height: 18),
                if (!hasImage)
                  _HoverLift(
                    child: InkWell(
                      onTap: isGenerating ? null : _pickImage,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.80),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFDBE4F0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0F2E90FA),
                              blurRadius: 16,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: const [
                            Icon(Icons.cloud_upload_outlined, size: 42, color: Color(0xFF2E90FA)),
                            SizedBox(height: 12),
                            Text(
                              'Нажмите, чтобы загрузить фото\nкомнаты',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'PNG, JPG или HEIC (до 10MB)',
                              style: TextStyle(color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  _HoverLift(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.82),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFDBE4F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0F2E90FA),
                            blurRadius: 16,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Stack(
                              children: [
                                Image.memory(
                                  selectedImageBytes!,
                                  width: double.infinity,
                                  height: 220,
                                  fit: BoxFit.cover,
                                  color: previewOverlay,
                                  colorBlendMode: BlendMode.softLight,
                                ),
                                if (selectedStyle != null)
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.92),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        selectedStyle!,
                                        style: TextStyle(
                                          color: previewAccent,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (selectedStyle != null)
                                  Positioned(
                                    left: 12,
                                    bottom: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.92),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.auto_awesome, size: 16, color: previewAccent),
                                          const SizedBox(width: 8),
                                          Text(
                                            _previewLabel(selectedStyle!),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF111827),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isGenerating ? null : _removeImage,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFDBE4F0)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFF111827)),
                                  label: const Text(
                                    'Удалить',
                                    style: TextStyle(
                                      color: Color(0xFF111827),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isGenerating ? null : _pickImage,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E90FA),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Заменить', style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                const Text('2. Опишите интерьер', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.82),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFDBE4F0)),
                  ),
                  child: TextField(
                    controller: promptController,
                    enabled: !isGenerating,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Например: уютная гостиная в скандинавском стиле с тёплым светом и растениями',
                      hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(14),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PromptChip(text: 'уютно', onTap: () => _appendPrompt('уютно')),
                    _PromptChip(text: 'светло', onTap: () => _appendPrompt('светло')),
                    _PromptChip(text: 'современно', onTap: () => _appendPrompt('современно')),
                    _PromptChip(text: 'с растениями', onTap: () => _appendPrompt('с растениями')),
                    _PromptChip(text: 'тёплый свет', onTap: () => _appendPrompt('тёплый свет')),
                    _PromptChip(text: 'минимализм', onTap: () => _appendPrompt('минимализм')),
                  ],
                ),
                const SizedBox(height: 22),
                const Text('3. Выберите стиль', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: styles.map((style) {
                    final isSelected = selectedStyle == style;

                    return _StyleChip(
                      text: style,
                      isSelected: isSelected,
                      onTap: () {
                        if (isGenerating) return;
                        setState(() { selectedStyle = style; });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
                _HoverLift(
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: canGenerate ? _generateDesign : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E90FA),
                        disabledBackgroundColor: const Color(0xFFBFD9F8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      icon: isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        isGenerating
                            ? 'Генерируем...'
                            : promptController.text.trim().isNotEmpty
                                ? 'Создать интерьер'
                                : 'Сгенерировать дизайн',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _previewLabel(String style) {
    switch (style) {
      case 'Minimalist':
        return 'Светлый и чистый';
      case 'Modern':
        return 'Современный акцент';
      case 'Scandi':
        return 'Мягкий сканди';
      case 'Classic':
        return 'Тёплая классика';
      case 'Industrial':
        return 'Строже и холоднее';
      case 'Boho':
        return 'Творчески и тепло';
      case 'Loft':
        return 'Глубже и темнее';
      case 'Zen':
        return 'Спокойнее и мягче';
      default:
        return 'Предпросмотр стиля';
    }
  }

  static Color _accentColor(String? style) {
    switch (style) {
      case 'Minimalist':
        return const Color(0xFF8FAFCF);
      case 'Modern':
        return const Color(0xFF2E90FA);
      case 'Scandi':
        return const Color(0xFF49A58A);
      case 'Classic':
        return const Color(0xFFB08968);
      case 'Industrial':
        return const Color(0xFF61656D);
      case 'Boho':
        return const Color(0xFFD28B5C);
      case 'Loft':
        return const Color(0xFF7A5C58);
      case 'Zen':
        return const Color(0xFF6E9E72);
      default:
        return const Color(0xFF2E90FA);
    }
  }

  static Color _overlayColor(String? style) {
    switch (style) {
      case 'Minimalist':
        return const Color(0x80EAF3FF);
      case 'Modern':
        return const Color(0x662E90FA);
      case 'Scandi':
        return const Color(0x8049A58A);
      case 'Classic':
        return const Color(0x66D9B38C);
      case 'Industrial':
        return const Color(0x996B7280);
      case 'Boho':
        return const Color(0x99D99A63);
      case 'Loft':
        return const Color(0x997A5C58);
      case 'Zen':
        return const Color(0x807FA37A);
      default:
        return Colors.transparent;
    }
  }
}

class _StyleChip extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _StyleChip({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverLift(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2E90FA) : Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2E90FA)
                  : const Color(0xFFDBE4F0),
            ),
            boxShadow: isSelected ? const [
              BoxShadow(
                color: Color(0x1A2E90FA),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ] : null,
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF111827),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _PromptChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _HoverLift(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFDBE4F0)),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverLift(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.78),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDBE4F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F2E90FA),
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF2E90FA)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2A44),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF74809A),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoverLift extends StatefulWidget {
  final Widget child;

  const _HoverLift({required this.child});

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        child: widget.child,
      ),
    );
  }
}
