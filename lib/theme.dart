import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// ToTo Cafe — Design System (Theme)
//
// Color tokens sourced from DESIGN.md.
// Additional legacy tokens from AGENTS.md (coffee-*, green-*, etc.) are
// exposed as named constants for convenience but the canonical semantic
// names follow DESIGN.md.
//
// Typography: Noto Serif Thai (headings/logo) + Noto Sans Thai (body/UI)
// as mandated by AGENTS.md — do NOT swap these fonts.
// ---------------------------------------------------------------------------

// ── Color Palette (DESIGN.md §2) ──────────────────────────────────────────

/// Page background — warm cream / off-white.
const Color kColorBg = Color(0xFFF5F1E4);

/// Cards, modals, panels.
const Color kColorSurface = Color(0xFFFBF9F2);

/// Forest green — primary buttons, active nav, selected states.
const Color kColorPrimary = Color(0xFF3F5F35);

/// Primary button hover / pressed.
const Color kColorPrimaryHover = Color(0xFF334D2B);

/// Dark brown — secondary CTA ("Proceed to Payment"), accents.
const Color kColorSecondary = Color(0xFF5B3A29);

/// Headings, logo text (brown).
const Color kColorTextHeading = Color(0xFF4A2F1E);

/// Alternating letters/words in logo (green).
const Color kColorTextHeadingAccent = Color(0xFF3F5F35);

/// Body copy.
const Color kColorTextBody = Color(0xFF3A362E);

/// Secondary text, labels, price subtitles.
const Color kColorTextMuted = Color(0xFF8A8374);

/// Card borders, dividers, input outlines.
const Color kColorBorder = Color(0xFFE4DECC);

/// Selected chip/option border.
const Color kColorBorderSelected = Color(0xFF3F5F35);

/// Text on filled green/brown buttons.
const Color kColorWhite = Color(0xFFFFFFFF);

// ── Legacy / AGENTS.md tokens ─────────────────────────────────────────────

const Color kCoffee900 = Color(0xFF2E2118);
const Color kCoffee700 = Color(0xFF3B2A20);
const Color kCoffee500 = Color(0xFF6B4A35);
const Color kGreen800 = Color(0xFF2E3D26);
const Color kGreen600 = Color(0xFF4F6344);
const Color kGreen100 = Color(0xFFE4EBDC);
const Color kCream = Color(0xFFFBF5EC);
const Color kTan = Color(0xFFF1E4CC);
const Color kGold = Color(0xFFC89B5C);

// ── Radius & Shape (DESIGN.md §5) ─────────────────────────────────────────

/// Full pill radius for buttons & chips.
const double kRadiusPill = 999;

/// Cards & product tiles.
const double kRadiusCard = 16;

/// Images (hero, product photo).
const double kRadiusImage = 16;

/// Modals.
const double kRadiusModal = 20;

/// Small badges.
const double kRadiusBadge = 12;

// ── Spacing (DESIGN.md §4 — 4px base unit) ────────────────────────────────

const double kSpace4 = 4;
const double kSpace8 = 8;
const double kSpace12 = 12;
const double kSpace16 = 16;
const double kSpace24 = 24;
const double kSpace32 = 32;
const double kSpace48 = 48;
const double kSpace64 = 64;

// ── Typography helpers ────────────────────────────────────────────────────

/// Heading / logo font — Noto Serif Thai.
TextStyle _serifStyle({
  double fontSize = 20,
  FontWeight fontWeight = FontWeight.w700,
  Color color = kColorTextHeading,
  double? letterSpacing,
  double? height,
}) {
  return GoogleFonts.notoSerifThai(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

/// Body / UI font — Noto Sans Thai.
TextStyle _sansStyle({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.w400,
  Color color = kColorTextBody,
  double? letterSpacing,
  double? height,
}) {
  return GoogleFonts.notoSansThai(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

// ── TextTheme ─────────────────────────────────────────────────────────────

TextTheme _buildTextTheme() {
  return TextTheme(
    // ─ Display / Headline slots → Noto Serif Thai (headings) ─────────
    displayLarge: _serifStyle(fontSize: 32, fontWeight: FontWeight.w700),
    displayMedium: _serifStyle(fontSize: 28, fontWeight: FontWeight.w700),
    displaySmall: _serifStyle(fontSize: 24, fontWeight: FontWeight.w700),
    headlineLarge: _serifStyle(fontSize: 24, fontWeight: FontWeight.w700),
    headlineMedium: _serifStyle(fontSize: 20, fontWeight: FontWeight.w700),
    headlineSmall: _serifStyle(fontSize: 18, fontWeight: FontWeight.w700),

    // ─ Title slots → Noto Serif Thai (product/modal names) ──────────
    titleLarge: _serifStyle(fontSize: 20, fontWeight: FontWeight.w700),
    titleMedium: _serifStyle(fontSize: 18, fontWeight: FontWeight.w600),
    titleSmall: _serifStyle(fontSize: 16, fontWeight: FontWeight.w600),

    // ─ Body / Label slots → Noto Sans Thai (UI text) ────────────────
    bodyLarge: _sansStyle(fontSize: 15),
    bodyMedium: _sansStyle(fontSize: 14),
    bodySmall: _sansStyle(fontSize: 13, color: kColorTextMuted),

    labelLarge: _sansStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ), // Button labels
    labelMedium: _sansStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15 * 11, // 0.15em
      color: kColorTextMuted,
    ), // Eyebrow / label text (UPPERCASE in code)
    labelSmall: _sansStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: kColorTextMuted,
    ),
  );
}

// ── ColorScheme ───────────────────────────────────────────────────────────

ColorScheme _buildColorScheme() {
  return const ColorScheme(
    brightness: Brightness.light,

    // Primary
    primary: kColorPrimary,
    onPrimary: kColorWhite,
    primaryContainer: kGreen100,
    onPrimaryContainer: kGreen800,

    // Secondary
    secondary: kColorSecondary,
    onSecondary: kColorWhite,
    secondaryContainer: kTan,
    onSecondaryContainer: kCoffee900,

    // Tertiary — gold accent
    tertiary: kGold,
    onTertiary: kColorWhite,
    tertiaryContainer: kTan,
    onTertiaryContainer: kCoffee700,

    // Error (keep Material defaults-ish but warm-toned)
    error: Color(0xFFB3261E),
    onError: kColorWhite,
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),

    // Surfaces
    surface: kColorSurface,
    onSurface: kColorTextBody,
    onSurfaceVariant: kColorTextMuted,
    outline: kColorBorder,
    outlineVariant: kColorBorder,

    // Misc
    shadow: Color(0x29000000),
    scrim: Color(0x52000000),
    inverseSurface: kCoffee900,
    onInverseSurface: kCream,
    inversePrimary: kGreen100,
    surfaceTint: Colors.transparent,
  );
}

