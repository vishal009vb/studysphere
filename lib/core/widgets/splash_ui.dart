import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class SplashUI extends StatefulWidget {
  const SplashUI({super.key});

  @override
  State<SplashUI> createState() => _SplashUIState();
}

class _SplashUIState extends State<SplashUI> with TickerProviderStateMixin {
  late final AnimationController _ringController;
  late final AnimationController _pulseController;
  late final AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _ringController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: Stack(
          children: [
            // ── Animated Background Rings ──────────────────────────────────
            AnimatedBuilder(
              animation: _ringController,
              builder: (_, __) {
                return CustomPaint(
                  size: Size(size.width, size.height),
                  painter: _RingPainter(_ringController.value),
                );
              },
            ),

            // ── Floating Orbs ──────────────────────────────────────────────
            Positioned(
              top: size.height * 0.08,
              left: size.width * 0.07,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, _pulseController.value * 18 - 9),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: size.height * 0.12,
              right: size.width * 0.05,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, -_pulseController.value * 22 + 11),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: size.height * 0.35,
              right: -30,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, _pulseController.value * 14 - 7),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ),
            ),

            // ── Star Particles ─────────────────────────────────────────────
            ..._buildParticles(size),

            // ── Main Content ───────────────────────────────────────────────
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo — same image as native splash for seamless transition
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, child) => Container(
                      width: 130 + _pulseController.value * 6,
                      height: 130 + _pulseController.value * 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06 + _pulseController.value * 0.04),
                      ),
                      child: Center(child: child),
                    ),
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: Image.asset('assets/splash_logo.png', fit: BoxFit.contain),
                    ),
                  )
                  .animate()
                  .fadeIn(begin: 1.0, duration: 700.ms, curve: Curves.easeOut)
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1, 1),
                    duration: 800.ms,
                    curve: Curves.elasticOut,
                  ),

                  const SizedBox(height: 36),

                  // App Name
                  Text(
                    'StudySphere',
                    style: GoogleFonts.outfit(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1.5,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 700.ms)
                  .slideY(begin: 0.3, end: 0, delay: 500.ms, duration: 600.ms, curve: Curves.easeOut),

                  const SizedBox(height: 12),

                  // Tagline
                  Text(
                    'Learn Smarter. Grow Faster.',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 750.ms, duration: 600.ms)
                  .slideY(begin: 0.3, end: 0, delay: 750.ms, duration: 600.ms, curve: Curves.easeOut),

                  const SizedBox(height: 70),

                  // Loading dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                      )
                      .animate(
                        onPlay: (c) => c.repeat(),
                        delay: (i * 200).ms,
                      )
                      .scaleXY(begin: 1, end: 1.7, duration: 600.ms, curve: Curves.easeInOut)
                      .then()
                      .scaleXY(begin: 1.7, end: 1, duration: 600.ms, curve: Curves.easeInOut);
                    }),
                  )
                  .animate()
                  .fadeIn(delay: 1000.ms, duration: 600.ms),
                ],
              ),
            ),

            // ── Bottom brand strip ─────────────────────────────────────────
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Text(
                'AI-Powered Learning',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              )
              .animate()
              .fadeIn(delay: 1200.ms, duration: 800.ms),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildParticles(Size size) {
    final positions = [
      [0.15, 0.18],
      [0.78, 0.12],
      [0.45, 0.07],
      [0.88, 0.45],
      [0.05, 0.55],
      [0.65, 0.82],
      [0.25, 0.88],
      [0.92, 0.72],
    ];

    return positions.asMap().entries.map((e) {
      final i = e.key;
      final pos = e.value;
      return Positioned(
        left: size.width * pos[0],
        top: size.height * pos[1],
        child: AnimatedBuilder(
          animation: _particleController,
          builder: (_, __) {
            final t = (_particleController.value + i * 0.13) % 1.0;
            final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2) * 0.7;
            return Opacity(
              opacity: opacity,
              child: Container(
                width: 4 + (i % 3) * 2.0,
                height: 4 + (i % 3) * 2.0,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
      );
    }).toList();
  }
}

class _RingPainter extends CustomPainter {
  final double t;
  _RingPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    void drawRing(double baseRadius, double speed, double alpha) {
      final radius = baseRadius + (t * speed % 1.0) * 80;
      final opacity = (1 - (t * speed % 1.0)) * alpha;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }

    drawRing(80, 0.5, 0.15);
    drawRing(80, 0.8, 0.12);
    drawRing(80, 1.1, 0.09);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t;
}
