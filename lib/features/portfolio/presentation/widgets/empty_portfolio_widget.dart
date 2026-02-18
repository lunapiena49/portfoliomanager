import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/app_constants.dart';

class EmptyPortfolioWidget extends StatelessWidget {
  const EmptyPortfolioWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(32.w),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 80.w,
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                ),
                SizedBox(height: 24.h),
                Text(
                  'portfolio.no_positions'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                Text(
                  'portfolio.empty_portfolio.description'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32.h),
                ElevatedButton.icon(
                  onPressed: () => context.push('${RouteNames.home}/import'),
                  icon: const Icon(Icons.upload_file),
                  label: Text('portfolio.import_portfolio'.tr()),
                ),
                SizedBox(height: 12.h),
                OutlinedButton.icon(
                  onPressed: () => context.push('${RouteNames.home}/create-portfolio'),
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: Text('portfolio.create_portfolio'.tr()),
                ),
                SizedBox(height: 16.h),
                TextButton.icon(
                  onPressed: () => context.push(RouteNames.guide),
                  icon: const Icon(Icons.help_outline),
                  label: Text('common.help'.tr()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
