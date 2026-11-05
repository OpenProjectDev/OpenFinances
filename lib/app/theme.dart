import 'package:flutter/material.dart';

/// The brand's blue (the owner, 2026-10-22: green is a status color, not a
/// theme): the default theme color, the leaf of the mark, the "Finances" of
/// the wordmark.
const kBrandBlue = Color(0xFF2196F3);
const kAppBg = Color(0xFF1E1F21);

/// The app's dark theme as main.dart last built it (theme color, font):
/// for the first page, dark whatever the theme mode (it carries on from the
/// dark branding screen).
ThemeData? builtDarkTheme;

/// The app's one red: a strong red that reads in both themes (the
/// scheme's error tones are pale pink in dark mode). Errors, overdue,
/// over budget, delete — always this, with white on it.
const Color kStrongRed = Color(0xFFE53935);

/// The warning orange: allowed, but look again (a date in the future where
/// one isn't expected).
const Color kWarnOrange = Color(0xFFEF6C00);

/// Text (and icons) on a colored background [bg]: white or black by the
/// color itself, never by light / dark mode (the owner, 2026-10-24: black on
/// the blue theme color in light mode, and with a black theme color the text
/// vanished). One rule everywhere: the category chips' (black only on light
/// colors, e.g. yellow).
Color onColor(Color bg) =>
    bg.computeLuminance() > 0.53 ? Colors.black : Colors.white;

/// How far apart two colors read (WCAG contrast ratio, 1 to 21).
double contrastOf(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

/// [color], darkened on a light [background] (lightened on a dark one) just
/// enough to read on it ([minContrast]; 3 = large text and icons). A color
/// that reads already is returned as it is.
Color readableOn(Color color, Color background, {double minContrast = 3}) {
  if (contrastOf(color, background) >= minContrast) return color;
  final darken = background.computeLuminance() > .5;
  var hsl = HSLColor.fromColor(color);
  for (var i = 0; i < 25; i++) {
    if (contrastOf(hsl.toColor(), background) >= minContrast) break;
    hsl = hsl.withLightness(
      (hsl.lightness + (darken ? -.04 : .04)).clamp(0.0, 1.0),
    );
  }
  return hsl.toColor();
}

extension OpenFinancesTextOnStrong on BuildContext {
  /// Text on the theme color (filled buttons, total tiles, chips).
  Color get textOnStrong => onColor(Theme.of(this).colorScheme.primary);

  /// The theme color as TEXT or an icon on the page (a selected label, the
  /// "All" chip, the selected tab): readable whatever color was picked (a
  /// pale yellow in light mode is darkened just enough).
  Color get primaryInk {
    final scheme = Theme.of(this).colorScheme;
    return readableOn(scheme.primary, scheme.surface);
  }
}

ThemeData openFinancesLightTheme({
  String? fontFamily,
  List<String>? fontFamilyFallback,
}) {
  final base = ColorScheme.fromSeed(
    seedColor: kBrandBlue,
    brightness: Brightness.light,
  );

  final scheme = base.copyWith(onPrimary: onColor(base.primary));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: fontFamily, // null = device font
    fontFamilyFallback: fontFamilyFallback,

    appBarTheme: const AppBarTheme(centerTitle: true),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),

    // Global NavigationBar styling
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: scheme.primary);
        }
        return IconThemeData(color: scheme.onSurfaceVariant);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(color: scheme.primary, fontWeight: FontWeight.w700);
        }
        return TextStyle(color: scheme.onSurfaceVariant);
      }),
    ),
  );
}

ThemeData openFinancesDarkTheme({
  String? fontFamily,
  List<String>? fontFamilyFallback,
}) {
  final base = ColorScheme.fromSeed(
    seedColor: kBrandBlue,
    brightness: Brightness.dark,
  );

  // 👉 Ensure text/icons on "primary" are white in dark mode
  final scheme = base.copyWith(onPrimary: Colors.white);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: fontFamily, // null = device font
    fontFamilyFallback: fontFamilyFallback,

    appBarTheme: const AppBarTheme(centerTitle: true),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),

    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: scheme.primary);
        }
        return IconThemeData(color: scheme.onSurfaceVariant);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(color: scheme.primary, fontWeight: FontWeight.w700);
        }
        return TextStyle(color: scheme.onSurfaceVariant);
      }),
    ),
  );
}
