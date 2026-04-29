import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/market_data_providers.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/api/gemini_service.dart';
import '../../../onboarding/presentation/bloc/onboarding_bloc.dart';
import '../bloc/settings_bloc.dart';

/// Settings page.
///
/// Surface area: general (lang/currency/theme), AI (Gemini), market-data
/// providers (EODHD, FMP, Alpha Vantage, Twelve Data, Finnhub, Polygon,
/// Marketstack, Tiingo, Nasdaq Data Link, Stooq), refresh-interval picker,
/// data management, about.
///
/// The market-data section is rendered from the static [ProviderCatalog]:
/// add a provider there and it shows up here automatically.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _geminiApiKeyController =
      TextEditingController();
  final Map<MarketDataProvider, TextEditingController> _providerControllers =
      {};
  final Map<MarketDataProvider, bool> _providerObscure = {};

  bool _isTestingConnection = false;
  bool _obscureGeminiApiKey = true;
  String _lastSyncedGeminiApiKey = '';
  final Map<MarketDataProvider, String> _lastSyncedProviderKeys = {};

  @override
  void initState() {
    super.initState();
    for (final provider in MarketDataProvider.values) {
      _providerControllers[provider] = TextEditingController();
      _providerObscure[provider] = true;
    }
    context.read<SettingsBloc>().add(LoadSettingsEvent());
    final state = context.read<SettingsBloc>().state;
    if (state is SettingsLoaded) {
      _hydrateFromState(state);
    }
  }

  void _hydrateFromState(SettingsLoaded state) {
    if (state.settings.geminiApiKey != null) {
      _geminiApiKeyController.text = state.settings.geminiApiKey!;
      _lastSyncedGeminiApiKey = state.settings.geminiApiKey!;
    }
    for (final provider in MarketDataProvider.values) {
      final value = state.settings.providerApiKeys[provider] ?? '';
      _providerControllers[provider]!.text = value;
      _lastSyncedProviderKeys[provider] = value;
    }
  }

  @override
  void dispose() {
    _geminiApiKeyController.dispose();
    for (final c in _providerControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        if (state is! SettingsLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        _syncControllersFromState(state);

        return Scaffold(
          appBar: AppBar(
            title: Text('settings.title'.tr()),
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: 'common.help'.tr(),
                onPressed: () => context.push(RouteNames.guide),
              ),
            ],
          ),
          body: ListView(
            children: [
              _buildSectionHeader('settings.general.title'.tr()),
              _buildLanguageTile(context, state),
              _buildCurrencyTile(context, state),
              _buildThemeTile(context, state),

              _buildSectionHeader('settings.market_data.title'.tr()),
              _buildMarketDataIntro(context),
              _buildRefreshIntervalTile(context, state),
              ..._buildProviderTiles(context, state),

              _buildSectionHeader('settings.ai.title'.tr()),
              _buildGeminiApiKeyTile(context),

              _buildSectionHeader('settings.data.title'.tr()),
              _buildDataTile(
                context,
                icon: Icons.upload,
                title: 'settings.data.export'.tr(),
                onTap: () {
                  // TODO: Implement export
                },
              ),
              _buildDataTile(
                context,
                icon: Icons.delete_forever,
                title: 'settings.data.clear'.tr(),
                isDestructive: true,
                onTap: () => _showClearDataDialog(context),
              ),

              _buildSectionHeader('settings.about.title'.tr()),
              _buildAboutTile(
                context,
                icon: Icons.help_outline,
                title: 'guide.title'.tr(),
                onTap: () => context.push(RouteNames.guide),
              ),
              _buildAboutTile(
                context,
                icon: Icons.gavel_outlined,
                title: 'settings.about.legal_documents'.tr(),
                onTap: () => context.push(RouteNames.legalDocuments),
              ),
              _buildAboutTile(
                context,
                icon: Icons.replay,
                title: 'settings.about.review_onboarding'.tr(),
                onTap: () => _resetOnboarding(context),
              ),
              _buildAboutTile(
                context,
                icon: Icons.info_outline,
                title: 'settings.about.version'.tr(),
                trailing: Text(
                  AppConstants.appVersion,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),

              SizedBox(height: 32.h),
            ],
          ),
        );
      },
    );
  }

  void _syncControllersFromState(SettingsLoaded state) {
    final geminiApiKey = state.settings.geminiApiKey ?? '';
    if (geminiApiKey != _lastSyncedGeminiApiKey) {
      _lastSyncedGeminiApiKey = geminiApiKey;
      if (_geminiApiKeyController.text != geminiApiKey) {
        _geminiApiKeyController.text = geminiApiKey;
      }
    }
    for (final provider in MarketDataProvider.values) {
      final value = state.settings.providerApiKeys[provider] ?? '';
      if (value != _lastSyncedProviderKeys[provider]) {
        _lastSyncedProviderKeys[provider] = value;
        final controller = _providerControllers[provider]!;
        if (controller.text != value) {
          controller.text = value;
        }
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 8.h),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildMarketDataIntro(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline,
                size: 18.r, color: theme.colorScheme.primary),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                'settings.market_data.intro'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshIntervalTile(
    BuildContext context,
    SettingsLoaded state,
  ) {
    final interval = state.settings.marketDataRefreshInterval;
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: ListTile(
        leading:
            Icon(Icons.schedule, color: Theme.of(context).primaryColor),
        title: Text('settings.market_data.refresh_interval.title'.tr()),
        subtitle: Text(
          'settings.market_data.refresh_interval.options.${interval.name}'
              .tr(),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showRefreshIntervalDialog(context, state),
      ),
    );
  }

  Future<void> _showRefreshIntervalDialog(
    BuildContext context,
    SettingsLoaded state,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('settings.market_data.refresh_interval.title'.tr()),
          content: SingleChildScrollView(
            child: RadioGroup<MarketDataRefreshInterval>(
              groupValue: state.settings.marketDataRefreshInterval,
              onChanged: (value) {
                if (value == null) return;
                context
                    .read<SettingsBloc>()
                    .add(UpdateMarketDataRefreshIntervalEvent(value));
                Navigator.of(dialogContext).pop();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'settings.market_data.refresh_interval.description'.tr(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  SizedBox(height: 12.h),
                  ...MarketDataRefreshInterval.values.map((opt) {
                    return RadioListTile<MarketDataRefreshInterval>(
                      title: Text(
                        'settings.market_data.refresh_interval.options.${opt.name}'
                            .tr(),
                      ),
                      subtitle: Text(
                        'settings.market_data.refresh_interval.descriptions.${opt.name}'
                            .tr(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      value: opt,
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildProviderTiles(
    BuildContext context,
    SettingsLoaded state,
  ) {
    return ProviderCatalog.all.map((cfg) {
      return _buildProviderTile(context, cfg, state);
    }).toList(growable: false);
  }

  Widget _buildProviderTile(
    BuildContext context,
    ProviderConfig cfg,
    SettingsLoaded state,
  ) {
    final controller = _providerControllers[cfg.id]!;
    final obscure = _providerObscure[cfg.id] ?? true;
    final hasKey = state.settings.hasProviderKey(cfg.id);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      child: ExpansionTile(
        leading: CircleAvatar(
          radius: 16.r,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            _iconFor(cfg.id),
            size: 16.r,
            color: Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          cfg.displayName,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Text(
          'settings.providers.${cfg.id.name}.short'.tr(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: hasKey
            ? Icon(Icons.check_circle,
                color: AppTheme.successColor, size: 20.r)
            : (cfg.requiresKey
                ? const Icon(Icons.radio_button_unchecked, size: 20)
                : Icon(Icons.public,
                    color: AppTheme.successColor, size: 20.r)),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'settings.providers.${cfg.id.name}.description'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: 8.h),
                _buildProviderQuotaChip(context, cfg),
                SizedBox(height: 12.h),
                if (cfg.requiresKey)
                  TextField(
                    controller: controller,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'settings.providers.api_key_label'
                          .tr(namedArgs: {'provider': cfg.displayName}),
                      hintText: 'settings.providers.api_key_hint'.tr(),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(obscure
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () => setState(() {
                              _providerObscure[cfg.id] = !obscure;
                            }),
                          ),
                          IconButton(
                            icon: const Icon(Icons.save),
                            onPressed: () => _saveProviderKey(cfg),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'common.delete'.tr(),
                            onPressed: () => _clearProviderKey(cfg),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: AppTheme.successColor, size: 18.r),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'settings.providers.no_key_required'.tr(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: 12.h),
                _buildEndpointRow(context, cfg),
                SizedBox(height: 12.h),
                _buildProviderActionRow(context, cfg),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderQuotaChip(BuildContext context, ProviderConfig cfg) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6.w,
      runSpacing: 6.h,
      children: [
        _chip(
          context,
          icon: Icons.electric_bolt,
          text: 'settings.providers.${cfg.id.name}.free_quota'.tr(),
          color: theme.colorScheme.tertiary,
        ),
        if (cfg.supportsRealtime)
          _chip(
            context,
            icon: Icons.bolt,
            text: 'settings.providers.tag_realtime'.tr(),
            color: theme.colorScheme.primary,
          ),
        if (cfg.supportsHistoric)
          _chip(
            context,
            icon: Icons.history,
            text: 'settings.providers.tag_historic'.tr(),
            color: theme.colorScheme.secondary,
          ),
      ],
    );
  }

  Widget _chip(
    BuildContext context, {
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12.r),
          SizedBox(width: 4.w),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndpointRow(BuildContext context, ProviderConfig cfg) {
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: SelectableText(
              cfg.exampleEndpoint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.3,
                  ),
            ),
          ),
          IconButton(
            iconSize: 18.r,
            tooltip: 'settings.providers.copy_endpoint'.tr(),
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: cfg.exampleEndpoint),
              );
              if (!mounted) return;
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('settings.providers.endpoint_copied'.tr()),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProviderActionRow(BuildContext context, ProviderConfig cfg) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text('settings.providers.signup'.tr()),
          onPressed: () => _copyToClipboard(cfg.signupUrl),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.menu_book_outlined, size: 16),
          label: Text('settings.providers.docs'.tr()),
          onPressed: () => _copyToClipboard(cfg.docsUrl),
        ),
      ],
    );
  }

  Future<void> _copyToClipboard(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('settings.providers.url_copied'.tr())),
    );
  }

  void _saveProviderKey(ProviderConfig cfg) {
    final controller = _providerControllers[cfg.id]!;
    context
        .read<SettingsBloc>()
        .add(UpdateProviderApiKeyEvent(cfg.id, controller.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('settings.providers.api_key_saved'
            .tr(namedArgs: {'provider': cfg.displayName})),
      ),
    );
  }

  void _clearProviderKey(ProviderConfig cfg) {
    _providerControllers[cfg.id]!.clear();
    context
        .read<SettingsBloc>()
        .add(UpdateProviderApiKeyEvent(cfg.id, null));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('settings.providers.api_key_cleared'
            .tr(namedArgs: {'provider': cfg.displayName})),
      ),
    );
  }

  IconData _iconFor(MarketDataProvider id) {
    switch (id) {
      case MarketDataProvider.eodhd:
        return Icons.bar_chart;
      case MarketDataProvider.fmp:
        return Icons.query_stats;
      case MarketDataProvider.alphaVantage:
        return Icons.text_format;
      case MarketDataProvider.twelveData:
        return Icons.show_chart;
      case MarketDataProvider.finnhub:
        return Icons.bolt;
      case MarketDataProvider.polygon:
        return Icons.public;
      case MarketDataProvider.marketstack:
        return Icons.stacked_line_chart;
      case MarketDataProvider.tiingo:
        return Icons.timeline;
      case MarketDataProvider.nasdaqDataLink:
        return Icons.account_tree_outlined;
      case MarketDataProvider.stooq:
        return Icons.cloud_download;
    }
  }

  Widget _buildLanguageTile(BuildContext context, SettingsLoaded state) {
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text('settings.general.language'.tr()),
      subtitle:
          Text(AppLocalization.getLanguageName(state.settings.languageCode)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showLanguageDialog(context, state),
    );
  }

  Widget _buildCurrencyTile(BuildContext context, SettingsLoaded state) {
    return ListTile(
      leading: const Icon(Icons.attach_money),
      title: Text('settings.general.currency'.tr()),
      subtitle: Text(state.settings.baseCurrency),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showCurrencyDialog(context, state),
    );
  }

  Widget _buildThemeTile(BuildContext context, SettingsLoaded state) {
    return ListTile(
      leading: const Icon(Icons.palette),
      title: Text('settings.general.theme'.tr()),
      subtitle: Text(_getThemeName(state.settings.themeMode)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeDialog(context, state),
    );
  }

  Widget _buildGeminiApiKeyTile(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.key, color: Theme.of(context).primaryColor),
                SizedBox(width: 12.w),
                Text(
                  'settings.ai.api_key'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _geminiApiKeyController,
              obscureText: _obscureGeminiApiKey,
              decoration: InputDecoration(
                hintText: 'settings.ai.api_key_hint'.tr(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _obscureGeminiApiKey
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => setState(
                        () => _obscureGeminiApiKey = !_obscureGeminiApiKey,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.save),
                      onPressed: () {
                        context.read<SettingsBloc>().add(
                              UpdateGeminiApiKeyEvent(
                                _geminiApiKeyController.text,
                              ),
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('settings.ai.api_key_saved'.tr()),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12.h),
            OutlinedButton.icon(
              onPressed:
                  _isTestingConnection ? null : () => _testConnection(context),
              icon: _isTestingConnection
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi),
              label: Text('settings.ai.test_connection'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? AppTheme.errorColor : null),
      title: Text(
        title,
        style: TextStyle(color: isDestructive ? AppTheme.errorColor : null),
      ),
      onTap: onTap,
    );
  }

  Widget _buildAboutTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing:
          trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }

  String _getThemeName(String mode) {
    switch (mode) {
      case 'light':
        return 'settings.general.theme_light'.tr();
      case 'dark':
        return 'settings.general.theme_dark'.tr();
      default:
        return 'settings.general.theme_system'.tr();
    }
  }

  Future<void> _showLanguageDialog(
      BuildContext context, SettingsLoaded state) async {
    final languages = AppLocalization.getAllLanguages();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.general.language'.tr()),
        content: RadioGroup<String>(
          groupValue: state.settings.languageCode,
          onChanged: (value) {
            if (value != null) {
              context.read<SettingsBloc>().add(UpdateLanguageEvent(value));
              Navigator.pop(context);
            }
          },
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: languages.map((lang) {
                return RadioListTile<String>(
                  title: Text('${lang['flag']} ${lang['nativeName']}'),
                  value: lang['code']!,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCurrencyDialog(
      BuildContext context, SettingsLoaded state) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.general.currency'.tr()),
        content: RadioGroup<String>(
          groupValue: state.settings.baseCurrency,
          onChanged: (value) {
            if (value != null) {
              context
                  .read<SettingsBloc>()
                  .add(UpdateBaseCurrencyEvent(value));
              Navigator.pop(context);
            }
          },
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: AppConstants.supportedCurrencies.map((currency) {
                return RadioListTile<String>(
                  title: Text(currency),
                  value: currency,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showThemeDialog(
      BuildContext context, SettingsLoaded state) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.general.theme'.tr()),
        content: RadioGroup<String>(
          groupValue: state.settings.themeMode,
          onChanged: (value) {
            if (value == null) return;
            context.read<SettingsBloc>().add(UpdateThemeModeEvent(value));
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text('settings.general.theme_system'.tr()),
                value: 'system',
              ),
              RadioListTile<String>(
                title: Text('settings.general.theme_light'.tr()),
                value: 'light',
              ),
              RadioListTile<String>(
                title: Text('settings.general.theme_dark'.tr()),
                value: 'dark',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showClearDataDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.data.clear'.tr()),
        content: Text('settings.data.clear_confirm_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;
    context.read<SettingsBloc>().add(ClearAllDataEvent());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('settings.data.clear_success'.tr())),
    );
  }

  Future<void> _testConnection(BuildContext context) async {
    setState(() => _isTestingConnection = true);

    final geminiService = GeminiService();
    geminiService.setApiKey(_geminiApiKeyController.text);

    final success = await geminiService.testConnection();

    setState(() => _isTestingConnection = false);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'settings.ai.connection_success'.tr()
                : 'settings.ai.connection_error'.tr(),
          ),
          backgroundColor:
              success ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    }
  }

  void _resetOnboarding(BuildContext context) {
    context.read<OnboardingBloc>().add(ResetOnboardingEvent());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('settings.about.onboarding_reset_message'.tr()),
      ),
    );
    context.go(RouteNames.splash);
  }
}
