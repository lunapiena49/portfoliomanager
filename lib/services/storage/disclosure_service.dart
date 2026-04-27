import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

/// Tracks the explicit, versioned consent the user has given to each
/// disclosure screen shown during onboarding.
///
/// Consents are persisted in [SharedPreferences] so the prompts are not
/// shown again on relaunch. The `_v1` suffix on each key is intentional:
/// if a future policy revision materially changes what the app does on
/// disk or on the network, bump the key version so returning users are
/// presented with the updated disclosure.
///
/// Storage layer: [SharedPreferences]
///   - Key: "privacy_disclosure_v1"    value: bool
///   - Key: "storage_disclosure_v1"    value: bool
///   - Key: "network_disclosure_v1"    value: bool
class DisclosureService {
  DisclosureService._();

  static SharedPreferences get _prefs {
    final instance = _cached;
    if (instance == null) {
      throw StateError(
        'DisclosureService.init() must be called before any accessor',
      );
    }
    return instance;
  }

  static SharedPreferences? _cached;

  /// Must be called during bootstrap, after [SharedPreferences] has been
  /// initialized by [LocalStorageService].
  static Future<void> init() async {
    _cached = await SharedPreferences.getInstance();
  }

  static bool isPrivacyAccepted() =>
      _prefs.getBool(AppConstants.privacyDisclosureAcceptedKey) ?? false;

  static bool isStorageAccepted() =>
      _prefs.getBool(AppConstants.storageDisclosureAcceptedKey) ?? false;

  static bool isNetworkAccepted() =>
      _prefs.getBool(AppConstants.networkDisclosureAcceptedKey) ?? false;

  /// True only when all three disclosures have been accepted in this or
  /// a prior session. Used as the gate for completing onboarding.
  static bool allAccepted() =>
      isPrivacyAccepted() && isStorageAccepted() && isNetworkAccepted();

  static Future<void> acceptPrivacy() async {
    await _prefs.setBool(AppConstants.privacyDisclosureAcceptedKey, true);
  }

  static Future<void> acceptStorage() async {
    await _prefs.setBool(AppConstants.storageDisclosureAcceptedKey, true);
  }

  static Future<void> acceptNetwork() async {
    await _prefs.setBool(AppConstants.networkDisclosureAcceptedKey, true);
  }

  /// Wipes all consent flags -- useful for the "Review onboarding" action
  /// in Settings.
  static Future<void> resetAll() async {
    await _prefs.remove(AppConstants.privacyDisclosureAcceptedKey);
    await _prefs.remove(AppConstants.storageDisclosureAcceptedKey);
    await _prefs.remove(AppConstants.networkDisclosureAcceptedKey);
  }
}
