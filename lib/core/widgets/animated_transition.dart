import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';

/// Reusable lightweight animations to ensure consistent UI feel
/// while keeping performance high (60 FPS).
class AnimatedTransition {
  static Widget fadeIn(Widget child, {Duration delay = Duration.zero}) {
    return child.animate(delay: delay).fadeIn(duration: 400.ms, curve: Curves.easeOut);
  }

  static Widget slideUp(Widget child, {Duration delay = Duration.zero}) {
    return child.animate(delay: delay)
        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
        .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }

  static Widget scaleIn(Widget child, {Duration delay = Duration.zero}) {
    return child.animate(delay: delay)
        .fadeIn(duration: 300.ms)
        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), duration: 300.ms, curve: Curves.easeOutBack);
  }
}

/// A lightweight skeleton loader for lazy loading states.
class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
