// lib/shared/ui/app_notice.dart
// The app's one way to show a short message (instead of SnackBars, which
// hide behind bottom sheets and the keyboard). Sits at the bottom, above
// the keyboard and the nav bar, on the app's background; optional action
// chip (e.g. Undo) and a close square. It fades from the moment it shows:
// slowly at first, faster toward the end, so it's clear it's going.
// A success or a failure first shows its status where the close square
// will be (green with a check, red with "!"), which then turns into the
// close square: a red x alone read as "it failed".

import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/app_icons.dart';
import 'package:flutter/material.dart';

import 'package:openfinances/app/theme.dart';
import 'package:openfinances/shared/haptics.dart';

/// What a message reports: a success and a failure show their status
/// before the close square; a neutral one shows the close square at once.
enum NoticeKind { neutral, success, failure }

/// How long a message stays (all kinds alike).
const Duration kNoticeDuration = Duration(milliseconds: 6500);

/// How long a status shows before it turns into the close square, and how
/// long that turn takes.
const Duration _statusHold = Duration(milliseconds: 1500);
const Duration _statusTurn = Duration(milliseconds: 350);

/// The success status's green (the app's "saved" green).
const Color kSuccessGreen = Color(0xFF2E7D32);

class AppNotice {
  AppNotice._(this._overlay);
  final OverlayState _overlay;

  static OverlayEntry? _current;

  /// Grab before an `await` (like ScaffoldMessenger.of) when the calling
  /// widget may be gone by the time the message shows.
  static AppNotice of(BuildContext context) =>
      AppNotice._(Overlay.of(context, rootOverlay: true));

  /// Shows [message] (replacing one already showing). [actionLabel] +
  /// [onAction] add a chip; tapping it runs the action and closes.
  void show(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    NoticeKind kind = NoticeKind.neutral,
    Duration duration = kNoticeDuration,
  }) {
    dismiss();
    // Something went wrong: felt too.
    if (kind == NoticeKind.failure) Haptics.alert(_overlay.context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _NoticeView(
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
        kind: kind,
        duration: duration,
        onDone: () {
          if (_current == entry) dismiss();
        },
      ),
    );
    _current = entry;
    _overlay.insert(entry);
  }

  static void dismiss() {
    _current?.remove();
    _current = null;
  }
}

/// Shorthand for `AppNotice.of(context).show(...)`.
void showAppNotice(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  NoticeKind kind = NoticeKind.neutral,
  Duration duration = kNoticeDuration,
}) => AppNotice.of(context).show(
  message,
  actionLabel: actionLabel,
  onAction: onAction,
  kind: kind,
  duration: duration,
);

class _NoticeView extends StatefulWidget {
  const _NoticeView({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.kind,
    required this.duration,
    required this.onDone,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final NoticeKind kind;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_NoticeView> createState() => _NoticeViewState();
}

class _NoticeViewState extends State<_NoticeView>
    with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, duration: widget.duration)
    ..forward().whenComplete(() {
      if (mounted) widget.onDone();
    });

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  /// 0..1: the status turning into the close square (1 from the start
  /// for a neutral message).
  double get _turn {
    if (widget.kind == NoticeKind.neutral) return 1;
    final ms = _fade.value * widget.duration.inMilliseconds;
    return Curves.easeInOut.transform(
      ((ms - _statusHold.inMilliseconds) / _statusTurn.inMilliseconds).clamp(
        0.0,
        1.0,
      ),
    );
  }

  /// Around the notice's contents, on every side.
  static const double _inset = 10;

  /// The close square (and the status before it), and the action chip's
  /// height.
  static const double _square = 32;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // Above the keyboard when it's up, else above the bottom nav bar.
    final bottom = keyboard > 0
        ? keyboard + 12
        : MediaQuery.paddingOf(context).bottom + 64 + 12;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      // Starts fading very slowly and speeds up as time runs out (its
      // fading only: the notice isn't built or painted again for it).
      child: FadeTransition(
        opacity: _fade.drive(
          Tween(
            begin: 1.0,
            end: 0.0,
          ).chain(CurveTween(curve: Curves.easeInCubic)),
        ),
        child: RepaintBoundary(
          child: Material(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            elevation: 6,
            shadowColor: Colors.black,
            surfaceTintColor: Colors.transparent,
            child: Padding(
              // The same on every side (and on the reading side in RTL).
              padding: const EdgeInsets.all(_inset),
              child: Row(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        // The text's letters as far from its side as from
                        // the top and bottom: on one line they sit in the
                        // middle of the square's height, so the side gets the
                        // same air (measured from the letters' ink).
                        final style = textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                        );
                        final scaler = MediaQuery.textScalerOf(context);
                        final line = TextPainter(
                          text: TextSpan(text: widget.message, style: style),
                          textDirection: Directionality.of(context),
                          textScaler: scaler,
                          maxLines: 1,
                        )..layout(maxWidth: box.maxWidth);
                        final oneLine = !line.didExceedMaxLines;
                        final ink = style == null
                            ? null
                            : InkMetrics.instance.inkHeight(
                                widget.message,
                                style,
                                scaler,
                              );
                        // Several lines: the first line's letters sit
                        // within its line box; the side gets that air too.
                        final room = oneLine ? _square : line.height;
                        final extra = ((room - (ink ?? line.height)) / 2).clamp(
                          0.0,
                          12.0,
                        );
                        line.dispose();
                        return Padding(
                          padding: EdgeInsetsDirectional.only(start: extra),
                          child: InkText(widget.message, style: style),
                        );
                      },
                    ),
                  ),
                  if (widget.actionLabel != null) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        widget.onDone();
                        widget.onAction?.call();
                      },
                      child: Container(
                        height: _square,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: InkText(
                          widget.actionLabel!,
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.textOnStrong,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  // Close: the app's rounded red square with an x; a success
                  // or failure shows its status here first, then turns into it.
                  GestureDetector(
                    onTap: widget.onDone,
                    child: AnimatedBuilder(
                      animation: _fade,
                      builder: (context, _) {
                        final t = _turn;
                        final status = widget.kind == NoticeKind.success
                            ? kSuccessGreen
                            : kStrongRed;
                        Widget glyph(AssetImage icon, double size, double o) =>
                            Opacity(
                              opacity: o,
                              child: Center(
                                child: ImageIcon(
                                  icon,
                                  size: size,
                                  color: Colors.white,
                                ),
                              ),
                            );
                        return Container(
                          width: _square,
                          height: _square,
                          decoration: BoxDecoration(
                            color: Color.lerp(status, kStrongRed, t),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (t < 1)
                                glyph(
                                  widget.kind == NoticeKind.success
                                      ? AppIcons.check
                                      : AppIcons.danger,
                                  15,
                                  1 - t,
                                ),
                              if (t > 0) glyph(AppIcons.close, 13, t),
                            ],
                          ),
                        );
                      },
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
