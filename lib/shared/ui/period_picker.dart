import 'package:flutter/material.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/app_icons.dart';

/// Bumped when the app moves the period by itself (History's "See last
/// entry", the today chip): the period bar flashes to show it moved.
final ValueNotifier<int> periodJumped = ValueNotifier<int>(0);

/// The period bar used on Expenses, Budget and Statistics: prev / label /
/// next. Each arrow owns a full-height strip at its end of the bar (big tap
/// target), the middle opens the range list, and nothing ripples or
/// highlights on tap. When [flash] is bumped it pulses twice in the theme
/// color (no border: the app has none), so a jump it didn't see the user
/// make reads as a move.
class PeriodPicker extends StatefulWidget {
  const PeriodPicker({
    super.key,
    required this.label,
    required this.labelDirection,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
    required this.onOpenList,
    required this.prevTooltip,
    required this.nextTooltip,
    this.flash,
  });

  final String label;

  /// Jalali labels read RTL, Gregorian strictly LTR.
  final TextDirection labelDirection;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onOpenList;
  final String prevTooltip;
  final String nextTooltip;

  /// Bumped: the bar flashes (see [periodJumped]).
  final Listenable? flash;

  static const double height = 48;
  static const double _arrowZone = 64;

  @override
  State<PeriodPicker> createState() => _PeriodPickerState();
}

class _PeriodPickerState extends State<PeriodPicker>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void initState() {
    super.initState();
    widget.flash?.addListener(_flashNow);
  }

  @override
  void didUpdateWidget(PeriodPicker old) {
    super.didUpdateWidget(old);
    if (old.flash != widget.flash) {
      old.flash?.removeListener(_flashNow);
      widget.flash?.addListener(_flashNow);
    }
  }

  @override
  void dispose() {
    widget.flash?.removeListener(_flashNow);
    _pulse.dispose();
    super.dispose();
  }

  /// Two soft pulses (about a second).
  Future<void> _flashNow() async {
    try {
      for (var i = 0; i < 2; i++) {
        await _pulse.forward(from: 0).orCancel;
        await _pulse.reverse().orCancel;
      }
    } on TickerCanceled {
      // left the page
    }
  }

  @override
  Widget build(BuildContext context) {
    final PeriodPicker(
      :label,
      :labelDirection,
      :canPrev,
      :canNext,
      :onPrev,
      :onNext,
      :onOpenList,
      :prevTooltip,
      :nextTooltip,
    ) = widget;
    const height = PeriodPicker.height;
    final scheme = Theme.of(context).colorScheme;
    final textMain = scheme.onSurface;

    // The app's chevrons are images (they don't mirror themselves): prev
    // points to the start side, next to the end.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final toStart = rtl ? AppIcons.chevronRight : AppIcons.chevronLeft;
    final toEnd = rtl ? AppIcons.chevronLeft : AppIcons.chevronRight;

    Widget arrow(
      ImageProvider icon,
      String tooltip,
      bool enabled,
      VoidCallback f,
    ) {
      return Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? f : null,
          child: SizedBox(
            width: PeriodPicker._arrowZone,
            height: double.infinity,
            // Centered: a tight box would stretch the image.
            child: Center(
              child: ImageIcon(
                icon,
                size: 16,
                color: enabled ? textMain : textMain.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      );
    }

    // The bar's own tone, pulsed toward the theme color by a flash.
    final flashed = Color.alphaBlend(
      scheme.primary.withValues(alpha: .45),
      scheme.surfaceContainerHigh,
    );
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Container(
        height: height,
        decoration: BoxDecoration(
          color: Color.lerp(
            scheme.surfaceContainerHigh,
            flashed,
            Curves.easeInOut.transform(_pulse.value),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
      child: Row(
        children: [
          arrow(toStart, prevTooltip, canPrev, onPrev),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpenList,
              child: Center(
                child: Directionality(
                  textDirection: labelDirection,
                  child: InkText(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: textMain,
                    ),
                  ),
                ),
              ),
            ),
          ),
          arrow(toEnd, nextTooltip, canNext, onNext),
        ],
      ),
    );
  }
}
