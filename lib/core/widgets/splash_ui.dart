import 'package:flutter/material.dart';

/// Static Native Splash UI matching the native launch screen.
/// Completely static with zero background animations, rings, or floating tickers.
class SplashUI extends StatelessWidget {
  const SplashUI({super.key});

  @override
  Widget build(BuildContext context) {
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
