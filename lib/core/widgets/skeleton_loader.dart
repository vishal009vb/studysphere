import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    this.shape = BoxShape.rectangle,
  });

  const SkeletonLoader.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = 0.0,
        shape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: shape,
          borderRadius: shape == BoxShape.rectangle
              ? BorderRadius.circular(borderRadius)
              : null,
        ),
      ),
    );
  }

  // Pre-configured loading placeholders
  static Widget listTilePlaceholder() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader(width: 50, height: 50, borderRadius: 12),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: double.infinity, height: 16),
                SizedBox(height: 8),
                SkeletonLoader(width: 150, height: 12),
                SizedBox(height: 8),
                Row(
                  children: [
                    SkeletonLoader(width: 40, height: 10),
                    SizedBox(width: 12),
                    SkeletonLoader(width: 40, height: 10),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
