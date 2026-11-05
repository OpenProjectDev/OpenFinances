// lib/app/branding_screen.dart
// The moment after the native splash. The splash shows the mark alone, as
// big as Android 12+ lets it (it clips the splash's picture to a 192 dp
// circle), rendered from [BrandMark] itself (tool/brand/render_brand_test
// .dart), so the first frame here is the same picture and the hand-over
// can't be seen. Then, quickly, the mark (its size kept) rises to make
// room, "OpenFinances" comes in under it, then "An OpenProject app", both
// the same way (rising a little as they fade in), and the app takes over.
// Shown once per launch, over everything, while the app builds underneath.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openfinances/app/brand_mark.dart';
import 'package:openfinances/app/initial_setup.dart';
import 'package:openfinances/app/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Completes when the branding screen starts leaving (or isn't shown):
/// the biometric prompt waits for it, so it doesn't come up over the mark.
final Completer<void> brandingOver = Completer<void>();

/// The splash's and the branding screen's background (the app's own).
const Color kSplashBg = kAppBg;

/// The lockup's font, whatever font the app is set to (the brand's).
const String _brandFont = 'Manrope';

/// The subline's grey.
const Color _muted = Color(0xFF757677);

/// "OpenFinances" as the brand writes it: Manrope, "Open" in [openColor]
/// (white on the dark branding screen), "Finances" in the brand blue. Plain
/// [Text], no text scaling (Settings' header shows it too).
class BrandName extends StatelessWidget {
  const BrandName({
    super.key,
    this.size = BrandLockup.kNameSize,
    this.openColor = Colors.white,
  });

  final double size;
  final Color openColor;

  /// The brand's text style at [size].
  static TextStyle style(double size, FontWeight weight, Color color) =>
      TextStyle(
        fontFamily: _brandFont,
        fontFamilyFallback: const [],
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.2,
        decoration: TextDecoration.none,
      );

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      style: style(size, FontWeight.w600, openColor),
      children: const [
        TextSpan(text: 'Open'),
        TextSpan(
          text: 'Finances',
          style: TextStyle(color: kBrandBlue),
        ),
      ],
    ),
    textScaler: TextScaler.noScaling,
    textDirection: TextDirection.ltr,
  );
}

