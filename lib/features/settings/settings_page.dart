// lib/features/settings/settings_page.dart
import 'package:openfinances/shared/calendar_text.dart' show isFaUi;
import 'package:openfinances/shared/ui/day_wheel.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/keep_in_view.dart';
import 'package:openfinances/app/app_bottom_bar.dart';

import 'package:flutter/material.dart';
import 'package:openfinances/shared/money_input.dart';
import 'package:openfinances/app/theme.dart';
import 'package:openfinances/data/entry_suggestions.dart';
import 'package:openfinances/shared/ui/app_notice.dart';
import 'package:openfinances/shared/ui/app_icons.dart';
import 'package:flutter/services.dart'; // MethodChannel + SystemChannels
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:openfinances/data/backup.dart';
import 'package:openfinances/data/expense_provider.dart';
import 'package:openfinances/data/income_provider.dart';
import 'package:openfinances/data/upcoming_provider.dart';
import 'package:openfinances/data/debt_provider.dart';
import 'package:openfinances/data/debt_repository.dart';
import 'package:openfinances/features/settings/categories_page.dart';
import 'package:openfinances/features/settings/licenses_page.dart';
import 'package:openfinances/shared/ui/glitch_icon.dart';
import 'package:openfinances/features/settings/change_log.dart';

import 'package:openfinances/shared/ui/split_chip.dart' show kPartGap;
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:openfinances/app/biometric_lock_gate.dart';
import 'package:openfinances/app/brand_mark.dart';
import 'package:openfinances/app/branding_screen.dart';
import 'package:openfinances/app/family_marks.dart';
import 'package:openfinances/shared/ui/fold_section.dart';
import 'package:openfinances/shared/ui/tab_swipe.dart';
import 'package:openfinances/features/widgets/bare_app_bar.dart';
import 'package:openfinances/features/sms/bank_notifications.dart';
import 'package:openfinances/shared/ui/surfaces.dart';
import 'package:openfinances/features/sms/sms_formats_page.dart';
import 'package:openfinances/shared/ui/entry_fields.dart';
import 'package:openfinances/shared/ui/scroll_chain.dart';
import 'package:openfinances/shared/ui/scroll_hint.dart';
import 'package:openfinances/shared/ui/segmented_pills.dart';
import 'package:openfinances/shared/ui/color_picker_page.dart';
import 'package:local_auth/local_auth.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart' as p;
import 'package:provider/provider.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:openfinances/shared/digits.dart';
import 'package:openfinances/shared/ui/group_fit.dart';
import 'package:openfinances/shared/ui/square_chip.dart';
import 'package:openfinances/shared/ui/privacy_sheet.dart';
import 'package:openfinances/shared/backup_pick.dart';
import 'package:openfinances/shared/haptics.dart';

/// Corner radius for settings chips, buttons and rows (less than a pill).
const double _kChipRadius = 10;

/// Gap between rows of one group, and between groups.
const double _kRowGap = 8;

