import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../platform/file_helper.dart';
import '../services/saved_works_service.dart';
import '01_splash.dart';
import 'profile_screen.dart';

class ModeSelectScreen extends StatefulWidget {
  const ModeSelectScreen({super.key});

  @override
  State<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends State<ModeSelectScreen> {
  Future<void> _refreshWorks() async {
    setState(() {});
  }

  Future<void> _deleteWork(String workId) async {
    await SavedWorksService.deleteWork(workId);
  }

  bool _isRegisteredUser(User? user) {
    if (user == null) return false;
    if (user.isAnonymous) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
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
            right: -80,
            child: Container(
              width: 330,
              height: 330,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3AA0FF).withOpacity(0.22),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF5B7BFF).withOpacity(0.18),
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _refreshWorks,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          );
                        },
                        icon: const Icon(Icons.person_outline, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const SplashScreen()),
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: const [
                        Text(
                          'RoomCraft AI',
                          style: TextStyle(
                            fontSize: 28,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Создавайте интерьер мечты с ИИ и вручную',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFB5C5DA),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _featurePill(icon: Icons.auto_awesome, label: 'ИИ-помощник'),
                      _featurePill(icon: Icons.photo_library_outlined, label: 'Фото комнаты'),
                      _featurePill(icon: Icons.attach_money_rounded, label: 'Бюджет'),
                      _featurePill(icon: Icons.compare_arrows_rounded, label: '3 варианта'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _bigCard(
                        title: 'Создать с помощью ИИ',
                        subtitle: 'Загрузите комнату, выберите стиль и получите готовый интерьер за минуты.',
                        color: const Color(0xFF2E90FA),
                        onTap: () async {
                          await Navigator.pushNamed(context, '/ai_create');
                          setState(() {});
                        },
                      ),
                      _smallCard(
                        title: 'Ручной редактор',
                        subtitle: 'Расставляйте мебель и декор вручную в 2D-режиме.',
                        onTap: () async {
                          await Navigator.pushNamed(context, '/editor');
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Последние проекты',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<User?>(
                    stream: FirebaseAuth.instance.authStateChanges(),
                    builder: (context, authSnapshot) {
                      final user = authSnapshot.data;

                      if (!_isRegisteredUser(user)) {
                        return Row(
                          children: [
                            Expanded(child: _placeholderBox()),
                            const SizedBox(width: 12),
                            Expanded(child: _placeholderBox()),
                          ],
                        );
                      }

                      return StreamBuilder<List<SavedWorkWithId>>(
                        stream: SavedWorksService.getWorksStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: CircularProgressIndicator(color: Colors.white),
                              ),
                            );
                          }

                          final savedWorks = snapshot.data ?? [];

                          if (savedWorks.isEmpty) {
                            return Row(
                              children: [
                                Expanded(child: _placeholderBox()),
                                const SizedBox(width: 12),
                                Expanded(child: _placeholderBox()),
                              ],
                            );
                          }

                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: savedWorks.map((item) {
                              final work = item.work;
                              return _savedWorkCard(
                                context: context,
                                work: work,
                                onDelete: () => _deleteWork(item.id),
                                onOpen: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/result',
                                    arguments: {
                                      'style': work.style,
                                      'imagePath': work.imagePath,
                                      'imageBytes': work.imageBase64.isNotEmpty
                                          ? base64Decode(work.imageBase64)
                                          : null,
                                      'prompt': work.prompt,
                                      'placedItems': work.placedItems,
                                    },
                                  );
                                },
                              );
                            }).toList(),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _placeholderBox() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Color(0xFFB5C5DA), size: 36),
      ),
    );
  }

  static Widget _HoverLift({required Widget child}) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool hovered = false;

        return MouseRegion(
          onEnter: (_) => setState(() => hovered = true),
          onExit: (_) => setState(() => hovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, hovered ? -2 : 0, 0),
            child: child,
          ),
        );
      },
    );
  }

  static Widget _featurePill({required IconData icon, required String label}) {
    return _HoverLift(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _savedWorkCard({
    required BuildContext context,
    required SavedWork work,
    required VoidCallback onDelete,
    required VoidCallback onOpen,
  }) {
    final bool isManual = work.style == 'Ручной режим';
    final Color overlayColor = _overlayColor(work.style);
    final Color accentColor = _accentColor(work.style);

    return SizedBox(
      width: (MediaQuery.of(context).size.width - 44) / 2,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 110,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final areaWidth = constraints.maxWidth;
                        final areaHeight = constraints.maxHeight;

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildWorkThumbnail(work, overlayColor),

                            if (!isManual && work.style.isNotEmpty)
                              Positioned(
                                left: 8,
                                top: 8,
                                child: _miniStyleChip(
                                  title: work.style,
                                  accentColor: accentColor,
                                ),
                              ),

                            if (isManual)
                              ...work.placedItems.map((item) {
                                final double rawX =
                                    ((item['x'] as num?)?.toDouble() ?? 0.0);
                                final double rawY =
                                    ((item['y'] as num?)?.toDouble() ?? 0.0);

                                final double x = rawX > 1
                                    ? rawX
                                    : rawX * areaWidth;
                                final double y = rawY > 1
                                    ? rawY
                                    : rawY * areaHeight;

                                return Positioned(
                                  left: x.clamp(2.0, areaWidth - 60),
                                  top: y.clamp(2.0, areaHeight - 24),
                                  child: _miniPlacedChip(
                                    title: (item['title'] ?? '').toString(),
                                    iconCodePoint:
                                        (item['iconCodePoint'] as num?)
                                            ?.toInt() ??
                                        Icons.category.codePoint,
                                  ),
                                );
                              }),

                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: onDelete,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.95),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        work.mode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),

                      if (work.prompt.isNotEmpty)
                        Text(
                          work.prompt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                        )
                      else
                        Text(
                          work.style,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                        ),

                      const SizedBox(height: 4),

                      if (work.description.isNotEmpty)
                        Text(
                          work.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                        ),

                      const SizedBox(height: 4),
                      Text(
                        work.dateLabel,
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
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

  static Widget _buildWorkThumbnail(SavedWork work, Color overlayColor) {
    final Widget placeholder = Container(
      color: const Color(0xFFE9EEF6),
      child: const Center(
        child: Icon(Icons.image, color: Color(0xFFB8C4D6), size: 30),
      ),
    );

    if (work.imageBase64.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(work.imageBase64),
          fit: BoxFit.cover,
          color: overlayColor,
          colorBlendMode: BlendMode.softLight,
          errorBuilder: (context, error, stackTrace) => placeholder,
        );
      } catch (_) {
        return placeholder;
      }
    }

    if (work.imagePath.startsWith('http')) {
      return Image.network(
        work.imagePath,
        fit: BoxFit.cover,
        color: overlayColor,
        colorBlendMode: BlendMode.softLight,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }

    if (!kIsWeb && fileExists(work.imagePath)) {
      return fileImage(
        work.imagePath,
        fit: BoxFit.cover,
        color: overlayColor,
        colorBlendMode: BlendMode.softLight,
        fallback: placeholder,
      );
    }

    return placeholder;
  }

  static Widget _miniStyleChip({
    required String title,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDBE4F0)),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: accentColor,
        ),
      ),
    );
  }

  static Widget _miniPlacedChip({
    required String title,
    required int iconCodePoint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDBE4F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            IconData(iconCodePoint, fontFamily: 'MaterialIcons'),
            size: 10,
            color: const Color(0xFF111827),
          ),
          const SizedBox(width: 3),
          Text(
            title,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  static Color _accentColor(String style) {
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
      case 'Ручной режим':
        return const Color(0xFF1F2A37);
      default:
        return const Color(0xFF2E90FA);
    }
  }

  static Color _overlayColor(String style) {
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

  static Widget _bigCard({
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 420,
      child: _HoverLift(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color,
                  const Color(0xFF0F1A34),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A5EC7FF),
                  blurRadius: 22,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFFD7E4F8),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF2E90FA)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _smallCard({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 420,
      child: _HoverLift(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.edit_note_rounded, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFFB5C5DA),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
