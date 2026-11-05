import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Re-opens the soft keyboard when the user comes back to the app (from
/// recents, the notification shade, another app…) if it was open when
/// they left and a text field still has focus. Android hides the IME when
/// the window loses focus and Flutter doesn't bring it back on its own,
/// unlike native text fields.
class KeyboardRestorer extends StatefulWidget {
  const KeyboardRestorer({super.key, required this.child});
  final Widget child;

  @override
  State<KeyboardRestorer> createState() => _KeyboardRestorerState();
}

class _KeyboardRestorerState extends State<KeyboardRestorer>
    with WidgetsBindingObserver {
  bool _restoreOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        // Only ever SET here. Returning from Recents can be followed at once
        // by the biometric prompt (inactive again) before the keyboard came
        // back; that must not cancel the pending restore.
        if (_keyboardOpen() && _focusedTextNode() != null) {
          _restoreOnResume = true;
        }
      case AppLifecycleState.resumed:
        if (_restoreOnResume) _restore();
      default:
        break;
    }
  }

  static bool get _resumed =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  /// Fallback only: MainActivity re-shows the keyboard natively (and
  /// without the slide-in) as soon as the window regains focus. If that
  /// didn't happen, ask Flutter's text input to show it, then re-focus.
  /// Stays pending while the app isn't resumed (e.g. biometric prompt up).
  Future<void> _restore() async {
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted || !_resumed) return; // try again on the next resume
    if (_keyboardOpen() || _focusedTextNode() == null) {
      _restoreOnResume = false;
      return;
    }
    await SystemChannels.textInput.invokeMethod<void>('TextInput.show');

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted || !_resumed) return;
    _restoreOnResume = false;
    final node = _focusedTextNode();
    if (node == null || _keyboardOpen()) return;
    node.unfocus();
    node.requestFocus();
  }

  static bool _keyboardOpen() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    return views.isNotEmpty && views.first.viewInsets.bottom > 0;
  }

  /// The primary focus node, if it belongs to a text field.
  static FocusNode? _focusedTextNode() {
    final node = FocusManager.instance.primaryFocus;
    final ctx = node?.context;
    if (node == null || ctx == null || !ctx.mounted) return null;
    final isText =
        ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
    return isText ? node : null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
