// lib/features/expenses/add_edit_expense_sheet.dart
// A reusable Add/Edit bottom sheet for OpenFinances, covering BOTH expenses and
// income. Which ledger a row belongs to is picked via a switch at the top
// (new entries only — editing keeps the row's existing kind). Expense and
// income stay entirely separate providers/tables; this sheet just routes
// to the right one based on `kind`.

import 'package:flutter/material.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/app/app_bottom_bar.dart';
import 'package:openfinances/app/theme.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart' as s;

import 'package:openfinances/data/category_repository.dart';
import 'package:openfinances/data/currency_units.dart';
import 'package:openfinances/data/entry_suggestions.dart';
import 'package:openfinances/data/expense_provider.dart';
import 'package:openfinances/data/income_provider.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/data/upcoming_provider.dart';
import 'package:openfinances/data/upcoming_repository.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/features/settings/categories_page.dart';
import 'package:openfinances/shared/date_picker.dart';
import 'package:openfinances/shared/money_input.dart';
import 'package:openfinances/shared/ui/app_icons.dart';
import 'package:openfinances/shared/ui/entry_fields.dart';
import 'package:openfinances/shared/ui/joined_menu.dart';
import 'package:openfinances/shared/ui/swipe_row.dart';
import 'package:openfinances/shared/ui/keyboard_inset.dart';
import 'package:openfinances/shared/review_prompter.dart';
import 'package:openfinances/shared/sheet_drafts.dart';
import 'package:openfinances/shared/transaction_kind.dart';
import 'package:openfinances/shared/ui/segmented_pills.dart';
import 'package:openfinances/shared/haptics.dart';

// Space between the sheet's sections, and between rows inside one.
const double _kRowGap = kSheetRowGap;

/// Where an entry of [kind] goes when no category is picked: the general
/// category while it exists, else the first one (there's always one).
String fallbackCategoryGid(BuildContext context, TransactionKind kind) =>
    kind == TransactionKind.expense
    ? context.read<ExpenseProvider>().fallbackCategoryGid
    : context.read<IncomeProvider>().fallbackCategoryGid;

/// Public API. Pass `existing` + `kind` (the row's actual kind) to edit;
/// omit `existing` to add a new entry, in which case `kind` is just the
/// sheet's starting toggle position (the user can still flip it).
/// [prefillAmountMinor] / [prefillDate] start a new entry with those values
/// (e.g. from a bank message). The amount is in [prefillCurrency] (the
/// display currency if null): it's shown converted, and if the user keeps
/// it, it's saved exactly as given, in that unit. Resolves to true if the
/// entry was saved.
Future<bool> showAddEditTransactionSheet({
  required BuildContext context,
  Map<String, dynamic>? existing,
  TransactionKind kind = TransactionKind.expense,
  int? prefillAmountMinor,
  String? prefillCurrency,
  DateTime? prefillDate,
}) async {
  return _AddEditTransactionSheet._show(
    hostContext: context,
    existing: existing,
    initialKind: kind,
    prefillAmountMinor: prefillAmountMinor,
    prefillCurrency: prefillCurrency,
    prefillDate: prefillDate,
  );
}

/// ------------------------ Internal implementation ------------------------
class _AddEditTransactionSheet {
  static const double kButtonHeight = 50;

