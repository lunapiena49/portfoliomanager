import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';

import '../bloc/goals_bloc.dart';
import '../../domain/entities/goals_entities.dart';
import '../../../portfolio/presentation/bloc/portfolio_bloc.dart';
import '../../../portfolio/domain/entities/portfolio_entities.dart';

class GoalsTab extends StatefulWidget {
  const GoalsTab({super.key});

  @override
  State<GoalsTab> createState() => _GoalsTabState();
}

class _GoalsTabState extends State<GoalsTab> with TickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  GoalType? _filterType;
  GoalStatus? _filterStatus;
  bool _showCompletedGoals = true;
  SortOption _sortOption = SortOption.name;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    context.read<GoalsBloc>().add(LoadGoalsEvent());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<InvestmentGoal> _getFilteredGoals(List<InvestmentGoal> goals) {
    var filtered = goals.where((goal) {
      if (!_showCompletedGoals && goal.status == GoalStatus.completed) {
        return false;
      }
      if (_filterType != null && goal.type != _filterType) {
        return false;
      }
      if (_filterStatus != null && goal.status != _filterStatus) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        return goal.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (goal.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      }
      return true;
    }).toList();

    switch (_sortOption) {
      case SortOption.name:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortOption.targetAmount:
        filtered.sort((a, b) => b.targetAmount.compareTo(a.targetAmount));
        break;
      case SortOption.progress:
        filtered.sort((a, b) {
          final progressA = a.targetAmount > 0 ? a.currentAmount / a.targetAmount : 0;
          final progressB = b.targetAmount > 0 ? b.currentAmount / b.targetAmount : 0;
          return progressB.compareTo(progressA);
        });
        break;
      case SortOption.targetDate:
        filtered.sort((a, b) {
          if (a.targetDate == null && b.targetDate == null) return 0;
          if (a.targetDate == null) return 1;
          if (b.targetDate == null) return -1;
          return a.targetDate!.compareTo(b.targetDate!);
        });
        break;
      case SortOption.createdDate:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGoalsList(),
                _buildAnalyticsView(),
                _buildSettingsView(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showAddGoalSheet(context),
              icon: const Icon(Icons.add),
              label: Text('goals.add'.tr()),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.1),
            Theme.of(context).primaryColor.withOpacity(0.05),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up,
                color: Theme.of(context).primaryColor,
                size: 28.w,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'goals.title'.tr(),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'goals.subtitle'.tr(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _showFilterDialog,
                icon: Icon(Icons.filter_list, color: Theme.of(context).primaryColor),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'goals.search'.tr(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () => setState(() => _searchQuery = ''),
                      icon: const Icon(Icons.clear),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(10.r),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        tabs: [
          Tab(text: 'goals.tabs.list'.tr()),
          Tab(text: 'goals.tabs.analytics'.tr()),
          Tab(text: 'goals.tabs.settings'.tr()),
        ],
      ),
    );
  }

  Widget _buildGoalsList() {
    return BlocBuilder<GoalsBloc, GoalsState>(
      builder: (context, state) {
        if (state is GoalsLoading) {
          return _buildLoadingState();
        }

        if (state is GoalsError) {
          return _buildErrorState(state.message);
        }

        if (state is GoalsLoaded) {
          final filteredGoals = _getFilteredGoals(state.goals);

          if (filteredGoals.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<GoalsBloc>().add(LoadGoalsEvent());
            },
            child: AnimatedList(
              key: _listKey,
              controller: _scrollController,
              initialItemCount: filteredGoals.length,
              itemBuilder: (context, index, animation) {
                return _buildGoalCard(filteredGoals[index], animation);
              },
            ),
          );
        }

        return const SizedBox.shrink();
      },
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
              height: 120.h,
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
          Icon(
            Icons.error_outline,
            size: 64.w,
            color: Colors.red[400],
          ),
          SizedBox(height: 16.h),
          Text(
            'goals.error.title'.tr(),
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
            onPressed: () => context.read<GoalsBloc>().add(LoadGoalsEvent()),
            child: Text('common.retry'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.trending_up,
            size: 64.w,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16.h),
          Text(
            'goals.empty.title'.tr(),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 8.h),
          Text(
            'goals.empty.description'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: () => _showAddGoalSheet(context),
            icon: const Icon(Icons.add),
            label: Text('goals.add.first'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(InvestmentGoal goal, Animation<double> animation) {
    final progress = goal.targetAmount > 0 
        ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;

    return SizeTransition(
      sizeFactor: animation,
      child: Card(
        margin: EdgeInsets.only(bottom: 12.h),
        elevation: 2,
        child: InkWell(
          onTap: () => _showGoalDetailSheet(context, goal),
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _getGoalTypeColor(goal.type).withOpacity(0.1),
                      child: Icon(
                        _getGoalTypeIcon(goal.type),
                        color: _getGoalTypeColor(goal.type),
                        size: 20.w,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (goal.description != null) ...[
                            SizedBox(height: 4.h),
                            Text(
                              goal.description!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    _StatusChip(status: goal.status),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${goal.currentAmount.toStringAsFixed(2)} ${goal.currency}',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'of ${goal.targetAmount.toStringAsFixed(2)} ${goal.currency}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: progress >= 1.0 ? Colors.green : null,
                          ),
                        ),
                        Text(
                          _getGoalTypeLabel(context, goal.type),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0 ? Colors.green : Theme.of(context).primaryColor,
                  ),
                ),
                if (goal.targetDate != null) ...[
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16.w, color: Colors.grey[600]),
                      SizedBox(width: 4.w),
                      Text(
                        'goals.target_date'.tr(args: [
                          goal.targetDate.toString().split(' ')[0]
                        ]),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ).animate().slideY(duration: 300.ms, begin: 0.1);
  }

  Widget _buildAnalyticsView() {
    return BlocBuilder<GoalsBloc, GoalsState>(
      builder: (context, state) {
        if (state is GoalsLoaded) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCards(state.goals),
                SizedBox(height: 24.h),
                _buildProgressChart(state.goals),
                SizedBox(height: 24.h),
                _buildGoalTypeDistribution(state.goals),
              ],
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildSummaryCards(List<InvestmentGoal> goals) {
    final totalGoals = goals.length;
    final completedGoals = goals.where((g) => g.status == GoalStatus.completed).length;
    final totalTarget = goals.fold<double>(0, (sum, goal) => sum + goal.targetAmount);
    final totalCurrent = goals.fold<double>(0, (sum, goal) => sum + goal.currentAmount);

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'goals.analytics.total_goals'.tr(),
            value: totalGoals.toString(),
            icon: Icons.list,
            color: Colors.blue,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _SummaryCard(
            title: 'goals.analytics.completed'.tr(),
            value: completedGoals.toString(),
            icon: Icons.check_circle,
            color: Colors.green,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _SummaryCard(
            title: 'goals.analytics.total_value'.tr(),
            value: '${totalCurrent.toStringAsFixed(0)} ${goals.firstOrNull?.currency ?? ''}',
            icon: Icons.account_balance,
            color: Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressChart(List<InvestmentGoal> goals) {
    final chartData = goals.map((goal) {
      final progress = goal.targetAmount > 0 ? (goal.currentAmount / goal.targetAmount) * 100 : 0;
      return GoalChartData(
        goal.name,
        progress,
        _getGoalTypeColor(goal.type),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'goals.analytics.progress_chart'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              height: 200.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: chartData.length,
                itemBuilder: (context, index) {
                  final data = chartData[index];
                  return Container(
                    width: 60.w,
                    margin: EdgeInsets.only(right: 8.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: 150.h * (data.progress / 100),
                          width: 40.w,
                          decoration: BoxDecoration(
                            color: data.color,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          '${data.progress.toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          data.name.length > 8 
                              ? '${data.name.substring(0, 8)}...'
                              : data.name,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalTypeDistribution(List<InvestmentGoal> goals) {
    final typeDistribution = <GoalType, int>{};
    for (final goal in goals) {
      typeDistribution[goal.type] = (typeDistribution[goal.type] ?? 0) + 1;
    }

    final total = goals.length;
    final chartData = typeDistribution.entries.map((entry) {
      return PieChartData(
        _getGoalTypeLabel(context, entry.key),
        entry.value,
        _getGoalTypeColor(entry.key),
        (entry.value / total) * 100,
      );
    }).toList();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'goals.analytics.type_distribution'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              height: 200.h,
              child: Wrap(
                spacing: 16.w,
                runSpacing: 16.h,
                children: chartData.map((data) {
                  return Container(
                    width: 100.w,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 60.w,
                          height: 60.w,
                          child: Stack(
                            children: [
                              CircularProgressIndicator(
                                value: data.percentage / 100,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(data.color),
                                strokeWidth: 8.w,
                              ),
                              Center(
                                child: Text(
                                  '${data.percentage.toStringAsFixed(0)}%',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          data.category.length > 12
                              ? '${data.category.substring(0, 12)}...'
                              : data.category,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          '${data.value} goals',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsView() {
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: Text('goals.settings.show_completed'.tr()),
                subtitle: Text('goals.settings.show_completed_desc'.tr()),
                value: _showCompletedGoals,
                onChanged: (value) => setState(() => _showCompletedGoals = value),
              ),
              const Divider(),
              ListTile(
                title: Text('goals.settings.default_currency'.tr()),
                subtitle: Text('goals.settings.default_currency_desc'.tr()),
                trailing: const Text('EUR'),
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('goals.filter.title'.tr()),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<GoalType>(
                  value: _filterType,
                  decoration: InputDecoration(
                    labelText: 'goals.filter.type'.tr(),
                  ),
                  items: GoalType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_getGoalTypeLabel(context, type)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _filterType = value),
                ),
                SizedBox(height: 16.h),
                DropdownButtonFormField<GoalStatus>(
                  value: _filterStatus,
                  decoration: InputDecoration(
                    labelText: 'goals.filter.status'.tr(),
                  ),
                  items: GoalStatus.values.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(_getStatusLabel(context, status)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _filterStatus = value),
                ),
                SizedBox(height: 16.h),
                DropdownButtonFormField<SortOption>(
                  value: _sortOption,
                  decoration: InputDecoration(
                    labelText: 'goals.filter.sort'.tr(),
                  ),
                  items: SortOption.values.map((option) {
                    return DropdownMenuItem(
                      value: option,
                      child: Text(_getSortOptionLabel(context, option)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _sortOption = value ?? SortOption.name),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _filterType = null;
                _filterStatus = null;
                _sortOption = SortOption.name;
              });
              Navigator.of(context).pop();
            },
            child: Text('common.clear'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  void _showAddGoalSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.add, color: Theme.of(context).primaryColor),
                  SizedBox(width: 8.w),
                  Text(
                    'goals.add.title'.tr(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Text(
                'goals.add.coming_soon'.tr(),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGoalDetailSheet(BuildContext context, InvestmentGoal goal) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getGoalTypeColor(goal.type).withOpacity(0.1),
                    child: Icon(
                      _getGoalTypeIcon(goal.type),
                      color: _getGoalTypeColor(goal.type),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _getGoalTypeLabel(context, goal.type),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(status: goal.status),
                ],
              ),
              SizedBox(height: 24.h),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildDetailRow(
                      context,
                      'goals.details.description'.tr(),
                      goal.description ?? 'goals.details.no_description'.tr(),
                    ),
                    _buildDetailRow(
                      context,
                      'goals.details.target_amount'.tr(),
                      '${goal.targetAmount.toStringAsFixed(2)} ${goal.currency}',
                    ),
                    _buildDetailRow(
                      context,
                      'goals.details.current_amount'.tr(),
                      '${goal.currentAmount.toStringAsFixed(2)} ${goal.currency}',
                    ),
                    _buildDetailRow(
                      context,
                      'goals.details.progress'.tr(),
                      '${((goal.currentAmount / goal.targetAmount) * 100).toStringAsFixed(1)}%',
                    ),
                    if (goal.targetDate != null)
                      _buildDetailRow(
                        context,
                        'goals.details.target_date'.tr(),
                        goal.targetDate.toString().split(' ')[0],
                      ),
                    if (goal.monthlyContribution != null)
                      _buildDetailRow(
                        context,
                        'goals.details.monthly_contribution'.tr(),
                        '${goal.monthlyContribution!.toStringAsFixed(2)} ${goal.currency}',
                      ),
                    if (goal.targetAllocation != null) ...[
                      SizedBox(height: 16.h),
                      Text(
                        'goals.details.asset_allocation'.tr(),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      ...goal.targetAllocation!.assetTypeTargets.entries.map(
                        (entry) => _buildDetailRow(
                          context,
                          _assetTypeLabel(context, entry.key),
                          '${entry.value.toStringAsFixed(0)}%',
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

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Color _getGoalTypeColor(GoalType type) {
    switch (type) {
      case GoalType.retirement:
        return Colors.purple;
      case GoalType.emergency:
        return Colors.red;
      case GoalType.house:
        return Colors.blue;
      case GoalType.education:
        return Colors.green;
      case GoalType.travel:
        return Colors.orange;
      case GoalType.custom:
        return Colors.grey;
    }
  }

  IconData _getGoalTypeIcon(GoalType type) {
    switch (type) {
      case GoalType.retirement:
        return Icons.beach_access;
      case GoalType.emergency:
        return Icons.health_and_safety;
      case GoalType.house:
        return Icons.home;
      case GoalType.education:
        return Icons.school;
      case GoalType.travel:
        return Icons.flight;
      case GoalType.custom:
        return Icons.star;
    }
  }

  String _getGoalTypeLabel(BuildContext context, GoalType type) {
    switch (type) {
      case GoalType.retirement:
        return 'goals.types.retirement'.tr();
      case GoalType.emergency:
        return 'goals.types.emergency'.tr();
      case GoalType.house:
        return 'goals.types.house'.tr();
      case GoalType.education:
        return 'goals.types.education'.tr();
      case GoalType.travel:
        return 'goals.types.travel'.tr();
      case GoalType.custom:
        return 'goals.types.custom'.tr();
    }
  }

  String _getStatusLabel(BuildContext context, GoalStatus status) {
    switch (status) {
      case GoalStatus.active:
        return 'goals.status.active'.tr();
      case GoalStatus.completed:
        return 'goals.status.completed'.tr();
      case GoalStatus.paused:
        return 'goals.status.paused'.tr();
      case GoalStatus.cancelled:
        return 'goals.status.cancelled'.tr();
    }
  }

  String _getSortOptionLabel(BuildContext context, SortOption option) {
    switch (option) {
      case SortOption.name:
        return 'goals.sort.name'.tr();
      case SortOption.targetAmount:
        return 'goals.sort.target_amount'.tr();
      case SortOption.progress:
        return 'goals.sort.progress'.tr();
      case SortOption.targetDate:
        return 'goals.sort.target_date'.tr();
      case SortOption.createdDate:
        return 'goals.sort.created_date'.tr();
    }
  }

  String _assetTypeLabel(BuildContext context, String assetType) {
    switch (assetType.toLowerCase()) {
      case 'stocks':
        return 'portfolio.filters.stocks'.tr();
      case 'bonds':
        return 'portfolio.filters.bonds'.tr();
      case 'etfs':
        return 'portfolio.filters.etfs'.tr();
      case 'crypto':
        return 'portfolio.filters.crypto'.tr();
      case 'commodities':
        return 'portfolio.filters.commodities'.tr();
      case 'cash':
        return 'portfolio.filters.cash'.tr();
      default:
        return assetType;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final GoalStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case GoalStatus.active:
        color = Colors.blue;
        label = 'goals.status.active'.tr();
        break;
      case GoalStatus.completed:
        color = Colors.green;
        label = 'goals.status.completed'.tr();
        break;
      case GoalStatus.paused:
        color = Colors.orange;
        label = 'goals.status.paused'.tr();
        break;
      case GoalStatus.cancelled:
        color = Colors.red;
        label = 'goals.status.cancelled'.tr();
        break;
    }

    return Chip(
      label: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12.sp,
        ),
      ),
      backgroundColor: color,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24.w),
            SizedBox(height: 8.h),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GoalChartData {
  final String name;
  final num progress;
  final Color color;

  GoalChartData(this.name, this.progress, this.color);
}

class PieChartData {
  final String category;
  final int value;
  final Color color;
  final double percentage;

  PieChartData(this.category, this.value, this.color, this.percentage);
}

enum SortOption {
  name,
  targetAmount,
  progress,
  targetDate,
  createdDate,
}
