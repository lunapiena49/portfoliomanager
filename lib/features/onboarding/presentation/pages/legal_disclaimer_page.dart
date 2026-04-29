import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/consent_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Financial disclaimer screen.
///
/// Shown:
///  * during onboarding before the user can land on home;
///  * from Settings > Legal documents (`reviewMode = true`) so the user
///    can re-read what they accepted.
///
/// Consent is recorded in [ConsentService] together with the document
/// version: bumping [_disclaimerVersion] causes the splash gate to ask
/// for re-consent on the next launch.
class LegalDisclaimerPage extends StatefulWidget {
  /// When true, the page is opened from Settings just to inspect the
  /// text. The CTA becomes a "back" button and no consent record is
  /// written.
  final bool reviewMode;

  const LegalDisclaimerPage({super.key, this.reviewMode = false});

  @override
  State<LegalDisclaimerPage> createState() => _LegalDisclaimerPageState();
}

class _LegalDisclaimerPageState extends State<LegalDisclaimerPage> {
  /// Bump when the legal text materially changes. The splash flow uses
  /// this to detect "user accepted v1 but we are now on v2" and force
  /// a re-consent screen.
  static const String _disclaimerVersion = '1.0.0';

  bool _notAdvice = false;
  bool _notFiduciary = false;
  bool _ownResponsibility = false;

  bool get _allChecked =>
      _notAdvice && _notFiduciary && _ownResponsibility;

  Future<void> _accept() async {
    if (!_allChecked) return;
    await ConsentService.record(
      document: ConsentDocument.financialDisclaimer,
      version: _disclaimerVersion,
      decision: ConsentDecision.accepted,
    );
    if (!mounted) return;
    if (widget.reviewMode) {
      Navigator.of(context).pop();
    } else {
      context.go(RouteNames.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: widget.reviewMode
          ? AppBar(
              title: Text('legal.disclaimer.title'.tr()),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Column(
            children: [
              if (!widget.reviewMode) ...[
                Container(
                  width: 88.w,
                  height: 88.w,
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.gavel,
                    size: 44.w,
                    color: AppTheme.warningColor,
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  'legal.disclaimer.title'.tr(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6.h),
                Text(
                  'legal.disclaimer.intro'.tr(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                SizedBox(height: 16.h),
              ],
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DisclaimerSection(
                        titleKey: 'legal.disclaimer.sections.no_advice.title',
                        bodyKey: 'legal.disclaimer.sections.no_advice.body',
                      ),
                      _DisclaimerSection(
                        titleKey: 'legal.disclaimer.sections.ai_warning.title',
                        bodyKey: 'legal.disclaimer.sections.ai_warning.body',
                      ),
                      _DisclaimerSection(
                        titleKey:
                            'legal.disclaimer.sections.no_fiduciary.title',
                        bodyKey: 'legal.disclaimer.sections.no_fiduciary.body',
                      ),
                      _DisclaimerSection(
                        titleKey: 'legal.disclaimer.sections.risk.title',
                        bodyKey: 'legal.disclaimer.sections.risk.body',
                      ),
                      SizedBox(height: 12.h),
                      _Checkbox(
                        labelKey:
                            'legal.disclaimer.checks.not_advice',
                        value: _notAdvice,
                        onChanged: (v) =>
                            setState(() => _notAdvice = v ?? false),
                      ),
                      _Checkbox(
                        labelKey:
                            'legal.disclaimer.checks.not_fiduciary',
                        value: _notFiduciary,
                        onChanged: (v) =>
                            setState(() => _notFiduciary = v ?? false),
                      ),
                      _Checkbox(
                        labelKey:
                            'legal.disclaimer.checks.own_responsibility',
                        value: _ownResponsibility,
                        onChanged: (v) =>
                            setState(() => _ownResponsibility = v ?? false),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: _allChecked ? _accept : null,
                  child: Text(
                    widget.reviewMode
                        ? 'common.done'.tr()
                        : 'legal.disclaimer.cta_accept'.tr(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisclaimerSection extends StatelessWidget {
  final String titleKey;
  final String bodyKey;

  const _DisclaimerSection({
    required this.titleKey,
    required this.bodyKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titleKey.tr(),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4.h),
          Text(
            bodyKey.tr(),
            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  final String labelKey;
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _Checkbox({
    required this.labelKey,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      controlAffinity: ListTileControlAffinity.leading,
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(
        labelKey.tr(),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