  static Future<bool> _show({
    required BuildContext hostContext,
    Map<String, dynamic>? existing,
    required TransactionKind initialKind,
    int? prefillAmountMinor,
    String? prefillCurrency,
    DateTime? prefillDate,
  }) async {
    var saved = false;
    final settings = hostContext.read<SettingsProvider>();
    final initialCalendar = settings.calendar;
    // A prefilled amount as shown (in the display currency).
    final prefillShown = prefillAmountMinor == null
        ? null
        : amountInUnit(
            prefillAmountMinor,
            prefillCurrency ?? settings.currencyCode,
            settings.currencyCode,
          );

    final bool isEditing = existing != null;
    TransactionKind currentKind = initialKind;

    final noteCtrl = TextEditingController(
      text: (existing?['note'] as String?)?.trim() ?? '',
    );

    final noteFold = NoteFold(noteCtrl);

    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');

    final amountCtrl = TextEditingController(
      text: isEditing
          ? formatMinorWithCommas((existing['amountMinor'] ?? 0) as int)
          : prefillShown != null
          ? formatMinorWithCommas(prefillShown)
          : '',
    );

    final titleNode = FocusNode();
    final amountNode = FocusNode();

    // What the user has typed themselves (picking a chip resets it, so the
    // chip row goes back to its unfiltered list).
    final titleQuery = ValueNotifier<String>('');

    DateTime pickedLocal = isEditing
        ? (existing['occurredAtUtc'] as DateTime).toLocal()
        : prefillDate ??
              (initialCalendar == AppCalendar.jalali
                  ? s.Jalali.now().toDateTime()
                  : DateTime.now());

    List<CategoryDto> categoriesFor(BuildContext ctx, TransactionKind k) =>
        k == TransactionKind.expense
        ? ctx.read<ExpenseProvider>().categories
        : ctx.read<IncomeProvider>().categories;

    String initialCategoryFor(BuildContext ctx, TransactionKind k) {
      if (isEditing) {
        return (existing['categoryGid'] as String?) ??
            fallbackCategoryGid(ctx, k);
      }
      return fallbackCategoryGid(ctx, k);
    }

    String selectedCategoryGid = initialCategoryFor(hostContext, currentKind);

    // How the form started (Save waits for a change when editing).
    final startTitle = titleCtrl.text;
    final startAmount = amountCtrl.text;
    final startNote = noteCtrl.text;
    final startCategory = selectedCategoryGid;
    final startDate = pickedLocal;
    final startKind = currentKind;

    // A new entry (not one prefilled from a bank message) picks up what a
    // cancelled one left ("keep entries").
    final drafts =
        !isEditing && prefillAmountMinor == null && prefillDate == null;
    final draft = drafts ? SheetDrafts.of(settings, 'entry') : null;
    if (draft != null) {
      currentKind = TransactionKind.values[draft['kind'] as int];
      titleCtrl.text = draft['title'] as String;
      amountCtrl.text = draft['amount'] as String;
      noteCtrl.text = draft['note'] as String;
      pickedLocal = draft['date'] as DateTime;
      selectedCategoryGid = draft['category'] as String;
    }
    bool anyChange() =>
        titleCtrl.text != startTitle ||
        amountCtrl.text != startAmount ||
        noteCtrl.text != startNote ||
        selectedCategoryGid != startCategory ||
        pickedLocal != startDate ||
        currentKind != startKind;
    // Save is grey until it can save: a title and an amount, and (editing)
    // something changed. Tapped grey with a field missing, it still points
    // at that field.
    bool complete() {
      final n = double.tryParse(
        faToEnDigits(amountCtrl.text.trim()).replaceAll(RegExp(r'[,٬،\s]'), ''),
      );
      return titleCtrl.text.trim().isNotEmpty && n != null && n > 0;
    }

    // The sheet's setState (set by its builder), for the date picker.
    StateSetter? setSheet;

    // The sheet is built ONCE and reused: the route re-runs its builder on
    // every frame of the keyboard animation, and handing back the identical
    // widget instance lets Flutter skip rebuilding the whole form each frame
    // (only KeyboardInset updates). This was the main source of lag.
    Widget? sheet;
    Widget buildSheet(BuildContext sheetCtx) {
      final scheme = Theme.of(sheetCtx).colorScheme;

      // Keyboard after the sheet has slid up, not during.
      if (!isEditing) focusAfterRouteOpens(sheetCtx, titleNode);

      bool titleHasError = false;
      bool amountHasError = false;

      // The keyboard stays closed after picking (see pickSheetDate), and
      // the button shows the new date at once.
      Future<void> pickDate() async {
        final res = await pickSheetDate(sheetCtx, pickedLocal, pastOnly: true);
        if (!sheetCtx.mounted || res == null) return;
        setSheet?.call(() => pickedLocal = res);
      }

      return Material(
        color: scheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        elevation: 8,
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            setSheet = setSheetState;
            final l = AppLocalizations.of(context)!;
            final settingsWatch = context.watch<SettingsProvider>();

            final calendar = settingsWatch.calendar;
            final isRtlUi = Directionality.of(context) == TextDirection.rtl;
            final isExpense = currentKind == TransactionKind.expense;

            void switchKind(TransactionKind k) {
              if (k == currentKind) return;
              setSheetState(() {
                currentKind = k;
                selectedCategoryGid = initialCategoryFor(context, k);
              });
            }

            ButtonStyle outlinedButtonStyle() => OutlinedButton.styleFrom(
              overlayColor: Colors.transparent,
              minimumSize: const Size.fromHeight(kButtonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide.none,
              backgroundColor: scheme.surfaceContainerHigh,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            );

            // Scroll only if the field is actually (partly) hidden, and only
            // as far as needed. Always aligning to 25% used to start a scroll
            // animation on every focus — on top of the keyboard animation and
            // the text field's own caret scrolling — which read as stutter.
            Future<void> bringIntoView(BuildContext fieldContext) async {
              await Future.delayed(const Duration(milliseconds: 10));
              if (!fieldContext.mounted) return;
              await Scrollable.ensureVisible(
                fieldContext,
                alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
              );
            }

            String dateLabel(DateTime dt) =>
                formatDateForCalendar(dt, calendar, fa: isRtlUi);

            // ---- Suggestions (titles used before, this kind)
            // (Expenses: with Due's titles, one list for both.)
            final sugg = isExpense
                ? EntrySuggestions.ofExpenses(
                    context.read<ExpenseProvider>().raw,
                    _dueTitles(context),
                  )
                : EntrySuggestions.of(context.read<IncomeProvider>().raw);
            void setText(TextEditingController c, String t) =>
                c.value = TextEditingValue(
                  text: t,
                  selection: TextSelection.collapsed(offset: t.length),
                );

            // Title chip: fill the title, reset the title row, and pick the
            // category it was last used in. Never the amount (the owner,
            // 2026-10-25: amount suggestions only had to be erased).
            void pickTitle(String t) {
              setText(titleCtrl, t);
              titleQuery.value = '';
              final cat = sugg.categoryFor(t);
              final knownCat =
                  cat != null &&
                  categoriesFor(context, currentKind).any((c) => c.gid == cat);
              setSheetState(() {
                titleHasError = false;
                if (knownCat) selectedCategoryGid = cat;
              });
            }

            void clearTitle() {
              titleCtrl.clear();
              titleQuery.value = '';
              titleNode.requestFocus();
            }

            // Suggestion rows: only with suggestions on and something to
            // offer (typing that matches nothing keeps the row, empty).
            // Without one, the field is just a row of the form.
            final suggestSource = isExpense
                ? SuggestSource.expense
                : SuggestSource.income;
            bool hideTitle(String t, String? c) =>
                hiddenTitleSuggestion(settingsWatch, suggestSource, t, c);
            final showTitles =
                settingsWatch.suggestionsOn &&
                sugg.titles(hide: hideTitle).isNotEmpty;

            return SafeArea(
              top: false,
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Expense/Income switch — only when adding new
                    // (editing keeps the row's existing kind).
                    if (!isEditing) ...[
                      SegmentedPills<TransactionKind>(
                        selected: currentKind,
                        onChanged: switchKind,
                        options: {
                          TransactionKind.expense: l.expenseShort,
                          TransactionKind.income: l.incomeTitle,
                        },
                      ),
                      const SizedBox(height: _kRowGap),
                    ],

                    // ---- Section: title + its suggestions
                    Builder(
                      builder: (fieldCtx) => Focus(
                        onFocusChange: (has) {
                          if (has) bringIntoView(fieldCtx);
                        },
                        child: InkField(
                          controller: titleCtrl,
                          hint: l.titleLabel,
                          builder: (shown) => TextField(
                            controller: titleCtrl,
                            focusNode: titleNode,
                            autofocus: false, // see focusAfterRouteOpens
                            textInputAction: TextInputAction.next,
                            textAlign: isRtlUi
                                ? TextAlign.right
                                : TextAlign.left,
                            textDirection: isRtlUi
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            onChanged: (t) {
                              titleQuery.value = t;
                              if (titleHasError) {
                                setSheetState(() => titleHasError = false);
                              }
                            },
                            decoration: entryFieldDecoration(
                              context,
                              shown: shown,
                              error: titleHasError,

                              suffixIcon: ClearWhenFilled(
                                controller: titleCtrl,
                                onClear: clearTitle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    showTitles
                        ? SuggestionsSlot(
                            controller: titleCtrl,
                            focusNode: titleNode,
                            row: ValueListenableBuilder<String>(
                              valueListenable: titleQuery,
                              builder: (_, q, _) {
                                final titles = sugg.titles(
                                  query: q,
                                  hide: hideTitle,
                                );
                                return SuggestionChipsRow(
                                  key: ValueKey(
                                    't$q',
                                  ), // new list starts at the top
                                  labels: titles,
                                  emptyText: l.noMatch,
                                  onTap: (i) => pickTitle(titles[i]),
                                  onLongPress: (i) => ignoreTitleSuggestion(
                                    context,
                                    suggestSource,
                                    titles[i],
                                  ),
                                );
                              },
                            ),
                          )
                        : const SizedBox(height: kSheetRowGap),

                    // ---- Amount (+ calculator) and the note's chip, its field under them
                    NoteRow(
                      fold: noteFold,
                      field: AmountFieldRow(
                        controller: amountCtrl,
                        focusNode: amountNode,
                        error: amountHasError,
                        hint: isExpense
                            ? l.amountHintNumbersOnly
                            : l.amountHintIncomeOnly,
                        onFocused: bringIntoView,
                        onChanged: (t) {
                          if (amountHasError) {
                            setSheetState(() => amountHasError = false);
                          }
                        },
                        onCalculated: () {
                          if (amountHasError) {
                            setSheetState(() => amountHasError = false);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: _kRowGap),
                    NoteSection(fold: noteFold),

                    // ---- Section: date / category
                    // The date as wide as it needs; the category gets the
                    // rest of the row (a long name has room).
                    Row(
                      children: [
                        IntrinsicWidth(
                          child: SheetDateField(
                            style: _pickerButtonStyle(scheme),
                            label: dateLabel(pickedLocal),
                            onTap: pickDate,
                            reset:
                                DateUtils.isSameDay(pickedLocal, DateTime.now())
                                ? null
                                : () => setSheetState(
                                    () => pickedLocal = DateTime.now(),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CategoryPickerButton(
                            kind: currentKind,
                            initialCategoryGid: selectedCategoryGid,
                            onChanged: (gid) =>
                                setSheetState(() => selectedCategoryGid = gid),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: _kRowGap),

                    // ---- Section: actions
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        children: [
                          Expanded(
                            child: CancelButton(
                              height: kButtonHeight,
                              onCancel: () => Navigator.pop(sheetCtx),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ListenableBuilder(
                              listenable: Listenable.merge([
                                titleCtrl,
                                amountCtrl,
                                noteCtrl,
                              ]),
                              builder: (context, _) => OutlinedButton(
                                style: saveButtonStyle(
                                  context,
                                  outlinedButtonStyle(),
                                  complete() && (!isEditing || anyChange()),
                                ),
                                onPressed: isEditing && !anyChange()
                                    ? null
                                    : () async {
                                        final title = titleCtrl.text.trim();
                                        final raw = amountCtrl.text.trim();
                                        final amountText = faToEnDigits(
                                          raw,
                                        ).replaceAll(RegExp(r'[,٬،\s]'), '');

                                        final amountDouble = double.tryParse(
                                          amountText,
                                        );
                                        final amountInt = amountDouble != null
                                            ? (amountDouble * 100).round()
                                            : null;

                                        final titleOk = title.isNotEmpty;
                                        final amountOk =
                                            amountInt != null && amountInt > 0;

                                        if (!titleOk || !amountOk) {
                                          setSheetState(() {
                                            titleHasError = !titleOk;
                                            amountHasError = !amountOk;
                                          });
                                          Haptics.alert(sheetCtx);
                                          if (!titleOk) {
                                            titleNode.requestFocus();
                                          } else if (!amountOk) {
                                            amountNode.requestFocus();
                                          }
                                          return;
                                        }

                                        try {
                                          var settingsCurrency = context
                                              .read<SettingsProvider>()
                                              .currencyCode;
                                          // Prefilled amount kept as is: recorded
                                          // exactly as given, in its own unit.
                                          var amountToSave = amountInt;
                                          if (!isEditing &&
                                              prefillCurrency != null &&
                                              amountInt == prefillShown) {
                                            amountToSave = prefillAmountMinor!;
                                            settingsCurrency = prefillCurrency;
                                          }

                                          final String? cleanNote = (() {
                                            final t = noteCtrl.text.trim();
                                            return t.isEmpty ? null : t;
                                          })();

                                          final occurredLocal = DateTime(
                                            pickedLocal.year,
                                            pickedLocal.month,
                                            pickedLocal.day,
                                          );

                                          if (isExpense) {
                                            final ep = context
                                                .read<ExpenseProvider>();
                                            if (!isEditing) {
                                              await ep.addExpense(
                                                title: title,
                                                amountMinor: amountToSave,
                                                occurredLocal: occurredLocal,
                                                note: cleanNote,
                                                categoryGid:
                                                    selectedCategoryGid,
                                                accountGid: null,
                                                currency: settingsCurrency,
                                              );
                                            } else {
                                              final gid = _ensureGid(existing);
                                              await ep.updateExpense(gid, {
                                                'title': title,
                                                // Rewrite the recorded amount only
                                                // if the user changed it.
                                                if (amountInt !=
                                                    existing['amountMinor']) ...{
                                                  'amountMinor': amountInt,
                                                  'currency': settingsCurrency,
                                                },
                                                'occurredAtUtc': occurredLocal
                                                    .toUtc()
                                                    .toIso8601String(),
                                                'note': cleanNote,
                                                'categoryGid':
                                                    selectedCategoryGid,
                                              });
                                            }
                                          } else {
                                            final ip = context
                                                .read<IncomeProvider>();
                                            if (!isEditing) {
                                              await ip.addIncome(
                                                title: title,
                                                amountMinor: amountToSave,
                                                occurredLocal: occurredLocal,
                                                note: cleanNote,
                                                categoryGid:
                                                    selectedCategoryGid,
                                                accountGid: null,
                                                currency: settingsCurrency,
                                              );
                                            } else {
                                              final gid = _ensureGid(existing);
                                              await ip.updateIncome(gid, {
                                                'title': title,
                                                // Rewrite the recorded amount only
                                                // if the user changed it.
                                                if (amountInt !=
                                                    existing['amountMinor']) ...{
                                                  'amountMinor': amountInt,
                                                  'currency': settingsCurrency,
                                                },
                                                'occurredAtUtc': occurredLocal
                                                    .toUtc()
                                                    .toIso8601String(),
                                                'note': cleanNote,
                                                'categoryGid':
                                                    selectedCategoryGid,
                                              });
                                            }
                                          }

                                          saved = true;
                                          await ReviewPrompter.bumpAndMaybePrompt();
                                        } catch (e) {
                                          debugPrint('Error saving entry: $e');
                                        } finally {
                                          if (sheetCtx.mounted) {
                                            Navigator.of(sheetCtx).pop();
                                          } else if (context.mounted) {
                                            Navigator.of(context).pop();
                                          }
                                        }
                                      },
                                child: InkText(
                                  isEditing ? l.saveChanges : l.save,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (isEditing) ...[
                      const SizedBox(height: _kRowGap),
                      OutlinedButton.icon(
                        icon: const ImageIcon(AppIcons.trash, size: 18),
                        style: OutlinedButton.styleFrom(
                          overlayColor: Colors.transparent,
                          minimumSize: const Size.fromHeight(kButtonHeight),
                          foregroundColor: Colors.white,
                          backgroundColor: kStrongRed,
                          side: BorderSide.none,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final l = AppLocalizations.of(context)!;
                          final ok = await confirmDeleteSheet(
                            context,
                            title: isExpense
                                ? l.deleteExpenseTitle
                                : l.deleteIncomeTitle,
                            message: isExpense
                                ? l.deleteExpenseConfirm
                                : l.deleteIncomeConfirm,
                          );
                          if (!context.mounted) return;

                          if (ok) {
                            final gid = _ensureGid(existing);
                            if (isExpense) {
                              await context
                                  .read<ExpenseProvider>()
                                  .deleteExpense(gid);
                            } else {
                              await context.read<IncomeProvider>().deleteIncome(
                                gid,
                              );
                            }
                            if (sheetCtx.mounted) {
                              Navigator.of(sheetCtx).pop();
                            }
                          }
                        },
                        label: InkText(AppLocalizations.of(context)!.delete),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    await showModalBottomSheet(
      context: hostContext,
      isScrollControlled: true,
      useSafeArea: false,
      isDismissible: true, // Allow tapping outside to dismiss
      enableDrag: true, // Allow dragging down to dismiss
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) =>
          KeyboardInset(child: sheet ??= buildSheet(sheetCtx)),
    );
    if (drafts) {
      saved
          ? SheetDrafts.saved('entry')
          : SheetDrafts.closed(
              settings,
              'entry',
              changed: anyChange(),
              values: {
                'kind': currentKind.index,
                'title': titleCtrl.text,
                'amount': amountCtrl.text,
                'note': noteCtrl.text,
                'date': pickedLocal,
                'category': selectedCategoryGid,
              },
            );
    }
    return saved;
  }

  static ButtonStyle _pickerButtonStyle(ColorScheme scheme) =>
      OutlinedButton.styleFrom(
        overlayColor: Colors.transparent,
        fixedSize: const Size.fromHeight(kButtonHeight),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        backgroundColor: scheme.surfaceContainerHigh,
        foregroundColor: scheme.onSurface,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

  static String _ensureGid(Map<String, dynamic> e) {
    final raw = e['gid'] ?? e['_id'];
    if (raw != null && raw.toString().isNotEmpty) return raw.toString();
    final dt = e['occurredAtUtc'];
    if (dt is DateTime) {
      return 'local_${dt.millisecondsSinceEpoch}_${e.hashCode}';
    }
    return 'local_${DateTime.now().millisecondsSinceEpoch}_${e.hashCode}';
  }
}

/// Expense/income category dropdown with a "manage categories" entry.
/// Also the Statistics per-category chart's picker ([only]).
class CategoryPickerButton extends StatefulWidget {
  final TransactionKind kind;
  final String initialCategoryGid;
  final ValueChanged<String> onChanged;
  final VoidCallback? onUserInteracted;

  /// Only these categories (in the categories' own order); null: all.
  final Set<String>? only;

  /// The "manage categories" entry at the end of the list.
  final bool showManage;

  const CategoryPickerButton({
    super.key,
    required this.kind,
    required this.initialCategoryGid,
    required this.onChanged,
    this.onUserInteracted,
    this.only,
    this.showManage = true,
  });

  @override
  State<CategoryPickerButton> createState() => _CategoryPickerButtonState();
}

class _CategoryPickerButtonState extends State<CategoryPickerButton> {
  late String selected;
  bool get _isExpense => widget.kind == TransactionKind.expense;
  String get _generalGid => fallbackCategoryGid(context, widget.kind);

  @override
  void initState() {
    super.initState();
    selected = widget.initialCategoryGid;
  }

  @override
  void didUpdateWidget(covariant CategoryPickerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategoryGid != widget.initialCategoryGid ||
        oldWidget.kind != widget.kind) {
      selected = widget.initialCategoryGid;
    }
  }

  // `listen` must stay false outside build (e.g. after awaiting a route),
  // otherwise Provider asserts.
  List<CategoryDto> _categories(BuildContext ctx, {bool listen = false}) {
    final all = _isExpense
        ? Provider.of<ExpenseProvider>(ctx, listen: listen).categories
        : Provider.of<IncomeProvider>(ctx, listen: listen).categories;
    final only = widget.only;
    return only == null ? all : [...all.where((c) => only.contains(c.gid))];
  }

  String _categoryName(BuildContext ctx, String? gid) => _isExpense
      ? ctx.read<ExpenseProvider>().categoryName(gid)
      : ctx.read<IncomeProvider>().categoryName(gid);

  Future<void> _goManageCategories(BuildContext ctx) async {
    final ep = ctx.read<ExpenseProvider>();
    final ip = ctx.read<IncomeProvider>();
    // What there was: one new category when back is the one chosen (the
    // owner, 2026-11-01; several: no guess).
    final before = {for (final c in _categories(ctx)) c.gid};
    await Navigator.of(ctx).push<bool>(
      MaterialPageRoute(
        // Its bar marks the tab the sheet was opened on.
        builder: (_) => CategoryTabsPage(
          initialIndex: _isExpense ? 0 : 1,
          navIndex: mainTab.value,
        ),
      ),
    );
    // The providers follow category writes on their own; this makes sure
    // both kinds are current before the picker checks its choice (the page
    // has both tabs). Left by a tab tap, the sheet is gone: nothing more.
    await Future.wait([ep.loadCategories(), ip.loadCategories()]);
    if (!ctx.mounted) return;

    final cats = _categories(ctx);
    if (cats.isEmpty) {
      setState(() {});
      return;
    }

    final added = [
      for (final c in cats)
        if (!before.contains(c.gid)) c.gid,
    ];
    if (added.length == 1) {
      setState(() => selected = added.single);
      widget.onChanged(added.single);
    } else if (!cats.any((c) => c.gid == selected)) {
      final idxGeneral = cats.indexWhere((c) => c.gid == _generalGid);
      final newSel = idxGeneral >= 0 ? cats[idxGeneral].gid : cats.first.gid;
      setState(() => selected = newSel);
      widget.onChanged(newSel);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final cats = _categories(context, listen: true);

    if (cats.isNotEmpty && !cats.any((c) => c.gid == selected)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final idxGeneral = cats.indexWhere((c) => c.gid == _generalGid);
        final newSel = idxGeneral >= 0 ? cats[idxGeneral].gid : cats.first.gid;
        setState(() => selected = newSel);
        widget.onChanged(newSel);
      });
    }

    // The chosen category's own color on the button (and each category's
    // on its row in the menu), text black or white to stay readable.
    Color on(Color bg) => onColor(bg);
    CategoryDto? chosen;
    for (final c in cats) {
      if (c.gid == selected) chosen = c;
    }
    final buttonBg = chosen == null
        ? scheme.surfaceContainerHigh
        : Color(chosen.color);
    // The menu lists the other categories: picking the shown one again is
    // a tap on the button, which closes the menu.
    final others = [...cats.where((c) => c.gid != selected)];
    final rows = others.length + (widget.showManage ? 1 : 0);
    // The chevron's ink (its image is as wide as it's drawn, 63% as tall)
    // sits as far from the button's end as from its top and bottom; the
    // category icon gets the same air at the start.
    const h = _AddEditTransactionSheet.kButtonHeight;
    const chevron = 14.0;
    const endAir = (h - chevron * .63) / 2;
    const iconSize = 20.0;
    const startAir = (h - iconSize * .83) / 2 - iconSize * .085;
    final style = OutlinedButton.styleFrom(
      overlayColor: Colors.transparent,
      fixedSize: const Size.fromHeight(h),
      padding: const EdgeInsetsDirectional.only(start: startAir, end: endAir),
      // Its corners square off at once as the menu opens (not over 200 ms),
      // and no splash under the menu.
      animationDuration: Duration.zero,
      splashFactory: NoSplash.splashFactory,
      backgroundColor: buttonBg,
      foregroundColor: chosen == null ? scheme.onSurface : on(buttonBg),
      side: BorderSide.none,
    );

    // General always exists, so only a filtered list (Statistics) can be
    // empty: nothing to pick then.
    if (cats.isEmpty) return const SizedBox.shrink();

    return JoinedMenu(
      rowCount: rows,
      // Room for a name on two lines.
      rowHeight: 52,
      rows: (close) => [
        for (final c in others)
          MenuItemButton(
            style: MenuItemButton.styleFrom(
              backgroundColor: Color(c.color),
              foregroundColor: on(Color(c.color)),
              iconColor: on(Color(c.color)),
              overlayColor: Colors.transparent,
            ),
            onPressed: () {
              setState(() => selected = c.gid);
              widget.onChanged(c.gid);
              close();
            },
            // Its icon, placed like the manage entry's.
            child: SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  CategoryIcon(
                    resolveCategoryIcon(c.iconCodePoint, c.iconFontFamily),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkText(
                      c.name,
                      maxLines: 2,
                      style: const TextStyle(height: 1.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (widget.showManage)
          MenuItemButton(
            // In the app's color among the categories' own: this one
            // manages the list, it isn't a category (and the settings
            // mark says so).
            style: MenuItemButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: context.textOnStrong,
              iconColor: context.textOnStrong,
              overlayColor: Colors.transparent,
            ),
            onPressed: () async {
              close();
              await _goManageCategories(context);
              if (!context.mounted) return;
              setState(() {});
            },
            child: Row(
              children: [
                const ImageIcon(AppIcons.cogwheel, size: 18),
                const SizedBox(width: 8),
                InkText(l.manageCategories),
              ],
            ),
          ),
      ],
      button: (ctx, radius, toggle) {
        return OutlinedButton(
          style: style.copyWith(
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: radius),
            ),
          ),
          // Opens on the first tap, at once. (It used to open "after the
          // next frame", and with the keyboard closed nothing drew one:
          // it took a second tap, or a cursor blink, to show up.)
          onPressed: () {
            widget.onUserInteracted?.call();
            toggle();
          },
          // Its icon, its name from the start, the chevron at the end.
          child: Row(
            children: [
              if (chosen != null) ...[
                CategoryIcon(
                  resolveCategoryIcon(
                    chosen.iconCodePoint,
                    chosen.iconFontFamily,
                  ),
                  size: iconSize,
                  color: on(buttonBg),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                // Never cut short: a long name takes a second line (the
                // button has room for two; names are at most
                // kCategoryNameMax long).
                child: InkText(
                  _categoryName(context, selected),
                  maxLines: 2,
                  textAlign: TextAlign.start,
                  style: const TextStyle(height: 1.15),
                ),
              ),
              const SizedBox(width: 8),
              const ImageIcon(AppIcons.chevronDown, size: chevron),
            ],
          ),
        );
      },
    );
  }
}

/// Due's titles, for the expense suggestions (none where Due isn't
/// provided, e.g. a test).
List<UpcomingSuggestion> _dueTitles(BuildContext context) {
  try {
    return context.read<UpcomingProvider>().history;
  } on ProviderNotFoundException {
    return const [];
  }
}