// ── ThemeData ──────────────────────────────────────────────────────────────

/// The single source of truth for the ToTo Cafe visual identity.
///
/// Usage in `MaterialApp`:
/// ```dart
/// MaterialApp(
///   theme: totoCafeTheme,
///   ...
/// )
/// ```
final ThemeData totoCafeTheme = ThemeData(
  useMaterial3: true,
  colorScheme: _buildColorScheme(),
  textTheme: _buildTextTheme(),
  scaffoldBackgroundColor: kColorBg,

  // ── AppBar ──────────────────────────────────────────────────────────
  appBarTheme: AppBarTheme(
    backgroundColor: kColorBg,
    foregroundColor: kColorTextHeading,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: _serifStyle(fontSize: 20, fontWeight: FontWeight.w700),
  ),

  // ── Card ────────────────────────────────────────────────────────────
  cardTheme: CardThemeData(
    color: kColorSurface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(kRadiusCard),
      side: const BorderSide(color: kColorBorder),
    ),
    margin: EdgeInsets.zero,
  ),

  // ── Elevated Button (Primary CTA — green pill) ─────────────────────
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kColorPrimary,
      foregroundColor: kColorWhite,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: kSpace24, vertical: kSpace12),
      shape: const StadiumBorder(),
      textStyle: _sansStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: kColorWhite,
      ),
    ),
  ),

  // ── Outlined Button (Chip-style / unselected option) ───────────────
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: kColorTextBody,
      side: const BorderSide(color: kColorBorder),
      padding: const EdgeInsets.symmetric(horizontal: kSpace16, vertical: kSpace8),
      shape: const StadiumBorder(),
      textStyle: _sansStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: kColorTextBody,
      ),
    ),
  ),

  // ── Filled Button (Secondary CTA — dark brown pill) ────────────────
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: kColorSecondary,
      foregroundColor: kColorWhite,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: kSpace24, vertical: kSpace12),
      shape: const StadiumBorder(),
      textStyle: _sansStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: kColorWhite,
      ),
    ),
  ),

  // ── Chip ────────────────────────────────────────────────────────────
  chipTheme: ChipThemeData(
    backgroundColor: Colors.transparent,
    selectedColor: kColorPrimary,
    side: const BorderSide(color: kColorBorder),
    shape: const StadiumBorder(),
    labelStyle: _sansStyle(fontSize: 14, fontWeight: FontWeight.w500),
    secondaryLabelStyle: _sansStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: kColorWhite,
    ),
    padding: const EdgeInsets.symmetric(horizontal: kSpace12, vertical: kSpace4),
    showCheckmark: false,
  ),

  // ── Dialog / Modal ──────────────────────────────────────────────────
  dialogTheme: DialogThemeData(
    backgroundColor: kColorSurface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(kRadiusModal),
    ),
    titleTextStyle: _serifStyle(fontSize: 20, fontWeight: FontWeight.w700),
    contentTextStyle: _sansStyle(fontSize: 14),
  ),

  // ── Bottom Sheet ───────────────────────────────────────────────────
  bottomSheetTheme: BottomSheetThemeData(
    backgroundColor: kColorSurface,
    surfaceTintColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusModal)),
    ),
  ),

  // ── Snack Bar ──────────────────────────────────────────────────────
  snackBarTheme: SnackBarThemeData(
    backgroundColor: kCoffee900,
    contentTextStyle: _sansStyle(fontSize: 14, color: kCream),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(kRadiusCard),
    ),
    behavior: SnackBarBehavior.floating,
  ),

  // ── Divider ────────────────────────────────────────────────────────
  dividerTheme: const DividerThemeData(
    color: kColorBorder,
    thickness: 1,
    space: 0,
  ),

  // ── Input / TextField ─────────────────────────────────────────────
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: kColorSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kRadiusCard),
      borderSide: const BorderSide(color: kColorBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kRadiusCard),
      borderSide: const BorderSide(color: kColorBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kRadiusCard),
      borderSide: const BorderSide(color: kColorPrimary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: kSpace16,
      vertical: kSpace12,
    ),
    hintStyle: _sansStyle(fontSize: 14, color: kColorTextMuted),
    labelStyle: _sansStyle(fontSize: 14, color: kColorTextMuted),
  ),

  // ── Icon ───────────────────────────────────────────────────────────
  iconTheme: const IconThemeData(
    color: kColorTextBody,
    size: 24,
  ),

  // ── Splash / highlight for touch feedback ─────────────────────────
  splashColor: kColorPrimary.withValues(alpha: 0.08),
  highlightColor: kColorPrimary.withValues(alpha: 0.04),
);
