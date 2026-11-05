import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:openfinances/shared/ui/check_box.dart';
import 'package:openfinances/shared/ui/split_chip.dart';
import 'package:openfinances/app/biometric_lock_gate.dart';
import 'package:openfinances/data/backup.dart';
import 'package:openfinances/features/sms/bank_notifications.dart';
import 'package:openfinances/shared/backup_pick.dart';
import 'package:openfinances/app/brand_mark.dart';
import 'package:openfinances/app/branding_screen.dart';
import 'package:openfinances/app/theme.dart';
import 'package:openfinances/shared/ui/app_icons.dart';
import 'package:openfinances/shared/ui/color_picker_page.dart';
import 'package:openfinances/shared/ui/fold_section.dart';
import 'package:openfinances/shared/ui/privacy_sheet.dart';
import 'package:openfinances/shared/ui/segmented_pills.dart';
import 'package:openfinances/shared/ui/square_chip.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/app_notice.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/settings_provider.dart';
import '../data/expense_provider.dart';
import '../data/income_provider.dart';
import '../data/category_repository.dart';

/// Pref key: the first-launch setup (language) is done.
const String kOnboardingDoneKey = 'onboarding_done_v1';

/// Whether the first-launch setup is done (older builds stored it as a
/// string or a number).
bool onboardingDone(SharedPreferences sp) {
  final dynamic v = sp.get(kOnboardingDoneKey);
  if (v is bool) return v;
  if (v is String) {
    final s = v.toLowerCase().trim();
    // accept common truthy strings from older builds
    return s == 'true' || s == '1' || s == 'yes' || s == 'done';
  }
  if (v is int) return v != 0;
  return false;
}

class InitialSetupGate extends StatefulWidget {
  const InitialSetupGate({super.key, required this.child});
  final Widget child;

  @override
  State<InitialSetupGate> createState() => _InitialSetupGateState();
}

class _InitialSetupGateState extends State<InitialSetupGate> {
  static const _kOnboardingDone = kOnboardingDoneKey;
  bool _loading = true;
  bool _showSetup = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  bool _readOnboardingDone(SharedPreferences sp) => onboardingDone(sp);

  /// Ensure the stored value ends up as a proper bool
  Future<void> _migrateOnboardingDone(SharedPreferences sp, bool value) async {
    // remove any old non-bool then set the canonical bool
    await sp.remove(_kOnboardingDone);
    await sp.setBool(_kOnboardingDone, value);
  }

  Future<void> _check() async {
    final sp = await SharedPreferences.getInstance();
    final done = _readOnboardingDone(sp);
    // If it wasn't a bool, migrate it quietly
    if (sp.get(_kOnboardingDone) is! bool) {
      await _migrateOnboardingDone(sp, done);
    }
    _showSetup = !done;
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // The introduction gives way to the app with a short fade.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _showSetup
          ? InitialSetupPage(
              key: const ValueKey('intro'),
              onFinished: () async {
                final sp = await SharedPreferences.getInstance();
                await _migrateOnboardingDone(sp, true); // always store as bool
                if (mounted) setState(() => _showSetup = false);
              },
            )
          : KeyedSubtree(key: const ValueKey('app'), child: widget.child),
    );
  }
}

/// The introduction (the very first launch): it carries on from the
/// branding screen. It starts as that screen's last picture (the lockup in
/// the same place, so the hand-over can't be seen); then the three lines
/// rise up and out of the page and its rows come in, each fading in while
/// rising into place, centered (the owner, 2026-10-25):
/// - the languages, two chips in one, the one picked in the theme color
///   (English to start); picking one puts the app (and the page) in it at
///   once, with its calendar and currency;
/// - "More options", closed: the theme color, calendar, currency and
///   digits, to change what the language set;
/// - "I've read the privacy policy" (its name opens it) and "Show tips",
///   with checkboxes; Continue, into the app once the first is ticked.
class InitialSetupPage extends StatefulWidget {
  const InitialSetupPage({super.key, required this.onFinished});
  final VoidCallback onFinished;

  @override
  State<InitialSetupPage> createState() => _InitialSetupPageState();
}

