/// ProfessorOS – Design System v2 "The Journal"
/// Reference implementation for Dark Mode ("Pressroom Night"),
/// Light Mode ("Pressroom Day"), and v1 "Marginalia" backward compatibility.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_provider.dart';

// ── The Journal v2 Colors (Dark Mode / Pressroom Night) ───────────────
class AppColors {
  AppColors._();

  // ── Surfaces ──────────────────────────────────────────────────
  static const Color canvas       = Color(0xFF131315); // page background (warmed to eliminate halation glare)
  static const Color surface      = Color(0xFF1A1A1F); // cards, containers
  static const Color surfaceMid   = Color(0xFF24242C); // hover, active rows
  static const Color surfaceHigh  = Color(0xFF2E2E38); // popovers, drawers
  
  // ── Borders (1px only) ─────────────────────────────────────────
  static const Color rule         = Color(0xFF3A3A46); // hairline dividers (elevated for visibility)
  static const Color ruleStrong   = Color(0xFF525262); // section dividers (> 3.05:1 WCAG AA boundary)
  
  // ── Ink ───────────────────────────────────────────────────────
  static const Color inkPrimary   = Color(0xFFEAE8E3); // all primary text (warmed paper white)
  static const Color inkSecondary = Color(0xFF9E9EB0); // metadata, labels, captions (> 5.5:1 WCAG AA)
  static const Color inkGhost     = Color(0xFF787886); // placeholders, disabled only (> 4.0:1)
  static const Color inkAccent    = Color(0xFFC8D0FF); // links, active nav item (11.8:1 AAA)
  
  // ── Status pairs (ALWAYS use bg + ink together) ───────────────
  static const Color statusPassBg       = Color(0xFF0E2F1D);
  static const Color statusPassInk      = Color(0xFF52CE89); // > 6.6:1 WCAG AA
  static const Color statusPendingBg    = Color(0xFF2E2211);
  static const Color statusPendingInk   = Color(0xFFE5A544); // > 6.5:1 WCAG AA
  static const Color statusCriticalBg   = Color(0xFF341414);
  static const Color statusCriticalInk  = Color(0xFFF46A6A); // > 6.1:1 WCAG AA

  // ── Backward-compatible semantic aliases for existing code ────
  static const Color bgPage     = canvas;
  static const Color bgCard     = surface;
  static const Color bgSurface  = surface;
  static const Color bgMargin   = surface;
  static const Color bgHover    = surfaceMid;
  static const Color bgActive   = surfaceMid;
  static const Color bgElevated = surfaceHigh;
  static const Color bgInput    = surface;

  static const Color textPrimary   = inkPrimary;
  static const Color textSecondary = inkSecondary;
  static const Color textMuted     = inkGhost;
  static const Color inkFaint      = inkGhost;

  static const Color marginRule   = rule;
  static const Color borderStrong = ruleStrong;
  static const Color border       = rule;
  static const Color borderFocus  = inkPrimary;

  static const Color feedbackRed  = statusCriticalInk;
  static const Color verified     = statusPassInk;
  static const Color pending      = statusPendingInk;
  static const Color signal       = inkPrimary;

  static const Color primary       = inkPrimary;
  static const Color emerald       = statusPassInk;
  static const Color primaryIndigo = inkPrimary;
  static const Color primaryCyan   = inkPrimary;
  static const Color primaryViolet = inkPrimary;
  static const Color primaryMid    = inkPrimary;
  static const Color primarySoft   = surfaceMid;
  static const Color successGreen  = statusPassInk;
  static const Color dangerRose    = statusCriticalInk;
  static const Color accentAmber   = statusPendingInk;
  static const Color accentCyan    = inkPrimary;
  static const Color accentPink    = inkPrimary;

  static const Color heroBg        = canvas;
  static const Color heroBg2       = canvas;

  static Color badgeColor(String role) {
    switch (role.toLowerCase()) {
      case 'professor': return inkAccent;
      case 'student':   return statusPassInk;
      case 'ta':        return statusPendingInk;
      case 'admin':     return inkPrimary;
      default:          return inkSecondary;
    }
  }

  static Color hecGradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'W': return statusPassInk;
      case 'X': return inkAccent;
      case 'Y': return statusPendingInk;
      case 'Z': return statusCriticalInk;
      default:  return inkSecondary;
    }
  }
}

