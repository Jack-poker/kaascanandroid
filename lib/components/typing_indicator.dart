import 'package:flutter/material.dart';
import 'package:kaascan/widgets/cached_network_image_wrapper.dart';

/// An animated typing indicator with bouncing dots and AI avatar.
class TypingIndicator extends StatefulWidget {
  final String? avatarUrl;
  final String? senderName;

  const TypingIndicator({
    super.key,
    this.avatarUrl,
    this.senderName,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _dotAnimations = List.generate(3, (i) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            i * 0.15,
            0.4 + i * 0.15,
            curve: Curves.easeInOutSine,
          ),
        ),
      );
    });

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 48, top: 4, bottom: 4),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: Offset.zero,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: 1.0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI Avatar
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurpleAccent.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: widget.avatarUrl != null &&
                          widget.avatarUrl!.isNotEmpty
                      ? CachedNetworkImageWrapper(
                          imageUrl: widget.avatarUrl!,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(16),
                          errorWidget: const Icon(
                            Icons.smart_toy,
                            color: Colors.white,
                            size: 18,
                          ),
                        )
                      : const Icon(
                          Icons.smart_toy,
                          color: Colors.white,
                          size: 18,
                        ),
                ),
              ),
              const SizedBox(width: 8),
              // Typing bubble
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < 3; i++) _buildDot(i),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _dotAnimations[index],
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.only(right: 5),
          child: Transform.translate(
            offset: Offset(0, -4 * _dotAnimations[index].value),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,color: Colors.deepPurpleAccent.withValues(
                    alpha: 0.3 + 0.5 * _dotAnimations[index].value,
                  ),
              ),
            ),
          ),
        );
      },
    );
  }
}
