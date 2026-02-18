import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../services/storage/local_storage_service.dart';
import '../bloc/onboarding_bloc.dart';

class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  State<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  String? _selectedLanguage;
  String? _selectedCurrency;

  void _onContinuePressed(BuildContext context) async {
    if (_selectedLanguage == null || _selectedCurrency == null) return;

    await LocalStorageService.setBaseCurrency(_selectedCurrency!);

    final onboardingState = context.read<OnboardingBloc>().state;
    final isOnboardingComplete = onboardingState is OnboardingCompleted;

    if (isOnboardingComplete) {
      context.go(RouteNames.home);
    } else {
      context.go(RouteNames.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languages = AppLocalization.getAllLanguages();
    final currencies = AppConstants.supportedCurrencies;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'language_selection.title'.tr(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: 8.h),
              Text(
                'language_selection.subtitle'.tr(),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: 24.h),

              // Language Selection
              ListView.separated(
                itemCount: languages.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, __) => SizedBox(height: 8.h),
                itemBuilder: (context, index) {
                  final lang = languages[index];
                  final code = lang['code']!;
                  final isSelected = _selectedLanguage == code;

                  return Card(
                    color: isSelected
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                        : null,
                    child: ListTile(
                      onTap: () async {
                        setState(() {
                          _selectedLanguage = code;
                        });
                        await context.setLocale(Locale(code));
                        await LocalStorageService.setLanguage(code);
                      },
                      leading: Text(
                        lang['flag'] ?? '',
                        style: TextStyle(fontSize: 24.sp),
                      ),
                      title: Text(lang['nativeName'] ?? ''),
                      trailing: isSelected
                          ? Icon(Icons.check_circle,
                              color: Theme.of(context).primaryColor)
                          : const Icon(Icons.radio_button_unchecked),
                    ),
                  );
                },
              ),

              SizedBox(height: 16.h),

              // Currency Selection
              Text(
                'language_selection.currency_title'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              SizedBox(height: 8.h),
              Text(
                'language_selection.currency_subtitle'.tr(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SizedBox(height: 12.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: currencies.map((currency) {
                  final isSelected = _selectedCurrency == currency;

                  return ChoiceChip(
                    label: Text(currency),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCurrency = currency;
                        });
                      }
                    },
                  );
                }).toList(),
              ),

              SizedBox(height: 16.h),
              Text(
                'language_selection.footer'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
              ),
              SizedBox(height: 16.h),

              // Continue Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_selectedLanguage != null && _selectedCurrency != null)
                      ? () => _onContinuePressed(context)
                      : null,
                  child: Text('common.next'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