// ── The Journal v2 Light Mode ("Pressroom Day") ────────────────────────
class AppColorsLight {
  AppColorsLight._();

  static const Color canvas       = Color(0xFFEFECE6); // deepened warm paper tone
  static const Color surface      = Color(0xFFFFFFFF); // crisp white cards (prevents TN washout)
  static const Color surfaceMid   = Color(0xFFE6E3DC);
  static const Color surfaceHigh  = Color(0xFFDCD8D0);
  static const Color rule         = Color(0xFFC4C2BA); // adjusted for paper/card visibility
  static const Color ruleStrong   = Color(0xFF8A8982); // 3.12:1 WCAG AA boundary contrast
  static const Color inkPrimary   = Color(0xFF161614); // 15.7:1 AAA
  static const Color inkSecondary = Color(0xFF54544D); // 6.45:1 AA (clear on washed-out screens)
  static const Color inkGhost     = Color(0xFF74746D); // 3.91:1 AA for UI components
  static const Color inkAccent    = Color(0xFF1A3A9C); // 8.05:1 AAA deep academic blue
  static const Color statusPassBg       = Color(0xFFD6EFE2);
  static const Color statusPassInk      = Color(0xFF145C30); // 6.2:1 AA
  static const Color statusPendingBg    = Color(0xFFF5E9CE);
  static const Color statusPendingInk   = Color(0xFF6E4408); // 5.32:1 AA
  static const Color statusCriticalBg   = Color(0xFFF5DADA);
  static const Color statusCriticalInk  = Color(0xFF8B1C1C); // 6.75:1 AAA
}

// ── Marginalia v1 Palette (Paper Canvas Classic) ──────────────────────
class AppColorsMarginalia {
  AppColorsMarginalia._();

  static const Color bgPage     = Color(0xFFF6F5F0);
  static const Color bgCard     = Color(0xFFFFFFFF);
  static const Color bgSurface  = Color(0xFFFFFFFF);
  static const Color bgMargin   = Color(0xFFF6F5F0);
  static const Color bgHover    = Color(0xFFFBF1EE);
  static const Color bgActive   = Color(0xFFEFEAE0);
  static const Color bgElevated = Color(0xFFFFFFFF);
  static const Color bgInput    = Color(0xFFFFFFFF);
  static const Color inkPrimary   = Color(0xFF1E2A38);
  static const Color inkSecondary = Color(0xFF5B6470);
  static const Color inkFaint     = Color(0xFF9CA0A6);
  static const Color marginRule   = Color(0xFFE4E1D8);
  static const Color borderStrong = Color(0xFFD4CFC2);
  static const Color feedbackRed  = Color(0xFFB4432E);
  static const Color verified     = Color(0xFF3F6B4F);
  static const Color pending      = Color(0xFFB5872A);
  static const Color signal       = Color(0xFF2F5D8A);
}

// ── Spacing Tokens ────────────────────────────────────────────────────
class AppSpacing {
  AppSpacing._();
  static const s2  = 2.0;   // icon-to-label gap
  static const s4  = 4.0;   // between metadata items in same row
  static const s8  = 8.0;   // compact component internal padding
  static const s12 = 12.0;  // label to content gap
  static const s16 = 16.0;  // standard card padding (all sides)
  static const s24 = 24.0;  // between distinct sections
  static const s32 = 32.0;  // between major layout zones
  static const s48 = 48.0;  // page-level horizontal margin
}

// ── Border Radius Tokens ──────────────────────────────────────────────
class AppRadius {
  AppRadius._();
  static const r2   = 2.0;   // stamp badges, toasts, code blocks
  static const r4   = 4.0;   // buttons (more press-like, less pill)
  static const r6   = 6.0;   // cards, surface containers
  static const r8   = 8.0;   // input fields, drawers
}

// ── Typography Tokens ─────────────────────────────────────────────────
class AppText {
  AppText._();

  // DM Serif Display — rare, deliberate (3 contexts only: course name header, HEC sections, wordmark)
  static TextStyle get display => GoogleFonts.dmSerifDisplay(
    fontSize: 26,
    fontWeight: FontWeight.w400,
    height: 1.2,
    letterSpacing: -0.3,
    color: AppColors.inkPrimary,
  );

