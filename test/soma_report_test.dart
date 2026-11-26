import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaascan/components/soma_report_card.dart';
import 'package:kaascan/services/soma_report.dart';
import 'package:qaad_sdk/qaad_sdk.dart';

void main() {
  test('decodes a report, builds the card map and the PDF', () async {
    final tokens = [
      38, 24, 21, 21, 14, 16, 14, 62, 48, 10, 27, 10, 23, 10, 29, 17, 10, 63,
      49, 34, 10, 23, 35, 10, 63, 7, 8, 6, 5, 4, 8, 63, 0, 7, 8, 8, 6, 3, 9,
      3, 9, 8, 63, 55, 30, 34, 18, 28, 17, 18, 22, 14, 62, 40, 22, 22, 10, 23,
      30, 14, 21, 63, 44, 23, 14, 35, 10, 39, 14, 11, 24, 27, 10, 17, 65, 40,
      30, 35, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
      90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90,
      54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
      90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90,
      54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
      90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90,
      54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
      90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90,
      54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
      90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90,
      54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
      90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90,
      54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
      90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90,
      54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
      90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90,
      54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
      90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90,
      54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
      90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90,
      54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
    ];
    final payload = Comp.compress(tokens);
    final report = SomaReport.decode(payload);

    expect(report.studentName, 'Ineza Deborah');
    expect(report.schoolName, 'College Maranatha');
    expect(report.subjects, isNotEmpty);
    expect(report.overallPercent, closeTo(84.8, 0.6));
    final kinyarwanda =
        report.subjects.firstWhere((s) => s.shortName == 'Kinyarwanda');
    final french = report.subjects.firstWhere((s) => s.shortName == 'French');
    expect(kinyarwanda.displayPercent, closeTo(59.4, 0.6));
    expect(french.displayPercent, closeTo(100, 0.1));
    expect(report.strengths, isNotEmpty);
    expect(report.needsSupport, isNotEmpty);
    expect(report.toUiMap()['subjects'], isA<List>());
    expect(report.toUiMap()['topics'], isA<List>());
    expect(report.agentPrompt('rw'), contains('Ineza Deborah'));
    expect(report.introMessage('rw'), contains('Ineza Deborah'));
    expect(report.introMessage('rw'), contains('?'));
    expect(report.introMessage('rw'), isNot(contains('84.8')));
    expect(SomaReport.thinkingPhrases, contains('Ndigusoma indanga manota'));
    expect(report.topics('rw').map((t) => t['key']),
        ['marks', 'info', 'lessons']);

    final pdf = await report.generatePdf();
    expect(pdf, isNotEmpty);
  });

  testWidgets('report card lays out without overflowing', (tester) async {
    final tokens = [
      38, 24, 21, 21, 14, 16, 14, 62, 48, 10, 27, 10, 23, 10, 29, 17, 10, 63,
      49, 34, 10, 23, 35, 10, 63, 7, 8, 6, 5, 4, 8, 63, 0, 7, 8, 8, 6, 3, 9,
      3, 9, 8, 63, 55, 30, 34, 18, 28, 17, 18, 22, 14, 62, 40, 22, 22, 10, 23,
      30, 14, 21, 63, 44, 23, 14, 35, 10, 39, 14, 11, 24, 27, 10, 17, 65, 40,
      30, 35, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
      90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90,
      54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
      90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90,
      54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
      90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90,
      54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
      90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90,
      54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
      90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90,
      54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
      90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90,
      54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
      90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90,
      54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
      90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90,
      54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
      90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90,
      54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
      90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90,
      54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53, 90, 90, 54, 53,
    ];
    final report = SomaReport.decode(Comp.compress(tokens));
    await tester.binding.setSurfaceSize(const Size(380, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0022FF),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SomaReportCard(
              report: report.toUiMap('en'),
              onSeeReport: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Ineza Deborah'), findsOneWidget);
    expect(find.text('Mathematics'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