/// The mark, "OpenFinances" under it and "An OpenProject app" under that,
/// all sized by [scale] (1: as designed). [name] and [subline] (0..1) bring
/// their lines in: each fades in while rising [kRise] into place; the mark
/// and the lines' places don't move with them. [sublineOpacity] fades the
/// subline out where it is (the introduction, as the lockup moves up).
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.scale = 1,
    this.name = 1,
    this.subline = 1,
    this.sublineOpacity = 1,
  });

  final double scale, name, subline, sublineOpacity;

  /// The mark (the splash shows it alone: the most a rounded square of its
  /// corners can be inside Android's 192 dp circle, a little to spare), the
  /// gap under it, the name, the gap under that, the subline (dp).
  static const double kMark = 152,
      kGap = 18,
      kNameSize = 30,
      kSublineGap = 8,
      kSublineSize = 14;

  /// How far a line rises as it comes in.
  static const double kRise = 10;

  /// The whole lockup's height at [scale].
  static double height(double scale) =>
      (kMark + kGap + kNameSize * 1.2 + kSublineGap + kSublineSize * 1.2) *
      scale;

  @override
  Widget build(BuildContext context) {
    Widget enter(double t, Widget child) => Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, (1 - t) * kRise * scale),
        child: child,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: kMark * scale),
        SizedBox(height: kGap * scale),
        enter(name, BrandName(size: kNameSize * scale)),
        SizedBox(height: kSublineGap * scale),
        Opacity(
          opacity: sublineOpacity,
          child: enter(
            subline,
            Text(
              'An OpenProject app',
              textScaler: TextScaler.noScaling,
              textDirection: TextDirection.ltr,
              style: BrandName.style(
                kSublineSize * scale,
                FontWeight.w500,
                _muted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Where the lockup ends up on the branding screen (its top and middle
/// across, on the whole screen, and its scale): the first launch's
/// introduction starts with it drawn right there.
typedef LockupPlace = ({double top, double middle, double scale});

/// Over the app (MaterialApp's builder): the branding screen, then nothing.
/// On the very first launch it doesn't fade out: the introduction
/// (initial_setup.dart) is under it, showing the same picture, and takes
/// over from it.
class BrandingOverlay extends StatefulWidget {
  const BrandingOverlay({super.key});

  /// The lockup's final place, once the branding screen has laid it out.
  static LockupPlace? place;

  /// The lockup's final place on a [screen] when there was no branding
  /// screen to take it from (designed size, centered).
  static LockupPlace designedPlace(Size screen) => (
    top: (screen.height - BrandLockup.height(1)) / 2,
    middle: screen.width / 2,
    scale: 1,
  );

  @override
  State<BrandingOverlay> createState() => _BrandingOverlayState();
}

class _BrandingOverlayState extends State<BrandingOverlay>
    with SingleTickerProviderStateMixin {
  /// Once per launch: a restart from a restore doesn't show it again.
  static bool _shown = false;

  static const _app = MethodChannel('openfinances/app');

  // The timeline (ms), from when the native splash is gone: the mark rises
  // 0-300; the name comes in 80-340, the subline 260-520 (the same way);
  // held until 1300, then the app fades in over 200.
  static const _hold = 1300, _out = 200, _total = _hold + _out;

  /// The very first launch (before the language is chosen) plays the
  /// timeline this many times slower: the brand gets a proper moment once.
  static const _firstLaunchPace = 3;

  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _total),
  );
  bool _done = _shown;

  /// The first launch: slower, and handed over to the introduction.
  bool _firstLaunch = false;

  /// Where the native splash drew the plate (logical px), once known; null
  /// until then, or when there's none to match (older Android: its splash
  /// is the picture at its designed size, in the middle).
  Rect? _plate;

  @override
  void initState() {
    super.initState();
    if (_done) {
      if (!brandingOver.isCompleted) brandingOver.complete();
      return;
    }
    _shown = true;
    _t.addListener(_tick);
    _matchSplash();
  }

  /// Asks Android where the splash's plate is, draws the lockup right
  /// there, and only then lets the splash go and starts moving.
  Future<void> _matchSplash() async {
    Map<Object?, Object?>? at;
    try {
      at = await _app
          .invokeMethod<Map<Object?, Object?>>('splashPlate')
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {
      at = null; // no splash to match (or no answer): the designed place
    }
    // The first launch: slower (the prefs are loaded already, by now).
    try {
      if (!onboardingDone(await SharedPreferences.getInstance())) {
        _firstLaunch = true;
        _t.duration = _t.duration! * _firstLaunchPace;
      }
    } catch (_) {}
    if (!mounted) return;
    final ratio = View.of(context).devicePixelRatio;
    double v(String k) => ((at?[k] as num?) ?? 0).toDouble() / ratio;
    setState(() {
      _plate = at == null
          ? null
          // Square: its width is sure (its bottom rows can blur away).
          : Rect.fromLTWH(v('l'), v('t'), v('w'), v('w'));
    });
    // Drawn where the splash is: now it can go, and this can move.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _app.invokeMethod<void>('splashDone');
      } catch (_) {}
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        // No motion: the final picture at once, held, then gone.
        _t.value = 600 / _total;
        Future<void>.delayed(const Duration(milliseconds: 700), _finish);
      } else {
        _t.forward();
      }
    });
  }

  void _tick() {
    if (_t.value * _total >= _hold && !brandingOver.isCompleted) {
      brandingOver.complete();
      // The introduction under it shows the same picture: no fade.
      if (_firstLaunch) _finish();
    }
    if (_t.isCompleted) _finish();
  }

  void _finish() {
    if (!mounted || _done) return;
    if (!brandingOver.isCompleted) brandingOver.complete();
    setState(() => _done = true);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  /// 0..1 over [from, to] ms of the timeline, eased.
  double _span(int from, int to, [Curve curve = Curves.easeOutCubic]) => curve
      .transform(((_t.value * _total - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    if (_done) return const SizedBox.shrink();
    final screen = MediaQuery.sizeOf(context);
    // The lockup's size: the mark as Android drew it (else as designed);
    // the lines keep their size to it.
    final scale = (_plate?.width ?? BrandLockup.kMark) / BrandLockup.kMark;
    // Where the mark's top starts (the splash's, or the middle) and ends
    // (the three lines centered together); and its middle across.
    final startTop =
        _plate?.top ?? (screen.height - BrandLockup.kMark * scale) / 2;
    final endTop = (screen.height - BrandLockup.height(scale)) / 2;
    final middle = _plate?.center.dx ?? screen.width / 2;
    BrandingOverlay.place = (top: endTop, middle: middle, scale: scale);
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final leaving = 1 - _span(_hold, _total, Curves.easeOut);
        final top = startTop + (endTop - startTop) * _span(0, 300);
        return IgnorePointer(
          ignoring: leaving < 1,
          child: Opacity(
            opacity: leaving,
            child: ColoredBox(
              color: kSplashBg,
              // At the designed place until the splash says where it
              // drew (on Android 12+ this is under the splash till then).
              child: Stack(
                children: [
                  Positioned(
                    top: top,
                    left: middle - 200,
                    width: 400,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: BrandLockup(
                        scale: scale,
                        name: _span(80, 340),
                        subline: _span(260, 520),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
