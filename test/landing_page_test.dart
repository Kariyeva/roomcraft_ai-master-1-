import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft_ai/screens/01_splash.dart';
import 'package:roomcraft_ai/theme/app_theme.dart';

void main() {
  for (final width in [320.0, 375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('Landing renders and scrolls at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const SplashScreen(),
          routes: {
            '/login': (_) => const Scaffold(body: Text('Existing login')),
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Создать дизайн  ↗'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Начать проект  ↗'), 500);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Начать проект  ↗'));
      await tester.pumpAndSettle();
      expect(find.text('Existing login'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Mobile navigation scrolls to process section', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SplashScreen()),
    );
    await tester.tap(find.byTooltip('Навигация'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Как это работает'));
    await tester.pumpAndSettle();
    expect(
      find.text('02 / ОТ ФОТОГРАФИИ К ИДЕЕ').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
