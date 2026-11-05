// lib/shared/ui/glitch_icon.dart
// An icon that glitches (the owner, 2026-11-03: About's bug): once, a random
// 700 to 2200 ms after it comes into view, then never again until it has been
// out of view and come back. Hard cuts, no easing: the icon torn into horizontal
// bands that slip sideways, a faint ghost behind, bits off its sides, a flicker.
// Each time different: how long it lasts, where it's worst, and its speed, which
// keeps running up and slowing down, with moments whole as if it were over
// ([glitchBeats]). The icon's own color only. Between glitches it's a plain
// [ImageIcon], costing nothing.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

/// How long after coming into view it glitches, at random between these.
const int kGlitchWaitMin = 700, kGlitchWaitMax = 2200;

/// How long it lasts, at random between these (ms).
const int kGlitchPlayMin = 500, kGlitchPlayMax = 800;

/// How long a moment of it holds, at random between these (ms): its speed. The
/// shortest is a frame or so.
const int kGlitchHoldMin = 16, kGlitchHoldMax = 45;

/// A moment of the glitch: how long it holds; how many bands the icon is torn
/// into (0: whole) and how far they slip; how far the ghost stands off; how
/// many bits fly off; how solid it all is. Distances are shares of the icon's
/// ink.
typedef GlitchBeat = ({
  int ms,
  int bands,
  double slip,
  double ghost,
  int bits,
  double alpha,
});

/// A moment with the icon whole.
GlitchBeat _whole(int ms) =>
    (ms: ms, bands: 0, slip: 0, ghost: 0, bits: 0, alpha: 1);

/// A moment of the glitch at [strength] (0 to 1).
GlitchBeat _torn(int ms, double strength, math.Random random) {
  final flicker = random.nextDouble();
  return (
    ms: ms,
    bands: 2 + (strength * 5).round(),
    slip: .04 + .18 * strength,
    ghost: strength < .3 ? 0 : .02 + .08 * strength,
    bits: (strength * 4).round(),
    alpha: strength > .45 && flicker < .25
        ? .55
        : (strength > .3 && flicker < .45 ? .85 : 1),
  );
}

/// One glitch: runs of moments, slowing down, then speeding up, by turns (both
/// in every glitch, however short), or a quick stutter once it has done both,
/// sometimes a moment whole between them; growing to its worst
/// at a random point and fading from there, each moment stronger or weaker at
/// random; a last small twitch. Lasts a random time, to the millisecond.
List<GlitchBeat> glitchBeats(math.Random random) {
  final total =
      kGlitchPlayMin + random.nextInt(kGlitchPlayMax - kGlitchPlayMin + 1);
  // A quick hold and a slow one, always far apart: picked anywhere in the range,
  // two could come out alike and the run would go at one even pace.
  double quick() => kGlitchHoldMin + random.nextDouble() * 8;
  double slow() => kGlitchHoldMax - random.nextDouble() * 8;

  const lastTwitch = 30;
  final worstAt = .25 + random.nextDouble() * .5;
  final beats = <GlitchBeat>[];
  var used = 0;
  // The time left for one of [ms], the last twitch kept (0: none left).
  int fit(int ms) {
    final left = total - lastTwitch - used;
    return left < kGlitchHoldMin ? 0 : math.min(ms, left);
  }

  var slowing = random.nextBool();
  var turns = 0;
  while (fit(kGlitchHoldMin) > 0) {
    // The first two short, so even the shortest glitch has room for both turns.
    final free = turns >= 2;
    final count = free ? 3 + random.nextInt(3) : 3;
    final stutter = free && random.nextDouble() < .25;
    final from = slowing ? quick() : slow(), to = slowing ? slow() : quick();
    if (!stutter) {
      slowing = !slowing;
      turns++;
    }
    for (var i = 0; i < count; i++) {
      final hold = stutter ? quick() : from + (to - from) * i / (count - 1);
      final ms = fit(hold.round());
      if (ms == 0) break;
      final at = used / total;
      final grown = at < worstAt ? at / worstAt : (1 - at) / (1 - worstAt);
      final strength = (.25 + .75 * grown) * (.45 + .55 * random.nextDouble());
      beats.add(_torn(ms, strength, random));
      used += ms;
    }
    if (free && random.nextDouble() < .45) {
      final ms = fit(15 + random.nextInt(30));
      if (ms > 0) {
        beats.add(_whole(ms));
        used += ms;
      }
    }
  }
  // Under a moment's time left: whole for it, then the twitch.
  final left = total - lastTwitch - used;
  if (left > 0) beats.add(_whole(left));
  beats.add(_torn(lastTwitch, .1, random));
  return beats;
}

