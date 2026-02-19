import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/onboarding_bloc.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _items = [
    OnboardingItem(
      icon: Icons.tune,
      titleKey: 'onboarding.features.setup.title',
      descriptionKey: 'onboarding.features.setup.description',
      color: AppTheme.primaryColor,
    ),
    OnboardingItem(
      icon: Icons.account_balance_wallet,
      titleKey: 'onboarding.features.import.title',
      descriptionKey: 'onboarding.features.import.description',
      color: AppTheme.primaryColor,
    ),
    OnboardingItem(
      icon: Icons.auto_awesome,
      titleKey: 'onboarding.features.analysis.title',
      descriptionKey: 'onboarding.features.analysis.description',
      color: AppTheme.accentColor,
    ),
    OnboardingItem(
      icon: Icons.trending_up,
      titleKey: 'onboarding.features.tracking.title',
      descriptionKey: 'onboarding.features.tracking.description',
      color: AppTheme.successColor,
    ),
    OnboardingItem(
      icon: Icons.flag,
      titleKey: 'onboarding.features.goals.title',
      descriptionKey: 'onboarding.features.goals.description',
      color: AppTheme.warningColor,
    ),
    OnboardingItem(
      icon: Icons.show_chart,
      titleKey: 'onboarding.features.market.title',
      descriptionKey: 'onboarding.features.market.description',
      color: AppTheme.successColor,
    ),
    OnboardingItem(
      icon: Icons.shield_outlined,
      titleKey: 'onboarding.features.security.title',
      descriptionKey: 'onboarding.features.security.description',
      color: AppTheme.accentColor,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() {
    if (_currentPage < _items.length - 1) {
      _pageController.nextPage(
        duration: AppConstants.animationDuration,
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() {
    context.read<OnboardingBloc>().add(CompleteOnboardingEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (state is OnboardingCompleted) {
          context.go(RouteNames.home);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
            // Top bar with back & skip
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _currentPage > 0
                        ? () {
                            _pageController.previousPage(
                              duration: AppConstants.animationDuration,
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                  ),
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: Text('common.skip'.tr()),
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'onboarding.welcome.title'.tr(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'onboarding.welcome.subtitle'.tr(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            // Page content takes remaining space
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  return _buildPage(_items[index]);
                },
              ),
            ),

            // Page indicator
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: SmoothPageIndicator(
                controller: _pageController,
                count: _items.length,
                effect: WormEffect(
                  dotColor: Theme.of(context).dividerColor,
                  activeDotColor: Theme.of(context).primaryColor,
                  dotHeight: 8.h,
                  dotWidth: 8.w,
                  spacing: 8.w,
                ),
              ),
            ),

            // Action buttons
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 24.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      child: Text(
                        _currentPage < _items.length - 1
                            ? 'common.next'.tr()
                            : 'onboarding.get_started'.tr(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildPage(OnboardingItem item) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isSmallHeight = screenHeight < 700;

    final double iconSize = isSmallHeight ? 96.w : 120.w;
    final double iconInnerSize = isSmallHeight ? 48.w : 60.w;
    final double titleSpacing = isSmallHeight ? 32.h : 48.h;
    final double descriptionSpacing = isSmallHeight ? 12.h : 16.h;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: isSmallHeight ? 16.h : 32.h),
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.icon,
                size: iconInnerSize,
                color: item.color,
              ),
            ),
            SizedBox(height: titleSpacing),
            Text(
              item.titleKey.tr(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: descriptionSpacing),
            Text(
              item.descriptionKey.tr(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isSmallHeight ? 24.h : 40.h),
          ],
        ),
      ),
    );
  }
}

class OnboardingItem {
  final IconData icon;
  final String titleKey;
  final String descriptionKey;
  final Color color;

  OnboardingItem({
    required this.icon,
    required this.titleKey,
    required this.descriptionKey,
    required this.color,
  });
}
