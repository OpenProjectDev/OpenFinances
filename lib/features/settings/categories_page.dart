import 'package:flutter/material.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/data/upcoming_provider.dart';
import 'package:openfinances/data/income_provider.dart';
import 'package:openfinances/data/expense_provider.dart';
import 'package:openfinances/shared/ui/app_icons.dart';
import 'package:openfinances/app/app_bottom_bar.dart';
import 'package:openfinances/app/nav_icons.dart';
import 'package:openfinances/shared/ui/app_notice.dart';
import 'package:openfinances/app/theme.dart';
import 'package:openfinances/shared/ui/entry_fields.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:openfinances/data/category_repository.dart';
import 'package:openfinances/shared/ui/color_picker_page.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/ui/keyboard_inset.dart';
import 'package:openfinances/shared/ui/uicons.g.dart';
import 'package:openfinances/shared/transaction_kind.dart';
import 'package:openfinances/features/expenses/add_edit_expense_sheet.dart'
    show CategoryPickerButton;

/// UIcons by code point (categories store the code point and the font).
final Map<int, IconData> _uiconByCode = {
  for (final i in kUIconsSolid.values) i.codePoint: i,
};

/// A stored category icon (code point + font) as an icon. Categories saved
/// before the switch to UIcons hold Material icons: those show their
/// closest UIcon (nothing stored is rewritten). The default stays
/// [Icons.category] (drawn with the app's own image by [CategoryIcon]).
IconData resolveCategoryIcon(int codePoint, [String? fontFamily]) {
  if (fontFamily == kUIconsSolid.values.first.fontFamily) {
    return _uiconByCode[codePoint] ?? Icons.category;
  }
  final name = kUIconForMaterial[codePoint];
  return name == null ? Icons.category : kUIconsSolid[name]!;
}

/// A category's icon: [icon] from the picker, except the default one,
/// which is drawn with the app's own image.
/// The longest a category name can be: it shows whole (on two lines at
/// most) in the category pickers.
const int kCategoryNameMax = 30;

class CategoryIcon extends StatelessWidget {
  const CategoryIcon(this.icon, {super.key, this.size, this.color});

  final IconData icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) => icon == Icons.category
      // The image fills its box; the font glyphs keep a margin: a bit
      // smaller to look the same size.
      ? ImageIcon(
          AppIcons.category,
          size: (size ?? IconTheme.of(context).size ?? 24) * .8,
          color: color,
        )
      : Icon(icon, size: size, color: color);
}

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({
    super.key,
    this.repository,
    this.title,
    this.embedded = false,
    this.navIndex = 3,
  });

  /// The main tab this page was opened from (highlighted in its bottom
  /// bar; standalone only).
  final int navIndex;

  /// Which set of categories to manage. Defaults to expense categories;
  /// pass a repository built with `CategoryRepository(table: 'income_categories')`
  /// to manage income categories with the exact same UI.
  final CategoryRepository? repository;

  /// Overrides the AppBar title (defaults to the localized "Categories").
  final String? title;

  /// Rendered inside [CategoryTabsPage]: no app bar and no pop handling
  /// of its own (the host page owns both).
  final bool embedded;

  @override
  State<CategoriesPage> createState() => CategoriesPageState();
}

