import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:provider/provider.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart' as p;

import 'l10n/generated/app_localizations.dart';
import 'app/theme.dart';
import 'shared/ui/hold_tip.dart';
import 'shared/ui/ink_text.dart';
import 'shared/ui/surfaces.dart';
import 'app/main_page.dart';
import 'app/biometric_lock_gate.dart';
import 'app/branding_screen.dart';
import 'app/initial_setup.dart';
import 'data/db.dart';
import 'data/debt_provider.dart';
import 'data/expense_provider.dart';
import 'data/income_provider.dart';
import 'data/settings_provider.dart';
import 'data/upcoming_provider.dart';
import 'features/sms/bank_notifications.dart';
import 'shared/digits.dart';
import 'shared/keyboard_restorer.dart';

/// The app's license (GNU GPL v3) and the fonts' (SIL Open Font License
/// 1.1, Shabnam's with its Apache note), in full, among the open-source
/// licenses.
void _addFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (name, path) in const [
      // The app's own, first (GNU GPL v3; the owner, 2026-11-01).
      ('OpenFinances', 'LICENSE'),
      ('Shabnam (font)', 'assets/fonts/shabnam/LICENSE.txt'),
      ('Manrope (font)', 'assets/fonts/manrope/OFL.txt'),
      ('Vazirmatn (font)', 'assets/fonts/digits/Vazirmatn-OFL.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        name,
      ], await rootBundle.loadString(path));
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Always vertical (the owner, 2026-11-03; Android's own from the manifest).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  _addFontLicenses();
  await AppDb.instance.open();
  BankNotifications.listen();
  final settings = SettingsProvider();
  await settings.ready;
  // The fonts' letters measured before the first frame, so all text sits
  // centered from the start (InkText).
  await InkMetrics.instance.prepare(
    openFinancesDarkTheme(
      fontFamily: settings.fontFamily,
      fontFamilyFallback: settings.fontFamilyFallback,
    ).textTheme.bodyMedium!,
  );
  final preloaded = _Once(settings);

  runApp(
    Phoenix(
      child: MultiProvider(
        providers: [
          // The first one is loaded already; after a restart (Phoenix, e.g.
          // a restore) a fresh one reads the restored settings.
          ChangeNotifierProvider<SettingsProvider>(
            create: (_) => preloaded.take() ?? SettingsProvider(),
          ),
          ChangeNotifierProxyProvider<SettingsProvider, ExpenseProvider>(
            create: (_) => ExpenseProvider()..init(),
            // Amounts are shown in the currency setting's unit.
            update: (_, s, p) => p!..setDisplayCurrency(s.currencyCode),
          ),
          ChangeNotifierProxyProvider<SettingsProvider, IncomeProvider>(
            create: (_) => IncomeProvider()..init(),
            // Amounts are shown in the currency setting's unit.
            update: (_, s, p) => p!..setDisplayCurrency(s.currencyCode),
          ),
          ChangeNotifierProxyProvider<SettingsProvider, UpcomingProvider>(
            create: (_) => UpcomingProvider()..init(),
            // Amounts are shown in the currency setting's unit.
            update: (_, s, p) => p!..setDisplayCurrency(s.currencyCode),
          ),
          ChangeNotifierProxyProvider<SettingsProvider, DebtProvider>(
            create: (_) => DebtProvider()..init(),
            // Amounts are shown in the currency setting's unit.
            update: (_, s, p) => p!..setDisplayCurrency(s.currencyCode),
          ),
        ],
        child: const KeyboardRestorer(child: OpenFinancesApp()),
      ),
    ),
  );
}

/// A value handed out once (then null).
class _Once<T> {
  _Once(this._value);
  T? _value;
  T? take() {
    final v = _value;
    _value = null;
    return v;
  }
}

class OpenFinancesApp extends StatelessWidget {
  const OpenFinancesApp({super.key});

  /// The last themes built, and what they were built from: the same
  /// ThemeData objects until the color or a font changes (a new one each
  /// build made MaterialApp fade every page's theme on any settings change,
  /// e.g. a period arrow).
  static (Color, String?, List<String>)? _themeKey;
  static (ThemeData, ThemeData)? _themes;

  @override
  Widget build(BuildContext context) {
    // Only what the app shell uses: other settings changes don't rebuild it.
    final (seed, font, fontFallback, themeMode, locale) = context
        .select<
          SettingsProvider,
          (Color, String?, List<String>, ThemeMode, Locale)
        >(
          (s) => (
            s.seedColor,
            s.fontFamily,
            s.fontFamilyFallback,
            s.themeMode,
            s.locale,
          ),
        );
    final key = (seed, font, fontFallback);
    if (_themeKey != key || _themes == null) {
      _themes = _buildThemes(seed, font, fontFallback);
      _themeKey = key;
    }
    final (light, dark) = _themes!;
    builtDarkTheme = dark;
    return _app(context, light, dark, themeMode, locale, font, fontFallback);
  }

