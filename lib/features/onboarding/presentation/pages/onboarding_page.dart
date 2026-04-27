import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/storage/disclosure_service.dart';
import '../bloc/onboarding_bloc.dart';
import '../widgets/disclosure_screen.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final List<_OnboardingStep> _steps;

  bool _privacyAccepted = false;
  bool _storageAccepted = false;
  bool _networkAccepted = false;

  @override
  void initState() {
    super.initState();
    _privacyAccepted = DisclosureService.isPrivacyAccepted();
    _storageAccepted = DisclosureService.isStorageAccepted();
    _networkAccepted = DisclosureService.isNetworkAccepted();

    _steps = [
      _FeatureStep(
        icon: Icons.tune,
        titleKey: 'onboarding.features.setup.title',
        descriptionKey: 'onboarding.features.setup.description',
        color: AppTheme.primaryColor,
      ),
      _FeatureStep(
        icon: Icons.account_balance_wallet,
        titleKey: 'onboarding.features.import.title',
        descriptionKey: 'onboarding.features.import.description',
        color: AppTheme.primaryColor,
      ),
      _FeatureStep(
        icon: Icons.auto_awesome,
        titleKey: 'onboarding.features.analysis.title',
        descriptionKey: 'onboarding.features.analysis.description',
        color: AppTheme.accentColor,
      ),
      _FeatureStep(
        icon: Icons.trending_up,
        titleKey: 'onboarding.features.tracking.title',
        descriptionKey: 'onboarding.features.tracking.description',
        color: AppTheme.successColor,
      ),
      _FeatureStep(
        icon: Icons.flag,
        titleKey: 'onboarding.features.goals.title',
        descriptionKey: 'onboarding.features.goals.description',
        color: AppTheme.warningColor,
      ),
      _FeatureStep(
        icon: Icons.show_chart,
        titleKey: 'onboarding.features.market.title',
        descriptionKey: 'onboarding.features.market.description',
        color: AppTheme.successColor,
      ),
      _PrivacyDisclosureStep(color: AppTheme.accentColor),
      _StorageDisclosureStep(color: AppTheme.primaryColor),
      _NetworkDisclosureStep(color: AppTheme.successColor),
      _FeatureStep(
        icon: Icons.shield_outlined,
        titleKey: 'onboarding.features.security.title',
        descriptionKey: 'onboarding.features.security.description',
        color: AppTheme.accentColor,
      ),
    ];
  }

  bool get _allDisclosuresAccepted =>
      _privacyAccepted && _storageAccepted && _networkAccepted;

  bool _stepBlocksProgress(_OnboardingStep step) {
    if (step is _PrivacyDisclosureStep && !_privacyAccepted) return true;
    if (step is _StorageDisclosureStep && !_storageAccepted) return true;
    if (step is _NetworkDisclosureStep && !_networkAccepted) return true;
    return false;
  }

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

  Future<void> _acceptPrivacy() async {
    await DisclosureService.acceptPrivacy();
    if (!mounted) return;
    setState(() => _privacyAccepted = true);
  }

  Future<void> _acceptStorage() async {
    await DisclosureService.acceptStorage();
    if (!mounted) return;
    setState(() => _storageAccepted = true);
  }

  Future<void> _acceptNetwork() async {
    await DisclosureService.acceptNetwork();
    if (!mounted) return;
    setState(() => _networkAccepted = true);
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: AppConstants.animationDuration,
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() {
    if (!_allDisclosuresAccepted) return;
    context.read<OnboardingBloc>().add(CompleteOnboardingEvent());
  }

  void _reloadDisclosureFlags() {
    final privacy = DisclosureService.isPrivacyAccepted();
    final storage = DisclosureService.isStorageAccepted();
    final network = DisclosureService.isNetworkAccepted();
    if (privacy == _privacyAccepted &&
        storage == _storageAccepted &&
        network == _networkAccepted) {
      return;
    }
    setState(() {
      _privacyAccepted = privacy;
      _storageAccepted = storage;
      _networkAccepted = network;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _steps[_currentPage];
    final isLast = _currentPage == _steps.length - 1;
    final blockedByDisclosure = _stepBlocksProgress(currentStep);
    final canAdvance = !blockedByDisclosure &&
        (!isLast || _allDisclosuresAccepted);
    // Skip is only meaningful once all three disclosures have been
    // accepted. Before that, we hide the button entirely rather than
    // showing it greyed-out: a disabled-but-visible control reads as
    // broken when it stays that way for the whole feature walk-through.
    final canSkip = _allDisclosuresAccepted;

    return BlocListener<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (state is OnboardingCompleted) {
          context.go(RouteNames.home);
        } else if (state is OnboardingRequired) {
          // ResetOnboardingEvent was dispatched (e.g. from Settings ->
          // Review onboarding) while this page is still mounted. The
          // disclosure flags in SharedPreferences have been cleared,
          // so we must re-read them here otherwise the local booleans
          // keep the CTA enabled against stale state.
          _reloadDisclosureFlags();
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
                    Visibility(
                      visible: canSkip,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: TextButton(
                        onPressed:
                            canSkip ? _completeOnboarding : null,
                        child: Text('common.skip'.tr()),
                      ),
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
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                  itemCount: _steps.length,
                  itemBuilder: (context, index) =>
                      _buildStep(_steps[index]),
                ),
              ),

              // Page indicator
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: SmoothPageIndicator(
                  controller: _pageController,
                  count: _steps.length,
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
                        onPressed: canAdvance ? _nextPage : null,
                        child: Text(
                          isLast
                              ? 'onboarding.get_started'.tr()
                              : 'common.next'.tr(),
                        ),
                      ),
                    ),
                    if (blockedByDisclosure) ...[
                      SizedBox(height: 8.h),
                      Text(
                        'onboarding.disclosure_required'.tr(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(_OnboardingStep step) {
    if (step is _FeatureStep) return _buildFeaturePage(step);
    if (step is _PrivacyDisclosureStep) {
      return DisclosureScreen(
        headerIcon: Icons.privacy_tip_outlined,
        headerColor: step.color,
        titleKey: 'onboarding.privacy.title',
        introKey: 'onboarding.privacy.intro',
        bullets: const [
          DisclosureBullet(
            icon: Icons.phone_iphone,
            titleKey: 'onboarding.privacy.bullets.local.title',
            descriptionKey: 'onboarding.privacy.bullets.local.description',
          ),
          DisclosureBullet(
            icon: Icons.vpn_key_outlined,
            titleKey: 'onboarding.privacy.bullets.keys.title',
            descriptionKey: 'onboarding.privacy.bullets.keys.description',
          ),
          DisclosureBullet(
            icon: Icons.visibility_off_outlined,
            titleKey: 'onboarding.privacy.bullets.telemetry.title',
            descriptionKey:
                'onboarding.privacy.bullets.telemetry.description',
          ),
          DisclosureBullet(
            icon: Icons.delete_outline,
            titleKey: 'onboarding.privacy.bullets.control.title',
            descriptionKey:
                'onboarding.privacy.bullets.control.description',
          ),
        ],
        footnoteKey: 'onboarding.privacy.footnote',
        confirmLabelKey: 'onboarding.disclosure.confirm',
        confirmedLabelKey: 'onboarding.disclosure.confirmed',
        accepted: _privacyAccepted,
        onAccept: _acceptPrivacy,
      );
    }
    if (step is _StorageDisclosureStep) {
      return DisclosureScreen(
        headerIcon: Icons.folder_outlined,
        headerColor: step.color,
        titleKey: 'onboarding.storage.title',
        introKey: 'onboarding.storage.intro',
        bullets: const [
          DisclosureBullet(
            icon: Icons.folder_special_outlined,
            titleKey: 'onboarding.storage.bullets.root.title',
            descriptionKey: 'onboarding.storage.bullets.root.description',
          ),
          DisclosureBullet(
            icon: Icons.storage_outlined,
            titleKey: 'onboarding.storage.bullets.data.title',
            descriptionKey: 'onboarding.storage.bullets.data.description',
          ),
          DisclosureBullet(
            icon: Icons.cloud_download_outlined,
            titleKey: 'onboarding.storage.bullets.cache.title',
            descriptionKey: 'onboarding.storage.bullets.cache.description',
          ),
          DisclosureBullet(
            icon: Icons.upload_file_outlined,
            titleKey: 'onboarding.storage.bullets.imports.title',
            descriptionKey:
                'onboarding.storage.bullets.imports.description',
          ),
          DisclosureBullet(
            icon: Icons.save_alt_outlined,
            titleKey: 'onboarding.storage.bullets.exports.title',
            descriptionKey:
                'onboarding.storage.bullets.exports.description',
          ),
        ],
        footnoteKey: 'onboarding.storage.footnote',
        confirmLabelKey: 'onboarding.disclosure.confirm',
        confirmedLabelKey: 'onboarding.disclosure.confirmed',
        accepted: _storageAccepted,
        onAccept: _acceptStorage,
      );
    }
    if (step is _NetworkDisclosureStep) {
      return DisclosureScreen(
        headerIcon: Icons.public_outlined,
        headerColor: step.color,
        titleKey: 'onboarding.network.title',
        introKey: 'onboarding.network.intro',
        bullets: const [
          DisclosureBullet(
            icon: Icons.insights_outlined,
            titleKey: 'onboarding.network.bullets.snapshot.title',
            descriptionKey:
                'onboarding.network.bullets.snapshot.description',
          ),
          DisclosureBullet(
            icon: Icons.auto_awesome,
            titleKey: 'onboarding.network.bullets.gemini.title',
            descriptionKey: 'onboarding.network.bullets.gemini.description',
          ),
          DisclosureBullet(
            icon: Icons.show_chart,
            titleKey: 'onboarding.network.bullets.eodhd.title',
            descriptionKey: 'onboarding.network.bullets.eodhd.description',
          ),
          DisclosureBullet(
            icon: Icons.analytics_outlined,
            titleKey: 'onboarding.network.bullets.fmp.title',
            descriptionKey: 'onboarding.network.bullets.fmp.description',
          ),
        ],
        footnoteKey: 'onboarding.network.footnote',
        confirmLabelKey: 'onboarding.disclosure.confirm',
        confirmedLabelKey: 'onboarding.disclosure.confirmed',
        accepted: _networkAccepted,
        onAccept: _acceptNetwork,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildFeaturePage(_FeatureStep item) {
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

abstract class _OnboardingStep {
  const _OnboardingStep();
}

class _FeatureStep extends _OnboardingStep {
  final IconData icon;
  final String titleKey;
  final String descriptionKey;
  final Color color;

  const _FeatureStep({
    required this.icon,
    required this.titleKey,
    required this.descriptionKey,
    required this.color,
  });
}

class _PrivacyDisclosureStep extends _OnboardingStep {
  final Color color;
  const _PrivacyDisclosureStep({required this.color});
}

class _StorageDisclosureStep extends _OnboardingStep {
  final Color color;
  const _StorageDisclosureStep({required this.color});
}

class _NetworkDisclosureStep extends _OnboardingStep {
  final Color color;
  const _NetworkDisclosureStep({required this.color});
}
