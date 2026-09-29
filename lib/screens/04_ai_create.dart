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

    final List<String> roomTypes = const [
      'Гостиная',
      'Спальня',
      'Кухня',
      'Детская',
      'Кабинет',
      'Другое',
    ];

    final List<String> budgets = const ['Эконом', 'Средний', 'Премиум'];

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
                    Color(0xFF050B16),
                    Color(0xFF0A1730),
                    Color(0xFF091622),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -100,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF31A0FF).withOpacity(0.18),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -90,
            child: Container(
              width: 330,
              height: 330,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF687BFF).withOpacity(0.14),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    const Text(
                      'RoomCraft AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Создать новый интерьер',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Загрузите фото, задайте стиль и создайте готовую концепцию комнаты за минуты.',
                  style: TextStyle(
                    color: Color(0xFFB5C5DA),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                _FeatureCard(
                  icon: Icons.photo_camera_back_outlined,
                  title: 'Шаг 1 · Фото комнаты',
                  subtitle: 'Загрузите планировку или реальное фото комнаты',
                ),
                const SizedBox(height: 12),
                if (!hasImage)
                  _HoverLift(
                    child: InkWell(
                      onTap: isGenerating ? null : _pickImage,
                      borderRadius: BorderRadius.circular(26),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Column(
                          children: const [
                            Icon(Icons.cloud_upload_outlined, size: 42, color: Colors.white),
                            SizedBox(height: 12),
                            Text(
                              'Загрузите фотографию комнаты',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'PNG, JPG или HEIC (до 10MB)',
                              style: TextStyle(color: Color(0xFFB5C5DA)),
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
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
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
                                        color: Colors.black.withOpacity(0.3),
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
                                    side: const BorderSide(color: Colors.white24),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                                  label: const Text(
                                    'Удалить',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
                const SizedBox(height: 18),
                _FeatureCard(
                  icon: Icons.home_work_outlined,
                  title: 'Шаг 2 · Тип помещения',
                  subtitle: 'Выберите комнату, которую вы хотите оформить',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: roomTypes.map((room) {
                    return _StyleChip(
                      text: room,
                      isSelected: false,
                      onTap: () {},
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                _FeatureCard(
                  icon: Icons.palette_outlined,
                  title: 'Шаг 3 · Стиль интерьера',
                  subtitle: 'Выберите визуальный стиль для вашей комнаты',
                ),
                const SizedBox(height: 10),
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
                        setState(() => selectedStyle = style);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                _FeatureCard(
                  icon: Icons.currency_exchange,
                  title: 'Шаг 4 · Бюджет',
                  subtitle: 'Учитывайте смету при генерации рекомендаций',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: budgets.map((item) {
                    return _StyleChip(
                      text: item,
                      isSelected: false,
                      onTap: () {},
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                _FeatureCard(
                  icon: Icons.auto_awesome,
                  title: 'Шаг 5 · ИИ-помощник',
                  subtitle: 'Опишите желаемый интерьер и его детали',
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1E38),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF29486F)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A3F7CCF),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: promptController,
                    enabled: !isGenerating,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Например: светлая спальня в стилe минимализм, тёплое освещение, натуральные материалы',
                      hintStyle: TextStyle(color: Color(0xFF9FB2CF)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PromptChip(text: 'Сделать комнату светлее', onTap: () => _appendPrompt('Сделать комнату светлее')),
                    _PromptChip(text: 'Добавить хранения', onTap: () => _appendPrompt('Добавить хранения')),
                    _PromptChip(text: 'Сделать уютнее', onTap: () => _appendPrompt('Сделать уютнее')),
                    _PromptChip(text: 'Больше пространства', onTap: () => _appendPrompt('Больше пространства')),
                    _PromptChip(text: 'Натуральные материалы', onTap: () => _appendPrompt('Натуральные материалы')),
                    _PromptChip(text: 'Тёплое освещение', onTap: () => _appendPrompt('Тёплое освещение')),
                  ],
                ),
                const SizedBox(height: 22),
                _HoverLift(
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
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
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(
                        isGenerating ? 'Создаём ваш интерьер…' : 'Создать дизайн с ИИ',
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
            color: isSelected
                ? const Color(0xFF2E90FA)
                : const Color(0xFF11243D),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2E90FA)
                  : const Color(0xFF2C4A6B),
            ),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x1A2E90FA),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFFD9E8FF),
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
            color: const Color(0xFF12233F),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF2A456A)),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFD9E8FF),
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
          color: const Color(0xFF102540),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A456A)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A2E90FA),
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
                color: const Color(0xFF17355E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF8FC5FF)),
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
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFB5C5DA),
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
