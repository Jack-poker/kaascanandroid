import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:kaascan/components/soma_robot.dart';

/// The chat background: the parent's chosen colour with faint doodles,
/// both following [SomaRobotTheme].
class SomaChatBackground extends StatelessWidget {
  const SomaChatBackground({
    super.key,
    this.child,
    this.background,
    this.doodle,
    this.cell = 72,
  });

  final Widget? child;
  /// Fixed values for previews; otherwise the parent's saved choice.
  final SomaBackgroundColor? background;
  final SomaDoodle? doodle;
  /// Spacing between doodles; smaller for small previews.
  final double cell;

  @override
  Widget build(BuildContext context) {
    SomaRobotTheme.ensureLoaded();
    return ListenableBuilder(
      listenable: SomaRobotTheme.all,
      builder: (_, __) {
        final bg = background ?? SomaRobotTheme.background.value;
        final set = doodle ?? SomaRobotTheme.doodle.value;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          color: bg.color,
          child: Stack(
            children: [
              if (set.icons.isNotEmpty)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _DoodlePainter(
                        icons: set.icons,
                        color: Colors.white.withValues(alpha: 0.09),
                        cell: cell,
                      ),
                    ),
                  ),
                ),
              if (child != null) Positioned.fill(child: child!),
            ],
          ),
        );
      },
    );
  }
}

class _DoodlePainter extends CustomPainter {
  _DoodlePainter({
    required this.icons,
    required this.color,
    required this.cell,
  });

  final List<IconData> icons;
  final Color color;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final cols = (size.width / cell).ceil() + 1;
    final rows = (size.height / cell).ceil() + 1;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        // Seeded per cell so the pattern is identical on every repaint.
        final rnd = math.Random(r * 7919 + c * 104729);
        final icon = icons[rnd.nextInt(icons.length)];
        final glyph = cell * (0.32 + rnd.nextDouble() * 0.12);
        final stagger = r.isOdd ? cell / 2 : 0.0;
        final x = c * cell + stagger + (rnd.nextDouble() - 0.5) * cell * 0.25;
        final y = r * cell + (rnd.nextDouble() - 0.5) * cell * 0.25;
        final angle = (rnd.nextDouble() - 0.5) * 0.9;

        final tp = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              fontSize: glyph,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angle);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_DoodlePainter old) =>
      old.icons != icons || old.color != color || old.cell != cell;
}
