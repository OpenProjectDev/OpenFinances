// lib/shared/ui/swipe_row.dart
// The list rows' swipe gesture: swipe start→end to delete (after a confirm
// sheet), end→start to edit. Used by the History, Upcoming and Debts lists.

import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:openfinances/app/theme.dart';

import 'package:openfinances/l10n/generated/app_localizations.dart';

class SwipeAction {
  final Widget icon;
  final String label;
  final Color color;
  final Color onColor;
  const SwipeAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onColor,
  });
}

/// Swipeable row whose action panel only fills the strip the row has
/// uncovered (with its own rounded corners and a small gap), so nothing
/// peeks out behind the row's rounded corners.
class SwipeRow extends StatefulWidget {
  const SwipeRow({
    super.key,
    required this.dismissKey,
    required this.confirmDismiss,
    this.startAction,
    required this.endAction,
    required this.radius,
    required this.child,
  });

  final Key dismissKey;
  final ConfirmDismissCallback confirmDismiss;
  final SwipeAction? startAction; // swipe start→end (null: that way off)
  final SwipeAction endAction; // swipe end→start
  final double radius;
  final Widget child;

  /// The usual pair: swipe start→end deletes once [confirmDelete] says yes,
  /// end→start calls [onEdit]. The row itself never slides away.
  factory SwipeRow.editDelete({
    Key? key,
    required BuildContext context,
    required Key dismissKey,
    required double radius,
    required Future<bool> Function() confirmDelete,
    required Future<void> Function() onDelete,
    required VoidCallback onEdit,
    required Widget child,
  }) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return SwipeRow(
      key: key,
      dismissKey: dismissKey,
      radius: radius,
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          final ok = await confirmDelete();
          if (ok) await onDelete();
          return ok;
        }
        if (dir == DismissDirection.endToStart) onEdit();
        return false;
      },
      startAction: SwipeAction(
        icon: const ImageIcon(AppIcons.trash),
        label: l.delete,
        color: kStrongRed,
        onColor: Colors.white,
      ),
      endAction: SwipeAction(
        icon: const ImageIcon(AppIcons.edit),
        label: l.edit,
        color: scheme.secondaryContainer,
        onColor: scheme.onSecondaryContainer,
      ),
      child: child,
    );
  }

  @override
  State<SwipeRow> createState() => _SwipeRowState();
}

class _SwipeRowState extends State<SwipeRow> {
  static const double _gap = 8;
  double _progress = 0;

  Widget _panel(SwipeAction a, AlignmentDirectional align) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth * _progress - _gap;
        if (w <= 0) return const SizedBox.shrink();
        return Align(
          alignment: align,
          child: Container(
            width: w,
            decoration: BoxDecoration(
              color: a.color,
              borderRadius: BorderRadius.circular(widget.radius),
            ),
            alignment: Alignment.center,
            clipBehavior: Clip.hardEdge,
            child: w < 40
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconTheme.merge(
                        data: IconThemeData(color: a.onColor, size: 24),
                        child: a.icon,
                      ),
                      if (w > 110) ...[
                        const SizedBox(width: 8),
                        InkText(
                          a.label,
                          style: TextStyle(
                            color: a.onColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: widget.dismissKey,
      direction: widget.startAction == null
          ? DismissDirection.endToStart
          : DismissDirection.horizontal,
      confirmDismiss: widget.confirmDismiss,
      onUpdate: (d) {
        if ((d.progress - _progress).abs() > 0.002) {
          setState(() => _progress = d.progress);
        }
      },
      // One way only: [background] is that way's panel.
      background: widget.startAction == null
          ? _panel(widget.endAction, AlignmentDirectional.centerEnd)
          : _panel(widget.startAction!, AlignmentDirectional.centerStart),
      secondaryBackground: widget.startAction == null
          ? null
          : _panel(widget.endAction, AlignmentDirectional.centerEnd),
      child: widget.child,
    );
  }
}

/// Bottom sheet asking to confirm a delete; resolves to true on "Delete".
Future<bool> confirmDeleteSheet(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    builder: (_) => _ConfirmDeleteSheet(title: title, message: message),
  );
  return ok ?? false;
}

class _ConfirmDeleteSheet extends StatelessWidget {
  const _ConfirmDeleteSheet({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkText(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            InkText(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  // Not red: Delete next to it already is.
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      overlayColor: Colors.transparent,
                      side: BorderSide.none,
                      backgroundColor: scheme.surfaceContainerHigh,
                      foregroundColor: scheme.onSurface,
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: InkText(l.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      overlayColor: Colors.transparent,
                      backgroundColor: kStrongRed,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context, true),
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
  }
}
