// app/biometric_lock_gate.dart
import 'dart:async' show unawaited;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:openfinances/app/branding_screen.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import 'package:openfinances/data/settings_provider.dart';

/// When locked, shows only a heavy blur + scrim and triggers the system sheet.
/// Tap anywhere to retry if the user cancelled; leaving and coming back
/// asks again.
class BiometricLockGate extends StatefulWidget {
  const BiometricLockGate({
    super.key,
    required this.child,
    required this.enabled,
    required this.reason,
    this.allowDeviceCredential = true,
    this.gracePeriod = const Duration(seconds: 15),
    this.awayGrace = const Duration(minutes: 2),
    this.blurSigma = 28.0, // very blurred
    this.scrimAlpha = 0.35, // dim over blur
  });

  final Widget child;
  final bool enabled;
  final String reason;
  final bool allowDeviceCredential;
  final Duration gracePeriod;

  /// Away from the app for less than this (e.g. switching to the bank app
  /// to copy an amount), it doesn't lock on coming back.
  final Duration awayGrace;
  final double blurSigma;
  final double scrimAlpha;

  /// The last unlock, shared by every gate: a restart (e.g. after a
  /// restore) builds a new gate while the old one's prompt may still be up;
  /// its answer must reach the new one (it used to stay blurred until a
  /// tap and a second prompt).
  static final ValueNotifier<DateTime?> _unlockedAt = ValueNotifier(null);

  /// A prompt is up (from any gate): no second one over it.
  static bool _promptUp = false;

  /// The user is in the app right now (e.g. a restore is about to restart
  /// it): the next gate starts unlocked.
  static void trustNow() => _unlockedAt.value = DateTime.now();

  @override
  State<BiometricLockGate> createState() => _BiometricLockGateState();
}

