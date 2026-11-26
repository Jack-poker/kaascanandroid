import 'package:kaascan/components/soma_robot.dart';
import 'dart:async';
import 'package:flutter/material.dart';

/// Smart thinking indicator with rotating Kinyarwanda phrases and
/// animated dots. Cycles through contextual status messages so the
/// user stays engaged while Soma AI prepares a response.
class TypingIndicator extends StatefulWidget {
  final String? avatarUrl;
  final String? senderName;

  /// Optional status lines. Defaults to playful Kinyarwanda phrases.
  final List<String>? phrases;

  /// The robot's face while it thinks — playful by default.
  final SomaMood mood;

  const TypingIndicator({
    super.key,
    this.avatarUrl,
    this.senderName,
    this.phrases,
    this.mood = SomaMood.thinking,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  // ── dot animation ──────────────────────────────────────────────────────────
  late AnimationController _dotController;
  late List<Animation<double>> _dotAnimations;

  // ── phrase rotation ────────────────────────────────────────────────────────
  static const _phrases = [
    'Ndigusoma indanga manota',
    'Kureba amakuru',
    'Kureba ibihembye byose',
    'Ndiriwaza neza...',
    'Ntegura igisubizo cyiza...',
  ];

  int _phraseIndex = 0;
  double _phraseOpacity = 1.0;
  Timer? _phraseTimer;

  @override
  void initState() {
    super.initState();

    // Dots bounce animation
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _dotAnimations = List.generate(3, (i) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _dotController,
          curve: Interval(
            i * 0.15,
            0.4 + i * 0.15,
            curve: Curves.easeInOutSine,
          ),
        ),
      );
    });

    // Phrase cycling — fade out → swap text → fade in every 2.4 s
    _phraseTimer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
      if (!mounted) return;
      setState(() => _phraseOpacity = 0.0);
      Future.delayed(const Duration(milliseconds: 280), () {
        if (!mounted) return;
        final count = widget.phrases?.length ?? _phrases.length;
        if (count == 0) return;
        setState(() {
          _phraseIndex = (_phraseIndex + 1) % count;
          _phraseOpacity = 1.0;
        });
      });
    });
  }

  @override
  void dispose() {
    _dotController.dispose();
    _phraseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phrases = widget.phrases ?? _phrases;
    final index = phrases.isEmpty ? 0 : _phraseIndex % phrases.length;
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 48, top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SomaAvatar(mood: widget.mood),

          const SizedBox(width: 8),

          // ── thinking bubble ───────────────────────────────────────────────
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Rotating phrase
                  AnimatedOpacity(
                    opacity: _phraseOpacity,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOut,
                    child: Text(
                      phrases.isEmpty ? '' : phrases[index],
                      style: const TextStyle(
                        color: Color(0xFF0019CD),
                        fontFamily: 'minigap',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Bouncing dots
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, _buildDot),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _dotAnimations[index],
      builder: (context, _) {
        final v = _dotAnimations[index].value;
        return Padding(
          padding: const EdgeInsets.only(right: 5),
          child: Transform.translate(
            offset: Offset(0, -5 * v),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(
                  const Color(0xFF90A4D4).withValues(alpha: 0.5),
                  const Color(0xFF0019CD),
                  v,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
