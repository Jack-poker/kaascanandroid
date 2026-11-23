import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaascan/screens/savings_screen.dart';

/// Renders the savings card and page with sample data. Set SAVINGS_SHOTS to a
/// folder to also save PNG screenshots there.
SavingsData sample({bool empty = false}) {
  final now = DateTime.now().toUtc();
  return SavingsData({
    'student_id': 'S1',
    'student_name': 'Keza Uwase',
    'saved': empty ? 0 : 1850,
    'auto_save': {'on': true, 'reason': '', 'rate': 5.0, 'min_purchase': 50, 'max_per_purchase': 500},
    'this_week': empty ? 0 : 350,
    'this_month': empty ? 0 : 900,
    'total_put_aside': empty ? 0 : 2050,
    'times_saved': empty ? 0 : 23,
    'weeks': [
      for (var i = 7; i >= 0; i--)
        {
          'week_start': now.subtract(Duration(days: 7 * i)).toIso8601String().substring(0, 10),
          'amount': empty ? 0 : [120, 300, 0, 260, 410, 180, 240, 350][7 - i],
        }
    ],
    'milestone': {'previous': 1000, 'next': 2500, 'progress': empty ? 0 : 0.5667},
    'events': empty
        ? []
        : [
            {'kind': 'saved', 'amount': 50, 'purchase': 1000, 'merchant': 'Canteen GS', 'rate': 5, 'at': now.toIso8601String()},
            {'kind': 'saved', 'amount': 75, 'purchase': 1500, 'merchant': 'Book shop', 'rate': 5, 'at': now.subtract(const Duration(days: 1)).toIso8601String()},
            {'kind': 'released', 'amount': 200, 'purchase': 0, 'merchant': 'Released to card', 'rate': 0, 'at': now.subtract(const Duration(days: 9)).toIso8601String()},
          ],
  });
}

Future<void> _loadFonts() async {
  for (final (family, file) in [('gilroy', 'fonts/gilroy-semibold.ttf'), ('gilroy-light', 'fonts/Gilroy-Light.otf')]) {
    final loader = FontLoader(family)..addFont(rootBundle.load(file));
    await loader.load();
  }
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  final dir = Platform.environment['SAVINGS_SHOTS'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Soma's sound player: no audio in tests.
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global',
                      'xyz.luan/audioplayers.global/events']) {
      m.setMockMethodCallHandler(MethodChannel(ch), (_) async => null);
    }
  });

  Future<void> render(WidgetTester tester, Widget child, String name, {double height = 2000}) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = Size(390, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(key: key, child: child),
    ));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(seconds: 2));
    // The language service creates a sound player at start-up; tests have no audio plugin.
    final e = tester.takeException();
    if (e != null && !'$e'.contains('audioplayers')) fail('$e');
    await _shot(tester, key, name);
  }

  testWidgets('savings page draws with savings', (tester) async {
    await render(tester, SavingsScreen(studentId: 'S1', studentName: 'Keza Uwase', data: sample()), 'savings_page');
    expect(find.text('Keza has saved'), findsOneWidget);
    expect(find.text('How saving works'), findsOneWidget);
    expect(find.text('Last 8 weeks'), findsOneWidget);
  });

  testWidgets('savings page draws with nothing saved yet', (tester) async {
    await render(tester, SavingsScreen(studentId: 'S1', studentName: 'Keza Uwase', data: sample(empty: true)), 'savings_empty');
    expect(find.textContaining('No savings yet'), findsOneWidget);
  });

  testWidgets('students page savings card draws', (tester) async {
    await render(
      tester,
      Scaffold(
        backgroundColor: const Color(0xFF0022FF),
        body: Center(child: SavingsPreviewCard(studentId: 'S1', studentName: 'Keza Uwase', data: sample())),
      ),
      'savings_card',
      height: 420,
    );
    expect(find.text('Savings'), findsOneWidget);
  });
}
