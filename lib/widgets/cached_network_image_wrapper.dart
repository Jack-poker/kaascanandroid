import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A drop-in, silently-failing replacement for [Image.network] that uses the
/// [cached_network_image] package for disk/memory caching.
///
/// All errors are swallowed and rendered as a soft gray placeholder with a
/// person icon. No red error banners, no broken-image icons, and no exception
/// messages are ever shown to the user.
class CachedNetworkImageWrapper extends StatelessWidget {
  const CachedNetworkImageWrapper({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.placeholder,
    this.errorWidget,
    this.fallbackColor,
    this.showLoading = true,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color? fallbackColor;
  final bool showLoading;

  static final _gray = Colors.grey.shade300;
  static final _iconGray = Colors.grey.shade500;

  /// Preloads an image into the [CachedNetworkImage] cache.
  ///
  /// Swallows all errors so callers never need to handle exceptions.
  static Future<void> preload(String url) async {
    try {
      if (url.trim().isEmpty) return;
      final provider = CachedNetworkImageProvider(url);
      // ignore: deprecated_member_use
      await provider.resolve(const ImageConfiguration());
    } catch (_) {
      // Deliberately silent: priming the cache should never surface errors.
    }
  }

  /// Evicts an image from the [CachedNetworkImage] cache.
  ///
  /// Swallows all errors so callers never need to handle exceptions.
  static Future<void> evict(String url) async {
    try {
      if (url.trim().isEmpty) return;
      await CachedNetworkImage.evictFromCache(url);
    } catch (_) {
      // Deliberately silent: cache eviction should never surface errors.
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    try {
      if (imageUrl.trim().isEmpty) {
        child = _buildErrorWidget(context);
      } else {
        child = CachedNetworkImage(
          imageUrl: imageUrl,
          width: width,
          height: height,
          fit: fit,
          placeholder: showLoading
              ? (_, __) => placeholder ?? _buildShimmerPlaceholder(context)
              : (_, __) => _buildShimmerPlaceholder(context, visible: false),
          errorWidget: (_, __, ___) => errorWidget ?? _buildErrorWidget(context),
        );
      }
    } catch (_) {
      child = _buildErrorWidget(context);
    }

    return _applyShape(child);
  }

  Widget _applyShape(Widget child) {
    if (shape == BoxShape.circle) {
      child = ClipOval(child: child);
    }
    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _buildShimmerPlaceholder(BuildContext context, {bool visible = true}) {
    final placeholderWidget = Container(
      width: width,
      height: height,
      color: fallbackColor ?? _gray,
      child: visible ? const _ShimmerEffect() : null,
    );
    return placeholderWidget;
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: fallbackColor ?? _gray,
      child: Icon(
        Icons.person_outline,
        size: _resolveIconSize(),
        color: _iconGray,
      ),
    );
  }

  double _resolveIconSize() {
    final base = width ?? height ?? 48.0;
    return base * 0.4;
  }
}

/// A tiny built-in shimmer effect so we don't need another dependency.
class _ShimmerEffect extends StatefulWidget {
  const _ShimmerEffect();

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade200,
                Colors.grey.shade300,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(
                -1.0 + _controller.value * 2.5,
                0.0,
              ),
              end: Alignment(
                -0.5 + _controller.value * 2.5,
                0.0,
              ),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey.shade300,
      ),
    );
  }
}