/// How often it looks whether it's in view. Looking is next to nothing, and
/// sees everything alike: scrolling, a section opening, a tab or a page over it.
const Duration _kLookEvery = Duration(milliseconds: 150);

class GlitchIcon extends StatefulWidget {
  const GlitchIcon(
    this.image, {
    super.key,
    required this.size,
    required this.color,
    this.ink = 1,
  });

  final ImageProvider image;
  final double size;
  final Color color;

  /// How much of the file the icon's ink fills, centered: what the glitch tears
  /// and how far it reaches go by the ink, not the file's margins.
  final double ink;

  @override
  State<GlitchIcon> createState() => _GlitchIconState();
}

class _GlitchIconState extends State<GlitchIcon>
    with SingleTickerProviderStateMixin {
  static final _random = math.Random();

  late final AnimationController _play;
  final _beat = ValueNotifier<int>(0);
  bool _playing = false;
  int _seed = 0;
  List<GlitchBeat> _beats = const [];

  Timer? _look, _wait;
  bool _inView = false;

  /// What it looks with (read when they change: a timer can't depend on them).
  bool _active = true;
  ModalRoute<Object?>? _route;
  ScrollableState? _scrollable;
  Size _screen = Size.zero;
  EdgeInsets _insets = EdgeInsets.zero;

  ImageStream? _stream;
  ImageInfo? _image;
  late final _listener = ImageStreamListener((info, _) {
    _image?.dispose();
    _image = info;
  });

  @override
  void initState() {
    super.initState();
    _play = AnimationController(vsync: this)
      ..addListener(() {
        var at = _play.value * _play.duration!.inMilliseconds;
        var i = 0;
        while (i < _beats.length - 1 && at >= _beats[i].ms) {
          at -= _beats[i].ms;
          i++;
        }
        _beat.value = i;
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _playing = false);
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _active = TickerMode.valuesOf(context).enabled;
    _route = ModalRoute.of(context);
    _scrollable = Scrollable.maybeOf(context);
    _screen = MediaQuery.sizeOf(context);
    _insets = MediaQuery.paddingOf(context);
    _resolve();
    if (_active) {
      _look ??= Timer.periodic(_kLookEvery, (_) => _lookAround());
    } else {
      _look?.cancel();
      _look = null;
      _left();
    }
  }

  @override
  void didUpdateWidget(GlitchIcon old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image) _resolve();
  }

  void _resolve() {
    final stream = widget.image.resolve(
      createLocalImageConfiguration(context, size: Size.square(widget.size)),
    );
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  /// All of it on the screen and nothing over it: under the bottom bar or
  /// behind a sheet isn't in view.
  bool get _seen {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    if (_route != null && !_route!.isCurrent) return false;
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return false;
    final at = box.localToGlobal(Offset.zero) & box.size;
    var top = _insets.top, bottom = _screen.height - _insets.bottom;
    final view = _scrollable?.context.findRenderObject();
    if (view is RenderBox && view.attached && view.hasSize) {
      final area = view.localToGlobal(Offset.zero) & view.size;
      top = math.max(top, area.top);
      bottom = math.min(bottom, area.bottom);
    }
    return at.top >= top && at.bottom <= bottom;
  }

  void _lookAround() {
    if (!mounted) return;
    final seen = _seen;
    if (seen == _inView) return;
    if (!seen) return _left();
    _inView = true;
    final wait =
        kGlitchWaitMin + _random.nextInt(kGlitchWaitMax - kGlitchWaitMin + 1);
    _wait = Timer(Duration(milliseconds: wait), _start);
  }

  /// Out of view: the next time in, it may glitch again.
  void _left() {
    _inView = false;
    _wait?.cancel();
    _wait = null;
    if (_playing && mounted) {
      _play.stop();
      setState(() => _playing = false);
    }
  }

  void _start() {
    if (!mounted || _image == null) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    final beats = glitchBeats(_random);
    setState(() {
      _playing = true;
      _seed = _random.nextInt(1 << 30);
      _beats = beats;
    });
    _beat.value = 0;
    _play.duration = Duration(
      milliseconds: beats.fold<int>(0, (a, b) => a + b.ms),
    );
    _play.forward(from: 0);
  }

  @override
  void dispose() {
    _look?.cancel();
    _wait?.cancel();
    _stream?.removeListener(_listener);
    _image?.dispose();
    _play.dispose();
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_playing) {
      return ImageIcon(widget.image, size: widget.size, color: widget.color);
    }
    return SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(
        painter: GlitchPainter(
          image: _image!.image,
          color: widget.color,
          ink: widget.ink,
          beats: _beats,
          beat: _beat,
          seed: _seed,
        ),
      ),
    );
  }
}

