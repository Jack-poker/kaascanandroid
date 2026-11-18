// Layout checks for the withdraw flow: every screen and dialog must fit
// (or scroll) on small and large phones, with and without the keyboard.
// Any RenderFlex overflow fails the test.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/components/student_withdraw.dart';
import 'package:kaascan/components/withdraw.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers the student-withdraw options call with fixed data.
class _FakeClient extends backendClient {
  final bool needsApproval;
  _FakeClient({required this.needsApproval});

  @override
  Future<Response> studentWithdrawOptions(String token, String studentId) async => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: {
          'student_id': studentId,
          'student_name': 'Emmanuel Dutuze Kwizera Long Name',
          'balance': 17900,
          'min': 100,
          'max': 5000000,
          'phone': '078****456',
          'network': 'MTN',
          'available': true,
          'needs_approval': needsApproval,
          'note': needsApproval
              ? 'Part of this money came in by bank card, so our team approves the payout first (usually within a few hours).'
              : 'Sent to your Mobile Money right away.',
        },
      );
}

const _phones = <String, Size>{
  'small 320x568': Size(320, 568),
  'medium 360x640': Size(360, 640),
  'pixel 3a xl 411x823': Size(411, 823),
};

Future<void> _pump(
  WidgetTester tester,
  Size size,
  Widget child, {
  double keyboard = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump(const Duration(milliseconds: 500));
}

/// The dashboard shows WithdrawPage in a sheet 92% of the screen tall,
/// below a 25px drag-handle strip.
Widget _sheet(Size size) => Column(
      children: [
        SizedBox(height: size.height * 0.08 + 25),
        const Expanded(child: WithdrawPage()),
      ],
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'login_token': 't'}));

  testWidgets('withdraw page fits with large system text', (tester) async {
    const size = Size(360, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester, size, _sheet(size));
    expect(tester.takeException(), isNull);
  });

  for (final entry in _phones.entries) {
    for (final approval in [false, true]) {
      testWidgets(
          'student withdraw sheet fits on ${entry.key} (approval: $approval)',
          (tester) async {
        await _pump(
          tester,
          entry.value,
          Align(
            alignment: Alignment.bottomCenter,
            child: StudentWithdrawSheet(
              student: const {'student_id': 'S1', 'student_name': 'Emmanuel'},
              client: _FakeClient(needsApproval: approval),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text(approval ? 'Request withdrawal' : 'Withdraw to Mobile Money'), findsOneWidget);
      });
    }

    testWidgets('withdraw page fits on ${entry.key}', (tester) async {
      await _pump(tester, entry.value, _sheet(entry.value));
      expect(tester.takeException(), isNull);
      expect(find.text('Bikuza cash'), findsOneWidget);
    });

    testWidgets('bank details dialog fits with keyboard on ${entry.key}',
        (tester) async {
      await _pump(
        tester,
        entry.value,
        const Dialog(child: BankDetailsDialog()),
        keyboard: entry.value.height * 0.4,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('otp dialog fits with keyboard on ${entry.key}',
        (tester) async {
      await _pump(
        tester,
        entry.value,
        Dialog(
          backgroundColor: Colors.transparent,
          child: OtpDialog(
            token: 't',
            amount: 1000,
            app: backendClient(),
            phone: '',
          ),
        ),
        keyboard: entry.value.height * 0.4,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
