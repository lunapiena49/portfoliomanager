import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/rebalancing_bloc.dart';
import '../../domain/entities/rebalancing_entities.dart';
import '../../../portfolio/presentation/bloc/portfolio_bloc.dart';
import '../../../portfolio/domain/entities/portfolio_entities.dart';

enum _RebalancingMenuAction {
  analysis,
  importPortfolio,
  settings,
  help,
  managePortfolios,
}

class RebalancingTab extends StatefulWidget {
  const RebalancingTab({super.key});

  @override
  State<RebalancingTab> createState() => _RebalancingTabState();
}

class _RebalancingTabState extends State<RebalancingTab> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  late final TextInputFormatter _targetPercentFormatter =
      TextInputFormatter.withFunction((oldValue, newValue) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }

    final normalized = text.replaceAll(',', '.');
    final isValidFormat = RegExp(r'^\d{0,3}(\.\d{0,2})?$').hasMatch(normalized);
    if (!isValidFormat) {
      return oldValue;
    }

    final parsed = double.tryParse(normalized);
    if (parsed != null && parsed > 100) {
      return oldValue;
    }

    return newValue;
  });
  bool _showOnlyChanges = false;
  Portfolio? _lastLoadedPortfolio;

  @override
  void initState() {
    super.initState();
    _loadRebalancing(force: true);
  }

  Portfolio? _extractPortfolio(PortfolioState state) {
    if (state is PortfolioLoaded) {
      return state.portfolio;
    }
    return null;
  }

  void _loadRebalancing({Portfolio? portfolio, bool force = false}) {
    final nextPortfolio =
        portfolio ?? _extractPortfolio(context.read<PortfolioBloc>().state);
    if (nextPortfolio == null) return;

    if (!force && _lastLoadedPortfolio == nextPortfolio) {
      return;
    }

    _lastLoadedPortfolio = nextPortfolio;
    context.read<RebalancingBloc>().add(
          LoadRebalancingEvent(portfolio: nextPortfolio),
        );
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _initControllers(List<RebalanceTarget> targets) {
    for (final target in targets) {
      if (!_controllers.containsKey(target.positionId)) {
        _controllers[target.positionId] = TextEditingController(
          text: target.targetPercent.toStringAsFixed(2),
        );
      }

      if (!_focusNodes.containsKey(target.positionId)) {
        final positionId = target.positionId;
        final focusNode = FocusNode();
        focusNode.addListener(() {
          if (!focusNode.hasFocus) {
            _commitTargetValue(positionId);
          }
        });
        _focusNodes[positionId] = focusNode;
      }
    }
    // Remove controllers for positions that no longer exist
    final ids = targets.map((t) => t.positionId).toSet();
    _controllers.removeWhere((key, controller) {
      if (!ids.contains(key)) {
        controller.dispose();
        _focusNodes.remove(key)?.dispose();
        return true;
      }
      return false;
    });
  }

  void _syncControllersFromState() {
    final currentState = context.read<RebalancingBloc>().state;
    if (currentState is! RebalancingLoaded) return;

    for (final target in currentState.targets) {
      final positionId = target.positionId;
      if (_focusNodes[positionId]?.hasFocus ?? false) {
        continue;
      }

      final controller = _controllers[positionId];
      if (controller == null) {
        continue;
      }

      final nextText = target.targetPercent.toStringAsFixed(2);
      if (controller.text != nextText) {
        controller.text = nextText;
      }
    }
  }

  void _scheduleControllerSync() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      _syncControllersFromState();
    });
  }

  void _setTargetValue(String positionId, double value) {
    final clamped = value.clamp(0.0, 100.0);
    final nextText = clamped.toStringAsFixed(2);
    final controller = _controllers[positionId];
    if (controller != null) {
      controller.value = controller.value.copyWith(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
        composing: TextRange.empty,
      );
    }

    context.read<RebalancingBloc>().add(
          UpdateTargetPercentEvent(
            positionId: positionId,
            targetPercent: clamped,
          ),
        );
  }

  double? _parseTargetInput(String rawValue) {
    final normalized = rawValue.trim().replaceAll(',', '.');
    if (normalized.isEmpty || normalized == '.') {
      return null;
    }
    return double.tryParse(normalized);
  }

  void _commitTargetValue(String positionId) {
    final controller = _controllers[positionId];
    if (controller == null) {
      return;
    }

    final parsed = _parseTargetInput(controller.text);
    if (parsed != null) {
      _setTargetValue(positionId, parsed);
    } else {
      _scheduleControllerSync();
    }
  }

  Widget _buildMetricCard({
    required String label,
    required Widget value,
    String? caption,
    CrossAxisAlignment alignment = CrossAxisAlignment.start,
    Color? captionColor,
  }) {
    final theme = Theme.of(context);
    final align = alignment == CrossAxisAlignment.end
        ? Alignment.centerRight
        : Alignment.centerLeft;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 6.h),
          Align(alignment: align, child: value),
          if (caption != null) ...[
            SizedBox(height: 4.h),
            Align(
              alignment: align,
              child: Text(
                caption,
                textAlign: alignment == CrossAxisAlignment.end
                    ? TextAlign.end
                    : TextAlign.start,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: captionColor ?? Colors.grey[600],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _resetTargetsToCurrent() {
    context.read<RebalancingBloc>().add(SetTargetsFromCurrentEvent());
    _scheduleControllerSync();
  }

  @override
  Widget build(BuildContext context) {
    final portfolioState = context.watch<PortfolioBloc>().state;
    return BlocListener<PortfolioBloc, PortfolioState>(
      listenWhen: (previous, current) {
        if (current is! PortfolioLoaded) return false;
        if (previous is! PortfolioLoaded) return true;
        return previous.portfolio != current.portfolio;
      },
      listener: (context, state) {
        if (state is PortfolioLoaded) {
          _loadRebalancing(portfolio: state.portfolio);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('rebalancing.title'.tr()),
          actions: _buildAppBarActions(context, portfolioState),
        ),
        body: BlocConsumer<RebalancingBloc, RebalancingState>(
          listener: (context, state) {
            if (state is RebalancingLoaded && state.isSaved) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('rebalancing.messages.saved'.tr()),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is RebalancingLoading) {
              return _buildLoadingState();
            }

            if (state is RebalancingError) {
              return _buildErrorState(state.message);
            }

            if (state is RebalancingLoaded) {
              _initControllers(state.targets);
              return _buildContent(state);
            }

            // Initial state – check if portfolio is available
            return _buildNoPortfolioState();
          },
        ),
      ),
    );
  }

  String _formatCurrency(double value, String currency) {
    final formatter = NumberFormat.currency(
      symbol: _getCurrencySymbol(currency),
      decimalDigits: 2,
    );

    return formatter.format(value);
  }

  String _formatSignedPercent(double value) {
    final sign = value >= 0 ? '+' : '-';
    return '$sign${value.abs().toStringAsFixed(2)}%';
  }

  String _formatSignedCurrency(double value, String currency) {
    final sign = value >= 0 ? '+' : '-';
    return '$sign${_formatCurrency(value.abs(), currency)}';
  }

  String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'EUR':
        return 'EUR ';
      case 'USD':
        return '\$';
      case 'GBP':
        return '£';
      case 'CHF':
        return 'CHF ';
      case 'JPY':
        return '¥';
      default:
        return '$currency ';
    }
  }

  List<Widget> _buildAppBarActions(
    BuildContext context,
    PortfolioState portfolioState,
  ) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    if (!isCompact) {
      return [
        IconButton(
          icon: const Icon(Icons.auto_awesome),
          tooltip: 'navigation.analysis'.tr(),
          onPressed: () => context.push(RouteNames.analysis),
        ),
        IconButton(
          icon: const Icon(Icons.upload_file),
          tooltip: 'portfolio.import_portfolio'.tr(),
          onPressed: () => context.push('${RouteNames.home}/import'),
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'navigation.settings'.tr(),
          onPressed: () => context.push(RouteNames.settings),
        ),
        IconButton(
          icon: const Icon(Icons.help_outline),
          tooltip: 'common.help'.tr(),
          onPressed: () => context.push(RouteNames.guide),
        ),
        if (portfolioState is PortfolioLoaded)
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'portfolio.manage_portfolios'.tr(),
            onPressed: () => _showPortfolioManager(context, portfolioState),
          ),
      ];
    }

    return [
      PopupMenuButton<_RebalancingMenuAction>(
        icon: const Icon(Icons.menu),
        onSelected: (action) {
          switch (action) {
            case _RebalancingMenuAction.analysis:
              context.push(RouteNames.analysis);
              break;
            case _RebalancingMenuAction.importPortfolio:
              context.push('${RouteNames.home}/import');
              break;
            case _RebalancingMenuAction.settings:
              context.push(RouteNames.settings);
              break;
            case _RebalancingMenuAction.help:
              context.push(RouteNames.guide);
              break;
            case _RebalancingMenuAction.managePortfolios:
              if (portfolioState is PortfolioLoaded) {
                _showPortfolioManager(context, portfolioState);
              }
              break;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _RebalancingMenuAction.analysis,
            child: _buildMenuItem(
              context,
              Icons.auto_awesome,
              'navigation.analysis'.tr(),
            ),
          ),
          PopupMenuItem(
            value: _RebalancingMenuAction.importPortfolio,
            child: _buildMenuItem(
              context,
              Icons.upload_file,
              'portfolio.import_portfolio'.tr(),
            ),
          ),
          PopupMenuItem(
            value: _RebalancingMenuAction.settings,
            child: _buildMenuItem(
              context,
              Icons.settings,
              'navigation.settings'.tr(),
            ),
          ),
          PopupMenuItem(
            value: _RebalancingMenuAction.help,
            child: _buildMenuItem(
              context,
              Icons.help_outline,
              'common.help'.tr(),
            ),
          ),
          if (portfolioState is PortfolioLoaded)
            PopupMenuItem(
              value: _RebalancingMenuAction.managePortfolios,
              child: _buildMenuItem(
                context,
                Icons.folder_open,
                'portfolio.manage_portfolios'.tr(),
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

  void _showPortfolioManager(BuildContext context, PortfolioLoaded state) {
    final portfolios = [...state.allPortfolios];
    final currentId = state.portfolio.id;
    if (portfolios.every((p) => p.id != currentId)) {
      portfolios.add(state.portfolio);
    }
    portfolios.sort((a, b) {
      if (a.id == currentId) return -1;
      if (b.id == currentId) return 1;
      return a.accountName.compareTo(b.accountName);
    });

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'portfolio.manage_portfolios'.tr(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 12.h),
                    ...portfolios.map((portfolio) {
                      final isCurrent = portfolio.id == currentId;
                      final displayName = portfolio.accountName.isNotEmpty
                          ? portfolio.accountName
                          : portfolio.accountId;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(displayName),
                        leading: Icon(
                          isCurrent
                              ? Icons.check_circle
                              : Icons.account_balance_wallet,
                          color:
                              isCurrent ? Theme.of(context).primaryColor : null,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'portfolio.rename_portfolio'.tr(),
                          onPressed: () =>
                              _showRenameDialog(context, portfolio),
                        ),
                        onTap: () {
                          context.read<PortfolioBloc>().add(
                                SelectPortfolioEvent(portfolio.id),
                              );
                          Navigator.of(sheetContext).pop();
                        },
                      );
                    }),
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          context.push('${RouteNames.home}/create-portfolio');
                        },
                        icon: const Icon(Icons.create_new_folder_outlined),
                        label: Text('portfolio.create_portfolio'.tr()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, Portfolio portfolio) {
    final controller = TextEditingController(
      text: portfolio.accountName.isNotEmpty
          ? portfolio.accountName
          : portfolio.accountId,
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('portfolio.rename_portfolio'.tr()),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'portfolio.portfolio_name'.tr(),
              hintText: 'portfolio.portfolio_name_hint'.tr(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                context.read<PortfolioBloc>().add(
                      RenamePortfolioEvent(
                        portfolioId: portfolio.id,
                        name: name,
                      ),
                    );
                Navigator.of(dialogContext).pop();
              },
              child: Text('common.save'.tr()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent(RebalancingLoaded state) {
    if (state.targets.isEmpty) {
      return _buildNoPortfolioState();
    }

    final filteredResults = _showOnlyChanges
        ? state.results.where((r) => !r.isAtTarget).toList()
        : state.results;

    return RefreshIndicator(
      onRefresh: () async => _loadRebalancing(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        children: [
          _buildHeader(),
          SizedBox(height: 8.h),
          _buildToolbar(state),
          SizedBox(height: 8.h),
          _buildSummaryCard(state),
          ...filteredResults.map(
            (result) => KeyedSubtree(
              key: ValueKey('rebalance_${result.positionId}'),
              child: _buildPositionCard(result),
            ),
          ),
          SizedBox(height: 4.h),
          _buildBottomBar(state),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.of(context).size.width < 720;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12.w,
        vertical: isCompact ? 10.h : 12.h,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.primary,
            size: isCompact ? 18.w : 20.w,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'rebalancing.subtitle'.tr(),
              maxLines: isCompact ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
              ),
            ),
          ),
          IconButton(
            tooltip: 'common.help'.tr(),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => _showHelpDialog(),
            icon: Icon(Icons.help_outline, color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(RebalancingLoaded state) {
    final width = MediaQuery.of(context).size.width;
    final menuItemWidth = math.max(180.0, math.min(460.0, width * 0.45));
    final triggerMinWidth = math.max(112.0, math.min(156.0, width * 0.22));
    final theme = Theme.of(context);
    final triggerDecoration = BoxDecoration(
      color: theme.colorScheme.surface.withOpacity(0.75),
      borderRadius: BorderRadius.circular(10.r),
      border: Border.all(color: theme.dividerColor.withOpacity(0.45)),
    );

    Widget buildMenuTrigger({
      required String label,
      required IconData leadingIcon,
    }) {
      return Container(
        constraints: BoxConstraints(minWidth: triggerMinWidth),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: triggerDecoration,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(leadingIcon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.menu, size: 18, color: theme.colorScheme.primary),
          ],
        ),
      );
    }

    final filtersMenu = PopupMenuButton<bool>(
      tooltip: 'rebalancing.menu.filters'.tr(),
      constraints: BoxConstraints(
        minWidth: menuItemWidth,
        maxWidth: menuItemWidth,
      ),
      onSelected: (value) => setState(() => _showOnlyChanges = value),
      itemBuilder: (context) => [
        CheckedPopupMenuItem<bool>(
          value: !_showOnlyChanges,
          checked: _showOnlyChanges,
          child: SizedBox(
            width: menuItemWidth,
            child: Text(
              'rebalancing.filter.changes_only'.tr(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
            ),
          ),
        ),
      ],
      child: buildMenuTrigger(
        label: 'rebalancing.menu.filters'.tr(),
        leadingIcon: Icons.filter_list,
      ),
    );

    final optionsMenu = PopupMenuButton<String>(
      tooltip: 'rebalancing.menu.options'.tr(),
      constraints: BoxConstraints(
        minWidth: menuItemWidth,
        maxWidth: menuItemWidth,
      ),
      onSelected: (value) {
        switch (value) {
          case 'reset_current':
            _resetTargetsToCurrent();
            break;
          case 'equal':
            _distributeEqually(state);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'reset_current',
          child: SizedBox(
            width: menuItemWidth,
            child: Row(
              children: [
                const Icon(Icons.refresh, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'rebalancing.menu.reset_to_current'.tr(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        PopupMenuItem(
          value: 'equal',
          child: SizedBox(
            width: menuItemWidth,
            child: Row(
              children: [
                const Icon(Icons.drag_handle, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'rebalancing.menu.distribute_equally'.tr(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      child: buildMenuTrigger(
        label: 'rebalancing.menu.options'.tr(),
        leadingIcon: Icons.tune,
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            filtersMenu,
            optionsMenu,
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(RebalancingLoaded state) {
    final isValid = state.isValid;
    final diff = state.totalTargetPercent - 100.0;
    final theme = Theme.of(context);
    final highlightColor = isValid
        ? AppTheme.successColor
        : diff > 0
            ? AppTheme.errorColor
            : AppTheme.warningColor;
    final diffColor =
        diff.abs() < 0.01 ? AppTheme.successColor : highlightColor;
    final diffText =
        '${diff >= 0 ? '+' : '-'}${diff.abs().toStringAsFixed(2)}%';
    final diffIcon = diff.abs() < 0.01
        ? Icons.check
        : diff > 0
            ? Icons.trending_up
            : Icons.trending_down;

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      color: highlightColor.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: highlightColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12.w,
              runSpacing: 12.h,
              children: [
                _buildSummaryStat(
                  label: 'rebalancing.summary.total_target'.tr(),
                  value: '${state.totalTargetPercent.toStringAsFixed(2)}%',
                  valueColor: highlightColor,
                  icon: Icons.track_changes,
                  iconColor: theme.colorScheme.primary,
                ),
                _buildSummaryStat(
                  label: 'rebalancing.summary.remaining'.tr(),
                  value: diffText,
                  valueColor: diffColor,
                  icon: diffIcon,
                  iconColor: diffColor,
                ),
                _buildSummaryStat(
                  label: 'rebalancing.summary.portfolio_value'.tr(),
                  value: _formatCurrency(
                    state.totalPortfolioValue,
                    state.baseCurrency,
                  ),
                  icon: Icons.account_balance_wallet,
                  iconColor: theme.colorScheme.primary,
                ),
              ],
            ),
            if (!isValid) ...[
              SizedBox(height: 12.h),
              Text(
                diff > 0
                    ? 'rebalancing.summary.over_allocated'
                        .tr(args: [diff.toStringAsFixed(2)])
                    : 'rebalancing.summary.under_allocated'
                        .tr(args: [diff.abs().toStringAsFixed(2)]),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: diff > 0 ? AppTheme.errorColor : AppTheme.warningColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (isValid && state.isBalanced) ...[
              SizedBox(height: 12.h),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 18.w,
                    color: AppTheme.successColor,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'rebalancing.summary.balanced'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildSummaryStat({
    required String label,
    required String value,
    Color? valueColor,
    IconData? icon,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    final resolvedColor = valueColor ?? theme.colorScheme.onSurface;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: (iconColor ?? resolvedColor).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                icon,
                size: 16.w,
                color: iconColor ?? resolvedColor,
              ),
            ),
            SizedBox(width: 8.w),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: resolvedColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPositionCard(
    RebalanceResult result,
  ) {
    final controller = _controllers[result.positionId];
    final theme = Theme.of(context);

    Color deltaColor;
    IconData deltaIcon;
    String actionLabel;

    if (result.needsIncrease) {
      deltaColor = AppTheme.successColor;
      deltaIcon = Icons.arrow_upward;
      actionLabel = 'rebalancing.action.add'.tr();
    } else if (result.needsDecrease) {
      deltaColor = AppTheme.errorColor;
      deltaIcon = Icons.arrow_downward;
      actionLabel = 'rebalancing.action.remove'.tr();
    } else {
      deltaColor = AppTheme.neutralColor;
      deltaIcon = Icons.check_circle_outline;
      actionLabel = 'rebalancing.action.hold'.tr();
    }

    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final metricValueMinHeight = (46.0 * textScale.clamp(1.0, 1.35)).toDouble();

    final currentMetric = _buildMetricCard(
      label: 'rebalancing.current'.tr(),
      value: ConstrainedBox(
        constraints: BoxConstraints(minHeight: metricValueMinHeight),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${result.currentPercent.toStringAsFixed(2)}%',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
      caption: _formatCurrency(result.currentValue, result.currency),
    );

    final targetMetric = _buildMetricCard(
      label: 'rebalancing.target'.tr(),
      value: ConstrainedBox(
        constraints: BoxConstraints(minHeight: metricValueMinHeight),
        child: TextField(
          key: ValueKey('target_input_${result.positionId}'),
          controller: controller,
          focusNode: _focusNodes[result.positionId],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_targetPercentFormatter],
          minLines: 1,
          maxLines: 1,
          textInputAction: TextInputAction.done,
          textAlignVertical: TextAlignVertical.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          decoration: InputDecoration(
            suffixText: '%',
            suffixStyle: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: theme.colorScheme.surface.withOpacity(0.6),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: math.max(10.0, 10.0 * textScale),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            isDense: true,
          ),
          onTapOutside: (_) => _commitTargetValue(result.positionId),
          onEditingComplete: () => _commitTargetValue(result.positionId),
          onSubmitted: (_) => _commitTargetValue(result.positionId),
        ),
      ),
      caption: _formatCurrency(result.targetValue, result.currency),
    );

    final deltaMetric = _buildMetricCard(
      label: 'rebalancing.delta'.tr(),
      alignment: CrossAxisAlignment.end,
      value: ConstrainedBox(
        constraints: BoxConstraints(minHeight: metricValueMinHeight),
        child: Align(
          alignment: Alignment.centerRight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              _formatSignedPercent(result.deltaPercent),
              textAlign: TextAlign.end,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: deltaColor,
              ),
            ),
          ),
        ),
      ),
      caption: _formatSignedCurrency(result.deltaValue, result.currency),
      captionColor: deltaColor,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final isMedium = constraints.maxWidth >= 520;

        Widget metrics;
        if (isWide) {
          metrics = Row(
            children: [
              Expanded(child: currentMetric),
              SizedBox(width: 12.w),
              Expanded(child: targetMetric),
              SizedBox(width: 12.w),
              Expanded(child: deltaMetric),
            ],
          );
        } else if (isMedium) {
          metrics = Column(
            children: [
              Row(
                children: [
                  Expanded(child: currentMetric),
                  SizedBox(width: 12.w),
                  Expanded(child: targetMetric),
                ],
              ),
              SizedBox(height: 12.h),
              deltaMetric,
            ],
          );
        } else {
          metrics = Column(
            children: [
              currentMetric,
              SizedBox(height: 12.h),
              targetMetric,
              SizedBox(height: 12.h),
              deltaMetric,
            ],
          );
        }

        return Card(
          margin: EdgeInsets.only(bottom: 12.h),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        result.symbol,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        result.name,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: deltaColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(deltaIcon, size: 14.w, color: deltaColor),
                          SizedBox(width: 6.w),
                          Text(
                            actionLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: deltaColor,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                metrics,
                SizedBox(height: 12.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: Stack(
                    children: [
                      Container(
                        height: 6.h,
                        decoration: BoxDecoration(
                          color: theme.dividerColor.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor:
                            (result.currentPercent / 100).clamp(0.0, 1.0),
                        child: Container(
                          height: 6.h,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor:
                            (result.targetPercent / 100).clamp(0.0, 1.0),
                        child: Container(
                          height: 6.h,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: deltaColor,
                                width: 2.w,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 200.ms, delay: 50.ms);
      },
    );
  }

  Widget _buildBottomBar(RebalancingLoaded state) {
    final isCompact = MediaQuery.of(context).size.width < 720;
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
        ),
        child: isCompact
            ? Row(
                children: [
                  Tooltip(
                    message: 'rebalancing.actions.reset'.tr(),
                    child: OutlinedButton(
                      onPressed: _resetTargetsToCurrent,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
                        minimumSize: Size(44.w, 40.h),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Icon(Icons.refresh),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: state.isValid
                          ? () {
                              context
                                  .read<RebalancingBloc>()
                                  .add(SaveTargetsEvent());
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.save),
                      label: Text(
                        'rebalancing.actions.save'.tr(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resetTargetsToCurrent,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.refresh),
                      label: Text('rebalancing.actions.reset'.tr()),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: state.isValid
                          ? () {
                              context
                                  .read<RebalancingBloc>()
                                  .add(SaveTargetsEvent());
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.save),
                      label: Text('rebalancing.actions.save'.tr()),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            margin: EdgeInsets.only(bottom: 12.h),
            child: Container(
              height: 100.h,
              padding: EdgeInsets.all(16.w),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.w, color: Colors.red[400]),
          SizedBox(height: 16.h),
          Text(
            'rebalancing.error.title'.tr(),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () => _loadRebalancing(force: true),
            child: Text('common.retry'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPortfolioState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = math.min(64.r, constraints.maxHeight * 0.3);
        final titleSpacing = math.min(16.h, constraints.maxHeight * 0.06);
        final descriptionSpacing = math.min(8.h, constraints.maxHeight * 0.03);

        return SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.balance,
                  size: iconSize,
                  color: Colors.grey[400],
                ),
                SizedBox(height: titleSpacing),
                Text(
                  'rebalancing.empty.title'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: descriptionSpacing),
                Text(
                  'rebalancing.empty.description'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('rebalancing.help.title'.tr()),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('rebalancing.help.description'.tr()),
              SizedBox(height: 16.h),
              Text(
                'rebalancing.help.steps_title'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Text('rebalancing.help.step1'.tr()),
              Text('rebalancing.help.step2'.tr()),
              Text('rebalancing.help.step3'.tr()),
              Text('rebalancing.help.step4'.tr()),
              Text('rebalancing.help.step5'.tr()),
              Text('rebalancing.help.step6'.tr()),
              Text('rebalancing.help.step7'.tr()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  void _distributeEqually(RebalancingLoaded state) {
    final count = state.targets.length;
    if (count == 0) return;

    final equalPercent = double.parse((100.0 / count).toStringAsFixed(2));

    for (final target in state.targets) {
      _controllers[target.positionId]?.text = equalPercent.toStringAsFixed(2);
      context.read<RebalancingBloc>().add(
            UpdateTargetPercentEvent(
              positionId: target.positionId,
              targetPercent: equalPercent,
            ),
          );
    }
  }
}
