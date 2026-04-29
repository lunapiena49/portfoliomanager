import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';

/// Settings > Legal documents.
///
/// Surfaces the user-visible reference URLs (Privacy Policy + Terms of
/// Service hosted on the public data repo) plus the in-app financial
/// disclaimer reachable via [RouteNames.legalDisclaimer]. Open Source
/// Licenses use the standard `showLicensePage` shipped by Flutter.
///
/// We deliberately keep the URLs as selectable text + copy button: the
/// app does not bundle `url_launcher` in v1.0 to keep the dependency
/// surface small, and Play Store policy still considers tap-to-clipboard
/// + Web disclosure acceptable for a personal finance utility.
class LegalDocumentsPage extends StatelessWidget {
  const LegalDocumentsPage({super.key});

  static const String _privacyUrl =
      '${AppConstants.marketSnapshotBaseUrl}/legal/it/privacy.html';
  static const String _termsUrl =
      '${AppConstants.marketSnapshotBaseUrl}/legal/it/terms.html';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('legal.documents.title'.tr()),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        children: [
          _LegalCard(
            icon: Icons.privacy_tip_outlined,
            titleKey: 'legal.documents.privacy.title',
            descriptionKey: 'legal.documents.privacy.description',
            url: _privacyUrl,
          ),
          _LegalCard(
            icon: Icons.description_outlined,
            titleKey: 'legal.documents.terms.title',
            descriptionKey: 'legal.documents.terms.description',
            url: _termsUrl,
          ),
          _ActionCard(
            icon: Icons.gavel,
            titleKey: 'legal.documents.disclaimer.title',
            descriptionKey: 'legal.documents.disclaimer.description',
            onTap: () => context.push(RouteNames.legalDisclaimer),
          ),
          _ActionCard(
            icon: Icons.menu_book_outlined,
            titleKey: 'legal.documents.licenses.title',
            descriptionKey: 'legal.documents.licenses.description',
            onTap: () => showLicensePage(
              context: context,
              applicationName: AppConstants.appName,
              applicationVersion: AppConstants.appVersion,
              applicationLegalese:
                  'legal.documents.licenses.legalese'.tr(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalCard extends StatelessWidget {
  final IconData icon;
  final String titleKey;
  final String descriptionKey;
  final String url;

  const _LegalCard({
    required this.icon,
    required this.titleKey,
    required this.descriptionKey,
    required this.url,
  });

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('legal.documents.url_copied'.tr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6.h),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    titleKey.tr(),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              descriptionKey.tr(),
              style: theme.textTheme.bodySmall,
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      url,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'legal.documents.copy'.tr(),
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => _copy(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String titleKey;
  final String descriptionKey;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.titleKey,
    required this.descriptionKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6.h),
      child: ListTile(
        leading: Icon(icon),
        title: Text(titleKey.tr()),
        subtitle: Text(descriptionKey.tr()),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
