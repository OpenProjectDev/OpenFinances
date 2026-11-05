import 'package:flutter/widgets.dart';

/// App-specific glyphs (single-color PNGs, tinted via [ImageIcon]).
/// Use like icons: `const ImageIcon(AppIcons.calendar)` picks up the
/// surrounding IconTheme's size and color.
abstract final class AppIcons {
  static const calendar = AssetImage('assets/icons/calendar.png');

  /// Where backups are saved (kmg design, Flaticon).
  static const folder = AssetImage('assets/icons/folder.png');

  /// A backup's file name, to rename it (ekays.dsgn's title tag, Flaticon).
  static const titleTag = AssetImage('assets/icons/title_tag.png');

  /// Back to the default (a picked backup folder, a chosen name): KP Arts'
  /// "Undo", Flaticon.
  static const undo = AssetImage('assets/icons/undo.png');

  /// Calculator (amount field): a squircle with ÷ cut out (Uicons "circle
  /// divide").
  static const calculator = AssetImage('assets/icons/calculator.png');

  /// The bottom bar's Budget (Uicons "HDD") and Settings (a gear) tabs;
  /// drawn by BudgetNavIcon / SettingsNavIcon.
  static const budget = AssetImage('assets/nav/budget.png');
  static const settings = AssetImage('assets/nav/settings.png');

  /// The biometric lock chip.
  static const fingerprint = AssetImage('assets/icons/fingerprint.png');

  /// Managing categories (a hexagonal nut).
  static const cogwheel = AssetImage('assets/icons/cogwheel.png');

  /// Theme colors (settings).
  static const palette = AssetImage('assets/icons/palette.png');

  /// Save (a diskette), tinted like the other line icons.
  static const diskette = AssetImage('assets/icons/diskette.png');

  /// Edit (swipe-to-edit panels).
  static const edit = AssetImage('assets/icons/edit.png');

  /// Clearing a field (red).
  static const eraser = AssetImage('assets/icons/eraser.png');

  /// Close / remove (notices, a debt's due date, a payment).
  static const close = AssetImage('assets/icons/close.png');

  /// A notice's status before its close square: done (Maxim Basinski
  /// Premium's "Check") and failed (Magnific's "Danger").
  static const check = AssetImage('assets/icons/check.png');
  static const danger = AssetImage('assets/icons/danger.png');

  /// A category's default icon (the "category" choice in the picker).
  static const category = AssetImage('assets/icons/category.png');

  /// Delete (on every delete button and swipe panel).
  static const trash = AssetImage('assets/icons/trash.png');

  /// More / less than before (Statistics' pills: Falcone's "Down arrow",
  /// Flaticon; up is it turned round).
  static const moreArrows = AssetImage('assets/icons/arrows_up.png');
  static const lessArrows = AssetImage('assets/icons/arrows_down.png');

  /// The percent sign after a percentage (the pie's and Budget's chips;
  /// meaicon's "Percent", Flaticon).
  static const percent = AssetImage('assets/icons/percent.png');

  /// A category's titles suggested (eye) or not (hidden).
  static const show = AssetImage('assets/icons/show.png');
  static const hide = AssetImage('assets/icons/hide.png');

  /// Chevrons: dropdowns open (down), period steps (left / right).
  static const chevronDown = AssetImage('assets/icons/chevron_down.png');
  static const chevronUp = AssetImage('assets/icons/chevron_up.png');
  static const chevronLeft = AssetImage('assets/icons/chevron_left.png');
  static const chevronRight = AssetImage('assets/icons/chevron_right.png');

  /// Backup format: JSON (curly braces).
  static const json = AssetImage('assets/icons/json.png');

  /// Backup format: Excel. Full-color artwork: draw with `Image`, not
  /// [ImageIcon] (tinting would flatten it).
  static const xls = AssetImage('assets/icons/xls.png');

  /// About: email the developer.
  static const support = AssetImage('assets/icons/support.png');

  /// About: report a bug.
  static const bug = AssetImage('assets/icons/bug.png');

  /// About: the project on GitHub.
  static const github = AssetImage('assets/icons/github.png');

  /// Something being worked out; turns while it is.
  static const loading = AssetImage('assets/icons/loading.png');
}