/// A moment of the glitch ([beats], [beat] the one up). What it draws is decided
/// by [seed] and the beat alone: a beat holds still however many frames it's up
/// for.
class GlitchPainter extends CustomPainter {
  GlitchPainter({
    required this.image,
    required this.color,
    required this.beats,
    required this.beat,
    required this.seed,
    this.ink = 1,
  }) : super(repaint: beat);

  final ui.Image image;
  final Color color;
  final double ink;
  final List<GlitchBeat> beats;
  final ValueListenable<int> beat;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final b = beats[beat.value];
    final random = math.Random(seed * 31 + beat.value);
    final w = image.width.toDouble(), h = image.height.toDouble();
    final whole = Offset.zero & size;
    // The ink's width, and how far in from each side of the file it starts.
    final inkW = size.width * ink, inset = (1 - ink) / 2;

    // Hard edges: smoothed, the bands' meeting lines show as hairlines.
    Paint tinted(double alpha) => Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.medium
      ..colorFilter = ColorFilter.mode(
        color.withValues(alpha: color.a * alpha),
        BlendMode.srcIn,
      );

    if (b.bands == 0) {
      canvas.drawImageRect(image, Rect.fromLTWH(0, 0, w, h), whole, tinted(1));
      return;
    }

    if (b.ghost > 0) {
      final side = random.nextBool() ? 1 : -1;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, w, h),
        whole.shift(Offset(side * b.ghost * inkW, 0)),
        tinted(.35 * b.alpha),
      );
    }

    // The bands, across the ink: even ones with their cuts moved at random, none
    // too thin.
    final cuts = [
      0.0,
      for (var k = 1; k < b.bands; k++)
        inset + ink * (k + (random.nextDouble() - .5) * .7) / b.bands,
      1.0,
    ];

    // Every other band hardly moves, so it's still the icon being torn.
    final solid = tinted(b.alpha);
    for (var k = 0; k + 1 < cuts.length; k++) {
      final from = cuts[k], to = cuts[k + 1];
      final reach = b.slip * inkW * (k.isOdd ? .25 : 1);
      final slip = (random.nextDouble() * 2 - 1) * reach;
      canvas.drawImageRect(
        image,
        Rect.fromLTRB(0, from * h, w, to * h),
        Rect.fromLTRB(
          slip,
          from * size.height,
          size.width + slip,
          to * size.height,
        ),
        solid,
      );
    }

    // The bits, off the ink's sides but near enough to stay in its chip (a third
    // of the ink's width at most), some fainter.
    for (var k = 0; k < b.bits; k++) {
      final long = inkW * (.07 + random.nextDouble() * .13);
      final thick = inkW * (.03 + random.nextDouble() * .04);
      final off = inkW * (.02 + random.nextDouble() * .09);
      final left = size.width * inset, right = size.width - left;
      final x = random.nextBool() ? right + off : left - off - long;
      final y = size.height * (inset + ink * (.1 + random.nextDouble() * .8));
      canvas.drawRect(
        Rect.fromLTWH(x, y, long, thick),
        Paint()
          ..color = color.withValues(
            alpha: color.a * b.alpha * (random.nextBool() ? 1 : .5),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(GlitchPainter old) =>
      old.image != image ||
      old.color != color ||
      old.ink != ink ||
      old.beats != beats ||
      old.beat != beat ||
      old.seed != seed;
}
