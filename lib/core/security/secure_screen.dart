import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps a sensitive route to prevent screenshots, screen recording, and
/// USB/Cast mirroring while it is on top of the navigation stack.
///
/// Implementation notes:
///  * Android: invokes a method channel registered by [MainActivity] which
///    sets/clears `WindowManager.LayoutParams.FLAG_SECURE` on the activity
///    window. The flag affects the entire window, so concurrently visible
///    routes (modal sheets, dialogs) inherit the protection.
///  * iOS / web / desktop: no-op. iOS protection lands in Phase 2 with a
///    blur view in `applicationWillResignActive`; the v1.0 release ships
///    Android-only.
///
/// FLAG_SECURE is window-scoped, so wrapping a single page works only as
/// long as the page stays mounted. We toggle it ON in [initState] and OFF
/// in [dispose] to keep non-sensitive surfaces (Settings, market browser)
/// screenshot-able.
class SecureScreen extends StatefulWidget {
  final Widget child;

  /// Override the platform-channel target for tests (mockito-style).
  /// Production code never sets this.
  @visibleForTesting
  final MethodChannel? channelOverride;

  const SecureScreen({
    super.key,
    required this.child,
    this.channelOverride,
  });

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  static const MethodChannel _defaultChannel =
      MethodChannel('app.plurifin.portfoliomanager/secure_screen');

  MethodChannel get _channel => widget.channelOverride ?? _defaultChannel;

  bool _enabledOnce = false;

  @override
  void initState() {
    super.initState();
    _enable();
  }

  @override
  void dispose() {
    _disable();
    super.dispose();
  }

  Future<void> _enable() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<bool>('enable');
      _enabledOnce = true;
    } on PlatformException {
      // Silent: a missing handler must not crash the page. Worst case the
      // screen remains screenshot-able, which is the pre-2A.5 behavior.
    } on MissingPluginException {
      // Same rationale as PlatformException.
    }
  }

  Future<void> _disable() async {
    if (!_enabledOnce) return;
    try {
      await _channel.invokeMethod<bool>('disable');
    } on PlatformException {
      // Best-effort cleanup.
    } on MissingPluginException {
      // Best-effort cleanup.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
