// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppColors {
  static const primary       = Color(0xFF2563EB);
  static const primaryLight  = Color(0xFFEFF6FF);
  static const primaryDark   = Color(0xFF1D4ED8);
  static const accent        = Color(0xFF0EA5E9);
  static const success       = Color(0xFF10B981);
  static const successLight  = Color(0xFFECFDF5);
  static const warning       = Color(0xFFF59E0B);
  static const warningLight  = Color(0xFFFFFBEB);
  static const danger        = Color(0xFFEF4444);
  static const dangerLight   = Color(0xFFFEF2F2);
  static const purple        = Color(0xFF8B5CF6);
  static const purpleLight   = Color(0xFFF5F3FF);
  static const hot           = Color(0xFFEF4444);
  static const hotBg         = Color(0xFFFEF2F2);
  static const cold          = Color(0xFF3B82F6);
  static const coldBg        = Color(0xFFEFF6FF);
  static const warm          = Color(0xFFF59E0B);
  static const warmBg        = Color(0xFFFFFBEB);
  static const junk          = Color(0xFF6B7280);
  static const junkBg        = Color(0xFFF3F4F6);
  static const converted     = Color(0xFF10B981);
  static const convertedBg   = Color(0xFFECFDF5);
  static const background    = Color(0xFFF8FAFC);
  static const surface       = Color(0xFFFFFFFF);
  static const textPrimary   = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textHint      = Color(0xFF94A3B8);
  static const border        = Color(0xFFE2E8F0);
  static const divider       = Color(0xFFF1F5F9);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
  );
}