class _BiometricLockGateState extends State<BiometricLockGate>
    with WidgetsBindingObserver {
  final _auth = LocalAuthentication();

  bool _supported = true;
  bool _locked = false;
  bool _authInProgress = false;

  bool _wasInBackground = false; // set only when not authenticating
  DateTime? _lastUnlockAt; // for grace period
  DateTime? _leftAt; // when the app was last left (not for the auth sheet)

  /// The app was left (Home, Recents) while locked. Android 10+ cancels
  /// an open prompt then as if the user cancelled it, so local_auth's
  /// sticky option never shows it again: coming back asks again instead
  /// of leaving a blur that needs a tap.
  bool _leftWhileLocked = false;
  DateTime? _resumedAt; // the last coming back, while a prompt was pending

  bool _withinGrace(DateTime? ts) {
    if (ts == null) return false;
    return DateTime.now().difference(ts) < widget.gracePeriod;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BiometricLockGate._unlockedAt.addListener(_unlockedElsewhere);
    _init();
  }

  /// The latest unlock: this gate's, another gate's, or Settings'.
  DateTime? get _latestUnlock {
    final shared = BiometricLockGate._unlockedAt.value;
    final settings = context.read<SettingsProvider>().lastBiometricAuthAt;
    if (shared == null) return settings;
    if (settings == null) return shared;
    return shared.isAfter(settings) ? shared : settings;
  }

  /// Another gate's prompt (or a restore) unlocked: so is this one.
  void _unlockedElsewhere() {
    final at = BiometricLockGate._unlockedAt.value;
    if (!mounted || !_locked || !_withinGrace(at)) return;
    _leftWhileLocked = false;
    setState(() {
      _locked = false;
      _lastUnlockAt = at;
    });
  }

  Future<void> _init() async {
    final supported = await _auth.isDeviceSupported();
    if (!mounted) return;
    setState(() => _supported = supported);

    if (widget.enabled && supported) {
      // Just unlocked (Settings, another gate, a restore): no prompt now.
      final externalLast = _latestUnlock;
      if (_withinGrace(externalLast)) {
        setState(() {
          _lastUnlockAt = externalLast;
          _locked = false;
        });
      } else {
        setState(() => _locked = true);
        // Not over the branding screen: once it starts leaving.
        await brandingOver.future;
        if (mounted) unawaited(_authenticate());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled || !_supported) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      // Not inactive: the prompt itself takes the focus, which is inactive.
      if (_locked && state != AppLifecycleState.inactive) {
        _leftWhileLocked = true;
      }
      if (!_authInProgress) {
        // Don't count the auth sheet; the first of these events is the
        // moment the user left.
        if (!_wasInBackground) _leftAt = DateTime.now();
        _wasInBackground = true;
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_wasInBackground && !_authInProgress) {
        final away = _leftAt == null
            ? widget.awayGrace
            : DateTime.now().difference(_leftAt!);
        final withinGrace =
            _withinGrace(_lastUnlockAt) || away < widget.awayGrace;
        if (!withinGrace) {
          setState(() => _locked = true);
          unawaited(_authenticate());
        }
      }
      _wasInBackground = false;
      if (_leftWhileLocked && _locked) {
        if (_authInProgress) {
          // Its answer may still be on the way: see _retryAfterLeaving.
          _resumedAt = DateTime.now();
        } else {
          _leftWhileLocked = false;
          unawaited(_authenticate());
        }
      }
    }
  }

  Future<void> _authenticate() async {
    if (!mounted || !_locked || _authInProgress) return;
    // Another gate's prompt is up: its answer reaches this one too.
    if (BiometricLockGate._promptUp) return;
    BiometricLockGate._promptUp = true;
    setState(() => _authInProgress = true);

    try {
      final ok = await _auth.authenticate(
        localizedReason: widget.reason,
        biometricOnly: !widget.allowDeviceCredential,
        persistAcrossBackgrounding: true, // was stickyAuth
        sensitiveTransaction: true,
      );
      BiometricLockGate._promptUp = false;
      // Shared first: if this gate was replaced meanwhile, the new one
      // unlocks from it.
      if (ok) BiometricLockGate._unlockedAt.value = DateTime.now();
      if (!mounted) return;
      setState(() {
        _locked = !ok;
        _authInProgress = false;
        if (ok) _lastUnlockAt = DateTime.now();
      });
      if (ok) {
        _leftWhileLocked = false;
        _resumedAt = null;
      } else {
        _retryAfterLeaving();
      }
    } catch (_) {
      BiometricLockGate._promptUp = false;
      if (!mounted) return;
      setState(() => _authInProgress = false); // remain locked; tap to retry
      _retryAfterLeaving();
    }
  }

  /// A prompt failed. Cancelled by leaving the app: still away, coming back
  /// asks again (didChangeAppLifecycleState); already back, ask now. A
  /// cancel well after coming back is the user's: the blur stays, tap to
  /// retry.
  void _retryAfterLeaving() {
    final back =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (!_leftWhileLocked || !back) return;
    _leftWhileLocked = false;
    final at = _resumedAt;
    _resumedAt = null;
    if (at != null && DateTime.now().difference(at) < _lateAnswer) {
      unawaited(_authenticate());
    }
  }

  static const _lateAnswer = Duration(seconds: 2);

  @override
  void didUpdateWidget(covariant BiometricLockGate oldWidget) {
    super.didUpdateWidget(oldWidget);

    // OFF -> ON (also: the settings loading after a restart): only prompt
    // if nothing just unlocked.
    if (widget.enabled && !oldWidget.enabled && _supported) {
      final externalLast = _latestUnlock;
      if (_withinGrace(externalLast)) {
        setState(() {
          _lastUnlockAt = externalLast;
          _locked = false; // skip second prompt
        });
      } else {
        setState(() => _locked = true);
        unawaited(_authenticate());
      }
    }

    // ON -> OFF: unlock immediately
    if (!widget.enabled && oldWidget.enabled) {
      setState(() => _locked = false);
    }
  }

  @override
  void dispose() {
    BiometricLockGate._unlockedAt.removeListener(_unlockedElsewhere);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Merge any later Settings auth into our grace window.
    final externalLast = context.select<SettingsProvider, DateTime?>(
      (sp) => sp.lastBiometricAuthAt,
    );
    if (externalLast != null &&
        (_lastUnlockAt == null || externalLast.isAfter(_lastUnlockAt!))) {
      _lastUnlockAt = externalLast;
    }

    final showLock = widget.enabled && _supported && _locked;
    final cs = Theme.of(context).colorScheme;

    // Always the same Stack shape, child first: returning a bare child when
    // unlocked used to change the tree's shape on every lock/unlock, which
    // recreated everything below (lost tab, open sheets, text focus).
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        // 🔒 Heavy blur + scrim; blocks touches; tap to retry auth
        if (showLock)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!_authInProgress) unawaited(_authenticate());
            },
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: widget.blurSigma,
                  sigmaY: widget.blurSigma,
                ),
                child: ColoredBox(
                  color: cs.surface.withValues(alpha: widget.scrimAlpha),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
