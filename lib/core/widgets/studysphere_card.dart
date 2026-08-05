import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum CardStyle { clay, glass }

class StudySphereCard extends StatefulWidget {
  final Widget child;
  final CardStyle style;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  const StudySphereCard({
    super.key,
    required this.child,
    this.style = CardStyle.clay,
    this.borderRadius = 20.0,
    this.padding = const EdgeInsets.all(16.0),
    this.onTap,
    this.color,
  });

  @override
  State<StudySphereCard> createState() => _StudySphereCardState();
}

class _StudySphereCardState extends State<StudySphereCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      padding: widget.padding,
      child: widget.child,
    );

    if (widget.style == CardStyle.clay) {
      cardContent = AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: widget.color ?? AppColors.surface,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: AppColors.border,
            width: 1.5,
          ),
          boxShadow: AppColors.softShadow,
        ),
        child: cardContent,
      );
    } else {
      // Glassmorphism card style
      cardContent = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            decoration: BoxDecoration(
              color: (widget.color ?? Colors.white).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: AppColors.glassShadow,
            ),
            child: cardContent,
          ),
        ),
      );
    }

    if (widget.onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) {
            _controller.reverse();
            widget.onTap!();
          },
          onTapCancel: () => _controller.reverse(),
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: cardContent,
          ),
        ),
      );
    }

    return cardContent;
  }
}
