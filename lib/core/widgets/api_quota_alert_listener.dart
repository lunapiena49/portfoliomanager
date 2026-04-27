import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../services/api/api_quota_alert_service.dart';

/// Root listener that converts [ApiQuotaAlertService] events into user-facing
/// material banners.
///
/// Why a banner and not a snackbar: quota / invalid-key states are sticky
/// problems -- the user needs to act (rotate key, wait, upgrade plan), and a
/// snackbar that auto-dismisses in 3s is too easy to miss.
///
/// Coalescing: rapid bursts of the same `(provider, reason)` are deduped on
/// a 60s window so a thrashing service does not spam banners.
///
/// Wiring: pass [messengerKey] into both this widget AND
/// `MaterialApp.scaffoldMessengerKey` so the banner attaches to the same
/// messenger that page-level Scaffolds use.
class ApiQuotaAlertListener extends StatefulWidget {
  const ApiQuotaAlertListener({
    super.key,
    required this.messengerKey,
    required this.child,
  });

  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final Widget child;

  @override
  State<ApiQuotaAlertListener> createState() => _ApiQuotaAlertListenerState();
}

class _ApiQuotaAlertListenerState extends State<ApiQuotaAlertListener> {
  static const Duration _coalesceWindow = Duration(seconds: 60);
  static const Duration _bannerLifetime = Duration(seconds: 12);

  StreamSubscription<ApiQuotaEvent>? _sub;
  final Map<String, DateTime> _lastEmitted = {};

  @override
  void initState() {
    super.initState();
    _sub = ApiQuotaAlertService.instance.stream.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(ApiQuotaEvent event) {
    final key = '${event.provider.id}::${event.reason.name}';
    final now = DateTime.now();
    final last = _lastEmitted[key];
    if (last != null && now.difference(last) < _coalesceWindow) {
      return;
    }
    _lastEmitted[key] = now;

    final messenger = widget.messengerKey.currentState;
    if (messenger == null) return;

    final providerLabel = _resolveProviderLabel(event.provider);
    final title = _resolveReasonTitle(event.reason);
    final body = _resolveReasonBody(event.reason, providerLabel);

    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: _backgroundFor(event.reason),
          leading: Icon(
            _iconFor(event.reason),
            color: Colors.white,
          ),
          content: Text(
            '$title\n$body',
            style: const TextStyle(color: Colors.white, height: 1.3),
          ),
          actions: [
            TextButton(
              onPressed: () => messenger.hideCurrentMaterialBanner(),
              child: Text(
                'common.dismiss'.tr(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

    Future.delayed(_bannerLifetime, () {
      if (!mounted) return;
      widget.messengerKey.currentState?.hideCurrentMaterialBanner();
    });
  }

  String _resolveProviderLabel(ApiQuotaProvider provider) {
    final key = 'api_quota.providers.${provider.id}';
    final translated = key.tr();
    if (translated.isNotEmpty && translated != key) return translated;
    return provider.displayName;
  }

  String _resolveReasonTitle(ApiQuotaReason reason) {
    switch (reason) {
      case ApiQuotaReason.rateLimit:
        return 'api_quota.rate_limit.title'.tr();
      case ApiQuotaReason.quotaExceeded:
        return 'api_quota.quota_exceeded.title'.tr();
      case ApiQuotaReason.invalidKey:
        return 'api_quota.invalid_key.title'.tr();
    }
  }

  String _resolveReasonBody(ApiQuotaReason reason, String providerLabel) {
    final args = {'provider': providerLabel};
    switch (reason) {
      case ApiQuotaReason.rateLimit:
        return 'api_quota.rate_limit.body'.tr(namedArgs: args);
      case ApiQuotaReason.quotaExceeded:
        return 'api_quota.quota_exceeded.body'.tr(namedArgs: args);
      case ApiQuotaReason.invalidKey:
        return 'api_quota.invalid_key.body'.tr(namedArgs: args);
    }
  }

  Color _backgroundFor(ApiQuotaReason reason) {
    switch (reason) {
      case ApiQuotaReason.rateLimit:
        return const Color(0xFFD97706);
      case ApiQuotaReason.quotaExceeded:
        return const Color(0xFFB91C1C);
      case ApiQuotaReason.invalidKey:
        return const Color(0xFF7C2D12);
    }
  }

  IconData _iconFor(ApiQuotaReason reason) {
    switch (reason) {
      case ApiQuotaReason.rateLimit:
        return Icons.timelapse;
      case ApiQuotaReason.quotaExceeded:
        return Icons.warning_amber;
      case ApiQuotaReason.invalidKey:
        return Icons.vpn_key_off;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
