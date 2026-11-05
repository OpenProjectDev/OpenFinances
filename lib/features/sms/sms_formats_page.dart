// lib/features/sms/sms_formats_page.dart
// Settings > SMS formats: the bank message layouts the user defined (or
// said to ignore). Each can be edited (which way the money goes, the unit)
// or deleted (its messages are unknown again); none is added here: a
// format is defined from an unknown message in the SMS tab, so the bottom
// bar's "+" goes there, filtered to the unknown ones.

import 'package:openfinances/shared/calendar_text.dart' show isFaUi;
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/uicons.g.dart';
import 'package:flutter/material.dart';

import 'package:openfinances/app/app_bottom_bar.dart';
import 'package:openfinances/app/nav_icons.dart';
import 'package:openfinances/features/sms/bank_notifications.dart';
import 'package:openfinances/features/sms/sms_view.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/money_input.dart';
import 'package:openfinances/shared/ui/entry_fields.dart';
import 'package:openfinances/shared/ui/keyboard_inset.dart';
import 'package:openfinances/shared/ui/segmented_pills.dart';
import 'package:openfinances/shared/ui/swipe_row.dart';
import 'package:openfinances/shared/digits.dart';

class SmsFormatsPage extends StatefulWidget {
  const SmsFormatsPage({super.key, this.navIndex = 3});

  /// The bottom bar's tab this page belongs to (Settings).
  final int navIndex;

  @override
  State<SmsFormatsPage> createState() => _SmsFormatsPageState();
}

class _SmsFormatsPageState extends State<SmsFormatsPage> {
  List<BankFormatInfo>? _items;

  @override
  void initState() {
    super.initState();
    // Live: formats defined, renamed or forgotten anywhere show here at once.
    BankNotifications.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    BankNotifications.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final items = await BankNotifications.formats();
    if (mounted) setState(() => _items = items.reversed.toList());
  }

  String _kindLabel(AppLocalizations l, String kind) => switch (kind) {
    'income' => l.incomeTitle,
    'sign' => l.formatBySign,
    'ignore' => l.ignoredOne,
    _ => l.expenseShort,
  };

  Future<void> _edit(BankFormatInfo f) async {
    final res = await showModalBottomSheet<(String, String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => KeyboardInset(child: _FormatEditor(format: f)),
    );
    if (res == null) return;
    await BankNotifications.updateFormat(
      f.skeleton,
      name: res.$1,
      kind: res.$2,
      unit: res.$3,
    );
  }

  /// "+": formats are defined from an unknown message. (Asked before the
  /// jump, so the Expenses page's sub-tab change isn't taken for a place the
  /// user was.) Back brings this page back.
  void _add() {
    smsOpenRequest.value = kUnknown;
    goToMainTab(context, 0, reopen: _reopen);
  }

  Widget _reopen(BuildContext _) => SmsFormatsPage(navIndex: widget.navIndex);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final items = _items;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: InkText(l.smsFormats),
        leading: IconButton(
          icon: const Icon(UIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      bottomNavigationBar: AppBottomBar(
        selected: widget.navIndex,
        onTab: (i) => goToMainTab(context, i, reopen: _reopen),
        onAdd: _add,
        adds: AddSheet.smsFormat,
      ),
      // Under the Scaffold: its bottom padding includes the bar the list
      // runs under (the page's own context has only the system's), so the
      // last format can scroll clear of it.
      body: Builder(
        builder: (context) {
          final bottom = MediaQuery.paddingOf(context).bottom;
          return _list(context, items, bottom);
        },
      ),
    );
  }

