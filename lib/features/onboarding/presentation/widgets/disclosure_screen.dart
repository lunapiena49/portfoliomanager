import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A single disclosure bullet: icon + title + optional description.
class DisclosureBullet {
  final IconData icon;
  final String titleKey;
  final String? descriptionKey;

  const DisclosureBullet({
    required this.icon,
    required this.titleKey,
    this.descriptionKey,
  });
}

/// Reusable onboarding screen that presents a privacy-related disclosure
/// and exposes an explicit "I understand and confirm" button.
///
/// The screen does not navigate on its own: when the user confirms, the
/// [onAccept] callback fires and the parent decides whether to advance
/// the PageView, mark the consent in [DisclosureService], etc.
///
/// When [accepted] is true the CTA flips to a disabled "confirmed" state
/// so the user can still scroll back through the flow and see what they
/// agreed to.
class DisclosureScreen extends StatelessWidget {
  final IconData headerIcon;
  final Color headerColor;
  final String titleKey;
  final String introKey;
  final List<DisclosureBullet> bullets;
  final String? footnoteKey;
  final String confirmLabelKey;
  final String confirmedLabelKey;
  final bool accepted;
  final VoidCallback onAccept;

  const DisclosureScreen({
    super.key,
    required this.headerIcon,
    required this.headerColor,
    required this.titleKey,
    required this.introKey,
    required this.bullets,
    required this.confirmLabelKey,
    required this.confirmedLabelKey,
    required this.accepted,
    required this.onAccept,
    this.footnoteKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallHeight = screenHeight < 700;
    final double iconSize = isSmallHeight ? 72.w : 92.w;
    final double iconInnerSize = isSmallHeight ? 36.w : 46.w;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: isSmallHeight ? 8.h : 16.h),
            Center(
              child: Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: headerColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  headerIcon,
                  size: iconInnerSize,
                  color: headerColor,
                ),
              ),
            ),
            SizedBox(height: isSmallHeight ? 16.h : 24.h),
            Text(
              titleKey.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              introKey.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            SizedBox(height: isSmallHeight ? 16.h : 24.h),
            ...bullets.map((b) => _BulletRow(bullet: b, accentColor: headerColor)),
            if (footnoteKey != null) ...[
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 18.w,
                        color: theme.textTheme.bodySmall?.color),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        footnoteKey!.tr(),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: isSmallHeight ? 16.h : 24.h),
            _ConfirmButton(
              accepted: accepted,
              accentColor: headerColor,
              labelKey: confirmLabelKey,
              acceptedLabelKey: confirmedLabelKey,
              onAccept: onAccept,
            ),
            SizedBox(height: isSmallHeight ? 16.h : 24.h),
          ],
        ),
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  final DisclosureBullet bullet;
  final Color accentColor;

  const _BulletRow({required this.bullet, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(bullet.icon, size: 18.w, color: accentColor),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bullet.titleKey.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (bullet.descriptionKey != null) ...[
                  SizedBox(height: 2.h),
                  Text(
                    bullet.descriptionKey!.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  final bool accepted;
  final Color accentColor;
  final String labelKey;
  final String acceptedLabelKey;
  final VoidCallback onAccept;

  const _ConfirmButton({
    required this.accepted,
    required this.accentColor,
    required this.labelKey,
    required this.acceptedLabelKey,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    if (accepted) {
      return SizedBox(
        width: double.infinity,
        height: 48.h,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: Icon(Icons.check_circle, color: accentColor),
          label: Text(acceptedLabelKey.tr()),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
            foregroundColor: accentColor,
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: ElevatedButton(
        onPressed: onAccept,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
        ),
        child: Text(labelKey.tr()),
      ),
    );
  }
}