  static (ThemeData, ThemeData) _buildThemes(
    Color seed,
    String? font,
    List<String> fontFallback,
  ) {
    // LIGHT
    final lightBase = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(primary: seed, onPrimary: onColor(seed));
    // Pills inside tiles: a clear step above the tiles (surfaces.dart).
    final lightScheme = lightBase.copyWith(
      surfaceContainerHighest: surfaceTone(lightBase, 2),
    );

    // The font (app's own per language, or the device's) is set once here:
    // every theme text style, and so every widget, derives from it.
    final ThemeData light =
        openFinancesLightTheme(
          fontFamily: font,
          fontFamilyFallback: fontFallback,
        ).copyWith(
          colorScheme: lightScheme,
          appBarTheme: AppBarTheme(
            backgroundColor: lightScheme.surface,
            foregroundColor: lightScheme.onSurface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: lightScheme.primary,
            foregroundColor: lightScheme.onPrimary,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(lightScheme.primary),
              foregroundColor: WidgetStatePropertyAll(lightScheme.onPrimary),
            ),
          ),
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            elevation: 6,
          ),
        );

    // DARK
    final darkBase =
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ).copyWith(
          primary: seed,
          onPrimary: onColor(seed),
          surface: kAppBg,
          surfaceContainerLowest: const Color(0xFF1A1B1D),
          surfaceContainerLow: const Color(0xFF222326),
          surfaceContainer: const Color(0xFF24262A),
          surfaceContainerHigh: const Color(0xFF26282C),
        );
    final darkScheme = darkBase.copyWith(
      surfaceContainerHighest: surfaceTone(darkBase, 2),
    );

    final ThemeData dark =
        openFinancesDarkTheme(
          fontFamily: font,
          fontFamilyFallback: fontFallback,
        ).copyWith(
          colorScheme: darkScheme,
          scaffoldBackgroundColor: kAppBg,
          canvasColor: kAppBg,
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: kAppBg,
            modalBackgroundColor: kAppBg,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: kAppBg,
            surfaceTintColor: Colors.transparent,
          ),
          cardTheme: const CardThemeData(surfaceTintColor: Colors.transparent),
          appBarTheme: const AppBarTheme(
            backgroundColor: kAppBg,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: darkScheme.primary,
            foregroundColor: darkScheme.onPrimary,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(darkScheme.primary),
              foregroundColor: WidgetStatePropertyAll(darkScheme.onPrimary),
            ),
          ),
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            elevation: 6,
          ),
        );

    return (_minimal(light), _minimal(dark));
  }

  Widget _app(
    BuildContext context,
    ThemeData light,
    ThemeData dark,
    ThemeMode themeMode,
    Locale locale,
    String? font,
    List<String> fontFallback,
  ) {
    return MaterialApp(
      locale: locale,
      title: 'OpenFinances',
      debugShowCheckedModeBanner: false,

      // Localization
      supportedLocales: const [
        Locale('fa', 'IR'),
        Locale('en', 'US'),
        ...AppLocalizations.supportedLocales,
      ],
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        p.PersianMaterialLocalizations.delegate,
        p.PersianCupertinoLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Lists stop at their ends: no stretch (or glow) past them.
      scrollBehavior: const _NoOverscroll(),

      themeMode: themeMode,
      theme: light,
      darkTheme: dark,

      // One font everywhere: anything that builds a bare TextStyle (overlays,
      // tooltips, third-party widgets) still inherits the app font.
      builder: (context, child) => DigitsScope(
        style: context.select<SettingsProvider, DigitStyle>(
          (s) => s.digitStyle,
        ),
        order: context.select<SettingsProvider, DateOrder>((s) => s.dateOrder),
        child: InkMetricsScope(
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontFamily: font,
              fontFamilyFallback: fontFallback,
            ),
            // The lock wraps the whole Navigator, so its blur also covers open
            // sheets/dialogs (it used to sit inside the home page only). Over
            // it all, once per launch, the branding screen.
            child: Stack(
              fit: StackFit.expand,
              children: [
                _AppLock(child: child!),
                const BrandingOverlay(),
              ],
            ),
          ),
        ),
      ),

      // 🔐 After onboarding, still respect biometric gate.
      home: InitialSetupGate(child: _AppEntry()),
    );
  }
}