/// The page's side margin (the list's horizontal padding).
const double _kPageGutter = 12;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const MethodChannel _downloadsCh = MethodChannel(
    'openfinances/downloads',
  );

  // ---------- helpers ----------

  static Map<String, dynamic> settingsToMap(SettingsProvider s) => {
    'themeMode': s.themeMode.name,
    'seedColor': s.seedColor.toARGB32(),
    'currencyCode': s.currencyCode,
    'startDay': s.startDay,
    'biometricEnabled': s.biometricEnabled,
    'localeCode': s.locale.languageCode,
    'calendar': s.calendar.name,
  };

  // ===== ANDROID: Save to Downloads (or [folder]) via MethodChannel =====
  /// Whether the app can still write in the folder [uri].
  static Future<bool> _hasFolderAccess(String uri) async {
    try {
      final ok = await _downloadsCh.invokeMethod<bool>('hasFolderAccess', {
        'uri': uri,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// The system's folder picker, on the current folder; the one picked is kept
  /// and returned (null: none picked).
  static Future<String?> _pickFolder(
    SettingsProvider sp, {
    bool orThrow = false,
  }) async {
    try {
      final picked = await _downloadsCh.invokeMapMethod<String, Object?>(
        'pickFolder',
        {'current': ?sp.backupFolder},
      );
      final uri = picked?['uri'];
      if (uri is! String) return null;
      await sp.setBackupFolder(uri, picked?['name'] as String?);
      return uri;
    } catch (_) {
      if (orThrow) rethrow;
      return null;
    }
  }

  Future<String?> _saveToDownloadsAndroid({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    String? folder,
  }) async {
    try {
      final uri = await _downloadsCh.invokeMethod<String>('save', {
        'fileName': fileName,
        'mimeType': mimeType,
        'bytes': bytes,
        'folder': ?folder,
      });
      return uri; // content:// URI when successful
    } catch (_) {
      return null;
    }
  }

  // Read text with BOM detection (for restore)

  Future<void> _openCategoryManager(BuildContext context) async {
    final ep = context.read<ExpenseProvider>();
    final ip = context.read<IncomeProvider>();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CategoryTabsPage()));
    await ep.init();
    await ip.init();
  }

  // ---------- Phoenix-only restart ----------
  /// Restarts the app at once. (It used to wait for the next frame, but
  /// after a restore nothing on screen changes, so no frame came: the app
  /// sat still until a tap.)
  void _phoenixRestart(BuildContext context) {
    if (!context.mounted) return;
    // The user is in the app (they just restored): the restarted app
    // doesn't lock.
    BiometricLockGate.trustNow();
    Phoenix.rebirth(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final sp = context.watch<SettingsProvider>();
    final persian = sp.locale.languageCode == 'fa';
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = 24 + bottomSafe + kBottomNavigationBarHeight;

    // ---------- Biometric toggle ----------
    Future<void> toggleBiometric(BuildContext context, bool wantEnable) async {
      final spRead = context.read<SettingsProvider>();
      final notice = AppNotice.of(context);
      final auth = LocalAuthentication();

      if (wantEnable == spRead.biometricEnabled) return;

      try {
        final supported = await auth.isDeviceSupported();
        if (!supported) {
          notice.show(l.deviceNoBiometry, kind: NoticeKind.failure);
          return;
        }

        final ok = await auth.authenticate(
          localizedReason: wantEnable
              ? l.biometricEnableReason
              : l.biometricDisableReason,
          persistAcrossBackgrounding: true, // was stickyAuth
          sensitiveTransaction: true,
        );

        if (!ok) {
          notice.show(l.authFailed, kind: NoticeKind.failure);
          return;
        }

        spRead.markBiometricJustAuthed();
        await spRead.setBiometricEnabled(wantEnable);
      } on LocalAuthException catch (e) {
        // local_auth 3 reports typed codes (no more native error dialogs).
        final msg = switch (e.code) {
          LocalAuthExceptionCode.noBiometricHardware ||
          LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable =>
            l.biomNotAvailable,
          LocalAuthExceptionCode.noBiometricsEnrolled => l.biomNotEnrolled,
          LocalAuthExceptionCode.noCredentialsSet => l.passcodeNotSet,
          LocalAuthExceptionCode.temporaryLockout => l.lockedOut,
          LocalAuthExceptionCode.biometricLockout => l.permanentlyLockedOut,
          // Cancel/timeout used to come back as `false` — same message.
          LocalAuthExceptionCode.userCanceled ||
          LocalAuthExceptionCode.systemCanceled ||
          LocalAuthExceptionCode.timeout => l.authFailed,
          _ => l.authUnavailable,
        };
        notice.show(msg, kind: NoticeKind.failure);
      }
    }

    // ---------- UI ----------
    // From the text theme: these replace the inherited style, so a bare
    // TextStyle would drop the app font.
    final textTheme = Theme.of(context).textTheme;
    final listTileTitle15 = textTheme.bodyLarge!.copyWith(
      fontSize: 15,
      color: scheme.onSurface,
    );
    final listTileSubtitle13 = textTheme.bodyMedium!.copyWith(
      fontSize: 13,
      color: scheme.onSurfaceVariant,
    );

    // Inline state via StatefulBuilder

    /// A backup ([full], or expenses with their categories and budgets) as
    /// JSON or [excel], saved to Download or the folder picked (with a Share
    /// action). Resolves to whether it was saved; any part that can't be
    /// read fails it.
    Future<bool> doExport({
      required bool full,
      required bool excel,
      String? name,
    }) async {
      final notice = AppNotice.of(context);
      final spRead = context.read<SettingsProvider>();
      try {
        final data = await BackupData.collect(
          full: full,
          settings: settingsToMap(spRead),
          bank: BankNotifications.exportData,
        );
        // Named by today's date in the user's calendar: OpenFinances-14050730.
        final fileName =
            '${name ?? _backupStem(spRead)}.${excel ? 'xlsx' : 'json'}';
        final mime = excel
            ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            : 'application/json';
        final bytes = excel ? data.toXlsx() : data.toJsonBytes();
        // A folder that came from a restored backup: its name is known, the
        // access to it isn't (Android ties that to the install). The picker
        // opens on it, one tap gives it back; declined, Download this time.
        var folder = spRead.backupFolder;
        if (folder != null && !await SettingsPage._hasFolderAccess(folder)) {
          folder = await SettingsPage._pickFolder(spRead);
          if (folder != null && !await SettingsPage._hasFolderAccess(folder)) {
            folder = null;
          }
        }
        final uri = await _saveToDownloadsAndroid(
          fileName: fileName,
          mimeType: mime,
          bytes: bytes,
          folder: folder,
        );
        if (!context.mounted) return uri != null;
        notice.show(
          uri != null
              // The folder's own name, not its path (the owner, 2026-11-02).
              ? l.backupSavedIn(
                  folder == null
                      ? 'Download'
                      : _backupFolderPath(
                          spRead,
                        ).split('\\').where((part) => part.isNotEmpty).last,
                )
              : l.backupError('save failed'),
          kind: uri != null ? NoticeKind.success : NoticeKind.failure,
          actionLabel: l.share,
          onAction: () => SharePlus.instance.share(
            ShareParams(
              files: [XFile.fromData(bytes, name: fileName, mimeType: mime)],
              fileNameOverrides: [fileName],
              subject: '${l.backupSubject} (${excel ? 'Excel' : 'JSON'})',
            ),
          ),
        );
        return uri != null;
      } catch (e) {
        if (!context.mounted) return false;
        notice.show(l.backupError(e.toString()), kind: NoticeKind.failure);
        return false;
      }
    }

    Future<void> doRestore() async {
      final notice = AppNotice.of(context); // capture before awaits
      try {
        final data = await pickBackup(context);
        if (data == null || !context.mounted) return;

        // The app has data of its own: the user says what becomes of it.
        var merge = false;
        if (await BackupData.appHasData()) {
          if (!context.mounted) return;
          final choice = await _restoreChoiceSheet(context);
          if (choice == null || !context.mounted) return;
          if (choice == _RestoreChoice.backUpAndReplace) {
            final saved = await doExport(full: true, excel: false);
            if (!saved || !context.mounted) return; // its notice says why
          }
          merge = choice == _RestoreChoice.merge;
        }

        final report = await data.restore(
          merge: merge,
          currentBank: BankNotifications.exportData,
          importBank: BankNotifications.importData,
        );
        // Said after the restart (the app reloads everything).
        BackupData.lastRestore = report;
        if (!context.mounted) return;
        _phoenixRestart(context);
      } catch (e) {
        if (!context.mounted) return;
        notice.show(l.restoreError(e.toString()), kind: NoticeKind.failure);
      }
    }

    return Scaffold(
      appBar: bareAppBar(),
      // No inline text fields here; don't relayout under add-sheet keyboards.
      resizeToAvoidBottomInset: false,
      body: ListTileTheme(
        data: ListTileThemeData(
          titleTextStyle: listTileTitle15,
          subtitleTextStyle: listTileSubtitle13,
        ),
        child: TabScrollTop(
          tab: 3,
          // Tapping this tab again scrolls back up.
          builder: (list) => ListView(
            controller: list,
            padding: EdgeInsets.fromLTRB(
              _kPageGutter,
              8,
              _kPageGutter,
              bottomPadding,
            ),
            children: [
              // As far from the top and from the first section as from the
              // screen's sides (it pads itself).
              const _AppHeader(),

              // ===== Personalization: look, the month, language, money =====
              FoldSection(
                id: 'settings.personalization',
                title: l.sectionPersonalization,
                children: [
                  SegmentedPills<ThemeMode>(
                    radius: _kChipRadius,
                    selected: sp.themeMode,
                    onChanged: (m) =>
                        context.read<SettingsProvider>().setThemeMode(m),
                    options: {
                      ThemeMode.system: l.system,
                      ThemeMode.light: l.light,
                      ThemeMode.dark: l.dark,
                    },
                  ),
                  // The theme color as a square, then the month's first day
                  // (a wheel, saved with the square after it).
                  _StartDayRow(
                    colorChip: SquareChip(
                      tooltip: l.themeColors,
                      onTap: () async {
                        final navigator = Navigator.of(context);
                        final settings = context.read<SettingsProvider>();
                        final picked = await navigator.push<Color>(
                          MaterialPageRoute(
                            builder: (_) => ColorPickerPage(
                              initial: settings.seedColor,
                              isThemeColor: true,
                            ),
                            fullscreenDialog: true,
                          ),
                        );
                        if (picked != null) settings.setSeedColor(picked);
                      },
                      child: ImageIcon(AppIcons.palette, color: sp.seedColor),
                    ),
                  ),
                  SegmentedPills<String>(
                    radius: _kChipRadius,
                    selected: sp.locale.languageCode,
                    onChanged: (code) => context
                        .read<SettingsProvider>()
                        .setLocale(Locale(code)),
                    // The change flips the page's direction: a slide
                    // would cross the whole row.
                    slide: false,
                    options: {'fa': l.persian, 'en': l.english},
                  ),
                  // Font for the current language: the app's own or the
                  // device's.
                  // A font for each language, each row in its own language
                  // (titles can mix them); Persian's only in Persian (the
                  // owner, 2026-11-03).
                  if (persian)
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: SegmentedPills<bool>(
                        radius: _kChipRadius,
                        selected: sp.appFontFa,
                        onChanged: (v) => context
                            .read<SettingsProvider>()
                            .setAppFont(fa: true, v: v),
                        options: const {
                          true: 'فونت شبنم',
                          false: 'فونت دستگاه',
                        },
                      ),
                    ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: SegmentedPills<bool>(
                      radius: _kChipRadius,
                      selected: sp.appFontEn,
                      onChanged: (v) => context
                          .read<SettingsProvider>()
                          .setAppFont(fa: false, v: v),
                      options: const {
                        true: 'Manrope font',
                        false: 'Device font',
                      },
                    ),
                  ),
                  SegmentedPills<AppCalendar>(
                    radius: _kChipRadius,
                    selected: sp.calendar,
                    onChanged: (c) =>
                        context.read<SettingsProvider>().setCalendar(c),
                    options: {
                      AppCalendar.jalali: l.calendarJalali,
                      AppCalendar.gregorian: l.calendarGregorian,
                    },
                  ),
                  // The order of a date's parts (at first, as the app
                  // always wrote them).
                  SegmentedPills<DateOrder>(
                    radius: _kChipRadius,
                    selected: sp.dateOrder,
                    onChanged: (v) =>
                        context.read<SettingsProvider>().setDateOrder(v),
                    options: {
                      DateOrder.standard: l.dateOrderDefault,
                      DateOrder.dmy: l.dateOrderDmy,
                      DateOrder.mdy: l.dateOrderMdy,
                      DateOrder.ymd: l.dateOrderYmd,
                    },
                  ),
                  // Digits: English, or Persian (each shown in itself);
                  // only in Persian (in English they're English).
                  if (persian)
                    SegmentedPills<DigitStyle>(
                      radius: _kChipRadius,
                      selected: sp.digitStyle,
                      onChanged: (v) =>
                          context.read<SettingsProvider>().setDigitStyle(v),
                      options: {
                        DigitStyle.persian: '۱۲۳',
                        DigitStyle.english: '123',
                      },
                    ),
                  SegmentedPills<String>(
                    radius: _kChipRadius,
                    selected:
                        const [
                          'IRT',
                          'IRR',
                          'USD',
                          'EUR',
                        ].contains(sp.currencyCode)
                        ? sp.currencyCode
                        : 'IRT',
                    // Only changes what's shown: stored amounts keep the unit
                    // they were recorded in (toman/rial are converted on
                    // display).
                    onChanged: (v) =>
                        context.read<SettingsProvider>().setCurrency(v),
                    options: {
                      'IRT': l.currencyToman,
                      'IRR': l.currencyRial,
                      'USD': r'$',
                      'EUR': '€',
                    },
                  ),
                  // Tips over what can't be seen (off by default; also on
                  // the first page). Turned on, they all show again, the
                  // scrolling hints and "never show again"s too. By
                  // it, the amount fields' "000" button (on in Persian
                  // by default; the owner, 2026-10-26).
                  ToggleChips<String>(
                    radius: _kChipRadius,
                    on: {
                      if (sp.tipsOn) 'tips',
                      if (sp.quickZeros) 'zeros',
                      if (sp.hapticsOn) 'haptics',
                    },
                    onTap: (k) {
                      if (k == 'zeros') {
                        sp.setQuickZeros(!sp.quickZeros);
                        return;
                      }
                      if (k == 'haptics') {
                        sp.setHapticsOn(!sp.hapticsOn);
                        return;
                      }
                      sp.setTipsOn(!sp.tipsOn);
                    },
                    options: {
                      'tips': l.showTips,
                      'zeros': l.quickZeros,
                      'haptics': l.haptics,
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ===== Tabs & access: home tabs, bank notifications, lock =====
              FoldSection(
                key: _tabsSectionKey,
                id: 'settings.tabs',
                // Its chips listen for "point here" requests.
                buildClosed: true,
                title: l.sectionTabsAccess,
                children: [
                  const _HomeTabsRow(),
                  // The biometric lock as a square, then the bank
                  // notifications (greyed out while the SMS tab is off).
                  SquareRow(
                    leading: SquareChip(
                      tooltip: l.biometricLock,
                      selected: sp.biometricEnabled,
                      onTap: () =>
                          toggleBiometric(context, !sp.biometricEnabled),
                      child: ImageIcon(
                        AppIcons.fingerprint,
                        color: sp.biometricEnabled
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    child: _Greyed(
                      off: !sp.tabSms,
                      onBlocked: () => _needSmsTab(context),
                      child: const _BankNotificationChips(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ===== What's not suggested =====
              const _IgnoredBox(),
              const SizedBox(height: 12),

              // ===== Data: categories, SMS formats, backup / restore =====
              FoldSection(
                id: 'settings.data',
                title: l.sectionData,
                children: [
                  // The two buttons' words one size.
                  FitGroup(
                    child: Row(
                      children: [
                        Expanded(
                          child: _dataButton(
                            context,
                            l.categories,
                            () => _openCategoryManager(context),
                          ),
                        ),
                        const SizedBox(width: _kRowGap),
                        Expanded(
                          child: _Greyed(
                            off: !sp.tabSms,
                            onBlocked: () => _needSmsTab(context),
                            child: _dataButton(
                              context,
                              l.smsFormats,
                              () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SmsFormatsPage(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _BackupOptions(
                    onBackup: (full, excel, name) =>
                        doExport(full: full, excel: excel, name: name),
                    onRestore: doRestore,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ===== About: credits, licenses, contact =====
              FoldSection(
                id: 'settings.about',
                title: 'About', // English, as all of it
                children: const [_AboutBox()],
              ),

              const _KeyboardRoom(),
            ],
          ),
        ),
      ),
    );
  }

  // ===== UI helpers =====

  /// A Data section button (categories, SMS formats).
  Widget _dataButton(BuildContext context, String text, VoidCallback onTap) =>
      FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          overlayColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_kChipRadius),
          ),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: GroupFit(child: InkText(text)),
      );
}

/// Something greyed out because the SMS tab is off was tapped: open Tabs &
/// access, scroll to the tab chips, flash the SMS chip red, and say why.
Future<void> _needSmsTab(BuildContext context) async {
  final l = AppLocalizations.of(context)!;
  showAppNotice(context, l.smsFirst);
  await _tabsSectionKey.currentState?.open();
  final target = _HomeTabsRow.where.currentContext;
  if (target == null || !target.mounted) return;
  // Scroll only if the tab chips aren't comfortably in view: clear of the
  // top, and of the bottom bar and the notice that just appeared there.
  final box = target.findRenderObject() as RenderBox?;
  if (box != null && box.attached) {
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final screen = MediaQuery.sizeOf(target).height;
    final pad = MediaQuery.paddingOf(target);
    const margin = 48.0;
    const noticeAndBar = 64 + 12 + 80.0; // bottom bar, gap, notice
    final comfortable =
        top >= pad.top + margin &&
        bottom <= screen - pad.bottom - noticeAndBar - margin;
    if (!comfortable && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        alignment: .3,
      );
    }
  }
  if (context.mounted) Haptics.alert(context);
  _HomeTabsRow.flash.value++;
}

final _tabsSectionKey = GlobalKey<FoldSectionState>();

/// Shown faded while [off] (e.g. SMS settings while the SMS tab is off); a
/// tap then calls [onBlocked] instead.
class _Greyed extends StatelessWidget {
  const _Greyed({
    required this.off,
    required this.child,
    required this.onBlocked,
  });
  final bool off;
  final Widget child;
  final VoidCallback onBlocked;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: off ? onBlocked : null,
    child: IgnorePointer(
      ignoring: off,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: off ? .4 : 1,
        child: child,
      ),
    ),
  );
}

/// The home page tabs (History always on); its SMS chip can be flashed red
/// ([flash]) when something needs that tab.
class _HomeTabsRow extends StatefulWidget {
  const _HomeTabsRow();

  /// Where the row is (to scroll to it).
  static final where = GlobalKey();

  /// Bumped to flash the SMS chip.
  static final flash = ValueNotifier<int>(0);

  @override
  State<_HomeTabsRow> createState() => _HomeTabsRowState();
}

class _HomeTabsRowState extends State<_HomeTabsRow>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void initState() {
    super.initState();
    _HomeTabsRow.flash.addListener(_flash);
  }

  @override
  void dispose() {
    _HomeTabsRow.flash.removeListener(_flash);
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _flash() async {
    try {
      for (var i = 0; i < 3; i++) {
        await _pulse.forward(from: 0).orCancel;
        await _pulse.reverse().orCancel;
      }
    } on TickerCanceled {
      // left the page
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return KeyedSubtree(
      key: _HomeTabsRow.where,
      // Each tab on or off by itself: toggles, not a choice.
      child: ToggleChips<String>(
        radius: _kChipRadius,
        attention: _pulse,
        attentionOn: 'sms',
        on: {
          'history',
          if (sp.tabUpcoming) 'upcoming',
          if (sp.tabDebts) 'debts',
          if (sp.tabSms) 'sms',
        },
        onTap: (t) => switch (t) {
          'history' => showAppNotice(context, l.historyAlwaysOn),
          'upcoming' => sp.setTabUpcoming(!sp.tabUpcoming),
          'debts' => sp.setTabDebts(!sp.tabDebts),
          _ => sp.setTabSms(!sp.tabSms),
        },
        options: {
          'history': l.historyTab,
          'upcoming': l.incomingTab,
          'debts': l.debtsTab,
          'sms': l.smsTab,
        },
      ),
    );
  }
}

/// The theme color square, then the month's first day: one chip that is
/// all a wheel (drag anywhere on it up or down; it loops, 28 above 1, and
/// snaps to a day; only that day shows; a flick carries on a little), with its save square inside it at
/// the end: grey while nothing changed, the theme color with a change, then
/// green (or red) for a moment after saving, fading back. A tap on the chip
/// shows that it scrolls: half a day up, back, half a day down, back (a
/// drag takes over at once).
class _StartDayRow extends StatefulWidget {
  const _StartDayRow({required this.colorChip});
  final Widget colorChip;

  @override
  State<_StartDayRow> createState() => _StartDayRowState();
}

enum _SaveState { idle, saved, failed }

class _StartDayRowState extends State<_StartDayRow> {
  static const _height = 56.0;
  static const _days = 28;

  _SaveState _state = _SaveState.idle;

  /// The day the wheel last settled on (a drag in progress or the tap
  /// hint doesn't change it, so Save doesn't light up for those).
  late int _day = context.read<SettingsProvider>().startDay;

  Future<void> _save() async {
    final sp = context.read<SettingsProvider>();
    var ok = true;
    try {
      await sp.setStartDay(_day);
      ok = sp.startDay == _day;
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _state = ok ? _SaveState.saved : _SaveState.failed);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _state = _SaveState.idle);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final saved = context.watch<SettingsProvider>().startDay;
    final fa = isFaUi(context);
    final changed = _day != saved;
    final (Color? color, Color iconColor) = switch (_state) {
      _SaveState.saved => (const Color(0xFF2E7D32), Colors.white),
      _SaveState.failed => (kStrongRed, Colors.white),
      _ when changed => (scheme.primary, context.textOnStrong),
      _ => (null, scheme.onSurfaceVariant.withValues(alpha: .45)),
    };

    return SizedBox(
      height: _height,
      child: SquareRow(
        leading: widget.colorChip,
        child: Builder(
          builder: (context) => ClipRRect(
            borderRadius: BorderRadius.circular(_kChipRadius),
            child: ColoredBox(
              color: context.raised,
              child: Row(
                children: [
                  // The whole chip is the wheel (lib/shared/ui/day_wheel.dart):
                  // drag anywhere on it; the label lets touches through.
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DayWheel(
                          value: _day - 1,
                          count: _days,
                          loop: true,
                          labelOf: (i) => faDigitsFor(fa)
                              ? toFaDigits('${i + 1}')
                              : '${i + 1}',
                          onChanged: (i) => setState(() => _day = i + 1),
                          alignment: AlignmentDirectional.centerEnd,
                          padding: const EdgeInsetsDirectional.only(end: 14),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: scheme.onSurface,
                          ),
                        ),
                        IgnorePointer(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 14,
                              end: 48,
                            ),
                            child: Row(
                              children: [
                                const ImageIcon(AppIcons.calendar, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkText(
                                    l.monthStartDay,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Save, inside the chip: it belongs to this setting.
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: SquareChip(
                        tooltip: l.save,
                        color: color ?? context.raisedBy(2),
                        onTap: changed ? _save : null,
                        child: ImageIcon(
                          AppIcons.diskette,
                          color: iconColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A backup's file name without its extension, by today's date in the
/// user's calendar: OpenFinances-14050730.
/// The longest a backup's name can be (it stays on its chip's one line).
const int _kBackupNameMax = 24;

String _backupStem(SettingsProvider sp) {
  String two(int n) => n.toString().padLeft(2, '0');
  if (sp.calendar == AppCalendar.jalali) {
    final j = p.Jalali.now();
    return 'OpenFinances-${j.year}${two(j.month)}${two(j.day)}';
  }
  final n = DateTime.now();
  return 'OpenFinances-${n.year}${two(n.month)}${two(n.day)}';
}

/// Where backups go, as the phone's file manager shows it (storage, then
/// the folders; no /storage/emulated/0): \Internal storage\Download. In
/// English whatever the app's language (the owner, 2026-10-25: only a
/// folder's own name may be Persian). A folder of another app's storage
/// (not a path) shows its name.
String _backupFolderPath(SettingsProvider sp) {
  final uri = sp.backupFolder;
  if (uri == null) return r'\Internal storage\Download';
  // A storage folder: …/tree/primary%3ADocuments%2FBackups
  final i = uri.indexOf('/tree/');
  if (uri.startsWith('content://com.android.externalstorage.documents/') &&
      i >= 0) {
    final id = Uri.decodeComponent(uri.substring(i + 6).split('/').first);
    final colon = id.indexOf(':');
    final volume = colon < 0 ? id : id.substring(0, colon);
    final rel = colon < 0 ? '' : id.substring(colon + 1);
    final root = volume == 'primary' ? 'Internal storage' : 'SD card';
    return ['', root, ...rel.split('/').where((s) => s.isNotEmpty)].join('\\');
  }
  final name = sp.backupFolderName?.trim() ?? '';
  // No name given (an unusual storage app): just that it's a folder.
  return '\\${name.isEmpty ? 'Folder' : name}';
}

/// The backup box's third row: where the backup will be saved, as a path
/// with the file's name (its extension waits for the format). A tap picks
/// another folder (remembered); its red reset mark, shown for a picked one,
/// goes back to Download, the default.
class _BackupFolderButton extends StatelessWidget {
  const _BackupFolderButton();

  Future<void> _pick(BuildContext context) async {
    final sp = context.read<SettingsProvider>();
    final notice = AppNotice.of(context);
    final l = AppLocalizations.of(context)!;
    try {
      final old = sp.backupFolder;
      final uri = await SettingsPage._pickFolder(sp, orThrow: true);
      if (uri == null) return;
      if (old != null && old != uri) await _release(old);
    } catch (e) {
      notice.show(l.backupError(e.toString()), kind: NoticeKind.failure);
    }
  }

  static Future<void> _release(String uri) async {
    try {
      await SettingsPage._downloadsCh.invokeMethod('releaseFolder', {
        'uri': uri,
      });
    } catch (_) {}
  }

  Future<void> _reset(BuildContext context) async {
    final sp = context.read<SettingsProvider>();
    final old = sp.backupFolder;
    await sp.setBackupFolder(null, null);
    if (old != null) await _release(old);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final sp = context.watch<SettingsProvider>();
    final custom = sp.backupFolder != null;
    final radius = BorderRadius.circular(_kChipRadius);
    // A path reads left to right, in both languages; the folder only (the
    // file's name has its own chip under it).
    return Material(
      color: context.raised,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () => _pick(context),
        child: Directionality(
          textDirection: TextDirection.ltr,
          // At least as tall as the name row; a long path takes more lines
          // (never cut: the owner, 2026-10-26).
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                // From the start (the left: a path reads left to right),
                // its mark and text level with the name row's.
                const SizedBox(width: _kMarkInset),
                const SizedBox(
                  width: _kMarkSlot,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _BackupMark(AppIcons.folder),
                  ),
                ),
                const SizedBox(width: _kMarkGap),
                // The whole path; it breaks after a "\" when it must.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: InkText(
                      _backupFolderPath(sp).replaceAll(r'\', '\\\u200B'),
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
                if (custom)
                  _ResetMark(l.backupFolderReset, () => _reset(context))
                else
                  const SizedBox(width: _kMarkInset),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The marks of the folder and name rows (the owner's folder and title
/// tag, as drawn): both PNGs are trimmed to their drawing, which fills the
/// width and 81% of the height in each, so one size draws them alike (21:
/// 17 high).
const double _kMarkSize = 21;

/// Both rows from the start: a slot as wide as the marks, so the marks and
/// the texts after them line up.
const double _kMarkInset = 14, _kMarkSlot = _kMarkSize, _kMarkGap = 12;

/// The red mark at the end of the folder and name rows when they aren't the
/// default: back to it (the owner's undo icon, KP Arts).
class _ResetMark extends StatelessWidget {
  const _ResetMark(this.tooltip, this.onTap);
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tooltip,
    child: IconButton(
      style: IconButton.styleFrom(overlayColor: Colors.transparent),
      onPressed: onTap,
      icon: const ImageIcon(AppIcons.undo, size: 17, color: kStrongRed),
    ),
  );
}

class _BackupMark extends StatelessWidget {
  const _BackupMark(this.image);
  final AssetImage image;

  @override
  Widget build(BuildContext context) => ImageIcon(
    image,
    size: _kMarkSize,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

/// The backup box's fourth row: the file's name (without its extension:
/// the format may not be chosen yet), by default today's
/// (OpenFinances-14050730). A tap turns it into an empty field with save
/// (green) and cancel (red) marks. Saved, the name is this backup's; empty,
/// the default (as its red reset mark does). Leaving it any other way
/// (cancel, the box's Cancel, the box or its section closing) drops what
/// was typed.
class _BackupNameChip extends StatefulWidget {
  const _BackupNameChip({
    super.key,
    required this.name,
    required this.onChanged,
  });

  /// The name chosen; null: the default.
  final String? name;
  final ValueChanged<String?> onChanged;

  @override
  State<_BackupNameChip> createState() => _BackupNameChipState();
}

/// While the backup's name is being typed: the page makes room for the
/// keyboard ([_KeyboardRoom]; pages don't resize for it).
final _nameEditing = ValueNotifier<bool>(false);

/// At the end of the page: as tall as the keyboard while the backup's name
/// is typed, so the field can scroll above it (the owner, 2026-10-25: it
/// stayed under the keyboard); nothing otherwise.
class _KeyboardRoom extends StatelessWidget {
  const _KeyboardRoom();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _nameEditing,
    builder: (context, on, _) =>
        SizedBox(height: on ? MediaQuery.viewInsetsOf(context).bottom : 0),
  );
}

class _BackupNameChipState extends State<_BackupNameChip> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  bool _editing = false;

  @override
  void dispose() {
    if (_editing) _nameEditing.value = false;
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _edit() {
    _field.clear();
    _nameEditing.value = true;
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editing) _focus.requestFocus();
    });
  }

  void _cancel() {
    _focus.unfocus();
    _nameEditing.value = false;
    setState(() => _editing = false);
  }

  /// What can't be in a file's name goes; nothing left: the default.
  void _save() {
    final name = _field.text
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '')
        .trim();
    _focus.unfocus();
    _nameEditing.value = false;
    setState(() => _editing = false);
    widget.onChanged(name.isEmpty ? null : name);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final sp = context.watch<SettingsProvider>();
    final shown = widget.name ?? _backupStem(sp);
    final style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    );
    Widget mark(
      AssetImage image,
      double size,
      String tip,
      VoidCallback onTap, {
      Color? color,
    }) => Semantics(
      button: true,
      label: tip,
      child: IconButton(
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(overlayColor: Colors.transparent),
        icon: ImageIcon(
          image,
          size: size,
          color: color ?? scheme.onSurfaceVariant,
        ),
      ),
    );
    final hint = style.copyWith(
      color: scheme.onSurfaceVariant.withValues(alpha: .45),
    );
    final radius = BorderRadius.circular(_kChipRadius);
    // The whole chip renames (the owner, 2026-10-25: only its mark didn't
    // feel right); while editing, the field and its marks take the taps.
    return Material(
      color: context.raised,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: _editing ? null : _edit,
        child: Directionality(
          textDirection: TextDirection.ltr,
          // At least 48 tall; a long name takes more lines (never cut).
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                const SizedBox(width: _kMarkInset),
                // The mark's slot (the folder row's too).
                SizedBox(
                  width: _kMarkSlot,
                  child: _editing
                      ? null
                      : const Align(
                          alignment: Alignment.centerLeft,
                          child: _BackupMark(AppIcons.titleTag),
                        ),
                ),
                const SizedBox(width: _kMarkGap),
                Expanded(
                  child: _editing
                      // Empty, the default's name faint in it.
                      ? TextField(
                          controller: _field,
                          focusNode: _focus,
                          textInputAction: TextInputAction.done,
                          // Short enough to stay on the chip's one line (the
                          // owner, 2026-10-26; the date name is 21); no
                          // counter.
                          maxLength: _kBackupNameMax,
                          buildCounter:
                              (
                                _, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) => null,
                          // Kept above the keyboard as it rises (the page
                          // grows by it: [_KeyboardRoom]).
                          scrollPadding: EdgeInsets.fromLTRB(
                            20,
                            20,
                            20,
                            MediaQuery.viewInsetsOf(context).bottom + 24,
                          ),
                          style: style,
                          onSubmitted: (_) => _save(),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: _backupStem(sp),
                            hintStyle: hint,
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: InkText(shown, style: style),
                        ),
                ),
                if (_editing) ...[
                  mark(AppIcons.check, 18, l.save, _save, color: kSuccessGreen),
                  mark(
                    AppIcons.close,
                    13,
                    l.cancel,
                    _cancel,
                    color: kStrongRed,
                  ),
                  const SizedBox(width: 4),
                ] else if (widget.name != null)
                  _ResetMark(l.backupNameReset, () => widget.onChanged(null))
                else
                  const SizedBox(width: _kMarkInset),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Backup format option: a large icon with its name under it, the same
/// padding on the sides, above, between and below.
/// The JSON / Excel choice's track: one piece a step above the box (red
/// while [attention] pulses: "pick one here"), the two options inside it.
class _FormatTrack extends StatelessWidget {
  const _FormatTrack({required this.children, this.attention});
  final List<Widget> children;
  final Animation<double>? attention;

  /// From the track's edge to the options, and between them.
  static const double inset = 3;

  @override
  Widget build(BuildContext context) {
    final base = context.raised;
    Widget track(Color color) => Container(
      padding: const EdgeInsets.all(inset),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(_kChipRadius),
      ),
      child: Row(children: children),
    );
    final a = attention;
    return a == null
        ? track(base)
        : AnimatedBuilder(
            animation: a,
            builder: (_, _) => track(SegmentedPills.attentionColor(base, a)),
          );
  }
}

/// One format in [_FormatTrack]: its mark and name, no fill of its own,
/// tinted when picked.
class _FormatChoice extends StatelessWidget {
  const _FormatChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget Function(double size) icon;

  /// Old fixed padding; the icon is 15% smaller than the space it left.
  static const double _basePad = 24;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _box(
      context,
      selected
          ? SegmentedPills.selectedColor(scheme, context.raised)
          : Colors.transparent,
    );
  }

  Widget _box(BuildContext context, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(_kChipRadius - _FormatTrack.inset),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_kChipRadius - _FormatTrack.inset),
        child: LayoutBuilder(
          builder: (context, c) {
            // One padding on the sides, the top and under the label; half
            // of it between the icon and the label.
            final size = (c.maxWidth - 2 * _basePad) * .85;
            final pad = (c.maxWidth - size) / 2;
            return Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconTheme.merge(
                    data: IconThemeData(color: scheme.onSurface),
                    child: SizedBox.square(dimension: size, child: icon(size)),
                  ),
                  SizedBox(height: pad / 2),
                  InkText(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// "OpenFinances" at the top of Settings, exactly as the branding screen
/// writes it ([BrandName]: its font, size and colors; "Open" in the text
/// color on a light theme), centered, the motto small and faint under it.
class _AppHeader extends StatelessWidget {
  const _AppHeader();

  /// How far Manrope's tallest letters here ("F", "i"'s dot) reach above
  /// the baseline, as a share of the font size (from the font's outlines).
  static const double _inkTop = .735;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    const size = BrandLockup.kNameSize;
    final name = TextPainter(
      text: TextSpan(
        text: 'OpenFinances',
        style: BrandName.style(size, FontWeight.w600, Colors.white),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final nameWidth = name.width;
    // From the top of the name's box down to the top of its letters.
    final above =
        name.computeDistanceToActualBaseline(TextBaseline.alphabetic) -
        size * _inkTop;
    name.dispose();

    // The same air above the name's letters (from the status bar) and below
    // the motto as from the name to the screen's sides. Above, the page's
    // 8 dp bar and the list's own 8 count.
    return LayoutBuilder(
      builder: (context, box) {
        final side = _kPageGutter + (box.maxWidth - nameWidth) / 2;
        return Padding(
          padding: EdgeInsets.only(
            top: (side - 16 - above).clamp(0, 400).toDouble(),
            bottom: side.clamp(0, 400).toDouble(),
          ),
          child: Column(
            children: [
              BrandName(
                size: size,
                openColor: dark ? Colors.white : scheme.onSurface,
              ),
              const SizedBox(height: 4),
              InkText(
                AppLocalizations.of(context)!.appMotto,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.0,
                  color: scheme.onSurfaceVariant.withValues(alpha: .55),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Reading the messaging app's notifications and showing our own: each
/// chip is on only while its permission is there. Turning one on asks for
/// the permission (reading: the system screen); if it isn't given, a notice
/// says the setting can't be on without it.
class _BankNotificationChips extends StatefulWidget {
  const _BankNotificationChips();

  @override
  State<_BankNotificationChips> createState() => _BankNotificationChipsState();
}

class _BankNotificationChipsState extends State<_BankNotificationChips>
    with SingleTickerProviderStateMixin {
  bool _canRead = false;
  bool _canPost = false;
  bool _askedToRead = false; // sent to the system screen to turn reading on
  late final AppLifecycleListener _lifecycle;

  /// "Show notifications" pulsing red (asked for by the SMS tab); after a
  /// permission was asked for, the chip's flash: green (given) or red.
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  /// The color [_pulse] turns the chip.
  Color _pulseTo = kStrongRed;

  /// The last [notifySettingRequest] handled (one may come in before this
  /// page was ever built).
  static int _handled = 0;

  /// The chip flashed ([notifySettingTarget] of the last request).
  String _target = 'show';

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _back);
    _check();
    notifySettingRequest.addListener(_pointHere);
    WidgetsBinding.instance.addPostFrameCallback((_) => _pointHere());
  }

  @override
  void dispose() {
    notifySettingRequest.removeListener(_pointHere);
    _pulse.dispose();
    _lifecycle.dispose();
    super.dispose();
  }

  /// Opens Tabs & access, brings these chips into view and flashes the one
  /// asked for.
  Future<void> _pointHere() async {
    if (notifySettingRequest.value == _handled || !mounted) return;
    _handled = notifySettingRequest.value;
    setState(() {
      _target = notifySettingTarget;
      _pulseTo = kStrongRed;
    });
    // Let the page come up first (it may have just been switched to).
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _tabsSectionKey.currentState?.open();
    if (!mounted) return;
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      alignment: .35,
    );
    try {
      for (var i = 0; i < 3; i++) {
        await _pulse.forward(from: 0).orCancel;
        await _pulse.reverse().orCancel;
      }
    } on TickerCanceled {
      // left the page
    }
  }

  Future<void> _check() async {
    final read = await BankNotifications.hasAccess();
    final post = await BankNotifications.canPostNotifications();
    if (mounted) {
      setState(() {
        _canRead = read;
        _canPost = post;
      });
    }
  }

  Future<void> _back() async {
    await _check();
    if (_askedToRead && mounted) {
      if (_canRead) {
        _result('read', true);
      } else {
        _refused('read');
      }
    }
    _askedToRead = false;
  }

  void _refused(String chip) {
    _result(chip, false);
    showAppNotice(
      context,
      AppLocalizations.of(context)!.needsPermission,
      kind: NoticeKind.failure,
    );
  }

  /// After a permission was asked for: [chip] green for a moment if it was
  /// given, red if not (the owner, 2026-10-26: the red "this one" pulse
  /// went on after coming back, as if it had failed).
  Future<void> _result(String chip, bool ok) async {
    _pulse.stop();
    setState(() {
      _target = chip;
      _pulseTo = ok ? const Color(0xFF2E7D32) : kStrongRed;
    });
    try {
      await _pulse.forward(from: _pulse.value).orCancel;
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) await _pulse.reverse().orCancel;
    } on TickerCanceled {
      // left the page
    }
  }

  Future<void> _toggle(String v) async {
    final sp = context.read<SettingsProvider>();
    // Tapped: the "this one" pulse has done its job.
    _pulse
      ..stop()
      ..value = 0;
    if (v == 'read') {
      // Taken back (or given) in the system screen only.
      _askedToRead = !_canRead;
      await BankNotifications.openAccessSettings();
      return;
    }
    if (sp.bankNotify && _canPost) {
      await sp.setBankNotify(false);
      return;
    }
    final ok = await BankNotifications.requestPostNotifications();
    await _check();
    if (ok && _canPost) {
      await sp.setBankNotify(true);
      if (mounted) _result('show', true);
    } else if (mounted) {
      _refused('show');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return ToggleChips<String>(
      radius: _kChipRadius,
      attention: _pulse,
      attentionOn: _target,
      attentionTo: _pulseTo,
      on: {if (_canRead) 'read', if (sp.bankNotify && _canPost) 'show'},
      onTap: _toggle,
      options: {'read': l.readBankNotifications, 'show': l.notifyBankMessages},
    );
  }
}

/// What can be suggested, per list, as chips: ignored ones first, in red;
/// tap a chip to ignore it or bring it back. Four tabs (expense, income,
/// debt, owed); the two debt sides each have titles and people (a second
/// row). Header, tabs, that row and the chips sit on slightly different
/// shades. Fixed height, scrolls.
class _IgnoredBox extends StatefulWidget {
  const _IgnoredBox();

  @override
  State<_IgnoredBox> createState() => _IgnoredBoxState();
}

enum _IgnoredTab { expense, income, owe, owed }

class _IgnoredBoxState extends State<_IgnoredBox> {
  _IgnoredTab _tab = _IgnoredTab.expense;

  /// The chips' box (it shows that it scrolls: [ScrollHint]).
  final _chips = ScrollController();

  @override
  void dispose() {
    _chips.dispose();
    super.dispose();
  }

  bool _people = false; // on a debt tab: people instead of titles

  SuggestSource get _source => switch (_tab) {
    _IgnoredTab.expense => SuggestSource.expense,
    _IgnoredTab.income => SuggestSource.income,
    _IgnoredTab.owe =>
      _people ? DebtDirection.owe.personSource : DebtDirection.owe.titleSource,
    _IgnoredTab.owed =>
      _people
          ? DebtDirection.owed.personSource
          : DebtDirection.owed.titleSource,
  };

  List<String> _suggestable(BuildContext context) => switch (_tab) {
    // Upcoming payments are expenses: their titles share this list (the
    // sheets' own: History's and Due's, merged).
    _IgnoredTab.expense => EntrySuggestions.ofExpenses(
      context.watch<ExpenseProvider>().raw,
      context.watch<UpcomingProvider>().history,
    ).titles(),
    _IgnoredTab.income => EntrySuggestions.of(
      context.watch<IncomeProvider>().raw,
    ).titles(),
    _IgnoredTab.owe || _IgnoredTab.owed => () {
      final dp = context.watch<DebtProvider>();
      final side = _tab == _IgnoredTab.owe
          ? DebtDirection.owe
          : DebtDirection.owed;
      return _people ? dp.people(side) : dp.titles(side);
    }(),
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final sp = context.watch<SettingsProvider>();
    final source = _source;
    final ignored = sp.ignoredTitles(source);
    final rest = [
      for (final t in _suggestable(context))
        if (!sp.isTitleIgnored(source, t)) t,
    ];
    final debtTab = _tab == _IgnoredTab.owe || _tab == _IgnoredTab.owed;

    final chips = [
      for (final t in ignored) (t, true),
      for (final t in rest) (t, false),
    ];
    final empty = _people ? l.noPeopleToIgnore : l.noTitlesToIgnore;

    // One block: the parts touch (no gaps that would read as lines), told
    // apart by their tone only; what's on a part (pills, chips) sits a full
    // step above it.
    // Two parts of the one section, touching, told apart by their tone
    // only: what the app remembers and whether it suggests (the section's
    // own tone), then the ignore lists (a step up: their tabs and chips).
    Widget part(double level, List<Widget> rows) => Container(
      color: surfaceTone(scheme, level),
      padding: const EdgeInsets.all(kSectionInset),
      child: SurfaceDepth(
        depth: level,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: kSectionRowGap),
              rows[i],
            ],
          ],
        ),
      ),
    );
    const ignoreLevel = 1.6;

    return FoldSection(
      id: 'settings.history',
      title: l.sectionHistory,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          part(1, [
            // Remember folds (off), scroll spots (off), what was entered in
            // a cancelled add sheet (on, until a restart).
            ToggleChips<String>(
              radius: 10,
              verticalPadding: 8,
              on: {
                if (sp.rememberSections) 'folds',
                if (sp.rememberScroll) 'place',
                if (sp.rememberEntries) 'entries',
              },
              onTap: (k) => switch (k) {
                'folds' => sp.setRememberSections(!sp.rememberSections),
                'place' => sp.setRememberScroll(!sp.rememberScroll),
                _ => sp.setRememberEntries(!sp.rememberEntries),
              },
              options: {
                'folds': l.keepFolds,
                'place': l.keepPlace,
                'entries': l.keepEntries,
              },
            ),
            // Suggestions in the add/edit sheets, on or off (off by
            // default; the ignore lists are greyed out while off).
            ToggleChips<String>(
              radius: 10,
              verticalPadding: 8,
              on: {if (sp.suggestionsOn) 'on'},
              onTap: (_) => sp.setSuggestionsOn(!sp.suggestionsOn),
              options: {'on': l.showSuggestions},
            ),
          ]),
          _Greyed(
            off: !sp.suggestionsOn,
            onBlocked: () {},
            child: TabSwipe(
              // A swipe moves between the tabs (the chips scroll first).
              onNext: _tab.index < _IgnoredTab.values.length - 1
                  ? () => setState(
                      () => _tab = _IgnoredTab.values[_tab.index + 1],
                    )
                  : null,
              onPrevious: _tab.index > 0
                  ? () => setState(
                      () => _tab = _IgnoredTab.values[_tab.index - 1],
                    )
                  : null,
              child: part(ignoreLevel, [
                SegmentedPills<_IgnoredTab>(
                  radius: 10,
                  verticalPadding: 8,
                  selected: _tab,
                  onChanged: (t) => setState(() => _tab = t),
                  options: {
                    _IgnoredTab.expense: l.spentShort,
                    _IgnoredTab.income: l.incomeTitle,
                    _IgnoredTab.owe: l.debtShort,
                    _IgnoredTab.owed: l.creditShort,
                  },
                ),
                if (debtTab)
                  SegmentedPills<bool>(
                    radius: 10,
                    verticalPadding: 8,
                    selected: _people,
                    onChanged: (v) => setState(() => _people = v),
                    options: {false: l.titlesTab, true: l.peopleTab},
                  ),
                chips.isEmpty
                    ? SizedBox(
                        height: 56,
                        child: Center(
                          child: InkText(
                            empty,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: .55,
                              ),
                            ),
                          ),
                        ),
                      )
                    // As tall as its chips, up to four whole rows; then it
                    // scrolls (and shows it does: [ScrollHint]).
                    : ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight:
                              _JustifiedChips.height * 4 +
                              _JustifiedChips._gap * 3,
                        ),
                        // At its end, the page scrolls on.
                        child: ScrollHint(
                          id: ScrollHint.ignoredChips,
                          controller: _chips,
                          child: ScrollChain(
                            child: SingleChildScrollView(
                              controller: _chips,
                              child: _JustifiedChips(
                                labels: [for (final c in chips) c.$1],
                                builder: (i, width) {
                                  final (t, off) = chips[i];
                                  return GestureDetector(
                                    onTap: () => off
                                        ? sp.unignoreTitle(source, t)
                                        : sp.ignoreTitle(source, t),
                                    child: Container(
                                      width: width,
                                      constraints: const BoxConstraints(
                                        minHeight: _JustifiedChips.height,
                                      ),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: _JustifiedChips.pad,
                                      ),
                                      decoration: BoxDecoration(
                                        color: off
                                            ? kStrongRed
                                            : surfaceTone(
                                                scheme,
                                                ignoreLevel + 1,
                                              ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: InkText(
                                        t,
                                        style: _JustifiedChips.textStyle
                                            .copyWith(
                                              color: off
                                                  ? Colors.white
                                                  : scheme.onSurface,
                                            ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chips in rows that each fill the whole width: a row takes as many chips
/// as fit at their own width, then shares what's left equally among them.
class _JustifiedChips extends StatelessWidget {
  const _JustifiedChips({required this.labels, required this.builder});

  final List<String> labels;

  /// Chip [i], [width] wide (text centered).
  final Widget Function(int i, double width) builder;

  static const double height = 34;
  static const double pad = 14; // each side of the text
  static const double _gap = 8;
  static const textStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(textStyle);
    final scaler = MediaQuery.textScalerOf(context);
    final dir = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final max = c.maxWidth;
        final natural = [
          for (final t in labels)
            () {
              final p = TextPainter(
                text: TextSpan(text: t, style: style),
                textDirection: dir,
                textScaler: scaler,
                maxLines: 1,
              )..layout();
              final w = (p.width + 2 * pad + 1).clamp(0.0, max);
              p.dispose();
              return w.toDouble();
            }(),
        ];
        // Rows, greedily.
        final rows = <List<int>>[];
        var used = 0.0;
        for (var i = 0; i < natural.length; i++) {
          final need =
              natural[i] + (rows.isEmpty || rows.last.isEmpty ? 0 : _gap);
          if (rows.isEmpty || used + need > max) {
            rows.add([i]);
            used = natural[i];
          } else {
            rows.last.add(i);
            used += need;
          }
        }
        return Column(
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: _gap),
              () {
                final row = rows[r];
                final taken =
                    row.fold(0.0, (s, i) => s + natural[i]) +
                    _gap * (row.length - 1);
                // (half a pixel spare: rounding never overflows the row)
                final extra = (max - taken - .5) / row.length;
                return Row(
                  children: [
                    for (var k = 0; k < row.length; k++) ...[
                      if (k > 0) const SizedBox(width: _gap),
                      builder(row[k], natural[row[k]] + extra),
                    ],
                  ],
                );
              }(),
            ],
          ],
        );
      },
    );
  }
}

/// Backup and Restore, each a full-width button. Backup opens upward into a
/// box with the choices (what, and which format: nothing chosen at first)
/// and Cancel above it; the button is grey until both are chosen (tapping it then
/// pulses the rows still missing a choice red, each stopping once chosen),
/// the theme color when ready. Pressed: the box closes, the backup runs,
/// and the button turns green (saved) or red, fading back.
class _BackupOptions extends StatefulWidget {
  const _BackupOptions({required this.onBackup, required this.onRestore});

  /// [name]: the file's, without its extension (null: today's default).
  final Future<bool> Function(bool fullData, bool excel, String? name) onBackup;
  final VoidCallback onRestore;

  @override
  State<_BackupOptions> createState() => _BackupOptionsState();
}

class _BackupOptionsState extends State<_BackupOptions>
    with TickerProviderStateMixin {
  bool? _fullData; // true = full data, false = expenses only
  bool? _excel; // false = JSON, true = Excel
  String? _name; // the file's name, if renamed (this backup only)

  /// Bumped as the box opens and closes: the name row starts afresh (an
  /// unsaved edit in it is dropped).
  int _session = 0;
  bool? _result; // the last backup: saved or not, shown for a moment

  late final _dataPulse = _pulse();
  late final _formatPulse = _pulse();
  late final _open = AnimationController(vsync: this, duration: kSectionAnim)
    ..addListener(_growing);
  late final _openCurve = CurvedAnimation(
    parent: _open,
    curve: Curves.easeInOutCubic,
  );

  bool _isOpen = false; // the box (choices) is open

  /// The box (the choices and the Backup button at its end): kept in view
  /// as it opens above the button, frame by frame, the button first (the
  /// owner, 2026-10-31: it slipped off screen while the box grew, and came
  /// back only after).
  final _box = GlobalKey();

  /// The choices at their full height (they're laid out whole, shown in
  /// part), and how far open the box was at the last tick.
  final _choices = GlobalKey();
  double _lastT = 0;

  /// As the box opens, on each tick (before the frame is laid out): the
  /// page moves by what this frame will add, so the button lands in view on
  /// every frame, not a frame late.
  void _growing() {
    final t = _openCurve.value;
    final dt = t - _lastT;
    _lastT = t;
    if (_open.status != AnimationStatus.forward || dt <= 0) return;
    final c = _box.currentContext;
    final choices = _choices.currentContext?.findRenderObject() as RenderBox?;
    if (c == null || choices == null || !choices.hasSize) return;
    // The choices' share of their height, and the box's padding (8 a
    // side at full).
    keepInView(c, bottomFirst: true, grow: (choices.size.height + 16) * dt);
  }

  bool get _ready => _fullData != null && _excel != null;

  AnimationController _pulse() => AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  /// Three pulses, unless the row gets its choice (which stops it).
  Future<void> _run(AnimationController c) async {
    try {
      for (var i = 0; i < 3; i++) {
        await c.forward(from: 0).orCancel;
        await c.reverse().orCancel;
      }
    } on TickerCanceled {
      // stopped by a choice
    }
  }

  void _stop(AnimationController c) {
    c.stop();
    c.value = 0;
  }

  void _close() {
    _stop(_dataPulse);
    _stop(_formatPulse);
    _open.reverse();
    setState(() {
      _isOpen = false;
      _session++;
    });
  }

  Future<void> _press() async {
    if (!_isOpen) {
      // The last choices stay (asked once; the owner, 2026-10-28), the name
      // starts afresh.
      final sp = context.read<SettingsProvider>();
      setState(() {
        _fullData = sp.backupFull;
        _excel = sp.backupExcel;
        _name = null;
        _session++;
        _isOpen = true;
      });
      await _open.forward();
      return;
    }
    if (!_ready) {
      if (_fullData == null) _run(_dataPulse);
      if (_excel == null) _run(_formatPulse);
      return;
    }
    final full = _fullData!;
    final excel = _excel!;
    final name = _name;
    context.read<SettingsProvider>().setBackupChoice(full: full, excel: excel);
    _close();
    final ok = await widget.onBackup(full, excel, name);
    if (!mounted) return;
    setState(() => _result = ok);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _result = null);
  }

  @override
  void dispose() {
    _dataPulse.dispose();
    _formatPulse.dispose();
    _openCurve.dispose();
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600);

    void pickFormat(bool excel) {
      _stop(_formatPulse);
      setState(() => _excel = excel);
    }

    // The Backup button: green/red for a moment after a backup, grey while
    // the box is open without both choices, else the theme color.
    final (Color bg, Color fg) = switch (_result) {
      true => (const Color(0xFF2E7D32), Colors.white),
      false => (kStrongRed, Colors.white),
      _ when _isOpen && !_ready => (
        context.raisedBy(2),
        scheme.onSurfaceVariant.withValues(alpha: .6),
      ),
      _ => (scheme.primary, context.textOnStrong),
    };

    Widget bigButton({
      required Color bg,
      required Color fg,
      required String label,
      required VoidCallback onTap,
    }) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(_kChipRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: InkText(label, style: textStyle?.copyWith(color: fg)),
            ),
          ],
        ),
      ),
    );

    final boxTone = context.raised;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The backup box: just the button when closed; open, a step above
        // the section, with the choices and Cancel above the button (it
        // opens upward: the button stays where it was tapped, at the end).
        AnimatedBuilder(
          key: _box,
          animation: _openCurve,
          builder: (context, child) {
            final t = _openCurve.value;
            return Container(
              padding: EdgeInsets.all(8 * t),
              decoration: BoxDecoration(
                color: boxTone.withValues(alpha: t),
                borderRadius: BorderRadius.circular(_kChipRadius + 4 * t),
              ),
              child: child,
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizeTransition(
                sizeFactor: _openCurve,
                // Grows upward: the button stays at the bottom, under its choices.
                alignment: AlignmentDirectional.bottomCenter,
                child: FadeTransition(
                  key: _choices,
                  opacity: _openCurve,
                  // What's in the box sits a step above it.
                  child: SurfaceDepth(
                    depth: SurfaceDepth.of(context) + 1,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: _kRowGap),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedPills<bool?>(
                            radius: _kChipRadius,
                            selected: _fullData,
                            attention: _dataPulse,
                            onChanged: (v) {
                              _stop(_dataPulse);
                              setState(() => _fullData = v);
                            },
                            options: {true: l.fullData, false: l.expensesOnly},
                          ),
                          const SizedBox(height: _kRowGap),
                          // One of the two: one track (like every choice).
                          _FormatTrack(
                            attention: _formatPulse,
                            children: [
                              Expanded(
                                child: _FormatChoice(
                                  label: 'JSON',
                                  selected: _excel == false,
                                  onTap: () => pickFormat(false),
                                  icon: (size) =>
                                      ImageIcon(AppIcons.json, size: size),
                                ),
                              ),
                              const SizedBox(width: _FormatTrack.inset),
                              Expanded(
                                child: _FormatChoice(
                                  label: 'Excel',
                                  selected: _excel == true,
                                  onTap: () => pickFormat(true),
                                  // Full-color artwork, not tinted.
                                  icon: (size) => Image(
                                    image: AppIcons.xls,
                                    width: size,
                                    height: size,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: _kRowGap),
                          const _BackupFolderButton(),
                          const SizedBox(height: _kRowGap),
                          _BackupNameChip(
                            key: ValueKey(_session),
                            name: _name,
                            onChanged: (n) => setState(() => _name = n),
                          ),
                          const SizedBox(height: _kRowGap),
                          OutlinedButton(
                            style: cancelButtonStyle(
                              OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    _kChipRadius,
                                  ),
                                ),
                              ),
                            ),
                            onPressed: _close,
                            child: InkText(l.cancel),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bigButton(bg: bg, fg: fg, label: l.backup, onTap: _press),
            ],
          ),
        ),
        const SizedBox(height: _kRowGap),
        bigButton(
          bg: scheme.primary,
          fg: context.textOnStrong,
          label: l.restore,
          onTap: widget.onRestore,
        ),
      ],
    );
  }
}

/// About's email and bug icons, sized to read alike in their chips: the bug's
/// file has far wider margins, and its solid body reads heavier, so a little less
/// ink looks equal (in dp: 36.7 x 36.7 and 33.8 x 34.6; the owner, 2026-11-03).
const double _kSupportIcon = 40, _kBugIcon = 54;

/// How much of the bug's file its ink fills (for the glitch's reach).
const double _kBugInk = .64;

/// Settings > About: the credits the app's fonts and icons ask for (in
/// their own wording, so in English), the open-source licenses, and how to
/// reach the developer.
class _AboutBox extends StatelessWidget {
  const _AboutBox();

  static const _email = 'hs.96@outlook.com';
  static const _website = 'https://openfinances.openproject.website';
  static const _openProjectSite = 'https://openproject.website';
  static const _openDesignSite = 'https://opendesign.openproject.website';
  static const _repo = 'https://github.com/OpenProjectDev/OpenFinances';

  /// The "This app" part: its logo opens it.
  static final _thisApp = GlobalKey<FoldSectionState>();

  /// Flaticon artists whose icons the app draws. Their licenses ask for
  /// `designed by <author> from Flaticon` in the credits, not which icon is
  /// whose; for the record (certificates in docs/licenses/flaticon):
  /// Magnific: calendar, eraser, danger; Maxim Basinski Premium:
  /// check; Md Tanvirul Haque: trash bin;
  /// Icon Mart: add; Phoenix Group: setting; riajulislam: fingerprint; Yogi
  /// Aprelliyanto: diskette, application; Mayor Icons: show, hide layer;
  /// Anggara: pencil; ariefstudio: close; Assetwave: bracket curly;
  /// moniruldislam: xls; Vector Squad: cogwheel; Dave Gandy: down; Google:
  /// palette; Royyan Wijaya: the leaf (app icon); Arkinasi: ruler and pencil
  /// (OpenDesign); gravisio: AI brain (OpenProject); kmg design: folder;
  /// ekays.dsgn: title tag; KP Arts: undo; meaicon: percent; Falcone: down
  /// arrow (more / less); riajulislam also GitHub; wind: loading; Hilmy
  /// Abiyyu A.: headset (email); Wiwin Winaldi: bug report.
  static const _artists = [
    'Magnific',
    'Maxim Basinski Premium',
    'Md Tanvirul Haque',
    'Icon Mart',
    'Phoenix Group',
    'riajulislam',
    'Yogi Aprelliyanto',
    'Mayor Icons',
    'Anggara',
    'ariefstudio',
    'Assetwave',
    'moniruldislam',
    'Vector Squad',
    'Dave Gandy',
    'Google',
    'Royyan Wijaya',
    'Arkinasi',
    'gravisio',
    'kmg design',
    'ekays.dsgn',
    'KP Arts',
    'meaicon',
    'Falcone',
    'wind',
    'Hilmy Abiyyu A.',
    'Wiwin Winaldi',
  ];

  static Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!ok && context.mounted) {
      showAppNotice(
        context,
        AppLocalizations.of(context)!.couldNotOpen,
        kind: NoticeKind.failure,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read while the user looks here, so the licenses page opens at once.
    preloadLicenses();
    final scheme = Theme.of(context).colorScheme;
    // English and Manrope here whatever the app's language and font (the
    // credits are worded as their licenses ask).
    final text = TextStyle(
      fontFamily: kAboutFont,
      fontSize: 12.5,
      height: 1.4,
      color: scheme.onSurface,
    );
    final faint = text.copyWith(color: scheme.onSurfaceVariant);
    final strong = text.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600);

    // A folding part of credits (closed at first), read from the left.
    Widget box(String id, String title, List<Widget> rows, {Key? key}) =>
        FoldSection(
          key: key,
          id: 'settings.about.$id',
          title: title,
          radius: _kChipRadius,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        );
    // A credit: its name, then who made it and its license.
    Widget credit(String name, List<String> lines, {Uri? link}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: link == null ? null : () => _open(context, link),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkText(name, style: strong),
            for (final t in lines) InkText(t, style: faint),
          ],
        ),
      ),
    );

    return aboutText(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The family: OpenFinances, OpenDesign, OpenProject.
          _FamilyLogos(
            onFinances: () => _thisApp.currentState?.open(),
            onProject: () => _open(context, Uri.parse(_openProjectSite)),
            onDesign: () => _open(context, Uri.parse(_openDesignSite)),
          ),
          const SizedBox(height: _kRowGap),
          const _VersionSection(),
          const SizedBox(height: _kRowGap),
          // The app's own license (its text heads the licenses page).
          box('app', 'This app', key: _thisApp, [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ThisAppText(
                style: faint,
                onFinances: () => _open(context, Uri.parse(_website)),
                onProject: () => _open(context, Uri.parse(_openProjectSite)),
              ),
            ),
          ]),
          const SizedBox(height: _kRowGap),
          box('icons', 'Icons', [
            credit('Uicons', [
              'by Flaticon - flaticon.com/uicons',
            ], link: Uri.parse('https://www.flaticon.com/uicons')),
            InkText(
              'Icons designed by these artists from Flaticon',
              style: strong,
            ),
            const SizedBox(height: 8),
            // The artists as chips (a step above the part they're in), in
            // rows that fill the width, like every chip row.
            Builder(
              builder: (context) => _JustifiedChips(
                labels: _artists,
                builder: (i, width) => Container(
                  width: width,
                  constraints: const BoxConstraints(
                    minHeight: _JustifiedChips.height,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: _JustifiedChips.pad,
                  ),
                  decoration: BoxDecoration(
                    color: context.raised,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: InkText(
                    _artists[i],
                    style: _JustifiedChips.textStyle.copyWith(
                      fontFamily: kAboutFont,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ]),
          const SizedBox(height: _kRowGap),
          box('fonts', 'Fonts', [
            credit('Shabnam', [
              'by Saber Rastikerdar - SIL Open Font License 1.1',
              'Based on DejaVu / Bitstream Vera; Latin from Roboto, '
                  'Apache License 2.0',
            ]),
            credit('Manrope', [
              'by Mikhail Sharanda - SIL Open Font License 1.1',
            ]),
            credit('Vazirmatn', [
              'by Saber Rastikerdar - SIL Open Font License 1.1',
            ]),
          ]),
          const SizedBox(height: _kRowGap),
          box('privacy', 'Privacy', [
            const PrivacyPolicyText(english: true),
            const SizedBox(height: 10),
          ]),
          const SizedBox(height: _kRowGap),
          // The licenses, then email and a bug to report (squares, like the
          // color and fingerprint chips).
          SizedBox(
            height: 68,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) => GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LicensesPage(navIndex: 3),
                        ),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: context.raised,
                          borderRadius: BorderRadius.circular(_kChipRadius),
                        ),
                        child: InkText(
                          'Licenses',
                          style: text.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: _kRowGap),
                AspectRatio(
                  aspectRatio: 1,
                  child: SquareChip(
                    tooltip: 'Email',
                    onTap: () => _open(context, Uri.parse('mailto:$_email')),
                    child: ImageIcon(
                      AppIcons.support,
                      size: _kSupportIcon,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: _kRowGap),
                AspectRatio(
                  aspectRatio: 1,
                  child: SquareChip(
                    tooltip: 'Report a bug',
                    onTap: () => _open(context, Uri.parse('$_repo/issues/new')),
                    child: GlitchIcon(
                      AppIcons.bug,
                      size: _kBugIcon,
                      ink: _kBugInk,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "OpenFinances is free software developed by OpenProject under the GNU..."
/// (a sentence, so plain Text: InkText takes one style): OpenFinances as at
/// the top of Settings, at the text's size; the names open their sites.
class _ThisAppText extends StatefulWidget {
  const _ThisAppText({
    required this.style,
    required this.onFinances,
    required this.onProject,
  });
  final TextStyle style;
  final VoidCallback onFinances, onProject;

  @override
  State<_ThisAppText> createState() => _ThisAppTextState();
}

class _ThisAppTextState extends State<_ThisAppText> {
  late final _finances = TapGestureRecognizer()
    ..onTap = () => widget.onFinances();
  late final _project = TapGestureRecognizer()
    ..onTap = () => widget.onProject();

  @override
  void dispose() {
    _finances.dispose();
    _project.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final size = widget.style.fontSize!;
    final open = dark ? Colors.white : scheme.onSurface;
    // The style on the Text (it keeps the theme's fallback fonts, which the
    // digit-only About font needs for its letters; on a span, it would drop
    // them).
    return Text.rich(
      style: widget.style,
      TextSpan(
        children: [
          TextSpan(
            text: 'Open',
            recognizer: _finances,
            style: BrandName.style(size, FontWeight.w600, open),
          ),
          TextSpan(
            text: 'Finances',
            recognizer: _finances,
            style: BrandName.style(size, FontWeight.w600, kBrandBlue),
          ),
          const TextSpan(text: ' is free software developed by '),
          TextSpan(
            text: 'OpenProject',
            recognizer: _project,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const TextSpan(
            text:
                ' under the GNU General Public License v3 (or later). Icons '
                'and fonts keep their own licenses (below)',
          ),
        ],
      ),
    );
  }
}

/// The three marks of the family across the whole row, as equal squares:
/// OpenFinances, OpenProject (the umbrella, in the middle) and OpenDesign
/// (all on the app's plate).
class _FamilyLogos extends StatelessWidget {
  const _FamilyLogos({
    required this.onFinances,
    required this.onProject,
    required this.onDesign,
  });

  final VoidCallback onFinances, onProject, onDesign;

  @override
  Widget build(BuildContext context) {
    // Drawn at 256 and scaled to the square's size (no LayoutBuilder:
    // Settings measures its rows' intrinsic sizes).
    Widget square(String name, VoidCallback onTap, Widget logo) => Expanded(
      child: Semantics(
        button: true,
        label: name,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AspectRatio(aspectRatio: 1, child: FittedBox(child: logo)),
        ),
      ),
    );
    return Row(
      children: [
        square('OpenFinances', onFinances, const BrandMark(size: 256)),
        const SizedBox(width: _kRowGap),
        square(
          'OpenProject',
          onProject,
          const FamilyMarkView(FamilyMark.openProject, size: 256),
        ),
        const SizedBox(width: _kRowGap),
        square(
          'OpenDesign',
          onDesign,
          const FamilyMarkView(FamilyMark.openDesign, size: 256),
        ),
      ],
    );
  }
}

/// "Version 1.0.9" (the installed app's, from Android; its build number is in
/// the log), a section like the rest: what each version changed, the newest
/// first, in a box of limited height that scrolls ([kChangeLog]).
class _VersionSection extends StatefulWidget {
  const _VersionSection();

  @override
  State<_VersionSection> createState() => _VersionSectionState();
}

class _VersionSectionState extends State<_VersionSection> {
  static const _app = MethodChannel('openfinances/app');
  static const double _maxHeight = 280;
  String? _version;

  @override
  void initState() {
    super.initState();
    _app
        .invokeMethod<String>('version')
        .then((v) {
          if (mounted) setState(() => _version = v);
        })
        .catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = TextStyle(
      fontFamily: kAboutFont,
      fontSize: 12.5,
      height: 1.4,
      color: scheme.onSurfaceVariant,
    );
    final strong = text.copyWith(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    );
    return FoldSection(
      id: 'settings.about.version',
      title: _version == null
          ? 'Version'
          : 'Version ${_version!.split('+').first}',
      radius: _kChipRadius,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _UpdateCheck(),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _maxHeight),
            child: ScrollChain(
              child: HintedScroll(
                id: ScrollHint.changeLog,
                builder: (context, controller) => SingleChildScrollView(
                  controller: controller,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, v) in kChangeLog.indexed) ...[
                        if (i > 0) const SizedBox(height: 14),
                        InkText('${v.version} - ${v.date}', style: strong),
                        const SizedBox(height: 4),
                        for (final line in v.changes)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: InkText(line, style: text),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where an update check stands.
enum _Update { idle, checking, notPlay, upToDate, available }

/// Check for updates, the Version section's first thing (the owner,
/// 2026-11-02), on a tap only. Android asks the Play Store, which does the
/// network part (the app has no INTERNET permission). Turning while it asks;
/// green with a check when up to date (also when Play no longer lists the app,
/// the owner's call); not installed from Play: GitHub instead, and a warning
/// joined under it; Play unreachable: a failure notice, back to asking.
class _UpdateCheck extends StatefulWidget {
  const _UpdateCheck();

  @override
  State<_UpdateCheck> createState() => _UpdateCheckState();
}

class _UpdateCheckState extends State<_UpdateCheck>
    with SingleTickerProviderStateMixin {
  static const _app = MethodChannel('openfinances/app');
  _Update _state = _Update.idle;

  /// Steady, as the machinery of the Settings icon; runs only while checking.
  late final _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final notice = AppNotice.of(context);
    setState(() => _state = _Update.checking);
    _turn.repeat();
    final asked = Stopwatch()..start();
    String? answer;
    try {
      answer = await _app.invokeMethod<String>('checkUpdate');
    } catch (_) {
      answer = null;
    }
    // Long enough to read as checking.
    final left = 700 - asked.elapsedMilliseconds;
    if (left > 0) await Future<void>.delayed(Duration(milliseconds: left));
    if (!mounted) return;
    _turn.stop();
    setState(() {
      _state = switch (answer) {
        'notPlay' => _Update.notPlay,
        'upToDate' => _Update.upToDate,
        'available' => _Update.available,
        _ => _Update.idle,
      };
    });
    if (_state == _Update.idle) {
      notice.show("Couldn't reach the Play Store", kind: NoticeKind.failure);
    }
  }

  void _tap() {
    switch (_state) {
      case _Update.checking:
        return;
      case _Update.notPlay:
        _AboutBox._open(context, Uri.parse(_AboutBox._repo));
      case _Update.available:
        _AboutBox._open(
          context,
          Uri.parse(
            'https://play.google.com/store/apps/details'
            '?id=com.openproject.openfinances',
          ),
        );
      case _Update.idle:
      case _Update.upToDate:
        _check();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const r = Radius.circular(_kChipRadius);
    final warn = _state == _Update.notPlay;
    final (Color bg, String label, Widget? icon) = switch (_state) {
      _Update.idle => (context.raised, 'Check for updates', null),
      _Update.checking => (
        context.raised,
        'Checking',
        RotationTransition(
          turns: _turn,
          child: ImageIcon(AppIcons.loading, size: 18, color: scheme.onSurface),
        ),
      ),
      _Update.notPlay => (
        context.raised,
        'Open GitHub',
        ImageIcon(AppIcons.github, size: 20, color: scheme.onSurface),
      ),
      _Update.upToDate => (
        kSuccessGreen,
        'Up to date',
        ImageIcon(AppIcons.check, size: 18, color: onColor(kSuccessGreen)),
      ),
      _Update.available => (scheme.primary, 'Update available', null),
    };
    final fg = onColor(bg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _tap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints: const BoxConstraints(minHeight: 50),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: warn
                    ? const BorderRadius.vertical(top: r)
                    : const BorderRadius.all(r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[icon, const SizedBox(width: 10)],
                  Flexible(
                    child: InkText(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kAboutFont,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            _state == _Update.idle ||
                                _state == _Update.checking ||
                                warn
                            ? scheme.onSurface
                            : fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (warn) ...[
          const SizedBox(height: kPartGap),
          Container(
            constraints: const BoxConstraints(minHeight: 40),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: kWarnOrange,
              borderRadius: BorderRadius.vertical(bottom: r),
            ),
            child: InkText(
              'Not installed from the Play Store\nCheck GitHub for updates',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kAboutFont,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: onColor(kWarnOrange),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// What becomes of the app's own data when a backup is restored over it.
enum _RestoreChoice { replace, backUpAndReplace, merge }

/// Asked before a restore when the app already has data: delete it, back
/// it up and then delete it, or merge the backup into it; or cancel.
Future<_RestoreChoice?> _restoreChoiceSheet(BuildContext context) {
  return showModalBottomSheet<_RestoreChoice>(
    context: context,
    builder: (context) {
      final l = AppLocalizations.of(context)!;
      final scheme = Theme.of(context).colorScheme;
      Widget chip(_RestoreChoice c, String label, Color bg, Color fg) =>
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pop(context, c),
              child: Container(
                height: 56,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(_kChipRadius),
                ),
                child: InkText(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          );
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkText(
                l.restoreChoiceMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  chip(
                    _RestoreChoice.replace,
                    l.restoreDeleteCurrent,
                    kStrongRed,
                    Colors.white,
                  ),
                  const SizedBox(width: _kRowGap),
                  chip(
                    _RestoreChoice.backUpAndReplace,
                    l.restoreBackUpThenDelete,
                    scheme.primary,
                    context.textOnStrong,
                  ),
                  const SizedBox(width: _kRowGap),
                  chip(
                    _RestoreChoice.merge,
                    l.restoreMerge,
                    scheme.primary,
                    context.textOnStrong,
                  ),
                ],
              ),
              const SizedBox(height: _kRowGap),
              // Not red: deleting is one of the choices above.
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  overlayColor: Colors.transparent,
                  side: BorderSide.none,
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: scheme.surfaceContainerHigh,
                  foregroundColor: scheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_kChipRadius),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: InkText(l.cancel),
              ),
            ],
          ),
        ),
      );
    },
  );
}
