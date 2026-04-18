import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../portfolio/presentation/bloc/portfolio_bloc.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../bloc/analysis_bloc.dart';

enum _AnalysisMenuAction {
  chat,
  help,
}

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  @override
  void initState() {
    super.initState();
    _syncApiKey();
  }

  void _syncApiKey() {
    final settingsState = context.read<SettingsBloc>().state;
    if (settingsState is SettingsLoaded) {
      context
          .read<AnalysisBloc>()
          .add(UpdateAnalysisApiKeyEvent(settingsState.settings.geminiApiKey));
    }
  }

  void _generateAnalysis() {
    final portfolioState = context.read<PortfolioBloc>().state;
    final settingsState = context.read<SettingsBloc>().state;

    if (portfolioState is! PortfolioLoaded) return;
    if (settingsState is! SettingsLoaded) return;

    context
        .read<AnalysisBloc>()
        .add(UpdateAnalysisApiKeyEvent(settingsState.settings.geminiApiKey));
    context.read<AnalysisBloc>().add(GenerateAnalysisEvent(
          portfolio: portfolioState.portfolio,
          language: settingsState.settings.languageCode,
        ));
  }

  String _resolveErrorMessage(String raw) {
    if (raw.startsWith('analysis.')) {
      return raw.tr();
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('analysis.title'.tr()),
        actions: _buildAppBarActions(context),
      ),
      body: BlocBuilder<PortfolioBloc, PortfolioState>(
        builder: (context, portfolioState) {
          if (portfolioState is! PortfolioLoaded) {
            return Center(
              child: Text('portfolio.no_positions'.tr()),
            );
          }

          return BlocBuilder<AnalysisBloc, AnalysisState>(
            builder: (context, analysisState) {
              final isLoading = analysisState is AnalysisInProgress;
              final result =
                  analysisState is AnalysisSuccess ? analysisState.result : null;
              final errorMessage = analysisState is AnalysisFailure
                  ? _resolveErrorMessage(analysisState.message)
                  : null;

              return SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'analysis.suggestions.title'.tr(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 12.h),
                    _buildSuggestionChips(),
                    SizedBox(height: 24.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _generateAnalysis,
                        icon: isLoading
                            ? SizedBox(
                                width: 20.w,
                                height: 20.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Text(
                          isLoading
                              ? 'analysis.generating'.tr()
                              : 'analysis.generate_full'.tr(),
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    if (errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: AppTheme.errorColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: AppTheme.errorColor),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                errorMessage,
                                style: TextStyle(color: AppTheme.errorColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (result != null) ...[
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    'analysis.ai_result_title'.tr(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.h),
                              SelectableText(
                                result,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    if (!isCompact) {
      return [
        IconButton(
          icon: const Icon(Icons.chat),
          tooltip: 'analysis.chat_tooltip'.tr(),
          onPressed: () => context.push(RouteNames.aiChat),
        ),
        IconButton(
          icon: const Icon(Icons.help_outline),
          tooltip: 'common.help'.tr(),
          onPressed: () => context.push(RouteNames.guide),
        ),
      ];
    }

    return [
      PopupMenuButton<_AnalysisMenuAction>(
        icon: const Icon(Icons.menu),
        onSelected: (action) {
          switch (action) {
            case _AnalysisMenuAction.chat:
              context.push(RouteNames.aiChat);
              break;
            case _AnalysisMenuAction.help:
              context.push(RouteNames.guide);
              break;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _AnalysisMenuAction.chat,
            child: _buildMenuItem(
              context,
              Icons.chat,
              'analysis.chat_tooltip'.tr(),
            ),
          ),
          PopupMenuItem(
            value: _AnalysisMenuAction.help,
            child: _buildMenuItem(
              context,
              Icons.help_outline,
              'common.help'.tr(),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 20.w),
        SizedBox(width: 12.w),
        Text(label),
      ],
    );
  }

  Widget _buildSuggestionChips() {
    final suggestions = [
      ('analysis.suggestions.risk'.tr(), Icons.warning_amber),
      ('analysis.suggestions.diversification'.tr(), Icons.pie_chart),
      ('analysis.suggestions.performance'.tr(), Icons.trending_up),
      ('analysis.suggestions.recommendations'.tr(), Icons.lightbulb),
    ];

    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: suggestions.map((s) {
        return ActionChip(
          avatar: Icon(s.$2, size: 18.w),
          label: Text(s.$1),
          onPressed: () {
            // TODO: Generate specific analysis
          },
        );
      }).toList(),
    );
  }
}