/// Scrolling as Material's, without the stretch Android 12+ plays when a
/// list can go no further (the owner's call: nothing moves past an end).
class _NoOverscroll extends MaterialScrollBehavior {
  const _NoOverscroll();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

/// App-wide "no lines" look: no borders or dividers — surfaces are told
/// apart by background color only. Tooltips sit on the app background.
ThemeData _minimal(ThemeData t) {
  final cs = t.colorScheme;
  final bg = t.scaffoldBackgroundColor;
  final noStroke = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  );
  // No ripple / pressed highlight anywhere. InkWell-based widgets (ListTile,
  // chips, menus, InkWell itself) read the theme's splash/highlight; button-
  // style widgets and tabs draw their own overlay, so those are cleared too.
  const none = WidgetStatePropertyAll<Color?>(Colors.transparent);
  ButtonStyle quiet(ButtonStyle? s) => (s ?? const ButtonStyle()).copyWith(
    overlayColor: none,
    splashFactory: NoSplash.splashFactory,
  );
  return t.copyWith(
    // One background for pages, sheets, menus and dialogs: "surface" is
    // the app background (in light mode they used to differ, so a menu
    // opened from a sheet showed a different color).
    colorScheme: cs.copyWith(surface: bg),
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    filledButtonTheme: FilledButtonThemeData(
      style: quiet(t.filledButtonTheme.style),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: quiet(t.elevatedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(style: quiet(t.textButtonTheme.style)),
    iconButtonTheme: IconButtonThemeData(style: quiet(t.iconButtonTheme.style)),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: quiet(t.segmentedButtonTheme.style),
      selectedIcon: t.segmentedButtonTheme.selectedIcon,
    ),
    tabBarTheme: t.tabBarTheme.copyWith(
      overlayColor: none,
      splashFactory: NoSplash.splashFactory,
    ),
    switchTheme: t.switchTheme.copyWith(overlayColor: none),
    checkboxTheme: t.checkboxTheme.copyWith(overlayColor: none),
    radioTheme: t.radioTheme.copyWith(overlayColor: none),
    tooltipTheme: TooltipThemeData(
      // Above what's held (not under the finger), and a moment after the
      // lift before it goes (the owner, 2026-10-29; every tip fades
      // for kTipFadeOut).
      preferBelow: false,
      showDuration: kTipFadeOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      // Derive from the text theme so the app font carries over (a bare
      // TextStyle here replaces the tooltip's whole style, font included).
      textStyle: t.textTheme.bodyMedium?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    // Pop-ups sit on the app background, not white/tinted surfaces.
    snackBarTheme: t.snackBarTheme.copyWith(
      backgroundColor: bg,
      contentTextStyle: t.textTheme.bodyMedium?.copyWith(color: cs.onSurface),
      actionTextColor: cs.primary,
      behavior: SnackBarBehavior.floating,
      elevation: 6,
    ),
    dialogTheme: t.dialogTheme.copyWith(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: t.popupMenuTheme.copyWith(
      color: bg,
      surfaceTintColor: Colors.transparent,
    ),
    menuTheme: MenuThemeData(
      style: (t.menuTheme.style ?? const MenuStyle()).copyWith(
        backgroundColor: WidgetStatePropertyAll(bg),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    bottomSheetTheme: t.bottomSheetTheme.copyWith(
      backgroundColor: bg,
      modalBackgroundColor: bg,
      surfaceTintColor: Colors.transparent,
    ),
    datePickerTheme: t.datePickerTheme.copyWith(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHigh,
      border: noStroke,
      enabledBorder: noStroke,
      focusedBorder: noStroke,
      disabledBorder: noStroke,
    ),
    dividerTheme: const DividerThemeData(color: Colors.transparent),
    // No scrollbars anywhere (dropdown and menu lists force-show theirs,
    // so hide the thumb itself rather than relying on scroll behavior).
    scrollbarTheme: const ScrollbarThemeData(
      thickness: WidgetStatePropertyAll(0),
      thumbColor: WidgetStatePropertyAll(Colors.transparent),
      trackColor: WidgetStatePropertyAll(Colors.transparent),
      trackBorderColor: WidgetStatePropertyAll(Colors.transparent),
    ),
    chipTheme: t.chipTheme.copyWith(side: BorderSide.none),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: quiet(
        OutlinedButton.styleFrom(
          side: BorderSide.none,
          backgroundColor: cs.surfaceContainerHigh,
        ),
      ),
    ),
  );
}

class _AppEntry extends StatelessWidget {
  const _AppEntry();

  @override
  Widget build(BuildContext context) => const MainPage();
}

class _AppLock extends StatelessWidget {
  const _AppLock({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enabled = context.select<SettingsProvider, bool>(
      (s) => s.biometricEnabled,
    );
    return BiometricLockGate(
      enabled: enabled,
      allowDeviceCredential: true,
      // Below MaterialApp's Localizations, so the prompt follows the UI.
      reason: AppLocalizations.of(context)?.unlockReason ?? '',
      child: child,
    );
  }
}
