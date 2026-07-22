import 'package:flutter/material.dart';

/// StudySphere Design System — Figma-matched Color System
/// Primary: Lavender Purple #7C72E8
/// Background: #F0EFFF (soft lavender)
class AppColors {
  // ─── Primary (Lavender Purple — Figma exact) ───────────────
  static const Color primary           = Color(0xFF7C72E8); // Figma primary
  static const Color onPrimary         = Color(0xFFFFFFFF);
  static const Color primaryContainer  = Color(0xFF9F97F2); // Lighter purple
  static const Color onPrimaryContainer= Color(0xFFFFFFFF);
  static const Color primaryFixed      = Color(0xFFEEECFF); // Very light purple bg
  static const Color primaryFixedDim   = Color(0xFFD6D3FF);

  // ─── Secondary (Orange accent) ─────────────────────────────
  static const Color secondary          = Color(0xFFFF8C42); // Figma orange
  static const Color onSecondary        = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFFF8C42);
  static const Color onSecondaryContainer=Color(0xFFFFFFFF);
  static const Color secondaryFixed     = Color(0xFFFFF0E8);
  static const Color secondaryFixedDim  = Color(0xFFFFD4B5);

  // ─── Tertiary (Hot Pink) ──────────────────────────────────
  static const Color tertiary           = Color(0xFFE91E8C); // Figma pink
  static const Color onTertiary         = Color(0xFFFFFFFF);
  static const Color tertiaryContainer  = Color(0xFFE91E8C);
  static const Color onTertiaryContainer= Color(0xFFFFFFFF);
  static const Color tertiaryFixed      = Color(0xFFFFE4F3);
  static const Color tertiaryFixedDim   = Color(0xFFFFB3D9);

  // ─── Blue accent ──────────────────────────────────────────
  static const Color blue               = Color(0xFF3B82F6); // Figma blue (AI)
  static const Color blueFixed          = Color(0xFFEFF6FF);

  // ─── Surface & Background ─────────────────────────────────
  static const Color background         = Color(0xFFF0EFFF); // Figma lavender bg
  static const Color surface            = Color(0xFFF0EFFF);
  static const Color surfaceLowest      = Color(0xFFFFFFFF); // White cards
  static const Color surfaceLow         = Color(0xFFF8F7FF);
  static const Color surfaceContainer   = Color(0xFFEEECFF);
  static const Color surfaceHigh        = Color(0xFFE4E2FF);
  static const Color surfaceHighest     = Color(0xFFDDD9FF);
  static const Color surfaceVariant     = Color(0xFFE4E2FF);
  static const Color surfaceDim         = Color(0xFFD4D1F5);

  // ─── Text ─────────────────────────────────────────────────
  static const Color onBackground       = Color(0xFF1A1A2E);
  static const Color onSurface          = Color(0xFF1A1A2E);
  static const Color onSurfaceVariant   = Color(0xFF717182);
  static const Color textPrimary        = Color(0xFF1A1A2E);
  static const Color textSecondary      = Color(0xFF717182);

  // ─── Borders & Outline ────────────────────────────────────
  static const Color outline            = Color(0xFF9B9ABD);
  static const Color outlineVariant     = Color(0xFFE4E2FF);
  static const Color border             = Color(0xFFE4E2FF); // Figma border color

  // ─── Semantic ─────────────────────────────────────────────
  static const Color success            = Color(0xFF22C55E);
  static const Color warning            = Color(0xFFF59E0B);
  static const Color error              = Color(0xFFD4183D);
  static const Color accent             = Color(0xFF7C72E8);

  // ─── Gradients (Figma exact) ──────────────────────────────
  /// Hero section gradient — Figma: #7B72E9 → #9F97F2 → #B8B2FF
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF7B72E9), Color(0xFF9F97F2), Color(0xFFB8B2FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Primary gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C72E8), Color(0xFFB8B2FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// AI gradient — blue to indigo
  static const LinearGradient aiGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFF8C42), Color(0xFFFFB347)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Quick Action Card Colors (Figma exact) ───────────────
  static const Color qaNotesColor      = Color(0xFF7C72E8); // Purple
  static const Color qaQPColor         = Color(0xFFFF8C42); // Orange
  static const Color qaCommunityColor  = Color(0xFFE91E8C); // Pink
  static const Color qaAIColor         = Color(0xFF3B82F6); // Blue

  // ─── Shadows ──────────────────────────────────────────────
  /// Level 1 shadow — subtle card shadow
  static const List<BoxShadow> shadowLevel1 = [
    BoxShadow(
      color: Color(0x0A7C72E8),
      offset: Offset(0, 4),
      blurRadius: 12,
    ),
  ];

  /// Level 2 shadow — elevated card / hero shadow
  static const List<BoxShadow> shadowLevel2 = [
    BoxShadow(
      color: Color(0x187C72E8),
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];

  /// Primary-tinted hover shadow
  static List<BoxShadow> get shadowHover => [
    BoxShadow(
      color: primary.withOpacity(0.15),
      offset: const Offset(0, 8),
      blurRadius: 20,
    ),
  ];

  /// Legacy aliases
  static const List<BoxShadow> glassShadow = shadowLevel2;
  static const List<BoxShadow> softShadow  = shadowLevel1;
}