class _InitialSetupPageState extends State<InitialSetupPage>
    with TickerProviderStateMixin {
  String _language = 'en'; // the language picked (English to start)
  bool _calendarSet = false; // changed here: a language no longer sets it
  bool _currencySet = false;
  bool _privacy = false; // "I've read the privacy policy"
  bool _tips = false; // tips: off unless turned on here (or in Settings)
  bool _saving = false;

  // The timeline (ms) once the branding screen is gone: the lockup rises
  // out 0-700; the rows come in one after another, 420-1140.
  static const _total = 1140;
  late final _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _total),
  );

  /// The privacy row pulsing red: Continue tapped before it was ticked.
  late final _privacyPulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  /// How far a row rises as it comes in (as the brand's lines do, a
  /// little more: they're bigger).
  static const double _rise = 16;

  static const double _width = 320;
  static const _round = Radius.circular(16);

  final _scroll = ScrollController();
  double _extent = 0;

  /// The page grew (More opening): keep its end, Continue, in view.
  bool _followEnd(ScrollMetricsNotification n) {
    final max = n.metrics.maxScrollExtent;
    if (max > _extent && _scroll.hasClients) {
      _scroll.jumpTo(max);
    }
    _extent = max;
    return false;
  }

  /// The lockup's place on the page (its top-middle on the screen, laid
  /// out: measured after each frame until it's there). It starts at the
  /// branding screen's place and moves up into it.
  final _slot = GlobalKey();
  Offset? _slotAt;

  void _measureSlot() {
    final box = _slot.currentContext?.findRenderObject() as RenderBox?;
    if (!mounted || box == null || !box.hasSize) return;
    final at = box.localToGlobal(Offset(box.size.width / 2, 0));
    if (at != _slotAt) setState(() => _slotAt = at);
  }

  @override
  void initState() {
    super.initState();
    // English to start, with its calendar and currency (shown as they'll
    // be: the page is in the language picked).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pickLanguage('en');
    });
    // Starts once the branding screen above has handed over.
    brandingOver.future.then((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _t.value = 1;
      } else {
        _t.forward();
      }
    });
  }

  @override
  void dispose() {
    _t.dispose();
    _privacyPulse.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// 0..1 over [from, to] ms of the timeline, eased.
  double _span(int from, int to) => Curves.easeOutCubic.transform(
    ((_t.value * _total - from) / (to - from)).clamp(0.0, 1.0),
  );

  /// The app (and this page) in [lang] at once, with its calendar and
  /// currency (fa: Jalali, toman; en: Gregorian, euro) unless they were
  /// changed here.
  Future<void> _pickLanguage(String lang) async {
    setState(() => _language = lang);
    final settings = context.read<SettingsProvider>();
    await settings.setLocale(Locale(lang));
    if (!_calendarSet) {
      await settings.setCalendar(
        lang == 'fa' ? AppCalendar.jalali : AppCalendar.gregorian,
      );
    }
    if (!_currencySet) await settings.setCurrency(lang == 'fa' ? 'IRT' : 'EUR');
  }

  /// Three red pulses on the privacy row, unless it's ticked meanwhile.
  Future<void> _pointAtPrivacy() async {
    try {
      for (var i = 0; i < 3 && !_privacy; i++) {
        await _privacyPulse.forward(from: 0).orCancel;
        await _privacyPulse.reverse().orCancel;
      }
    } on TickerCanceled {
      // Ticked, or the page closed.
    }
  }

  void _togglePrivacy() {
    setState(() => _privacy = !_privacy);
    if (_privacy) {
      _privacyPulse
        ..stop()
        ..value = 0;
    }
  }

  /// A backup, chosen and read, put in place; then straight into the app,
  /// restarted with the backup's settings (its language among them): the
  /// introduction is done. Over a fresh install it replaces; should the app
  /// have data somehow, it merges (never loses any).
  Future<void> _restore() async {
    if (_saving) return;
    final l = AppLocalizations.of(context)!;
    final notice = AppNotice.of(context);
    final data = await pickBackup(context);
    if (data == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final merge = await BackupData.appHasData();
      final report = await data.restore(
        merge: merge,
        currentBank: BankNotifications.exportData,
        importBank: BankNotifications.importData,
      );
      // Said after the restart (the app reloads everything).
      BackupData.lastRestore = report;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kOnboardingDoneKey, true);
      if (!mounted) return;
      BiometricLockGate.trustNow(); // they're here: no lock on the way in
      Phoenix.rebirth(context);
    } catch (e) {
      if (!mounted) return;
      notice.show(l.restoreError(e.toString()), kind: NoticeKind.failure);
      setState(() => _saving = false);
    }
  }

  /// Into the app: everything picked here is set already (but tips); the
  /// default categories get the language's names.
  Future<void> _continue() async {
    if (!_privacy) {
      _pointAtPrivacy();
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    final lang = _language;
    try {
      final settings = context.read<SettingsProvider>();
      final expenses = context.read<ExpenseProvider>();
      final income = context.read<IncomeProvider>();
      if (_tips) await settings.setTipsOn(true);

      // Name the default categories in the chosen language. Best effort: a
      // hiccup here must never block onboarding.
      final desiredName = lookupAppLocalizations(Locale(lang)).generalCategory;
      try {
        await _localizeDefault(
          load: expenses.loadCategories,
          current: () => expenses.categories,
          rename: expenses.renameCategory,
          upsert: expenses.upsertCategory,
          seedGid: 'cat_general',
          name: desiredName,
        );
        await _localizeDefault(
          load: income.loadCategories,
          current: () => income.categories,
          rename: income.renameCategory,
          upsert: income.upsertCategory,
          seedGid: 'inccat_general',
          name: desiredName,
        );
      } catch (e) {
        debugPrint('[InitialSetup] default category naming skipped: $e');
      }

      widget.onFinished();
    } catch (_) {
      if (!mounted) return;
      showAppNotice(
        context,
        lookupAppLocalizations(Locale(lang)).failedToSaveSettings,
        kind: NoticeKind.failure,
      );
      setState(() => _saving = false);
    }
  }

  /// If the user still has just the one seeded category, give it the
  /// localized name; if there is none, recreate it under the seeded gid
  /// (other code falls back to that gid).
  Future<void> _localizeDefault({
    required Future<void> Function() load,
    required List<CategoryDto> Function() current,
    required Future<void> Function(String gid, String name) rename,
    required Future<void> Function(CategoryDto c) upsert,
    required String seedGid,
    required String name,
  }) async {
    await load();
    final cats = current();
    if (cats.isEmpty) {
      final now = DateTime.now().toUtc();
      await upsert(
        CategoryDto(
          gid: seedGid,
          name: name,
          sort: 1000,
          createdAtUtc: now,
          updatedAtUtc: now,
          iconCodePoint: Icons.category.codePoint,
          iconFontFamily: 'MaterialIcons',
          color: const Color(0xFF607D8B).toARGB32(),
        ),
      );
    } else if (cats.length == 1 && cats.first.name != name) {
      await rename(cats.first.gid, name);
    }
    // Several categories: the user has set things up already — leave them.
  }

  /// The checkbox of the privacy and tips rows: a white outline, or filled
  /// with the theme color and its check on it.
  Widget _box(bool on, Color seed) => CheckBoxMark(
    on: on,
    color: seed,
    checkColor: onColor(seed),
    outline: Colors.white,
  );

  /// The privacy sheet; read to its "Got it", the row is ticked.
  Future<void> _openPrivacy(BuildContext context) async {
    if (await showPrivacySheet(context) && mounted && !_privacy) {
      _togglePrivacy();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dark whatever the theme mode: it carries on from the dark branding
    // screen.
    return Theme(
      data: builtDarkTheme ?? Theme.of(context),
      child: Builder(builder: _page),
    );
  }

  Widget _page(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    final seed = sp.seedColor;
    final screen = MediaQuery.sizeOf(context);
    // The branding screen's last picture: the lockup where it left it.
    final place =
        BrandingOverlay.place ?? BrandingOverlay.designedPlace(screen);
    final width = (screen.width - 2 * 48).clamp(0.0, _width);
    // The page's own text one size under what it was (the owner,
    // 2026-10-25); More's rows keep the app's sizes.
    const white = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    );

    // The languages: two chips in one (square where they meet, a little
    // apart: lib/shared/ui/split_chip.dart), each name
    // in its own language and font, left to right in both; the one picked
    // in the theme color.
    Widget language(String value, String label, String font, bool first) {
      final picked = _language == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => _pickLanguage(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: picked ? seed : kBrandPlate,
              borderRadius: first
                  ? const BorderRadius.horizontal(left: _round)
                  : const BorderRadius.horizontal(right: _round),
            ),
            child: InkText(
              label,
              textDirection: value == 'fa'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: font,
                fontFamilyFallback: const [],
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: picked ? onColor(seed) : Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    final languages = Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          language('en', 'English', 'Manrope', true),
          const SizedBox(width: kPartGap),
          language('fa', 'فارسی', 'Shabnam', false),
        ],
      ),
    );

    // More: what the language sets, to change (closed to start). The
    // digits are Settings' only.
    final more = FoldSection(
      id: 'setup.more',
      title: l.setupMore,
      children: [
        // The theme color as a square before the calendar (as in
        // Settings).
        SquareRow(
          leading: SquareChip(
            tooltip: l.themeColors,
            onTap: () async {
              final settings = context.read<SettingsProvider>();
              final picked = await Navigator.of(context).push<Color>(
                MaterialPageRoute(
                  builder: (_) =>
                      ColorPickerPage(initial: seed, isThemeColor: true),
                  fullscreenDialog: true,
                ),
              );
              if (picked != null) await settings.setSeedColor(picked);
            },
            child: ImageIcon(AppIcons.palette, color: seed),
          ),
          child: SegmentedPills<AppCalendar>(
            radius: 10,
            selected: sp.calendar,
            onChanged: (c) {
              _calendarSet = true;
              context.read<SettingsProvider>().setCalendar(c);
            },
            options: {
              AppCalendar.jalali: l.calendarJalali,
              AppCalendar.gregorian: l.calendarGregorian,
            },
          ),
        ),
        SegmentedPills<String>(
          radius: 10,
          selected: sp.currencyCode,
          onChanged: (v) {
            _currencySet = true;
            context.read<SettingsProvider>().setCurrency(v);
          },
          options: {
            'IRT': l.currencyToman,
            'IRR': l.currencyRial,
            'USD': r'$',
            'EUR': '€',
          },
        ),
      ],
    );

    // A row with a checkbox at its start; a tap anywhere on it ticks.
    Widget checkRow({
      required bool on,
      required VoidCallback onTap,
      required Widget child,
      Animation<double>? attention,
    }) => GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: attention ?? kAlwaysDismissedAnimation,
        builder: (context, child) => Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: SegmentedPills.attentionColor(kBrandPlate, attention),
            borderRadius: const BorderRadius.all(_round),
          ),
          child: child,
        ),
        child: Row(
          children: [
            _box(on, seed),
            const SizedBox(width: 12),
            // One line; smaller rather than cut (large system text).
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );

    // "I've read the privacy policy": the policy's name opens it.
    const mark = '\u0000';
    final readParts = l.privacyRead(mark).split(mark);
    final privacy = checkRow(
      on: _privacy,
      onTap: _togglePrivacy,
      attention: _privacyPulse,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (readParts.first.isNotEmpty)
            InkText(readParts.first, style: white),
          GestureDetector(
            onTap: () => _openPrivacy(context),
            child: InkText(
              l.privacyPolicy,
              style: white.copyWith(color: context.primaryInk),
            ),
          ),
          if (readParts.length > 1 && readParts.last.isNotEmpty)
            InkText(readParts.last, style: white),
        ],
      ),
    );
    final tips = checkRow(
      on: _tips,
      onTap: () => setState(() => _tips = !_tips),
      child: InkText(l.showTips, style: white),
    );
    // Restore, beside Tips: a backup straight into the app (no Continue,
    // no privacy tick: whoever has a backup has been here before).
    final restore = GestureDetector(
      onTap: _restore,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: seed,
          borderRadius: const BorderRadius.all(_round),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: InkText(
            l.restore,
            style: white.copyWith(color: onColor(seed)),
          ),
        ),
      ),
    );

    // Into the app: the theme color once the privacy row is ticked, grey
    // before (a tap then points at that row).
    final go = GestureDetector(
      onTap: _continue,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _privacy ? seed : kBrandPlate,
          borderRadius: const BorderRadius.all(_round),
        ),
        child: InkText(
          l.setupContinue,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _privacy
                ? onColor(seed)
                : Colors.white.withValues(alpha: .45),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: kSplashBg,
      body: AbsorbPointer(
        absorbing: _saving,
        child: AnimatedBuilder(
          animation: _t,
          builder: (context, _) {
            // The lockup moves up from the branding screen's place to its
            // own (0-700), the subline fading out on the way (0-350); the
            // rows come in under it.
            final move = Curves.easeInOutCubic.transform(
              (_t.value * _total / 700).clamp(0.0, 1.0),
            );
            final fade = (_t.value * _total / 350).clamp(0.0, 1.0);
            final slot = _slotAt;
            final from = slot == null
                ? Offset.zero
                : Offset(place.middle - slot.dx, place.top - slot.dy);
            if (_t.value < 1) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _measureSlot(),
              );
            }
            Widget enter(int from, Widget child) {
              final t = _span(from, from + 480);
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * _rise),
                  child: child,
                ),
              );
            }

            // Centered; scrolling once "More" makes it taller than the
            // screen. Tappable once the rows are coming in.
            return IgnorePointer(
              ignoring: _t.value * _total < 420,
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, box) =>
                      NotificationListener<ScrollMetricsNotification>(
                        onNotification: _followEnd,
                        child: SingleChildScrollView(
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: (box.maxHeight - 48).clamp(
                                0.0,
                                double.infinity,
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // The mark and the name stay (the subline
                                  // fades, its room kept as space).
                                  SizedBox(
                                    key: _slot,
                                    child: Transform.translate(
                                      offset: from * (1 - move),
                                      child: BrandLockup(
                                        scale: place.scale,
                                        sublineOpacity: 1 - fade,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: width,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        enter(420, languages),
                                        const SizedBox(height: 12),
                                        enter(500, more),
                                        // As far from the rows under it as
                                        // from the languages over it.
                                        const SizedBox(height: 12),
                                        enter(580, privacy),
                                        const SizedBox(height: 8),
                                        enter(
                                          620,
                                          Row(
                                            children: [
                                              Expanded(child: tips),
                                              const SizedBox(width: 8),
                                              Expanded(child: restore),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        enter(660, go),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
