import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Static Native Splash UI matching the native launch screen.
/// Completely static with zero background animations, rings, or floating tickers.
class SplashUI extends StatelessWidget {
  const SplashUI({super.key});

  @override
  Widget build(BuildContext context) {
    // Web: show gradient splash instead of asset image (avoids white screen)
    if (kIsWeb) {
      return const Scaffold(
        body: SizedBox.expand(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6A4FE8), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_rounded, size: 72, color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'StudySphere',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your Smart Study Companion',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Mobile: use native splash asset
    return Scaffold(
      body: SizedBox.expand(
        child: Image.asset(
          'assets/splash_bg.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
