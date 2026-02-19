import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/api/gemini_service.dart';
import '../../../onboarding/presentation/bloc/onboarding_bloc.dart';
import '../bloc/settings_bloc.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _geminiApiKeyController =
      TextEditingController();
  final TextEditingController _fmpApiKeyController = TextEditingController();
  final TextEditingController _eodhdApiKeyController = TextEditingController();
  bool _isTestingConnection = false;
  bool _obscureGeminiApiKey = true;
  bool _obscureFmpApiKey = true;
  bool _obscureEodhdApiKey = true;
  String _lastSyncedGeminiApiKey = '';
  String _lastSyncedFmpApiKey = '';
  String _lastSyncedEodhdApiKey = '';

  @override
  void initState() {
    super.initState();
    context.read<SettingsBloc>().add(LoadSettingsEvent());
    final state = context.read<SettingsBloc>().state;
    if (state is SettingsLoaded) {
      if (state.settings.geminiApiKey != null) {
        _geminiApiKeyController.text = state.settings.geminiApiKey!;
        _lastSyncedGeminiApiKey = state.settings.geminiApiKey!;
      }
      if (state.settings.fmpApiKey != null) {
        _fmpApiKeyController.text = state.settings.fmpApiKey!;
        _lastSyncedFmpApiKey = state.settings.fmpApiKey!;
      }
      if (state.settings.eodhdApiKey != null) {
        _eodhdApiKeyController.text = state.settings.eodhdApiKey!;
        _lastSyncedEodhdApiKey = state.settings.eodhdApiKey!;
      }
    }
  }

  @override
  void dispose() {
    _geminiApiKeyController.dispose();
    _fmpApiKeyController.dispose();
    _eodhdApiKeyController.dispose();
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

        final geminiApiKey = state.settings.geminiApiKey ?? '';
        if (geminiApiKey != _lastSyncedGeminiApiKey) {
          _lastSyncedGeminiApiKey = geminiApiKey;
          if (_geminiApiKeyController.text != geminiApiKey) {
            _geminiApiKeyController.text = geminiApiKey;
          }
        }
        final fmpApiKey = state.settings.fmpApiKey ?? '';
        if (fmpApiKey != _lastSyncedFmpApiKey) {
          _lastSyncedFmpApiKey = fmpApiKey;
          if (_fmpApiKeyController.text != fmpApiKey) {
            _fmpApiKeyController.text = fmpApiKey;
          }
        }
        final eodhdApiKey = state.settings.eodhdApiKey ?? '';
        if (eodhdApiKey != _lastSyncedEodhdApiKey) {
          _lastSyncedEodhdApiKey = eodhdApiKey;
          if (_eodhdApiKeyController.text != eodhdApiKey) {
            _eodhdApiKeyController.text = eodhdApiKey;
          }
        }

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
              // General Section
              _buildSectionHeader('settings.general.title'.tr()),
              _buildLanguageTile(context, state),
              _buildCurrencyTile(context, state),
              _buildThemeTile(context, state),

              // Market Data Section (EODHD — primary optional key)
              _buildSectionHeader('settings.eodhd.title'.tr()),
              _buildEodhdApiKeyTile(context),

              // AI Section
              _buildSectionHeader('settings.ai.title'.tr()),
              _buildGeminiApiKeyTile(context),
              _buildFmpApiKeyTile(context),

              // Data Section
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

              // About Section
              _buildSectionHeader('settings.about.title'.tr()),
              _buildAboutTile(
                context,
                icon: Icons.help_outline,
                title: 'guide.title'.tr(),
                onTap: () => context.push(RouteNames.guide),
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

  Widget _buildFmpApiKeyTile(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.query_stats, color: Theme.of(context).primaryColor),
                SizedBox(width: 12.w),
                Text(
                  'settings.fmp.api_key'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _fmpApiKeyController,
              obscureText: _obscureFmpApiKey,
              decoration: InputDecoration(
                hintText: 'settings.fmp.api_key_hint'.tr(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _obscureFmpApiKey
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => setState(
                        () => _obscureFmpApiKey = !_obscureFmpApiKey,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.save),
                      onPressed: () {
                        context.read<SettingsBloc>().add(
                              UpdateFmpApiKeyEvent(_fmpApiKeyController.text),
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('settings.fmp.api_key_saved'.tr()),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEodhdApiKeyTile(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: Theme.of(context).primaryColor),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'settings.eodhd.api_key'.tr(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'settings.eodhd.api_key_optional_hint'.tr(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _eodhdApiKeyController,
              obscureText: _obscureEodhdApiKey,
              decoration: InputDecoration(
                hintText: 'settings.eodhd.api_key_hint'.tr(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _obscureEodhdApiKey
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => setState(
                        () => _obscureEodhdApiKey = !_obscureEodhdApiKey,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.save),
                      onPressed: () {
                        context.read<SettingsBloc>().add(
                              UpdateEodhdApiKeyEvent(
                                _eodhdApiKeyController.text,
                              ),
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('settings.eodhd.api_key_saved'.tr()),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageTile(BuildContext context, SettingsLoaded state) {
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text('settings.general.language'.tr()),
      subtitle: Text(AppLocalization.getLanguageName(state.settings.languageCode)),
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
                          SnackBar(content: Text('settings.ai.api_key_saved'.tr())),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12.h),
            OutlinedButton.icon(
              onPressed: _isTestingConnection ? null : () => _testConnection(context),
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
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
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

  Future<void> _showLanguageDialog(BuildContext context, SettingsLoaded state) async {
    final languages = AppLocalization.getAllLanguages();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.general.language'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: languages.map((lang) {
              return RadioListTile<String>(
                title: Text('${lang['flag']} ${lang['nativeName']}'),
                value: lang['code']!,
                groupValue: state.settings.languageCode,
                onChanged: (value) {
                  if (value != null) {
                    context.read<SettingsBloc>().add(UpdateLanguageEvent(value));
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _showCurrencyDialog(BuildContext context, SettingsLoaded state) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.general.currency'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppConstants.supportedCurrencies.map((currency) {
              return RadioListTile<String>(
                title: Text(currency),
                value: currency,
                groupValue: state.settings.baseCurrency,
                onChanged: (value) {
                  if (value != null) {
                    context.read<SettingsBloc>().add(UpdateBaseCurrencyEvent(value));
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _showThemeDialog(BuildContext context, SettingsLoaded state) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.general.theme'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Text('settings.general.theme_system'.tr()),
              value: 'system',
              groupValue: state.settings.themeMode,
              onChanged: (value) {
                context.read<SettingsBloc>().add(UpdateThemeModeEvent(value!));
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: Text('settings.general.theme_light'.tr()),
              value: 'light',
              groupValue: state.settings.themeMode,
              onChanged: (value) {
                context.read<SettingsBloc>().add(UpdateThemeModeEvent(value!));
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: Text('settings.general.theme_dark'.tr()),
              value: 'dark',
              groupValue: state.settings.themeMode,
              onChanged: (value) {
                context.read<SettingsBloc>().add(UpdateThemeModeEvent(value!));
                Navigator.pop(context);
              },
            ),
          ],
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

    if (confirmed == true && mounted) {
      context.read<SettingsBloc>().add(ClearAllDataEvent());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.data.clear_success'.tr())),
      );
    }
  }

  Future<void> _testConnection(BuildContext context) async {
    setState(() => _isTestingConnection = true);

    final geminiService = GeminiService();
    geminiService.setApiKey(_geminiApiKeyController.text);

    final success = await geminiService.testConnection();

    setState(() => _isTestingConnection = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'settings.ai.connection_success'.tr()
                : 'settings.ai.connection_error'.tr(),
          ),
          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    }
  }

  void _resetOnboarding(BuildContext context) {
    context.read<OnboardingBloc>().add(ResetOnboardingEvent());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('settings.about.onboarding_reset_message'.tr())),
    );
    // Navigate to splash to restart onboarding flow
    context.go(RouteNames.splash);
  }
}