  Widget _list(
    BuildContext context,
    List<BankFormatInfo>? items,
    double bottom,
  ) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final fa = isFaUi(context);
    return items == null
        ? const Center(child: CircularProgressIndicator())
        : items.isEmpty
        ? Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: Center(
              child: InkText(
                l.formatsEmpty,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          )
        : ListView.separated(
            padding: EdgeInsets.fromLTRB(12, 4, 12, bottom + 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final f = items[i];
              // An example message, else the layout itself (numbers as •).
              final sample = f.example ?? f.skeleton.replaceAll('#', '•••');
              return SwipeRow.editDelete(
                context: context,
                dismissKey: ValueKey('fmt_${f.skeleton.hashCode}'),
                radius: 14,
                confirmDelete: () => confirmDeleteSheet(
                  context,
                  title: l.deleteFormatTitle,
                  message: l.deleteFormatConfirm,
                ),
                onDelete: () => BankNotifications.deleteFormat(f.skeleton),
                onEdit: () => _edit(f),
                child: Material(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _edit(f),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: InkText(
                                  // Its name, else the bank that sent it.
                                  f.name.isNotEmpty
                                      ? f.name
                                      : (f.sender ?? '').isEmpty
                                      ? l.formatNoExample
                                      : f.sender!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              InkText(
                                faDigitsFor(fa)
                                    ? toFaDigits('${f.count}')
                                    : '${f.count}',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _Pill(_kindLabel(l, f.kind)),
                              const SizedBox(width: 8),
                              if (f.kind != 'ignore')
                                _Pill(
                                  f.unit == 'IRT'
                                      ? l.currencyToman
                                      : l.currencyRial,
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkText(
                              sample,
                              textDirection: RegExp(r'[؀-ۿ]').hasMatch(sample)
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.6,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        widthFactor: 1,
        child: InkText(
          text,
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Which way a format's amounts go (or that it's ignored) and their unit.
class _FormatEditor extends StatefulWidget {
  const _FormatEditor({required this.format});
  final BankFormatInfo format;

  @override
  State<_FormatEditor> createState() => _FormatEditorState();
}

class _FormatEditorState extends State<_FormatEditor> {
  late String _kind = widget.format.kind;
  late String _unit = widget.format.unit;
  late final _name = TextEditingController(text: widget.format.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final style = OutlinedButton.styleFrom(
      overlayColor: Colors.transparent,
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHigh,
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Its name (the sender's stands in while empty).
            InkField(
              controller: _name,
              hint: (widget.format.sender ?? '').isNotEmpty
                  ? widget.format.sender
                  : AppLocalizations.of(context)!.formatName,
              builder: (shown) => TextField(
                controller: _name,
                textAlign: Directionality.of(context) == TextDirection.rtl
                    ? TextAlign.right
                    : TextAlign.left,
                decoration: entryFieldDecoration(
                  context,
                  shown: shown,
                  suffixIcon: ClearWhenFilled(
                    controller: _name,
                    onClear: _name.clear,
                  ),
                ),
              ),
            ),
            const SizedBox(height: kSheetRowGap),
            SegmentedPills<String>(
              selected: _kind,
              onChanged: (k) => setState(() => _kind = k),
              options: {
                'expense': l.spentShort,
                'income': l.incomeTitle,
                // Only a layout whose amount carries its own +/-.
                if (widget.format.kind == 'sign') 'sign': l.formatBySign,
                'ignore': l.ignoredOne,
              },
            ),
            if (_kind != 'ignore') ...[
              const SizedBox(height: kSheetRowGap),
              SegmentedPills<String>(
                selected: _unit,
                onChanged: (u) => setState(() => _unit = u),
                options: {'IRT': l.currencyToman, 'IRR': l.currencyRial},
              ),
            ],
            const SizedBox(height: kSheetRowGap),
            Row(
              children: [
                Expanded(
                  child: ListenableBuilder(
                    listenable: _name,
                    builder: (context, _) {
                      final changed =
                          _name.text.trim() != widget.format.name.trim() ||
                          _kind != widget.format.kind ||
                          _unit != widget.format.unit;
                      return OutlinedButton(
                        style: saveButtonStyle(context, style, changed),
                        onPressed: changed
                            ? () => Navigator.of(
                                context,
                              ).pop((_name.text.trim(), _kind, _unit))
                            : null,
                        child: InkText(l.save),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: cancelButtonStyle(style),
                    onPressed: () => Navigator.of(context).pop(),
                    child: InkText(l.cancel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
