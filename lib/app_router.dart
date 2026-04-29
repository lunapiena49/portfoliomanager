import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/app_constants.dart';
import 'core/security/secure_screen.dart';
import 'core/widgets/pluri_logo.dart';
import 'services/api/market_snapshot_service.dart';
import 'services/storage/local_storage_service.dart';
import 'features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';
import 'features/onboarding/presentation/pages/language_selection_page.dart';
import 'features/portfolio/presentation/pages/home_page.dart';
import 'features/portfolio/presentation/pages/import_page.dart';
import 'features/portfolio/presentation/pages/position_detail_page.dart';
import 'features/portfolio/presentation/pages/add_position_page.dart';
import 'features/portfolio/presentation/pages/edit_position_page.dart';
import 'features/portfolio/presentation/pages/create_portfolio_page.dart';
import 'features/analysis/presentation/pages/analysis_page.dart';
import 'features/analysis/presentation/pages/ai_chat_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/onboarding/presentation/pages/guide_page.dart';
import 'features/onboarding/presentation/pages/legal_documents_page.dart';
import 'features/onboarding/presentation/pages/legal_disclaimer_page.dart';

/// Application router configuration using go_router
class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static CustomTransitionPage<void> _fadeTransitionPage(
    GoRouterState state,
    Widget child,
  ) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: AppConstants.splashTransitionDuration,
      reverseTransitionDuration: AppConstants.splashTransitionDuration,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      // Gate on the synchronous SharedPreferences flag, not on the (async)
      // OnboardingBloc state. Otherwise deep links resolve before the bloc
      // finishes CheckOnboardingStatusEvent and a returning user is bounced
      // back to /onboarding on cold start.
      final isOnboardingComplete = LocalStorageService.isOnboardingComplete();
      final isOnboardingRoute = state.matchedLocation == RouteNames.onboarding;
      final isSplashRoute = state.matchedLocation == RouteNames.splash;
      final isLanguageRoute =
          state.matchedLocation == RouteNames.languageSelection;
      final hasSelectedLanguage = LocalStorageService.isLanguageSelected();

      // Never redirect away from splash explicitly; SplashPage will handle navigation
      if (isSplashRoute) {
        return null;
      }

      // Ensure language is selected before continuing
      if (!hasSelectedLanguage && !isLanguageRoute) {
        return RouteNames.languageSelection;
      }

      // If onboarding not complete and not on onboarding page, redirect
      if (!isOnboardingComplete &&
          !isOnboardingRoute &&
          !isSplashRoute &&
          !isLanguageRoute) {
        return RouteNames.onboarding;
      }

      // If onboarding complete and on onboarding or language page, redirect to home
      if (isOnboardingComplete && (isOnboardingRoute || isLanguageRoute)) {
        return RouteNames.home;
      }

      return null;
    },
    routes: [
      // Splash Screen
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const SplashPage(),
      ),

      // Onboarding
      GoRoute(
        path: RouteNames.onboarding,
        pageBuilder: (context, state) =>
            _fadeTransitionPage(state, const OnboardingPage()),
      ),

      // Language selection
      GoRoute(
        path: RouteNames.languageSelection,
        pageBuilder: (context, state) =>
            _fadeTransitionPage(state, const LanguageSelectionPage()),
      ),

      // Main App with Bottom Navigation
      GoRoute(
        path: RouteNames.home,
        pageBuilder: (context, state) =>
            _fadeTransitionPage(state, const SecureScreen(child: HomePage())),
        routes: [
          // Import Portfolio
          GoRoute(
            path: 'import',
            builder: (context, state) =>
                const SecureScreen(child: ImportPage()),
          ),

          // Position Detail
          GoRoute(
            path: 'position/:id',
            builder: (context, state) {
              final positionId = state.pathParameters['id'] ?? '';
              return SecureScreen(
                child: PositionDetailPage(positionId: positionId),
              );
            },
          ),

          // Edit Position
          GoRoute(
            path: 'position/:id/edit',
            builder: (context, state) {
              final positionId = state.pathParameters['id'] ?? '';
              return SecureScreen(
                child: EditPositionPage(positionId: positionId),
              );
            },
          ),
		  // ADD POSITION
		  GoRoute(
		    path: 'add-position',
			builder: (context, state) =>
			    const SecureScreen(child: AddPositionPage()),
		  ),
          // CREATE PORTFOLIO
          GoRoute(
            path: 'create-portfolio',
            builder: (context, state) =>
                const SecureScreen(child: CreatePortfolioPage()),
          ),
        ],
      ),

      // Analysis
      GoRoute(
        path: RouteNames.analysis,
        builder: (context, state) =>
            const SecureScreen(child: AnalysisPage()),
      ),

      // AI Chat
      GoRoute(
        path: RouteNames.aiChat,
        builder: (context, state) =>
            const SecureScreen(child: AIChatPage()),
      ),

      // Settings (no SecureScreen: contains keys but the user must be
      // able to take a screenshot of the about/version section for support).
      GoRoute(
        path: RouteNames.settings,
        builder: (context, state) => const SettingsPage(),
      ),

      // Guide
      GoRoute(
        path: RouteNames.guide,
        builder: (context, state) => const GuidePage(),
      ),

      // Legal documents (Privacy Policy / ToS / Disclaimer landing).
      GoRoute(
        path: RouteNames.legalDocuments,
        builder: (context, state) => const LegalDocumentsPage(),
      ),

      // Re-show the financial disclaimer with full text + bumped consent
      // tracking. Reachable from Settings > Legal documents.
      GoRoute(
        path: RouteNames.legalDisclaimer,
        builder: (context, state) =>
            const LegalDisclaimerPage(reviewMode: true),
      ),
    ],
    errorBuilder: (context, state) => ErrorPage(error: state.error.toString()),
  );
}

