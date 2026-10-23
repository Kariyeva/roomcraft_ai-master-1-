// ignore_for_file: file_names
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/studio_components.dart';

/// Public entry point. Existing route and class are retained for compatibility.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _processKey = GlobalKey();
  final _conceptsKey = GlobalKey();
  final _professionalsKey = GlobalKey();

  void _start() => Navigator.pushNamed(context, '/login');

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 550),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 900;
            final gutter = desktop ? 56.0 : 22.0;
            return SelectionArea(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: gutter,
                            vertical: 18,
                          ),
                          child: Row(
                            children: [
                              const Expanded(child: _Wordmark()),
                              if (desktop) ...[
                                TextButton(
                                  onPressed: () => _scrollTo(_conceptsKey),
                                  child: const Text('Концепции'),
                                ),
                                TextButton(
                                  onPressed: () => _scrollTo(_processKey),
                                  child: const Text('Как это работает'),
                                ),
                                TextButton(
                                  onPressed: () => _scrollTo(_professionalsKey),
                                  child: const Text('Для студий'),
                                ),
                                const SizedBox(width: 32),
                              ],
                              TextButton(
                                onPressed: _start,
                                child: const Text('Войти ↗'),
                              ),
                              if (!desktop)
                                PopupMenuButton<String>(
                                  tooltip: 'Навигация',
                                  icon: const Icon(Icons.menu, size: 22),
                                  onSelected: (value) =>
                                      _scrollTo(switch (value) {
                                        'concepts' => _conceptsKey,
                                        'process' => _processKey,
                                        _ => _professionalsKey,
                                      }),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'concepts',
                                      child: Text('Концепции'),
                                    ),
                                    PopupMenuItem(
                                      value: 'process',
                                      child: Text('Как это работает'),
                                    ),
                                    PopupMenuItem(
                                      value: 'studio',
                                      child: Text('Для студий'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        _hero(desktop, gutter),
                        Padding(
                          padding: EdgeInsets.all(gutter),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _concepts(desktop),
                              const SizedBox(height: 76),
                              _process(desktop),
                              const SizedBox(height: 76),
                              _professionals(desktop),
                              const SizedBox(height: 76),
                              _finalCta(desktop),
                              const SizedBox(height: 64),
                              const Divider(),
                              const SizedBox(height: 24),
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                spacing: 32,
                                runSpacing: 20,
                                children: [
                                  const _Wordmark(),
                                  const Text(
                                    'Инструмент для ваших идей.\nАлматы, Казахстан',
                                    style: AppText.body,
                                  ),
                                  TextButton(
                                    onPressed: () => _scrollTo(_processKey),
                                    child: const Text('О платформе ↑'),
                                  ),
                                  const Text(
                                    '© 2026 RoomCraft AI',
                                    style: AppText.body,
                                  ),
                                ],
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
          },
        ),
      ),
    );
  }

  Widget _hero(bool desktop, double gutter) {
    final intro = Padding(
      padding: EdgeInsets.all(desktop ? 48 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ИНТЕРЬЕРЫ, В КОТОРЫХ ХОЧЕТСЯ ЖИТЬ', style: AppText.label),
          SizedBox(height: desktop ? 44 : 30),
          Text(
            'Пространство\nначинается\nс идеи.',
            style: AppText.display.copyWith(
              fontSize: desktop ? 62 : 43,
              letterSpacing: desktop ? -2.5 : -1.5,
            ),
          ),
          const SizedBox(height: 26),
          const ConstrainedBody(
            'Интеллектуальная платформа для создания, визуализации и согласования интерьерных концепций.',
          ),
          const SizedBox(height: 32),
          StudioButton(label: 'Создать дизайн  ↗', onPressed: _start),
          const SizedBox(height: 22),
          const Text('ВАШЕ ПРОСТРАНСТВО. ВАШ ВЗГЛЯД.', style: AppText.label),
        ],
      ),
    );
    final photo = Stack(
      children: [
        const Positioned.fill(
          child: _InteriorImage(
            asset: 'assets/images/hero-interior.jpg',
            description:
                'Светлая гостиная с натуральным деревом и мягкой мебелью',
          ),
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.paper,
            child: const Text('01 / ТИХАЯ РОСКОШЬ', style: AppText.label),
          ),
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: desktop ? gutter : 0),
      child: Container(
        color: AppColors.sand,
        child: desktop
            ? Row(
                children: [
                  Expanded(flex: 5, child: intro),
                  Expanded(flex: 6, child: SizedBox(height: 650, child: photo)),
                ],
              )
            : Column(
                children: [
                  intro,
                  SizedBox(height: 320, child: photo),
                ],
              ),
      ),
    );
  }

  Widget _concepts(bool desktop) => Column(
    key: _conceptsKey,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionLabel(number: '01', text: 'ИЗБРАННЫЕ КОНЦЕПЦИИ'),
      const SizedBox(height: 18),
      Text(
        'Разные характеры.\nОщущение дома — одно.',
        style: AppText.heading.copyWith(fontSize: desktop ? 38 : 29),
      ),
      const SizedBox(height: 12),
      const Text(
        'Визуальные ориентиры стилей · интерьерная фотография',
        style: AppText.body,
      ),
      const SizedBox(height: 30),
      if (desktop)
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _Concept(
                asset: 'assets/images/concept-stone.jpg',
                title: 'Естественный баланс',
                subtitle: '01 / МИНИМАЛИЗМ · КАМЕНЬ И СВЕТ',
                ratio: 0.95,
              ),
            ),
            SizedBox(width: 28),
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  _Concept(
                    asset: 'assets/images/concept-warm.jpg',
                    title: 'Тёплая геометрия',
                    subtitle: '02 / СОВРЕМЕННЫЙ · ПРИРОДНЫЕ ФАКТУРЫ',
                    ratio: 1.95,
                  ),
                  SizedBox(height: 28),
                  _Concept(
                    asset: 'assets/images/hero-interior.jpg',
                    title: 'Искусство простоты',
                    subtitle: '03 / СКАНДИНАВСКИЙ · МЯГКИЕ ТОНА',
                    ratio: 2.6,
                  ),
                ],
              ),
            ),
          ],
        )
      else
        const Column(
          children: [
            _Concept(
              asset: 'assets/images/concept-stone.jpg',
              title: 'Естественный баланс',
              subtitle: '01 / МИНИМАЛИЗМ · КАМЕНЬ И СВЕТ',
              ratio: 1.15,
            ),
            SizedBox(height: 28),
            _Concept(
              asset: 'assets/images/concept-warm.jpg',
              title: 'Тёплая геометрия',
              subtitle: '02 / СОВРЕМЕННЫЙ · ПРИРОДНЫЕ ФАКТУРЫ',
              ratio: 1.2,
            ),
            SizedBox(height: 28),
            _Concept(
              asset: 'assets/images/hero-interior.jpg',
              title: 'Искусство простоты',
              subtitle: '03 / СКАНДИНАВСКИЙ · МЯГКИЕ ТОНА',
              ratio: 1.2,
            ),
          ],
        ),
    ],
  );

  Widget _process(bool desktop) {
    const steps = [
      ('01', 'Взгляд на пространство', 'Загрузите фотографию помещения.'),
      ('02', 'Ваш характер', 'Укажите стиль и пожелания к интерьеру.'),
      ('03', 'Новая перспектива', 'Получите варианты интерьерной концепции.'),
      ('04', 'Последний штрих', 'Отредактируйте и сохраните результат.'),
    ];
    return Column(
      key: _processKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 28),
        const _SectionLabel(number: '02', text: 'ОТ ФОТОГРАФИИ К ИДЕЕ'),
        const SizedBox(height: 30),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = desktop ? 4 : (constraints.maxWidth >= 550 ? 2 : 1);
            return Wrap(
              spacing: 24,
              runSpacing: 28,
              children: steps
                  .map(
                    (step) => SizedBox(
                      width:
                          (constraints.maxWidth - 24 * (columns - 1)) / columns,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.$1,
                            style: AppText.display.copyWith(
                              fontSize: 46,
                              color: AppColors.stone,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(step.$2, style: const TextStyle(fontSize: 17)),
                          const SizedBox(height: 10),
                          Text(step.$3, style: AppText.body),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _professionals(bool desktop) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(number: '03', text: 'ДЛЯ ДИЗАЙНЕРОВ И СТУДИЙ'),
        const SizedBox(height: 26),
        Text(
          'Больше пространства\nдля творчества.',
          style: AppText.heading.copyWith(fontSize: desktop ? 38 : 29),
        ),
        const SizedBox(height: 24),
        const Text(
          'Исследуйте визуальные направления, работайте с фотографией помещения и сохраняйте идеи в личной коллекции. От первой мысли до концепции для обсуждения с клиентом.',
          style: AppText.body,
        ),
        const SizedBox(height: 24),
        const Divider(),
        const Text(
          '01   Визуальный поиск на основе вашего помещения',
          style: AppText.body,
        ),
        const Divider(),
        const Text(
          '02   AI-инструменты и ручной 2D-редактор',
          style: AppText.body,
        ),
        const Divider(),
        const Text(
          '03   Сохранённые работы в личном кабинете',
          style: AppText.body,
        ),
        const SizedBox(height: 22),
        TextButton(
          onPressed: _start,
          child: const Text('Открыть рабочее пространство ↗'),
        ),
      ],
    );
    return Container(
      key: _professionalsKey,
      padding: EdgeInsets.all(desktop ? 40 : 24),
      color: AppColors.sand,
      child: desktop
          ? Row(
              children: [
                const Expanded(
                  child: AspectRatio(
                    aspectRatio: 0.95,
                    child: _InteriorImage(
                      asset: 'assets/images/concept-warm.jpg',
                      description: 'Спокойный интерьер в природных оттенках',
                    ),
                  ),
                ),
                const SizedBox(width: 48),
                Expanded(child: text),
              ],
            )
          : text,
    );
  }

  Widget _finalCta(bool desktop) => Column(
    children: [
      const Text('СЛЕДУЮЩАЯ ИДЕЯ — ВАША', style: AppText.label),
      const SizedBox(height: 22),
      Text(
        'Каким будет\nваше пространство?',
        textAlign: TextAlign.center,
        style: AppText.display.copyWith(fontSize: desktop ? 52 : 34),
      ),
      const SizedBox(height: 28),
      FilledButton(onPressed: _start, child: const Text('Начать проект  ↗')),
    ],
  );
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();
  @override
  Widget build(BuildContext context) => const Text(
    'ROOMCRAFT / AI',
    style: TextStyle(
      fontSize: 13,
      letterSpacing: 2.4,
      fontWeight: FontWeight.w600,
    ),
  );
}

class ConstrainedBody extends StatelessWidget {
  const ConstrainedBody(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 360),
    child: Text(text, style: AppText.body),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.number, required this.text});
  final String number;
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text('$number / $text', style: AppText.label);
}

class _Concept extends StatelessWidget {
  const _Concept({
    required this.asset,
    required this.title,
    required this.subtitle,
    required this.ratio,
  });
  final String asset;
  final String title;
  final String subtitle;
  final double ratio;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AspectRatio(
        aspectRatio: ratio,
        child: _InteriorImage(asset: asset, description: title),
      ),
      const SizedBox(height: 16),
      Text(title, style: AppText.heading.copyWith(fontSize: 23)),
      const SizedBox(height: 6),
      Text(subtitle, style: AppText.label),
    ],
  );
}

class _InteriorImage extends StatelessWidget {
  const _InteriorImage({required this.asset, required this.description});
  final String asset;
  final String description;
  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    fit: BoxFit.cover,
    width: double.infinity,
    height: double.infinity,
    semanticLabel: description,
    filterQuality: FilterQuality.medium,
    cacheWidth:
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(400, 1800),
    errorBuilder: (_, _, _) => ColoredBox(
      color: AppColors.sand,
      child: Center(child: Text('Фотография недоступна', style: AppText.body)),
    ),
  );
}