  // DM Sans — UI and content
  static TextStyle get title => GoogleFonts.dmSans(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: -0.1,
    color: AppColors.inkPrimary,
  );
  static TextStyle get body => GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.65,
    color: AppColors.inkPrimary,
  );
  // Long-form assignment prose and reading (prevents line-tracking skips)
  static TextStyle get bodyLong => GoogleFonts.dmSans(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AppColors.inkPrimary,
  );
  static TextStyle get bodyDense => GoogleFonts.dmSans(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.inkPrimary,
  );
  static TextStyle get sectionHeader => GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.8,
    color: AppColors.inkSecondary,
  );
  static TextStyle get label => GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.1,
    letterSpacing: 0.15,
    color: AppColors.inkSecondary,
  );
  // Captions adhere to 12sp minimum floor on mobile to avoid Pentile OLED stem breakage
  static TextStyle get caption => GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.2,
    color: AppColors.inkSecondary,
  );

  // JetBrains Mono — numbers, code, IDs
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: AppColors.inkPrimary,
  );
  static TextStyle get monoLarge => GoogleFonts.jetBrainsMono(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: AppColors.inkPrimary,
  );
  static TextStyle get monoStat => GoogleFonts.jetBrainsMono(
    fontSize: 28,
    fontWeight: FontWeight.w400,
    height: 1.1,
    color: AppColors.inkPrimary,
  );
}

// ── Gradients & Shadows ───────────────────────────────────────────────
class AppGradients {
  AppGradients._();
  // Zero gradients in v2
  static const LinearGradient primaryButton = LinearGradient(colors: [AppColors.inkPrimary, AppColors.inkPrimary]);
  static const LinearGradient aurora = LinearGradient(colors: [AppColors.canvas, AppColors.canvas]);
  static const LinearGradient heroPanel = LinearGradient(colors: [AppColors.surface, AppColors.surface]);
  static const LinearGradient cardSheen = LinearGradient(colors: [Colors.transparent, Colors.transparent]);
}

class AppShadows {
  AppShadows._();
  // Zero shadows in v2
  static List<BoxShadow> get card => const [];
  static List<BoxShadow> get elevated => const [];
  static List<BoxShadow> get buttonGlow => const [];
  static List<BoxShadow> get sidebar => const [];
}

