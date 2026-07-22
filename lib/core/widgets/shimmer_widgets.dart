import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_colors.dart';

// ─── Base shimmer box ──────────────────────────────────────────────────────────
Widget _shimmerBox({double? width, double? height, double radius = 10, BoxShape shape = BoxShape.rectangle}) {
  return Shimmer.fromColors(
    baseColor: const Color(0xFFE8E8E8),
    highlightColor: const Color(0xFFF5F5F5),
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(radius) : null,
      ),
    ),
  );
}

// ─── Note Card Shimmer ─────────────────────────────────────────────────────────
class NoteCardShimmer extends StatelessWidget {
  const NoteCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          _shimmerBox(width: 52, height: 52, radius: 14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(height: 14, radius: 6),
                const SizedBox(height: 8),
                _shimmerBox(height: 11, width: 160, radius: 6),
                const SizedBox(height: 8),
                Row(children: [
                  _shimmerBox(width: 60, height: 22, radius: 11),
                  const SizedBox(width: 8),
                  _shimmerBox(width: 50, height: 22, radius: 11),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Note List Shimmer (multiple cards) ───────────────────────────────────────
class NoteListShimmer extends StatelessWidget {
  final int count;
  const NoteListShimmer({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      itemBuilder: (_, __) => const NoteCardShimmer(),
    );
  }
}

// ─── Banner Shimmer ────────────────────────────────────────────────────────────
class BannerShimmer extends StatelessWidget {
  const BannerShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.primary.withOpacity(0.3),
      highlightColor: AppColors.primary.withOpacity(0.5),
      child: Container(
        height: 160,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}

// ─── Course Card Shimmer ───────────────────────────────────────────────────────
class CourseCardShimmer extends StatelessWidget {
  const CourseCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 152,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFE0E0E0),
        highlightColor: const Color(0xFFF0F0F0),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmerBox(width: 46, height: 46, radius: 14),
              const SizedBox(height: 10),
              _shimmerBox(height: 13, radius: 6),
              const SizedBox(height: 6),
              _shimmerBox(width: 80, height: 10, radius: 6),
              const Spacer(),
              _shimmerBox(height: 5, radius: 3),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Profile Header Shimmer ────────────────────────────────────────────────────
class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8E8E8),
      highlightColor: const Color(0xFFF5F5F5),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            _shimmerBox(width: 68, height: 68, shape: BoxShape.circle),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBox(height: 16, width: 140, radius: 8),
                  const SizedBox(height: 8),
                  _shimmerBox(height: 12, width: 100, radius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Community Post Shimmer ────────────────────────────────────────────────────
class CommunityPostShimmer extends StatelessWidget {
  const CommunityPostShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _shimmerBox(width: 40, height: 40, shape: BoxShape.circle),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _shimmerBox(width: 120, height: 12, radius: 6),
              const SizedBox(height: 6),
              _shimmerBox(width: 80, height: 10, radius: 6),
            ]),
          ]),
          const SizedBox(height: 14),
          Shimmer.fromColors(
            baseColor: const Color(0xFFE8E8E8),
            highlightColor: const Color(0xFFF5F5F5),
            child: Column(children: [
              _shimmerBox(height: 12, radius: 6),
              const SizedBox(height: 6),
              _shimmerBox(height: 12, width: 260, radius: 6),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─── Home Hero Shimmer ─────────────────────────────────────────────────────────
class HeroShimmer extends StatelessWidget {
  const HeroShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.primary.withOpacity(0.4),
      highlightColor: AppColors.primary.withOpacity(0.6),
      child: Container(
        height: 150,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(28),
        ),
      ),
    );
  }
}
