import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaascan/components/chat_auto_scroll.dart';

/// A chat whose last message grows by setState alone, like the typewriter,
/// with nothing else animating on screen.
class _Chat extends StatefulWidget {
  const _Chat({super.key, required this.controller});
  final ScrollController controller;

  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  final List<double> heights = List.filled(20, 80, growable: true);
  int userMessages = 1;

  void growLast(double by) => setState(() => heights[heights.length - 1] += by);

  void add(double height, {bool user = false}) => setState(() {
        heights.add(height);
        if (user) userMessages++;
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ChatAutoScroll(
          controller: widget.controller,
          userMessageCount: userMessages,
          child: ListView.builder(
            controller: widget.controller,
            itemCount: heights.length,
            itemBuilder: (_, i) => SizedBox(height: heights[i], child: Text('message $i')),
          ),
        ),
      ),
    );
  }
}

void main() {
  late ScrollController controller;
  final chatKey = GlobalKey<_ChatState>();

  double distanceFromEnd() =>
      controller.position.maxScrollExtent - controller.position.pixels;

  double jumpButtonScale(WidgetTester tester) =>
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

  setUp(() => controller = ScrollController());
  tearDown(() => controller.dispose());

  Future<void> openChat(WidgetTester tester) async {
    await tester.pumpWidget(_Chat(key: chatKey, controller: controller));
    await tester.pumpAndSettle();
    expect(distanceFromEnd(), 0, reason: 'opens on the newest message');
  }

  testWidgets('follows an answer as it grows, down to its last line', (tester) async {
    await openChat(tester);
    for (var line = 0; line < 6; line++) {
      chatKey.currentState!.growLast(22);
      await tester.pump(); // the one frame that line causes
      expect(distanceFromEnd(), 0, reason: 'line $line stays in view');
    }
    // The card under a finished answer appears in one go, with no animation
    // left to drive another frame.
    chatKey.currentState!.add(320);
    await tester.pump();
    expect(distanceFromEnd(), 0);
  });

  testWidgets('a slow drag up from the bottom is not pulled back', (tester) async {
    await openChat(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ListView)));
    for (var step = 0; step < 12; step++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump();
      if (step == 6) chatKey.currentState!.growLast(22); // answer still typing
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(distanceFromEnd(), greaterThan(80));
  });

  testWidgets('reading older messages is left alone; the button brings you back', (tester) async {
    await openChat(tester);
    await tester.fling(find.byType(ListView), const Offset(0, 500), 800);
    await tester.pumpAndSettle();
    final readingAt = controller.position.pixels;
    expect(jumpButtonScale(tester), 1);

    chatKey.currentState!.add(120); // a new answer arrives
    await tester.pumpAndSettle();
    expect(controller.position.pixels, readingAt);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();
    expect(distanceFromEnd(), 0);
    expect(jumpButtonScale(tester), 0);
  });

  testWidgets('sending a message returns to the newest message', (tester) async {
    await openChat(tester);
    await tester.fling(find.byType(ListView), const Offset(0, 500), 800);
    await tester.pumpAndSettle();
    expect(distanceFromEnd(), greaterThan(240));

    chatKey.currentState!.add(60, user: true);
    await tester.pump();
    expect(distanceFromEnd(), 0);
  });
}
