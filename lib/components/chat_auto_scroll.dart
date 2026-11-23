import 'package:flutter/material.dart';

/// Keeps a chat on its newest message while answers type out and cards
/// appear. Once the parent scrolls up to reread, it stops following and shows
/// a button to jump back down.
class ChatAutoScroll extends StatefulWidget {
  const ChatAutoScroll({
    super.key,
    required this.controller,
    required this.userMessageCount,
    required this.child,
  });

  /// The controller of [child], a vertical scroll view.
  final ScrollController controller;

  /// When this goes up the parent just sent something, so the chat follows
  /// the newest message again.
  final int userMessageCount;

  final Widget child;

  @override
  State<ChatAutoScroll> createState() => _ChatAutoScrollState();
}

class _ChatAutoScrollState extends State<ChatAutoScroll> {
  /// Closer than this to the end still counts as "at the bottom".
  static const double _stickSlop = 48;
  static const double _showButtonAfter = 240;

  bool _stick = true;
  bool _showButton = false;
  double? _lastMaxExtent;
  double? _lastViewport;

  @override
  void didUpdateWidget(ChatAutoScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userMessageCount > oldWidget.userMessageCount) {
      _stick = true;
      // A message added below the screen doesn't always change the measured
      // size, so follow once that frame is laid out.
      WidgetsBinding.instance
        ..addPostFrameCallback((_) => _follow())
        ..ensureVisualUpdate();
    }
  }

  bool _onScroll(ScrollNotification n) {
    // Depth 0 only: ignore horizontal lists (student cards) inside bubbles.
    if (n.depth != 0) return false;
    final distance = n.metrics.maxScrollExtent - n.metrics.pixels;
    if (n is ScrollUpdateNotification && n.dragDetails != null) {
      _stick = distance < _stickSlop;
    } else if (n is ScrollEndNotification && distance < _stickSlop) {
      _stick = true;
    }
    _setButton(distance > _showButtonAfter);
    return false;
  }

  bool _onMetrics(ScrollMetricsNotification n) {
    if (n.depth != 0 || !widget.controller.hasClients) return false;
    // Flutter also sends this after every scroll; only a change in content or
    // viewport size means something new to follow.
    final resized = n.metrics.maxScrollExtent != _lastMaxExtent ||
        n.metrics.viewportDimension != _lastViewport;
    _lastMaxExtent = n.metrics.maxScrollExtent;
    _lastViewport = n.metrics.viewportDimension;
    if (resized) _follow();
    final position = widget.controller.position;
    _setButton(position.maxScrollExtent - position.pixels > _showButtonAfter);
    return false;
  }

  /// Jumps to the end if following. Safe here because metrics notifications
  /// arrive after the frame; a drag or fling in progress is never interrupted.
  void _follow() {
    if (!mounted || !_stick || !widget.controller.hasClients) return;
    final position = widget.controller.position;
    if (position.isScrollingNotifier.value) return;
    if (position.pixels < position.maxScrollExtent) {
      position.jumpTo(position.maxScrollExtent);
    }
  }

  void _setButton(bool show) {
    if (show == _showButton) return;
    // Scroll notifications can arrive during layout, so rebuild after the
    // frame, and make sure that frame happens.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted && show != _showButton) setState(() => _showButton = show);
      })
      ..ensureVisualUpdate();
  }

  void _jumpToLatest() {
    _stick = true;
    if (!widget.controller.hasClients) return;
    widget.controller
        .animateTo(
          widget.controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        )
        // Content that grew during the animation was skipped; catch up.
        .then((_) => _follow());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<ScrollMetricsNotification>(
          onNotification: _onMetrics,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: widget.child,
          ),
        ),
        Positioned(
          right: 14,
          bottom: 12,
          child: AnimatedScale(
            scale: _showButton ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: Semantics(
              button: true,
              label: 'Jump to latest message',
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                shadowColor: Colors.black26,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _jumpToLatest,
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF0019CD),
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
