import 'package:flutter/material.dart';

import 'package:kaascan/components/soma_robot.dart';

/// Bottom-nav geometry shared with DashboardNav, so the connector always
/// lands on the robot tab.
class SomaNavGeometry {
  SomaNavGeometry._();

  static const double sideMargin = 24;
  static const double itemSize = 48;
  static const int itemCount = 3;
  static const Color appBlue = Color(0xFF0022FF);

  /// Centre x of the robot tab (first item of a spaceEvenly row).
  static double robotCenterX(double screenWidth) {
    final bar = screenWidth - sideMargin * 2;
    final gap = (bar - itemSize * itemCount) / (itemCount + 1);
    return sideMargin + gap + itemSize / 2;
  }

  /// Bar fill for an accent: a light tint; the app blue keeps its original.
  static Color barColor(Color accent) => accent == appBlue
      ? const Color.fromARGB(255, 191, 210, 255)
      : Color.lerp(accent, Colors.white, 0.75)!;
}

/// The liquid neck joining the chat input (above) to the robot tab on the
/// bottom nav (below). While Soma thinks, a light travels up it.
class SomaNavConnector extends StatefulWidget {
  const SomaNavConnector({
    super.key,
    this.height = 20,
    this.waiting = false,
  });

  final double height;
  final bool waiting;

  @override
  State<SomaNavConnector> createState() => _SomaNavConnectorState();
}

class _SomaNavConnectorState extends State<SomaNavConnector>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(SomaNavConnector old) {
    super.didUpdateWidget(old);
    if (old.waiting != widget.waiting) _sync();
  }

  void _sync() {
    if (widget.waiting) {
      _pulse.repeat();
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: ListenableBuilder(
          listenable: Listenable.merge([SomaRobotTheme.background, _pulse]),
          builder: (context, _) {
            final accent = SomaRobotTheme.background.value.color;
            return CustomPaint(
              painter: _NeckPainter(
                top: Colors.white,
                bottom: SomaNavGeometry.barColor(accent),
                glow: accent,
                progress: widget.waiting ? _pulse.value : null,
                centerX: SomaNavGeometry.robotCenterX(
                    MediaQuery.sizeOf(context).width),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NeckPainter extends CustomPainter {
  _NeckPainter({
    required this.top,
    required this.bottom,
    required this.glow,
    required this.progress,
    required this.centerX,
  });

  final Color top;
  final Color bottom;
  final Color glow;
  final double? progress;
  final double centerX;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final cx = centerX;
    const neck = 11.0; // half-width at the narrowest point
    final fillet = h * 0.9; // how far the curves flare into each surface

    // Two concave flares meeting at a narrow waist: like two drops merging.
    final path = Path()
      ..moveTo(cx - neck - fillet, 0)
      ..quadraticBezierTo(cx - neck, 0, cx - neck, h / 2)
      ..quadraticBezierTo(cx - neck, h, cx - neck - fillet, h)
      ..lineTo(cx + neck + fillet, h)
      ..quadraticBezierTo(cx + neck, h, cx + neck, h / 2)
      ..quadraticBezierTo(cx + neck, 0, cx + neck + fillet, 0)
      ..close();

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      ).createShader(Rect.fromLTWH(0, -1, size.width, h + 2));
    canvas.drawPath(path, fill);
    // Bleed a pixel into both surfaces so no hairline seam shows.
    final span = (neck + fillet) * 2;
    canvas.drawRect(
        Rect.fromLTWH(cx - neck - fillet, -1, span, 1.5), Paint()..color = top);
    canvas.drawRect(Rect.fromLTWH(cx - neck - fillet, h - 0.5, span, 1.5),
        Paint()..color = bottom);

    // Thinking: a soft light rises from the robot tab into the chat input.
    final p = progress;
    if (p != null) {
      final y = h - p * h;
      final fade = p < 0.8 ? 1.0 : (1 - p) / 0.2;
      canvas.drawCircle(
        Offset(cx, y),
        4.5,
        Paint()
          ..color = glow.withValues(alpha: 0.35 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        Offset(cx, y),
        2.5,
        Paint()..color = glow.withValues(alpha: 0.9 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_NeckPainter old) =>
      old.progress != progress ||
      old.top != top ||
      old.bottom != bottom ||
      old.glow != glow ||
      old.centerX != centerX;
}
