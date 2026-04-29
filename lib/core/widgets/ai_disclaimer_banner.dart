import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_theme.dart';

/// Persistent legal banner pinned to the bottom of pages where the user
/// reads AI-generated content. The banner is purely informational -- it
/// does not gate input or scroll, so we keep its footprint to a single
/// padded row + icon + text.
///
/// The text key resolves to a localized string in the `legal.banner.*`
/// namespace, e.g. "I contenuti AI non sono consulenza finanziaria.
/// Decisioni e responsabilita' restano tue."
class AiDisclaimerBanner extends StatelessWidget {
  /// Tap callback -- typical use is to push the financial-disclaimer
  /// review screen so the user can re-read the full text.
  final VoidCallback? onTap;

  const AiDisclaimerBanner({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppTheme.warningColor;

    final content = Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border(
          top: BorderSide(color: color.withValues(alpha: 0.40)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 16.r),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'legal.banner.ai_disclaimer'.tr(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.textTheme.bodySmall?.color,
                height: 1.3,
              ),
            ),
          ),
          if (onTap != null) ...[
            SizedBox(width: 6.w),
            Icon(Icons.chevron_right, color: color, size: 16.r),
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}