// ── AppTheme Factory ──────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get light => journalLight;

  static ThemeData themeFor(DesignSystem design, JournalThemeMode mode) {
    if (design == DesignSystem.marginalia) {
      return marginaliaLight;
    }
    return mode == JournalThemeMode.light ? journalLight : journalDark;
  }

  // ── The Journal v2 - Dark Mode (Default "Pressroom Night") ───────────
  static ThemeData get journalDark {
    final dmSansTT = GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.canvas,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.inkPrimary,
        onPrimary: AppColors.canvas,
        secondary: AppColors.inkSecondary,
        onSecondary: AppColors.inkPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.inkPrimary,
        error: AppColors.statusCriticalInk,
        onError: AppColors.canvas,
      ),
      textTheme: dmSansTT.copyWith(
        displayLarge:  AppText.display.copyWith(fontSize: 32),
        displayMedium: AppText.display.copyWith(fontSize: 26),
        displaySmall:  AppText.display.copyWith(fontSize: 22),
        headlineLarge: AppText.title.copyWith(fontSize: 24, fontWeight: FontWeight.w600),
        headlineMedium:AppText.title.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
        headlineSmall: AppText.title.copyWith(fontSize: 18),
        titleLarge:    AppText.title,
        titleMedium:   AppText.title.copyWith(fontSize: 16),
        titleSmall:    AppText.title.copyWith(fontSize: 14),
        bodyLarge:     AppText.body,
        bodyMedium:    AppText.bodyDense,
        bodySmall:     AppText.caption,
        labelLarge:    AppText.label.copyWith(fontSize: 14),
        labelMedium:   AppText.label,
        labelSmall:    AppText.caption,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r8), borderSide: const BorderSide(color: AppColors.rule, width: 1)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r8), borderSide: const BorderSide(color: AppColors.rule, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r8), borderSide: const BorderSide(color: AppColors.ruleStrong, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r8), borderSide: const BorderSide(color: AppColors.statusCriticalInk, width: 1)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r8), borderSide: const BorderSide(color: AppColors.statusCriticalInk, width: 1.5)),
        labelStyle: GoogleFonts.dmSans(color: AppColors.inkSecondary, fontSize: 13),
        hintStyle:  GoogleFonts.dmSans(color: AppColors.inkGhost, fontSize: 13),
        errorStyle: GoogleFonts.dmSans(color: AppColors.statusCriticalInk, fontSize: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.inkPrimary,
          foregroundColor: AppColors.canvas,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r4)),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inkPrimary,
          side: const BorderSide(color: AppColors.ruleStrong, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r4)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.inkAccent,
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r6),
          side: const BorderSide(color: AppColors.rule, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.rule, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.inkPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppText.display.copyWith(fontSize: 20),
        iconTheme: const IconThemeData(color: AppColors.inkPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: GoogleFonts.dmSans(color: AppColors.inkPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r2),
          side: const BorderSide(color: AppColors.rule, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── The Journal v2 - Light Mode ("Pressroom Day") ───────────────────
  static ThemeData get journalLight {
    final dmSansTT = GoogleFonts.dmSansTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColorsLight.canvas,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColorsLight.inkPrimary,
        onPrimary: AppColorsLight.canvas,
        secondary: AppColorsLight.inkSecondary,
        onSecondary: AppColorsLight.inkPrimary,
        surface: AppColorsLight.surface,
        onSurface: AppColorsLight.inkPrimary,
        error: AppColorsLight.statusCriticalInk,
        onError: AppColorsLight.canvas,
      ),
      textTheme: dmSansTT.copyWith(
        displayLarge:  AppText.display.copyWith(fontSize: 32, color: AppColorsLight.inkPrimary),
        displayMedium: AppText.display.copyWith(fontSize: 26, color: AppColorsLight.inkPrimary),
        displaySmall:  AppText.display.copyWith(fontSize: 22, color: AppColorsLight.inkPrimary),
        headlineLarge: AppText.title.copyWith(fontSize: 24, fontWeight: FontWeight.w600, color: AppColorsLight.inkPrimary),
        headlineMedium:AppText.title.copyWith(fontSize: 20, fontWeight: FontWeight.w600, color: AppColorsLight.inkPrimary),
        headlineSmall: AppText.title.copyWith(fontSize: 18, color: AppColorsLight.inkPrimary),
        titleLarge:    AppText.title.copyWith(color: AppColorsLight.inkPrimary),
        titleMedium:   AppText.title.copyWith(fontSize: 16, color: AppColorsLight.inkPrimary),
        titleSmall:    AppText.title.copyWith(fontSize: 14, color: AppColorsLight.inkPrimary),
        bodyLarge:     AppText.body.copyWith(color: AppColorsLight.inkPrimary),
        bodyMedium:    AppText.bodyDense.copyWith(color: AppColorsLight.inkPrimary),
        bodySmall:     AppText.caption.copyWith(color: AppColorsLight.inkSecondary),
        labelLarge:    AppText.label.copyWith(fontSize: 14, color: AppColorsLight.inkPrimary),
        labelMedium:   AppText.label.copyWith(color: AppColorsLight.inkSecondary),
        labelSmall:    AppText.caption.copyWith(color: AppColorsLight.inkGhost),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorsLight.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r8), borderSide: const BorderSide(color: AppColorsLight.rule, width: 1)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r8), borderSide: const BorderSide(color: AppColorsLight.rule, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r8), borderSide: const BorderSide(color: AppColorsLight.ruleStrong, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r8), borderSide: const BorderSide(color: AppColorsLight.statusCriticalInk, width: 1)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r8), borderSide: const BorderSide(color: AppColorsLight.statusCriticalInk, width: 1.5)),
        labelStyle: GoogleFonts.dmSans(color: AppColorsLight.inkSecondary, fontSize: 13),
        hintStyle:  GoogleFonts.dmSans(color: AppColorsLight.inkGhost, fontSize: 13),
        errorStyle: GoogleFonts.dmSans(color: AppColorsLight.statusCriticalInk, fontSize: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorsLight.inkPrimary,
          foregroundColor: AppColorsLight.canvas,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r4)),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColorsLight.inkPrimary,
          side: const BorderSide(color: AppColorsLight.ruleStrong, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r4)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColorsLight.inkAccent,
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      cardTheme: CardTheme(
        color: AppColorsLight.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r6),
          side: const BorderSide(color: AppColorsLight.rule, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColorsLight.rule, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColorsLight.canvas,
        foregroundColor: AppColorsLight.inkPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppText.display.copyWith(fontSize: 20, color: AppColorsLight.inkPrimary),
        iconTheme: const IconThemeData(color: AppColorsLight.inkPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColorsLight.surface,
        contentTextStyle: GoogleFonts.dmSans(color: AppColorsLight.inkPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r2),
          side: const BorderSide(color: AppColorsLight.rule, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Marginalia v1 - Classic Light Mode ──────────────────────────────
  static ThemeData get marginaliaLight {
    final frauncesTT = GoogleFonts.frauncesTextTheme();
    final interTT = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColorsMarginalia.bgPage,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColorsMarginalia.signal,
        primary: AppColorsMarginalia.signal,
        secondary: AppColorsMarginalia.inkSecondary,
        surface: AppColorsMarginalia.bgCard,
        error: AppColorsMarginalia.feedbackRed,
      ),
      textTheme: TextTheme(
        displayLarge:  frauncesTT.displayLarge?.copyWith(color: AppColorsMarginalia.inkPrimary, fontWeight: FontWeight.w600),
        displayMedium: frauncesTT.displayMedium?.copyWith(color: AppColorsMarginalia.inkPrimary, fontWeight: FontWeight.w600),
        displaySmall:  frauncesTT.displaySmall?.copyWith(color: AppColorsMarginalia.inkPrimary, fontWeight: FontWeight.w600),
        headlineLarge: frauncesTT.headlineLarge?.copyWith(color: AppColorsMarginalia.inkPrimary, fontWeight: FontWeight.w600),
        headlineMedium:frauncesTT.headlineMedium?.copyWith(color: AppColorsMarginalia.inkPrimary, fontWeight: FontWeight.w600, fontSize: 28),
        headlineSmall: frauncesTT.headlineSmall?.copyWith(color: AppColorsMarginalia.inkPrimary, fontWeight: FontWeight.w600, fontSize: 20),
        titleLarge:    frauncesTT.titleLarge?.copyWith(color: AppColorsMarginalia.inkPrimary, fontWeight: FontWeight.w600),
        titleMedium:   frauncesTT.titleMedium?.copyWith(color: AppColorsMarginalia.inkPrimary, fontWeight: FontWeight.w500),
        titleSmall:    frauncesTT.titleSmall?.copyWith(color: AppColorsMarginalia.inkPrimary, fontWeight: FontWeight.w500),
        bodyLarge:     interTT.bodyLarge?.copyWith(color: AppColorsMarginalia.inkPrimary, fontSize: 16),
        bodyMedium:    interTT.bodyMedium?.copyWith(color: AppColorsMarginalia.inkPrimary, fontSize: 14),
        bodySmall:     interTT.bodySmall?.copyWith(color: AppColorsMarginalia.inkSecondary, fontSize: 13),
        labelLarge:    interTT.labelLarge?.copyWith(color: AppColorsMarginalia.inkPrimary, fontWeight: FontWeight.w500, fontSize: 14),
        labelMedium:   interTT.labelMedium?.copyWith(color: AppColorsMarginalia.inkSecondary, fontWeight: FontWeight.w500, fontSize: 12),
        labelSmall:    interTT.labelSmall?.copyWith(color: AppColorsMarginalia.inkSecondary, fontWeight: FontWeight.w600, fontSize: 11),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorsMarginalia.bgInput,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColorsMarginalia.marginRule)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColorsMarginalia.marginRule)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColorsMarginalia.signal, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColorsMarginalia.feedbackRed)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColorsMarginalia.feedbackRed, width: 2)),
        labelStyle: GoogleFonts.inter(color: AppColorsMarginalia.inkSecondary, fontSize: 14),
        hintStyle:  GoogleFonts.inter(color: AppColorsMarginalia.inkFaint, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorsMarginalia.signal,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      cardTheme: CardTheme(
        color: AppColorsMarginalia.bgCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColorsMarginalia.marginRule),
        ),
      ),
    );
  }
}