/// Splash screen shown while checking onboarding status
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  static const Duration _minDisplayDuration =
      AppConstants.splashMinimumDuration;
  static const Duration _fadeOutDuration = Duration(milliseconds: 600);
  static const Color _neonMint = Color(0xFF3DF2A7);

  late final AnimationController _fadeOutController;
  late final Animation<double> _fadeOutAnim;

  bool _minDelayElapsed = false;
  bool _hasNavigated = false;
  String? _pendingRoute;
  Timer? _delayTimer;

  // Daily market data sync state. Drives the progress bar shown below the
  // logo so the user has visible feedback while the snapshot is downloaded
  // from GitHub Pages on app start.
  bool _syncRunning = false;
  bool _syncCompleted = false;
  double _syncProgress = 0.0;

  @override
  void initState() {
    super.initState();

    _fadeOutController = AnimationController(
      vsync: this,
      duration: _fadeOutDuration,
    );
    _fadeOutAnim = CurvedAnimation(
      parent: _fadeOutController,
      curve: Curves.easeInCubic,
    );

    _delayTimer = Timer(_minDisplayDuration, () {
      if (!mounted) return;
      _minDelayElapsed = true;
      _maybeNavigate();
    });

    if (!LocalStorageService.isLanguageSelected()) {
      _pendingRoute = RouteNames.languageSelection;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OnboardingBloc>().add(CheckOnboardingStatusEvent());
      _maybeRunDailySync();
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _fadeOutController.dispose();
    super.dispose();
  }

  Future<void> _maybeRunDailySync() async {
    // Skip the daily download when we already pulled today (the UI keeps
    // the progress bar hidden and falls back to the cached snapshot).
    if (!LocalStorageService.isMarketSnapshotStale()) {
      return;
    }

    setState(() {
      _syncRunning = true;
      _syncProgress = 0.0;
    });

    final service = MarketSnapshotService();
    try {
      final ok = await service.refreshAll(
        onProgress: (value) {
          if (!mounted) return;
          setState(() {
            _syncProgress = value.clamp(0.0, 1.0);
          });
        },
      );
      if (ok) {
        await LocalStorageService.setLastMarketSyncToday();
      }
    } catch (_) {
      // The snapshot refresh is best-effort: never block app start on a
      // failed download. The market tab will surface the error if needed.
    } finally {
      if (mounted) {
        setState(() {
          _syncRunning = false;
          _syncCompleted = true;
          _syncProgress = 1.0;
        });
      }
    }
  }

  void _handleOnboardingState(OnboardingState state) {
    if (_pendingRoute == RouteNames.languageSelection) {
      _maybeNavigate();
      return;
    }

    if (state is OnboardingCompleted) {
      // If the user backgrounded the app recently, drop them back on the page
      // they were last viewing instead of always sending them to home.
      // Restoration is best-effort: stale or non-whitelisted entries return
      // null and we fall back to home.
      _pendingRoute =
          LocalStorageService.getLastRouteIfRecent() ?? RouteNames.home;
    } else if (state is OnboardingRequired) {
      _pendingRoute = RouteNames.onboarding;
    }

    _maybeNavigate();
  }

  void _maybeNavigate() {
    if (!mounted || _hasNavigated || !_minDelayElapsed) return;
    final route = _pendingRoute;
    if (route == null) return;
    _hasNavigated = true;

    _fadeOutController.forward().then((_) {
      if (mounted) context.go(route);
    });
  }

  double _responsiveLogoWidth(double screenWidth) {
    if (screenWidth >= 1024) {
      return (screenWidth * 0.35).clamp(400.0, 600.0);
    } else if (screenWidth >= 600) {
      return (screenWidth * 0.55).clamp(320.0, 480.0);
    } else {
      return (screenWidth * 0.75).clamp(200.0, 360.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final logoWidth = _responsiveLogoWidth(screenWidth);

    return BlocListener<OnboardingBloc, OnboardingState>(
      listener: (context, state) => _handleOnboardingState(state),
      child: FadeTransition(
        opacity: ReverseAnimation(_fadeOutAnim),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0E14),
                  Color(0xFF101A22),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: PluriLogo(
                        width: logoWidth,
                        tintColor: _neonMint,
                        showOrbital: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: logoWidth * 0.25,
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            _neonMint.withValues(alpha: 0.28),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AppConstants.appName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.2,
                              shadows: [
                                Shadow(
                                  color: _neonMint.withValues(alpha: 0.4),
                                  blurRadius: 18,
                                ),
                                Shadow(
                                  color: _neonMint.withValues(alpha: 0.15),
                                  blurRadius: 40,
                                ),
                              ],
                            ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSyncIndicator(context, logoWidth),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncIndicator(BuildContext context, double logoWidth) {
    if (!_syncRunning && !_syncCompleted) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation<Color>(_neonMint),
        ),
      );
    }

    final percent = (_syncProgress.clamp(0.0, 1.0) * 100).round();
    final barWidth = logoWidth.clamp(220.0, 360.0);
    final progressLabel = 'splash.market_sync.progress'
        .tr(namedArgs: {'percent': percent.toString()});

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'splash.market_sync.title'.tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          _syncCompleted
              ? 'splash.market_sync.ready'.tr()
              : 'splash.market_sync.subtitle'.tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.62),
              ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: barWidth,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _syncProgress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              valueColor: const AlwaysStoppedAnimation<Color>(_neonMint),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          progressLabel,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
      ],
    );
  }
}

/// Error page for navigation errors
class ErrorPage extends StatelessWidget {
  final String error;

  const ErrorPage({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('error.title'.tr()),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'error.page_not_found'.tr(),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(RouteNames.home),
              child: Text('error.go_home'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