class CategoriesPageState extends State<CategoriesPage> {
  late final _repo = widget.repository ?? CategoryRepository();
  bool _loading = true;
  bool _changed = false; // track if anything modified
  List<CategoryDto> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await _repo.list();
    if (!mounted) return;
    setState(() {
      _items = rows;
      _loading = false;
    });
  }

  /// A new category (the bottom bar's "+").
  void addNew() => _openSheet();

  Future<void> _openSheet({CategoryDto? existing}) async {
    // Delete offered unless it's the last category (it names the heir).
    final heir = existing == null ? null : _heir(existing.gid);
    final sheet = _NewCategorySheet(
      existing: existing,
      heirName: heir?.name,
      others: [
        for (final c in _items)
          if (c.gid != existing?.gid) c,
      ],
    );
    final res = await showModalBottomSheet<_NewCatResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      // One instance reused on every builder call (re-run each keyboard
      // frame); KeyboardInset lifts it without rebuilding the form.
      builder: (ctx) => KeyboardInset(child: sheet),
    );
    if (!mounted || res == null) return;

    // Its Delete: asked here, with where its entries go.
    if (existing != null && res.name == '__DELETE__') {
      await _delete(existing.gid);
      return;
    }

    final now = DateTime.now().toUtc();
    if (existing == null) {
      final dto = CategoryDto(
        gid: 'cat_${DateTime.now().millisecondsSinceEpoch}',
        name: res.name, // user-provided — not localized
        sort: _items.isEmpty
            ? 0
            : (_items.map((e) => e.sort).reduce((a, b) => a > b ? a : b) + 1),
        createdAtUtc: now,
        updatedAtUtc: now,
        iconCodePoint: res.iconCodePoint,
        iconFontFamily: res.iconFontFamily,
        color: res.colorValue,
      );
      await _repo.upsert(dto);
      _changed = true;
    } else {
      await _repo.upsert(
        existing.copyWith(
          name: res.name, // user-provided — not localized
          iconCodePoint: res.iconCodePoint,
          iconFontFamily: res.iconFontFamily,
          color: res.colorValue,
          updatedAtUtc: now,
          isDirty: true,
        ),
      );
      _changed = true;
    }
    await _load();
  }

  /// Where [gid]'s entries go when it's deleted: General if it stays,
  /// else the first remaining category; null when it's the last one.
  CategoryDto? _heir(String gid) {
    final rest = _items.where((c) => c.gid != gid).toList();
    if (rest.isEmpty) return null;
    return rest.where((c) => c.gid == _repo.generalGid).firstOrNull ??
        rest.first;
  }

  Future<void> _delete(String gid) async {
    final l = AppLocalizations.of(context)!;
    final heir = _heir(gid);
    if (heir == null) {
      showAppNotice(
        context,
        l.lastCategoryCantDelete,
        kind: NoticeKind.failure,
      );
      return;
    }
    final to = await _askCategoryHeir(
      context,
      kind: _repo.isIncome ? TransactionKind.income : TransactionKind.expense,
      deleting: gid,
      others: {
        for (final c in _items)
          if (c.gid != gid) c.gid,
      },
      initial: heir.gid,
    );
    if (!mounted || to == null) return;
    await _deleteNow(gid, to);
  }

  /// Deletes [gid] (asked already); its entries move to [heirGid].
  Future<void> _deleteNow(String gid, String heirGid) async {
    final income = _repo.isIncome;
    final ep = context.read<ExpenseProvider>();
    final ip = context.read<IncomeProvider>();
    final up = context.read<UpcomingProvider>();
    await _repo.deleteMovingTo(gid, heirGid);
    _changed = true;
    // Its entries now sit under the heir: reload them.
    if (income) {
      await ip.init();
    } else {
      await ep.init();
      await up.init();
    }
    await _load();
  }

  // onReorderItem already gives the final index (no "-1 when moving down").
  // The new order is shown synchronously (before any await) so the drop
  // lands on it; waiting for the DB writes first flashed the old order.
  Future<void> _reorder(int oldIndex, int newIndex) async {
    final list = List<CategoryDto>.from(_items);
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);

    final now = DateTime.now().toUtc();
    final changed = <CategoryDto>[];
    for (var i = 0; i < list.length; i++) {
      if (list[i].sort == i) continue;
      list[i] = list[i].copyWith(sort: i, updatedAtUtc: now, isDirty: true);
      changed.add(list[i]);
    }
    setState(() => _items = list);
    _changed = true;
    for (final c in changed) {
      await _repo.upsert(c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final page = Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: InkText(widget.title ?? l.categories),
              // The sheets' red close square (the owner, 2026-10-26).
              leading: Center(
                child: SheetCloseChip(
                  onTap: () => Navigator.of(context).pop(_changed),
                ),
              ),
            ),
      // Standalone: the app's bottom bar, its "+" adds a category (inside
      // CategoryTabsPage the host shows the bar).
      extendBody: true,
      bottomNavigationBar: widget.embedded
          ? null
          : AppBottomBar(
              selected: widget.navIndex,
              // Back after a tab jump brings this page back.
              onTab: (i) => goToMainTab(context, i, reopen: (_) => widget),
              onAdd: addNew,
              adds: AddSheet.category,
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: InkText(
                  l.noCategoriesYet,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          // Clear of the bottom bar it runs under (the Scaffold's padding
          // has its height; this State's context only the system's).
          : Builder(
              builder: (context) => ReorderableListView.builder(
                padding: EdgeInsets.fromLTRB(
                  12,
                  12,
                  12,
                  MediaQuery.paddingOf(context).bottom + 16,
                ),
                itemCount: _items.length,
                onReorderItem: _reorder,
                // The dragged row as-is: no lifted shadow/tint while moving.
                proxyDecorator: (child, _, _) =>
                    Material(type: MaterialType.transparency, child: child),
                itemBuilder: (context, i) {
                  final c = _items[i];
                  final color = Color(c.color);
                  final icon = resolveCategoryIcon(
                    c.iconCodePoint,
                    c.iconFontFamily,
                  );

                  // Like every list: start→end deletes, end→start edits.
                  // The last category only edits (one always stays).
                  final general = _items.length < 2;
                  final deleteBg = _swipeBg(
                    context,
                    alignStart: false,
                    color: kStrongRed,
                    icon: const ImageIcon(AppIcons.trash),
                    iconColor: Colors.white,
                    label: l.delete,
                  );
                  final editBg = _swipeBg(
                    context,
                    alignStart: true,
                    color: scheme.secondaryContainer,
                    icon: const ImageIcon(AppIcons.edit),
                    iconColor: scheme.onSecondaryContainer,
                    label: l.edit,
                  );
                  return Dismissible(
                    key: ValueKey('cat_${c.gid}'),
                    direction: general
                        ? DismissDirection.endToStart
                        : DismissDirection.horizontal,
                    background: general ? editBg : deleteBg,
                    secondaryBackground: editBg,
                    confirmDismiss: (dir) async {
                      if (dir == DismissDirection.endToStart) {
                        await _openSheet(existing: c);
                      } else if (dir == DismissDirection.startToEnd) {
                        await _delete(c.gid);
                      }
                      return false;
                    },
                    child: Card(
                      key: ValueKey('card_${c.gid}'),
                      color: scheme.surfaceContainerHigh,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.20),
                          child: CategoryIcon(icon, color: color),
                        ),
                        title: InkText(c.name), // user text, not translated
                        // Off: titles used in this category aren't suggested.
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // An eye: its titles are suggested; tap to hide
                            // them (the eye crossed out, faint).
                            Builder(
                              builder: (context) {
                                final on = !context
                                    .watch<SettingsProvider>()
                                    .noSuggestCategories
                                    .contains(c.gid);
                                return Semantics(
                                  button: true,
                                  label: l.suggestTitlesFromCategory,
                                  child: IconButton(
                                    style: IconButton.styleFrom(
                                      overlayColor: Colors.transparent,
                                    ),
                                    onPressed: () => context
                                        .read<SettingsProvider>()
                                        .setCategorySuggests(c.gid, !on),
                                    icon: ImageIcon(
                                      on ? AppIcons.show : AppIcons.hide,
                                      size: 22,
                                      color: on
                                          ? scheme.onSurface
                                          : scheme.onSurfaceVariant.withValues(
                                              alpha: .5,
                                            ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                            const Icon(UIcons.drag),
                          ],
                        ),
                        onTap: () => _openSheet(existing: c),
                      ),
                    ),
                  );
                },
              ),
            ),
    );

    if (widget.embedded) return page;
    return PopScope(
      canPop: false, // we'll handle back ourselves
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed); // pass the "changed" flag back
      },
      child: page,
    );
  }

  Widget _swipeBg(
    BuildContext context, {
    required bool alignStart,
    required Color color,
    required Widget icon,
    required Color iconColor,
    required String label,
  }) {
    return Container(
      alignment: alignStart ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: alignStart
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          IconTheme.merge(
            data: IconThemeData(color: iconColor, size: 24),
            child: icon,
          ),
          const SizedBox(width: 8),
          InkText(
            label,
            style: TextStyle(color: iconColor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Asks before deleting category [deleting]: where its entries go, in the
/// add sheet's category picker ([others] only, [initial] chosen: General
/// unless it's the one going; the owner, 2026-10-26). The category picked,
/// or null: kept.
Future<String?> _askCategoryHeir(
  BuildContext context, {
  required TransactionKind kind,
  required String deleting,
  required Set<String> others,
  required String initial,
}) {
  var to = initial;
  return showModalBottomSheet<String>(
    context: context,
    builder: (sheet) {
      final l = AppLocalizations.of(sheet)!;
      final scheme = Theme.of(sheet).colorScheme;
      final style = OutlinedButton.styleFrom(
        overlayColor: Colors.transparent,
        minimumSize: const Size.fromHeight(50),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: scheme.surfaceContainerHigh,
        foregroundColor: scheme.onSurface,
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
                l.deleteCategory,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              InkText(
                l.deleteCategoryMoveTo,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              CategoryPickerButton(
                kind: kind,
                initialCategoryGid: initial,
                only: others,
                showManage: false,
                onChanged: (gid) => to = gid,
              ),
              const SizedBox(height: kSheetRowGap),
              Row(
                children: [
                  Expanded(
                    // Not red: Delete next to it already is.
                    child: OutlinedButton(
                      style: style,
                      onPressed: () => Navigator.pop(sheet),
                      child: InkText(l.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: cancelButtonStyle(style),
                      onPressed: () => Navigator.pop(sheet, to),
                      icon: const ImageIcon(AppIcons.trash, size: 18),
                      label: InkText(l.delete),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _NewCatResult {
  final String name;
  final int iconCodePoint;
  final String iconFontFamily;
  final int colorValue;
  const _NewCatResult(
    this.name,
    this.iconCodePoint,
    this.iconFontFamily,
    this.colorValue,
  );
}

class _NewCategorySheet extends StatefulWidget {
  const _NewCategorySheet({
    this.existing,
    this.heirName,
    this.others = const [],
  });
  final CategoryDto? existing;

  /// The other categories (shown beside the colors).
  final List<CategoryDto> others;

  /// Where its entries go if deleted; null: it can't be (the last one).
  final String? heirName;

  @override
  State<_NewCategorySheet> createState() => _NewCategorySheetState();
}

class _NewCategorySheetState extends State<_NewCategorySheet> {
  final _nameCtrl = TextEditingController();
  final _nameFocus = FocusNode();

  // Defaults
  IconData _icon = Icons.category;
  Color _color = const Color(0xFF0BA5A4);

  // How the form started (Save waits for a change when editing).
  String _startName = '';
  IconData? _startIcon;
  Color? _startColor;

  bool get _anyChange =>
      _nameCtrl.text != _startName ||
      _icon != _startIcon ||
      _color != _startColor;

  /// Editing and nothing changed: nothing to save.
  bool get _unchangedEdit => widget.existing != null && !_anyChange;

  /// Save is grey until it can save: a name, and (editing) a change.
  bool get _ready => _nameCtrl.text.trim().isNotEmpty && !_unchangedEdit;

  @override
  void initState() {
    super.initState();
    // Keyboard after the sheet has slid up, not during (only when adding).
    if (widget.existing == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focusAfterRouteOpens(context, _nameFocus);
      });
    }
    final ex = widget.existing;
    if (ex != null) {
      _nameCtrl.text = ex.name;
      _icon = resolveCategoryIcon(ex.iconCodePoint, ex.iconFontFamily);
      _color = Color(ex.color);
    }
    _startName = _nameCtrl.text;
    _startIcon = _icon;
    _startColor = _color;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isEditing = widget.existing != null;
    // The last category can be renamed / recolored, never deleted.
    final canDelete = isEditing && widget.heirName != null;
    final fieldStyle = OutlinedButton.styleFrom(
      overlayColor: Colors.transparent,
      minimumSize: const Size.fromHeight(50),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      backgroundColor: scheme.surfaceContainerHigh,
      foregroundColor: scheme.onSurface,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    // No full-height Align around this: it made the (transparent) sheet
    // cover the whole screen, so taps outside never reached the barrier.
    return Material(
      color: scheme.surface,
      elevation: 8,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(22),
        topRight: Radius.circular(22),
      ),
      // Like the other sheets: no title or label (the name's placeholder
      // says what it is), filled buttons without strokes.
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkField(
                controller: _nameCtrl,
                hint: l.categoryNameLabel,
                builder: (shown) => TextField(
                  controller: _nameCtrl,
                  focusNode: _nameFocus,
                  autofocus: false, // see focusAfterRouteOpens in initState
                  textInputAction: TextInputAction.done,
                  // Short enough to show whole (on two lines at most) in the
                  // category pickers; no counter.
                  maxLength: kCategoryNameMax,
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                  textAlign: TextAlign.right,
                  decoration: entryFieldDecoration(
                    context,
                    shown: shown,
                    suffixIcon: ClearWhenFilled(
                      controller: _nameCtrl,
                      onClear: () {
                        _nameCtrl.clear();
                        _nameFocus.requestFocus();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: kSheetRowGap),

              // Icon & Color pickers
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: fieldStyle,
                      onPressed: () async {
                        final picked = await Navigator.of(context)
                            .push<IconData>(
                              MaterialPageRoute(
                                builder: (_) => _IconPickerPage(initial: _icon),
                                fullscreenDialog: true,
                              ),
                            );
                        if (picked != null && mounted) {
                          setState(() => _icon = picked);
                        }
                      },
                      icon: CategoryIcon(_icon),
                      label: InkText(l.pickIcon),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: fieldStyle,
                      onPressed: () async {
                        final picked = await Navigator.of(context).push<Color>(
                          MaterialPageRoute(
                            builder: (_) => ColorPickerPage(
                              initial: _color,
                              // Its own icon on the chosen color, and the
                              // others as they look.
                              mark: (ink, size) =>
                                  CategoryIcon(_icon, color: ink, size: size),
                              others: [
                                for (final c in widget.others)
                                  ColorPickerCategory(
                                    Color(c.color),
                                    (ink, size) => CategoryIcon(
                                      resolveCategoryIcon(
                                        c.iconCodePoint,
                                        c.iconFontFamily,
                                      ),
                                      color: ink,
                                      size: size,
                                    ),
                                  ),
                              ],
                            ),
                            fullscreenDialog: true,
                          ),
                        );
                        if (picked != null && mounted) {
                          setState(() => _color = picked);
                        }
                      },
                      icon: CircleAvatar(radius: 10, backgroundColor: _color),
                      label: InkText(l.pickColor),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: kSheetRowGap),

              // Buttons row (Cancel, optional Delete, Save)
              Row(
                children: [
                  Expanded(
                    child: CancelButton(onCancel: () => Navigator.pop(context)),
                  ),
                  const SizedBox(width: 12),

                  if (canDelete) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const ImageIcon(AppIcons.trash, size: 18),
                        style: fieldStyle.copyWith(
                          foregroundColor: const WidgetStatePropertyAll(
                            Colors.white,
                          ),
                          backgroundColor: const WidgetStatePropertyAll(
                            kStrongRed,
                          ),
                        ),
                        // The page asks next, with where its entries go.
                        onPressed: () => Navigator.pop(
                          context,
                          const _NewCatResult(
                            '__DELETE__',
                            0,
                            'MaterialIcons',
                            0,
                          ),
                        ),
                        label: InkText(l.delete),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  Expanded(
                    child: ListenableBuilder(
                      listenable: _nameCtrl,
                      builder: (context, _) => OutlinedButton(
                        style: saveButtonStyle(context, fieldStyle, _ready),
                        onPressed: _unchangedEdit
                            ? null
                            : () {
                                final name = _nameCtrl.text.trim();
                                if (name.isEmpty) {
                                  showAppNotice(
                                    context,
                                    l.enterCategoryName,
                                    kind: NoticeKind.failure,
                                  );
                                  return;
                                }
                                Navigator.pop(
                                  context,
                                  _NewCatResult(
                                    name, // user text — saved as-is
                                    _icon.codePoint,
                                    _icon.fontFamily ?? 'MaterialIcons',
                                    _color.toARGB32(),
                                  ),
                                );
                              },
                        child: InkText(l.save),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ================= ICON PICKER PAGE =================

/// Picks a category icon: "All" (every icon, with a search over their
/// names and the groups' names) first, then the groups.
class _IconPickerPage extends StatefulWidget {
  const _IconPickerPage({required this.initial});
  final IconData initial;

  static const double _glyph = 22.0;

  @override
  State<_IconPickerPage> createState() => _IconPickerPageState();
}

class _IconPickerPageState extends State<_IconPickerPage> {
  final _search = TextEditingController();

  /// The default icon (the app's own image) first, then the groups' icons,
  /// then every other UIcon (by name).
  static final List<IconData> _all = () {
    final seen = <int>{};
    return [
      Icons.category,
      for (final (_, names) in kUIconGroups)
        for (final n in names)
          if (seen.add(kUIconsSolid[n]!.codePoint)) kUIconsSolid[n]!,
      for (final i in kUIconsSolid.values)
        if (seen.add(i.codePoint)) i,
    ];
  }();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _groupLabel(AppLocalizations l, String key) => switch (key) {
    'Shopping' => l.iconGroupShopping,
    'Money' => l.iconGroupMoney,
    'Food' => l.iconGroupFood,
    'Transport' => l.iconGroupTransport,
    'Home' => l.iconGroupHome,
    'Bills' => l.iconGroupBills,
    'Tech' => l.iconGroupTech,
    'Health' => l.iconGroupHealth,
    'Personal' => l.iconGroupPersonal,
    'Work' => l.iconGroupWork,
    'Leisure' => l.iconGroupLeisure,
    _ => l.iconGroupOther,
  };

  /// The groups whose name (in either language) holds what's typed, then
  /// icons whose name has a part starting with each word typed ("car" finds
  /// car-side and card, not scarf), exact parts first.
  List<IconData> _found(AppLocalizations l) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    final out = <IconData>[];
    final seen = <int>{};
    void add(IconData i) {
      if (seen.add(i.codePoint)) out.add(i);
    }

    for (final (key, names) in kUIconGroups) {
      if (_groupLabel(l, key).toLowerCase().contains(q) ||
          key.toLowerCase().contains(q)) {
        for (final n in names) {
          add(kUIconsSolid[n]!);
        }
      }
    }
    final words = q.split(RegExp(r'[\s-]+')).where((w) => w.isNotEmpty);
    final exact = <IconData>[];
    final prefix = <IconData>[];
    kUIconsSolid.forEach((name, icon) {
      final parts = name.split('-');
      if (!words.every((w) => parts.any((p) => p.startsWith(w)))) return;
      (words.every(parts.contains) ? exact : prefix).add(icon);
    });
    exact.forEach(add);
    prefix.forEach(add);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    void pick(IconData i) => Navigator.pop(context, i);

    return DefaultTabController(
      length: 1 + kUIconGroups.length,
      child: Scaffold(
        appBar: AppBar(
          title: InkText(l.pickIconTitle),
          leading: IconButton(
            icon: const ImageIcon(AppIcons.close, size: 16),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l.allShort),
              for (final (key, _) in kUIconGroups)
                Tab(text: _groupLabel(l, key)),
            ],
          ),
        ),
        backgroundColor: scheme.surface,
        body: TabBarView(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: InkField(
                    controller: _search,
                    hint: l.searchIcons,
                    builder: (shown) => TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      textAlign: TextAlign.center,
                      decoration: entryFieldDecoration(
                        context,
                        shown: shown,
                        suffixIcon: ClearWhenFilled(
                          controller: _search,
                          onClear: () => setState(_search.clear),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _CategoryIconGrid(
                    icons: _found(l),
                    initial: widget.initial,
                    onPick: pick,
                  ),
                ),
              ],
            ),
            for (final (_, names) in kUIconGroups)
              _CategoryIconGrid(
                icons: [for (final n in names) kUIconsSolid[n]!],
                initial: widget.initial,
                onPick: pick,
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryIconGrid extends StatelessWidget {
  const _CategoryIconGrid({
    required this.icons,
    required this.initial,
    required this.onPick,
  });

  final List<IconData> icons;
  final IconData initial;
  final ValueChanged<IconData> onPick;

  static const double _glyph = _IconPickerPage._glyph;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 72,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      padding: const EdgeInsets.all(8),
      itemCount: icons.length,
      itemBuilder: (context, i) {
        final icon = icons[i];
        final selected =
            icon.codePoint == initial.codePoint &&
            icon.fontFamily == initial.fontFamily;
        return InkWell(
          onTap: () => onPick(icon),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: selected
                  ? scheme.primary.withValues(alpha: 0.2)
                  : scheme.surfaceContainerHigh,
            ),
            child: CategoryIcon(icon, size: _glyph),
          ),
        );
      },
    );
  }
}

/// One "Manage categories" entry point: expense and income categories as
/// two tabs of the same editor. Pops `true` so callers reload.
class CategoryTabsPage extends StatefulWidget {
  const CategoryTabsPage({super.key, this.initialIndex = 0, this.navIndex = 3});

  /// 0 = expense categories, 1 = income categories.
  final int initialIndex;

  /// The main tab this page was opened from (highlighted in the bar).
  final int navIndex;

  @override
  State<CategoryTabsPage> createState() => _CategoryTabsPageState();
}

class _CategoryTabsPageState extends State<CategoryTabsPage> {
  final _pages = [
    GlobalKey<CategoriesPageState>(),
    GlobalKey<CategoriesPageState>(),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialIndex,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.of(context).pop(true);
        },
        // Builder: the "+" needs the tab controller below this point.
        child: Builder(
          builder: (context) => Scaffold(
            extendBody: true,
            // The app's bottom bar; "+" adds a category to the tab showing
            // (the same sheet on both tabs: no tilt between them).
            bottomNavigationBar: AnimatedBuilder(
              animation: DefaultTabController.of(context),
              builder: (context, _) => AppBottomBar(
                selected: widget.navIndex,
                // Back after a tab jump brings this page back.
                onTab: (i) => goToMainTab(context, i, reopen: (_) => widget),
                onAdd: () => _pages[DefaultTabController.of(context).index]
                    .currentState
                    ?.addNew(),
                adds: AddSheet.category,
              ),
            ),
            appBar: AppBar(
              title: InkText(l.categories),
              // The sheets' red close square (the owner, 2026-10-26).
              leading: Center(
                child: SheetCloseChip(
                  onTap: () => Navigator.of(context).pop(true),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: TabBar(
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      labelColor: scheme.primary,
                      unselectedLabelColor: scheme.onSurfaceVariant,
                      labelStyle: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      tabs: [
                        Tab(height: 40, text: l.expenseShort),
                        Tab(height: 40, text: l.incomeTitle),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            body: TabBarView(
              children: [
                CategoriesPage(key: _pages[0], embedded: true),
                CategoriesPage(
                  key: _pages[1],
                  embedded: true,
                  repository: CategoryRepository(table: 'income_categories'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
