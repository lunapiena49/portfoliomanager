import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

/// Result of the boot-time device integrity probe.
///
/// `compromised` is intentionally permissive: any inconclusive answer
/// (plugin missing, platform exception, web build) maps to `false` so
/// false positives never lock the user out. The contract is "best-effort
/// hint" -- never a hard gate.
class IntegrityCheckResult {
  final bool compromised;
  final bool developerMode;
  final String? errorMessage;

  const IntegrityCheckResult({
    required this.compromised,
    required this.developerMode,
    this.errorMessage,
  });

  /// True when the device passed every check we ran.
  bool get isHealthy => !compromised && !developerMode;

  factory IntegrityCheckResult.healthy() => const IntegrityCheckResult(
        compromised: false,
        developerMode: false,
      );
}

/// Boot-time integrity probe.
///
/// Detects rooted Android devices (Magisk, SuperSU, common manager apps)
/// and jailbroken iOS devices (Cydia, modified system paths). Result is
/// a hint surfaced to the UI, NOT a hard kill switch:
///
///  * On a compromised device, the splash flow continues.
///  * The Settings page disables outbound AI/network calls until the
///    user explicitly acknowledges the warning.
///  * Hive encryption is unaffected (the cipher key still lives in the
///    OS keystore, which on rooted devices is the weakest link anyway).
///
/// Web and desktop fall through to a healthy result.
class IntegrityCheck {
  IntegrityCheck._();

  static IntegrityCheckResult? _cachedResult;

  /// Runs the probe and caches the result for the rest of the session.
  /// Subsequent calls return the cached value.
  static Future<IntegrityCheckResult> evaluate() async {
    final cached = _cachedResult;
    if (cached != null) return cached;

    if (kIsWeb) {
      _cachedResult = IntegrityCheckResult.healthy();
      return _cachedResult!;
    }

    try {
      final jailbroken = await FlutterJailbreakDetection.jailbroken;
      final devMode = await FlutterJailbreakDetection.developerMode;

      _cachedResult = IntegrityCheckResult(
        compromised: jailbroken,
        developerMode: devMode,
      );
    } catch (e) {
      // Plugin can throw on emulators or under unusual platform versions.
      // Treat as healthy so the user is never locked out by a probe bug.
      debugPrint('IntegrityCheck: probe failed: $e');
      _cachedResult = IntegrityCheckResult(
        compromised: false,
        developerMode: false,
        errorMessage: e.toString(),
      );
    }

    return _cachedResult!;
  }

  /// True when the cached probe says the device is compromised. Returns
  /// false when no probe has run yet -- callers must await [evaluate]
  /// during bootstrap before relying on this flag.
  static bool get isCompromised =>
      _cachedResult?.compromised ?? false;

  /// True when developer mode is on. UI can show a softer warning here:
  /// developer mode itself is not a security failure, but combined with
  /// USB debugging it widens the attack surface.
  static bool get isDeveloperMode =>
      _cachedResult?.developerMode ?? false;

  /// Test hook -- forces the cached result. Production code never calls
  /// this; tests use it to simulate a rooted device.
  static void overrideForTest(IntegrityCheckResult result) {
    _cachedResult = result;
  }

  /// Clear the cache. Tests only.
  static void resetForTests() {
    _cachedResult = null;
  }
}
