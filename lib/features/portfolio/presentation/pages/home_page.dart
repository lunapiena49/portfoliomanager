import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/portfolio_bloc.dart';
import '../widgets/portfolio_summary_card.dart';
import '../widgets/position_list_item.dart';
import '../widgets/empty_portfolio_widget.dart';
import '../widgets/portfolio_treemap_section.dart';
import '../../domain/entities/portfolio_entities.dart';
import '../../../market/presentation/pages/market_tab.dart' as market;
import '../../../rebalancing/presentation/pages/rebalancing_tab.dart' as rebalancing;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          PortfolioTab(),
          market.MarketTab(),
          rebalancing.RebalancingTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_balance_wallet),
            label: 'navigation.portfolio_short'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.show_chart),
            label: 'navigation.market_short'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.balance),
            label: 'navigation.rebalancing_short'.tr(),
          ),
        ],
      ),
    );
  }

}

enum _PortfolioMenuAction {
  analysis,
  importPortfolio,
  settings,
  help,
  managePortfolios,
}

/// Portfolio Tab
class PortfolioTab extends StatelessWidget {
  const PortfolioTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PortfolioBloc, PortfolioState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text('portfolio.title'.tr()),
            actions: _buildAppBarActions(context, state),
          ),
          body: _buildBody(context, state),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push('/home/add-position'),
            icon: const Icon(Icons.add),
            label: Text(
              'portfolio.add_position'.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context, PortfolioState state) {
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
        if (state is PortfolioLoaded)
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'portfolio.manage_portfolios'.tr(),
            onPressed: () => _showPortfolioManager(context, state),
          ),
      ];
    }

    return [
      PopupMenuButton<_PortfolioMenuAction>(
        icon: const Icon(Icons.menu),
        onSelected: (action) {
          switch (action) {
            case _PortfolioMenuAction.analysis:
              context.push(RouteNames.analysis);
              break;
            case _PortfolioMenuAction.importPortfolio:
              context.push('${RouteNames.home}/import');
              break;
            case _PortfolioMenuAction.settings:
              context.push(RouteNames.settings);
              break;
            case _PortfolioMenuAction.help:
              context.push(RouteNames.guide);
              break;
            case _PortfolioMenuAction.managePortfolios:
              if (state is PortfolioLoaded) {
                _showPortfolioManager(context, state);
              }
              break;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _PortfolioMenuAction.analysis,
            child: _buildMenuItem(
              context,
              Icons.auto_awesome,
              'navigation.analysis'.tr(),
            ),
          ),
          PopupMenuItem(
            value: _PortfolioMenuAction.importPortfolio,
            child: _buildMenuItem(
              context,
              Icons.upload_file,
              'portfolio.import_portfolio'.tr(),
            ),
          ),
          PopupMenuItem(
            value: _PortfolioMenuAction.settings,
            child: _buildMenuItem(
              context,
              Icons.settings,
              'navigation.settings'.tr(),
            ),
          ),
          PopupMenuItem(
            value: _PortfolioMenuAction.help,
            child: _buildMenuItem(
              context,
              Icons.help_outline,
              'common.help'.tr(),
            ),
          ),
          if (state is PortfolioLoaded)
            PopupMenuItem(
              value: _PortfolioMenuAction.managePortfolios,
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

  Widget _buildBody(BuildContext context, PortfolioState state) {
    if (state is PortfolioLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is PortfolioEmpty) {
      return const EmptyPortfolioWidget();
    }

    if (state is PortfolioError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64.w, color: AppTheme.errorColor),
            SizedBox(height: 16.h),
            Text(state.message.tr()),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () => context.read<PortfolioBloc>().add(LoadPortfolioEvent()),
              child: Text('common.retry'.tr()),
            ),
          ],
        ),
      );
    }

    if (state is PortfolioLoaded) {
      final positionCount = state.filteredPositions.length;
      return RefreshIndicator(
        onRefresh: () async {
          context.read<PortfolioBloc>().add(LoadPortfolioEvent());
        },
        child: CustomScrollView(
          slivers: [
            // Summary Card
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: PortfolioSummaryCard(portfolio: state.portfolio),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
                child: PortfolioTreemapSection(portfolio: state.portfolio),
              ),
            ),

            // Filter chips
            SliverToBoxAdapter(
              child: _buildFilterChips(context, state),
            ),

            // Positions header
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'portfolio.positions'.tr(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      (positionCount == 1
                              ? 'portfolio.position_count_one'
                              : 'portfolio.position_count_other')
                          .tr(namedArgs: {'count': positionCount.toString()}),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),

            // Positions list
            if (state.filteredPositions.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32.w),
                  child: Center(
                    child: Text(
                      'portfolio.no_positions'.tr(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final position = state.filteredPositions[index];
                    return PositionListItem(
                      position: position,
                      baseCurrency: state.portfolio.baseCurrency,
                      onTap: () => context.push('${RouteNames.home}/position/${position.id}'),
                    );
                  },
                  childCount: state.filteredPositions.length,
                ),
              ),

            // Bottom padding for FAB
            SliverToBoxAdapter(
              child: SizedBox(height: 80.h),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildFilterChips(BuildContext context, PortfolioLoaded state) {
    const macroAssetTypes = [
      'stocks',
      'bonds',
      'commodities',
      'crypto',
      'cash',
      'unassigned',
    ];
    final selectedFilter = state.filterAssetType?.toLowerCase();
    final chips = <Widget>[
      FilterChip(
        label: Text('portfolio.filters.all'.tr()),
        selected: state.filterAssetType == null,
        onSelected: (_) {
          context.read<PortfolioBloc>().add(
                const FilterPositionsEvent(assetType: null),
              );
        },
      ),
      ...macroAssetTypes.map((type) {
        return FilterChip(
          label: Text(_assetTypeLabel(context, type)),
          selected: selectedFilter == type,
          onSelected: (_) {
            context.read<PortfolioBloc>().add(
                  FilterPositionsEvent(
                    assetType: selectedFilter == type ? null : type,
                  ),
                );
          },
        );
      }),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: chips,
      ),
    );
  }

  String _assetTypeLabel(BuildContext context, String assetType) {
    switch (assetType.toLowerCase()) {
      case 'stocks':
        return 'portfolio.filters.stocks'.tr();
      case 'etfs':
        return 'portfolio.filters.etfs'.tr();
      case 'crypto':
        return 'portfolio.filters.crypto'.tr();
      case 'bonds':
        return 'portfolio.filters.bonds'.tr();
      case 'options':
        return 'portfolio.filters.options'.tr();
      case 'futures':
        return 'portfolio.filters.futures'.tr();
      case 'cash':
        return 'portfolio.filters.cash'.tr();
      case 'commodities':
        return 'portfolio.filters.commodities'.tr();
      case 'unassigned':
        return 'portfolio.filters.unassigned'.tr();
      default:
        return assetType;
    }
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
                          isCurrent ? Icons.check_circle : Icons.account_balance_wallet,
                          color: isCurrent ? Theme.of(context).primaryColor : null,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'portfolio.rename_portfolio'.tr(),
                          onPressed: () => _showRenameDialog(context, portfolio),
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
      text: portfolio.accountName.isNotEmpty ? portfolio.accountName : portfolio.accountId,
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
}