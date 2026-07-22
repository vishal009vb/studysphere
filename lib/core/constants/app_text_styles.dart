import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// StudySphere Typography System — Figma matched
/// Headings: Outfit (700, 800) — modern, clean, geometric
/// Body:     Inter (400, 600) — clean, highly readable
class AppTextStyles {
  // ─── Display (App name / Hero) ────────────────────────────
  static TextStyle displayLarge = GoogleFonts.outfit(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    height: 56 / 48,
    letterSpacing: -0.02 * 48,
    color: AppColors.onBackground,
  );

  // ─── Headline ─────────────────────────────────────────────
  static TextStyle headingLarge = GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 40 / 32,
    color: AppColors.onBackground,
  );

  static TextStyle headingMedium = GoogleFonts.outfit(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 28 / 20,
    color: AppColors.onBackground,
  );

  /// Mobile headline (22px)
  static TextStyle headingLargeMobile = GoogleFonts.outfit(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 30 / 22,
    color: AppColors.onBackground,
  );

  /// Used for card titles, section sub-headings
  static TextStyle headingSmall = GoogleFonts.outfit(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.onBackground,
  );

  // ─── Label ────────────────────────────────────────────────
  /// Label Medium — 14px, semibold, for card titles, nav labels
  static TextStyle labelMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
    color: AppColors.onBackground,
  );

  /// Label Small — 12px, bold, for chips, badges
  static TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 16 / 12,
    color: AppColors.onBackground,
  );

  // ─── Body ─────────────────────────────────────────────────
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
    color: AppColors.onBackground,
  );

  static TextStyle bodyMedium = GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    color: AppColors.onSurfaceVariant,
  );

  static TextStyle bodySmall = GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
    color: AppColors.onSurfaceVariant,
  );

  // ─── Utility ──────────────────────────────────────────────
  static TextStyle button = GoogleFonts.outfit(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
}
