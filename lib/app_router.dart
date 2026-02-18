import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/app_constants.dart';
import 'core/widgets/pluri_logo.dart';
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
      final onboardingState = context.read<OnboardingBloc>().state;
      final isOnboardingComplete = onboardingState is OnboardingCompleted;
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
            _fadeTransitionPage(state, const HomePage()),
        routes: [
          // Import Portfolio
          GoRoute(
            path: 'import',
            builder: (context, state) => const ImportPage(),
          ),

          // Position Detail
          GoRoute(
            path: 'position/:id',
            builder: (context, state) {
              final positionId = state.pathParameters['id'] ?? '';
              return PositionDetailPage(positionId: positionId);
            },
          ),

          // Edit Position
          GoRoute(
            path: 'position/:id/edit',
            builder: (context, state) {
              final positionId = state.pathParameters['id'] ?? '';
              return EditPositionPage(positionId: positionId);
            },
          ),
		  // ADD POSITION
		  GoRoute(
		    path: 'add-position',
			builder: (context, state) => const AddPositionPage(),
		  ),
          // CREATE PORTFOLIO
          GoRoute(
            path: 'create-portfolio',
            builder: (context, state) => const CreatePortfolioPage(),
          ),
        ],
      ),

      // Analysis
      GoRoute(
        path: RouteNames.analysis,
        builder: (context, state) => const AnalysisPage(),
      ),

      // AI Chat
      GoRoute(
        path: RouteNames.aiChat,
        builder: (context, state) => const AIChatPage(),
      ),

      // Settings
      GoRoute(
        path: RouteNames.settings,
        builder: (context, state) => const SettingsPage(),
      ),

      // Guide
      GoRoute(
        path: RouteNames.guide,
        builder: (context, state) => const GuidePage(),
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
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _fadeOutController.dispose();
    super.dispose();
  }

  void _handleOnboardingState(OnboardingState state) {
    if (_pendingRoute == RouteNames.languageSelection) {
      _maybeNavigate();
      return;
    }

    if (state is OnboardingCompleted) {
      _pendingRoute = RouteNames.home;
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
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: logoWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PluriLogo(
                              width: logoWidth,
                              tintColor: _neonMint,
                              showOrbital: true,
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
                                          color: _neonMint.withValues(
                                              alpha: 0.4),
                                          blurRadius: 18,
                                        ),
                                        Shadow(
                                          color: _neonMint.withValues(
                                              alpha: 0.15),
                                          blurRadius: 40,
                                        ),
                                      ],
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF3DF2A7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
        title: const Text('Error'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Page not found',
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
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
