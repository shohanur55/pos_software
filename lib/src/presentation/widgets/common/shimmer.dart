import 'package:flutter/material.dart';

import '../../theme/theme_extensions.dart';

/// Sweeps a highlight across its child.
///
/// One controller drives the whole subtree, so a list of placeholders shimmers
/// as a single surface instead of each row animating on its own.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled == oldWidget.enabled) return;
    widget.enabled ? _controller.repeat() : _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final highlight = context.color.shimmerHighlight;
    return AnimatedBuilder(
      animation: _controller,
      // The child is built once; only the mask repaints.
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          // Travels from fully off the left edge to fully off the right.
          final offset = _controller.value * 3 - 1;
          return LinearGradient(
            begin: Alignment(offset - 1, -0.4),
            end: Alignment(offset + 1, 0.4),
            colors: [Colors.transparent, highlight, Colors.transparent],
            stops: const [0.38, 0.5, 0.62],
          ).createShader(bounds);
        },
        child: child,
      ),
    );
  }
}

/// A placeholder block in the shape of the content it stands in for.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key, this.width, required this.height, this.radius});

  const ShimmerBox.circle({super.key, required double size})
    : width = size,
      height = size,
      radius = const BorderRadius.all(Radius.circular(999));

  final double? width;
  final double height;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.color.shimmerBase,
        borderRadius: radius ?? context.radius.sm,
      ),
    );
  }
}
